"""Support case schemas."""

from pydantic import BaseModel


class SupportCaseIn(BaseModel):
    case_type: str
    subject: str
    description: str
    reference_type: str | None = None
    reference_id: str | None = None


class SupportCaseOut(BaseModel):
    id: str
    user_id: str
    case_type: str
    status: str
    subject: str
    description: str
    reference_type: str | None
    reference_id: str | None
    assignee_id: str | None
    resolution: str | None


class ResolveIn(BaseModel):
    resolution: str
    assignee_id: str | None = None
