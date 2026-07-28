"""Read-only access to the flat files backing docker-mailserver's `FILE` account provisioner.

Formats mirror `target/scripts/helpers/database/db.sh` (`__db_get_delimiter_for`):
- postfix-accounts.cf / dovecot-masters.cf : `|`-delimited (LOGIN|PASSWORD_HASH|ATTRS)
- postfix-virtual.cf                       : whitespace-delimited (ALIAS RECIPIENT[,RECIPIENT...])
- dovecot-quotas.cf                        : `:`-delimited (MAIL_ACCOUNT:QUOTA)
- postfix-relaymap.cf / postfix-sasl-password.cf : whitespace-delimited (SENDER VALUE),
  see `target/scripts/helpers/relay.sh`. These aren't gated by `ACCOUNT_PROVISIONER`.

Reading these directly avoids depending on the human-oriented, ANSI-colored output of
`listmailuser`/`listalias`/`listdovecotmasteruser` (which also shells out to `doveadm` per
account for quota/alias display, and isn't meant to be machine-parsed).
"""

from pathlib import Path

from app.models.alias import AliasRead
from app.models.mailbox import MailboxRead
from app.models.master_user import MasterUserRead
from app.models.relay import RelayAuthRead, RelayHostRead


def _valid_lines(path: Path) -> list[str]:
    """Mirror `_get_valid_lines_from_file`: skip blank lines and comments."""
    if not path.is_file():
        return []

    lines = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if stripped and not stripped.startswith("#"):
            lines.append(raw_line)
    return lines


def list_mailboxes(database_accounts: Path) -> list[MailboxRead]:
    return [MailboxRead(email=line.split("|", 1)[0]) for line in _valid_lines(database_accounts)]


def mailbox_exists(database_accounts: Path, email: str) -> bool:
    target = email.lower()
    return any(line.split("|", 1)[0].lower() == target for line in _valid_lines(database_accounts))


def list_aliases(database_virtual: Path) -> list[AliasRead]:
    aliases = []
    for line in _valid_lines(database_virtual):
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        alias, recipients = parts
        aliases.append(
            AliasRead(alias=alias, recipients=[r.strip() for r in recipients.split(",")])
        )
    return aliases


def get_quota(database_quotas: Path, email: str) -> str | None:
    target = email.lower()
    for line in _valid_lines(database_quotas):
        account, _, quota = line.partition(":")
        if account.lower() == target:
            return quota
    return None


def list_master_users(database_dovecot_masters: Path) -> list[MasterUserRead]:
    return [
        MasterUserRead(username=line.split("|", 1)[0])
        for line in _valid_lines(database_dovecot_masters)
    ]


def list_relay_hosts(database_relaymap: Path) -> list[RelayHostRead]:
    hosts = []
    for line in _valid_lines(database_relaymap):
        parts = line.split(None, 1)
        sender = parts[0]
        host = parts[1].strip() if len(parts) == 2 else ""
        hosts.append(RelayHostRead(sender=sender, host=host or None))
    return hosts


def list_relay_auth(database_sasl_password: Path) -> list[RelayAuthRead]:
    entries = []
    for line in _valid_lines(database_sasl_password):
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        sender, credentials = parts
        username, _, _password = credentials.strip().partition(":")
        entries.append(RelayAuthRead(sender=sender, username=username))
    return entries
