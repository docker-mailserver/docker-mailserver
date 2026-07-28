from fastapi import APIRouter, Depends, status

from app.core.security import require_api_key
from app.models.postfix_restriction import (
    PostfixRestrictionCreate,
    PostfixRestrictionDirection,
    PostfixRestrictionRead,
)
from app.services import postfix_restriction_service

router = APIRouter(
    prefix="/postfix/restrictions",
    tags=["postfix-restrictions"],
    dependencies=[Depends(require_api_key)],
)


@router.get("/{direction}")
def list_restrictions(direction: PostfixRestrictionDirection) -> PostfixRestrictionRead:
    addresses = postfix_restriction_service.list_addresses(direction)
    return PostfixRestrictionRead(direction=direction, addresses=addresses)


@router.post("/{direction}", status_code=status.HTTP_201_CREATED)
def add_restriction(
    direction: PostfixRestrictionDirection, payload: PostfixRestrictionCreate
) -> None:
    postfix_restriction_service.add_address(direction, payload.address)


@router.delete("/{direction}/{address}", status_code=status.HTTP_204_NO_CONTENT)
def delete_restriction(direction: PostfixRestrictionDirection, address: str) -> None:
    postfix_restriction_service.delete_address(direction, address)
