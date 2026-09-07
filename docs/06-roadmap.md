# BarakaBozor — Roadmap

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## 1. Roadmap Principle

Build vertically:

```text
planning gate
→ backend tasks
→ backend checkpoint
→ Flutter tasks
→ frontend checkpoint
→ integration
→ Stage closure
```

Later Stage does not begin until current Stage is explicitly closed.

## 2. MVP Stages

| Stage | Name | Main outcome |
|---:|---|---|
| 0 | Product & Engineering Foundation | locked contracts + repo/workflow baseline |
| 1 | Authentication & Role-Based Entry | six secure role entries |
| 2 | Catalog & Pricing | Admin Catalog + Customer read/search |
| 3 | Customer Profile, Address & Cart | checkout-ready Customer shopping preparation |
| 4 | Checkout, Fees & Order Core | stable Order snapshots/lifecycle foundation |
| 5 | Shopper Assignment & Market Purchase | real market Shopping |
| 6 | Availability, Substitution & Approval | real exception/Customer decision workflow |
| 7 | Online Payments & Refunds | Payme/Paynet/xazna/Click financial flow |
| 8 | Courier Delivery | paid Order through physical delivery |
| 9 | Operator & Admin Operations | production operational workspace |
| 10 | Notifications, History & Reorder | complete Customer post-order experience |
| 11 | Manager Analytics | read-only business KPI |
| 12 | MVP Integration & Pilot Readiness | production-like E2E/security/quality gate |

## 3. Stage 0 — Product & Engineering Foundation

Create locked `docs/01–09`, repository foundation, root/backend/frontend `AGENTS.md`, `tasks/README.md` and templates, cross-document audit, initial GitHub baseline.

Stage 0 closes only after locked docs/workflow controls are in real repository, accepted baseline is on `origin/main`, and Stage 1 task decomposition is approved.

## 4. Stage 1 — Authentication & Role-Based Entry

Backend: Laravel/PostgreSQL foundation, users/Sanctum, Customer OTP, Staff login, first-login password gate, blocking, six-role authorization, first Admin CLI bootstrap.

Flutter: Riverpod/GoRouter/Dio/secure-storage foundation, Customer OTP UI, Staff login/password-change, role shells, session/account-switch isolation.

**External gate:** selected SMS vendor documentation/credentials. Core Auth may proceed, but Stage cannot close without approved real/sandbox SMS integration path.

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

**External gates:** official merchant documentation and valid sandbox/test credentials or approved provider test path. Missing access = `BLOCKED`, never fake success.

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

## 16. Standard Stage Definition of Done

Stage closes only when approved behavior is implemented, backend security/business rules are enforced, required Flutter uses real API, tasks accepted/delivered, checkpoints/integration pass, no P1/P2 remains, docs/bookkeeping current, accepted result on `origin/main`, local `main` synchronized/clean.

## 17. Task Planning Rule

Roadmap defines Stage boundary; `STAGE_<NN>_TASK_INDEX.md` defines execution order. Detailed implementation contracts are prepared/hardened in execution order, not speculatively for whole project.

## 18. Post-MVP Boundary

Do not pull into earlier Stages: multiple markets/cities, Seller marketplace, live GPS, automatic dispatch, AI/voice/Telegram, bonus/cashback/subscriptions, complex promotions, warehouse/inventory planning, custom roles, post-delivery claims/returns.
