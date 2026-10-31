from pydantic import BaseModel, Field


class OTPRequestIn(BaseModel):
    phone: str = Field(..., examples=["+996700123456"])
    role: str = Field(default="passenger", pattern="^(passenger|driver|ops)$")


class OTPRequestOut(BaseModel):
    sent: bool
    expires_in_seconds: int
    # Dev only — never returned in production
    debug_code: str | None = None


class OTPVerifyIn(BaseModel):
    phone: str
    code: str
    role: str = Field(default="passenger", pattern="^(passenger|driver|ops)$")
    full_name: str | None = None
    nickname: str | None = None
    locale: str = "ru"


class RegisterDriverIn(BaseModel):
    phone: str = Field(..., examples=["+996700123456"])
    full_name: str = Field(..., min_length=2, max_length=255)
    password: str = Field(..., min_length=6, max_length=128)
    photo_url: str | None = None


class LoginDriverIn(BaseModel):
    phone: str
    full_name: str
    password: str


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    role: str
    phone: str


class RefreshIn(BaseModel):
    refresh_token: str


class MeOut(BaseModel):
    id: str
    phone: str
    full_name: str | None
    nickname: str | None = None
    photo_url: str | None = None
    role: str
    locale: str
    status: str
