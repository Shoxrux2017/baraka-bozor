# BarakaBozor — Business Rules

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `docs/INTERVIEW_2026-09-24.md` and `DL-2`–`DL-4` in `docs/DECISIONS.md`.

## Rule Language

- **Must / must not** — mandatory.
- **May** — permitted where the state allows it.
- **Authoritative** — decided by the backend from persisted state, never by the client.

# 1. Core

**BR-CORE-001** — The company fulfils the order; market sellers are not users.

**BR-CORE-002** — One business, one city, one market, one handoff point, one service area.

**BR-CORE-003** — The backend is authoritative for identity, role, status, ownership, order and item lifecycle, quantities, prices, markup, fees, approvals, payment state, assignments and delivery state.

**BR-CORE-004** — Existing order snapshots are never rewritten by later catalog, markup, fee, address or settings changes. An edit before shopping creates new snapshots by the Customer's own action.

# 2. Roles and Accounts

**BR-ROLE-001** — Roles are exactly `customer`, `shopper`, `courier`, `operator`, `admin`, `manager`.

**BR-ROLE-002** — One role per account, immutable. A role change blocks the old account and creates a new one on the same phone.

**BR-ROLE-003** — Customers authenticate with phone and login code and have no password.

**BR-ROLE-004** — Staff authenticate with phone and password; staff self-registration is forbidden.

**BR-ROLE-005** — Admin-created staff receive a server-generated temporary password and start with `must_change_password = true`.

**BR-ROLE-006** — While the gate is set, only identity, password change and logout are permitted.

**BR-ROLE-007** — Staff status is `active` or `blocked`; a blocked account cannot use old tokens.

**BR-ROLE-008** — Admin may not block itself or the last active Admin.

**BR-ROLE-009** — The first Admin is created by a one-time server command, never by an API.

**BR-ROLE-010** — At most one active Customer account and one active Staff account per phone; login resolves the active account of its own family; an unblock is refused while another active account of the same family holds the phone.

**BR-ROLE-011** — Login codes for configured test phone numbers are the configured fixed code and are not delivered; the configuration is empty in production. No other login code is ever emitted anywhere.

# 3. Catalog

**BR-CAT-001** — Categories and products are managed data.

**BR-CAT-002** — Referenced catalog data is archived, never hard-deleted.

**BR-CAT-003** — An archived or inactive product cannot enter a cart or an order.

**BR-CAT-004** — One current image per product; JPEG, PNG or WebP; at most 5 MB; validated by the backend.

**BR-CAT-005** — `name_uz` and `name_ru` are required on categories and products; descriptions are optional. Search matches both languages.

**BR-CAT-006** — Categories are a flat list ordered by `sort_order`.

# 4. Quantity

**BR-QTY-001** — `kg`, `liter`, `meter`: positive, at most three decimals. `gram`, `piece`, `package`, `box`, `bundle`: positive integer.

**BR-QTY-002** — `ordered_quantity` is the Customer's contract and never silently increases.

**BR-QTY-003** — `billable_quantity ≤ ordered_quantity`.

**BR-QTY-004** — Excess purchase never increases the bill.

**BR-QTY-005** — A reduced billable quantity requires Customer approval, unless the whole item is removed under `remove_if_unavailable`.

**BR-QTY-006** — An approved reduction caps the billable quantity; the ordered quantity stays as history.

# 5. Prices

**BR-PRICE-001 — Customer price.** `customer_unit_price = half_up(market_price × (1 + markup_percent / 100))`. The Customer only ever sees customer prices.

**BR-PRICE-002 — Fixed.** The order snapshots the customer price; the billable unit price is that snapshot regardless of what the Shopper paid.

**BR-PRICE-003 — Estimate.** The order snapshots the estimate customer price, the markup and the tolerance. The billable unit price is `half_up(actual_market_price × (1 + markup_snapshot / 100))`. The ceiling is `half_up(estimate_snapshot × (1 + tolerance_snapshot / 100))`, or a higher ceiling an approval set. A billable unit price above the ceiling requires approval before purchase.

**BR-PRICE-004 — Replacement.** A replacement is billed at its own customer price computed the same way, subject to the original item's ceiling or an approval.

**BR-PRICE-005 — Automatic replacement ceiling.** Fixed original: its customer-price snapshot. Estimate original: its estimate plus tolerance, or an approved higher ceiling.

**BR-PRICE-006 — Price correction.** Admin may correct a purchased estimate item's recorded market price with a reason while the order is unpaid; totals and an unpaid online obligation are recomputed. A paid order locks corrections.

# 6. Money and Rounding

**BR-MONEY-001** — Currency is integer UZS.

**BR-MONEY-002** — No binary floating-point money arithmetic.

**BR-MONEY-003** — `line_total = half_up(billable_unit_price × billable_quantity)` to 1 UZS.

**BR-MONEY-004** — Merchandise subtotal is the sum of rounded purchased lines.

**BR-MONEY-005** — A percentage service fee is `half_up(subtotal × percent / 100)`.

**BR-MONEY-006** — `final_total = subtotal + service_fee + delivery_fee_snapshot`.

# 7. Settings

**BR-SET-001** — Business settings: `markup_percent`, service fee (`fixed` or `percentage`), `delivery_fee_uzs`, `minimum_order_uzs`, `price_tolerance_percent` (default 15), working hours (`opens_at`, `closes_at`), service area (`centre_latitude`, `centre_longitude`, `radius_km`), `delivery_delay_threshold_minutes` (default 60).

**BR-SET-002** — Checkout is blocked until every setting it needs exists.

**BR-SET-003** — Orders snapshot the settings they depend on; settings changes never touch existing orders.

**BR-SET-004** — Provider enablement per provider controls only new online payments.

# 8. Cart and Checkout

**BR-CART-001** — At most one active cart per Customer.

**BR-CART-002** — A product appears at most once per cart.

**BR-CART-003** — The cart shows current prices and is not history.

**BR-CART-004** — The default substitution rule is `allow_similar_substitution`.

**BR-CHK-001** — Checkout requires a non-empty `full_name`.

**BR-CHK-002** — Checkout requires an own active address with coordinates inside the service area, street and house.

**BR-CHK-003** — The merchandise subtotal of the preview must reach `minimum_order_uzs`; the refusal carries the minimum and the shortfall.

**BR-CHK-004** — The Customer chooses `cash` or `online`; `online` requires at least one enabled provider.

**BR-CHK-005** — The preview is `final` when every line is fixed, `estimate` otherwise; an estimate total is labelled as such.

**BR-CHK-006** — A signed five-minute checkout token binds the preview to the Customer, cart, address, products, prices, fees, settings and payment method.

**BR-CHK-007** — A stale token cannot create an order.

**BR-CHK-008** — Order creation converts the cart and creates a new empty active cart atomically.

**BR-CHK-009** — An order placed outside working hours is accepted; the preview tells the Customer it will be collected after opening.

# 9. Order States

```text
new
shopping_assigned
shopping
final_payment_pending    online orders only
ready_for_delivery
delivery_assigned
on_the_way
completed
cancelled
```

**BR-ORDER-001** — `completed` and `cancelled` are terminal.

**BR-ORDER-002** — Explicit actions own transitions; no generic status write exists.

**BR-ORDER-003** — "Awaiting the Customer" is derived from pending approvals; the order stays `shopping`.

**BR-ORDER-004** — The Customer may edit items and the delivery wish while `new` or `shopping_assigned` and shopping has not started; each edit re-snapshots the changed lines and writes history.

**BR-ORDER-005** — Order numbers are short, sequential and unique.

# 10. Order Item States

```text
pending    awaiting_customer    purchased    removed
```

**BR-ITEM-001** — `purchased` and `removed` are terminal.

**BR-ITEM-002** — A purchased item has a positive billable quantity, a billable unit price and a line total.

**BR-ITEM-003** — A removed item has billable quantity and line total zero and a `removed_reason_code`.

**BR-ITEM-004** — A replacement has the same `unit_code` as the original.

# 11. Assignment

**BR-ASSIGN-001** — Operators and Admins assign one active Shopper to a `new` order and one active Courier to a `ready_for_delivery` order.

**BR-ASSIGN-002** — Shopper reassignment only before shopping starts; Courier reassignment only before `on_the_way`.

**BR-ASSIGN-003** — Accept before start.

**BR-ASSIGN-004** — Shopper and Courier access is scoped to current assignments.

**BR-ASSIGN-005** — An assignment whose assignee's phone equals the Customer's is allowed and flagged `is_self_order` on the assignment, the board and history.

**BR-ASSIGN-006** — Shopping completion requires every item terminal and no pending approval; if nothing was purchased the order is cancelled with `no_items_purchased`.

# 12. Approvals

Types `price_over_tolerance`, `substitution`, `reduced_quantity`; states `pending`, `approved`, `rejected`, `expired`.

**BR-APP-001** — A proposal is immutable after creation except for its resolution.

**BR-APP-002** — At creation plus 10 minutes a pending approval is Operator attention.

**BR-APP-003** — At creation plus 30 minutes it expires.

**BR-APP-004** — Expiry never implies consent.

**BR-APP-005** — Only the Customer decides, only own pending approvals, only the persisted proposal.

**BR-APP-006** — Reject removes the item.

**BR-APP-007** — An expired approval is resolved by an Operator or Admin only as `remove_item`.

**BR-APP-008** — An approved price sets the item's ceiling; a later higher price needs a new approval.

**BR-APP-009** — An approved substitution authorizes only the proposed replacement and price context.

**BR-APP-010** — After approval the item returns to `pending` and the Shopper records the purchase.

**BR-APP-011** — At most one pending approval per item.

# 13. Payment

**BR-PAY-001** — Every order is paid after shopping; there is no prepayment.

**BR-PAY-002** — `payment_method` is `cash` or `online`, chosen at checkout, changeable only by an Operator switching an unpaid online order to cash.

**BR-PAY-003** — Cash: the Courier records the cash received at handover; the amount must equal the final total; the payment record is `paid` by that action.

**BR-PAY-004** — Online: a `final` payment obligation is created at shopping completion; success is provider-authoritative; no role can mark it paid.

**BR-PAY-005** — One live pending attempt per obligation; a new attempt is refused while one is pending.

**BR-PAY-006** — A failed attempt may be retried.

**BR-PAY-007** — An attempt without a result after the provider timeout is reconciled with the provider before anything else.

**BR-PAY-008** — Thirty minutes unpaid after shopping completion makes the order Operator attention; nothing is auto-cancelled.

**BR-PAY-009** — Provider callbacks are deduplicated by provider event identity and never cause duplicate transitions.

# 14. Refunds

**BR-REF-001** — A refund obligation is created when an order with a paid online payment is cancelled.

**BR-REF-002** — The refund amount is the paid amount; the sum of completed refunds never exceeds it.

**BR-REF-003** — Refunds are performed manually by an Admin in the provider's cabinet and recorded as `completed` with the provider reference, or `failed` with a note.

**BR-REF-004** — Outstanding refunds are Operator attention.

# 15. Cancellation

**BR-CAN-001** — While `new` or `shopping_assigned`, the Customer may cancel directly.

**BR-CAN-002** — From `shopping` through `delivery_assigned`, the Customer files a request; an Operator or Admin decides; at most one pending request per order.

**BR-CAN-003** — From `on_the_way`, no normal cancellation.

**BR-CAN-004** — Operators and Admins may cancel an unpaid online order after the 30-minute window and an order whose delivery failed.

**BR-CAN-005** — Cancellation records origin, actor, reason, time, previous state and whether a refund is due.

**BR-CAN-006** — An approved cancellation costs the Customer nothing.

# 16. Delivery

**BR-DEL-001** — `delivery_assigned → on_the_way → completed` is Courier-owned.

**BR-DEL-002** — Delay is derived from the threshold snapshot and is attention, not state.

**BR-DEL-003** — A Courier may mark `not_delivered` with a reason; the assignment ends `delivery_failed`, the order returns to `ready_for_delivery`, and it is Operator attention.

**BR-DEL-004** — Delivered on a cash order requires the cash amount and it must equal the final total.

**BR-DEL-005** — No proof photo, signature, code or GPS at handover.

# 17. Working Hours and Service Area

**BR-AREA-001** — An address point farther than `radius_km` from the centre is refused.

**BR-AREA-002** — Orders are accepted at any time; collection happens inside working hours.

# 18. Notifications

Customer: `order_accepted`, `approval_required`, `payment_required`, `courier_started`, `order_delivered`, `order_cancelled`. Shopper: `shopping_assigned`, `approval_answered`, `shopping_order_cancelled`. Courier: `delivery_assigned`, `delivery_cancelled`.

**BR-NOTIF-001** — Delivery is best-effort and never changes state.

**BR-NOTIF-002** — Texts are rendered in the user's `preferred_language`; payloads carry the event type and an ID only.

**BR-NOTIF-003** — SMS carries login codes only.

# 19. History and Reorder

**BR-HIST-001** — History is ownership-scoped and snapshot-stable.

**BR-HIST-002** — Reorder uses the original ordered products at current availability and prices.

**BR-HIST-003** — Products already in the cart are skipped, not overwritten.

**BR-HIST-004** — Reorder never creates an order.

# 20. Figures

Deferred past the pilot. When built: orders created by `created_at`; completed by `completed_at`; cancelled by `cancelled_at`; gross sales = sum of `final_total_uzs` of completed orders; service revenue = sum of `final_service_fee_uzs`; markup revenue = sum over purchased lines of `line_total − half_up(actual_market_price × billable_quantity)` where the actual price is known; average order value; average fulfilment time; popular products by completed orders containing the fulfilled product, quantities per unit; staff activity per member: shopping runs and deliveries completed, average duration.

# 21. Concurrency and Idempotency

**BR-CON-001** — Current persisted state under lock wins over a stale client.

**BR-CON-002** — One current Shopper assignment and one current Courier assignment per order.

**BR-CON-003** — High-risk mutations use the persisted `Idempotency-Key` contract in `09`.

**BR-CON-004** — Duplicate provider events never duplicate transitions.

**BR-CON-005** — Natural repeats (accept an accepted assignment, mark delivered a completed order from the same assignment) return the current resource without duplicate history.

# 22. Traceability

Preserve explainable history for order lifecycle, edits, assignments, approvals, price corrections, cancellations, payments and attempts, provider events, refunds and delivery failures. No path bypasses this history.
