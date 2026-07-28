from pydantic import BaseModel


class AmavisOverrideRead(BaseModel):
    content: str


class AmavisOverrideWrite(BaseModel):
    content: str
