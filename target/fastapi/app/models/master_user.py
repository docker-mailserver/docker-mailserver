from pydantic import BaseModel, Field


class MasterUserCreate(BaseModel):
    username: str = Field(min_length=1)
    password: str = Field(min_length=1)


class MasterUserUpdate(BaseModel):
    password: str = Field(min_length=1)


class MasterUserRead(BaseModel):
    username: str
