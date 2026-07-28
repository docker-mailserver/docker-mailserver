from typing import Literal

from pydantic import BaseModel, Field

# `rspamd-dkim` (target/bin/rspamd-dkim) supports both algorithms; `open-dkim`
# (target/bin/open-dkim, used whenever Rspamd doesn't manage DKIM) only ever generates RSA keys.
DkimKeyType = Literal["rsa", "ed25519"]
DkimKeySize = Literal[1024, 2048, 4096]


class DkimKeyGenerate(BaseModel):
    domain: str | None = Field(
        default=None,
        description=(
            "Domain(s) to generate keys for. Comma-separated when OpenDKIM manages DKIM; "
            "Rspamd only accepts a single domain. Defaults to DMS' FQDN domain, plus mail "
            "account domains when using the file-based account provisioner."
        ),
        examples=["example.com", "example.com,example.net"],
    )
    selector: str | None = Field(
        default=None,
        description="DKIM selector. Default: 'mail'.",
        examples=["mail"],
    )
    keysize: DkimKeySize | None = Field(
        default=None, description="RSA key size in bits. Default: 2048."
    )
    keytype: DkimKeyType | None = Field(
        default=None,
        description="Key algorithm. Only supported when Rspamd manages DKIM. Default: 'rsa'.",
    )
    force: bool = Field(
        default=False,
        description=(
            "Overwrite existing key files instead of failing. Only supported when Rspamd "
            "manages DKIM."
        ),
    )


class DkimKeyGenerateResult(BaseModel):
    output: str
