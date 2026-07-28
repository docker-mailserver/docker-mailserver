"""Wraps `target/bin/restrict-access`, the CLI behind `setup email restrict`.

Manages `postfix-send-access.cf` / `postfix-receive-access.cf`: Postfix `access` database
tables (texthash) of addresses/domains REJECTed as senders or recipients. Mutations are
delegated to the script rather than editing the files directly, so the one-time `main.cf`
adjustment (prepending `check_sender_access` / `check_recipient_access`) and the Postfix
reload it triggers stay in one place.
"""

import re

from app.core.cli import run_cli
from app.models.postfix_restriction import PostfixRestrictionDirection

_ENTRY_RE = re.compile(r"^(\S+)\s+REJECT\s*$", re.MULTILINE)


def list_addresses(direction: PostfixRestrictionDirection) -> list[str]:
    output = run_cli("restrict-access", "list", direction)
    return _ENTRY_RE.findall(output)


def add_address(direction: PostfixRestrictionDirection, address: str) -> None:
    run_cli("restrict-access", "add", direction, address)


def delete_address(direction: PostfixRestrictionDirection, address: str) -> None:
    run_cli("restrict-access", "del", direction, address)
