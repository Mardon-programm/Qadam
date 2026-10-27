from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "development"
    app_name: str = "Qadam"
    app_debug: bool = False
    secret_key: str = Field(default="dev-only-change-me")
    access_token_ttl_minutes: int = 30
    refresh_token_ttl_days: int = 30

    default_city: str = "bishkek"
    default_locale: str = "ru"
    supported_locales: str = "ru,ky"

    database_url: str = (
        "postgresql+asyncpg://qadam:qadam_dev_password@localhost:5432/qadam"
    )
    redis_url: str = "redis://localhost:6379/0"

    sms_provider: str = "console"
    otp_ttl_seconds: int = 300
    otp_length: int = 6
    otp_max_attempts: int = 5
    otp_rate_limit_per_phone: int = 5

    payment_provider: str = "mock"
    payment_webhook_secret: str = "dev-webhook-secret"

    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"

    ops_bootstrap_phone: str = "+996700000001"
    ops_bootstrap_name: str = "Qadam Ops"

    # City pricing defaults (KGS) — tunable via ops later
    city_base_fare: float = 50.0
    city_per_km: float = 12.0
    city_per_minute: float = 2.0
    city_min_fare: float = 80.0
    city_surge_cap: float = 2.0
    flex_commission_rate: float = 0.0  # Free for drivers - no commission

    @property
    def locale_list(self) -> list[str]:
        return [x.strip() for x in self.supported_locales.split(",") if x.strip()]

    @property
    def cors_origin_list(self) -> list[str]:
        return [x.strip() for x in self.cors_origins.split(",") if x.strip()]

    @property
    def is_dev(self) -> bool:
        return self.app_env in {"development", "dev", "local", "test"}

    @field_validator("secret_key")
    @classmethod
    def warn_weak_secret(cls, value: str) -> str:
        if value in {"change-me-to-a-long-random-string", "dev-only-change-me"}:
            return value
        if len(value) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters")
        return value


@lru_cache
def get_settings() -> Settings:
    return Settings()
