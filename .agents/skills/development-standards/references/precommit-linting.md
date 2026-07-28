# 🔧 Pre-commit, Linting & Conventions

Tous les changements doivent respecter `.pre-commit-config.yaml`.

## Hooks disponibles

### 1. Ruff — Python linting & formatting

Remplace Black, Flake8, isort.

```bash
ruff check backend/ --fix        # Auto-fix linting
ruff format backend/             # Format code
```

```toml
# pyproject.toml
[tool.ruff]
line-length = 100
target-version = "py314"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "B", "C4", "UP"]
ignore = ["E501"]  # géré par le formatter
```

### 2. python-typing-update — Modernisation des type hints

```bash
pre-commit run --hook-stage manual python-typing-update --all-files
```

Python 3.14+ : `str | None` au lieu de `Optional[str]`, `list[int]` au lieu de `List[int]`.

### 3. Prettier — Formatting frontend (HTML, JSON, YAML, Markdown, TS)

```bash
npm run prettier
cd frontend && npx prettier --write "src/**/*.{ts,html,scss}"
```

```json
// .prettierrc
{
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false,
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5",
  "arrowParens": "avoid"
}
```

### 4. Codespell — Orthographe

```bash
codespell                  # check
codespell --write-changes  # auto-fix
```

```
# .codespellrc
skip = ./.git,*.json,*.csv,.devcontainer,.vscode
ignore-words-list = te
```

### 5. Hooks pre-commit standard

`check-json`, `check-yaml` (`--unsafe`), `check-toml`, `check-added-large-files`, `end-of-file-fixer`, `trailing-whitespace`, `mixed-line-ending`. Les fichiers doivent finir par un saut de ligne, sans espaces de fin.

### 6. yamllint

```yaml
# .yamllint
extends: default
rules:
  line-length: disable
  indentation: { spaces: 2 }
```

## Exécution manuelle

```bash
pre-commit run --all-files            # tous les hooks
pre-commit run ruff-format --all-files
pre-commit install                    # auto-run au commit
pre-commit autoupdate                 # MAJ versions
git commit --no-verify                # désactiver (déconseillé)
```

## Workflow recommandé avant commit

```bash
cd backend && ruff format . && cd ..
cd frontend && npm run prettier && cd ..
pre-commit run --all-files            # doit passer sans modification
cd backend && python -m pytest && cd ..
cd frontend && npm run test && cd ..
git add . && git commit -m "feat(scope): description"
```

## Config IDE (auto-format)

`.vscode/settings.json` : `formatOnSave: true` partout ; formatter Python = `charliermarsh.ruff` (avec `source.fixAll` + `source.organizeImports`), reste = `esbenp.prettier-vscode`.

---

## 📋 Conventions communes

### Noms de fichiers

```
# Angular                          # FastAPI
my-component.component.{ts,html,css}  user_service.py    # Service
my.service.ts                        user_models.py     # Modèles Pydantic
my.pipe.ts / my.directive.ts         user_routes.py     # Routes
my.guard.ts                          config.py / exceptions.py
```

### Nommage

- **TypeScript** : `MAX_RETRY` (const), `currentUser` (var), `getUserById()` (fn), `UserService` (classe), `IUser` (interface), `Status` (enum). HTML : `data-testid`, `aria-label`, `(click)`, `(keydown.enter)`, `[attr.aria-expanded]`.
- **Python** : `MAX_RETRIES` (const), `current_user` (var), `get_user_by_id()` (fn), `UserService` (classe), `async def fetch_data()`.

---

## ✅ Checklist avant commit

**Angular :**

- [ ] `@if`/`@for`/`@switch` (pas `*ngIf`/`*ngFor`/`*ngSwitch`)
- [ ] Template `.html` et styles `.css` séparés
- [ ] `inject()` pour la DI ; état avec `signal()`/`computed()` ; formulaires en Signal Forms
- [ ] Pas d'imports circulaires ; fichiers finissant par un saut de ligne

**FastAPI :**

- [ ] Routes `async` ; modèles Pydantic pour la validation
- [ ] `HTTPException` pour les erreurs ; `logging` (pas `print()`)
- [ ] Type hints + docstrings ; config via `Settings`
- [ ] Fichiers `.py` finissant par un saut de ligne

**Documentation :** markdown standard, extension `.md`, fichiers finissant par un saut de ligne.

## Ressources

- [Pre-commit](https://pre-commit.com/) · [Ruff](https://docs.astral.sh/ruff/) · [Prettier](https://prettier.io/) · [Docker](https://docs.docker.com/) · [Docker Compose](https://docs.docker.com/compose/)
