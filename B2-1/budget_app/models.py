"""가계부 데이터 모델."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Any


@dataclass(frozen=True)
class Transaction:
    """수입 또는 지출 한 건."""

    id: str
    type: str
    date: str
    amount: int
    category: str
    memo: str = ""
    tags: tuple[str, ...] = ()

    def to_dict(self) -> dict[str, Any]:
        """JSONL에 기록할 수 있는 딕셔너리로 변환한다."""

        data = asdict(self)
        data["tags"] = list(self.tags)
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Transaction:
        """JSON 객체에서 거래 모델을 생성한다."""

        return cls(
            id=str(data["id"]),
            type=str(data["type"]),
            date=str(data["date"]),
            amount=int(data["amount"]),
            category=str(data["category"]),
            memo=str(data.get("memo", "")),
            tags=tuple(str(tag) for tag in data.get("tags", [])),
        )


@dataclass(frozen=True)
class MonthlySummary:
    """월별 집계 결과."""

    transaction_count: int
    total_income: int
    total_expense: int
    balance: int
    top_expenses: tuple[tuple[str, int], ...]
    budget: int | None
    budget_usage: float | None
    budget_exceeded: bool
