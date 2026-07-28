"""Thin wrapper around the docker-mailserver CLI binaries (`addmailuser`, `setquota`, ...).

Mutating operations are delegated to these battle-tested bash scripts instead of being
reimplemented here, so locking, password hashing and Dovecot/Postfix synchronization stay
in one place. See `target/scripts/helpers/database/` for the underlying logic.
"""

import logging
import re
import subprocess
from dataclasses import dataclass

from app.core.config import get_settings

logger = logging.getLogger("mailserver-api")

_ANSI_ESCAPE_RE = re.compile(r"\x1b\[[0-9;]*m")


def _strip_ansi(text: str) -> str:
    return _ANSI_ESCAPE_RE.sub("", text).strip()


@dataclass
class CliCommandError(Exception):
    binary: str
    cli_args: tuple[str, ...]
    returncode: int
    stderr: str

    def __str__(self) -> str:
        return self.stderr or f"'{self.binary}' exited with status {self.returncode}"


def run_cli(binary: str, *args: str, timeout: float = 30) -> str:
    """Run a docker-mailserver CLI binary and return its stdout.

    Raises `CliCommandError` (cleaned, ANSI-free stderr) on non-zero exit.
    """
    settings = get_settings()
    executable = settings.bin_dir / binary

    logger.debug("Running %s %s", executable, args)
    result = subprocess.run(
        [str(executable), *args],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )

    if result.returncode != 0:
        raise CliCommandError(
            binary=binary,
            cli_args=args,
            returncode=result.returncode,
            stderr=_strip_ansi(result.stderr),
        )

    return result.stdout
