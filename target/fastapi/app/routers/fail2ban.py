from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.fail2ban import (
    BanCreate,
    BanResult,
    Fail2banConfigName,
    Fail2banConfigRead,
    Fail2banConfigUpdate,
    JailBans,
    UnbanResult,
)
from app.services import fail2ban_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(prefix="/fail2ban", tags=["fail2ban"], dependencies=[Depends(require_api_key)])


@router.get(
    "/config/{name}",
    description="Reads the raw content of a fail2ban custom config file (jail.local or jail.d entry).",
)
def read_config(name: Fail2banConfigName, settings: SettingsDep) -> Fail2banConfigRead:
    return Fail2banConfigRead(name=name, content=fail2ban_service.read_config(settings, name))


@router.put(
    "/config/{name}",
    summary="Write fail2ban config",
    description=(
        "Overwrites the custom config file. DMS only applies its contents "
        "(to /etc/fail2ban/) on container startup, so a restart is needed for changes "
        "to take effect."
    ),
)
def write_config(
    name: Fail2banConfigName, payload: Fail2banConfigUpdate, settings: SettingsDep
) -> Fail2banConfigRead:
    fail2ban_service.write_config(settings, name, payload.content)
    return Fail2banConfigRead(name=name, content=payload.content)


@router.get("/bans", description="Lists all currently banned IP addresses, grouped by jail.")
def list_bans() -> list[JailBans]:
    return fail2ban_service.list_bans()


@router.post(
    "/bans",
    status_code=status.HTTP_201_CREATED,
    description="Manually bans an IP address in the custom jail.",
)
def ban_ip(payload: BanCreate) -> BanResult:
    if not fail2ban_service.ban_ip(payload.ip):
        raise HTTPException(status.HTTP_409_CONFLICT, f"'{payload.ip}' is already banned")
    return BanResult(ip=payload.ip, jail="custom")


@router.delete(
    "/bans/{ip:path}",
    description="Unbans an IP address from every jail it is currently banned in.",
)
def unban_ip(ip: str) -> UnbanResult:
    jails = fail2ban_service.unban_ip(ip)
    if not jails:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"'{ip}' is not banned")
    return UnbanResult(ip=ip, jails=jails)
