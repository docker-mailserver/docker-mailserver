from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.postgrey import PostgreyWhitelistName, PostgreyWhitelistRead, PostgreyWhitelistWrite
from app.services import postgrey_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/postgrey",
    tags=["postgrey"],
    dependencies=[Depends(require_api_key)],
)


@router.get("/whitelist/{name}")
def get_whitelist(name: PostgreyWhitelistName, settings: SettingsDep) -> PostgreyWhitelistRead:
    return PostgreyWhitelistRead(name=name, content=postgrey_service.read_whitelist(settings, name))


@router.put("/whitelist/{name}", status_code=status.HTTP_204_NO_CONTENT)
def set_whitelist(
    name: PostgreyWhitelistName, payload: PostgreyWhitelistWrite, settings: SettingsDep
) -> None:
    postgrey_service.write_whitelist(settings, name, payload.content)


@router.delete("/whitelist/{name}", status_code=status.HTTP_204_NO_CONTENT)
def delete_whitelist(name: PostgreyWhitelistName, settings: SettingsDep) -> None:
    postgrey_service.delete_whitelist(settings, name)
