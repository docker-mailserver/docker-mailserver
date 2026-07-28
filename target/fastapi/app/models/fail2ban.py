from typing import Literal

from pydantic import BaseModel, Field

# `jail` -> `fail2ban-jail.cf` (individual jail settings), `fail2ban` -> `fail2ban-fail2ban.cf`
# (general F2B settings). See `__setup__security__fail2ban` in
# target/scripts/startup/setup.d/security/misc.sh for where these are consumed.
Fail2banConfigName = Literal["jail", "fail2ban"]


class Fail2banConfigRead(BaseModel):
    name: Fail2banConfigName
    content: str


class Fail2banConfigUpdate(BaseModel):
    content: str


class BanCreate(BaseModel):
    # No format validation here: `fail2ban ban` (target/bin/fail2ban) accepts anything
    # fail2ban-client's `banip` will take, including single IPs and CIDR subnets.
    ip: str = Field(min_length=1, examples=["203.0.113.7", "203.0.113.0/24"])


class BanResult(BaseModel):
    ip: str
    jail: str


class UnbanResult(BaseModel):
    ip: str
    jails: list[str]


class JailBans(BaseModel):
    jail: str
    banned_ips: list[str]
