from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from .config import Settings
from .models import (
    ActuateRequest,
    ActionResponse,
    AlertResponse,
    IngestResponse,
    PredictionResponse,
    SensorIngestRequest,
)
from .services import FarmBackendService


settings = Settings.from_env()
service: FarmBackendService | None = None


@asynccontextmanager
async def lifespan(_: FastAPI):
    global service
    service = FarmBackendService.from_settings(settings)
    yield


app = FastAPI(
    title="Smart Farm IoT Backend",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _service() -> FarmBackendService:
    if service is None:
        raise HTTPException(
            status_code=503,
            detail="Backend service is not initialized.",
        )
    return service


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/sensor-data", response_model=IngestResponse)
def post_sensor_data(payload: SensorIngestRequest) -> IngestResponse:
    try:
        return _service().ingest_sensor_payload(payload)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except Exception as error:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(error)) from error


@app.get("/prediction/{zone_id}", response_model=PredictionResponse)
def get_prediction(zone_id: str) -> PredictionResponse:
    try:
        return _service().get_prediction(zone_id)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except Exception as error:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(error)) from error


@app.post("/actuate", response_model=ActionResponse)
def actuate(payload: ActuateRequest) -> ActionResponse:
    try:
        return _service().actuate(payload.zone_id, payload.action)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except Exception as error:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(error)) from error


@app.get("/alerts", response_model=list[AlertResponse])
def alerts() -> list[AlertResponse]:
    try:
        return _service().fetch_alerts()
    except Exception as error:  # pragma: no cover
        raise HTTPException(status_code=500, detail=str(error)) from error
