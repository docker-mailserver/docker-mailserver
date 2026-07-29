from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.log import LogFile, LogRead
from app.services import log_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(prefix="/logs", tags=["logs"], dependencies=[Depends(require_api_key)])


@router.get("", description="Lists the available DMS log files.")
def list_logs(settings: SettingsDep) -> list[LogFile]:
    return log_service.list_logs(settings)


@router.get("/{name}", description="Reads the trailing lines of a given log file.")
def read_log(
    name: str,
    settings: SettingsDep,
    lines: Annotated[int, Query(gt=0, le=10_000, description="Number of trailing lines")] = 200,
) -> LogRead:
    path = log_service.resolve_log_path(settings, name)
    if path is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"'{name}' does not exist")

    return log_service.read_log(path, name, lines)
