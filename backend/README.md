# Smart Farm FastAPI Backend

This backend receives IoT telemetry from ESP32 nodes, writes it into Supabase, exposes the prediction and alert endpoints the Flutter app already consumes, and records manual automation events.

## Environment

Add these values to the project `.env`:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
AI_BASE_URL=http://localhost:8000
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
```

`SUPABASE_SERVICE_ROLE_KEY` is required for backend inserts and updates.

## Run

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r backend\requirements.txt
uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints

- `GET /health`
- `POST /sensor-data`
- `GET /prediction/{zone_id}`
- `POST /actuate`
- `GET /alerts`

## Behavior

- Upserts IoT device heartbeat into `iot_devices`
- Writes sensor telemetry into `sensor_data`
- Writes a fresh prediction into `predictions`
- Updates the latest zone snapshot in `zones`
- Generates alerts for stress, anomalies, and connectivity issues
- Records manual automation actions into `actions`
