# BarakaBozor Backend

Laravel API for BarakaBozor. It serves the Flutter clients over JSON at `/api/v1` and nothing else: no web UI, no Blade views, no asset pipeline.

The backend is authoritative for identity, role, account state, record ownership, assignment scope, the order and item lifecycle, quantities, prices, markup, fees, approvals, payment state, cancellation and delivery completion.

## Running it

Every command runs inside the Compose stack; the host PHP cannot reach PostgreSQL. See `docker/README.md` for start-up, then:

```sh
docker compose -f docker/compose.yaml exec app php artisan test
docker compose -f docker/compose.yaml exec app vendor/bin/pint --test
docker compose -f docker/compose.yaml exec app vendor/bin/phpstan analyse
```

## Conventions

`AGENTS.md` in this directory holds the backend engineering rules: thin controllers, focused actions, explicit authorization scope, forward migrations, integer UZS money, atomic financial writes, stable API error codes. Read it with the root `AGENTS.md`, `docs/07–09` and the current wave file under `tasks/`.

Modules live under `app/Modules/<Module>/` with their routes in `routes/api/v1/<module>.php` and their service provider directly in the module directory; both are collected automatically.

## API errors

Every failure under `/api/v1` is rendered by `app/Exceptions/ApiExceptionRenderer.php` into the envelope of `docs/09-api-contracts.md` Section 3:

```json
{ "message": "Developer-facing English.", "code": "stable_machine_code", "errors": {}, "details": {}, "request_id": "req_..." }
```

Clients branch on `code`, never on `message`. No exception text, stack frame, file path or query fragment reaches a response body, in any debug mode.
