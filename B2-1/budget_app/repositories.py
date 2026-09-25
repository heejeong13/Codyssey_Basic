"""JSONL 파일 생성과 영구 저장을 담당하는 저장소."""

from __future__ import annotations

import json
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .errors import AppError
from .models import Transaction

DEFAULT_CATEGORIES = ("food", "transport", "rent", "salary", "etc")


def _write_json_line(file_object: Any, data: dict[str, Any]) -> None:
    """JSON 객체 하나를 UTF-8 JSONL 한 줄로 기록한다."""

    file_object.write(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    file_object.write("\n")


def _read_json(line: str, path: Path, line_number: int | None = None) -> dict[str, Any]:
    """JSONL 한 줄을 객체로 변환하고 손상된 데이터에는 사용자용 오류를 발생시킨다."""

    try:
        value = json.loads(line)
    except json.JSONDecodeError as exc:
        location = f" {line_number}번째 줄" if line_number is not None else ""
        raise AppError(
            f"{path}{location}의 JSON 데이터가 손상되었습니다.",
            "파일 내용을 복구하거나 올바른 JSONL 파일로 교체해 주세요.",
        ) from exc
    if not isinstance(value, dict):
        raise AppError(
            f"{path}에 객체가 아닌 JSON 데이터가 있습니다.",
            "JSONL의 각 줄을 JSON 객체로 작성해 주세요.",
        )
    return value


def _iter_lines_reverse(path: Path, chunk_size: int = 8192) -> Iterator[str]:
    """파일을 통째로 읽지 않고 마지막 줄부터 반환한다.

    파일 끝에서부터 일정 크기의 바이트 묶음을 읽고 줄바꿈을 기준으로
    분리한다. UTF-8 문자가 묶음 경계에서 나뉠 수 있으므로, 완성된 한 줄이
    된 뒤에만 디코딩한다.
    """

    with path.open("rb") as file_object:
        file_object.seek(0, 2)
        position = file_object.tell()
        buffer = b""
        while position > 0:
            read_size = min(chunk_size, position)
            position -= read_size
            file_object.seek(position)
            buffer = file_object.read(read_size) + buffer
            parts = buffer.split(b"\n")
            # 첫 조각은 앞쪽 묶음과 연결될 수 있으므로 다음 반복까지 보관한다.
            buffer = parts[0]
            for part in reversed(parts[1:]):
                if part.strip():
                    try:
                        yield part.decode("utf-8")
                    except UnicodeDecodeError as exc:
                        raise AppError(
                            f"{path} 파일이 UTF-8 형식이 아닙니다.",
                            "파일 인코딩을 UTF-8로 변환해 주세요.",
                        ) from exc
        if buffer.strip():
            try:
                yield buffer.decode("utf-8")
            except UnicodeDecodeError as exc:
                raise AppError(
                    f"{path} 파일이 UTF-8 형식이 아닙니다.",
                    "파일 인코딩을 UTF-8로 변환해 주세요.",
                ) from exc


@dataclass(frozen=True)
class DataPaths:
    """하나의 데이터 폴더 아래에서 사용하는 파일 경로 모음."""

    root: Path

    @property
    def transactions(self) -> Path:
        return self.root / "transactions.jsonl"

    @property
    def categories(self) -> Path:
        return self.root / "categories.jsonl"

    @property
    def budgets(self) -> Path:
        return self.root / "budgets.jsonl"

    def initialize(self) -> None:
        """데이터 파일을 준비하고 비어 있는 카테고리 파일을 기본값으로 채운다."""

        try:
            self.root.mkdir(parents=True, exist_ok=True)
            for path in (self.transactions, self.categories, self.budgets):
                path.touch(exist_ok=True)
            if self.categories.stat().st_size == 0:
                with self.categories.open("w", encoding="utf-8") as file_object:
                    for name in DEFAULT_CATEGORIES:
                        _write_json_line(file_object, {"name": name})
        except OSError as exc:
            raise AppError(
                f"데이터 폴더를 초기화할 수 없습니다: {self.root}",
                "경로와 파일 쓰기 권한을 확인해 주세요.",
            ) from exc


class TransactionRepository:
    """거래 JSONL의 스트리밍 조회와 저장을 담당한다."""

    def __init__(self, path: Path) -> None:
        self.path = path

    def iter_transactions(self, newest_first: bool = False) -> Iterator[Transaction]:
        """거래를 한 건씩 반환한다.

        newest_first가 참이면 역방향 줄 읽기를 사용하므로 전체 파일을
        메모리에 올리지 않고 최근에 저장된 거래부터 조회할 수 있다.
        """

        if newest_first:
            for line in _iter_lines_reverse(self.path):
                try:
                    yield Transaction.from_dict(_read_json(line, self.path))
                except (KeyError, TypeError, ValueError) as exc:
                    raise AppError(
                        f"{self.path}에 필수 거래 필드가 없거나 형식이 잘못되었습니다.",
                        "거래 JSONL의 필드와 값 형식을 확인해 주세요.",
                    ) from exc
            return

        try:
            with self.path.open("r", encoding="utf-8") as file_object:
                for line_number, line in enumerate(file_object, start=1):
                    if not line.strip():
                        continue
                    try:
                        yield Transaction.from_dict(
                            _read_json(line, self.path, line_number)
                        )
                    except (KeyError, TypeError, ValueError) as exc:
                        raise AppError(
                            f"{self.path} {line_number}번째 줄의 거래 형식이 잘못되었습니다.",
                            "필수 필드와 값 형식을 확인해 주세요.",
                        ) from exc
        except UnicodeDecodeError as exc:
            raise AppError(
                f"{self.path} 파일이 UTF-8 형식이 아닙니다.",
                "파일 인코딩을 UTF-8로 변환해 주세요.",
            ) from exc

    def append(self, transaction: Transaction) -> None:
        """거래 한 건을 파일 끝에 추가한다."""

        self.append_many((transaction,))

    def append_many(self, transactions: tuple[Transaction, ...]) -> None:
        """검증이 끝난 여러 거래를 한 번의 파일 열기로 추가한다."""

        try:
            with self.path.open("a", encoding="utf-8") as file_object:
                for transaction in transactions:
                    _write_json_line(file_object, transaction.to_dict())
        except OSError as exc:
            raise AppError(
                "거래를 저장하지 못했습니다.",
                f"{self.path} 파일의 쓰기 권한과 남은 공간을 확인해 주세요.",
            ) from exc

    def rewrite(self, transactions: list[Transaction]) -> None:
        """수정 또는 삭제 결과를 반영하기 위해 거래 파일 전체를 다시 쓴다."""

        try:
            with self.path.open("w", encoding="utf-8") as file_object:
                for transaction in transactions:
                    _write_json_line(file_object, transaction.to_dict())
        except OSError as exc:
            raise AppError(
                "거래 파일을 다시 쓰지 못했습니다.",
                f"{self.path} 파일의 쓰기 권한과 남은 공간을 확인해 주세요.",
            ) from exc


class CategoryStore:
    """카테고리 JSONL의 조회와 저장을 담당한다."""

    def __init__(self, path: Path) -> None:
        self.path = path

    def list_all(self) -> list[str]:
        """등록된 모든 카테고리를 저장 순서대로 반환한다."""

        categories: list[str] = []
        try:
            with self.path.open("r", encoding="utf-8") as file_object:
                for line_number, line in enumerate(file_object, start=1):
                    if not line.strip():
                        continue
                    data = _read_json(line, self.path, line_number)
                    name = data.get("name")
                    if not isinstance(name, str) or not name.strip():
                        raise AppError(
                            f"{self.path} {line_number}번째 줄의 카테고리가 잘못되었습니다.",
                            "name 필드에 비어 있지 않은 문자열을 넣어 주세요.",
                        )
                    categories.append(name)
        except UnicodeDecodeError as exc:
            raise AppError(
                f"{self.path} 파일이 UTF-8 형식이 아닙니다.",
                "파일 인코딩을 UTF-8로 변환해 주세요.",
            ) from exc
        return categories

    def add(self, name: str) -> None:
        """카테고리 하나를 파일 끝에 추가한다."""

        try:
            with self.path.open("a", encoding="utf-8") as file_object:
                _write_json_line(file_object, {"name": name})
        except OSError as exc:
            raise AppError(
                "카테고리를 저장하지 못했습니다.",
                f"{self.path} 파일의 쓰기 권한을 확인해 주세요.",
            ) from exc

    def rewrite(self, categories: list[str]) -> None:
        """삭제 결과를 반영하기 위해 카테고리 파일 전체를 다시 쓴다."""

        try:
            with self.path.open("w", encoding="utf-8") as file_object:
                for name in categories:
                    _write_json_line(file_object, {"name": name})
        except OSError as exc:
            raise AppError(
                "카테고리 파일을 다시 쓰지 못했습니다.",
                f"{self.path} 파일의 쓰기 권한을 확인해 주세요.",
            ) from exc


class BudgetStore:
    """월별 예산 JSONL의 조회와 저장을 담당한다."""

    def __init__(self, path: Path) -> None:
        self.path = path

    def get(self, month: str) -> int | None:
        """지정한 월의 예산을 반환하며, 없으면 None을 반환한다."""

        result: int | None = None
        try:
            with self.path.open("r", encoding="utf-8") as file_object:
                for line_number, line in enumerate(file_object, start=1):
                    if not line.strip():
                        continue
                    data = _read_json(line, self.path, line_number)
                    if data.get("month") == month:
                        result = int(data["amount"])
        except (KeyError, TypeError, ValueError) as exc:
            raise AppError(
                f"{self.path}의 예산 데이터 형식이 잘못되었습니다.",
                "month와 amount 필드를 확인해 주세요.",
            ) from exc
        except UnicodeDecodeError as exc:
            raise AppError(
                f"{self.path} 파일이 UTF-8 형식이 아닙니다.",
                "파일 인코딩을 UTF-8로 변환해 주세요.",
            ) from exc
        return result

    def set(self, month: str, amount: int) -> None:
        """월별 예산을 새로 등록하거나 기존 금액을 변경한다."""

        budgets: dict[str, int] = {}
        try:
            with self.path.open("r", encoding="utf-8") as file_object:
                for line_number, line in enumerate(file_object, start=1):
                    if not line.strip():
                        continue
                    data = _read_json(line, self.path, line_number)
                    budgets[str(data["month"])] = int(data["amount"])
            budgets[month] = amount
            with self.path.open("w", encoding="utf-8") as file_object:
                for saved_month in sorted(budgets):
                    _write_json_line(
                        file_object,
                        {"month": saved_month, "amount": budgets[saved_month]},
                    )
        except (KeyError, TypeError, ValueError) as exc:
            raise AppError(
                f"{self.path}의 예산 데이터 형식이 잘못되었습니다.",
                "month와 amount 필드를 확인해 주세요.",
            ) from exc
        except OSError as exc:
            raise AppError(
                "예산을 저장하지 못했습니다.",
                f"{self.path} 파일의 쓰기 권한을 확인해 주세요.",
            ) from exc
