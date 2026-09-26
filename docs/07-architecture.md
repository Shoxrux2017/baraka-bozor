# BarakaBozor — Architecture

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `docs/INTERVIEW_2026-09-24.md` and `DL-2`–`DL-5` in `docs/DECISIONS.md`. Maintained by the implementing agent.

## 1. Goals

Backend-authoritative business and financial state; stable order history; strong role, ownership, assignment and lifecycle authorization; transaction-safe quantity and payment behaviour; one codebase per side; simple deployment on one server.

## 2. Technology Baseline

### Backend

```text
PHP 8.4 (in Docker), Laravel 13, Laravel Sanctum, PostgreSQL 17
PHPUnit, Laravel Pint, Larastan (PHPStan level 5)
```

### Frontend

```text
Flutter / Dart, Riverpod, GoRouter, Dio, flutter_secure_storage, Material 3
package:web for the panel's image file dialog (DL-28)
Yandex MapKit for the address picker
```

Targets: **Android** and the **web panel** from the first client wave; **iOS** once a Mac and an Apple developer account exist (iOS code is written throughout). No Windows or Linux desktop build.

## 3. Repository Baseline

```text
baraka-bozor/
  AGENTS.md                 engineering rules
  docs/                     product and technical design, decisions, interview
  tasks/                    wave plans
  backend/                  Laravel application (runs only inside docker/)
  frontend/                 Flutter application
  docker/                   local runtime: PostgreSQL 17 + PHP 8.4
```

Backend routes are declared per module in `routes/api/v1/<module>.php` and collected by one loader; module service providers under `app/Modules/<Module>/` are collected by one registry; Flutter feature route fragments are collected by one registry in `lib/app/router.dart`. These registries exist so that a feature never edits a shared file.

## 4. System Context

```text
Flutter clients (Android, iOS, web panel)
      │ HTTPS/JSON
      ▼
Laravel modular monolith
 ├─ Auth / Authorization
 ├─ Catalog / Cart / Orders
 ├─ Shopping / Approvals
 ├─ Payments / Refunds
 ├─ Delivery / Operations
 └─ Notifications
      │
 ├─ PostgreSQL
 ├─ Laravel Filesystem (public product images)
 ├─ database queue + scheduler
 └─ adapters: Telegram Gateway, SMS (Eskiz), FCM, Payme, Click, Paynet, xazna
```

## 5. Style

Modular monolith. No microservices, message brokers, Kubernetes, mandatory Redis, Elasticsearch, GraphQL, WebSockets or separate analytics database. Order, shopping, approval, payment and delivery share one transactional PostgreSQL model.

## 6. Backend Responsibility Flow

```text
HTTP boundary (Form Request, thin controller)
→ Application action (one use case)
→ Domain policy or calculator where logic is reusable
→ Eloquent / PostgreSQL / adapters
→ Resource
```

Representative actions: `RequestCustomerLoginCode`, `VerifyCustomerLoginCode`, `AuthenticateStaff`, `ChangePassword`, `PreviewCheckout`, `CreateOrder`, `EditOrderItems`, `CancelOrder`, `AssignShopper`, `AcceptShoppingAssignment`, `StartShopping`, `RecordPurchasedItem`, `MarkItemUnavailable`, `ProposeSubstitution`, `RequestApproval`, `DecideApproval`, `ExpireApprovals`, `CompleteShopping`, `InitiatePaymentAttempt`, `ApplyProviderPaymentEvent`, `ReconcilePayment`, `SwitchOrderToCash`, `AssignCourier`, `StartDelivery`, `CompleteDelivery`, `FailDelivery`, `CompleteRefund`.

Representative domain components: `CustomerPriceCalculator`, `QuantityPolicy`, `SubstitutionPolicy`, `ApprovalPolicy`, `MoneyCalculator`, `ServiceFeeCalculator`, `OrderLifecycle`, `CancellationPolicy`, `PaymentPolicy`, `ServiceAreaPolicy`, `WorkingHours`.

## 7. Single-Business Boundary

Not multi-tenant. No tenant, market or city ownership columns.

## 8. Identity and Authentication

**Customer:** `phone → login code → customer → Sanctum token`. The code is six digits, hashed at rest, valid five minutes, five failed verifications, sixty seconds between sends, five sends per phone per hour. Delivery goes through the `CodeDeliveryGateway` abstraction with three implementations: Telegram Gateway, SMS (Eskiz), and a fake that records codes in a test-only in-process sink. The gateway selection: Telegram when the provider reports the number has a Telegram account, otherwise SMS when configured, otherwise (development) the fake. **Test phone numbers:** configuration lists phone numbers and one fixed code; a listed number verifies with that code and no delivery is attempted; the list is empty in production and is never an Admin setting.

**Staff:** `phone + password → role → Sanctum token`, with the first-login gate. Rate limits: five failed logins per phone per minute and twenty per IP per minute; five failed `current_password` checks per token per minute on password change. No account lockout.

**Tokens:** bearer on every surface, including the web panel; 30 days sliding from last use; several per account; all deleted on blocking, and status re-checked on every request. Sanctum's SPA cookie mode and CSRF are not used; the web panel's origin is allowed by CORS configuration.

**Two sessions on one device** for Customer mode: the client keeps a staff slot and a customer slot and sends the token of the active mode. A refused token ends only its own session.

## 9. Authorization Layers

1. authenticated token; 2. active account and password gate; 3. role capability; 4. ownership or current-assignment scope; 5. lifecycle condition; 6. current state under lock where race-sensitive. A UUID is never authorization. Operator capabilities are a subset of Admin capabilities enforced per endpoint.

## 10. Catalog and Media

Relational catalog with paired language columns. Server-side PostgreSQL search over `lower(name_uz)` and `lower(name_ru)`. Product image metadata in PostgreSQL, bytes on the Laravel public disk in development and S3-compatible storage in production, served from public URLs with long cache headers; the URL changes when the image changes.

## 11. Address and Map

The backend stores coordinates and text and validates the service-area circle by great-circle distance from the configured centre. The client uses Yandex MapKit for the picker; the backend has no map dependency.

## 12. Order Aggregate

```text
Order
 ├─ items (with both-language snapshots)
 ├─ history (status changes, edits, switches, corrections, assignment events)
 ├─ shopper assignments
 ├─ courier assignments
 ├─ approvals
 ├─ cancellation requests
 ├─ payment (cash record or online obligation) → attempts → provider events
 ├─ refunds (manual)
 └─ price corrections
```

## 13. Snapshot Boundary

At creation: product names in both languages, unit, price mode, market price, customer unit price, ordered quantity, note, substitution rule per line; recipient name and phone; address coordinates and text; markup percentage, tolerance percentage, service fee rule, delivery fee, delay threshold; payment method. An edit before shopping adds new lines with fresh line snapshots and leaves every other snapshot as it was (`DL-6`). Later catalog or settings changes never touch them.

## 14. Money and Quantity

Money `bigint` UZS; percentages `numeric(5,2)`; quantities `numeric(18,3)` with unit precision rules; every rounding half-up to 1 UZS in one `MoneyCalculator`. The client sends quantities and percentages as strings.

## 15. Order Lifecycle

```text
new → shopping_assigned → shopping → [final_payment_pending] → ready_for_delivery
    → delivery_assigned → on_the_way → completed
cancelled from any non-terminal state under the rules of 05 Section 15
```

`final_payment_pending` only for online orders. Awaiting-customer is derived from pending approvals. Every transition is an explicit action writing `order_history`.

## 16. Transactions and Concurrency

Transactions with row locks (`SELECT … FOR UPDATE` on the order row) for: order creation and cart conversion, editing, assignment, shopping start and completion, item recording, approval creation and decision and expiry, payment creation, provider events and reconciliation, switch to cash, cancellation and its decisions, delivery start, completion and failure, refund completion. Lock order: order, then items, then payment. Fresh locked state wins over a stale client.

## 17. Persisted Idempotency

```text
IdempotencyStore
  begin(actor, operation, key, request_hash)  → new | replay(resource) | in_progress | conflict
  complete(resource reference)
```

Unique `(actor_user_id, operation, idempotency_key)`, request hash, state `processing` or `completed`, and a 60-second lease on `processing`. Same key and hash while completed → the same logical result. Same key inside the lease → `409 idempotency_in_progress`. Same key after the lease with no completion → the operation runs again and takes the row over. Different hash → `409 idempotency_key_reused`. Provider callbacks use provider event identity instead.

## 18. Assignment

One current Shopper assignment and one current Courier assignment per order; history kept; accept before start; reassignment before start of work; `is_self_order` computed at assignment from the phones.

## 19. Approvals

A persisted immutable proposal with `attention_at = created + 10 min` and `expires_at = created + 30 min`. The scheduler runs the idempotent `ExpireApprovals` action every minute; reads also reconcile on the way through so a late scheduler never lets an expired approval be approved. Approval outcome is written onto the item (ceiling, replacement authorization, quantity cap) and the item returns to `pending`.

## 20. Payments

```text
Order → PaymentService → cash record | online obligation → provider adapter (Payme, Click; Paynet, xazna later)
```

Cash: a payment row `method = cash` created `paid` by the Courier's delivered action with the amount. Online: an obligation `method = online, status = unpaid` created at shopping completion with `attention_at = +30 min`; it becomes `pending` while an attempt is in flight or unknown and returns to `unpaid` when that attempt fails; attempts run against a chosen enabled provider; provider event → deduplicate by `(provider, event_key)` → normalize → apply under lock; success sets `paid` and moves the order to `ready_for_delivery`. Adapters hold transport, signing and parsing only. Merchant credentials live in backend configuration.

## 21. Reconciliation

An attempt `pending` for longer than the provider timeout (15 minutes) is "unknown". The scheduler asks the provider for its state; the answer is applied like an event. No new attempt is allowed on an obligation with a pending or unknown attempt.

## 22. Refunds

A `refunds` row is created when a paid online order is cancelled. Completion is manual: Admin records the provider reference. The system never calls a refund API in the MVP.

## 23. Code Delivery

`CodeDeliveryGateway` with `TelegramGatewayCodeDelivery`, `EskizSmsCodeDelivery` and `FakeCodeDelivery`. No code value is ever logged or returned. Provider credentials are configuration.

## 24. Notifications

`NotificationService` with an FCM adapter and a fake. The domain emits intents (`event type`, `user`, `order or approval ID`); a queued job renders the title and body from the two-language template set by `users.preferred_language` and sends a push whose data carries the event type and the ID only. Delivery rows are recorded; failure never rolls anything back. A device registers its token once per signed-in account; the Shopper's order screen polls every few seconds in the foreground and the client suppresses foreground banners for events the screen already shows.

## 25. Queue and Scheduler

Laravel database queue in PostgreSQL. Scheduler jobs: approval attention and expiry, unpaid-online attention, payment reconciliation, delay attention refresh. Correctness never depends on scheduler latency alone: every read path reconciles what it shows.

## 26. Time

Backend `Clock` in UTC; `Asia/Tashkent` for display and for working hours; device clocks are never authoritative.

## 27. Flutter Architecture

```text
Presentation → Riverpod controller → repository contract → repository → API data source / DTO → the one Dio client
```

Layout, fixed:

```text
lib/
  app/        root router and root providers
  core/       everything no single feature owns: network, storage, theme, error mapping, localization, formatting, routing registry, config, map
  features/<feature>/{data,domain,application,presentation}
```

Features: auth, catalog, profile, addresses, cart, orders, shopper, approvals, payments, courier, operations, admin, notifications, history. The web panel is the same application built for web with the operations and admin features; mobile builds carry the customer, shopper and courier features. A role that lands on the wrong surface sees a screen naming the right one.

Languages: Uzbek (Latin) and Russian; the client owns every user-facing string, renders text from machine codes, and never displays the API `message`. Language: device default, in-app switch, stored on the device and reported through `PATCH /auth/me`.

Money renders as `150 000 so'm` / `150 000 сум`; phones as `+998 90 123 45 67`.

Design: no brand assets exist. The client ships a text logo "BarakaBozor", the green seed colour already in `core/theme`, and standard Material 3 components; colours and logo live in one place so a designer can replace them later. The Shopper's price entry asks for confirmation when the entered market price is more than three times or less than a third of the estimate's market price (`DL-3`, S-35).

## 28. Async and Session Safety

Session, target and operation identity guard every async completion; a result that completes after a mode switch or an account change is discarded. Payment, approval and order actions suppress duplicate submission and reconcile from the server after an uncertain outcome. A failed load is never retried automatically: the screen shows the reason and a retry the person presses (`DL-28` (12)).

## 29. Navigation

Areas: `/auth`, `/customer`, `/shopper`, `/courier`, `/operations`, `/admin`, `/manager`. Guards are UX; the backend is the authority.

One session guard decides every navigation from the session state and the surface (`DL-15`): the bootstrap screen until the session is known, the retry screen if the bootstrap threw; signed out, only the login screens; unreachable, only the retry screen; a role on the wrong surface, only the screen naming the right one; the first-login gate, only the password change; otherwise the active role's area. The router re-evaluates the guard whenever the session changes, so a login, a mode switch or a dropped session moves the interface without any screen navigating. The login screens are flat routes with their own way back, never pages stacked over one another.

## 30. API Style

Versioned JSON REST under `/api/v1`; envelopes, strict request shape, pagination, error codes with an optional `details` object, idempotency headers — all in `09`. The backend performs no locale negotiation; `message` is developer English.

## 31. PII and Logging

Logs carry request ID, actor ID and role, order and payment IDs, action and safe error category. Never passwords, login codes, tokens, provider secrets, raw provider payloads. Shopper screens omit the address; Courier screens carry only the delivery data.

## 32. Figures

Deferred. When built: read-only aggregates over the authoritative tables, no warehouse.

## 33. Testing

Backend unit: price and money calculators, quantity, substitution and approval policies, lifecycle, cancellation, idempotency, service area, working hours. Backend feature (against PostgreSQL): auth and gates; role, ownership and assignment negatives; catalog, cart, checkout, order creation and editing; shopping and approvals; payments with fake providers including failure and unknown paths; delivery; operations and admin boundaries. Frontend: DTO parsing from the examples in `09`, request construction, repository failure mapping, controller transitions, session isolation, route guards, screen states. End to end before each wave closes: the real stack, the wave's scenario.

No code path may present a fake provider result as real.

## 34. Production Topology

```text
Internet → reverse proxy with TLS → Laravel (php-fpm) → PostgreSQL
                                  ├─ queue worker
                                  ├─ scheduler
                                  ├─ object storage (images)
                                  └─ Telegram / SMS / FCM / payment APIs
web panel: static build behind the same proxy
```

One Ubuntu VPS in Uzbekistan running Docker Compose, nightly database backups off the host. The proxy is named in `TRUSTED_PROXIES` so the application sees the client's address; without that, the per-IP login limit would count every client as the proxy.

## 35. Non-Goals

Microservices, brokers, Kubernetes, mandatory Redis, Elasticsearch, GraphQL, WebSockets, separate analytics database, multi-tenant foundation, live GPS, automatic dispatch, offline shopping mode, AI, warehouse.

## 36. External Gates

`06` Section 5. Published protocol documentation permits a thin adapter; credentials are needed to verify it. Never invent a protocol; never present a fake result as real.
