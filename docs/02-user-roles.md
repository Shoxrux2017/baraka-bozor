# BarakaBozor — User Roles

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `docs/INTERVIEW_2026-09-24.md` topics 6 and 7 and `DL-2`, `DL-3` in `docs/DECISIONS.md`.

## 1. Role Model

Exactly six roles:

```text
customer   shopper   courier   operator   admin   manager
```

Each account has exactly one role, immutable for the life of the account. No custom roles, multi-role accounts or role switching. To change a person's role, block the old account and create a new one; the new account reuses the same phone number (Section 3).

A Shopper or Courier who also holds a Customer account on the same number moves between the two accounts inside the app (Section 10). Each account keeps its own role and its own session.

The backend is authoritative for role, account status, record ownership, assignment scope and lifecycle permissions.

## 2. Authentication

### Customer

Phone number plus a six-digit login code. The code is delivered to the Customer's Telegram account when the number has one, otherwise by SMS once an SMS provider exists. No password. The account is created on the first verified login. Configured test phone numbers accept a fixed code without any delivery; the list is empty in production.

### Staff

`shopper`, `courier`, `operator`, `admin`, `manager` sign in with phone number and password. Admin creates every staff account except the first Admin, which a one-time server command creates. A new staff account starts with a server-generated temporary password and `must_change_password = true`; until the password is changed only the identity, password-change and logout endpoints work. Staff status is `active` or `blocked`.

## 3. Phone Uniqueness by Account Family

At most one active Customer account and at most one active Staff account per phone number. A blocked account keeps its phone; an active account of the same family cannot be created or unblocked while another active account of that family holds the number. One person may hold an active Customer account and an active Staff account on one number; the two never collide because they authenticate on different endpoints.

## 4. Customer

May: sign in; edit own name and language; manage own addresses; browse and search the catalog; manage own cart; create, edit (until shopping starts) and cancel own orders; decide own approvals; pay own online orders; file cancellation requests; see own orders, payments, refunds and delivery state; reorder.

Must not: reach another Customer's data; choose a role or status; assign staff; change prices or fees; set billable quantities or totals; mark payments as paid; mark deliveries as done; see internal or staff data.

## 5. Shopper

May: see own current assigned orders; accept an assignment; start shopping; see the products, quantities, notes, rules and price snapshots of those orders; record purchased quantity and actual price; mark an item unavailable; propose a replacement; request approvals; call the Customer while the order is in shopping; complete shopping when every item is terminal and no approval is pending; move to own Customer account inside the app.

Must not: see unassigned orders; increase a billable quantity; set a customer price directly; decide on the Customer's behalf; record payments; change the catalog, fees or settings; assign staff; mark deliveries.

A Shopper may hold several assigned orders at once. Once shopping has started, the assignment cannot be moved to another Shopper.

## 6. Courier

May: see own current delivery assignments with the delivery address, recipient name and phone, the order number, the payment method and, for cash, the amount to collect; accept; start delivery; mark delivered, recording the cash received for a cash order; mark not delivered with a reason; move to own Customer account inside the app.

Must not: change items, quantities, prices, fees, the catalog or assignments; see other Couriers' orders; record an online payment.

Once the Courier is on the way, the assignment cannot be moved to another Courier.

## 7. Operator

Runs the order board. May: see every order and the attention list; assign and reassign Shoppers before shopping starts and Couriers before delivery starts; decide cancellation requests; switch an unpaid online order to cash or cancel it; resolve an expired approval by removing the item; cancel an order the rules allow; see payments and outstanding refunds; add resolution notes.

Must not: use any generic status editor; approve spending, a substitution or a reduced quantity on the Customer's behalf; change the catalog, prices, fees or settings; manage staff or passwords; mark refunds as done; mark deliveries or payments.

The Operator surface is the Admin surface with catalog, staff, settings and refund completion hidden.

## 8. Admin

Everything the Operator may do, plus: manage categories, products, images and prices; create staff, block and unblock staff, reset another staff member's password; edit business settings and provider enablement; mark manual refunds as done; correct an estimate item's recorded price before the order is paid, with an audited reason.

Boundaries: an existing account's role is immutable; Admin cannot block itself or the last active Admin; Admin never sees a password; Admin cannot mark an online payment as paid; provider secrets are never returned by any API.

## 9. Manager

Read-only figures. Screens deferred past the pilot; the role exists so accounts can be created when they arrive.

## 10. Surfaces

| Role | Surface |
|---|---|
| Customer, Shopper, Courier | mobile app: Android from the first client wave, iOS when a Mac and an Apple developer account exist |
| Operator, Admin, Manager | web panel in the browser, built from the same Flutter code |

One Flutter codebase provides every role shell. A role that opens a surface not its own — an Admin on a phone, a Shopper in the browser — sees a screen naming the right surface; the backend does not enforce surfaces.

**Customer mode.** A Shopper or Courier reaches their own Customer account from inside the staff interface. Entering it verifies a Customer login code sent to the staff account's own phone; the password alone never opens it. Afterwards the app keeps both sessions and switches in one step; the active mode is always visible. Logging out of one mode ends only that session. Customer mode is not reachable while the staff first-login gate is set. If the staff account is blocked, the app drops the staff session only. Shoppers and Couriers use their personal phones.

## 11. Field Visibility

- Customer: own profile, addresses, cart, orders, approvals, payments, refunds, delivery state.
- Shopper: assigned orders' items, notes, rules and price snapshots; the Customer's phone only while the order is in shopping; never the delivery address.
- Courier: delivery address, recipient name and phone, order number, payment method and cash amount, for current assignments only.
- Operator and Admin: operational data; never passwords, login codes, bearer tokens, provider secrets.
- Manager: aggregates only.

## 12. Account Status

A blocked staff account cannot create a new session and cannot continue with an old token: every token is deleted at the moment of blocking and the status is re-checked on every request. Historical records are preserved. Unblocking is refused with `409 phone_already_active` while another active account of the same family holds the phone.

## 13. Core Security Invariants

1. The client never chooses the role.
2. A Customer never reaches another Customer's records.
3. Shopper and Courier access is scoped to current assignments.
4. Operator and Admin act through explicit operations, never arbitrary status writes.
5. Manager is read-only.
6. A blocked staff account cannot use an old token.
7. A direct ID never grants access.
8. Client route guards never replace backend authorization.
9. Online payment success is provider-authoritative; cash is recorded only by the Courier's handover action.
10. Passwords, login codes, tokens and provider secrets never appear in business API data.
