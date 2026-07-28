from app.core.cli import run_cli
from app.core.config import Settings
from app.models.master_user import MasterUserRead
from app.services import db_reader


def list_master_users(settings: Settings) -> list[MasterUserRead]:
    return db_reader.list_master_users(settings.database_dovecot_masters)


def create_master_user(username: str, password: str) -> None:
    run_cli("adddovecotmasteruser", username, password)


def update_master_user(username: str, password: str) -> None:
    run_cli("updatedovecotmasteruser", username, password)


def delete_master_user(username: str) -> None:
    run_cli("deldovecotmasteruser", username)
