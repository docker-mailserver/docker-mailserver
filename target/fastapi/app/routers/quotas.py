from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key, require_file_provisioner
from app.models.quota import QuotaRead, QuotaSet
from app.services import mailbox_service, quota_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/quotas",
    tags=["quotas"],
    dependencies=[Depends(require_api_key), Depends(require_file_provisioner)],
)


@router.get("/{email}", description="Reads the storage quota configured for a mailbox.")
def get_quota(email: str, settings: SettingsDep) -> QuotaRead:
    if not mailbox_service.mailbox_exists(settings, email):
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"'{email}' does not exist")

    return QuotaRead(email=email, quota=quota_service.get_quota(settings, email))


@router.put("/{email}", description="Sets the storage quota for a mailbox.")
def set_quota(email: str, payload: QuotaSet) -> QuotaRead:
    quota_service.set_quota(email, payload.quota)
    return QuotaRead(email=email, quota=payload.quota)


@router.delete(
    "/{email}",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Removes the storage quota override for a mailbox.",
)
def delete_quota(email: str) -> None:
    quota_service.delete_quota(email)
