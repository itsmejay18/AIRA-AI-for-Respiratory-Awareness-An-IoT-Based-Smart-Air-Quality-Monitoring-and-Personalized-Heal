from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


ROOT_ENV_PATH = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(ROOT_ENV_PATH)


@dataclass(frozen=True)
class Settings:
    supabase_url: str
    supabase_service_role_key: str
    api_host: str
    api_port: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            supabase_url=os.getenv("SUPABASE_URL", "").strip(),
            supabase_service_role_key=os.getenv(
                "SUPABASE_SERVICE_ROLE_KEY",
                "",
            ).strip(),
            api_host=os.getenv("BACKEND_HOST", "0.0.0.0").strip(),
            api_port=int(os.getenv("BACKEND_PORT", "8000")),
        )

    def validate(self) -> None:
        missing = []
        if not self.supabase_url:
            missing.append("SUPABASE_URL")
        if not self.supabase_service_role_key:
            missing.append("SUPABASE_SERVICE_ROLE_KEY")

        if missing:
            joined = ", ".join(missing)
            raise RuntimeError(
                f"Missing backend environment variables: {joined}. "
                "Set them in the project .env before starting FastAPI."
            )
