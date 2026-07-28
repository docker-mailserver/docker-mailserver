"""Read/write access to the Dovecot config-override file consumed at container startup.

`dovecot.cf` is copied wholesale to `/etc/dovecot/local.conf`
(see `target/scripts/startup/setup.d/dovecot.sh:_setup_dovecot`). Unlike Postfix's `main.cf`
override (plain `parameter = value` pairs), Dovecot's config format supports nested blocks
(e.g. `protocol imap { ... }`), so this is exposed as raw content rather than parsed
key/value pairs.
"""

from pathlib import Path


def read_override(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def write_override(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def delete_override(path: Path) -> None:
    path.unlink(missing_ok=True)
