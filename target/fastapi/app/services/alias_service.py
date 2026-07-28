from app.core.cli import run_cli
from app.core.config import Settings
from app.models.alias import AliasRead
from app.services import db_reader


def list_aliases(settings: Settings) -> list[AliasRead]:
    return db_reader.list_aliases(settings.database_virtual)


def create_alias(alias: str, recipient: str) -> None:
    run_cli("addalias", alias, recipient)


def delete_alias(alias: str, recipient: str) -> None:
    run_cli("delalias", alias, recipient)
