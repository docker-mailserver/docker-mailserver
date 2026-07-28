from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key, require_file_provisioner
from app.models.mailbox import MailboxCreate, MailboxRead, MailboxUpdate
from app.services import mailbox_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/mailboxes",
    tags=["mailboxes"],
    dependencies=[Depends(require_api_key), Depends(require_file_provisioner)],
)


@router.get("")
def list_mailboxes(settings: SettingsDep) -> list[MailboxRead]:
    return mailbox_service.list_mailboxes(settings)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_mailbox(payload: MailboxCreate) -> MailboxRead:
    mailbox_service.create_mailbox(payload.email, payload.password)
    return MailboxRead(email=payload.email)


@router.put("/{email}")
def update_mailbox(email: str, payload: MailboxUpdate) -> MailboxRead:
    mailbox_service.update_mailbox(email, payload.password)
    return MailboxRead(email=email)


@router.delete("/{email}", status_code=status.HTTP_204_NO_CONTENT)
def delete_mailbox(
    email: str,
    delete_data: Annotated[
        bool, Query(description="Also delete the mailbox's stored mail data")
    ] = False,
) -> None:
    mailbox_service.delete_mailbox(email, delete_data)
