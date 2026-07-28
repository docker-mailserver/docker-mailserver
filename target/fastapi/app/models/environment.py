from pydantic import BaseModel


class EnvironmentRead(BaseModel):
    variables: dict[str, str]
