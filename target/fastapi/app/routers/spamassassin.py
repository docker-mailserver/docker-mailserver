from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.spamassassin import SpamassassinRulesRead, SpamassassinRulesWrite
from app.services import spamassassin_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/spamassassin",
    tags=["spamassassin"],
    dependencies=[Depends(require_api_key)],
)


@router.get("/rules", description="Reads the raw content of the custom SpamAssassin rules file.")
def get_rules(settings: SettingsDep) -> SpamassassinRulesRead:
    content = spamassassin_service.read_rules(settings.spamassassin_rules_cf)
    return SpamassassinRulesRead(content=content)


@router.put(
    "/rules",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Overwrites the custom SpamAssassin rules file with the given content.",
)
def set_rules(payload: SpamassassinRulesWrite, settings: SettingsDep) -> None:
    spamassassin_service.write_rules(settings.spamassassin_rules_cf, payload.content)


@router.delete(
    "/rules",
    status_code=status.HTTP_204_NO_CONTENT,
    description="Deletes the custom SpamAssassin rules file.",
)
def delete_rules(settings: SettingsDep) -> None:
    spamassassin_service.delete_rules(settings.spamassassin_rules_cf)
