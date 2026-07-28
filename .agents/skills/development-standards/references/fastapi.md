# 🐍 FastAPI — Spécificités

> **Best practices génériques FastAPI** (`Annotated`, `response_model`, DI, async vs sync, routers, streaming) : voir le skill **`fastapi`**.
> **Couche base de données / ORM** (modèles, CRUD, sessions) : voir le skill **`sqlmodel`**.
> Ce fichier ne contient que les **écarts propres à ce dépôt**.

## Versions imposées

FastAPI **0.139.0 ou supérieur** · Python **3.14 ou supérieur** · Pydantic **v2 ou supérieur** · async/await partout.

## Règles projet (non négociables)

### 1. Architecture des dossiers

backend/app
├── statics     # héberge les assets statiques
├── routers     # héberge les routers ou endpoints
├── services    # les services mis à dispositions des différents routers
├── config.py   # ensemble des variables et contstantes (voir chapitre 4)
├── main.py     # fichier principale
├── security.py # héberge les middlewares de sécurité ratelimiting, csrf, security policies , etc...
├── depends.py  # héberge les dépendances de Fastapi Depend() ou Security()

### 2. Aucune fuite d'information vers le client

Ne **jamais** renvoyer de backtrace ni l'objet exception au client. Logger le détail côté serveur, renvoyer un message générique.

```python
try:
    return await service.do_something()
except Exception as exc:
    logger.error(f"Error in do_something: {exc}")
    raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Operation failed")
```

### 3. Exceptions typées + handlers

Hiérarchie d'exceptions applicatives plutôt que des `HTTPException` éparpillées.

```python
class BaseAPIException(Exception):
    def __init__(self, status_code: int, detail: str, headers: dict | None = None):
        self.status_code, self.detail, self.headers = status_code, detail, headers

class NotFoundException(BaseAPIException):
    def __init__(self, resource: str, resource_id):
        super().__init__(status.HTTP_404_NOT_FOUND, f"{resource} with ID {resource_id} not found")

# + ConflictException (409), UnauthorizedException (401), ForbiddenException (403)

@app.exception_handler(NotFoundException)
async def not_found_handler(request, exc):
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
```

### 4. Configuration & secrets via `BaseSettings`

**Rien en dur.** Tout passe par `pydantic_settings.BaseSettings` (`.env`). Variables propres au projet :

```python
class Settings(BaseSettings):
    secret_key: str                      # obligatoire en prod
    admin_username: str = "admin"
    admin_password: str = "changeme"
    # Database : db_host/port/name/user/password → database_url (postgresql+asyncpg)
    registry_url: str = "http://localhost:5000"
    registry_username: str | None = None
    registry_password: str | None = None
    # Scan de vulnérabilités
    vuln_scan_enabled: bool = True
    vuln_scan_severities: str = "CRITICAL,HIGH"
    vuln_scan_timeout: int = 300
    log_level: str = "INFO"
    cors_origins: str = "*"

    model_config = {"env_file": ".env", "case_sensitive": False}
```

### 5. Architecture conteneur unique

L'application entière (frontend + backend) est déployée dans **un seul conteneur Docker** multi-stage : build frontend Node → install deps backend (`python:3.14-slim`) → runtime servant le SPA statique via Uvicorn, port **8000**, avec `HEALTHCHECK` sur `/api/health`.

### 6. Swagger

Les pages Swagger **ne doivent pas dépendre** d'un cdn ou d'un hébergement internet.
Swagger doit être **désactivable** via une varaibel d'envrionnement

### 6. Rappels appliqués partout

- **Toutes** les routes `async` ; I/O en `await` (DB, HTTP).
- Validation par **modèles Pydantic v2** (syntaxe moderne `str | None`, `list[…]`, `field_validator`, `model_config`).
- `logging.getLogger(__name__)` — **jamais** `print()`.
- Type hints + docstrings sur toutes les fonctions.

_(Pour les patterns d'implémentation génériques, se reporter aux skills `fastapi` et `sqlmodel`.)_
