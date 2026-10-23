# W4-1 — Laravel Boost Trial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The implementing agent can ask the running app for its schema, routes, logs, last error and version-exact Laravel documentation through Laravel Boost's MCP server, without Boost writing any project rule file, and with no effect on tests or production.

**Architecture:** `laravel/boost` becomes a dev dependency. Its MCP server runs inside the `app` container (`php artisan boost:mcp`), and Claude Code starts it through `docker compose exec` from a local-scope registration that lives outside the repository. `boost:install` is never run, so nothing writes `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `boost.json`, guidelines or skills. Two Boost features we have no use for are switched off by environment: the browser log watcher (no Blade or JS front end; it adds an unauthenticated route) and the rule recorder (rules live in `AGENTS.md` and `docs/DECISIONS.md`, not `.ai/rules`).

**Tech Stack:** Laravel 13.32, PHP 8.4 in Docker, `laravel/boost` ^2.10 (2.10.3, requires `illuminate/*` ^13.0), `laravel/mcp` 1.1.

**Spec:** `tasks/WAVE_4.md`, task note W4-1; the Owner's decision `DL-103`.

**Checked before the plan (2026-10-23), on this branch, uncommitted:**
- `composer require --dev laravel/boost:^2.10` in the container added only `laravel/boost` 2.10.3, `laravel/mcp` 1.1.1, `laravel/roster` 1.0.0, `symfony/yaml` 8.1.9, `composer/semver` 3.5.2; no other package moved.
- `boost:mcp` inside the container answered `initialize` (protocol 2025-06-18) and `tools/list`: `application-info`, `browser-logs`, `database-connections`, `database-query`, `database-schema`, `get-absolute-url`, `last-error`, `read-log-entries`, `record-rule`, `search-docs`. `tinker` is off by default.
- Boost turns itself off under PHPUnit (`runningUnitTests()`) and outside `local` unless `APP_DEBUG=true`; the production image of W4-2 installs no dev dependencies.
- `database-query` refuses writing keywords and runs inside a PostgreSQL `READ ONLY` transaction that is always rolled back.
- `composer audit` reports three advisories in packages we already had (`symfony/http-foundation`, `league/commonmark`), none in Boost's.

## Global Constraints

- Branch `task/w4-1-laravel-boost` from `main` `3c977c9`. Never commit to `main`.
- Never run `boost:install` or `boost:update`. `git status` before each commit shows no `AGENTS.md`, `CLAUDE.md`, `.mcp.json`, `boost.json`, `.ai/`, `.claude/skills`, `.cursor`, `.github/copilot-instructions.md` change.
- Never run an artisan command that writes the dev database (`migrate:fresh`, `db:wipe`, `db:seed`, `--env=testing`).
- `README.md` at the root carries the Owner's own uncommitted edit and `.superpowers/` is untracked: neither is staged.
- Lockfile changes only with the Boost dependency (`AGENTS.md` §7); the reason goes in the commit message.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Before the pull request: the full backend suite, `pint --test`, `phpstan analyse`, `git diff --check`, and `/security-review` once (a backend dependency).

## Review Focus

1. **Tests and CI unchanged.** Boost must not register under PHPUnit; the full suite and PHPStan pass with it installed. Task 1 Step 4.
2. **No unauthenticated dev route.** With `APP_ENV=local`, `route:list` shows no `_boost/...` route once the watcher is off. Task 1 Step 3.
3. **No second rule store.** `record-rule` is absent from `tools/list`, so no agent writes `backend/.ai/rules`. Task 1 Step 3.
4. **The dev database stays intact.** A write through `database-query` is refused. Task 1 Step 3.
5. **The MCP works from Claude Code, not only from a pipe.** The local-scope registration starts the server through `docker compose exec`, and `claude mcp list` reports it connected. Task 1 Step 5.

---

### Task 1: Boost as a dev dependency, configured and connected

**Files:**
- Modify: `backend/composer.json`, `backend/composer.lock` (already changed by the check above)
- Modify: `backend/.env.example` (two lines after the `LOG_*` block)
- Modify: `docker/README.md` (new section "Laravel Boost for the agent", after "Walk a wave on the real stack")
- Modify: `docs/07-architecture.md` §2 Backend baseline (one line)
- Modify: `docs/DECISIONS.md` (new `DL-106`), `tasks/WAVE_4.md` (W4-1 row and risk row)
- Local only, not committed: `backend/.env` (same two lines); Claude Code local-scope MCP registration

- [ ] **Step 1: Switch off the two unused features.** In `backend/.env.example` and `backend/.env`, add with a one-line comment that Boost is the agent's dev tool (`DL-106`):

```text
BOOST_BROWSER_LOGS_WATCHER=false
BOOST_RULES_ENABLED=false
```

- [ ] **Step 2: Probe the server again.** Pipe `initialize`, `notifications/initialized`, `tools/list` into `docker compose -f docker/compose.yaml exec -T app php artisan boost:mcp`.
Expected: nine tools, no `record-rule`.

- [ ] **Step 3: Check the safety properties.**
  - `docker compose -f docker/compose.yaml exec -T app php artisan route:list --path=_boost` → no routes.
  - `tools/call database-query` with `DELETE FROM users` → an error result; with `SELECT count(*) FROM users` → a number.
  - `tools/call database-schema` (summary) and `tools/call search-docs` with `["queue retry after commit"]` → non-empty answers.

- [ ] **Step 4: Run the gates.** Full backend suite through `test-runner`, `vendor/bin/pint --test`, `vendor/bin/phpstan analyse` in the container.
Expected: all green, the same test count as `main`.

- [ ] **Step 5: Register the MCP for Claude Code at local scope.**

```text
claude mcp add --scope local laravel-boost -- docker compose -f G:/project/baraka-bozor/docker/compose.yaml exec -T app php artisan boost:mcp
claude mcp list
```

Expected: `laravel-boost` connected; `git status` shows no new file.

- [ ] **Step 6: Document.**
  - `docker/README.md`: what Boost gives, that it needs the stack up, the registration command, that `boost:install` is never run and why, the two switched-off features.
  - `docs/07` §2 Backend: `Laravel Boost (dev only, on trial, DL-103, DL-106)`.
  - `DL-106 — Laravel Boost set-up (2026-10-23, agent)`: version and compatibility check; MCP inside the container through a local-scope registration; no `boost:install`; the watcher and the rule recorder off and why; `tinker` left off (`dev-db` safety); `search-docs` sends the query and the package list to boost.laravel.com and, in `local`, skips TLS verification — accepted for documentation text, never send data through it; Boost is absent from tests and production.
  - `tasks/WAVE_4.md`: W4-1 → Merged with the PR number at the end; a risk row "`composer audit`: advisories in `symfony/http-foundation` (ReDoS through `Cache-Control`) and `league/commonmark`; updated in W4-2 before the first deployment".

- [ ] **Step 7: Commit.**

```text
git add backend/composer.json backend/composer.lock backend/.env.example docker/README.md docs/07-architecture.md docs/DECISIONS.md tasks/WAVE_4.md docs/superpowers/plans/2026-10-23-w4-1-laravel-boost.md
git commit   # "chore: add Laravel Boost as a dev dependency (DL-103, DL-106)"; body: the reason — the agent's MCP for schema, routes, logs and version-exact docs during the backend-heavy Wave 4
```

### Task 2: Record the Owner's answer on the store reviewers' sign-in

**Files:**
- Modify: `docs/DECISIONS.md` (new `DL-105`), `tasks/WAVE_4.md` (Owner question 1, task notes W4-4, W4-5, W4-6)

- [ ] **Step 1: `DL-105 — The store reviewers' sign-in (2026-10-23, Owner)`.** Option А: one reviewer phone in production, set in the server's environment with its own fixed code, distinct from the development code; it opens only a Customer account, never Shopper or Courier mode; the account is created in advance with the name "Проверка Google", so its orders are recognisable on the board and the Operator cancels them; the code is changed by editing the environment; the attempt limit of `DL-87` applies. It resolves interview 7.2's contradiction and supersedes the "empty in production" half of `BR-ROLE-011` and `AGENTS.md` §5 for this one number; those texts change with the code.
- [ ] **Step 2: `tasks/WAVE_4.md`.** Question 1 marked answered (`DL-105`). W4-4 gains "the reviewer number of `DL-105`: configuration, Customer-only gate, tests; `BR-ROLE-011`, `docs/09` and `AGENTS.md` §5 updated". W4-5 gains "the reviewer number and code set on the server; the account created". W4-6 replaces "the reviewers' access follows the answer to question 1" with "the reviewer number and code go into Play Console's App access".
- [ ] **Step 3: Commit** `docs: record the Owner's answer on the store reviewers' sign-in (DL-105)`.
