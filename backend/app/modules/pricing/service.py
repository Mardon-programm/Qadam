from decimal import ROUND_HALF_UP, Decimal
from math import asin, cos, radians, sin, sqrt

from app.core.config import get_settings
from app.core.osrm import get_osrm


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Approximate road distance fallback until OSRM is wired."""
    r = 6371.0
    dlat = radians(lat2 - lat1)
    dlng = radians(lng2 - lng1)
    a = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlng / 2) ** 2
    return 2 * r * asin(sqrt(a))


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def quote_city_fare(
    *,
    distance_km: float,
    duration_min: float,
    surge: float = 1.0,
) -> dict[str, Decimal]:
    """
    P = P_base + D * R + T * C, then apply surge (capped) and minimum fare.
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
) -> tuple[float, float]:
    """
    Returns (distance_km, duration_min).
    Uses OSRM for routing, falls back to Haversine if unavailable.
    """
    try:
        osrm = get_osrm()
        route = await osrm.get_route(
            start_lng=pickup_lng,
            start_lat=pickup_lat,
            end_lng=dropoff_lng,
            end_lat=dropoff_lat,
        )

        if route.get("error"):
            # OSRM failed, use fallback
            raise Exception("OSRM unavailable")

        distance_km = route["distance"] / 1000.0  # meters to km
        duration_min = route["duration"] / 60.0  # seconds to minutes
        return distance_km, max(duration_min, 5.0)

    except Exception:
        # Fallback to Haversine estimation
        straight = haversine_km(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)
        distance = straight * 1.3
        duration = (distance / 25.0) * 60.0 if distance > 0 else 5.0
        return distance, max(duration, 5.0)
