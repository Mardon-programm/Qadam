"""initial schema — all tables

Revision ID: 0001_initial
Revises:
Create Date: 2026-10-24 00:01:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── identity ──────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("full_name", sa.String(255)),
        sa.Column("locale", sa.String(8), nullable=False, server_default="ru"),
        sa.Column("role", sa.String(32), nullable=False, server_default="passenger"),
        sa.Column("status", sa.String(32), nullable=False, server_default="active"),
        sa.Column("is_phone_verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("last_login_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("phone", name="uq_users_phone"),
    )
    op.create_index("ix_users_status", "users", ["status"])

    op.create_table(
        "refresh_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("jti", sa.String(64), nullable=False, unique=True),
        sa.Column("revoked", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("user_agent", sa.Text()),
        sa.Column("ip_address", sa.String(64)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_refresh_sessions_user", "refresh_sessions", ["user_id"])

    op.create_table(
        "audit_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("actor_id", sa.String(36)),
        sa.Column("actor_role", sa.String(32)),
        sa.Column("action", sa.String(128), nullable=False),
        sa.Column("object_type", sa.String(64), nullable=False),
        sa.Column("object_id", sa.String(64)),
        sa.Column("meta_json", sa.Text()),
        sa.Column("ip_address", sa.String(64)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_audit_actor", "audit_events", ["actor_id"])
    op.create_index("ix_audit_object", "audit_events", ["object_type", "object_id"])

    # ── trust ─────────────────────────────────────────────────────────────────
    op.create_table(
        "driver_profiles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("verification_status", sa.String(32), nullable=False, server_default="draft"),
        sa.Column("online_status", sa.String(32), nullable=False, server_default="offline"),
        sa.Column("rating", sa.Numeric(3, 2), server_default="5.00"),
        sa.Column("rating_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("reliability_score", sa.Numeric(5, 2), server_default="100.00"),
        sa.Column("active_vehicle_id", sa.String(36)),
        sa.Column("last_lat", sa.Numeric(10, 7)),
        sa.Column("last_lng", sa.Numeric(10, 7)),
        sa.Column("last_location_at", sa.DateTime(timezone=True)),
        sa.Column("can_accept_corporate", sa.Boolean(), server_default="false"),
        sa.Column("blocked_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", name="uq_driver_profiles_user"),
    )
    op.create_index("ix_driver_online", "driver_profiles", ["online_status"])
    op.create_index("ix_driver_verification", "driver_profiles", ["verification_status"])

    op.create_table(
        "vehicles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("driver_profiles.id"), nullable=False),
        sa.Column("make", sa.String(64), nullable=False),
        sa.Column("model", sa.String(64), nullable=False),
        sa.Column("color", sa.String(32)),
        sa.Column("plate_number", sa.String(32), nullable=False),
        sa.Column("year", sa.Integer()),
        sa.Column("seats", sa.Integer(), nullable=False, server_default="4"),
        sa.Column("vehicle_class", sa.String(32), server_default="economy"),
        sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("plate_number", name="uq_vehicles_plate"),
    )
    op.create_index("ix_vehicles_driver", "vehicles", ["driver_id"])

    op.create_table(
        "driver_documents",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("driver_profiles.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(36), sa.ForeignKey("vehicles.id")),
        sa.Column("doc_type", sa.String(64), nullable=False),
        sa.Column("document_number", sa.String(128)),
        sa.Column("storage_url", sa.Text()),
        sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
        sa.Column("expires_on", sa.Date()),
        sa.Column("reviewed_by", sa.String(36)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("rejection_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_docs_driver", "driver_documents", ["driver_id"])
    op.create_index("ix_docs_expires", "driver_documents", ["expires_on"])

    # ── city ──────────────────────────────────────────────────────────────────
    op.create_table(
        "ride_orders",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("passenger_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("driver_profiles.id")),
        sa.Column("vehicle_id", sa.String(36), sa.ForeignKey("vehicles.id")),
        sa.Column("status", sa.String(32), nullable=False, server_default="created"),
        sa.Column("city", sa.String(64), nullable=False, server_default="bishkek"),
        sa.Column("pickup_address", sa.Text(), nullable=False),
        sa.Column("pickup_lat", sa.Numeric(10, 7), nullable=False),
        sa.Column("pickup_lng", sa.Numeric(10, 7), nullable=False),
        sa.Column("dropoff_address", sa.Text(), nullable=False),
        sa.Column("dropoff_lat", sa.Numeric(10, 7), nullable=False),
        sa.Column("dropoff_lng", sa.Numeric(10, 7), nullable=False),
        sa.Column("distance_km", sa.Numeric(10, 3)),
        sa.Column("duration_min", sa.Numeric(10, 2)),
        sa.Column("eta_min", sa.Integer()),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("quoted_price", sa.Numeric(12, 2)),
        sa.Column("final_price", sa.Numeric(12, 2)),
        sa.Column("surge_multiplier", sa.Numeric(4, 2), nullable=False, server_default="1.00"),
        sa.Column("driver_net_estimate", sa.Numeric(12, 2)),
        sa.Column("platform_fee_estimate", sa.Numeric(12, 2)),
        sa.Column("assigned_at", sa.DateTime(timezone=True)),
        sa.Column("started_at", sa.DateTime(timezone=True)),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("cancelled_at", sa.DateTime(timezone=True)),
        sa.Column("cancel_reason", sa.Text()),
        sa.Column("cancelled_by", sa.String(32)),
        sa.Column("ledger_posted", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("idempotency_key", sa.String(128), unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_ride_status", "ride_orders", ["status"])
    op.create_index("ix_ride_passenger", "ride_orders", ["passenger_id"])
    op.create_index("ix_ride_driver", "ride_orders", ["driver_id"])

    op.create_table(
        "ride_offers",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("ride_order_id", sa.String(36), sa.ForeignKey("ride_orders.id"), nullable=False),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("driver_profiles.id"), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="offered"),
        sa.Column("eta_min", sa.Integer()),
        sa.Column("net_estimate", sa.Numeric(12, 2)),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("ride_order_id", "driver_id", name="uq_offer_ride_driver"),
    )
    op.create_index("ix_offers_status", "ride_offers", ["status"])

    # ── region ────────────────────────────────────────────────────────────────
    op.create_table(
        "intercity_trips",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("driver_id", sa.String(36), sa.ForeignKey("driver_profiles.id"), nullable=False),
        sa.Column("vehicle_id", sa.String(36), sa.ForeignKey("vehicles.id"), nullable=False),
        sa.Column("origin_city", sa.String(64), nullable=False),
        sa.Column("destination_city", sa.String(64), nullable=False),
        sa.Column("depart_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("price_per_seat", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("seat_count", sa.Integer(), nullable=False),
        sa.Column("baggage_note", sa.Text()),
        sa.Column("meeting_point", sa.Text()),
        sa.Column("status", sa.String(32), nullable=False, server_default="scheduled"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(
        "ix_intercity_route_date",
        "intercity_trips",
        ["origin_city", "destination_city", "depart_at"],
    )

    op.create_table(
        "trip_seats",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("trip_id", sa.String(36), sa.ForeignKey("intercity_trips.id"), nullable=False),
        sa.Column("seat_code", sa.String(16), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="available"),
        sa.Column("held_until", sa.DateTime(timezone=True)),
        sa.Column("booking_id", sa.String(36)),
        sa.Column("version", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("trip_id", "seat_code", name="uq_trip_seat_code"),
    )
    op.create_index("ix_trip_seats_status", "trip_seats", ["trip_id", "status"])

    op.create_table(
        "bookings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("passenger_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("trip_id", sa.String(36), sa.ForeignKey("intercity_trips.id"), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="held"),
        sa.Column("seat_codes", sa.Text(), nullable=False),
        sa.Column("passenger_count", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("baggage_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_price", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("payment_id", sa.String(36)),
        sa.Column("held_until", sa.DateTime(timezone=True)),
        sa.Column("idempotency_key", sa.String(128)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("idempotency_key", name="uq_booking_idempotency"),
    )
    op.create_index("ix_bookings_passenger", "bookings", ["passenger_id"])

    # ── payments ──────────────────────────────────────────────────────────────
    op.create_table(
        "payments",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("external_id", sa.String(128)),
        sa.Column("status", sa.String(32), nullable=False, server_default="created"),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("payer_user_id", sa.String(36)),
        sa.Column("reference_type", sa.String(64), nullable=False),
        sa.Column("reference_id", sa.String(36), nullable=False),
        sa.Column("idempotency_key", sa.String(128), nullable=False),
        sa.Column("raw_payload", sa.Text()),
        sa.Column("failure_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("idempotency_key", name="uq_payments_idempotency"),
        sa.UniqueConstraint("provider", "external_id", name="uq_payments_provider_ext"),
    )
    op.create_index("ix_payments_status", "payments", ["status"])
    op.create_index("ix_payments_ref", "payments", ["reference_type", "reference_id"])

    op.create_table(
        "payment_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("payment_id", sa.String(36)),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("event_id", sa.String(128), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("processed", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("payload", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("provider", "event_id", name="uq_payment_event"),
    )

    # ── ledger ────────────────────────────────────────────────────────────────
    op.create_table(
        "ledger_entries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("account_id", sa.String(64), nullable=False),
        sa.Column("account_owner_type", sa.String(32), nullable=False),
        sa.Column("account_owner_id", sa.String(36), nullable=False),
        sa.Column("direction", sa.String(16), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("entry_type", sa.String(64), nullable=False),
        sa.Column("reference_type", sa.String(64), nullable=False),
        sa.Column("reference_id", sa.String(36), nullable=False),
        sa.Column("idempotency_key", sa.String(128), nullable=False),
        sa.Column("description", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("idempotency_key", name="uq_ledger_idempotency"),
    )
    op.create_index("ix_ledger_account", "ledger_entries", ["account_id"])
    op.create_index("ix_ledger_ref", "ledger_entries", ["reference_type", "reference_id"])

    op.create_table(
        "payouts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("driver_id", sa.String(36), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
        sa.Column("provider_ref", sa.String(128)),
        sa.Column("failure_reason", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_payouts_driver", "payouts", ["driver_id"])

    # ── subscriptions ─────────────────────────────────────────────────────────
    op.create_table(
        "subscriptions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("driver_id", sa.String(36), nullable=False),
        sa.Column("plan", sa.String(32), nullable=False, server_default="flex"),
        sa.Column("status", sa.String(32), nullable=False, server_default="active"),
        sa.Column("price", sa.Numeric(12, 2), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True)),
        sa.Column("paused_at", sa.DateTime(timezone=True)),
        sa.Column("pause_reason", sa.String(255)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_subscriptions_driver", "subscriptions", ["driver_id", "status"])

    # ── support ───────────────────────────────────────────────────────────────
    op.create_table(
        "support_cases",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("case_type", sa.String(64), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="open"),
        sa.Column("subject", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("reference_type", sa.String(64)),
        sa.Column("reference_id", sa.String(36)),
        sa.Column("assignee_id", sa.String(36)),
        sa.Column("resolution", sa.Text()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_support_status", "support_cases", ["status"])
    op.create_index("ix_support_user", "support_cases", ["user_id"])

    # ── corporate ─────────────────────────────────────────────────────────────
    op.create_table(
        "corporate_accounts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("legal_name", sa.String(255), nullable=False),
        sa.Column("tax_id", sa.String(64)),
        sa.Column("status", sa.String(32), nullable=False, server_default="active"),
        sa.Column("monthly_budget", sa.Numeric(14, 2)),
        sa.Column("currency", sa.String(8), nullable=False, server_default="KGS"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("legal_name", name="uq_corporate_legal_name"),
    )

    op.create_table(
        "corporate_members",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("account_id", sa.String(36), nullable=False),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("member_role", sa.String(32), nullable=False, server_default="employee"),
        sa.Column("trip_limit", sa.Numeric(12, 2)),
        sa.Column("status", sa.String(32), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("account_id", "user_id", name="uq_corporate_member"),
    )


def downgrade() -> None:
    # Drop in reverse dependency order
    op.drop_table("corporate_members")
    op.drop_table("corporate_accounts")
    op.drop_table("support_cases")
    op.drop_table("subscriptions")
    op.drop_table("payouts")
    op.drop_table("ledger_entries")
    op.drop_table("payment_events")
    op.drop_table("payments")
    op.drop_table("bookings")
    op.drop_table("trip_seats")
    op.drop_table("intercity_trips")
    op.drop_table("ride_offers")
    op.drop_table("ride_orders")
    op.drop_table("driver_documents")
    op.drop_table("vehicles")
    op.drop_table("driver_profiles")
    op.drop_table("audit_events")
    op.drop_table("refresh_sessions")
    op.drop_table("users")
