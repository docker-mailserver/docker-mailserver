from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import require_api_key
from app.models.mail_queue import QueueDeleteResult, QueueSummary
from app.services import mail_queue_service

router = APIRouter(prefix="/queue", tags=["mail-queue"], dependencies=[Depends(require_api_key)])


@router.get("", description="Lists all messages currently held in the Postfix mail queue.")
def list_queue() -> QueueSummary:
    return QueueSummary(messages=mail_queue_service.list_messages())


@router.post(
    "/flush",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Forces an immediate delivery attempt for every queued message.",
)
def flush_queue() -> None:
    mail_queue_service.flush_queue()


@router.delete("", description="Deletes every message currently in the mail queue.")
def delete_all_messages() -> QueueDeleteResult:
    return QueueDeleteResult(deleted=mail_queue_service.delete_all_messages())


@router.delete(
    "/{queue_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Deletes a single message from the mail queue by its queue ID.",
)
def delete_message(queue_id: str) -> None:
    if not mail_queue_service.delete_message(queue_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"No such queued message '{queue_id}'")
