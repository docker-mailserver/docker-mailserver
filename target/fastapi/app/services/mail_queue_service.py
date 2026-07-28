"""Wraps Postfix's `postqueue`/`postsuper` binaries to inspect and manage the mail queue.

Talks to these system binaries directly (not through `run_cli`/`target/bin`, which wrap
docker-mailserver's own setup scripts) since queue inspection and manipulation is native
Postfix functionality with nothing docker-mailserver-specific to layer on top.
"""

import re
import subprocess

from app.models.mail_queue import QueueMessage, QueueMessageStatus

_POSTQUEUE = "/usr/sbin/postqueue"
_POSTSUPER = "/usr/sbin/postsuper"

# First line of a queued message's entry in `postqueue -p` output, e.g.:
#   CA94D3B7CF*     320 Tue Jan 27 10:36:31  sender@example.com
# The trailing `*` (active) or `!` (hold) is omitted for deferred messages.
_MESSAGE_HEADER_RE = re.compile(
    r"^(?P<queue_id>[0-9A-Za-z]+)(?P<flag>[*!])?\s+"
    r"(?P<size>\d+)\s+"
    r"(?P<weekday>\S+)\s+(?P<month>\S+)\s+(?P<day>\S+)\s+(?P<time>\S+)\s+"
    r"(?P<sender>\S+)\s*$"
)


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, capture_output=True, text=True, timeout=30, check=False)


def _parse_message_block(block: str) -> QueueMessage:
    lines = block.splitlines()
    header = _MESSAGE_HEADER_RE.match(lines[0])
    if not header:
        raise ValueError(f"Unparsable postqueue header line: {lines[0]!r}")

    flag = header["flag"]
    status: QueueMessageStatus = "active" if flag == "*" else "hold" if flag == "!" else "deferred"

    reason = None
    recipients = []
    for line in lines[1:]:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("(") and stripped.endswith(")"):
            reason = stripped[1:-1]
        else:
            recipients.append(stripped)

    return QueueMessage(
        queue_id=header["queue_id"],
        status=status,
        size=int(header["size"]),
        arrival_time=f"{header['weekday']} {header['month']} {header['day']} {header['time']}",
        sender=header["sender"],
        recipients=recipients,
        reason=reason,
    )


def _parse_queue_output(output: str) -> list[QueueMessage]:
    stripped = output.strip()
    if not stripped or stripped.lower().startswith("mail queue is empty"):
        return []

    lines = stripped.splitlines()
    if lines[0].startswith("-Queue ID-"):
        lines = lines[1:]
    if lines and lines[-1].startswith("--"):
        lines = lines[:-1]

    body = "\n".join(lines).strip("\n")
    if not body:
        return []

    return [_parse_message_block(block) for block in re.split(r"\n\s*\n", body) if block.strip()]


def list_messages() -> list[QueueMessage]:
    result = _run(_POSTQUEUE, "-p")
    return _parse_queue_output(result.stdout)


def flush_queue() -> None:
    """Ask Postfix to attempt delivery of every queued message now."""
    _run(_POSTQUEUE, "-f")


def delete_all_messages() -> int:
    """Delete every queued message and return how many were removed."""
    count = len(list_messages())
    _run(_POSTSUPER, "-d", "ALL")
    return count


def delete_message(queue_id: str) -> bool:
    """Delete a single queued message. Returns False if `queue_id` doesn't exist."""
    if not any(message.queue_id == queue_id for message in list_messages()):
        return False
    _run(_POSTSUPER, "-d", queue_id)
    return True
