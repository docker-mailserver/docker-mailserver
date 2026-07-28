"""Wraps `target/bin/fail2ban` (the same binary behind `setup fail2ban`).

Mutations and jail listing are delegated to that script rather than talking to
`fail2ban-client` directly, so the jail selection for bans (`custom`) and the
"unban from every jail" behavior stay defined in one place.
"""

import re
from pathlib import Path

from app.core.cli import run_cli
from app.core.config import Settings
from app.models.fail2ban import Fail2banConfigName, JailBans

_BANNED_LINE_RE = re.compile(r"^Banned in (?P<jail>\S+):\s*(?P<ips>.+)$", re.MULTILINE)
_UNBANNED_LINE_RE = re.compile(r"^Unbanned IP from (?P<jail>\S+):", re.MULTILINE)

_CONFIG_PATH_ATTRS: dict[Fail2banConfigName, str] = {
    "jail": "fail2ban_jail_config",
    "fail2ban": "fail2ban_config",
}


def _config_path(settings: Settings, name: Fail2banConfigName) -> Path:
    return getattr(settings, _CONFIG_PATH_ATTRS[name])


def read_config(settings: Settings, name: Fail2banConfigName) -> str:
    path = _config_path(settings, name)
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def write_config(settings: Settings, name: Fail2banConfigName, content: str) -> None:
    _config_path(settings, name).write_text(content, encoding="utf-8")


def list_bans() -> list[JailBans]:
    output = run_cli("fail2ban")
    return [
        JailBans(jail=match["jail"], banned_ips=match["ips"].split())
        for match in _BANNED_LINE_RE.finditer(output)
    ]


def ban_ip(ip: str) -> bool:
    """Ban `ip` in the `custom` jail. Returns False if it was already banned."""
    output = run_cli("fail2ban", "ban", ip)
    return output.strip().startswith("Banned custom IP:")


def unban_ip(ip: str) -> list[str]:
    """Unban `ip` from every jail it's currently banned in.

    Returns the jails it was actually removed from (empty if it wasn't banned anywhere).
    """
    output = run_cli("fail2ban", "unban", ip)
    return [match["jail"] for match in _UNBANNED_LINE_RE.finditer(output)]
