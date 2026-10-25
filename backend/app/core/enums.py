from enum import StrEnum


class UserRole(StrEnum):
    PASSENGER = "passenger"
    DRIVER = "driver"
    OPS = "ops"
    CORPORATE = "corporate"
    SYSTEM = "system"


class UserStatus(StrEnum):
    ACTIVE = "active"
    BLOCKED = "blocked"
    DELETED = "deleted"


class VerificationStatus(StrEnum):
    DRAFT = "draft"
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    EXPIRED = "expired"


class DocumentType(StrEnum):
    DRIVER_LICENSE = "driver_license"
    VEHICLE_REGISTRATION = "vehicle_registration"
    TAXI_LICENSE = "taxi_license"
    INSURANCE = "insurance"
    PASSPORT = "passport"
    SELFIE = "selfie"


class DriverOnlineStatus(StrEnum):
    OFFLINE = "offline"
    ONLINE = "online"
    BUSY = "busy"


class RideOrderStatus(StrEnum):
    CREATED = "created"
    QUOTED = "quoted"
    SEARCHING = "searching"
    OFFERED = "offered"
    ASSIGNED = "assigned"
    DRIVER_ARRIVING = "driver_arriving"
    DRIVER_ARRIVED = "driver_arrived"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    FAILED = "failed"


class SeatStatus(StrEnum):
    AVAILABLE = "available"
    HELD = "held"
    CONFIRMED = "confirmed"
    OCCUPIED = "occupied"
    COMPLETED = "completed"


class BookingStatus(StrEnum):
    HELD = "held"
    CONFIRMED = "confirmed"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    NO_SHOW = "no_show"


class PaymentStatus(StrEnum):
    CREATED = "created"
    PENDING = "pending"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    REFUNDED = "refunded"
    PARTIALLY_REFUNDED = "partially_refunded"


class LedgerDirection(StrEnum):
    DEBIT = "debit"
    CREDIT = "credit"


class SubscriptionPlan(StrEnum):
    FLEX = "flex"
    PRO_DAILY = "pro_daily"
    PRO_MONTHLY = "pro_monthly"


class SubscriptionStatus(StrEnum):
    ACTIVE = "active"
    PAUSED = "paused"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class SupportCaseStatus(StrEnum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


class PayoutStatus(StrEnum):
    PENDING = "pending"
    PROCESSING = "processing"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
