from fastapi import HTTPException, status


class AppError(HTTPException):
    def __init__(
        self,
        detail: str,
        *,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        code: str = "app_error",
        retry_after_seconds: int | None = None,
    ) -> None:
        payload: dict[str, object] = {"code": code, "message": detail}
        if retry_after_seconds is not None:
            payload["retry_after_seconds"] = retry_after_seconds
        super().__init__(status_code=status_code, detail=payload)


class UnauthorizedError(AppError):
    def __init__(self, detail: str = "Unauthorized") -> None:
        super().__init__(
            detail,
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="unauthorized",
        )


class ForbiddenError(AppError):
    def __init__(self, detail: str = "Forbidden") -> None:
        super().__init__(
            detail,
            status_code=status.HTTP_403_FORBIDDEN,
            code="forbidden",
        )


class NotFoundError(AppError):
    def __init__(self, detail: str = "Not found") -> None:
        super().__init__(
            detail,
            status_code=status.HTTP_404_NOT_FOUND,
            code="not_found",
        )


class ConflictError(AppError):
    def __init__(self, detail: str = "Conflict") -> None:
        super().__init__(
            detail,
            status_code=status.HTTP_409_CONFLICT,
            code="conflict",
        )


class RateLimitError(AppError):
    def __init__(
        self,
        detail: str = "Too many requests",
        *,
        retry_after_seconds: int | None = None,
    ) -> None:
        super().__init__(
            detail,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            code="rate_limited",
            retry_after_seconds=retry_after_seconds,
        )
