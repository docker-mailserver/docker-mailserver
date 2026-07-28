from fastapi import APIRouter, Depends, HTTPException, status

from app.core.security import require_api_key
from app.models.dkim import DkimKeyGenerate, DkimKeyGenerateResult
from app.services import dkim_service

router = APIRouter(prefix="/dkim", tags=["dkim"], dependencies=[Depends(require_api_key)])


@router.post(
    "/keys",
    status_code=status.HTTP_201_CREATED,
    description=(
        "Generates DKIM keys (OpenDKIM, or Rspamd if enabled without OpenDKIM). "
        "OpenDKIM-managed keys are only applied to /etc/opendkim on container startup, "
        "so a restart is needed for those to take effect; Rspamd reloads immediately."
    ),
)
def generate_keys(payload: DkimKeyGenerate) -> DkimKeyGenerateResult:
    try:
        output = dkim_service.generate_keys(payload)
    except ValueError as error:
        # e.g. keytype='ed25519' requested while OpenDKIM (RSA-only) is the active backend.
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, str(error)) from error
    return DkimKeyGenerateResult(output=output)
