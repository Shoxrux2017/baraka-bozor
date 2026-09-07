# BarakaBozor Backend Engineering Rules

## 1. Scope

Applies to changes under `backend/`. Read with root `AGENTS.md` and the current approved implementation contract.

The contract defines behavior/API/schema/lifecycle/concurrency/tests. This file defines Laravel/PostgreSQL engineering standards.

## 2. Backend Architecture

Use the existing Laravel modular-monolith structure and prefer:

```text
HTTP boundary
  -> focused Application/Action use case
  -> Domain policy/service when reusable stateful logic is needed
  -> Eloquent/PostgreSQL/infrastructure
```

Do not introduce a generic repository layer, command bus, event framework, microservice boundary, or new package without explicit approval.

## 3. HTTP Boundary

Controllers stay thin. They normally:

1. receive validated input;
2. resolve authenticated actor/context;
3. call one focused Action/use case;
4. return an established Resource/response.

Do not put complex ownership/assignment checks, lifecycle transitions, transactions, row locking, pricing, money calculations, provider reconciliation, or multi-step persistence in controllers.

Use Form Requests for request-shape validation. Stateful domain rules belong in Actions/domain policies.

## 4. Authorization and Record Scope

Use trusted authenticated context first.

Conceptual protected query:

```text
authenticated actor
  -> role/active-state scope
  -> ownership/current assignment scope
  -> lifecycle rule
  -> read or mutation
```

Avoid globally finding a private record first and only then deciding whether it may be exposed when a scope-safe query is available.

Examples:

- Customer may access only own Addresses/Cart/Orders/Payments/Approvals.
- Shopper may access only current assigned Shopping Orders.
- Courier may access only current assigned Deliveries.
- Operator/Admin may perform only explicit domain actions allowed by the contract.
- Manager is read-only analytics.

Direct UUIDs, filters, pagination, nested resources, and query parameters must not widen scope.

## 5. Eloquent and Query Quality

Keep scope explicit and reviewable. Use server-side filtering/sorting/pagination/aggregates. Avoid N+1 queries, unbounded list loads, loading all rows and filtering in PHP, and hidden Resource queries.

Use deterministic ordering for paginated data where required. Add/use indexes that support the approved query shapes.

## 6. Persistence and Migrations

Use forward migrations for schema changes. Follow locked UUID/timestamptz/money/quantity/constraint conventions from the task contract.

Structural invariants belong in PostgreSQL when practical:

- foreign keys;
- unique/partial unique constraints;
- checks;
- non-null constraints;
- indexes.

Application validation remains required for actor/state/cross-record business rules.

Preserve existing data. Do not destructively edit delivered migrations. Do not use SQLite behavior as a substitute for PostgreSQL correctness.

## 7. Money, Quantity, and Historical Data

Do not use binary floating point for authoritative UZS calculations. Respect integer UZS and locked half-up rounding rules.

Preserve ordered/purchased/billable quantity distinction. Never let excess purchased quantity become automatic Customer charge.

Historical Order snapshots must not be silently recomputed from current Product/settings data.

## 8. Transactions and Concurrency

Use a DB transaction for dependent multi-writes and lifecycle/financial state transitions. When the contract requires row locking:

- lock inside the transaction;
- resolve the scoped authoritative row before locking;
- reload fresh state under lock;
- make the final decision from locked current state;
- preserve one consistent lock order when multiple rows are involved.

Use constraints/idempotency/replay guards in addition to locks where required. Do not use locks as a replacement for structural constraints.

Expected conflicts map to safe stable API errors; never leak DB exceptions.

## 9. External Providers

SMS, FCM, Payme, Paynet, xazna, and Click belong behind explicit infrastructure adapters. Domain/order code must not contain provider-specific HTTP protocol details.

Never call real providers from normal automated tests. Use fakes/stubs and separately approved sandbox/integration checks.

Provider secrets must come from backend configuration/environment and must never be returned to Flutter or logged.

Payment/refund callback processing must validate provider authenticity, deduplicate/replay-protect provider events, and apply normalized business results transactionally.

## 10. Error Handling and API Responses

Use the established API envelope and stable machine codes. Keep distinct where relevant:

- validation;
- unauthenticated;
- forbidden;
- scope-safe not found;
- lifecycle/business conflict;
- rate limit;
- provider unavailable;
- provider outcome unknown;
- server failure.

Do not branch on human-readable messages or expose stack traces/SQL/internal class names/secrets.

## 11. Logging

Log minimal operational metadata only. Never log passwords, OTP codes, bearer tokens, payment secrets/keys, raw sensitive provider payloads, or unnecessary Customer PII.

## 12. Backend Tests

Use focused PHPUnit/Laravel tests at the real boundary that owns behavior.

Relevant coverage includes:

- strict input validation;
- authentication/role/blocking/first-login gates;
- ownership/current-assignment/existence privacy;
- lifecycle conflicts/no-op behavior;
- PostgreSQL constraints/migrations;
- transactions/rollback;
- concurrency/idempotency/replay when specified;
- money/quantity/rounding;
- provider callback normalization/deduplication;
- response status/envelope/resource shape.

Keep tests deterministic with controlled clock/provider fakes and the configured PostgreSQL test database.

## 13. Backend Diff Review

In addition to root review, verify controllers are thin, stateful rules are outside Form Requests/Resources, queries are bounded, migrations preserve data, constraints/indexes support invariants, financial transitions are atomic, and no unrelated dependency/config/generated-file change exists.
