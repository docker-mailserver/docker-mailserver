from pydantic import BaseModel


class DovecotOverrideRead(BaseModel):
    content: str


class DovecotOverrideWrite(BaseModel):
    content: str
