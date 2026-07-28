from pydantic import BaseModel


class SpamassassinRulesRead(BaseModel):
    content: str


class SpamassassinRulesWrite(BaseModel):
    content: str
