"""Read/write access to the Rspamd config-override files consumed at container startup.

- `rspamd/custom-commands.conf` : directive lines (`set-option-for-module`, `add-line`, ...)
  parsed and applied to `/etc/rspamd/override.d/` as the final Rspamd configuration step.
- `rspamd/override.d/`          : arbitrary UCL config files copied wholesale to
  `/etc/rspamd/override.d/` before `custom-commands.conf` is applied.

See `target/scripts/helpers/rspamd.sh` and `target/scripts/startup/setup.d/security/rspamd.sh`.
Like the other free-form config-override files (Amavis, Dovecot, ...), both reads and writes
are implemented here rather than delegated to a bash script.
"""

from pathlib import Path

from app.models.rspamd import RspamdOverrideFile


def read_custom_commands(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8")


def write_custom_commands(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def delete_custom_commands(path: Path) -> None:
    path.unlink(missing_ok=True)


def list_override_files(directory: Path) -> list[RspamdOverrideFile]:
    if not directory.is_dir():
        return []

    files = [
        RspamdOverrideFile(name=entry.name) for entry in directory.iterdir() if entry.is_file()
    ]
    return sorted(files, key=lambda file: file.name)


def resolve_override_path(directory: Path, name: str) -> Path | None:
    """Resolve `name` to a file under `directory`, guarding against path traversal."""
    if not name or "/" in name or "\\" in name:
        return None

    path = directory / name
    if not path.is_file() or path.parent.resolve() != directory.resolve():
        return None

    return path


def read_override_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_override_file(directory: Path, name: str, content: str) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    (directory / name).write_text(content, encoding="utf-8")


def delete_override_file(path: Path) -> None:
    path.unlink(missing_ok=True)
