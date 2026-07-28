from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import require_api_key
from app.models.mail_queue import QueueDeleteResult, QueueSummary
from app.services import mail_queue_service

router = APIRouter(prefix="/queue", tags=["mail-queue"], dependencies=[Depends(require_api_key)])


@router.get("")
def list_queue() -> QueueSummary:
    return QueueSummary(messages=mail_queue_service.list_messages())


@router.post("/flush", status_code=status.HTTP_204_NO_CONTENT)
def flush_queue() -> None:
    mail_queue_service.flush_queue()


@router.delete("")
def delete_all_messages() -> QueueDeleteResult:
    return QueueDeleteResult(deleted=mail_queue_service.delete_all_messages())


@router.delete("/{queue_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_message(queue_id: str) -> None:
    if not mail_queue_service.delete_message(queue_id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"No such queued message '{queue_id}'")
