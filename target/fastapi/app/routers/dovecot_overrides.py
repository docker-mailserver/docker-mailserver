from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.dovecot_override import DovecotOverrideRead, DovecotOverrideWrite
from app.services import dovecot_override_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/dovecot/overrides",
    tags=["dovecot-overrides"],
    dependencies=[Depends(require_api_key)],
)


@router.get("", description="Reads the raw content of the Dovecot custom config override file.")
def get_override(settings: SettingsDep) -> DovecotOverrideRead:
    return DovecotOverrideRead(content=dovecot_override_service.read_override(settings.dovecot_cf))


@router.put(
    "",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Overwrites the Dovecot custom config override file with the given content.",
)
def set_override(payload: DovecotOverrideWrite, settings: SettingsDep) -> None:
    dovecot_override_service.write_override(settings.dovecot_cf, payload.content)


@router.delete(
    "",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Deletes the Dovecot custom config override file.",
)
def delete_override(settings: SettingsDep) -> None:
    dovecot_override_service.delete_override(settings.dovecot_cf)
