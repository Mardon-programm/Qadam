"""Geocoding and map configuration endpoints.

Thin proxy in front of OpenStreetMap Nominatim so the mobile app does not send
its own user agent, and so results can be cached and rate-limited server-side.
"""

import asyncio
import time
from typing import Any

import httpx
from fastapi import APIRouter, Query

from app.core.config import get_settings

router = APIRouter(prefix="/geo", tags=["geo"])

_client: httpx.AsyncClient | None = None
_cache: dict[str, tuple[float, Any]] = {}
_lock = asyncio.Lock()
_last_call = 0.0
_CACHE_TTL = 3600.0


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        settings = get_settings()
        _client = httpx.AsyncClient(
            timeout=8.0,
            headers={
                "User-Agent": f"Qadam/1.0 ({settings.geocoder_contact})",
                "Accept-Language": "ru,ky,en",
            },
        )
    return _client


async def _nominatim(path: str, params: dict[str, Any], key: str) -> Any:
    cached = _cache.get(key)
    now = time.monotonic()
    if cached and now - cached[0] < _CACHE_TTL:
        return cached[1]

    # Nominatim asks for at most one request per second.
    global _last_call
    async with _lock:
        wait = 1.0 - (time.monotonic() - _last_call)
        if wait > 0:
            await asyncio.sleep(wait)
        _last_call = time.monotonic()
        response = await _get_client().get(
            f"{get_settings().geocoder_url.rstrip('/')}{path}",
            params=params,
        )
        response.raise_for_status()
        data = response.json()

    _cache[key] = (time.monotonic(), data)
    if len(_cache) > 500:
        _cache.clear()
    return data


def _place(item: dict[str, Any]) -> dict[str, Any]:
    display = item.get("display_name") or ""
    parts = [p.strip() for p in display.split(",")]
    name = parts[0] if parts else display
    address = ", ".join(parts[1:4]) if len(parts) > 1 else ""
    return {
        "name": name,
        "address": address,
        "full_address": display,
        "lat": float(item["lat"]),
        "lng": float(item["lon"]),
    }


@router.get("/search")
async def search_places(
    q: str = Query(min_length=2, max_length=160),
    lat: float | None = None,
    lng: float | None = None,
    limit: int = Query(default=6, ge=1, le=10),
) -> dict[str, Any]:
    params: dict[str, Any] = {
        "q": q,
        "format": "jsonv2",
        "limit": limit,
        "addressdetails": 0,
        "accept-language": "ru,ky,en",
    }
    if lat is not None and lng is not None:
        # Prefer results around the passenger, without hiding the rest.
        params["viewbox"] = f"{lng - 0.6},{lat + 0.45},{lng + 0.6},{lat - 0.45}"
        params["bounded"] = 0

    key = f"s:{q.lower()}:{round(lat or 0, 2)}:{round(lng or 0, 2)}:{limit}"
    try:
        data = await _nominatim("/search", params, key)
    except httpx.HTTPError:
        return {"items": []}
    return {"items": [_place(item) for item in data if item.get("lat")]}


@router.get("/reverse")
async def reverse_place(
    lat: float,
    lng: float,
) -> dict[str, Any]:
    key = f"r:{lat:.5f}:{lng:.5f}"
    try:
        data = await _nominatim(
            "/reverse",
            {
                "lat": lat,
                "lon": lng,
                "format": "jsonv2",
                "addressdetails": 0,
                "accept-language": "ru,ky,en",
            },
            key,
        )
    except httpx.HTTPError:
        return {"place": None}
    if not data or not data.get("display_name"):
        return {"place": None}
    return {"place": _place(data)}


@router.get("/route")
async def road_route(
    from_lat: float,
    from_lng: float,
    to_lat: float,
    to_lng: float,
) -> dict[str, Any]:
    """Road-following geometry for the driver's approach to a pickup."""
    from app.core.osrm import get_osrm

    route = await get_osrm().get_route(
        start_lng=from_lng,
        start_lat=from_lat,
        end_lng=to_lng,
        end_lat=to_lat,
    )
    distance_m = float(route.get("distance") or 0)
    duration_s = float(route.get("duration") or 0)
    return {
        "distance_km": round(distance_m / 1000.0, 2),
        "duration_min": round(max(duration_s / 60.0, 1.0), 1),
        "geometry": route.get("geometry") or [],
        "source": route.get("source") or "estimate",
    }


@router.get("/map-config")
async def map_config() -> dict[str, Any]:
    settings = get_settings()
    template = settings.traffic_tile_url_template.strip()
    return {
        # Empty string means live traffic is not configured — the app hides
        # the toggle instead of showing fake jams.
        "traffic_tile_url": template or None,
        "traffic_attribution": settings.traffic_tile_attribution or None,
        "geocoding": True,
    }
