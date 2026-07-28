"""Generates DKIM keys via the `open-dkim` CLI binary (`setup config dkim`).

`open-dkim` (target/bin/open-dkim) configures OpenDKIM, unless Rspamd is enabled without
OpenDKIM, in which case it transparently forwards to `rspamd-dkim` (target/bin/rspamd-dkim)
instead. Either way it's the single entrypoint `setup config dkim` uses, so key generation is
delegated to it rather than reimplemented; which options are actually accepted (`keytype`,
`force`) depends on which backend ends up handling the request.
"""

from app.core.cli import run_cli
from app.models.dkim import DkimKeyGenerate


def generate_keys(payload: DkimKeyGenerate) -> str:
    args: list[str] = []

    if payload.keytype is not None:
        args += ["keytype", payload.keytype]
    if payload.keysize is not None:
        args += ["keysize", str(payload.keysize)]
    if payload.selector is not None:
        args += ["selector", payload.selector]
    if payload.domain is not None:
        args += ["domain", payload.domain]
    if payload.force:
        args.append("--force")

    return run_cli("open-dkim", *args)
