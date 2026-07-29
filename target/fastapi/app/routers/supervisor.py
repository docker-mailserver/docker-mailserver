from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import require_api_key
from app.models.supervisor import ServiceStatus
from app.services import supervisor_service

# The API itself runs as the `fastapi-api` supervisord program. Stopping/restarting it
# through this endpoint would kill the process handling the request before it can respond.
_SELF_PROGRAM_NAME = "fastapi-api"

router = APIRouter(prefix="/services", tags=["services"], dependencies=[Depends(require_api_key)])


def _require_known_service(status_: ServiceStatus | None, name: str) -> ServiceStatus:
    if status_ is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"No such service '{name}'")
    return status_


@router.get("", description="Lists all services managed by supervisord and their current status.")
def list_services() -> list[ServiceStatus]:
    return supervisor_service.list_services()


@router.get("/{name}", description="Reads the current status of a single supervisord service.")
def read_service(name: str) -> ServiceStatus:
    return _require_known_service(supervisor_service.get_service(name), name)


@router.post("/{name}/start", description="Starts a stopped supervisord service.")
def start_service(name: str) -> ServiceStatus:
    return _require_known_service(supervisor_service.start_service(name), name)


@router.post(
    "/{name}/stop",
    description=(
        "Stops a running supervisord service. The API's own service cannot be stopped "
        "through this endpoint."
    ),
)
def stop_service(name: str) -> ServiceStatus:
    if name == _SELF_PROGRAM_NAME:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Cannot stop the API's own service through itself"
        )
    return _require_known_service(supervisor_service.stop_service(name), name)


@router.post(
    "/{name}/restart",
    description=(
        "Restarts a supervisord service. The API's own service cannot be restarted "
        "through this endpoint."
    ),
)
def restart_service(name: str) -> ServiceStatus:
    if name == _SELF_PROGRAM_NAME:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Cannot restart the API's own service through itself"
        )
    return _require_known_service(supervisor_service.restart_service(name), name)
