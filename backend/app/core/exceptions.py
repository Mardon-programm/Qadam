from fastapi import HTTPException, status


class AppError(HTTPException):
    def __init__(
        self,
        detail: str,
        *,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        code: str = "app_error",
    ) -> None:
        super().__init__(status_code=status_code, detail={"code": code, "message": detail})


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
    def __init__(self, detail: str = "Too many requests") -> None:
        super().__init__(
            detail,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            code="rate_limited",
        )
