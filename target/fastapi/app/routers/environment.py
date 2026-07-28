from typing import Annotated

from fastapi import APIRouter, Depends

from app.core.config import Settings, get_settings
from app.core.security import require_api_key
from app.models.environment import EnvironmentRead
from app.services import environment_service

SettingsDep = Annotated[Settings, Depends(get_settings)]

router = APIRouter(
    prefix="/environment",
    tags=["environment"],
    dependencies=[Depends(require_api_key)],
)


@router.get("")
def get_environment(settings: SettingsDep) -> EnvironmentRead:
    variables = environment_service.read_variables(settings.dms_settings_file)
    return EnvironmentRead(variables=variables)
