from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.rspamd import (
    FILENAME_PATTERN,
    RspamdCustomCommandsRead,
    RspamdCustomCommandsWrite,
    RspamdOverrideFile,
    RspamdOverrideFileRead,
    RspamdOverrideFileWrite,
)
from app.services import rspamd_service

SettingsDep = Annotated[Settings, Depends(get_settings)]
NamePath = Annotated[str, Path(pattern=FILENAME_PATTERN)]

router = APIRouter(prefix="/rspamd", tags=["rspamd"], dependencies=[Depends(require_api_key)])


@router.get("/custom-commands")
def get_custom_commands(settings: SettingsDep) -> RspamdCustomCommandsRead:
    try:
        commands = rspamd_service.read_custom_commands(settings.rspamd_custom_commands_cf)
    except ValueError as error:
        # The file may have been hand-edited (it's also usable as a DMS Config volume file)
        # into something that no longer matches the typed directive schema.
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(error)) from error
    return RspamdCustomCommandsRead(commands=commands)


@router.put("/custom-commands", status_code=status.HTTP_204_NO_CONTENT)
def set_custom_commands(payload: RspamdCustomCommandsWrite, settings: SettingsDep) -> None:
    rspamd_service.write_custom_commands(settings.rspamd_custom_commands_cf, payload.commands)


@router.delete("/custom-commands", status_code=status.HTTP_204_NO_CONTENT)
def delete_custom_commands(settings: SettingsDep) -> None:
    rspamd_service.delete_custom_commands(settings.rspamd_custom_commands_cf)


@router.get("/override.d")
def list_override_files(settings: SettingsDep) -> list[RspamdOverrideFile]:
    return rspamd_service.list_override_files(settings.rspamd_override_d)


@router.get("/override.d/{name}")
def get_override_file(name: NamePath, settings: SettingsDep) -> RspamdOverrideFileRead:
    path = rspamd_service.resolve_override_path(settings.rspamd_override_d, name)
    if path is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"'{name}' does not exist")

    return RspamdOverrideFileRead(name=name, content=rspamd_service.read_override_file(path))


@router.put("/override.d/{name}", status_code=status.HTTP_204_NO_CONTENT)
def set_override_file(
    name: NamePath, payload: RspamdOverrideFileWrite, settings: SettingsDep
) -> None:
    rspamd_service.write_override_file(settings.rspamd_override_d, name, payload.content)


@router.delete("/override.d/{name}", status_code=status.HTTP_204_NO_CONTENT)
def delete_override_file(name: NamePath, settings: SettingsDep) -> None:
    path = rspamd_service.resolve_override_path(settings.rspamd_override_d, name)
    if path is not None:
        rspamd_service.delete_override_file(path)
