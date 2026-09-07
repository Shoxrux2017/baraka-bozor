# BarakaBozor — Architecture

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## 1. Architecture Goals

The MVP architecture must provide backend-authoritative business/financial state, historical Order stability, strong role/ownership/assignment/lifecycle authorization, transaction-safe quantity/payment/refund behavior, vertical Stage development, and simple deployment without speculative distributed infrastructure.

## 2. Technology Baseline

### Backend

```text
PHP 8.3+
Laravel 13
Laravel Sanctum
PostgreSQL
PHPUnit
Laravel Pint
```

### Frontend

```text
Flutter / Dart
Riverpod
GoRouter
Dio
flutter_secure_storage
Material 3
```

One Flutter codebase supports mobile Customer/Shopper/Courier and desktop Operator/Admin/Manager surfaces.

## 3. Repository Baseline

```text
baraka-bozor/
  AGENTS.md
  docs/01–09
  tasks/
  backend/AGENTS.md
  backend/...
  frontend/AGENTS.md
  frontend/...
  docker/
```

## 4. System Context

```text
Flutter clients
     │ HTTPS/JSON
     ▼
Laravel modular monolith
 ├─ Auth/Authorization
 ├─ Catalog/Cart/Orders
 ├─ Shopping/Approvals
 ├─ Payments/Refunds
 ├─ Delivery/Operations
 └─ Analytics
     │
 ├─ PostgreSQL
 ├─ Laravel Filesystem
 ├─ Queue/Scheduler
 └─ external adapters
      ├─ SMS
      ├─ Payme
      ├─ Paynet
      ├─ xazna
      ├─ Click
      └─ FCM
```

## 5. Architectural Style

Use a **modular monolith**. Do not start with microservices, event sourcing, Kafka/RabbitMQ, Kubernetes, mandatory Redis, Elasticsearch, GraphQL, or separate analytics database.

Order, Shopping, Approval, Payment, Refund, and Delivery are strongly connected and benefit from one transactional PostgreSQL model.

## 6. Backend Responsibility Flow

```text
HTTP boundary
→ Application Action
→ Domain Policy/Service
→ Eloquent/PostgreSQL/Infrastructure
→ Resource/response
```

Controllers parse/validate allowed input, resolve actor, call one Action, map expected failures, return Resource. Complex lifecycle/transaction logic does not belong in Controllers.

Representative Actions: `RequestCustomerOtp`, `VerifyCustomerOtp`, `AuthenticateStaff`, `ChangePassword`, `PreviewCheckout`, `CreateOrder`, `AssignShopper`, `AcceptShoppingAssignment`, `StartShopping`, `RecordPurchasedItem`, `RequestCustomerApproval`, `RespondToApproval`, `CompleteShopping`, `InitiatePayment`, `ApplyProviderPaymentEvent`, `ReconcilePayment`, `CreateRefund`, `AssignCourier`, `AcceptDeliveryAssignment`, `StartDelivery`, `CompleteDelivery`, `CancelOrder`.

Representative Domain components: `PricingPolicy`, `QuantityPolicy`, `SubstitutionPolicy`, `ApprovalPolicy`, `MoneyCalculator`, `ServiceFeeCalculator`, `OrderLifecycle`, `CancellationPolicy`, `PaymentPolicy`, `RefundPolicy`, `DeliveryPolicy`.

## 7. Single-Business Boundary

MVP is not multi-tenant SaaS. Do not add tenant/company/market/city ownership solely for future expansion. One business, one market/region. Multi-market/city requires later architecture revision.

## 8. Identity and Authentication

Customer: `phone → OTP → customer → Sanctum token`, no password.

Staff: `phone + password → Staff role → Sanctum token`.

Admin-created Staff begins `must_change_password=true`; backend blocks normal actions until password change, allowing only `/auth/me`, password change, logout.

Flutter stores bearer token using secure platform storage. Backend re-reads current user role/status; valid token never overrides `blocked`.

## 9. Authorization Layers

1. authenticated token;
2. active account / password-change gate;
3. role capability;
4. ownership/assignment scope;
5. lifecycle/business condition;
6. current authoritative state under lock where race-sensitive.

Direct UUID is never authorization.

## 10. Catalog and Media

Catalog is relational PostgreSQL. MVP Product search is server-side PostgreSQL; no Elasticsearch.

Product image metadata is PostgreSQL, bytes through Laravel Filesystem. One current image; JPEG/PNG/WebP <=5 MB. Development may use local storage; production may use S3-compatible storage without domain change.

## 11. Customer Address / Map

Backend stores structured address + coordinates and remains map-vendor neutral. Flutter map point-picker is selected during Stage 3 planning. Automatic geocoding is optional and not authoritative delivery requirement.

## 12. Order Aggregate Boundary

```text
Order
 ├─ historical Order Items
 ├─ status history
 ├─ Shopper assignment history
 ├─ Customer Approvals
 ├─ cancellation requests
 ├─ Payments / Attempts / Provider Events
 ├─ Refunds / Attempts
 └─ Courier assignment history
```

Do not store business aggregate as uncontrolled JSON blob.

## 13. Historical Snapshot Boundary

At Order creation persist original Product name/unit/price mode/fixed/range values, ordered quantity/note/substitution policy, recipient name/phone, Address coordinates/text, Service fee rule, Delivery fee, selected Payment provider. Current Catalog/settings changes never rewrite these.

## 14. Money and Quantity

- money: integer UZS;
- Service percentage: decimal;
- quantity: decimal-compatible with unit-specific rules;
- line totals and percentage Service fee: deterministic half-up to 1 UZS.

Flutter sends quantity/percentage decimal values as strings.

## 15. Order Lifecycle

```text
checkout_payment_pending
new
shopping_assigned
shopping
approval_required
final_payment_pending
ready_for_delivery
delivery_assigned
on_the_way
completed
cancelled
```

No generic status PATCH. Explicit Actions own transitions. `approval_required` is Order projection while at least one Item awaits Customer; other eligible Shopping Items may continue.

## 16. Transactions and Concurrency

Use PostgreSQL transactions for multi-record invariants and row locks when current state must serialize competing mutations.

Lock-sensitive families include Order creation/Cart conversion, assignments, Shopping start/completion, Approval decision/expiry fallback, Payment/refund creation/events/reconciliation, cancellation decision, delivery start/completion.

Fresh locked state wins over stale Flutter state.

## 17. Persisted Idempotency Architecture

High-risk Flutter mutations use one persisted boundary:

```text
IdempotencyStore
  begin(actor, operation, key, request_hash)
  complete(resource reference)
```

PostgreSQL stores unique `(actor_user_id, operation, idempotency_key)` + request hash + logical resource reference. Same key/request returns same logical result; same key/different request conflicts. Provider callbacks use provider-event identity instead.

## 18. Shopper/Courier Assignment

Current assignment unique/Order and history retained. Assignment must be accepted before work begins. Shopper reassignment only before Shopping starts; Courier reassignment only before `on_the_way`.

## 19. Customer Approval Architecture

Approval is first-class persisted proposal, immutable after creation except resolution. Scheduler/request-time reconciliation uses same idempotent expiration action.

`attention_at=created+10m`, `expires_at=created+30m`. Expiration never authorizes Customer spending; Operator/Admin fallback is Item removal only.

## 20. Payment Architecture

```text
Order
→ Payment application/orchestrator
→ provider adapter
   ├─ Payme
   ├─ Paynet
   ├─ xazna
   └─ Click
```

Common business capabilities: create Payment obligation, initiate Attempt, validate/normalize provider inbound request, reconcile state, create/process Refund. Provider-specific signatures/routes/merchant auth/responses remain inside adapters based on official docs.

## 21. Payment Event Boundary

```text
provider request
→ provider-specific auth/signature validation
→ provider-event deduplication
→ normalize outcome
→ transaction/lock Payment
→ update Attempt/Payment/Order
→ queue secondary notifications
```

Merchant credentials/private keys are backend configuration only and never Flutter/API data.

## 22. Refund Architecture

Refund is first-class entity with provider Attempts. Successful refund total is transactionally constrained not to exceed successful Payment amount. Pending overpayment Refund does not block delivery when Customer has already paid enough for final total.

## 23. SMS OTP Architecture

Domain uses `SmsGateway` abstraction. OTP generation/hash/expiry/attempts/rate limit are backend responsibilities. Production OTP is never logged. Exact OTP policy is fixed in API; actual SMS vendor is Stage 1 external gate.

## 24. Notification Architecture

Use `NotificationService` abstraction with FCM adapter for MVP mobile push. Domain emits semantic intents, not Firebase calls. Notification delivery is asynchronous/secondary and failure never rolls back valid Order/Payment transition.

## 25. Queue and Scheduler

Baseline may use Laravel database queue with PostgreSQL to avoid mandatory Redis.

Scheduler/request-time idempotent reconciliation handles Approval attention/expiry, unpaid fixed checkout cancellation, Payment/refund reconciliation, and operational attention refresh. Correctness must not depend only on scheduler latency.

## 26. Time

Backend `Clock` provides authoritative UTC time. `Asia/Tashkent` is MVP business display default; device clock not authoritative.

## 27. Flutter Architecture

```text
Presentation
→ Riverpod Controller/Notifier
→ Repository contract
→ Repository implementation
→ API Data Source / DTO
→ configured Dio
```

Widgets never call Dio or parse raw JSON directly. Logical features: auth, catalog, profile, addresses, cart, orders, shopper, approvals, payments, courier, operator, admin, notifications, history, analytics.

## 28. Flutter Async Safety

Session/target/operation identity prevents stale async completion from leaking prior Customer/Order/account into current UI. High-risk Payment/Approval/Order operations suppress duplicate submissions and reconcile server state after uncertain outcomes.

## 29. Navigation

Role-aware areas: `/auth`, `/customer`, `/shopper`, `/courier`, `/operator`, `/admin`, `/manager`. GoRouter guards improve UX; backend remains authority.

## 30. API Style

Versioned JSON REST `/api/v1`. Success/error envelopes, strict request shape, pagination, error codes, idempotency headers, and endpoints are in `09-api-contracts.md`.

## 31. PII and Logging

Logs may contain request ID, actor ID/role, Order/Payment ID, action, safe error category. Never passwords, OTPs, bearer tokens, merchant secrets/private keys, sensitive raw provider/card credentials. Shopper/Courier/Manager receive only necessary data.

## 32. Analytics

Use PostgreSQL read/aggregate queries over authoritative business state. No separate analytics database/warehouse in MVP.

## 33. Testing Architecture

Backend unit/domain: pricing/quantity/substitution/approval, money rounding/fees, lifecycle/cancellation/refund, idempotency, delay.

Backend feature: Auth/OTP/first-login/blocking; role/ownership/assignment negatives; Catalog/Cart/Checkout; Order snapshots/idempotency; Shopping/Approval; Payment/refund replay/reconciliation; Delivery; Operator/Admin/Manager boundaries.

Frontend: strict DTOs, request construction/failure mapping, Riverpod transitions, session/stale-result isolation, route guards, loading/error/data/empty, Payment unknown state, responsive role surfaces.

Integration: real Flutter → Laravel → PostgreSQL plus provider sandbox/test checks at relevant gates.

## 34. Production Topology

```text
Internet
→ HTTPS reverse proxy
→ Laravel API
   ├─ PostgreSQL
   ├─ Queue worker
   ├─ Scheduler
   ├─ File/object storage
   └─ external SMS/Payment/FCM APIs
```

## 35. Architecture Non-Goals

No microservices, Kafka/RabbitMQ, Kubernetes, mandatory Redis, Elasticsearch, GraphQL, WebSockets, separate analytics DB, multi-tenant/multi-market foundation, live GPS, automatic dispatch, offline-authoritative mutation sync, AI, warehouse/inventory subsystem.

## 36. External Integration Gates

Provider facts remain explicit implementation gates: selected SMS vendor, Flutter map/tile provider, Firebase config, and official Payme/Paynet/xazna/Click merchant protocols/credentials. Codex must not invent protocols or fake production success.
