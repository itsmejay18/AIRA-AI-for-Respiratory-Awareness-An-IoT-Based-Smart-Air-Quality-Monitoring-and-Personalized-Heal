from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, Field


ConnectionState = Literal["online", "warning", "offline"]
StressLevel = Literal["healthy", "warning", "critical"]


class ConnectivityPayload(BaseModel):
    connection_state: ConnectionState = "online"
    signal_strength: int = Field(default=100, ge=0, le=100)
    battery_level: int = Field(default=100, ge=0, le=100)
    pending_sync: bool = False


class EnvironmentPayload(BaseModel):
    soil_moisture: float = Field(ge=0, le=100)
    temperature: float = Field(ge=-30, le=90)
    humidity: float = Field(ge=0, le=100)


class ActuatorPayload(BaseModel):
    pump_online: bool = True
    relay_state: str = "off"
    last_action: str = "heartbeat"


class OptionalPayload(BaseModel):
    gas_ppm: float | None = None
    crop_type: str | None = None
    growth_stage: str | None = None


class SensorIngestRequest(BaseModel):
    device_id: str
    zone_id: str
    device_name: str
    timestamp: datetime
    firmware_version: str = "1.0.0"
    connectivity: ConnectivityPayload
    environment: EnvironmentPayload
    actuators: ActuatorPayload
    optional: OptionalPayload | None = None


class ActuateRequest(BaseModel):
    zone_id: str
    action: str


class PredictionResponse(BaseModel):
    zone_id: str
    stress_probability: float = Field(ge=0, le=1)
    stress_level: StressLevel
    forecast_hours: int
    summary: str
    created_at: datetime


class ActionResponse(BaseModel):
    id: str
    zone_id: str
    action_type: str
    status: str
    created_at: datetime
    notes: str


class AlertResponse(BaseModel):
    id: str
    zone_id: str
    title: str
    message: str
    type: str
    is_read: bool
    created_at: datetime


class IngestResponse(BaseModel):
    zone_id: str
    device_id: str
    sensor_record_id: str
    prediction: PredictionResponse
    alert_created: bool
    processed_at: datetime = Field(
        default_factory=lambda: datetime.now(timezone.utc),
    )
