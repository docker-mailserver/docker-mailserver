from collections import deque
from pathlib import Path

from app.core.config import Settings
from app.models.log import LogFile, LogRead


def list_logs(settings: Settings) -> list[LogFile]:
    if not settings.dms_logs_dir.is_dir():
        return []

    logs = [
        LogFile(name=entry.name, size=(stat := entry.stat()).st_size, modified_at=stat.st_mtime)
        for entry in settings.dms_logs_dir.iterdir()
        if entry.is_file()
    ]
    return sorted(logs, key=lambda log: log.name)


def resolve_log_path(settings: Settings, name: str) -> Path | None:
    """Resolve `name` to a file under `dms_logs_dir`, guarding against path traversal."""
    if not name or "/" in name or "\\" in name:
        return None

    path = settings.dms_logs_dir / name
    if not path.is_file() or path.parent.resolve() != settings.dms_logs_dir.resolve():
        return None

    return path


def read_log(path: Path, name: str, lines: int) -> LogRead:
    with path.open(encoding="utf-8", errors="replace") as log_file:
        tail = deque(log_file, maxlen=lines)
    return LogRead(name=name, lines=[line.rstrip("\n") for line in tail])
