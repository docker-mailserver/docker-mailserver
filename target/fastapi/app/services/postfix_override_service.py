"""Read/write access to Postfix config-override files consumed at container startup.

- `postfix-main.cf`   : appended wholesale to `/etc/postfix/main.cf` (`parameter = value` lines).
- `postfix-master.cf` : each line passed to `postconf -P` (`service/type/parameter=value`).

See `target/scripts/startup/setup.d/postfix.sh` and
`docs/content/config/advanced/override-defaults/postfix.md`.

Unlike the flat "databases" in `app/services/db_reader.py`, these are free-form config files
with no dedicated CLI tool (they're meant to be edited directly), so both reads and writes are
implemented here rather than delegated to a bash script.
"""

import re
from pathlib import Path

from app.models.postfix_override import PostfixMainOverrideRead, PostfixMasterOverrideRead


def _valid_lines(path: Path) -> list[str]:
    if not path.is_file():
        return []

    lines = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if stripped and not stripped.startswith("#"):
            lines.append(raw_line)
    return lines


def list_main_overrides(path: Path) -> list[PostfixMainOverrideRead]:
    overrides = []
    for line in _valid_lines(path):
        parameter, sep, value = line.partition("=")
        if not sep:
            continue
        overrides.append(PostfixMainOverrideRead(parameter=parameter.strip(), value=value.strip()))
    return overrides


def list_master_overrides(path: Path) -> list[PostfixMasterOverrideRead]:
    overrides = []
    for line in _valid_lines(path):
        key, sep, value = line.partition("=")
        if not sep:
            continue

        service, _, rest = key.strip().partition("/")
        type_, _, parameter = rest.partition("/")
        if not service or not type_ or not parameter:
            continue

        overrides.append(
            PostfixMasterOverrideRead(
                service=service, type=type_, parameter=parameter, value=value.strip()
            )
        )
    return overrides


def _upsert_line(path: Path, key: str, entry: str) -> None:
    """Replace the line whose `key` matches (`key = ...` / `key=...`), or append `entry`."""
    pattern = re.compile(rf"^{re.escape(key)}\s*=")
    lines = path.read_text(encoding="utf-8").splitlines() if path.is_file() else []

    for index, line in enumerate(lines):
        if pattern.match(line):
            lines[index] = entry
            break
    else:
        lines.append(entry)

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _remove_line(path: Path, key: str) -> None:
    if not path.is_file():
        return

    pattern = re.compile(rf"^{re.escape(key)}\s*=")
    lines = [line for line in path.read_text(encoding="utf-8").splitlines() if not pattern.match(line)]
    path.write_text("\n".join(lines) + "\n" if lines else "", encoding="utf-8")


def set_main_override(path: Path, parameter: str, value: str) -> None:
    _upsert_line(path, parameter, f"{parameter} = {value}")


def delete_main_override(path: Path, parameter: str) -> None:
    _remove_line(path, parameter)


def set_master_override(path: Path, service: str, type_: str, parameter: str, value: str) -> None:
    _upsert_line(path, f"{service}/{type_}/{parameter}", f"{service}/{type_}/{parameter}={value}")


def delete_master_override(path: Path, service: str, type_: str, parameter: str) -> None:
    _remove_line(path, f"{service}/{type_}/{parameter}")
