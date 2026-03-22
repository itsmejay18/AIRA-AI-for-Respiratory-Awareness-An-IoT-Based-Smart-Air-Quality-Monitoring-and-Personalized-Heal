from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from supabase import Client, create_client

from .config import Settings
from .models import (
    ActionResponse,
    AlertResponse,
    IngestResponse,
    PredictionResponse,
    SensorIngestRequest,
)


def _to_iso(value: datetime) -> str:
    return value.astimezone(UTC).isoformat()


def _build_sensor_id(zone_id: str, timestamp: datetime) -> str:
    return f"{zone_id}-{timestamp.astimezone(UTC).strftime('%Y%m%d%H%M%S')}"


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _derive_stress_probability(
    soil_moisture: float,
    temperature: float,
    humidity: float,
) -> float:
    moisture_risk = _clamp((55 - soil_moisture) / 35, 0, 1)
    temperature_risk = _clamp((temperature - 28) / 10, 0, 1)
    humidity_risk = _clamp((50 - humidity) / 30, 0, 1)
    probability = (moisture_risk * 0.55) + (temperature_risk * 0.3) + (
        humidity_risk * 0.15
    )
    return round(_clamp(probability, 0, 1), 4)


def _derive_stress_level(probability: float) -> str:
    if probability >= 0.7:
        return "critical"
    if probability >= 0.4:
        return "warning"
    return "healthy"


def _translator_message(
    stress_level: str,
    probability: float,
    forecast_hours: int,
    soil_moisture: float,
    temperature: float,
) -> str:
    if stress_level == "critical":
        return (
            f"High risk of drought stress in {forecast_hours} hours due to "
            f"soil moisture at {soil_moisture:.1f}% and temperature at "
            f"{temperature:.1f}C."
        )
    if stress_level == "warning":
        return (
            f"Soil moisture is trending down. Watch this zone over the next "
            f"{forecast_hours} hours."
        )
    return (
        f"Your plant is healthy. Estimated stress probability is "
        f"{probability * 100:.0f}%."
    )


def _select_rows(response: Any) -> list[dict[str, Any]]:
    data = getattr(response, "data", None)
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return [data]
    return []


@dataclass
class FarmBackendService:
    client: Client

    @classmethod
    def from_settings(cls, settings: Settings) -> "FarmBackendService":
        settings.validate()
        client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
        )
        return cls(client=client)

    def _fetch_zone(self, zone_id: str) -> dict[str, Any] | None:
        response = (
            self.client.table("zones")
            .select("*")
            .eq("id", zone_id)
            .limit(1)
            .execute()
        )
        rows = _select_rows(response)
        return rows[0] if rows else None

    def _latest_sensor_point(self, zone_id: str) -> dict[str, Any] | None:
        response = (
            self.client.table("sensor_data")
            .select("*")
            .eq("zone_id", zone_id)
            .order("recorded_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = _select_rows(response)
        return rows[0] if rows else None

    def ingest_sensor_payload(self, payload: SensorIngestRequest) -> IngestResponse:
        zone = self._fetch_zone(payload.zone_id)
        if zone is None:
            raise ValueError(
                f"Zone '{payload.zone_id}' was not found in Supabase."
            )

        previous = self._latest_sensor_point(payload.zone_id)
        sensor_record_id = _build_sensor_id(payload.zone_id, payload.timestamp)
        probability = _derive_stress_probability(
            soil_moisture=payload.environment.soil_moisture,
            temperature=payload.environment.temperature,
            humidity=payload.environment.humidity,
        )
        stress_level = _derive_stress_level(probability)
        forecast_hours = 4 if stress_level != "healthy" else 8
        summary = _translator_message(
            stress_level=stress_level,
            probability=probability,
            forecast_hours=forecast_hours,
            soil_moisture=payload.environment.soil_moisture,
            temperature=payload.environment.temperature,
        )

        self.client.table("iot_devices").upsert(
            {
                "id": payload.device_id,
                "zone_id": payload.zone_id,
                "name": payload.device_name,
                "connection_state": payload.connectivity.connection_state,
                "last_seen": _to_iso(payload.timestamp),
                "battery_level": payload.connectivity.battery_level,
                "signal_strength": payload.connectivity.signal_strength,
                "firmware_version": payload.firmware_version,
                "pump_online": payload.actuators.pump_online,
                "pending_sync": payload.connectivity.pending_sync,
            }
        ).execute()

        self.client.table("sensor_data").upsert(
            {
                "id": sensor_record_id,
                "zone_id": payload.zone_id,
                "soil_moisture": payload.environment.soil_moisture,
                "temperature": payload.environment.temperature,
                "humidity": payload.environment.humidity,
                "recorded_at": _to_iso(payload.timestamp),
            }
        ).execute()

        self.client.table("predictions").insert(
            {
                "zone_id": payload.zone_id,
                "stress_probability": probability,
                "stress_level": stress_level,
                "forecast_hours": forecast_hours,
                "summary": summary,
            }
        ).execute()

        self.client.table("zones").update(
            {
                "soil_moisture": payload.environment.soil_moisture,
                "temperature": payload.environment.temperature,
                "humidity": payload.environment.humidity,
                "current_stress": stress_level,
                "predicted_stress": stress_level,
            }
        ).eq("id", payload.zone_id).execute()

        moisture_drop = 0.0
        if previous is not None:
            previous_moisture = float(previous.get("soil_moisture") or 0)
            moisture_drop = previous_moisture - payload.environment.soil_moisture

        alert_created = (
            stress_level != "healthy"
            or moisture_drop >= 12
            or payload.connectivity.connection_state != "online"
        )

        if alert_created:
            alert_type = "prediction"
            title = "Stress Warning"
            message = summary
            if moisture_drop >= 12:
                alert_type = "anomaly"
                title = "Anomaly Detected"
                message = (
                    "Sudden soil moisture drop detected. Check the irrigation "
                    "line and sensor placement."
                )
            elif payload.connectivity.connection_state != "online":
                alert_type = "device"
                title = "Device Connectivity Issue"
                message = (
                    f"{payload.device_name} reported "
                    f"{payload.connectivity.connection_state} connectivity."
                )

            self.client.table("alerts").upsert(
                {
                    "id": f"alert-{payload.zone_id}-{payload.timestamp.astimezone(UTC).strftime('%Y%m%d%H%M%S')}",
                    "zone_id": payload.zone_id,
                    "title": title,
                    "message": message,
                    "type": alert_type,
                    "is_read": False,
                    "created_at": _to_iso(payload.timestamp),
                }
            ).execute()

        prediction = PredictionResponse(
            zone_id=payload.zone_id,
            stress_probability=probability,
            stress_level=stress_level,
            forecast_hours=forecast_hours,
            summary=summary,
            created_at=payload.timestamp.astimezone(UTC),
        )
        return IngestResponse(
            zone_id=payload.zone_id,
            device_id=payload.device_id,
            sensor_record_id=sensor_record_id,
            prediction=prediction,
            alert_created=alert_created,
        )

    def get_prediction(self, zone_id: str) -> PredictionResponse:
        response = (
            self.client.table("predictions")
            .select("*")
            .eq("zone_id", zone_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        rows = _select_rows(response)
        if not rows:
            zone = self._fetch_zone(zone_id)
            if zone is None:
                raise ValueError(f"Zone '{zone_id}' was not found in Supabase.")

            probability = _derive_stress_probability(
                soil_moisture=float(zone["soil_moisture"]),
                temperature=float(zone["temperature"]),
                humidity=float(zone["humidity"]),
            )
            stress_level = _derive_stress_level(probability)
            return PredictionResponse(
                zone_id=zone_id,
                stress_probability=probability,
                stress_level=stress_level,
                forecast_hours=4 if stress_level != "healthy" else 8,
                summary=_translator_message(
                    stress_level=stress_level,
                    probability=probability,
                    forecast_hours=4 if stress_level != "healthy" else 8,
                    soil_moisture=float(zone["soil_moisture"]),
                    temperature=float(zone["temperature"]),
                ),
                created_at=datetime.now(UTC),
            )

        latest = rows[0]
        return PredictionResponse(
            zone_id=str(latest["zone_id"]),
            stress_probability=float(latest["stress_probability"]),
            stress_level=str(latest["stress_level"]),
            forecast_hours=int(latest["forecast_hours"]),
            summary=str(latest["summary"]),
            created_at=datetime.fromisoformat(
                str(latest["created_at"]).replace("Z", "+00:00")
            ),
        )

    def actuate(self, zone_id: str, action: str) -> ActionResponse:
        zone = self._fetch_zone(zone_id)
        if zone is None:
            raise ValueError(f"Zone '{zone_id}' was not found in Supabase.")

        now = datetime.now(UTC)
        action_row = {
            "id": f"action-{uuid4().hex[:12]}",
            "zone_id": zone_id,
            "action_type": action,
            "status": "completed",
            "notes": f"{action.replace('_', ' ').title()} executed by backend.",
            "created_at": _to_iso(now),
        }
        self.client.table("actions").insert(action_row).execute()

        self.client.table("alerts").upsert(
            {
                "id": f"alert-{uuid4().hex[:12]}",
                "zone_id": zone_id,
                "title": "Irrigation Triggered",
                "message": f"{action.replace('_', ' ').title()} executed for {zone['name']}.",
                "type": "action",
                "is_read": False,
                "created_at": _to_iso(now),
            }
        ).execute()

        self.client.table("iot_devices").update(
            {
                "pump_online": action in {"manual_irrigation", "auto_irrigation"},
                "pending_sync": False,
            }
        ).eq("zone_id", zone_id).execute()

        return ActionResponse(**action_row)

    def fetch_alerts(self) -> list[AlertResponse]:
        response = (
            self.client.table("alerts")
            .select("*")
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
        rows = _select_rows(response)
        alerts: list[AlertResponse] = []
        for row in rows:
            alerts.append(
                AlertResponse(
                    id=str(row["id"]),
                    zone_id=str(row["zone_id"]),
                    title=str(row["title"]),
                    message=str(row["message"]),
                    type=str(row["type"]),
                    is_read=bool(row["is_read"]),
                    created_at=datetime.fromisoformat(
                        str(row["created_at"]).replace("Z", "+00:00")
                    ),
                )
            )
        return alerts
