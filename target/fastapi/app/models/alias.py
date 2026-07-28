from pydantic import BaseModel, Field

from app.models.common import MAIL_ACCOUNT_PATTERN


class AliasCreate(BaseModel):
    alias: str = Field(pattern=MAIL_ACCOUNT_PATTERN)
    # Comma-separated list of recipients is supported by `addalias` (see target/bin/addalias)
    recipient: str = Field(min_length=1)


class AliasRead(BaseModel):
    alias: str
    recipients: list[str]
