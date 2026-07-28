"""Read/write access to the SpamAssassin custom-rules file consumed at container startup.

`spamassassin-rules.cf` is copied wholesale to `/etc/spamassassin/` (see
`__setup__security__spamassassin` in target/scripts/startup/setup.d/security/misc.sh), so
it's exposed as raw content rather than parsed rules.
"""

from pathlib import Path


def read_rules(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def write_rules(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def delete_rules(path: Path) -> None:
    path.unlink(missing_ok=True)
