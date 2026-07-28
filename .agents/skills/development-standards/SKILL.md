---
name: development-standards
description: Normes de code (Angular + FastAPI). À utiliser quand on écrit/refactore du code frontend Angular ou backend FastAPI de ce dépôt, ou avant un commit. Charge les détails depuis references/ uniquement au besoin.
---

# 🎓 Normes de développement

Index des **règles propres à ce dépôt**. Les détails sont dans `references/` — n'y aller que si la tâche concerne la partie correspondante.

> **Best practices génériques des frameworks** : utiliser les skills dédiés plutôt que dupliquer ici — `angular-developer` (Angular), `fastapi` (FastAPI), `sqlmodel` (couche base de données / ORM).

| Couche      | Techno                      | Version                                           |
| ----------- | --------------------------- | ------------------------------------------------- |
| Frontend    | Angular                     | 22+ (Signals, Signal Forms, Zoneless, Standalone) |
| Backend     | FastAPI                     | 0.139.0+ (async, Pydantic v2)                     |
| UI          | Bootstrap / Bootstrap Icons | 5.3.8+ / 1.13.1+                                  |
| Runtimes    | Python / Node.js            | 3.14+ / 22+                                       |
| Déploiement | Docker                      | multi-stage, conteneur unique SPA                 |

## Règles essentielles

### Angular → détails : [references/angular.md](references/angular.md)

- Composants **standalone**, fichiers `.ts` / `.html` / `.css` **séparés** (pas d'inline massif).
- Control flow `@if` / `@for (… track …)` / `@switch` — **jamais** `*ngIf` / `*ngFor` / `*ngSwitch`.
- État réactif avec `signal()` / `computed()` / `effect()` ; mode **zoneless**.
- Formulaires en **Signal Forms** (`@angular/forms/signals`).
- DI via `inject()`. Pas de `any`. Désabonnement RxJS via `takeUntilDestroyed`.

### FastAPI → détails : [references/fastapi.md](references/fastapi.md)

- **Toutes** les routes `async` ; I/O en `await`.
- Validation par **modèles Pydantic v2** (syntaxe `str | None`, `list[…]`).
- Erreurs via `HTTPException` / exceptions typées ; **jamais** de backtrace renvoyée au client.
- `logging` (pas `print()`). Type hints + docstrings partout.
- Config & secrets via `BaseSettings` — **rien en dur**.

### Pre-commit, conventions & checklist → détails : [references/precommit-linting.md](references/precommit-linting.md)

- Python : `ruff check --fix` + `ruff format` (line-length 100). Frontend : `prettier`.
- Tout doit passer `pre-commit run --all-files` avant commit ; fichiers finissant par un saut de ligne.
- Conventions de nommage fichiers/symboles et checklist commit dans le fichier de référence.

## Quand utiliser ce skill

Écriture ou refactoring de code Angular/FastAPI dans ce dépôt, création de composants/services/routes/modèles, ou préparation d'un commit. Charger le fichier `references/` adapté à la tâche en cours plutôt que tout lire.
