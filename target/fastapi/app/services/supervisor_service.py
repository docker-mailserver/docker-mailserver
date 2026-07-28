"""Wraps `supervisorctl` to start/stop/restart the individual services (postfix, dovecot,
fail2ban, ...) that supervisord manages, each defined as a `[program:...]` entry in
`target/supervisor/conf.d/dms-services.conf`.

Talks to the `supervisorctl` binary rather than supervisord's XML-RPC socket directly, since
its plain-text output already carries the outcome we need and avoids adding the `supervisor`
package as a dependency of the API's own virtualenv.
"""

import re
import subprocess

from app.models.supervisor import ServiceStatus

_SUPERVISORCTL = "/usr/bin/supervisorctl"

_STATUS_LINE_RE = re.compile(
    r"^(?P<name>\S+)\s+"
    r"(?P<state>STOPPED|STARTING|RUNNING|BACKOFF|STOPPING|EXITED|FATAL|UNKNOWN)"
    r"\s*(?P<description>.*)$"
)
_NO_SUCH_PROCESS_RE = re.compile(r"^\S+:\s*ERROR\s*\(no such process\)\s*$")


def _run(*args: str) -> str:
    result = subprocess.run(
        [_SUPERVISORCTL, *args],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    return result.stdout


def _parse_status_line(line: str) -> ServiceStatus:
    match = _STATUS_LINE_RE.match(line)
    if not match:
        raise ValueError(f"Unparsable supervisorctl status line: {line!r}")
    return ServiceStatus(
        name=match["name"], state=match["state"], description=match["description"].strip()
    )


def list_services() -> list[ServiceStatus]:
    output = _run("status")
    return [_parse_status_line(line) for line in output.splitlines() if line.strip()]


def get_service(name: str) -> ServiceStatus | None:
    line = _run("status", name).strip()
    if _NO_SUCH_PROCESS_RE.match(line):
        return None
    return _parse_status_line(line)


def _apply_action(action: str, name: str) -> ServiceStatus | None:
    """Run `supervisorctl <action> <name>` and return its resulting status.

    `start`/`stop` are idempotent from the caller's point of view: re-applying them to a
    service already in the desired state reports the current status instead of an error,
    matching the `no-op on already-satisfied state` behavior operators expect from service
    managers. Only an unknown service name is treated as a real failure.
    """
    output = _run(action, name).strip()
    if _NO_SUCH_PROCESS_RE.match(output):
        return None
    return get_service(name)


def start_service(name: str) -> ServiceStatus | None:
    return _apply_action("start", name)


def stop_service(name: str) -> ServiceStatus | None:
    return _apply_action("stop", name)


def restart_service(name: str) -> ServiceStatus | None:
    return _apply_action("restart", name)
