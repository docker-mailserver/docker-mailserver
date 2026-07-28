"""Runtime configuration for the mailserver API.

Paths mirror the layout used by the rest of docker-mailserver and are not meant to be
operator-configurable (they're tied to the Docker image layout), so they're plain
constants rather than `Settings` fields:
- Mutable config/state read by the CLI tools lives under ``/tmp/docker-mailserver``.
- The CLI binaries (``addmailuser``, ``setquota``, ...) are installed to ``/usr/local/bin``.
"""

from functools import lru_cache
from pathlib import Path

from pydantic import PrivateAttr
from pydantic_settings import BaseSettings, SettingsConfigDict

DMS_CONFIG_DIR = Path("/tmp/docker-mailserver")
DMS_LOGS_DIR = Path("/var/log/mail")
BIN_DIR = Path("/usr/local/bin")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(case_sensitive=True)

    API_KEY: str | None = None
    API_KEY_FILE: str | None = None
    API_SWAGGER_ENABLED: bool = False
    ACCOUNT_PROVISIONER: str = "FILE"

    dms_config_dir: Path = DMS_CONFIG_DIR
    dms_logs_dir: Path = DMS_LOGS_DIR
    bin_dir: Path = BIN_DIR
    _dms_version: str = PrivateAttr(default="Unknown")

    @property
    def dms_version(self) -> str:
        return self._dms_version

    @property
    def database_accounts(self) -> Path:
        return self.dms_config_dir / "postfix-accounts.cf"

    @property
    def database_virtual(self) -> Path:
        return self.dms_config_dir / "postfix-virtual.cf"

    @property
    def database_quotas(self) -> Path:
        return self.dms_config_dir / "dovecot-quotas.cf"

    @property
    def database_dovecot_masters(self) -> Path:
        return self.dms_config_dir / "dovecot-masters.cf"

    @property
    def fail2ban_jail_config(self) -> Path:
        return self.dms_config_dir / "fail2ban-jail.cf"

    @property
    def fail2ban_config(self) -> Path:
        return self.dms_config_dir / "fail2ban-fail2ban.cf"

    @property
    def database_relaymap(self) -> Path:
        return self.dms_config_dir / "postfix-relaymap.cf"

    @property
    def database_sasl_password(self) -> Path:
        return self.dms_config_dir / "postfix-sasl-password.cf"

    @property
    def postfix_main_cf(self) -> Path:
        return self.dms_config_dir / "postfix-main.cf"

    @property
    def postfix_master_cf(self) -> Path:
        return self.dms_config_dir / "postfix-master.cf"

    @property
    def dovecot_cf(self) -> Path:
        return self.dms_config_dir / "dovecot.cf"

    @property
    def dovecot_sieve_before(self) -> Path:
        return self.dms_config_dir / "before.dovecot.sieve"

    @property
    def dovecot_sieve_after(self) -> Path:
        return self.dms_config_dir / "after.dovecot.sieve"

    @property
    def spamassassin_rules_cf(self) -> Path:
        return self.dms_config_dir / "spamassassin-rules.cf"


@lru_cache
def get_settings() -> Settings:
    return Settings()
