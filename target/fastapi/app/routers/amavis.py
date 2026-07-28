from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.amavis import AmavisOverrideRead, AmavisOverrideWrite
from app.services import amavis_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/amavis/overrides",
    tags=["amavis"],
    dependencies=[Depends(require_api_key)],
)


@router.get("")
def get_override(settings: SettingsDep) -> AmavisOverrideRead:
    return AmavisOverrideRead(content=amavis_service.read_override(settings.amavis_cf))


@router.put("", status_code=status.HTTP_204_NO_CONTENT)
def set_override(payload: AmavisOverrideWrite, settings: SettingsDep) -> None:
    amavis_service.write_override(settings.amavis_cf, payload.content)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def delete_override(settings: SettingsDep) -> None:
    amavis_service.delete_override(settings.amavis_cf)
