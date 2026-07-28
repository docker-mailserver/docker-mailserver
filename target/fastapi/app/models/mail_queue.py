from typing import Literal

from pydantic import BaseModel

# Suffix `postqueue -p` appends to the queue ID: `*` = active (being delivered right now),
# `!` = on hold, no suffix = deferred (delivery failed, will be retried).
QueueMessageStatus = Literal["active", "hold", "deferred"]


class QueueMessage(BaseModel):
    queue_id: str
    status: QueueMessageStatus
    size: int
    arrival_time: str
    sender: str
    recipients: list[str]
    reason: str | None = None


class QueueSummary(BaseModel):
    messages: list[QueueMessage]


class QueueDeleteResult(BaseModel):
    deleted: int
