from fastapi import Request, status
from fastapi.responses import JSONResponse

from app.core.cli import CliCommandError

_NOT_FOUND_MARKERS = ("does not exist",)
_CONFLICT_MARKERS = (
    "already exists",
    "already an alias",
    "already defined as an alias",
    "already denied",
)


def _status_code_for(message: str) -> int:
    lowered = message.lower()

    if any(marker in lowered for marker in _NOT_FOUND_MARKERS):
        return status.HTTP_404_NOT_FOUND
    if any(marker in lowered for marker in _CONFLICT_MARKERS):
        return status.HTTP_409_CONFLICT
    return status.HTTP_400_BAD_REQUEST


async def cli_command_error_handler(_: Request, exc: CliCommandError) -> JSONResponse:
    message = str(exc)
    return JSONResponse(status_code=_status_code_for(message), content={"detail": message})
