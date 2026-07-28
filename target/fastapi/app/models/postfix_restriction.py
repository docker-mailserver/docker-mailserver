from typing import Literal

from pydantic import BaseModel, Field

# `send` -> `postfix-send-access.cf` (checked via `smtpd_sender_restrictions`), `receive` ->
# `postfix-receive-access.cf` (checked via `smtpd_recipient_restrictions`). See
# `restrict-access` (target/bin/restrict-access) and `__postfix__setup_email_access` in
# target/scripts/startup/setup.d/postfix.sh.
PostfixRestrictionDirection = Literal["send", "receive"]


class PostfixRestrictionCreate(BaseModel):
    address: str = Field(min_length=1, examples=["user@example.com", "example.com"])


class PostfixRestrictionRead(BaseModel):
    direction: PostfixRestrictionDirection
    addresses: list[str]
