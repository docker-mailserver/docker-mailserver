"""Generates DKIM keys via the `open-dkim` CLI binary (`setup config dkim`).

`open-dkim` (target/bin/open-dkim) configures OpenDKIM, unless Rspamd is enabled without
OpenDKIM, in which case it transparently forwards to `rspamd-dkim` (target/bin/rspamd-dkim)
instead. Either way it's the single entrypoint `setup config dkim` uses, so key generation is
delegated to it rather than reimplemented; which options are actually accepted (`keytype`,
`force`) depends on which backend ends up handling the request, so that backend is resolved
here first (mirroring the check at the top of `open-dkim` itself) to build a request the
chosen backend will actually accept.
"""

from app.core.cli import run_cli
from app.core.config import get_settings
from app.models.dkim import DkimKeyGenerate
from app.services.environment_service import read_variables


def _rspamd_manages_dkim() -> bool:
    variables = read_variables(get_settings().dms_settings_file)
    return variables.get("ENABLE_RSPAMD") == "1" and variables.get("ENABLE_OPENDKIM") != "1"


def generate_keys(payload: DkimKeyGenerate) -> str:
    rspamd_backend = _rspamd_manages_dkim()

    if not rspamd_backend and payload.keytype == "ed25519":
        raise ValueError(
            "keytype 'ed25519' is only supported when Rspamd manages DKIM, "
            "but OpenDKIM is the active backend (which only generates RSA keys)"
        )

    args: list[str] = []

    if rspamd_backend and payload.keytype is not None:
        args += ["keytype", payload.keytype]
    if payload.keysize is not None:
        args += ["keysize", str(payload.keysize)]
    if payload.selector is not None:
        args += ["selector", payload.selector]
    if payload.domain is not None:
        args += ["domain", payload.domain]
    if rspamd_backend and payload.force:
        args.append("--force")

    return run_cli("open-dkim", *args)
