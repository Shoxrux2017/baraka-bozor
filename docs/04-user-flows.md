# BarakaBozor — User Flows

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `docs/INTERVIEW_2026-09-24.md` and `DL-2`–`DL-4` in `docs/DECISIONS.md`.

## 1. Main End-to-End Flow

```text
Customer login → catalog → cart → checkout preview → order
→ (edit or cancel while shopping has not started)
→ Operator assigns Shopper → accept → shopping, approvals where needed
→ final amount
→ cash: ready for delivery | online: 30 minutes to pay, then ready for delivery
→ Operator assigns Courier → accept → on the way → delivered (cash collected)
→ completed → history and reorder
```

## 2. Customer Login

1. The Customer enters an Uzbekistan mobile number.
2. The backend normalizes it, creates a login challenge, and sends the code through the code-delivery gateway: Telegram when the number has a Telegram account, otherwise SMS. The response says which channel was used and when a resend is allowed. It never says whether an account exists.
3. The Customer enters the code.
4. The backend verifies the challenge. An invalid, expired or exhausted code fails with its own code and stops.
5. The active Customer account for the phone is resolved, or created when none is active. A blocked Customer account is refused with `account_blocked`.
6. A token is issued; the app bootstraps identity through `/auth/me`.

A configured test phone number verifies with the configured fixed code and skips step 2's delivery. No cart is created here; the cart is created on first cart access.

## 3. Staff Login and First Password Change

1. Staff enters phone and password.
2. The backend validates credentials and active status and returns the role and `must_change_password`.
3. While the gate is set, only `/auth/me`, `/auth/change-password` and `/auth/logout` work.
4. Staff submits the temporary password and a new one; the backend updates the hash and clears the gate.
5. The role shell opens. The web panel for Operator, Admin and Manager; the mobile shells for Shopper and Courier.

## 4. Profile

A new Customer may browse with no name; checkout is blocked until `full_name` is set. The Customer picks the interface language in the app; the app stores it on the device and reports it to the server, which uses it for push texts.

## 5. Address

The Customer places a point on the Yandex map, enters street and house, optional label, apartment, landmark and note, and saves. The backend validates ownership, coordinates and that the point lies inside the service-area circle; a point outside is refused with `address_outside_service_area`.

## 6. Catalog and Cart

The Customer browses categories, searches (both languages), sees unit, price mode and customer price, chooses a valid quantity, a note and a substitution rule (default: allow similar), and adds the product to the active cart. A product already in the cart is updated through its cart item, never duplicated.

## 7. Checkout Preview

1. The Customer opens checkout with a non-empty cart, picks an own active address, picks `cash` or `online`, and may type a delivery wish.
2. The backend checks name, address and service area, product availability and prices, quantities, minimum order amount, settings completeness, and provider enablement for `online`.
3. It returns lines, subtotal, service fee, delivery fee and total, marked `final` (only fixed items) or `estimate` (any estimate item), plus a working-hours note when the order will be collected after opening.
4. It returns a signed five-minute checkout token bound to the current state.
5. The Customer confirms.

If anything changed, order creation returns `checkout_snapshot_stale` and the Customer previews again.

## 8. Order Creation

1. The Customer sends the checkout token with an `Idempotency-Key`.
2. The backend locks and revalidates the cart and state.
3. It creates the order with all snapshots, `status = new`, `payment_method` as chosen, the next order number, converts the cart, creates a new empty active cart, in one transaction.
4. The Customer receives `order_accepted`. A safe retry returns the same order.

## 9. Order Editing

While the order is `new` or `shopping_assigned` and shopping has not started, the Customer sends the full desired item list and delivery wish. The backend locks the order, validates it like a checkout (active products, quantities, minimum amount), replaces the items with fresh snapshots at current prices, writes an `order_edited` history entry, and returns the order. Once shopping has started the request is refused with `order_editing_locked`.

## 10. Customer Cancels Before Shopping

While `new` or `shopping_assigned`, the Customer cancels directly: the order becomes `cancelled`, any Shopper assignment ends with `order_cancelled`, and the assigned Shopper receives `shopping_order_cancelled`. Nothing is owed.

## 11. Assigning a Shopper

An Operator or Admin selects an active Shopper for a `new` order. The backend locks the order, validates, creates the assignment, sets `shopping_assigned`, flags the assignment as a self-order when the Shopper's phone equals the Customer's, and notifies the Shopper. Reassignment before shopping starts ends the old assignment with `reassigned`.

## 12. Shopper Accepts and Starts

The Shopper accepts the current assignment (repeatable, no duplicate history), then starts. Start requires acceptance; the order becomes `shopping` with `shopping_started_at`. The Shopper's order screen refreshes itself every few seconds while the app is open.

## 13. Fixed Item

The Shopper buys the physical quantity and records `purchased_quantity` and the fulfilled product. The actual market price may be recorded but is not required. The billable unit price is the fixed customer-price snapshot. The item becomes `purchased`.

## 14. Estimate Item

The Shopper sees the actual market price and enters it with the purchased quantity. The backend computes the customer price from it (actual price plus the markup snapshot, rounded). If that price is within the tolerance of the estimate snapshot — or at or below the ceiling a previous approval set — the item becomes `purchased` at that price. If it exceeds the ceiling, the backend refuses with `customer_approval_required` and the Shopper requests a `price_over_tolerance` approval carrying the proposed customer price before buying at that price.

## 15. Excess Quantity

```text
ordered   5.000 kg
purchased 5.200 kg
billable  5.000 kg
```

The excess never appears on the Customer's bill.

## 16. Reduced Quantity

The Shopper proposes a lower positive quantity; a `reduced_quantity` approval is created and the item becomes `awaiting_customer`. Approve caps the billable quantity at the proposal and returns the item to `pending` for the Shopper to record the purchase; the ordered quantity stays as history. Reject removes the item.

## 17. Unavailable — Remove

For `remove_if_unavailable` the Shopper marks the item unavailable and it is removed at once with `removed_reason_code = unavailable`. For the other two rules the Shopper either proposes a replacement (Sections 18, 19) or, when no replacement exists, marks the item unavailable with `resolution = remove`.

## 18. Automatic Replacement

For `allow_similar_substitution` the Shopper proposes an active product with the same unit and, for an estimate original, its actual price. The backend computes the replacement's customer price and compares it with the ceiling: the fixed customer-price snapshot, or the estimate plus tolerance. Within the ceiling the replacement is authorized at once and the Shopper records the purchase; above it a `substitution` approval is created. Both the original and the fulfilled product are snapshotted.

## 19. Contact Before Substitution

For `contact_before_substitution` every replacement creates a `substitution` approval. Approve authorizes exactly the proposed replacement and price context and returns the item to `pending`; reject removes the item.

## 20. Approval Timing

```text
created
+10 minutes  still pending, Operator attention item, Operator calls the Customer
+30 minutes  expired
```

An expired approval cannot be approved. An Operator or Admin resolves it only by removing the item. If no item remains to be purchased, the order is cancelled.

## 21. Approval Does Not Freeze the Rest

While at least one item is `awaiting_customer` the order shows `pending_approval_count > 0`; its status stays `shopping`. The Shopper continues with other `pending` items, may not touch the awaiting item, and cannot complete shopping until every approval is resolved.

## 22. Completing Shopping

Every item is `purchased` or `removed` and no approval is pending. The Shopper calls complete with an `Idempotency-Key`. The backend locks the order, rounds every line half-up to 1 UZS, sums the merchandise, applies the service fee and the delivery fee snapshot, and stores the final amounts. Then:

- `cash` → `ready_for_delivery`;
- `online` → a payment obligation for the final total, `final_payment_pending`, `payment_required` sent to the Customer;
- nothing purchased → `cancelled` with reason `no_items_purchased`.

The Shopper takes the packed order to the handoff point.

## 23. Online Payment

The Customer opens the order, sees the final composition, chooses an enabled provider and starts an attempt with an `Idempotency-Key`. The app follows the provider action the backend returns. The provider's callback or a reconciliation check confirms the result; success sets the payment `paid` and the order `ready_for_delivery`. A pending attempt blocks another; a failed attempt may be retried; an attempt with no result after the provider timeout is reconciled with the provider before anything else happens. The app never treats a redirect back as proof of payment.

## 24. Unpaid Online Order

Thirty minutes after `final_payment_pending` began with no payment, the order becomes an Operator attention item. The Operator calls the Customer and either switches the order to cash (the obligation is cancelled, the order becomes `ready_for_delivery`, history records the switch) or cancels the order.

## 25. Cancellation Request During Fulfilment

From `shopping` up to and including `delivery_assigned`, the Customer files a cancellation request with a reason; at most one pending request per order. An Operator or Admin approves or rejects it. Approve: the order becomes `cancelled`, the current assignment ends, the assignee is notified, and if an online payment was paid a manual refund obligation for the paid amount is created. Reject: the order continues. From `on_the_way` the request is refused with `order_cancellation_not_allowed`.

## 26. Assigning a Courier

An Operator or Admin selects an active Courier for a `ready_for_delivery` order. The backend locks and validates, creates the assignment, sets `delivery_assigned`, flags a self-order, and notifies the Courier. Reassignment before `on_the_way` ends the old assignment with `reassigned`.

## 27. Courier Accepts and Starts

The Courier accepts, collects the order at the handoff point, and starts. The backend records `on_the_way_at` and the delay deadline from the threshold snapshot, sets `on_the_way`, and notifies the Customer with `courier_started`.

## 28. Delivered

After handover the Courier marks delivered. For a cash order the Courier enters the cash received, which must equal the final total; the backend records the cash payment as paid by that Courier. The order becomes `completed`, `completed_at` is stored, and the Customer receives `order_delivered`. A repeat by the same assignment is a no-op.

## 29. Not Delivered

The Courier marks not delivered with a reason: `no_answer`, `refused`, `wrong_address`, `other` with a note. The assignment ends with `delivery_failed`, the order returns to `ready_for_delivery`, and it becomes an Operator attention item. The Operator reassigns a Courier, possibly later, or cancels the order with reason `delivery_failed`, which creates a manual refund obligation if an online payment was paid.

## 30. Courier Delay

While `on_the_way` and past the delay deadline the order is a derived attention item; its status does not change.

## 31. Manual Refund

An outstanding refund obligation appears on the Operator attention list. An Admin performs the refund in the provider's cabinet and marks the obligation completed with the provider's reference, or failed with a note; a failed obligation stays on the list.

## 32. Staff Creation and Blocking

Admin creates a staff account with name, phone and role. The backend validates that no active staff account holds the phone, generates a temporary password, sets the gate, and returns the temporary password once. Admin may block (not self, not the last active Admin) and unblock (refused while another active staff account holds the phone), and reset another staff member's password, which returns a new temporary password and sets the gate.

## 33. Reorder

The Customer opens a past order and taps reorder. The backend takes the originally ordered products, adds the active ones missing from the current cart at current prices, reports duplicates skipped and products unavailable, and the Customer proceeds through the normal checkout.

## 34. Customer Mode for Staff

From the Shopper or Courier interface the person opens Customer mode; the app requests a Customer login code for the staff account's phone, verifies it, stores the Customer session beside the staff session, and switches. Switching back is one step. Logout in one mode ends only that session.

## 35. Security Across Flows

Customer: own resources only. Shopper and Courier: current assignments only. Operator and Admin: explicit capabilities. Current backend state under lock wins over a stale client. Direct UUIDs never bypass scope.
