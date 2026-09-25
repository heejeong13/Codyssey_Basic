"""명령행 인터페이스와 대화형 입력."""

from __future__ import annotations

import argparse
from collections.abc import Callable, Iterator
from pathlib import Path

from .decorators import handle_cli_errors
from .errors import AppError
from .formatters import format_money, format_summary, format_transaction
from .models import Transaction
from .repositories import BudgetStore, CategoryStore, DataPaths, TransactionRepository
from .services import LedgerService


class LongOptionParser(argparse.ArgumentParser):
    """도움말 옵션도 `--` 표기만 사용하는 파서."""

    def __init__(self, *args: object, **kwargs: object) -> None:
        kwargs["add_help"] = False
        super().__init__(*args, **kwargs)
        self.add_argument("--help", action="help", help="도움말을 출력하고 종료")


def build_parser() -> argparse.ArgumentParser:
    """지원하는 명령과 `--` 옵션을 정의한 파서를 생성한다."""

    parser = LongOptionParser(description="파일 기반 콘솔 용돈기입장")
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path("./data"),
        help="데이터 저장 폴더 (기본값: ./data)",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    add_parser = commands.add_parser("add", help="대화형으로 거래 추가")
    add_parser.set_defaults(handler=handle_add)

    list_parser = commands.add_parser("list", help="최신순 거래 목록")
    list_parser.add_argument("--limit", type=int, default=20, help="출력 건수 (기본값: 20)")
    list_parser.set_defaults(handler=handle_list)

    search_parser = commands.add_parser("search", help="조건으로 거래 검색")
    search_parser.add_argument("--from", dest="from_date", help="시작일 YYYY-MM-DD")
    search_parser.add_argument("--to", dest="to_date", help="종료일 YYYY-MM-DD")
    search_parser.add_argument("--category", help="카테고리")
    search_parser.add_argument("--type", dest="transaction_type", help="income 또는 expense")
    search_parser.add_argument("--q", dest="query", help="메모 키워드")
    search_parser.add_argument("--tag", help="태그")
    search_parser.set_defaults(handler=handle_search)

    summary_parser = commands.add_parser("summary", help="월별 요약")
    summary_parser.add_argument("--month", required=True, help="대상 월 YYYY-MM")
    summary_parser.add_argument("--top", type=int, default=5, help="상위 지출 카테고리 수")
    summary_parser.set_defaults(handler=handle_summary)

    budget_parser = commands.add_parser("budget", help="월별 예산 설정 및 조회")
    budget_commands = budget_parser.add_subparsers(dest="budget_command", required=True)
    budget_set = budget_commands.add_parser("set", help="예산 설정")
    budget_set.add_argument("--month", required=True, help="대상 월 YYYY-MM")
    budget_set.add_argument("--amount", required=True, help="예산 금액")
    budget_set.set_defaults(handler=handle_budget_set)
    budget_get = budget_commands.add_parser("get", help="예산 조회")
    budget_get.add_argument("--month", required=True, help="대상 월 YYYY-MM")
    budget_get.set_defaults(handler=handle_budget_get)

    category_parser = commands.add_parser("category", help="카테고리 관리")
    category_commands = category_parser.add_subparsers(dest="category_command", required=True)
    category_add = category_commands.add_parser("add", help="대화형으로 카테고리 추가")
    category_add.set_defaults(handler=handle_category_add)
    category_list = category_commands.add_parser("list", help="카테고리 목록")
    category_list.set_defaults(handler=handle_category_list)
    category_remove = category_commands.add_parser("remove", help="대화형으로 카테고리 삭제")
    category_remove.set_defaults(handler=handle_category_remove)

    update_parser = commands.add_parser("update", help="ID로 거래 수정")
    update_parser.add_argument("--id", required=True, help="거래 ID")
    update_parser.add_argument("--date", help="변경할 날짜 YYYY-MM-DD")
    update_parser.add_argument("--type", dest="transaction_type", help="income 또는 expense")
    update_parser.add_argument("--category", help="변경할 카테고리")
    update_parser.add_argument("--amount", help="변경할 금액")
    update_parser.add_argument("--memo", help="변경할 메모")
    update_parser.add_argument("--tags", help="쉼표로 구분한 태그")
    update_parser.set_defaults(handler=handle_update)

    delete_parser = commands.add_parser("delete", help="ID로 거래 삭제")
    delete_parser.add_argument("--id", required=True, help="거래 ID")
    delete_parser.set_defaults(handler=handle_delete)

    import_parser = commands.add_parser("import", help="CSV 거래 가져오기")
    import_parser.add_argument("--from", dest="source", type=Path, required=True, help="CSV 경로")
    import_parser.set_defaults(handler=handle_import)

    export_parser = commands.add_parser("export", help="조건에 맞는 거래를 CSV로 내보내기")
    export_parser.add_argument("--out", type=Path, required=True, help="출력 CSV 경로")
    export_parser.add_argument("--month", help="대상 월 YYYY-MM")
    export_parser.add_argument("--from", dest="from_date", help="시작일 YYYY-MM-DD")
    export_parser.add_argument("--to", dest="to_date", help="종료일 YYYY-MM-DD")
    export_parser.set_defaults(handler=handle_export)

    return parser


def create_service(data_dir: Path) -> LedgerService:
    """데이터 파일을 초기화하고 서비스에 필요한 저장소를 연결한다."""

    paths = DataPaths(data_dir)
    paths.initialize()
    return LedgerService(
        TransactionRepository(paths.transactions),
        CategoryStore(paths.categories),
        BudgetStore(paths.budgets),
    )


def _print_transactions(transactions: Iterator[Transaction]) -> int:
    """거래 이터레이터를 소비하며 한 건씩 출력하고 출력 건수를 반환한다."""

    count = 0
    for transaction in transactions:
        print(format_transaction(transaction))
        count += 1
    if count == 0:
        print("거래 내역이 없습니다.")
    return count


def handle_add(args: argparse.Namespace, service: LedgerService) -> int:
    """대화형 입력을 받아 거래를 추가하며 잘못된 입력은 다시 받는다."""

    while True:
        try:
            print("등록된 카테고리: " + ", ".join(service.list_categories()))
            transaction = service.create_transaction(
                date=input("날짜(YYYY-MM-DD): "),
                transaction_type=input("타입(income/expense): "),
                category=input("카테고리: "),
                amount=input("금액: "),
                memo=input("메모(선택): "),
                tags=input("태그(선택, 쉼표 구분): "),
            )
            print(f"거래를 저장했습니다. id={transaction.id}")
            return 0
        except AppError as exc:
            print(f"입력 오류: {exc.message}")
            print(f"해결 방법: {exc.hint}")
            print("모든 항목을 다시 입력해 주세요.")


def handle_list(args: argparse.Namespace, service: LedgerService) -> int:
    """요청한 개수만큼 최신 거래를 출력한다."""

    _print_transactions(service.list_transactions(args.limit))
    return 0


def handle_search(args: argparse.Namespace, service: LedgerService) -> int:
    """명령행 검색 조건을 서비스에 전달하고 결과를 출력한다."""

    _print_transactions(
        service.search(
            from_date=args.from_date,
            to_date=args.to_date,
            category=args.category,
            transaction_type=args.transaction_type,
            query=args.query,
            tag=args.tag,
        )
    )
    return 0


def handle_summary(args: argparse.Namespace, service: LedgerService) -> int:
    """월별 집계와 설정된 예산 정보를 출력한다."""

    summary = service.summarize(args.month, args.top)
    if summary.transaction_count == 0:
        print(f"{args.month}: 데이터 없음")
        if summary.budget is not None and summary.budget_usage is not None:
            print(f"예산: {format_money(summary.budget)}")
            print(f"예산 사용률: {summary.budget_usage:.1f}%")
        return 0
    print(format_summary(args.month, summary))
    return 0


def handle_budget_set(args: argparse.Namespace, service: LedgerService) -> int:
    """월별 예산을 저장하고 결과를 출력한다."""

    amount = service.set_budget(args.month, args.amount)
    print(f"{args.month} 예산을 {format_money(amount)}으로 저장했습니다.")
    return 0


def handle_budget_get(args: argparse.Namespace, service: LedgerService) -> int:
    """월별 예산을 조회해 출력한다."""

    amount = service.get_budget(args.month)
    if amount is None:
        print(f"{args.month}에 설정된 예산이 없습니다.")
    else:
        print(f"{args.month} 예산: {format_money(amount)}")
    return 0


def handle_category_add(args: argparse.Namespace, service: LedgerService) -> int:
    """대화형으로 카테고리 이름을 입력받아 추가한다."""

    name = service.add_category(input("추가할 카테고리 이름: "))
    print(f"카테고리를 추가했습니다: {name}")
    return 0


def handle_category_list(args: argparse.Namespace, service: LedgerService) -> int:
    """등록된 카테고리를 한 줄에 하나씩 출력한다."""

    categories = service.list_categories()
    if not categories:
        print("등록된 카테고리가 없습니다.")
    else:
        for name in categories:
            print(name)
    return 0


def handle_category_remove(args: argparse.Namespace, service: LedgerService) -> int:
    """대화형으로 카테고리 이름을 입력받아 삭제한다."""

    name = input("삭제할 카테고리 이름: ")
    service.remove_category(name)
    print(f"카테고리를 삭제했습니다: {name.strip()}")
    return 0


def handle_update(args: argparse.Namespace, service: LedgerService) -> int:
    """사용자가 지정한 옵션만 변경 항목으로 모아 거래를 수정한다."""

    changes: dict[str, object] = {}
    for argument_name, field_name in (
        ("date", "date"),
        ("transaction_type", "type"),
        ("category", "category"),
        ("amount", "amount"),
        ("memo", "memo"),
        ("tags", "tags"),
    ):
        value = getattr(args, argument_name)
        if value is not None:
            changes[field_name] = value
    transaction = service.update_transaction(args.id, **changes)
    print(f"거래를 수정했습니다. id={transaction.id}")
    return 0


def handle_delete(args: argparse.Namespace, service: LedgerService) -> int:
    """ID가 일치하는 거래를 삭제한다."""

    service.delete_transaction(args.id)
    print(f"거래를 삭제했습니다. id={args.id}")
    return 0


def handle_import(args: argparse.Namespace, service: LedgerService) -> int:
    """외부 CSV를 가져오고 저장된 거래 건수를 출력한다."""

    count = service.import_csv(args.source)
    print(f"CSV 가져오기를 완료했습니다. 처리 건수={count}")
    return 0


def handle_export(args: argparse.Namespace, service: LedgerService) -> int:
    """조건에 맞는 거래를 CSV로 내보내고 처리 결과를 출력한다."""

    count = service.export_csv(
        args.out,
        month=args.month,
        from_date=args.from_date,
        to_date=args.to_date,
    )
    print(f"CSV 내보내기를 완료했습니다. 처리 건수={count}, 파일={args.out}")
    return 0


@handle_cli_errors
def main(argv: list[str] | None = None) -> int:
    """명령을 해석하고 해당 처리 함수를 실행해 종료 코드를 반환한다."""

    parser = build_parser()
    args = parser.parse_args(argv)
    service = create_service(args.data_dir)
    handler: Callable[[argparse.Namespace, LedgerService], int] = args.handler
    return handler(args, service)
