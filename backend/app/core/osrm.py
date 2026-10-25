"""OSRM routing client for distance and ETA calculations."""

from typing import Any

import httpx

from app.core.config import get_settings


class OSRMClient:
    """Client for OSRM routing service."""

    def __init__(self):
        settings = get_settings()
        # Default to local OSRM instance or use configured endpoint
        self.base_url = getattr(settings, "osrm_url", "http://localhost:5000")
        self.client = httpx.AsyncClient(timeout=10.0)

    async def close(self):
        """Close HTTP client."""
        await self.client.aclose()

    async def get_route(
        self,
        start_lng: float,
        start_lat: float,
        end_lng: float,
        end_lat: float,
        alternatives: bool = False,
    ) -> dict[str, Any]:
        """
        Get route between two points.

        Returns:
            {
                "distance": float (meters),
                "duration": float (seconds),
                "geometry": str (encoded polyline),
            }
        """
        coords = f"{start_lng},{start_lat};{end_lng},{end_lat}"
        params = {
            "alternatives": "true" if alternatives else "false",
            "steps": "false",
            "geometries": "polyline",
            "overview": "full",
        }

        url = f"{self.base_url}/route/v1/driving/{coords}"

        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            if data.get("code") != "Ok" or not data.get("routes"):
                return {
                    "distance": 0.0,
                    "duration": 0.0,
                    "geometry": "",
                    "error": data.get("message", "No route found"),
                }

            route = data["routes"][0]
            return {
                "distance": route["distance"],  # meters
                "duration": route["duration"],  # seconds
                "geometry": route["geometry"],
            }

        except httpx.HTTPError as e:
            # Fallback to straight-line estimation
            return await self._fallback_estimate(start_lat, start_lng, end_lat, end_lng)

    async def get_distance_matrix(
        self,
        sources: list[tuple[float, float]],  # [(lng, lat), ...]
        destinations: list[tuple[float, float]],
    ) -> dict[str, Any]:
        """
        Get distance matrix between multiple sources and destinations.

        Returns:
            {
                "distances": list[list[float]],  # meters
                "durations": list[list[float]],  # seconds
            }
        """
        coords = ";".join([f"{lng},{lat}" for lng, lat in sources + destinations])
        sources_idx = ";".join([str(i) for i in range(len(sources))])
        dests_idx = ";".join([str(i) for i in range(len(sources), len(sources) + len(destinations))])

        url = f"{self.base_url}/table/v1/driving/{coords}"
        params = {
            "sources": sources_idx,
            "destinations": dests_idx,
        }

        try:
            response = await self.client.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            if data.get("code") != "Ok":
                return {"distances": [], "durations": [], "error": data.get("message")}

            return {
                "distances": data.get("distances", []),
                "durations": data.get("durations", []),
            }

        except httpx.HTTPError:
            return {"distances": [], "durations": [], "error": "OSRM service unavailable"}

    async def _fallback_estimate(
        self,
        lat1: float,
        lng1: float,
        lat2: float,
        lng2: float,
    ) -> dict[str, Any]:
        """
        Fallback estimation using Haversine formula.
        Provides straight-line distance with road factor multiplier.
        """
        from math import asin, cos, radians, sin, sqrt

        R = 6371000  # Earth radius in meters

        lat1_rad = radians(lat1)
        lat2_rad = radians(lat2)
        delta_lat = radians(lat2 - lat1)
        delta_lng = radians(lng2 - lng1)

        a = sin(delta_lat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lng / 2) ** 2
        c = 2 * asin(sqrt(a))

        straight_distance = R * c  # meters

        # Apply road factor (roads are ~30% longer than straight line)
        road_distance = straight_distance * 1.3

        # Estimate duration assuming 40 km/h average city speed
        avg_speed_mps = 40 * 1000 / 3600  # 11.11 m/s
        duration = road_distance / avg_speed_mps

        return {
            "distance": road_distance,
            "duration": duration,
            "geometry": "",
            "fallback": True,
        }


# Global instance
_osrm_client: OSRMClient | None = None


def get_osrm() -> OSRMClient:
    """Get OSRM client singleton."""
    global _osrm_client
    if _osrm_client is None:
        _osrm_client = OSRMClient()
    return _osrm_client


async def close_osrm():
    """Close OSRM client."""
    global _osrm_client
    if _osrm_client is not None:
        await _osrm_client.close()
        _osrm_client = None
