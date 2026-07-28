"""Read-only access to `/etc/dms-settings`, the flattened snapshot of every DMS environment
variable written at container startup (see `__environment_variables_export` in
`target/scripts/startup/variables-stack.sh`): one `VAR='value'` per line, single-quoted, sorted.
"""

import re
from pathlib import Path

_LINE_PATTERN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)='(.*)'$")

# Unlike `print-environment` (a debug CLI meant to be run manually, see its warning), this
# service backs an HTTP endpoint, so secrets sourced into `/etc/dms-settings` must be redacted.
_SENSITIVE_VARS = {"LDAP_BIND_PW", "SRS_SECRET"}
_REDACTED = "***"


def read_variables(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}

    variables: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        match = _LINE_PATTERN.match(raw_line)
        if not match:
            continue
        name, value = match.group(1), match.group(2)
        variables[name] = _REDACTED if name in _SENSITIVE_VARS and value else value
    return variables
