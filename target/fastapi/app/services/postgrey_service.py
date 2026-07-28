"""Read/write access to the Postgrey whitelist files consumed at container startup.

`whitelist_clients.local` and `whitelist_recipients` are copied wholesale to
`/etc/postgrey/` (see `__setup__security__postgrey` in
target/scripts/startup/setup.d/security/misc.sh), so they're exposed as raw content
(one host/domain or recipient address per line) rather than parsed entries.
"""

from pathlib import Path

from app.core.config import Settings
from app.models.postgrey import PostgreyWhitelistName

_PATH_ATTRS: dict[PostgreyWhitelistName, str] = {
    "clients": "postgrey_whitelist_clients",
    "recipients": "postgrey_whitelist_recipients",
}


def _whitelist_path(settings: Settings, name: PostgreyWhitelistName) -> Path:
    return getattr(settings, _PATH_ATTRS[name])


def read_whitelist(settings: Settings, name: PostgreyWhitelistName) -> str:
    path = _whitelist_path(settings, name)
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def write_whitelist(settings: Settings, name: PostgreyWhitelistName, content: str) -> None:
    path = _whitelist_path(settings, name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def delete_whitelist(settings: Settings, name: PostgreyWhitelistName) -> None:
    _whitelist_path(settings, name).unlink(missing_ok=True)
