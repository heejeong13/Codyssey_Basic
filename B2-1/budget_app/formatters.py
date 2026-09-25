"""콘솔 출력 문자열 구성."""

from .models import MonthlySummary, Transaction


def format_money(amount: int) -> str:
    """정수 금액을 천 단위 구분 기호가 있는 원화 문자열로 만든다."""

    return f"{amount:,}원"


def format_transaction(transaction: Transaction) -> str:
    """거래 한 건을 콘솔에 출력할 한 줄 문자열로 만든다."""

    tags = ",".join(transaction.tags) if transaction.tags else "-"
    memo = transaction.memo or "-"
    return (
        f"id={transaction.id} | {transaction.date} | {transaction.type} | "
        f"{transaction.category} | {format_money(transaction.amount)} | "
        f"메모={memo} | 태그={tags}"
    )


def format_summary(month: str, summary: MonthlySummary) -> str:
    """월별 요약 결과를 여러 줄의 콘솔 문자열로 만든다."""

    lines = [
        f"[{month} 월별 요약]",
        f"총수입: {format_money(summary.total_income)}",
        f"총지출: {format_money(summary.total_expense)}",
        f"잔액: {format_money(summary.balance)}",
        "카테고리별 지출 TOP:",
    ]
    if summary.top_expenses:
        for index, (category, amount) in enumerate(summary.top_expenses, start=1):
            lines.append(f"{index}. {category}: {format_money(amount)}")
    else:
        lines.append("없음")
    if summary.budget is not None and summary.budget_usage is not None:
        lines.append(f"예산: {format_money(summary.budget)}")
        lines.append(f"예산 사용률: {summary.budget_usage:.1f}%")
        if summary.budget_exceeded:
            lines.append("경고: 월 예산을 초과했습니다.")
    return "\n".join(lines)
