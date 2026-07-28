from typing import Literal

from pydantic import BaseModel

# Mirrors supervisord's process state machine (see `supervisor.states.ProcessStates`).
ServiceState = Literal[
    "STOPPED", "STARTING", "RUNNING", "BACKOFF", "STOPPING", "EXITED", "FATAL", "UNKNOWN"
]


class ServiceStatus(BaseModel):
    name: str
    state: ServiceState
    description: str
