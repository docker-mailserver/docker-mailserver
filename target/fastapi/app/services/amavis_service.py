"""Read/write access to the Amavis config-override file consumed at container startup.

`amavis.cf` is copied wholesale to `/etc/amavis/conf.d/50-user` (see
`__setup__security__amavis` in target/scripts/startup/setup.d/security/misc.sh), so it's
exposed as raw content rather than parsed key/value pairs.
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
