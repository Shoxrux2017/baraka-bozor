# BarakaBozor — Roadmap

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

**Amended 2026-09-21** by Project Owner approval: Sections 1, 2, 4, 10, 16, 17 and 18 move execution from twelve serial stages to six waves with concurrent tracks. See `AUD-022` in `CONTRACT_ALIGNMENT_REPORT.md`. Stage **content** in Sections 3–15 is unchanged apart from the two provider gates named in Sections 4 and 10.

## 1. Roadmap Principle

Build in waves. Each wave runs several vertical tracks concurrently, then closes as one unit:

```text
wave planning gate (decisions resolved, then frozen for the wave)
→ concurrent tracks, each carrying backend and frontend for its own feature
→ backend block review + frontend block review
→ wave integration gate
→ wave closure
```

A later wave does not begin until the current wave is explicitly closed. Inside a wave, concurrency is bounded by the wave's declared width and by the path ownership map in `tasks/OWNERSHIP.md`.

Frontend work does not wait for backend code. Both sides implement the same locked contract in `09-api-contracts.md`, guarded by the shared fixtures required in `07-architecture.md` Section 33.

What this model deliberately keeps serial — the Cart to Order to purchase to Approval chain, and financial-invariant work under one owner per wave — its rationale and its risks are recorded in `docs/superpowers/specs/2026-09-21-parallel-execution-model-design.md`, approved by the Project Owner on 2026-09-21.

## 2. MVP Waves

| Wave | Name | Main outcome | Max concurrent tracks |
|---:|---|---|---:|
| 0 | Foundation | runnable stack, required CI, six secure role entries | 3 |
| 1 | Catalog and Account | Admin Catalog, Customer read/search, Customer profile and Addresses, Staff administration | 5 |
| 2 | Cart, Order and Money | checkout-ready Cart, stable Order snapshots/lifecycle foundation, payment adapters on published protocols | 3 |
| 3 | Fulfilment and Exceptions | real market Shopping, real exception/Customer decision workflow, physical delivery, operational workspace | 4 |
| 4 | Demonstrable MVP | complete Customer post-order experience, read-only business KPI, full end-to-end scenarios on fake providers | 3 |
| 5 | Providers and Launch | Payme/Paynet/xazna/Click financial flow, production-like E2E/security/quality gate, pilot readiness | 2 |

Stage 0 — Product & Engineering Foundation — is closed and is not a wave.

Where the original twelve stages went:

| Original stage | Wave |
|---|---|
| 1 Authentication & Role-Based Entry | 0 |
| 2 Catalog & Pricing | 1 |
| 3 Customer Profile, Address & Cart | 1 (profile, Addresses), 2 (Cart, map picker) |
| 4 Checkout, Fees & Order Core | 2 |
| 5 Shopper Assignment & Market Purchase | 2 (assignment abstraction), 3 (market purchase) |
| 6 Availability, Substitution & Approval | 3 |
| 7 Online Payments & Refunds | 2 (adapters on published protocols), 5 (real merchant integration, live reconciliation) |
| 8 Courier Delivery | 2 (assignment abstraction), 3 (delivery) |
| 9 Operator & Admin Operations | 1 (Staff administration, settings, provider enablement), 3 (Order board, exceptions, cancellation decisions, audited price correction) |
| 10 Notifications, History & Reorder | 1 (device registration, notification infrastructure), 4 (events, history, Reorder) |
| 11 Manager Analytics | 4 |
| 12 MVP Integration & Pilot Readiness | 4 (fake-provider scenarios), 5 (provider sandbox, release build, performance, security review, pilot) |

Sections 3–15 below define the content of each original stage. They remain the authoritative description of **what** must be built and are unchanged except where a provider gate moved. Section 2 maps that content onto waves; `tasks/WAVE_<N>_TASK_INDEX.md` defines execution order inside a wave.

## 3. Stage 0 — Product & Engineering Foundation

Create locked `docs/01–09`, repository foundation, root/backend/frontend `AGENTS.md`, `tasks/README.md` and templates, cross-document audit, initial GitHub baseline.

Stage 0 closes only after locked docs/workflow controls are in real repository, accepted baseline is on `origin/main`, and Stage 1 task decomposition is approved.

## 4. Stage 1 — Authentication & Role-Based Entry

Backend: Laravel/PostgreSQL foundation, users/Sanctum, Customer OTP, Staff login, first-login password gate, blocking, six-role authorization, first Admin CLI bootstrap.

Flutter: Riverpod/GoRouter/Dio/secure-storage foundation, Customer OTP UI, Staff login/password-change, role shells, session/account-switch isolation.

**External gate:** selected SMS vendor documentation/credentials. Core Auth proceeds behind the `SmsGateway` abstraction with a fake gateway, and Wave 0 closes on that fake. The approved real or sandbox SMS integration path is a **Wave 5** closure requirement, because the vendor contract and alpha-name registration require a registered legal entity that does not yet exist. The debt is recorded, not dropped.

## 5. Stage 2 — Catalog & Pricing

Categories, Products, one image (JPEG/PNG/WebP <=5MB), units, pricing constraints, archive/restore, Customer Catalog/search/product detail, Admin Catalog/pricing UI.

## 6. Stage 3 — Customer Profile, Address & Cart

Customer name/profile, checkout-ready Addresses, map point-picker, one active Cart, quantity precision, notes/substitution policies, current-pricing presentation.

**External gate:** select Flutter map/tile provider/package before map-picker implementation. Backend remains vendor-neutral.

## 7. Stage 4 — Checkout, Fees & Order Core

Business fees, checkout pricing-summary kinds, signed 5-minute token, Order idempotency, Cart conversion/new Cart, historical snapshots, `checkout_payment_pending`/`final_payment_pending`, Order/Item/status history.

## 8. Stage 5 — Shopper Assignment & Market Purchase

Admin Shopper assignment/reassignment before start, accept/start, assignment authorization, purchased/billable quantity, fixed/range/at_purchase processing, automatic structured replacements where allowed, dynamic price capture, half-up line calculations, Shopping completion for no-pending-Approval paths.

## 9. Stage 6 — Availability, Substitution & Approval

Unavailable workflows, range-over-max, reduced quantity, substitution Approval, +10m attention/+30m expiry, Customer decision, expired remove-only fallback, `approval_required` with continued unrelated Shopping, Customer/Shopper/Operator integration.

## 10. Stage 7 — Online Payments & Refunds

Payment obligations/Attempts, persisted idempotency, Payme/Paynet/xazna/Click adapters, official callback authentication, provider-event deduplication, reconciliation, prepaid/deferred/additional Payment, partial/full Refund, retry/reconciliation, client pending/failed/unknown/success UX.

**External gates:** official merchant documentation, and valid sandbox/test credentials or an approved provider test path. These two are now separated. Official **published** protocol documentation is enough to implement the thin adapter in Wave 2; the adapter carries transport, signing and response parsing only, while obligations, attempts, idempotency, reconciliation and refunds stay provider-agnostic. **Credentials remain mandatory** for verification and for Wave 5 closure. Missing access = `BLOCKED`, never fake success, and no invented protocol.

## 11. Stage 8 — Courier Delivery

Admin Courier assignment/reassignment before start, accept/start/delivered, assignment-scoped PII, delay snapshot/attention, Customer tracking. No live GPS/proof photo/signature/OTP.

## 12. Stage 9 — Operator & Admin Operations

Operational Order board, attention filters, no-response/expired Approval, Payment/refund problems, cancellation decisions, Staff create/activate/block/reset, self/last-admin protections, settings/provider enablement, audited dynamic price correction.

## 13. Stage 10 — Notifications, History & Reorder

FCM device registration, required Customer events, notification retry state, history, Reorder original Product + current Catalog, duplicate/unavailable reporting.

**External gate:** Firebase project/config before notification integration closure.

## 14. Stage 11 — Manager Analytics

Read-only aggregates using fixed KPI definitions. No BI/data warehouse/AI analytics.

## 15. Stage 12 — MVP Integration & Pilot Readiness

Real scenarios: fixed prepaid, deferred dynamic, range Approval, substitution/reduced quantity, excess purchase not billed, failed/unknown Payment, overpayment Refund, cancellation+Refund, Courier delay, Reorder, authorization negatives, blocked Staff token rejection.

Includes full backend/frontend suites, required release build, PostgreSQL migrations, provider sandbox checks, manual role smoke, security/financial integrity review, performance checks, and implementation-vs-doc review.

## 16. Standard Wave Definition of Done

Wave closes only when approved behavior is implemented, backend security/business rules are enforced, required Flutter uses real API, tasks accepted/delivered, checkpoints/integration pass, no P1/P2 remains, docs/bookkeeping current, accepted result on `origin/main`, local `main` synchronized/clean.

Two additions the wave model requires: the wave's financial-invariant handover is recorded (Section 1), and every task in the wave was merged on a green CI run of the head that was actually merged.

Nothing in this definition is relaxed by running tracks concurrently. Only its unit changed from Stage to Wave.

## 17. Task Planning Rule

Roadmap defines the wave boundary; `WAVE_<N>_TASK_INDEX.md` defines execution order and each track's declared width. Detailed implementation contracts are prepared/hardened in execution order, not speculatively for the whole project. A wave's specification decisions are resolved at its planning gate and then frozen for the wave.

## 18. Post-MVP Boundary

Do not pull into any wave: multiple markets/cities, Seller marketplace, live GPS, automatic dispatch, AI/voice/Telegram, bonus/cashback/subscriptions, complex promotions, warehouse/inventory planning, custom roles, post-delivery claims/returns.
