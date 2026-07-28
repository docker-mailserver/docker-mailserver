from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.sieve_filter import SieveFilterRead, SieveFilterWrite
from app.services import sieve_filter_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/dovecot/sieve",
    tags=["sieve-filters"],
    dependencies=[Depends(require_api_key)],
)


@router.get("/before")
def get_before_filter(settings: SettingsDep) -> SieveFilterRead:
    return SieveFilterRead(content=sieve_filter_service.read_filter(settings.dovecot_sieve_before))


@router.put("/before", status_code=status.HTTP_204_NO_CONTENT)
def set_before_filter(payload: SieveFilterWrite, settings: SettingsDep) -> None:
    sieve_filter_service.write_filter(settings.dovecot_sieve_before, payload.content)


@router.delete("/before", status_code=status.HTTP_204_NO_CONTENT)
def delete_before_filter(settings: SettingsDep) -> None:
    sieve_filter_service.delete_filter(settings.dovecot_sieve_before)


@router.get("/after")
def get_after_filter(settings: SettingsDep) -> SieveFilterRead:
    return SieveFilterRead(content=sieve_filter_service.read_filter(settings.dovecot_sieve_after))


@router.put("/after", status_code=status.HTTP_204_NO_CONTENT)
def set_after_filter(payload: SieveFilterWrite, settings: SettingsDep) -> None:
    sieve_filter_service.write_filter(settings.dovecot_sieve_after, payload.content)


@router.delete("/after", status_code=status.HTTP_204_NO_CONTENT)
def delete_after_filter(settings: SettingsDep) -> None:
    sieve_filter_service.delete_filter(settings.dovecot_sieve_after)
