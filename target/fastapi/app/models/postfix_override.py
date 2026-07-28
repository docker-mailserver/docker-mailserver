from pydantic import BaseModel, Field, field_validator

# `postfix-main.cf` parameter names (mirrors typical `postconf` identifiers).
PARAMETER_PATTERN = r"^[A-Za-z_][A-Za-z0-9_]*$"
# `postfix-master.cf` key segments (`service/type/parameter`): no `/` or whitespace.
TOKEN_PATTERN = r"^[^/\s]+$"


class PostfixOverrideValue(BaseModel):
    value: str = Field(min_length=1)

    @field_validator("value")
    @classmethod
    def _no_newlines(cls, value: str) -> str:
        if "\n" in value or "\r" in value:
            raise ValueError("must not contain newlines")
        return value


class PostfixMainOverrideRead(BaseModel):
    parameter: str
    value: str


class PostfixMasterOverrideRead(BaseModel):
    service: str
    type: str
    parameter: str
    value: str
