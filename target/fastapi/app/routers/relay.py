from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.relay import RelayAuthCreate, RelayAuthRead, RelayHostCreate, RelayHostRead
from app.services import relay_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(prefix="/relay", tags=["relay"], dependencies=[Depends(require_api_key)])


@router.get("/hosts")
def list_relay_hosts(settings: SettingsDep) -> list[RelayHostRead]:
    return relay_service.list_relay_hosts(settings)


@router.post("/hosts", status_code=status.HTTP_201_CREATED)
def add_relay_host(payload: RelayHostCreate) -> None:
    relay_service.add_relay_host(payload.domain, payload.host, payload.port)


@router.post("/hosts/{domain}/exclude", status_code=status.HTTP_204_NO_CONTENT)
def exclude_relay_domain(domain: str) -> None:
    relay_service.exclude_relay_domain(domain)


@router.delete("/hosts/{domain}", status_code=status.HTTP_204_NO_CONTENT)
def delete_relay_host(domain: str) -> None:
    relay_service.delete_relay_host(domain)


@router.get("/auth")
def list_relay_auth(settings: SettingsDep) -> list[RelayAuthRead]:
    return relay_service.list_relay_auth(settings)


@router.post("/auth", status_code=status.HTTP_201_CREATED)
def add_relay_auth(payload: RelayAuthCreate) -> None:
    relay_service.add_relay_auth(payload.domain, payload.username, payload.password)


@router.delete("/auth/{domain}", status_code=status.HTTP_204_NO_CONTENT)
def delete_relay_auth(domain: str) -> None:
    relay_service.delete_relay_auth(domain)
