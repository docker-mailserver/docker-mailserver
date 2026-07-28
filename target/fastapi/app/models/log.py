from datetime import datetime

from pydantic import BaseModel


class LogFile(BaseModel):
    name: str
    size: int
    modified_at: datetime


class LogRead(BaseModel):
    name: str
    lines: list[str]
