from app.core.cli import run_cli
from app.core.config import Settings
from app.models.mailbox import MailboxRead
from app.services import db_reader


def list_mailboxes(settings: Settings) -> list[MailboxRead]:
    return db_reader.list_mailboxes(settings.database_accounts)


def mailbox_exists(settings: Settings, email: str) -> bool:
    return db_reader.mailbox_exists(settings.database_accounts, email)


def create_mailbox(email: str, password: str) -> None:
    run_cli("addmailuser", email, password)


def update_mailbox(email: str, password: str) -> None:
    run_cli("updatemailuser", email, password)


def delete_mailbox(email: str, delete_data: bool) -> None:
    run_cli("delmailuser", "-y" if delete_data else "-n", email)
