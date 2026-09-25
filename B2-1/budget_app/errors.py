"""애플리케이션에서 사용자에게 안내할 오류 정의."""


class AppError(Exception):
    """원인과 해결 힌트를 함께 전달하는 예상 가능한 오류."""

    def __init__(self, message: str, hint: str) -> None:
        """사용자에게 보여 줄 오류 원인과 해결 방법을 저장한다."""

        super().__init__(message)
        self.message = message
        self.hint = hint
