# BarakaBozor — Business Rules

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## Rule Language

- **Must / must not** — mandatory MVP contract.
- **May** — permitted but not necessarily applicable in every state.
- **Authoritative** — decided/validated by backend/current persisted state rather than client presentation.

# 1. Core Rules

**BR-CORE-001 — Company fulfilment model**
Customer Orders BarakaBozor service; market Sellers are not platform users.

**BR-CORE-002 — One market/city operating model**
The MVP has one business operating against one wholesale market/region. Multi-market/city is Post-MVP.

**BR-CORE-003 — Server authority**
Backend is authoritative for identity, role, status, ownership, Order/Item lifecycle, billable quantities/prices, approvals, fees, Payment/refund state, assignments, and delivery state.

**BR-CORE-004 — Historical stability**
Existing Order snapshots must not be rewritten by later Catalog, Address, fee, or settings changes.

# 2. Role and Account Rules

**BR-ROLE-001** — Roles are exactly `customer`, `shopper`, `courier`, `operator`, `admin`, `manager`.

**BR-ROLE-002** — One primary role per account; role is immutable in MVP.

**BR-ROLE-003** — Customer authenticates with phone + SMS OTP and has no password.

**BR-ROLE-004** — Staff uses phone + password; Staff self-registration is forbidden.

**BR-ROLE-005** — Admin-created Staff gets server-generated temporary password and `must_change_password=true`.

**BR-ROLE-006** — While `must_change_password=true`, only current identity, password change, and logout onboarding capabilities are permitted.

**BR-ROLE-007** — Staff status is `active|blocked`; blocked Staff cannot use old tokens for normal protected operations.

**BR-ROLE-008** — Admin may not block self or the last active Admin account.

**BR-ROLE-009** — First Admin is created through controlled one-time backend CLI/bootstrap, never public API.

# 3. Catalog Rules

**BR-CAT-001** — Categories/Products are managed data, not hard-coded business enums.

**BR-CAT-002** — Historically referenced Catalog data is preserved through archive/deactivation rather than destructive deletion.

**BR-CAT-003** — Archived/inactive Product cannot be added to a new Cart/Order.

**BR-CAT-004** — One current Product image; JPEG/PNG/WebP; <=5 MB; backend-authoritative validation.

# 4. Quantity Rules

**BR-QTY-001** — Precision:

- `kg|liter|meter`: positive value with <=3 fractional digits;
- `gram|piece|package|box|bundle`: positive integer.

**BR-QTY-002** — `ordered_quantity` is Customer contract and never silently increases.

**BR-QTY-003** — `billable_quantity <= ordered_quantity`.

**BR-QTY-004** — Excess physical purchase does not increase Customer charge.

**BR-QTY-005** — Reduced fulfilment requires Customer Approval unless whole Item is removed under preselected policy.

**BR-QTY-006** — Approved reduction changes billable quantity only; ordered quantity remains historical intent.

# 5. Pricing Rules

**BR-PRICE-001 — Fixed**
Order snapshots fixed price. Ordinary fixed Item billable unit price = fixed snapshot. Shopper procurement price is not required for Customer calculation.

**BR-PRICE-002 — Range**
Order snapshots min/max. Actual <= approved ceiling is billable without extra approval. Actual > ceiling requires Customer Approval before purchase at that higher price. Actual below min is allowed and billed at lower actual price.

**BR-PRICE-003 — At purchase**
Customer accepts unknown original Product price at checkout. Shopper records actual unit price; no separate pre-purchase approval for original Product.

**BR-PRICE-004 — Substitution**
Replacement uses actual replacement unit price subject to ceiling/Approval.

**BR-PRICE-005 — Automatic replacement ceiling**

- fixed original → fixed snapshot;
- range original → max snapshot or later Customer-approved higher ceiling;
- at_purchase original → no automatic substitution; explicit Approval.

**BR-PRICE-006 — Price correction**
Admin audited correction applies only to dynamic purchased pricing before relevant final Payment lock. Operator cannot correct price.

# 6. Money and Rounding

**BR-MONEY-001** — Authoritative currency is integer UZS.

**BR-MONEY-002** — No binary floating-point money arithmetic.

**BR-MONEY-003 — Line rounding**

```text
raw_line = billable_unit_price_uzs × billable_quantity
line_total_uzs = half-up(raw_line) to nearest 1 UZS
```

**BR-MONEY-004** — Merchandise subtotal = sum of rounded purchased line totals.

**BR-MONEY-005** — Percentage Service fee is calculated from final merchandise subtotal and rounded half-up to nearest 1 UZS.

**BR-MONEY-006**

```text
final_total_uzs
= final_merchandise_subtotal_uzs
+ final_service_fee_uzs
+ delivery_fee_uzs_snapshot
```

# 7. Fee Rules

**BR-FEE-001** — Service mode `fixed|percentage`.

**BR-FEE-002** — Percentage base excludes Delivery fee.

**BR-FEE-003** — MVP Delivery fee is one fixed Admin-managed tariff.

**BR-FEE-004** — Order snapshots fee values/rule; settings changes do not mutate existing Order.

**BR-FEE-005** — Checkout blocked until required fee configuration exists.

# 8. Cart and Checkout Rules

**BR-CART-001** — At most one active Cart/Customer.

**BR-CART-002** — Product appears at most once/Cart.

**BR-CART-003** — Cart uses current Product/price data and is not historical.

**BR-CHK-001** — Checkout requires non-empty `full_name`.

**BR-CHK-002** — Checkout Address requires latitude, longitude, street, house.

**BR-CHK-003** — Preview kind is `final`, `estimate_range`, or `contains_unknown`.

**BR-CHK-004** — Backend returns signed 5-minute checkout token bound to Customer/Cart/Address/Products/pricing/fees/provider state.

**BR-CHK-005** — Stale preview cannot silently create Order.

**BR-CHK-006** — Order creation atomically converts source Cart and creates new empty active Cart.

# 9. Order States

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

**BR-ORDER-001** — `completed|cancelled` terminal.

**BR-ORDER-002** — Client never sets arbitrary status; explicit actions own transitions.

**BR-ORDER-003** — Pre-Shopping fixed payment uses `checkout_payment_pending`; post-Shopping deferred/additional uses `final_payment_pending`.

**BR-ORDER-004** — Pending Approval projects Order as `approval_required`; Shopper may still process other non-blocked Items; completion blocked until resolved.

# 10. Order Item States

```text
pending
awaiting_customer
purchased
removed
```

**BR-ITEM-001** — `purchased|removed` terminal fulfilment outcomes.

**BR-ITEM-002** — Purchased Item has positive billable quantity, billable unit price, line total.

**BR-ITEM-003** — Removed Item has billable quantity and line total zero.

# 11. Shopper Assignment and Shopping

**BR-SHOP-001** — Admin manually assigns one current active Shopper.

**BR-SHOP-002** — Shopper accepts before start.

**BR-SHOP-003** — Normal Shopper reassignment only before Shopping starts.

**BR-SHOP-004** — Shopper access current-assignment scoped.

**BR-SHOP-005** — Completion requires every Item terminal and no pending Approval.

**BR-SHOP-006** — If no purchased Item remains, Order cancels, final Customer fulfilment totals are zero, paid amount refunded as required.

# 12. Approval Rules

Types: `price_over_range|substitution|reduced_quantity`.
States: `pending|approved|rejected|expired`.

**BR-APP-001** — Proposal immutable after creation except resolution fields.

**BR-APP-002** — +10m creates Operator attention; still pending.

**BR-APP-003** — +30m expires unresolved Approval.

**BR-APP-004** — Expiration never implies consent.

**BR-APP-005** — Customer decides only own pending Approval and only persisted proposal.

**BR-APP-006** — Reject removes affected Item.

**BR-APP-007** — Expired Approval may be resolved by Operator/Admin only as `remove_item`.

**BR-APP-008** — Approved price-over-range establishes specific approved ceiling; later higher price requires new Approval.

**BR-APP-009** — Approved substitution authorizes only proposed replacement/price context.

# 13. Payment Flow Rules

**BR-PAY-001** — All fixed Items → prepaid; any range/at_purchase → deferred.

**BR-PAY-002** — Prepaid Shopping cannot begin before successful checkout Payment.

**BR-PAY-003** — Deferred final Payment created only after Shopping completion/final calculation.

**BR-PAY-004** — No UI/user role fabricates Payment success.

**BR-PAY-005** — One live pending Attempt/Payment; do not start another while outcome unknown.

**BR-PAY-006** — Definitive failed Attempt may retry.

**BR-PAY-007** — Unknown outcome requires reconciliation.

**BR-PAY-008** — Unpaid checkout Payment expires +30m and system-cancels Order before Shopping.

**BR-PAY-009** — Final/additional Payment after Shopping is not auto-cancelled at +30m; becomes Operator attention.

# 14. Prepaid Recalculation

```text
paid == final → ready
paid < final  → additional Payment, final_payment_pending
paid > final  → overpayment Refund + ready
```

**BR-PAY-010** — Additional amount never charged automatically.

**BR-PAY-011** — Pending overpayment Refund does not block Delivery if paid amount covers final total.

# 15. Refund Rules

**BR-REF-001** — Refund links to successful Payment and provider-authoritative outcome.

**BR-REF-002** — Sum successful Refunds <= successful paid amount.

**BR-REF-003** — Overpayment refund = paid amount above authoritative final total.

**BR-REF-004** — Approved whole-Order cancellation sets final Customer fulfilment total zero and refunds paid Customer amount.

**BR-REF-005** — Failed/unknown Refund becomes attention; Admin may retry safely under provider contract.

# 16. Cancellation Rules

**BR-CAN-001** — Before Shopping, Customer may cancel directly.

**BR-CAN-002** — After Shopping starts and before `on_the_way`, Customer creates request; Operator/Admin decides.

**BR-CAN-003** — `on_the_way` or later: normal MVP cancellation forbidden.

**BR-CAN-004** — Cancellation stores origin/actor/reason/time/previous state/refund requirement.

# 17. Courier Rules

**BR-COUR-001** — Admin assigns one current active Courier only for ready Order.

**BR-COUR-002** — Courier accepts before start.

**BR-COUR-003** — Normal reassignment only before `on_the_way`.

**BR-COUR-004** — Courier access current-assignment scoped.

**BR-COUR-005** — `delivery_assigned → on_the_way → completed` is Courier-owned.

**BR-COUR-006** — Delay is derived attention from snapshotted threshold, not lifecycle state.

# 18. Notification Rules

Required Customer notification types:

```text
order_accepted
approval_required
payment_required
courier_started
order_delivered
```

Notification failure does not change Order state.

# 19. History and Reorder

**BR-HIST-001** — Customer history ownership-scoped and snapshot-stable.

**BR-HIST-002** — Reorder uses original ordered Product + current availability/pricing.

**BR-HIST-003** — Existing current Cart Product is skipped, not overwritten.

**BR-HIST-004** — Reorder never creates Order automatically.

# 20. Analytics Rules

For selected period:

- Orders created: count by `created_at`.
- Completed Orders: `completed_at` in period.
- Cancelled Orders: `cancelled_at` in period.
- Gross sales: sum `final_total_uzs` for Completed Orders.
- Service revenue: sum `final_service_fee_uzs` for Completed Orders.
- AOV: average `final_total_uzs` for Completed Orders.
- Average fulfilment: average `completed_at-created_at` for Completed Orders.
- Popular Products: rank by number of Completed Orders containing fulfilled Product; quantity totals separate per unit.

# 21. Concurrency and Idempotency

**BR-CON-001** — Current persisted state under lock wins over stale UI.

**BR-CON-002** — One current Shopper assignment/Order.

**BR-CON-003** — One current Courier assignment/Order.

**BR-CON-004** — High-risk Flutter mutations use persisted idempotency contract in Architecture/DB/API.

**BR-CON-005** — Duplicate provider events do not duplicate financial/lifecycle transitions.

**BR-CON-006** — Explicitly approved natural lifecycle repeats may return current resource without duplicate history.

# 22. Traceability

Preserve explainable history for Order lifecycle, Shopper/Courier assignments, Customer Approvals, dynamic price corrections, cancellations, Payment Attempts/provider events, Refunds/refund Attempts. No generic status editor may bypass this history.
