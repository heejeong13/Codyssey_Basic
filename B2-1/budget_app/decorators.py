"""CLI 공통 예외 처리를 위한 데코레이터."""

from __future__ import annotations

from collections.abc import Callable
from functools import wraps
from typing import ParamSpec

from .errors import AppError

P = ParamSpec("P")


def handle_cli_errors(function: Callable[P, int]) -> Callable[P, int]:
    """예상 가능한 오류를 원인과 해결 힌트로 바꾸고 종료 코드를 반환한다.

    CLI 처리 함수마다 같은 try/except를 반복하지 않도록 공통 예외 처리를
    데코레이터로 분리한다. 사용자에게는 스택 트레이스를 노출하지 않는다.
    """

    @wraps(function)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> int:
        try:
            return function(*args, **kwargs)
        except AppError as exc:
            print(f"오류: {exc.message}")
            print(f"해결 방법: {exc.hint}")
            return 1
        except (EOFError, KeyboardInterrupt):
            print("\n오류: 입력이 중단되었습니다.")
            print("해결 방법: 명령을 다시 실행해 주세요.")
            return 130
        except Exception:
            print("오류: 예상하지 못한 문제가 발생했습니다.")
            print("해결 방법: 입력값과 데이터 파일 상태를 확인해 주세요.")
            return 1

    return wrapper
