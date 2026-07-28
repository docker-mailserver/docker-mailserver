from pydantic import BaseModel, Field, field_validator


def _reject_whitespace(value: str) -> str:
    if any(char.isspace() for char in value):
        raise ValueError("must not contain whitespace")
    return value


class RelayHostCreate(BaseModel):
    """Mirrors `setup relay add-domain <domain> <host> [<port>]`."""

    domain: str = Field(min_length=1, description="Sender domain, e.g. example.com")
    host: str = Field(min_length=1, description="Relay host, e.g. smtp.relay-service.test")
    port: int = Field(default=25, ge=1, le=65535)

    @field_validator("domain", "host")
    @classmethod
    def _validate(cls, value: str) -> str:
        return _reject_whitespace(value)


class RelayHostRead(BaseModel):
    """A row from `postfix-relaymap.cf`. `host` is `None` for an opt-out (excluded) entry."""

    sender: str
    host: str | None = None


class RelayAuthCreate(BaseModel):
    """Mirrors `setup relay add-auth <domain> <username> <password>`."""

    domain: str = Field(min_length=1)
    username: str = Field(min_length=1)
    password: str = Field(min_length=1)

    @field_validator("domain", "username")
    @classmethod
    def _validate(cls, value: str) -> str:
        return _reject_whitespace(value)


class RelayAuthRead(BaseModel):
    """A row from `postfix-sasl-password.cf`. The password is never exposed."""

    sender: str
    username: str
