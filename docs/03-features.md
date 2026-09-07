# BarakaBozor — Features

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## 1. MVP Feature Overview

The MVP must support one complete vertical workflow:

```text
Authentication
→ Catalog
→ Cart / Address
→ Checkout / Order
→ Market Shopping
→ Approval / Final Pricing where required
→ Online Payment
→ Courier Delivery
→ History / Reorder
```

Supporting operational features are Admin, Operator, Notifications, and Manager Analytics.

## 2. Authentication and Session

### Customer

- phone + SMS OTP registration/login;
- current-session bootstrap;
- logout;
- account creation on first verified phone;
- server-authoritative Customer role.

### Staff

- phone + password login;
- Admin-created accounts;
- temporary password;
- mandatory first-login password change;
- active/blocked enforcement;
- server-authoritative role-aware entry.

## 3. Customer Profile

Customer can view/update approved profile fields. `full_name` may be empty immediately after OTP registration, but checkout requires non-empty Customer name. Phone is authentication identity and is not changed through normal profile edit.

## 4. Delivery Addresses

Customer can create/view/edit/deactivate own Addresses.

Required for checkout eligibility: latitude, longitude, street, house. Optional: label, apartment, landmark, Courier delivery note.

MVP requires map-point selection but no specific map vendor.

## 5. Catalog

Admin-managed dynamic Categories and Products with Customer active-list/search access.

Product fields include name, description, Category, unit, availability/archive state, one current image, and pricing.

Product image: JPEG/PNG/WebP, maximum 5 MB, backend-authoritative validation.

## 6. Pricing

Supported:

```text
fixed
range
at_purchase
```

- `fixed`: one authoritative checkout unit price;
- `range`: accepted min/max and actual dynamic unit price during Shopping;
- `at_purchase`: price unknown at checkout and recorded by Shopper.

Historical Order pricing never follows later Catalog changes.

## 7. Quantity

- `kg`, `liter`, `meter`: positive decimal with up to 3 fractional digits;
- `gram`, `piece`, `package`, `box`, `bundle`: positive integer.

Ordered, purchased, and billable quantities remain distinct.

## 8. Cart

One active Cart per Customer. Customer can add a Product once, change quantity, update note/substitution policy, remove an Item, and review current pricing state. Cart is not historical.

## 9. Checkout Preview

Uses current Cart, profile, selected own Address, Product pricing, active fees, and selected enabled Payment provider.

Pricing summary kinds:

```text
final
estimate_range
contains_unknown
```

- all fixed → final authoritative total;
- fixed/range without `at_purchase` → estimated min/max;
- any `at_purchase` → no fake total; unknown-price flag and known components only.

Backend returns a signed short-lived checkout token validated again at Order creation.

## 10. Order Creation

Order creation snapshots Product/quantity/pricing/Customer/Address/fees/provider, determines prepaid/deferred flow, converts source Cart, creates a new empty active Cart in the same transaction, and is idempotent.

## 11. Order Lifecycle

Authoritative machine states:

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

No generic arbitrary status update exists. Customer-facing labels may map multiple machine states to one display label.

## 12. Shopper Assignment and Shopping

Admin manually assigns active Shopper. Shopper can accept, start, process assigned Items, record purchased quantity, record dynamic actual price, mark unavailable, propose replacement, request approval, continue other Items while one Item awaits Customer, and complete only when all Items terminal and no approval pending.

Normal reassignment after Shopping starts is out of MVP.

## 13. Availability and Substitution

Customer policies:

```text
allow_similar_substitution
contact_before_substitution
remove_if_unavailable
```

Structured replacement uses active Product with compatible unit. Automatic replacement obeys approved price ceiling; `at_purchase` replacement requires explicit approval.

## 14. Customer Approval

Types: `price_over_range`, `substitution`, `reduced_quantity`.

States: `pending`, `approved`, `rejected`, `expired`.

- 10 minutes → Operator attention, still pending;
- 30 minutes → expired;
- approve applies persisted proposal;
- reject removes affected Item;
- expired cannot be approved later;
- Operator/Admin may resolve expired only by removal.

## 15. Final Pricing

- fixed original → billable price = fixed snapshot;
- range → approved/allowed actual price;
- at_purchase → actual price;
- replacement → actual replacement price subject to approval ceiling.

Each `line_total` and percentage Service fee is rounded half-up to 1 UZS. Merchandise subtotal sums rounded line totals.

## 16. Online Payments

Mandatory providers: Payme, Paynet, xazna, Click.

Features: prepaid fixed-order Payment; deferred final Payment; additional Payment when approved recalculation increases prepaid final amount; failed retry; uncertain reconciliation; callback deduplication; provider-authoritative success; provider enablement for new checkout selection.

Raw provider protocol details are provider-specific Stage 7 contracts based on official merchant documentation.

## 17. Refunds

Supports partial overpayment refund, full approved-cancellation refund, provider attempt/reconciliation/retry, and provider-authoritative success. Pending overpayment refund does not block Delivery when Customer has already paid enough to cover final total.

## 18. Cancellation

- before Shopping: Customer can cancel directly;
- after Shopping starts and before `on_the_way`: Customer creates request, Operator/Admin decides;
- `on_the_way` or later: normal cancellation unavailable.

## 19. Courier Delivery

Admin manually assigns active Courier. Courier accepts, views assigned delivery context, starts, and marks delivered. Delay is derived attention, not lifecycle status.

## 20. Operator Operations

Operational board supports Customer no-response, pending/expired Approval, Payment failed/overdue/unknown, Refund failed/unknown, Courier delay, cancellation requests, and other approved problem views. No generic status editor.

## 21. Admin Operations

Catalog/pricing/image management; all-Order view/history; assignment before work starts; Staff create/activate/block/reset; Service/Delivery fee and delay threshold; provider enablement; permitted cancellation/refund management; audited dynamic-price correction before relevant final Payment lock. Existing Staff role mutation is not supported.

## 22. Notifications

Minimum Customer notification events: Order accepted, approval required, Payment required, Courier started, Order delivered. FCM is the approved mobile push mechanism behind an abstraction. Notification failure does not change authoritative Order state.

## 23. History and Reorder

Customer can view own history. Reorder uses original Product IDs from historical Items, applies current availability/pricing, never creates Order automatically, skips current Cart duplicates, and reports unavailable/skipped Products.

## 24. Manager Analytics

Read-only summary/top-Products/Staff-activity features with fixed KPI definitions in Business Rules/API.

## 25. Explicit Post-MVP

Bonus/cashback, recurring shopping, AI recommendations, voice ordering, Telegram bot, live GPS, automatic dispatch, multiple cities/markets, Seller marketplace, complex promotions, warehouse/inventory planning, custom roles, offline-first mutation sync, and post-delivery claims/returns workflow.
