"""가계부의 검증과 업무 규칙."""

from __future__ import annotations

import csv
from collections import defaultdict
from collections.abc import Iterator
from datetime import datetime
from pathlib import Path
from uuid import uuid4

from .errors import AppError
from .models import MonthlySummary, Transaction
from .repositories import BudgetStore, CategoryStore, TransactionRepository

CSV_COLUMNS = ("date", "type", "category", "amount", "memo", "tags")
ALLOWED_TYPES = ("income", "expense")


def validate_date(value: str) -> str:
    """문자열이 실제로 존재하는 YYYY-MM-DD 날짜인지 검증한다."""

    try:
        parsed = datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise AppError(
            f"날짜 형식이 올바르지 않습니다: {value}",
            "YYYY-MM-DD 형식의 실제 날짜를 입력해 주세요.",
        ) from exc
    if parsed.strftime("%Y-%m-%d") != value:
        raise AppError(
            f"날짜 형식이 올바르지 않습니다: {value}",
            "YYYY-MM-DD 형식으로 입력해 주세요.",
        )
    return value


def validate_month(value: str) -> str:
    """문자열이 실제로 존재하는 YYYY-MM 형식의 월인지 검증한다."""

    try:
        parsed = datetime.strptime(value, "%Y-%m")
    except ValueError as exc:
        raise AppError(
            f"월 형식이 올바르지 않습니다: {value}",
            "YYYY-MM 형식의 실제 월을 입력해 주세요.",
        ) from exc
    if parsed.strftime("%Y-%m") != value:
        raise AppError(
            f"월 형식이 올바르지 않습니다: {value}",
            "YYYY-MM 형식으로 입력해 주세요.",
        )
    return value


def validate_type(value: str) -> str:
    """거래 타입이 income 또는 expense인지 검증한다."""

    if value not in ALLOWED_TYPES:
        raise AppError(
            f"허용되지 않은 거래 타입입니다: {value}",
            "income 또는 expense를 입력해 주세요.",
        )
    return value


def validate_amount(value: int | str) -> int:
    """입력값을 0보다 큰 정수 금액으로 변환한다."""

    try:
        amount = int(value)
    except (TypeError, ValueError) as exc:
        raise AppError(
            f"금액이 정수가 아닙니다: {value}",
            "0보다 큰 정수를 입력해 주세요.",
        ) from exc
    if amount <= 0:
        raise AppError(
            f"금액은 0보다 커야 합니다: {amount}",
            "0보다 큰 정수를 입력해 주세요.",
        )
    return amount


def parse_tags(value: str | None) -> tuple[str, ...]:
    """쉼표로 구분된 태그 문자열을 중복 없는 튜플로 변환한다."""

    if not value:
        return ()
    tags: list[str] = []
    for raw_tag in value.split(","):
        tag = raw_tag.strip()
        if tag and tag not in tags:
            tags.append(tag)
    return tuple(tags)


class LedgerService:
    """저장소를 조합해 거래, 예산, 카테고리의 업무 규칙을 수행한다."""

    def __init__(
        self,
        transactions: TransactionRepository,
        categories: CategoryStore,
        budgets: BudgetStore,
    ) -> None:
        self.transactions = transactions
        self.categories = categories
        self.budgets = budgets

    def _validate_category(self, category: str) -> str:
        """카테고리가 현재 목록에 등록되어 있는지 확인한다."""

        if category not in self.categories.list_all():
            raise AppError(
                f"등록되지 않은 카테고리입니다: {category}",
                "category add 명령으로 먼저 카테고리를 등록해 주세요.",
            )
        return category

    def create_transaction(
        self,
        *,
        date: str,
        transaction_type: str,
        category: str,
        amount: int | str,
        memo: str = "",
        tags: str | None = None,
    ) -> Transaction:
        """입력값을 검증하고 고유 ID를 가진 거래를 저장한다."""

        transaction = Transaction(
            id=str(uuid4()),
            type=validate_type(transaction_type.strip()),
            date=validate_date(date.strip()),
            amount=validate_amount(amount),
            category=self._validate_category(category.strip()),
            memo=memo.strip(),
            tags=parse_tags(tags),
        )
        self.transactions.append(transaction)
        return transaction

    def list_transactions(self, limit: int) -> Iterator[Transaction]:
        """저장 시점 기준 최신 거래를 최대 limit개까지 스트리밍한다."""

        if limit <= 0:
            raise AppError(
                f"조회 건수는 0보다 커야 합니다: {limit}",
                "--limit에 0보다 큰 정수를 지정해 주세요.",
            )
        for index, transaction in enumerate(
            self.transactions.iter_transactions(newest_first=True)
        ):
            if index >= limit:
                break
            yield transaction

    def search(
        self,
        *,
        from_date: str | None = None,
        to_date: str | None = None,
        category: str | None = None,
        transaction_type: str | None = None,
        query: str | None = None,
        tag: str | None = None,
    ) -> Iterator[Transaction]:
        """주어진 조건을 모두 만족하는 거래를 최신순으로 스트리밍한다."""

        if from_date:
            validate_date(from_date)
        if to_date:
            validate_date(to_date)
        if from_date and to_date and from_date > to_date:
            raise AppError(
                "검색 시작일이 종료일보다 늦습니다.",
                "--from 날짜가 --to 날짜보다 빠르거나 같게 지정해 주세요.",
            )
        if category:
            self._validate_category(category)
        if transaction_type:
            validate_type(transaction_type)

        def matches() -> Iterator[Transaction]:
            # 조건을 통과한 거래만 즉시 넘겨 검색 결과 전체를 메모리에 쌓지 않는다.
            for transaction in self.transactions.iter_transactions(newest_first=True):
                if from_date and transaction.date < from_date:
                    continue
                if to_date and transaction.date > to_date:
                    continue
                if category and transaction.category != category:
                    continue
                if transaction_type and transaction.type != transaction_type:
                    continue
                if query and query.casefold() not in transaction.memo.casefold():
                    continue
                if tag and tag not in transaction.tags:
                    continue
                yield transaction

        return matches()

    def update_transaction(self, transaction_id: str, **changes: object) -> Transaction:
        """ID로 거래를 찾아 검증된 필드만 변경하고 파일을 다시 저장한다."""

        if not changes:
            raise AppError(
                "변경할 항목이 없습니다.",
                "--date, --type, --category, --amount, --memo, --tags 중 하나를 지정해 주세요.",
            )

        # 보너스인 원자적 교체는 사용하지 않고, 과제에서 허용한 전체 재작성을 적용한다.
        saved = list(self.transactions.iter_transactions())
        updated: Transaction | None = None
        for index, transaction in enumerate(saved):
            if transaction.id != transaction_id:
                continue
            new_date = str(changes.get("date", transaction.date))
            new_type = str(changes.get("type", transaction.type))
            new_category = str(changes.get("category", transaction.category))
            raw_amount = changes.get("amount", transaction.amount)
            new_memo = str(changes.get("memo", transaction.memo))
            raw_tags = changes.get("tags")
            new_tags = transaction.tags if raw_tags is None else parse_tags(str(raw_tags))
            updated = Transaction(
                id=transaction.id,
                type=validate_type(new_type.strip()),
                date=validate_date(new_date.strip()),
                amount=validate_amount(raw_amount),
                category=self._validate_category(new_category.strip()),
                memo=new_memo.strip(),
                tags=new_tags,
            )
            saved[index] = updated
            break
        if updated is None:
            raise AppError(
                f"거래 ID를 찾을 수 없습니다: {transaction_id}",
                "list 또는 search 명령으로 올바른 ID를 확인해 주세요.",
            )
        self.transactions.rewrite(saved)
        return updated

    def delete_transaction(self, transaction_id: str) -> None:
        """ID가 일치하는 거래를 제거하고 거래 파일 전체를 다시 저장한다."""

        saved = list(self.transactions.iter_transactions())
        remaining = [item for item in saved if item.id != transaction_id]
        if len(saved) == len(remaining):
            raise AppError(
                f"거래 ID를 찾을 수 없습니다: {transaction_id}",
                "list 또는 search 명령으로 올바른 ID를 확인해 주세요.",
            )
        self.transactions.rewrite(remaining)

    def summarize(self, month: str, top: int) -> MonthlySummary:
        """한 달의 수입·지출·잔액과 지출 카테고리 상위 항목을 집계한다."""

        validate_month(month)
        if top <= 0:
            raise AppError(
                f"상위 카테고리 개수는 0보다 커야 합니다: {top}",
                "--top에 0보다 큰 정수를 지정해 주세요.",
            )
        income = 0
        expense = 0
        count = 0
        category_expenses: defaultdict[str, int] = defaultdict(int)
        # 합계만 누적하므로 거래 수가 많아도 모든 거래를 별도 목록에 보관하지 않는다.
        for transaction in self.transactions.iter_transactions():
            if not transaction.date.startswith(f"{month}-"):
                continue
            count += 1
            if transaction.type == "income":
                income += transaction.amount
            else:
                expense += transaction.amount
                category_expenses[transaction.category] += transaction.amount
        top_expenses = tuple(
            sorted(category_expenses.items(), key=lambda item: (-item[1], item[0]))[:top]
        )
        budget = self.budgets.get(month)
        usage = (expense / budget * 100) if budget is not None else None
        return MonthlySummary(
            transaction_count=count,
            total_income=income,
            total_expense=expense,
            balance=income - expense,
            top_expenses=top_expenses,
            budget=budget,
            budget_usage=usage,
            budget_exceeded=budget is not None and expense > budget,
        )

    def set_budget(self, month: str, amount: int | str) -> int:
        """월과 금액을 검증한 뒤 예산을 저장한다."""

        validate_month(month)
        validated_amount = validate_amount(amount)
        self.budgets.set(month, validated_amount)
        return validated_amount

    def get_budget(self, month: str) -> int | None:
        """검증된 월의 예산을 조회한다."""

        validate_month(month)
        return self.budgets.get(month)

    def add_category(self, name: str) -> str:
        """비어 있지 않고 중복되지 않은 카테고리를 등록한다."""

        normalized = name.strip()
        if not normalized:
            raise AppError(
                "카테고리 이름이 비어 있습니다.",
                "비어 있지 않은 카테고리 이름을 입력해 주세요.",
            )
        if "," in normalized:
            raise AppError(
                "카테고리 이름에는 쉼표를 사용할 수 없습니다.",
                "쉼표를 제외한 이름을 입력해 주세요.",
            )
        if normalized in self.categories.list_all():
            raise AppError(
                f"이미 존재하는 카테고리입니다: {normalized}",
                "category list 명령으로 현재 목록을 확인해 주세요.",
            )
        self.categories.add(normalized)
        return normalized

    def list_categories(self) -> list[str]:
        """현재 등록된 카테고리 목록을 반환한다."""

        return self.categories.list_all()

    def remove_category(self, name: str) -> None:
        """거래에서 사용하지 않는 카테고리만 삭제한다."""

        normalized = name.strip()
        categories = self.categories.list_all()
        if normalized not in categories:
            raise AppError(
                f"존재하지 않는 카테고리입니다: {normalized}",
                "category list 명령으로 현재 목록을 확인해 주세요.",
            )
        if any(
            transaction.category == normalized
            for transaction in self.transactions.iter_transactions()
        ):
            raise AppError(
                f"사용 중인 카테고리는 삭제할 수 없습니다: {normalized}",
                "관련 거래의 카테고리를 수정하거나 거래를 삭제한 뒤 다시 시도해 주세요.",
            )
        self.categories.rewrite([item for item in categories if item != normalized])

    def import_csv(self, source: Path) -> int:
        """CSV를 모두 검증한 뒤 거래로 변환해 일괄 저장한다.

        중간 행에서 오류가 발생해 일부 거래만 저장되는 일을 막기 위해
        전체 행을 staged 목록에 준비한 후 한꺼번에 저장한다.
        """

        staged: list[Transaction] = []
        categories = set(self.categories.list_all())
        try:
            with source.open("r", encoding="utf-8-sig", newline="") as file_object:
                reader = csv.DictReader(file_object)
                headers = reader.fieldnames or []
                missing = [name for name in CSV_COLUMNS if name not in headers]
                if missing:
                    raise AppError(
                        f"CSV에 필수 열이 없습니다: {', '.join(missing)}",
                        f"헤더를 다음 형식으로 작성해 주세요: {', '.join(CSV_COLUMNS)}",
                    )
                for row_number, row in enumerate(reader, start=2):
                    try:
                        date = validate_date((row.get("date") or "").strip())
                        transaction_type = validate_type((row.get("type") or "").strip())
                        category = (row.get("category") or "").strip()
                        if category not in categories:
                            raise AppError(
                                f"등록되지 않은 카테고리입니다: {category}",
                                "category add 명령으로 먼저 카테고리를 등록해 주세요.",
                            )
                        amount = validate_amount((row.get("amount") or "").strip())
                    except AppError as exc:
                        raise AppError(
                            f"CSV {row_number}번째 행 오류: {exc.message}", exc.hint
                        ) from exc
                    staged.append(
                        Transaction(
                            id=str(uuid4()),
                            type=transaction_type,
                            date=date,
                            amount=amount,
                            category=category,
                            memo=(row.get("memo") or "").strip(),
                            tags=parse_tags(row.get("tags")),
                        )
                    )
        except FileNotFoundError as exc:
            raise AppError(
                f"CSV 파일을 찾을 수 없습니다: {source}",
                "--from에 존재하는 파일 경로를 지정해 주세요.",
            ) from exc
        except UnicodeDecodeError as exc:
            raise AppError(
                f"CSV 파일이 UTF-8 형식이 아닙니다: {source}",
                "파일을 UTF-8 인코딩으로 저장한 뒤 다시 시도해 주세요.",
            ) from exc
        except OSError as exc:
            raise AppError(
                f"CSV 파일을 읽을 수 없습니다: {source}",
                "파일 경로와 읽기 권한을 확인해 주세요.",
            ) from exc
        self.transactions.append_many(tuple(staged))
        return len(staged)

    def export_csv(
        self,
        destination: Path,
        *,
        month: str | None = None,
        from_date: str | None = None,
        to_date: str | None = None,
    ) -> int:
        """월 또는 날짜 범위에 해당하는 거래를 UTF-8 CSV로 내보낸다."""

        if month and (from_date or to_date):
            raise AppError(
                "--month와 날짜 범위는 동시에 사용할 수 없습니다.",
                "--month 또는 --from/--to 중 한 가지 방식만 선택해 주세요.",
            )
        if not month and not (from_date and to_date):
            raise AppError(
                "내보내기 조건이 부족합니다.",
                "--month 또는 --from과 --to를 함께 지정해 주세요.",
            )
        if bool(from_date) != bool(to_date):
            raise AppError(
                "날짜 범위의 시작일과 종료일이 모두 필요합니다.",
                "--from과 --to를 함께 지정해 주세요.",
            )
        if month:
            validate_month(month)
        if from_date:
            validate_date(from_date)
        if to_date:
            validate_date(to_date)
        if from_date and to_date and from_date > to_date:
            raise AppError(
                "내보내기 시작일이 종료일보다 늦습니다.",
                "--from 날짜가 --to 날짜보다 빠르거나 같게 지정해 주세요.",
            )

        count = 0
        try:
            with destination.open("w", encoding="utf-8", newline="") as file_object:
                writer = csv.DictWriter(file_object, fieldnames=CSV_COLUMNS)
                writer.writeheader()
                for transaction in self.transactions.iter_transactions():
                    if month and not transaction.date.startswith(f"{month}-"):
                        continue
                    if from_date and transaction.date < from_date:
                        continue
                    if to_date and transaction.date > to_date:
                        continue
                    writer.writerow(
                        {
                            "date": transaction.date,
                            "type": transaction.type,
                            "category": transaction.category,
                            "amount": transaction.amount,
                            "memo": transaction.memo,
                            "tags": ",".join(transaction.tags),
                        }
                    )
                    count += 1
        except OSError as exc:
            raise AppError(
                f"CSV 파일을 생성할 수 없습니다: {destination}",
                "출력 경로와 폴더의 쓰기 권한을 확인해 주세요.",
            ) from exc
        return count
