from typing import Annotated

from fastapi import APIRouter, Depends, Path, status

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.postfix_override import (
    PARAMETER_PATTERN,
    TOKEN_PATTERN,
    PostfixMainOverrideRead,
    PostfixMasterOverrideRead,
    PostfixOverrideValue,
)
from app.services import postfix_override_service

SettingsDep = Annotated[Settings, Depends(get_settings)]
ParameterPath = Annotated[str, Path(pattern=PARAMETER_PATTERN)]
ServicePath = Annotated[str, Path(pattern=TOKEN_PATTERN)]
TypePath = Annotated[str, Path(pattern=TOKEN_PATTERN, alias="type")]

router = APIRouter(
    prefix="/postfix/overrides",
    tags=["postfix-overrides"],
    dependencies=[Depends(require_api_key)],
)


@router.get("/main")
def list_main_overrides(settings: SettingsDep) -> list[PostfixMainOverrideRead]:
    return postfix_override_service.list_main_overrides(settings.postfix_main_cf)


@router.put("/main/{parameter}", status_code=status.HTTP_204_NO_CONTENT)
def set_main_override(
    parameter: ParameterPath, payload: PostfixOverrideValue, settings: SettingsDep
) -> None:
    postfix_override_service.set_main_override(settings.postfix_main_cf, parameter, payload.value)


@router.delete("/main/{parameter}", status_code=status.HTTP_204_NO_CONTENT)
def delete_main_override(parameter: ParameterPath, settings: SettingsDep) -> None:
    postfix_override_service.delete_main_override(settings.postfix_main_cf, parameter)


@router.get("/master")
def list_master_overrides(settings: SettingsDep) -> list[PostfixMasterOverrideRead]:
    return postfix_override_service.list_master_overrides(settings.postfix_master_cf)


@router.put("/master/{service}/{type}/{parameter}", status_code=status.HTTP_204_NO_CONTENT)
def set_master_override(
    service: ServicePath,
    type_: TypePath,
    parameter: ParameterPath,
    payload: PostfixOverrideValue,
    settings: SettingsDep,
) -> None:
    postfix_override_service.set_master_override(
        settings.postfix_master_cf, service, type_, parameter, payload.value
    )


@router.delete("/master/{service}/{type}/{parameter}", status_code=status.HTTP_204_NO_CONTENT)
def delete_master_override(
    service: ServicePath, type_: TypePath, parameter: ParameterPath, settings: SettingsDep
) -> None:
    postfix_override_service.delete_master_override(
        settings.postfix_master_cf, service, type_, parameter
    )
