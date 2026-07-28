from typing import Literal

from pydantic import BaseModel

# `clients` -> `whitelist_clients.local` (hosts/domains skipping greylisting), `recipients` ->
# `whitelist_recipients` (recipient addresses skipping greylisting). See
# `__setup__security__postgrey` in target/scripts/startup/setup.d/security/misc.sh.
PostgreyWhitelistName = Literal["clients", "recipients"]


class PostgreyWhitelistRead(BaseModel):
    name: PostgreyWhitelistName
    content: str


class PostgreyWhitelistWrite(BaseModel):
    content: str
