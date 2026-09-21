# BarakaBozor — User Roles

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07. Amended 2026-09-21 (AUD-023); see `docs/CONTRACT_ALIGNMENT_REPORT.md`.

## 1. Role Model

The MVP has exactly six primary roles:

```text
customer
shopper
courier
operator
admin
manager
```

Each account has exactly one primary role. No custom roles, multi-role accounts, role switching, or user-created permission sets.

Backend is authoritative for role, account status, record ownership, assignment scope, and lifecycle permissions.

## 2. Authentication Model

### Customer

- self-registers/authenticates with phone + SMS OTP;
- has no password in MVP;
- receives role `customer` from backend;
- cannot select/request another role.

### Staff

`shopper`, `courier`, `operator`, `admin`, `manager` use phone + password.

Staff accounts cannot self-register; Admin creates them except the first bootstrap Admin. New Staff receives a server-generated temporary password and begins `must_change_password=true`. Staff status is `active|blocked`.

The first Admin is created by a controlled one-time Laravel/Artisan bootstrap command. There is no public bootstrap endpoint.

## 3. Role Immutability

Staff role is immutable in MVP. To change a person's operational role, block the old account and create a new account so historical assignments remain attached to the original identity.

The new account uses the **same phone**. This is possible because `phone` uniqueness is scoped to active accounts within an account family — see `08` Section 3 — so the blocked account keeps its real phone and nothing is rewritten. A role change therefore does not require the person to obtain a second number.

The same scoping means a person may hold an active Staff account and an active Customer account on one number. A company employee can order as a Customer; the surfaces never collide because Staff authenticate with a password and Customers with an OTP.

## 4. Customer

Customer may authenticate, manage own profile/Addresses, browse/search Catalog, manage own Cart, create own Order, respond to own Approvals, initiate/retry own Payments, view own Refunds, request cancellation, track delivery, view history, and Reorder.

Customer must not access another Customer's data, choose authoritative role/status, assign Staff, mutate Catalog pricing, set billable quantity/final totals, fabricate Payment/refund success, mark delivery complete, or access internal credential/operational data.

## 5. Shopper

Shopper may view only current assigned Shopping Orders, accept assignment, start Shopping after acceptance, view required Product/quantity/pricing/note/policy data, record purchased quantity, record actual price for `range`/`at_purchase`, use approved structured replacements, mark unavailable, request Customer Approval, continue other non-blocked Items during a pending Approval, and complete Shopping only after all Items are terminal and no Approval is pending.

Shopper must not access unassigned Orders, increase Customer billable quantity because of excess purchase, choose billable prices directly, approve on behalf of Customer, fabricate Payment state, mutate Catalog/fees, assign Staff, or mark delivery complete.

Once Shopping starts, normal Shopper reassignment is not permitted in MVP.

## 6. Courier

Courier may view only current assigned delivery Orders, accept assignment, see required delivery PII, start delivery after acceptance, and mark delivered after physical handover.

Courier must not mutate Shopping, quantities, pricing, Payment/Refund, fees, Catalog, assignment, or another Courier's Order.

Once `on_the_way`, normal Courier reassignment is not permitted.

## 7. Operator

Operator monitors Order flow and permitted operational exceptions. Operator may view operational Orders/attention, contact relevant actors, decide cancellation requests where allowed, resolve expired Approval only by removing affected Item, monitor Payment/Refund state, and record permitted resolution notes/actions.

Operator must not use generic status mutation, approve higher spending/substitution/reduced quantity on Customer's behalf, mutate Catalog/fees, fabricate financial success, manage Staff credentials/roles, or mark delivery complete for Courier.

## 8. Admin

Admin may manage Categories/Products/images/pricing, view all Orders/history, assign/reassign Shopper before Shopping starts, assign/reassign Courier before delivery starts, create Staff, activate/block Staff, reset another Staff user's password, manage fees/delay threshold/Payment-provider enablement, handle approved cancellation/refund operations, and perform audited dynamic-price correction before relevant final Payment lock.

Security boundaries:

- existing Staff role is immutable;
- Admin may not block self;
- Admin may not block the last active Admin;
- Admin never reads an existing password;
- Admin cannot fabricate Payment/refund success;
- Payment secrets are never returned through Admin API;
- normal Order lifecycle still uses explicit domain actions.

## 9. Manager

Manager is read-only and may access approved KPI/analytics data only. Manager does not modify Orders, Catalog, Staff, Payment/Refund, fees, or settings.

## 10. Device Surfaces

| Role | Primary MVP Surface |
|---|---|
| Customer | Mobile |
| Shopper | Mobile |
| Courier | Mobile |
| Operator | Desktop |
| Admin | Desktop |
| Manager | Desktop |

One Flutter codebase provides all role-aware shells.

**Desktop means an installed Windows application**, not a browser surface. Operator, Admin and Manager are company staff at a workstation, and a native surface keeps the bearer token in platform-secured storage as `07` Section 8 requires, which a browser cannot offer. No web build is part of the MVP, and no CORS configuration is therefore needed.

**Mobile means Android and iOS from the same codebase.** Android and Windows are required release targets from Wave 0. An iOS release build becomes a required target in Wave 5, because building and signing for iOS needs macOS and an Apple Developer Program membership, neither of which the project has yet. iOS-specific code is written from the start; only the obligation to produce and verify an iOS build is deferred.

## 11. Field Visibility

- Customer: own profile/Addresses/Cart/Orders/Approvals/Payments/Refunds/delivery state.
- Shopper: only assigned Shopping data; delivery-address PII not exposed by default.
- Courier: only delivery PII for current assigned Order.
- Operator/Admin: operational data only as required; never passwords, OTPs, bearer tokens, merchant secrets/private keys.
- Manager: aggregates by default, not Customer PII.

## 12. Account Status

Blocked Staff cannot create a new session and cannot continue normal protected use through an old token. Historical records remain preserved.

An account may not be unblocked while another active account **of its own family** holds the same phone — Staff against Staff, Customer against Customer. Without this an unblock would produce two active accounts in one family for one number and break the invariant in `08` Section 3. An active Customer account never blocks unblocking a Staff account, or the reverse.

The refusal is `409 phone_already_active`, defined in `09` Section 59. Resolving such a case is an Admin operational decision, not something unblocking may do implicitly. Note that the obvious remedy — blocking the newer account — is unavailable when that account is the last active Admin, which `BR-ROLE-008` protects; another active Admin must exist first.

## 13. Core Security Invariants

1. Client cannot choose authoritative role.
2. Customer cannot access another Customer's records.
3. Shopper/Courier access is assignment-scoped.
4. Operator has explicit operations, not arbitrary status mutation.
5. Manager is read-only.
6. Blocked Staff cannot use old token as active Staff.
7. Direct IDs never grant access.
8. Flutter route guards never replace backend authorization.
9. Payment/refund success is provider-authoritative.
10. Passwords, OTPs, tokens, and merchant secrets never become business API data.
