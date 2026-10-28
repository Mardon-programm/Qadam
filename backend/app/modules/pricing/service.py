from dataclasses import dataclass, field
from decimal import ROUND_HALF_UP, Decimal
from math import asin, cos, radians, sin, sqrt

from app.core.config import get_settings
from app.core.osrm import get_osrm


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Straight-line distance in kilometres."""
    r = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 2 * r * asin(sqrt(a))


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(value, high))


@dataclass
class RouteEstimate:
    """Road route between two points plus the traffic it implies."""

    distance_km: float
    duration_min: float
    geometry: list[list[float]] = field(default_factory=list)
    source: str = "estimate"
    traffic_factor: float = 1.0

    @property
    def congestion(self) -> str:
        if self.source != "osrm":
            return "unknown"
        if self.traffic_factor < 1.08:
            return "free"
        if self.traffic_factor < 1.25:
            return "moderate"
        return "heavy"


def quote_city_fare(
    *,
    distance_km: float,
    duration_min: float,
    surge: float = 1.0,
    traffic_factor: float = 1.0,
    demand_factor: float = 1.0,
) -> dict[str, Decimal | str | list[list[float]]]:
    """
    P = (P_base + D * R + T * C) * surge, capped, with a minimum fare.

    ``surge`` is the final multiplier (traffic and demand already folded in);
    the separate factors are returned for the price breakdown in the app.
    Drivers keep the full fare (0% commission).
    """
    settings = get_settings()
    surge_c = min(max(surge, 1.0), settings.city_surge_cap)
    base = Decimal(str(settings.city_base_fare))
    distance = Decimal(str(distance_km)) * Decimal(str(settings.city_per_km))
    time_part = Decimal(str(duration_min)) * Decimal(str(settings.city_per_minute))
    raw = (base + distance + time_part) * Decimal(str(surge_c))
    price = max(raw, Decimal(str(settings.city_min_fare)))
    price = _money(price)

    commission = _money(price * Decimal(str(settings.flex_commission_rate)))
    driver_net = _money(price - commission)
    return {
        "quoted_price": price,
        "surge_multiplier": _money(Decimal(str(surge_c))),
        "traffic_multiplier": _money(Decimal(str(max(1.0, traffic_factor)))),
        "demand_multiplier": _money(Decimal(str(max(1.0, demand_factor)))),
        "platform_fee_estimate": commission,
        "driver_net_estimate": driver_net,
        "distance_km": _money(Decimal(str(distance_km))),
        "duration_min": _money(Decimal(str(duration_min))),
    }


async def estimate_route(
    pickup_lat: float,
    pickup_lng: float,
    dropoff_lat: float,
    dropoff_lng: float,
) -> RouteEstimate:
    """
    Road distance/duration/geometry via OSRM, with a Haversine fallback.

    ``traffic_factor`` compares the routed duration with free-flow driving at
    ``city_free_flow_kmh``; it is only meaningful for real OSRM routes.
    """
    settings = get_settings()
    try:
        osrm = get_osrm()
        route = await osrm.get_route(
            start_lng=pickup_lng,
            start_lat=pickup_lat,
            end_lng=dropoff_lng,
            end_lat=dropoff_lat,
        )

        distance_km = float(route["distance"]) / 1000.0
        duration_min = float(route["duration"]) / 60.0
        source = str(route.get("source") or ("estimate" if route.get("fallback") else "osrm"))

        if distance_km <= 0 or duration_min <= 0:
            raise ValueError("Empty route")

        free_flow_min = distance_km / max(settings.city_free_flow_kmh, 5.0) * 60.0
        traffic_factor = (
            _clamp(duration_min / free_flow_min, 1.0, 1.6)
            if source == "osrm" and free_flow_min > 0
            else 1.0
        )

        return RouteEstimate(
            distance_km=distance_km,
            duration_min=max(duration_min, 3.0),
            geometry=route.get("geometry") or [],
            source=source,
            traffic_factor=traffic_factor,
        )

    except Exception:
        straight = haversine_km(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        distance = straight * 1.3
        duration = (distance / 25.0) * 60.0 if distance > 0 else 5.0
        return RouteEstimate(
            distance_km=distance,
            duration_min=max(duration, 3.0),
            source="estimate",
        )
