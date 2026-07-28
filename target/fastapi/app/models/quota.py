from pydantic import BaseModel, Field

# Same validation as `_quota_unit_is_valid` in target/bin/setquota
QUOTA_PATTERN = r"^([0-9]+(B|k|M|G|T)|0)$"


class QuotaSet(BaseModel):
    quota: str = Field(pattern=QUOTA_PATTERN, examples=["10M", "5G", "0"])


class QuotaRead(BaseModel):
    email: str
    quota: str | None = None
