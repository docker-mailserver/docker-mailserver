from app.core.cli import run_cli
from app.core.config import Settings
from app.models.relay import RelayAuthRead, RelayHostRead
from app.services import db_reader


def list_relay_hosts(settings: Settings) -> list[RelayHostRead]:
    return db_reader.list_relay_hosts(settings.database_relaymap)


def add_relay_host(domain: str, host: str, port: int) -> None:
    run_cli("addrelayhost", domain, host, str(port))


def exclude_relay_domain(domain: str) -> None:
    run_cli("excluderelaydomain", domain)


def delete_relay_host(domain: str) -> None:
    run_cli("delrelayhost", domain)


def list_relay_auth(settings: Settings) -> list[RelayAuthRead]:
    return db_reader.list_relay_auth(settings.database_sasl_password)


def add_relay_auth(domain: str, username: str, password: str) -> None:
    run_cli("addsaslpassword", domain, username, password)


def delete_relay_auth(domain: str) -> None:
    run_cli("delsaslpassword", domain)
