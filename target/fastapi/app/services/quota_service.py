from app.core.cli import run_cli
from app.core.config import Settings
from app.services import db_reader


def get_quota(settings: Settings, email: str) -> str | None:
    return db_reader.get_quota(settings.database_quotas, email)


def set_quota(email: str, quota: str) -> None:
    run_cli("setquota", email, quota)


def delete_quota(email: str) -> None:
    run_cli("delquota", email)
