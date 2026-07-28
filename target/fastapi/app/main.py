import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.cli import CliCommandError
from app.core.config import get_settings
from app.core.exceptions import cli_command_error_handler
from app.core.security import get_api_key
from app.routers import (
    aliases,
    amavis,
    dkim,
    dovecot_overrides,
    environment,
    fail2ban,
    logs,
    mail_queue,
    mailboxes,
    master_users,
    postfix_overrides,
    postfix_restrictions,
    postgrey,
    quotas,
    relay,
    rspamd,
    sieve_filters,
    spamassassin,
    supervisor,
)

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    # Resolve the API key eagerly, so a missing API_KEY/API_KEY_FILE fails fast at
    # startup instead of on the first request.
    get_api_key()
    yield


settings = get_settings()

app = FastAPI(
    title="docker-mailserver API",
    description="REST API for managing mailboxes, aliases, quotas and Dovecot master users.",
    lifespan=lifespan,
    docs_url="/api/docs" if settings.API_SWAGGER_ENABLED else None,
    redoc_url="/api/redoc" if settings.API_SWAGGER_ENABLED else None,
    openapi_url="/api/openapi.json" if settings.API_SWAGGER_ENABLED else None,
)

app.add_exception_handler(CliCommandError, cli_command_error_handler)

app.include_router(mailboxes.router, prefix="/api")
app.include_router(aliases.router, prefix="/api")
app.include_router(quotas.router, prefix="/api")
app.include_router(master_users.router, prefix="/api")
app.include_router(logs.router, prefix="/api")
app.include_router(fail2ban.router, prefix="/api")
app.include_router(relay.router, prefix="/api")
app.include_router(postfix_overrides.router, prefix="/api")
app.include_router(postfix_restrictions.router, prefix="/api")
app.include_router(dovecot_overrides.router, prefix="/api")
app.include_router(sieve_filters.router, prefix="/api")
app.include_router(spamassassin.router, prefix="/api")
app.include_router(postgrey.router, prefix="/api")
app.include_router(amavis.router, prefix="/api")
app.include_router(rspamd.router, prefix="/api")
app.include_router(dkim.router, prefix="/api")
app.include_router(supervisor.router, prefix="/api")
app.include_router(mail_queue.router, prefix="/api")
app.include_router(environment.router, prefix="/api")


@app.get("/api/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok", "version": settings.dms_version}
