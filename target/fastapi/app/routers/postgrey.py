from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.postgrey import (
    PostgreyWhitelistEntries,
    PostgreyWhitelistEntryCreate,
    PostgreyWhitelistName,
    PostgreyWhitelistRead,
    PostgreyWhitelistWrite,
)
from app.services import postgrey_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/postgrey",
    tags=["postgrey"],
    dependencies=[Depends(require_api_key)],
)


@router.get(
    "/whitelist/{name}", description="Reads the raw content of a postgrey whitelist file."
)
def get_whitelist(name: PostgreyWhitelistName, settings: SettingsDep) -> PostgreyWhitelistRead:
    return PostgreyWhitelistRead(name=name, content=postgrey_service.read_whitelist(settings, name))


@router.put(
    "/whitelist/{name}",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Overwrites a postgrey whitelist file with the given content.",
)
def set_whitelist(
    name: PostgreyWhitelistName, payload: PostgreyWhitelistWrite, settings: SettingsDep
) -> None:
    postgrey_service.write_whitelist(settings, name, payload.content)


@router.delete(
    "/whitelist/{name}",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Deletes a postgrey whitelist file.",
)
def delete_whitelist(name: PostgreyWhitelistName, settings: SettingsDep) -> None:
    postgrey_service.delete_whitelist(settings, name)


@router.get(
    "/whitelist/{name}/entries",
    description="Lists the individual entries in a postgrey whitelist file.",
)
def list_whitelist_entries(
    name: PostgreyWhitelistName, settings: SettingsDep
) -> PostgreyWhitelistEntries:
    return PostgreyWhitelistEntries(
        name=name, entries=postgrey_service.list_whitelist_entries(settings, name)
    )


@router.post(
    "/whitelist/{name}/entries",
    status_code=status.HTTP_201_CREATED,
    description="Appends an entry to a postgrey whitelist file.",
)
def add_whitelist_entry(
    name: PostgreyWhitelistName, payload: PostgreyWhitelistEntryCreate, settings: SettingsDep
) -> None:
    postgrey_service.add_whitelist_entry(settings, name, payload.entry)


@router.delete(
    "/whitelist/{name}/entries/{entry}",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Removes an entry from a postgrey whitelist file.",
)
def delete_whitelist_entry(name: PostgreyWhitelistName, entry: str, settings: SettingsDep) -> None:
    postgrey_service.delete_whitelist_entry(settings, name, entry)
