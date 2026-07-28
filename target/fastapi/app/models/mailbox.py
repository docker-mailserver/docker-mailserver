from pydantic import BaseModel, Field

from app.models.common import MAIL_ACCOUNT_PATTERN


class MailboxCreate(BaseModel):
    email: str = Field(pattern=MAIL_ACCOUNT_PATTERN)
    password: str = Field(min_length=1)


class MailboxUpdate(BaseModel):
    password: str = Field(min_length=1)


class MailboxRead(BaseModel):
    email: str
