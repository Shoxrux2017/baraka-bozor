# BarakaBozor Backend

Laravel API for BarakaBozor. It serves a Flutter client over JSON at `/api/v1` and nothing else: there is no web UI, no Blade view and no asset pipeline.

The backend is authoritative for identity, role, account state, record ownership, assignment scope, Order and Item lifecycle, quantities, prices, fees, approvals, payment and refund state, cancellation, and delivery completion.

## Requirements

```text
PHP 8.3+
Composer
PostgreSQL
```

PostgreSQL wiring arrives in `S01-INT-001`. Until then the application runs without a database and its tests need none.

## Checks

```sh
php artisan test
php vendor/bin/pint --test
php vendor/bin/phpstan analyse
composer validate --strict
```

## Conventions

`AGENTS.md` in this directory holds the backend engineering rules: thin controllers, focused actions, explicit authorization scope, forward migrations, integer UZS money, atomic financial writes, and stable API error codes. Read it with the root `AGENTS.md` and the current task contract under `tasks/`.

The locked product and technical specification lives in `docs/01` through `docs/09` at the repository root. Open specification questions are tracked in `docs/SPEC_DECISIONS_BACKLOG.md`.

## API errors

Every failure under `/api/v1` is rendered by `app/Exceptions/ApiExceptionRenderer.php` into the locked envelope:

```json
{ "message": "Human-readable message.", "code": "stable_machine_code", "errors": {} }
```

Clients branch on `code`, never on `message`. No exception text, stack frame, file path or query fragment reaches a response body, in any debug mode.
