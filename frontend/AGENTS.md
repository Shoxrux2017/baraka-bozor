# BarakaBozor Frontend Engineering Rules

## 1. Scope

Applies to changes under `frontend/`. Read with root `AGENTS.md` and the current approved implementation contract.

The contract defines required UX/routes/API/state/validation/tests. This file defines Flutter engineering standards.

## 2. Flutter Architecture

Use the established feature-first flow:

```text
Presentation
  -> Application / Controller / Notifier
  -> Repository contract
  -> Data source / DTO / configured Dio client
```

Use `data/domain/application/presentation` boundaries where they provide real ownership. Do not introduce a second router, state framework, HTTP client, serialization approach, cache system, or competing architecture.

## 3. Presentation Responsibilities

Widgets/screens own rendering, user interaction, forms, focus/keyboard/accessibility, responsive layout, presentation formatting, and display of application state.

Widgets must not:

- call Dio directly;
- build raw API URLs;
- parse raw JSON;
- own persistent storage;
- decide authoritative role/ownership/lifecycle/payment/price/quantity outcomes;
- mutate unrelated global state.

## 4. Riverpod and State Ownership

Controllers/Notifiers/providers own one focused feature/use-case state boundary. Avoid global mutable singletons, God Notifiers, duplicate caches, static hidden state, and provider cycles.

State must express meaningful loading/data/empty/error and mutation states rather than loose booleans.

## 5. Async and Session Safety

Apply operation/session/target ownership safeguards whenever async work can outlive the current account, route, Order, Approval, Payment, or controller.

A stale completion must not:

- overwrite newer account/Order state;
- show old Customer data after account switch;
- publish payment success to a newer attempt;
- close the wrong dialog;
- navigate from an obsolete operation.

Widget `mounted` alone is insufficient when state outlives the widget. Use operation keys/generation/target-session identity/cancellation as appropriate.

## 6. Routing

Use GoRouter and one canonical route structure. Direct route entry must fail safely when auth/role/device context is invalid.

Route guards are UX only; backend authorization remains authoritative.

Navigation after async completion must happen only if the originating session/target/operation remains current.

## 7. Dio and Data Layer

Use one configured API client for base URL, bearer token, timeouts, shared envelope parsing, auth reconciliation, and safe logging.

Data sources own method/path/query/body/header construction. Repositories expose typed application-facing operations/failures. Widgets know no transport details.

Do not add automatic mutation retries unless the task explicitly defines idempotent safe retry behavior.

## 8. DTO and Machine-Value Discipline

Use strict typed DTOs/models. Do not pass raw `Map<String,dynamic>` through UI/application state when a typed boundary is appropriate.

Validate required/unknown keys, types, nullability, UUID/timestamp/enum shape, and cross-field invariants defined by the contract. Malformed success payloads are failures.

Keep machine values (`customer`, `shopping`, `payme`, etc.) separate from localized display labels. Never use translated UI text as control values.

## 9. Backend Authority

Flutter may validate obvious local input and format server data, but must not independently decide authoritative:

- role/permissions;
- record ownership/current assignment;
- Order/Item lifecycle;
- billable quantity;
- final price/fees/total;
- approval eligibility/result;
- payment/refund success;
- cancellation outcome;
- delivery completion.

Do not show confirmed financial success from redirect/navigation alone when backend/provider outcome is still unknown.

## 10. Forms and Mutations

Keep forms deterministic and controlled. Implement only approved normalization. Prevent duplicate submission while an operation is active unless the contract defines safe retry semantics.

Cancel/reset/focus behavior must keep visible controls and authoritative draft state consistent.

## 11. Caching and Invalidation

Reuse existing cache/provider ownership. Invalidation must be narrow and contract-defined. Do not optimistically patch paginated ordering/totals/financial state unless explicitly permitted.

When a mutation may have committed but its response is uncertain, downstream cached state must not remain falsely authoritative; reconcile from backend.

## 12. UI Quality

Follow theme/design tokens and support required:

- mobile/desktop responsiveness by approved role surface;
- text scaling and long content;
- scrolling without overflow;
- keyboard/focus behavior on desktop;
- accessible semantics and errors;
- status communication not based on color alone;
- loading/empty/error/data states;
- mutation busy/failure/reconciliation states.

## 13. Packages and Platforms

Do not add/change Flutter packages or platform files unless explicitly required. Do not alter `pubspec.lock` without a real approved dependency change. Do not regenerate unrelated Android/iOS/Windows/web files.

## 14. Frontend Tests

Use focused DTO/data-source/repository/controller/router/widget tests matching the changed responsibility.

Relevant coverage includes:

- strict DTO parsing;
- method/path/query/body/header construction;
- repository failure mapping;
- notifier state transitions;
- duplicate suppression/idempotent retry UI;
- stale completion/session switching;
- route guards/direct entry;
- loading/empty/error/data presentation;
- payment unknown/reconciliation UX;
- cache invalidation;
- focus/keyboard/accessibility/responsive overflow.

No real external networks and no arbitrary sleeps.

## 15. Frontend Diff Review

In addition to root review, verify Widgets do not call Dio/parse JSON, typed boundaries are focused, no competing router/state/cache/client exists, stale completions are safe, machine values stay separate from UI labels, backend authority is preserved, UI cannot remain permanently loading/disabled after failure, and package/platform/generated changes are justified.
