# 📘 Angular — Spécificités

> **Best practices génériques Angular** (signals, `linkedSignal`, `resource`, forms, DI, routing, SSR, ARIA, testing, control flow) : voir le skill **`angular-developer`**.
> Ce fichier ne contient que les **écarts propres à ce dépôt**.

## Versions imposées

Angular **22** · Bootstrap **5.3.8** · Bootstrap Icons **1.13.1** · Node.js **18+**.

## Règles projet (non négociables)

### 1. UI = Bootstrap, pas Tailwind

Le styling se fait avec **Bootstrap 5.3 + Bootstrap Icons**. Ne pas introduire Tailwind ni d'autre framework CSS (le skill `angular-developer` mentionne Tailwind à titre générique — ici on ne l'utilise pas).

### 2. Fichiers séparés obligatoires

Chaque composant a **trois fichiers distincts** — jamais de `template`/`styles` inline (sauf micro-exemple de doc).

```
app/features/user/user-list/
├── user-list.component.ts      ← templateUrl + styleUrl
├── user-list.component.html
└── user-list.component.css
```

```typescript
@Component({
  selector: 'app-user-list',
  templateUrl: './user-list.component.html',
  styleUrl: './user-list.component.css',
})
```

### 3. Mode Zoneless activé

L'application tourne en **zoneless** (réactivité par signaux). Conserver cette configuration au bootstrap :

```typescript
// app.config.ts
provideZoneChangeDetection({ eventCoalescing: true }),
```

### 4. Architecture des dossiers

```
frontend/src/app/
├── core/        # services singletons, guards, interceptors (JWT), models, constants
├── features/    # composants par fonctionnalité, lazy-loaded
├── shared/      # composants/pipes/directives réutilisables
├── app.config.ts · app.routes.ts · app.component.ts · main.ts
```

### 5. Rappels appliqués partout

- Control flow `@if` / `@for (… track …)` / `@switch` — **jamais** `*ngIf` / `*ngFor` / `*ngSwitch`.
- État via `signal()` / `computed()` / `effect()` ; formulaires en **Signal Forms** (`@angular/forms/signals`).
- DI via `inject()`. Pas de `any`. Désabonnement RxJS via `takeUntilDestroyed(inject(DestroyRef))`.
- Routes lazy via `loadComponent`, protégées par `AuthGuard` (`canActivate`).

_(Pour les exemples d'implémentation de ces points, se reporter au skill `angular-developer`.)_
