"""Read/write access to the global Sieve filter files consumed at container startup.

`before.dovecot.sieve` and `after.dovecot.sieve` are copied to
`/usr/lib/dovecot/sieve-global/{before,after}/50-{before,after}.dovecot.sieve` and compiled
with `sievec` (see `target/scripts/startup/setup.d/dovecot.sh:_setup_dovecot_sieve`). They run
respectively before and after the user's personal Sieve script, so like the Dovecot config
override they're exposed as raw content rather than parsed key/value pairs.
"""

from pathlib import Path


def read_filter(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def write_filter(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def delete_filter(path: Path) -> None:
    path.unlink(missing_ok=True)
