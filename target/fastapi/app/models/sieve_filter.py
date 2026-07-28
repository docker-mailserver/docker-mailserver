from pydantic import BaseModel


class SieveFilterRead(BaseModel):
    content: str


class SieveFilterWrite(BaseModel):
    content: str
