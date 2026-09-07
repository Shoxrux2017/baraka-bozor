# BarakaBozor — User Flows

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## 1. Main End-to-End Flow

```text
Customer authentication
→ Catalog
→ Cart
→ checkout preview
→ Order creation
→ Shopper assignment / accept / Shopping
→ Customer approval where required
→ final calculation
→ online Payment
→ Courier assignment / accept / delivery
→ Completed Order
→ history / Reorder
```

Fixed-only Order is prepaid before Shopping. Any `range`/`at_purchase` Item uses deferred Payment after Shopping.

## 2. Customer OTP Registration/Login

1. Customer enters Uzbekistan mobile phone number.
2. Backend validates/normalizes it.
3. Backend creates OTP challenge and sends SMS through configured gateway.
4. Customer enters OTP.
5. Backend validates challenge.
6. Existing Customer is authenticated or new `customer` account is created.
7. Backend ensures one active Cart.
8. Sanctum token is issued.
9. Flutter bootstraps authoritative identity via `/auth/me`.

Invalid/expired/exhausted OTP never creates session.

## 3. Staff Login and First Password Change

1. Staff enters phone + password.
2. Backend validates credentials and active status.
3. Backend returns authoritative role and `must_change_password`.
4. If password change required, normal role APIs remain blocked.
5. Staff submits current temporary password and new password.
6. Backend atomically updates hash and clears gate.
7. Role shell becomes available.

Blocked Staff cannot continue normal protected use through old token.

## 4. Customer Profile Completion

New Customer may authenticate/browse with no name, but checkout is blocked until `full_name` is non-empty.

## 5. Address Flow

Customer creates/edits own Address, selects coordinates, enters required street/house, optional apartment/landmark/label/note, and saves. Backend validates ownership and coordinates.

## 6. Catalog and Cart

Customer browses/searches Product, sees unit/pricing, chooses valid quantity, note and substitution policy, and adds to active Cart. Duplicate Product is updated through Cart-item flow, not duplicated.

## 7. Checkout Preview

1. Customer opens checkout with non-empty Cart.
2. Selects own active Address and one enabled Payment provider.
3. Backend verifies Customer name, Address completeness, Product availability/pricing, quantities, fees.
4. Returns `final`, `estimate_range`, or `contains_unknown` pricing summary.
5. Returns signed 5-minute checkout token bound to current state.
6. Customer confirms.

If state changes, Order creation returns `checkout_snapshot_stale` and Customer obtains new preview.

## 8. Order Creation

1. Customer sends checkout token + `Idempotency-Key`.
2. Backend locks/revalidates current Cart/state.
3. Creates Order/Item/Address/fee/pricing snapshots.
4. fixed-only → `payment_flow=prepaid`, `checkout_payment_pending`.
5. any range/at_purchase → `payment_flow=deferred`, `new`.
6. Source Cart → `converted`.
7. New empty active Cart created in same transaction.
8. Safe retry returns same logical Order.

## 9. Prepaid Fixed-Order Payment

Order has checkout Payment obligation. Customer initiates Attempt; provider-authoritative success moves Order to `new`. Unpaid checkout expires after 30 minutes and is system-cancelled before Shopping.

## 10. Admin Assigns Shopper

Admin selects active Shopper for eligible `new` Order. Backend locks/validates, creates assignment, Order → `shopping_assigned`. Reassignment allowed only before Shopping starts.

## 11. Shopper Accepts and Starts

Shopper accepts current assignment idempotently, then starts. Start requires acceptance. Order → `shopping`; authoritative start time saved.

## 12. Fixed Item

Shopper buys physical quantity and records purchased quantity + fulfilled Product identity. Procurement price is not required for ordinary fixed original Item; Customer billable price is fixed snapshot. Excess purchased quantity does not increase billable quantity. Item → `purchased`.

## 13. Range Item

Shopper observes actual price. If actual <= snapshotted max, records actual price/quantity and actual becomes billable. If actual > current approved ceiling, creates `price_over_range` Approval before purchase at that price; Item → `awaiting_customer`.

## 14. At-Purchase Item

Shopper purchases original Product and records actual price/quantity. Actual becomes billable. No separate pre-purchase approval for original Product; Customer sees final amount before deferred Payment.

## 15. Excess Quantity

```text
ordered = 5.000 kg
purchased = 5.200 kg
billable = 5.000 kg
```

Extra never creates Customer charge.

## 16. Reduced Quantity Approval

Shopper proposes lower positive quantity. Approval created, Item awaits Customer. Approve changes billable quantity only; ordered quantity remains historical. Reject removes Item.

## 17. Unavailable — Remove

If `remove_if_unavailable`, Shopper marks unavailable and Item is removed immediately because Customer preselected fallback.

## 18. Automatic Similar Replacement

For `allow_similar_substitution`, Shopper proposes active compatible replacement. Backend checks ceiling. If within ceiling and original not `at_purchase`, replacement can proceed automatically. Above ceiling or original `at_purchase` requires Customer Approval. Original and fulfilled Product snapshots are both preserved.

## 19. Contact Before Substitution

Shopper proposes replacement; Approval created. Customer approves exact proposal/ceiling or rejects. Reject removes Item.

## 20. Approval Timing

```text
created_at
+10 min → still pending, Operator attention
+30 min → expired
```

Customer cannot approve expired Approval. Operator/Admin may resolve expired only with `remove_item`; they cannot consent on Customer's behalf. If no fulfilment Item remains, Order cancels and paid amount is refunded as required.

## 21. Approval Does Not Freeze Unrelated Shopping

Order shows `approval_required` while at least one Item awaits Customer. Shopper may continue other `pending` Items, may not inconsistently mutate awaiting Item, and cannot complete Shopping until all approvals resolved/expired-and-removed.

## 22. Complete Shopping

Every Item is `purchased|removed`, no pending Approval. Shopper calls complete with idempotency key. Backend locks, rounds every line half-up to 1 UZS, sums merchandise, calculates Service fee, adds Delivery fee.

Outcomes:

- deferred → final Payment + `final_payment_pending`;
- prepaid paid == final → `ready_for_delivery`;
- prepaid paid < final → additional Payment + `final_payment_pending`;
- prepaid paid > final → overpayment Refund + `ready_for_delivery` because sufficient payment exists.

## 23. Deferred/Additional Payment

Customer notified, initiates Attempt. Pending outcome blocks another Attempt. Success makes Order sufficiently paid and ready if fulfilment complete. Failed may retry with new key; unknown requires reconciliation. After Shopping, 30-minute unpaid threshold creates Operator attention, not auto-cancel.

## 24. Provider Callback/Reconciliation

Provider-specific trusted request is authenticated/validated, event deduplicated, outcome normalized and transactionally applied. Duplicate callback cannot duplicate business transition. Client redirect alone is never Payment proof.

## 25. Refund

Backend creates refund obligation from approved event, links to successful Payment, provider processes, backend applies authoritative result. Overpayment refund may remain pending while delivery proceeds if final total is fully covered. Failed/unknown becomes operational attention.

## 26. Customer Cancellation

Before Shopping: immediate cancellation, final fulfilment total zero, refund paid amount if any.

After Shopping starts and before `on_the_way`: pending cancellation request; Operator/Admin decides. Approve → cancel + final fulfilment total zero + required refund; reject → continue valid lifecycle.

`on_the_way` or later: normal cancellation rejected.

## 27. Admin Assigns Courier

Order is ready and sufficiently paid. Admin chooses active Courier; backend locks/validates; Order → `delivery_assigned`. Reassignment only before delivery starts.

## 28. Courier Accepts and Starts

Courier accepts idempotently, then starts. Backend records `on_the_way_at` and delay snapshot/deadline; Order → `on_the_way`; Customer notified.

## 29. Courier Completes

After physical handover Courier calls Delivered. Backend validates assignment/state, Order → `completed`, timestamp saved, Customer notified. Safe repeat by same assignment is no-op success.

## 30. Courier Delay

Derived attention when `on_the_way` exceeds snapshotted threshold; Order remains `on_the_way`.

## 31. Admin Staff Creation

Admin creates Staff with name, phone, role. Backend validates unique phone/allowed role, generates temporary password, `must_change_password=true`, returns temporary password once. Admin cannot block self/last active Admin; existing role cannot be edited.

## 32. Reorder

Customer opens historical Order, calls Reorder. Backend uses original ordered Product IDs, current availability/pricing, adds eligible Products absent from current Cart, skips/reports duplicates, reports unavailable Products. Customer then uses normal checkout.

## 33. Manager Flow

Manager selects date period and reads server-calculated KPI. No analytics action mutates business records.

## 34. Security Across Flows

Customer own resources only; Shopper/Courier current assignment only; Operator/Admin explicit capabilities; Manager read-only; current backend state wins over stale Flutter; direct UUIDs never bypass scope.
