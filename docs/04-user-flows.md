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

## 2. Mobile Sign-In: Customer

1. The user enters an Uzbekistan mobile number and confirms it.
2. The backend normalizes it, creates a login challenge, and sends the code through the code-delivery gateway: Telegram when the number has a Telegram account, otherwise SMS. The response says which channel was used and when a resend is allowed. It never says whether an account exists.
3. The user enters the code.
4. The backend verifies the challenge. An invalid, expired or exhausted code fails with its own code and stops. The third wrong code locks the phone for sixty seconds with a countdown; during it neither a code nor a new code is accepted, and afterwards only a new code opens (`DL-87`).
5. The active Customer account for the phone is resolved, or created when none is active. A blocked Customer account is refused with `account_blocked`.
6. A Customer token is issued, with `staff_step` when the phone also holds a Shopper or Courier account (section 3); the app bootstraps identity through `/auth/me`.
7. A Customer without a name gives one on the name step and sees a welcome; then the home opens.

A configured test phone number verifies with the configured fixed code and skips step 2's delivery. No cart is created here; the cart is created on first cart access.

## 3. Staff Sign-In and First Password Change

**Shopper and Courier (mobile).**

1. After the code (section 2), the app asks for the staff password and sends it with the `staff_step` token to `POST /auth/staff/step`.
2. The backend validates the step (single use, 5 minutes, 5 wrong passwords), the password and the active status, and returns the staff token, the role and `must_change_password`. A wrong password keeps the step; an expired or exhausted step leaves the person signed in as a Customer, who asks for a new code.
3. `POST /auth/staff/login` refuses a Shopper or Courier with `staff_code_required`, so the code step cannot be skipped.

**Operator, Admin and Manager (web panel).**

1. Staff enters phone and password.
2. The backend validates credentials and active status and returns the role and `must_change_password`.

**Both.**

1. While the gate is set, only `/auth/me`, `/auth/change-password` and `/auth/logout` work.
2. Staff submits the temporary password and a new one; the backend updates the hash and clears the gate.
3. The role shell opens. The web panel for Operator, Admin and Manager; the mobile shells for Shopper and Courier.

## 4. Profile

A new Customer may browse with no name; checkout is blocked until `full_name` is set. The Customer picks the interface language in the app; the app stores it on the device and reports it to the server, which uses it for push texts.

## 5. Address

The Customer places the pin on the map, or types the address and checks where the map put the pin, then enters the street and house, optional label, apartment, landmark and note, and saves. The backend validates ownership, coordinates and that the point lies inside the service-area circle; a point outside is refused with `address_outside_service_area`.

## 6. Catalog and Cart

The Customer browses categories, searches (both languages), sees unit, price mode and customer price, chooses a valid quantity, a note and a substitution rule (default: allow similar), and adds the product to the active cart — from a product card with one tap or from the product screen, where the substitution rule and the note are chosen. A product already in the cart is updated through its cart item, never duplicated. The cart shows each line with its estimate and a stepper, the amounts checkout would charge, what is missing to the minimum order, the recommended products not yet in it (`DL-84`) and the delivery address; checkout opens only when every line is sold and the minimum is reached.

## 7. Checkout Preview

1. The Customer opens checkout with a non-empty cart; the preview is asked for when checkout opens and after an address change. The address is an own active one (preselected: the delivery address chosen on the home, `DL-75`); payment is `cash` or `online`, and the Customer may type a delivery wish.
2. The backend checks name, address and service area, product availability and prices, quantities, minimum order amount, settings completeness, and provider enablement for `online`.
3. It returns lines, subtotal, service fee, delivery fee and total, marked `final` (only fixed items, which no new cart has since `DL-78`) or `estimate` (any estimate item), plus a working-hours note when the order will be collected after opening.
4. It returns a signed five-minute checkout token bound to the current state.
5. The Customer confirms. Confirming previews again a changed wish or a stale token, and places an unchanged offer without asking again (`DL-89`).

If anything changed, order creation refuses: a check of the preview that now fails answers its own code — a product gone is `product_unavailable`, naming it — and any other change, an expired token or an address since removed is `checkout_snapshot_stale`; the Customer previews again (`DL-42`).

## 8. Order Creation

1. The Customer sends the checkout token with an `Idempotency-Key`.
2. The backend locks and revalidates the cart and state.
3. It creates the order with all snapshots, `status = new`, `payment_method` as chosen, the next order number, converts the cart, creates a new empty active cart, in one transaction.
4. The Customer receives `order_accepted`. A safe retry returns the same order.

## 9. Order Editing

While the order is `new` or `shopping_assigned` and shopping has not started, the Customer sends the full desired item list and delivery wish. The backend locks the order and validates it — each added product must be one the Customer may see now, each quantity fits its line's unit, and an edit that lowers the merchandise must still reach the minimum amount (`DL-43`) — then marks the lines that are gone `removed` with `customer_removed`, updates quantity, note and rule on the lines that stay while keeping their price snapshots, adds new lines with current prices and the current markup on each, leaves the order's fee and markup snapshots untouched (`DL-6`, `DL-37` (8)), writes an `edited` history entry with what changed, and returns the order; an unchanged list is a natural repeat. Once shopping has started the request is refused with `order_editing_locked`.

## 10. Customer Cancels Before Shopping

While `new` or `shopping_assigned`, the Customer cancels directly: the order becomes `cancelled`, any Shopper assignment ends with `order_cancelled`, and the assigned Shopper receives `shopping_order_cancelled`. Nothing is owed.

## 11. Assigning a Shopper

An Operator or Admin selects an active Shopper for a `new` order. The backend locks the order, validates, creates the assignment, sets `shopping_assigned`, flags the assignment as a self-order when the Shopper's phone equals the Customer's, and notifies the Shopper. Reassignment before shopping starts ends the old assignment with `reassigned`.

## 12. Shopper Accepts and Starts

The Shopper accepts the current assignment (repeatable, no duplicate history), then starts. Start requires acceptance; the order becomes `shopping` with `shopping_started_at`. The Shopper's order screen refreshes itself every few seconds while the app is open.

## 13. Fixed Item

A line placed before `DL-78` is the only fixed line. The Shopper buys the physical quantity and records `purchased_quantity` and the fulfilled product. The actual market price may be recorded but is not required. The billable unit price is the fixed customer-price snapshot. The item becomes `purchased`.

## 14. Estimate Item

The Shopper sees the actual market price and enters it with the purchased quantity; the app asks for confirmation first when the entered price is more than three times or less than a third of the estimate's market price, the typo guard of `DL-3` (S-35). The backend computes the customer price from it (actual price plus the line's markup snapshot, rounded). If that price is within the tolerance of the estimate snapshot — or at or below the ceiling a previous approval set — the item becomes `purchased` at that price. If it exceeds the ceiling, the backend refuses with `customer_approval_required` and the Shopper requests a `price_over_tolerance` approval carrying the proposed customer price before buying at that price.

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

For `remove_if_unavailable` the Shopper marks the item unavailable and it is removed at once with `removed_reason_code = unavailable`. For the other two rules the Shopper either proposes a replacement (Sections 18, 19) or, when no replacement exists, marks the item unavailable, which removes it the same way.

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

The Customer answers each question on their order's page. It shows the proposal in their own prices and the time it can be answered until, and it refreshes every fifteen seconds while the order is open (`DL-54` (15)). "My orders" marks the orders with a question waiting. A question past its expiry is said so, and no answer is offered (`DL-71`).

## 21. Approval Does Not Freeze the Rest

While at least one item is `awaiting_customer` the order's status stays `shopping`, and `pending_approval_count` counts the questions still open; one past its expiry leaves the count, and its item still waits until an Operator removes it (`DL-54` (8)). The Shopper continues with other `pending` items, may not touch the awaiting item, and cannot complete shopping until every approval is resolved.

## 22. Completing Shopping

Every item is `purchased` or `removed` and no approval is pending. The Shopper calls complete with an `Idempotency-Key`. The backend locks the order, rounds every line half-up to 1 UZS, sums the merchandise, applies the service fee and the delivery fee snapshot, and stores the final amounts. Then:

- `cash` → `ready_for_delivery`, and the Customer is told the final amount (`DL-78`, Wave 4);
- `online` → a payment obligation for the final total, `final_payment_pending`, `payment_required` sent to the Customer;
- nothing purchased never reaches completion: the action that removed the last line cancelled the order with reason `no_items_purchased` (`DL-54` (7)).

The Shopper takes the packed order to the handoff point.

## 23. Online Payment

The Customer opens the order, sees the final composition, chooses an enabled provider and starts an attempt with an `Idempotency-Key`. The app follows the provider action the backend returns. The provider's callback or a reconciliation check confirms the result; success sets the payment `paid` and the order `ready_for_delivery`. A pending attempt blocks another; a failed attempt may be retried; an attempt with no result after the provider timeout is reconciled with the provider before anything else happens. The app never treats a redirect back as proof of payment.

## 24. Unpaid Online Order

Thirty minutes after `final_payment_pending` began with no payment, the order becomes an Operator attention item. The Operator calls the Customer and either switches the order to cash (the obligation is cancelled, the order becomes `ready_for_delivery`, history records the switch) or cancels the order.

## 25. Cancellation Request During Fulfilment

From `shopping` up to and including `delivery_assigned`, the Customer files a cancellation request with a reason; at most one pending request per order. An Operator or Admin approves or rejects it. Approve: the order becomes `cancelled`, the current assignment ends, the assignee is notified, and if an online payment was paid a manual refund obligation for the paid amount is created. Reject: the order continues. From `on_the_way` the request is refused with `order_cancellation_not_allowed`.

The order's page shows the request with the Customer's reason and where it stands: waiting, approved, rejected, or closed when the order ended otherwise first (`DL-71`).

## 26. Assigning a Courier

An Operator or Admin selects an active Courier for a `ready_for_delivery` order. The backend locks and validates, creates the assignment, sets `delivery_assigned`, flags a self-order, and notifies the Courier. Reassignment before `on_the_way` ends the old assignment with `reassigned`.

## 27. Courier Accepts and Starts

The Courier accepts, collects the order at the handoff point (or, while no handoff point exists, calls the Shopper whose phone the assignment shows), and starts. The Courier's delivery page calls the recipient, opens the point in the phone's map app, and keeps itself current every ten seconds (`DL-54` (15), (16), `DL-72`). The backend records `on_the_way_at` and the delay deadline from the threshold snapshot, sets `on_the_way`, and notifies the Customer with `courier_started`.

## 28. Delivered

After handover the Courier marks delivered. For a cash order the Courier enters the cash received, which must equal the final total; the backend records the cash payment as paid by that Courier. The order becomes `completed`, `completed_at` is stored, and the Customer receives `order_delivered`. A repeat by the same assignment is a no-op.

In the app the Courier types the cash they counted into an empty field; a mismatch shows the amount to collect (`DL-72`).

## 29. Not Delivered

The Courier marks not delivered with a reason: `no_answer`, `refused`, `wrong_address`, `other` with a note. The assignment ends with `delivery_failed`, the order returns to `ready_for_delivery`, and it becomes an Operator attention item. The Operator reassigns a Courier, possibly later, or cancels the order with reason `delivery_failed`, which creates a manual refund obligation if an online payment was paid.

## 30. Courier Delay

While `on_the_way` and past the delay deadline the order is a derived attention item; its status does not change.

## 31. Manual Refund

An outstanding refund obligation appears on the Operator attention list. An Admin performs the refund in the provider's cabinet and marks the obligation completed with the provider's reference, or failed with a note; a failed obligation stays on the list.

## 32. Staff Creation and Blocking

Admin creates a staff account with name, phone and role. The backend validates that no active staff account holds the phone, generates a temporary password, sets the gate, and returns the temporary password once. Admin may block (not self, not the last active Admin) and unblock (refused while another active staff account holds the phone), and reset another staff member's password, which returns a new temporary password and sets the gate.

## 33. Reorder

The Customer opens an order of their own, whatever its status, and taps reorder. The backend takes its lines except those the Customer removed in an edit, adds the products missing from the current cart with the ordered quantity, note and rule at current prices, reports the duplicates skipped, the products unavailable (hidden, archived or in another unit now) and the lines that no longer fit the cart's 100, and the Customer proceeds through the normal checkout. A retry with the same key answers the first answer (`DL-91` item 3). After the answer the app opens a sheet that lists what was added, what was already in the cart, what is unavailable and what did not fit, and leads to the cart (`DL-92` (2)).

## 34. Customer Mode for Staff

From the Shopper or Courier interface the person opens Customer mode; the app requests a Customer login code for the staff account's phone, verifies it, stores the Customer session beside the staff session, and switches. Switching back is one step. Logout in one mode ends only that session.

## 35. Security Across Flows

Customer: own resources only. Shopper and Courier: current assignments only. Operator and Admin: explicit capabilities. Current backend state under lock wins over a stale client. Direct UUIDs never bypass scope.

## 36. Rating

After delivery the Customer rates the order from its page or from its card in the past tab: tapping a star opens the rating screen with that many chosen (`DL-92` (6)). On it the Customer rates with 1 to 5 stars; at 1 to 3 stars the app offers the reasons (not fresh, wrong weight, late, rude) and a comment, at 4 or 5 only the comment. The backend stores one rating per order while seven days have not passed since completion. Sending the same rating again changes nothing and answers the order; a different rating after the first, a rating of an order that was not delivered, and one past the window are refused, and the order shows what was stored. The order itself is untouched.

A rating of 1 to 3 stars becomes an attention item for the Operator, whatever the order's status. The Operator calls the Customer and marks the rating reviewed; the order then shows who reviewed it and when, and the item leaves the list. Marking it again changes nothing. A Manager only sees (`DL-91` (5)).
