import secrets
from functools import lru_cache
from pathlib import Path
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyHeader

from app.core.config import get_settings

_api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)


@lru_cache
def get_api_key() -> str:
    """Resolve the operator-provided API key.

    Must be supplied via `API_KEY` or `API_KEY_FILE`; there is no fallback generation,
    so misconfiguration fails fast at startup instead of silently minting a key.
    """
    settings = get_settings()

    if settings.API_KEY:
        return settings.API_KEY

    if settings.API_KEY_FILE:
        file_path = Path(settings.API_KEY_FILE)
        if file_path.is_file():
            return file_path.read_text(encoding="utf-8").strip()
        raise RuntimeError(f"API_KEY_FILE={file_path} does not exist")

    raise RuntimeError("No API key configured: set API_KEY or API_KEY_FILE")


def require_api_key(x_api_key: Annotated[str | None, Depends(_api_key_header)] = None) -> None:
    if x_api_key is None or not secrets.compare_digest(x_api_key, get_api_key()):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid API key",
        )


def require_file_provisioner() -> None:
    """The underlying CLI tools only manage the flat files used by `ACCOUNT_PROVISIONER=FILE`.

    Under `ACCOUNT_PROVISIONER=LDAP` they would still "succeed" but have no effect, since
    accounts are sourced from LDAP instead (see `listmailuser` applying the same restriction).
    """
    settings = get_settings()
    if settings.ACCOUNT_PROVISIONER != "FILE":
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="This API is only compatible with ACCOUNT_PROVISIONER=FILE",
        )
