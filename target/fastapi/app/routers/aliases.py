from typing import Annotated

from fastapi import APIRouter, Depends, Query, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.alias import AliasCreate, AliasRead
from app.services import alias_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/aliases",
    tags=["aliases"],
    dependencies=[Depends(require_api_key)],
)


@router.get("", description="Lists all configured mail aliases and their recipients.")
def list_aliases(settings: SettingsDep) -> list[AliasRead]:
    return alias_service.list_aliases(settings)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    description="Adds a recipient to an alias, creating the alias if it doesn't exist yet.",
)
def create_alias(payload: AliasCreate) -> None:
    alias_service.create_alias(payload.alias, payload.recipient)


@router.delete(
    "/{alias}",
    status_code=status.HTTP_204_NO_CONTENT,
    description=(
        "Removes a recipient from an alias. The alias itself is removed once its last "
        "recipient is deleted."
    ),
)
def delete_alias(alias: str, recipient: Annotated[str, Query(min_length=1)]) -> None:
    alias_service.delete_alias(alias, recipient)
