from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key, require_file_provisioner
from app.models.master_user import MasterUserCreate, MasterUserRead, MasterUserUpdate
from app.services import master_user_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/master-users",
    tags=["master-users"],
    dependencies=[Depends(require_api_key), Depends(require_file_provisioner)],
)


@router.get("", description="Lists all configured Dovecot master users.")
def list_master_users(settings: SettingsDep) -> list[MasterUserRead]:
    return master_user_service.list_master_users(settings)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    description="Creates a new Dovecot master user with a password.",
)
def create_master_user(payload: MasterUserCreate) -> MasterUserRead:
    master_user_service.create_master_user(payload.username, payload.password)
    return MasterUserRead(username=payload.username)


@router.put("/{username}", description="Updates the password of an existing master user.")
def update_master_user(username: str, payload: MasterUserUpdate) -> MasterUserRead:
    master_user_service.update_master_user(username, payload.password)
    return MasterUserRead(username=username)


@router.delete(
    "/{username}",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Deletes a master user.",
)
def delete_master_user(username: str) -> None:
    master_user_service.delete_master_user(username)
