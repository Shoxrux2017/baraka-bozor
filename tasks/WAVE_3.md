# Wave 3 — Fulfilment

Status: **Planned** on 2026-09-28. Plan under workflow v6 (`tasks/README.md`). Scope from `docs/06-roadmap.md` sections 2 and 3; engineering decisions for the wave in `DL-54`.

## Goal

An order placed on cash reaches the Customer's door.

- **Shopping.** The Operator or Admin assigns a Shopper, who accepts and starts. At the market the Shopper records each line: a fixed price is billed as promised, an estimate at the price actually paid. A line may also be found missing or replaced, or the Shopper asks the Customer about a higher price, a replacement or a smaller quantity.
- **Approvals.** The Customer decides in the app. An approval nobody answers reaches the Operator after ten minutes and expires after thirty.
- **Delivery.** Shopping completes with the final amount. The Operator assigns a Courier, who accepts, sets off, and either hands the order over and collects the cash or marks it not delivered.
- **Cancellation.** After shopping starts, the Customer may ask to cancel, and the Operator decides.
- **Attention and correction.** The attention list carries every type this wave can produce. The Admin may correct a mistyped purchase price while the order is unpaid.

Online payment stays in Wave 5; push and deployment stay in Wave 4.

## Owner gate

None (`docs/06` section 5). The MapKit key (`DL-36`) blocks nothing here: no staff screen embeds the map, and the Courier opens the delivery point in the phone's own map app (`DL-54` (15)).

## Tasks

| # | Task | Status |
|---|---|---|
| W3-1 | Schema: `order_courier_assignments`, `customer_approvals`, `order_cancellation_requests`, `order_item_price_corrections`, `payments`; models and factories | Planned |
| W3-2 | Shopper API: assigned orders, accept, start | Planned |
| W3-3 | Shopper API: record a purchase, mark a line unavailable | Planned |
| W3-4 | Shopper API: ask about a price, a replacement or a smaller quantity; the replacement search | Planned |
| W3-5 | Approvals: the Customer's list and decision, expiry, the Operator's removal of an expired item, their attention types | Planned |
| W3-6 | Shopper API: complete shopping with the final amounts | Planned |
| W3-7 | Operations API: the Courier picker, assignment and reassignment; the board's Courier; the self-order mark; blocked assignees | Planned |
| W3-8 | Courier API: deliveries, accept, start, delivered with cash, not delivered; delay and failed-delivery attention | Planned |
| W3-9 | Cancellation requests and their decision; the Operator's cancellation after a failed delivery | Planned |
| W3-10 | Admin API: price correction | Planned |
| W3-11 | Panel: the board — Courier assignment, the new attention types and filters, the attention list's height | Planned |
| W3-12 | Panel: the order page — purchases, approvals, cancellation requests, the Courier, the cash payment, price correction | Planned |
| W3-13 | App: the Shopper's area — assigned orders, accept, start, refresh, call the Customer | Planned |
| W3-14 | App: the Shopper at the market — buy, unavailable, replace, ask the Customer, complete | Planned |
| W3-15 | App: the Customer's order while it is shopped and delivered — approvals, the cancellation request | Planned |
| W3-16 | App: the Courier's area — deliveries, accept, set off, delivered with cash, not delivered | Planned |
| W3-17 | Wave closure: full suites, builds, real-stack walkthrough of the wave's scenario, Owner checklist and report | Planned |

The order of work:

- the backend first, in the order of the table;
- the panel after W3-10;
- the app after W3-6 for the Shopper and the Customer, and after W3-8 for the Courier.

As in Wave 2 the split is by layer. The panel and the three app areas consume the same actions, so each screen task then tests against a merged contract.

## Task notes

**W3-1. Schema.**

- Forward migrations as `docs/08` sections 17 to 21 describe them, with the conventions of `DL-18` and `DL-38`: UUID keys, `timestamptz`, named checks that name their null cases, `RESTRICT` foreign keys.
- Partial unique indexes: one current Courier assignment per order, one pending approval per item, one pending cancellation request per order, one live payment per order.
- `payments` is created whole (provider, statuses, `attention_at`), although this wave writes only cash rows. Wave 5 then adds `payment_attempts`, `provider_events` and `refunds` without reshaping a table that already has rows (`DL-54` (2)). Approval statuses take `cancelled` (`DL-54` (7)).
- Checks that hold for any writer:
  - an ended Courier assignment has its reason, and a failed one its failure reason;
  - a delivery start follows acceptance, and `delay_at` comes with the start;
  - an approval's proposal matches its type: a price for `price_over_tolerance`, a quantity for `reduced_quantity`, a replacement and its snapshots for `substitution`;
  - a resolved approval has its resolver and instant;
  - a cash payment is `paid` with its recorder;
  - a price correction is append-only, like `order_history`.
- Models, and factories able to build an order at any step of the wave.
- Tests: each check and index, by a row only it refuses (`DL-38` (8)); a rollback through `RollsBackMigrations`.

**W3-2. Assigned orders, accept, start.**

- `GET /shopper/orders` (current assignments, oldest first) and `GET /shopper/orders/{order}`, per `docs/09` section 28. The detail carries:
  - the items with their notes, rules, and market and customer price snapshots;
  - the ceiling, both as a customer price and as the highest market price within it (`DL-54` (5));
  - the order number and the delivery wish;
  - `customer_phone`, only while the order is `shopping`. Never the address.
- `POST .../accept` and `POST .../start` (`BR-ASSIGN-003`), both natural repeats (`BR-CON-005`).
- Start sets `shopping`, `shopping_started_at` and the assignment's `started_at` under the order lock. This closes the Customer's editing (`BR-ORDER-004`).
- An order the Shopper holds no current assignment for is the scope-safe `404`; that includes a replaced Shopper.
- Tests:
  - scope: another Shopper, a replaced one, a Courier, a Customer;
  - the phone's window;
  - start before accept, and the repeats;
  - an edit racing the start.

**W3-3. Record a purchase, mark a line unavailable.**

- `POST /shopper/orders/{order}/items/{item}/purchase` (`Idempotency-Key`) and `.../unavailable`, per `docs/09` sections 30 and 31 and `DL-54` (4) and (6).
- Under the order lock:
  - the order must be `shopping`, and the assignment the caller's and started (`409 shopping_not_active`);
  - the item must be `pending` (`409 item_already_resolved`).
- The billable quantity, price and line total come from `MoneyCalculator`.
- `409 customer_approval_required`, with the approval type and the values, answers:
  - a purchase below the ordered quantity or the approved cap;
  - a price above the ceiling.
- Unavailable removes the line with `unavailable`, whatever its rule; a replacement is W3-4's.
- The Customer's order and the board's order show each line's purchase: the quantity bought and billed, the price, the replacement.
- Tests:
  - a fixed line bought as itself is billed at its snapshot, whatever was paid;
  - an estimate within the tolerance, at the ceiling, and one UZS above;
  - excess is not billed (`docs/04` section 15);
  - an estimate line added by an edit is billed at its own markup (Wave 2 risk row);
  - a replay;
  - the last line marked unavailable cancels the order.

**W3-4. Ask about a price, a replacement or a smaller quantity.**

- `POST .../price-approval`, `.../substitution` and `.../reduced-quantity-approval`, per `docs/09` sections 32 to 34, `docs/04` sections 16 to 19, and `BR-PRICE-004` and `BR-PRICE-005`. Each runs under the order lock on a `pending` item.
- A price approval only above the current ceiling.
- A substitution:
  - must name an active product of the same unit (`409 replacement_unit_mismatch`), and not the original;
  - is refused for `remove_if_unavailable`;
  - under `allow_similar_substitution` and within the ceiling, is authorized at once (`substitution_resolution: automatic`);
  - otherwise creates a `substitution` approval.
- A reduced quantity lies strictly between zero and the ordered quantity, at the unit's precision.
- Each approval carries the persisted proposal with both names snapshotted, and `attention_at` and `expires_at` (`DL-54` (7)). It writes `approval_requested` and sets the item `awaiting_customer`.
- `GET /shopper/orders/{order}/items/{item}/replacements?search=` (`DL-54` (16)).
- Tests:
  - each branch of the substitution, per rule and ceiling;
  - the unit mismatch;
  - a second request on an awaiting item;
  - the proposal's values;
  - the timers, under a controlled clock.

**W3-5. Approvals.**

- `GET /customer/approvals?status=pending`, `GET /customer/approvals/{approval}` and `POST .../decision` (`Idempotency-Key`), per `docs/09` section 23 and `BR-APP-001` to `BR-APP-011`:
  - approve applies the proposal onto the item (the ceiling, the authorized replacement with its price context, or the quantity cap) and returns the item to `pending` (`DL-3` S-7);
  - reject removes the item with `customer_rejected`;
  - the refusals are `409 approval_expired` and `409 approval_already_resolved`.
- Expiry, per `DL-54` (7):
  - it runs on the way through every action on the order;
  - a command scheduled every minute in `routes/console.php` runs it too;
  - every read derives it without writing;
  - the `approval_expired` history row is written once, by whichever writing path comes first.
- `POST /operations/approvals/{approval}/resolve-expired` removes the item with `approval_expired`.
- The Customer's order carries its `pending_approval_count` and each line's pending approval.
- Attention types `approval_pending` and `approval_expired` (`DL-54` (12)).
- Tests:
  - an approval at 29:59 succeeds, and at 30:00 is refused, under a controlled clock;
  - a decision racing the expiry;
  - another Customer's approval is the scope-safe `404`;
  - a replay;
  - each proposal applied;
  - rejecting the last line cancels the order.

**W3-6. Complete shopping.**

- `POST /shopper/orders/{order}/complete` (`Idempotency-Key`), per `docs/09` section 35 and `docs/04` section 22.
- Every line must be `purchased` or `removed`, with no pending approval; otherwise `409 shopping_incomplete`.
- The final amounts come from `MoneyCalculator`, over the rounded lines, with the snapshotted fee rule (`BR-MONEY-003` to `006`).
- The order becomes `ready_for_delivery`, with `shopping_completed_at` and `ready_for_delivery_at`; the assignment ends as `completed`.
- From then on, the order's totals are the stored final amounts (`DL-37` (10)).
- The online branch arrives with Wave 5 (`DL-54` (1)).
- Tests:
  - the amounts for fixed, estimate, excess, capped and replaced lines, in both fee modes, checked against the database's own checks (`DL-38` (2));
  - a replay;
  - the incomplete refusals.

**W3-7. Courier assignment and the board.**

- `GET /operations/couriers` and `POST|PUT /operations/orders/{order}/courier-assignment`, per `docs/09` section 39 and `DL-54` (9), mirroring `DL-45`:
  - `POST` needs `ready_for_delivery` with no current Courier;
  - `PUT` needs `delivery_assigned` before `on_the_way`, with `replaces_assignment_id`;
  - the assignment takes the shared lock on the Courier's account;
  - history: `courier_assigned` and `courier_reassigned`.
- The board:
  - the `courier_id` filter;
  - the current Courier on a row, and in the detail's `courier_assignments`;
  - the self-order mark of `DL-54` (13);
  - the `staff_blocked` attention type (`DL-54` (12)).
- Tests:
  - each refusal, the repeat, and the stale reassignment;
  - a block racing the assignment;
  - the mark after shopping completes, and after a replacement.

**W3-8. Deliveries.**

- `GET /courier/orders` and `GET /courier/orders/{order}`, per `docs/09` section 36, with `shopper_phone` per `DL-54` (10).
- `accept`, `start`, `delivered` (`Idempotency-Key`) and `not-delivered`, per section 37 and `docs/04` sections 27 to 29.
- Start is refused while a cancellation request is pending (`DL-54` (11)).
- Delivered writes the cash payment and completes the order and the assignment, in one transaction. The order resources show the payment.
- Not delivered returns the order to `ready_for_delivery`.
- Attention types `courier_delayed` and `delivery_failed`.
- Tests:
  - scope;
  - the cash mismatch, with its expected amount;
  - a replay;
  - the delay, under a controlled clock;
  - a failed delivery reassigned and delivered;
  - the summary's completed count and sales.

**W3-9. Cancellation requests.**

- The request branch of `POST /customer/orders/{order}/cancel` (`docs/09` section 22, reason required), and `can_request_cancellation`.
- `GET /operations/cancellation-requests`, `GET .../{request}` and `POST .../{request}/decision` (section 40), per `DL-54` (11).
- `POST /operations/orders/{order}/cancel` with `delivery_failed` (section 41).
- The Customer's order carries its latest request.
- Attention type `cancellation_request`.
- Tests:
  - the state window, `shopping` to `delivery_assigned`;
  - only one pending request;
  - approval in each state ends the right assignment;
  - reject;
  - a repeated decision;
  - the Courier's start is refused while a request is pending;
  - the Operator may cancel only after a failed delivery.

**W3-10. Price correction.**

- `POST /admin/orders/{order}/items/{item}/price-correction`, per `docs/09` section 45 and `DL-54` (17).
- Tests:
  - an estimate line and a replacement are corrected, with the totals recomputed;
  - refused: a fixed line bought as itself, a price above the ceiling, a completed order, the Operator.

**W3-11. Panel: the board.**

- Panel feature `operations`:
  - the Courier picker and assignment on the order page, with the rules of `DL-48`;
  - the board's Courier column and filter;
  - the attention types of Wave 3, with their words;
  - the attention list given its own height, folding past a few items (Wave 2 risk row).
- Tests: request bodies and verbs, refusal texts, the attention words, the narrow window.

**W3-12. Panel: the order page.**

- The page shows:
  - each line's purchase;
  - the approvals, with their proposal and timers;
  - the cancellation requests;
  - the Courier assignments, with a failed delivery's reason;
  - the cash payment.
- Actions, where the rules allow: remove an expired item, decide a request, cancel after a failed delivery, and, for the Admin, correct a price.
- Each action runs through a controller per order with `AccountMutation` (`DL-28`); a `409` reloads the order.
- Tests: each action's body, its refusals, what the Operator does not see.

**W3-13. App: the Shopper's area.**

- App feature `shopper`. The Shopper's area replaces the placeholder shell with:
  - the list of current orders;
  - an order with its lines, the order number and the delivery wish;
  - accept and start;
  - the call button to the Customer while shopping (`DL-54` (15); this adds `url_launcher`);
  - the refresh of `DL-54` (14).
- Customer mode stays reachable.
- Tests:
  - DTOs from `docs/09`;
  - the refresh stops on a failure;
  - the phone's window;
  - both languages at phone width.

**W3-14. App: the Shopper at the market.**

- Per line:
  - buy: the quantity by unit, and the price per unit for an estimate or a replacement, with the typo guard of `DL-3` S-35 against the market price snapshot;
  - unavailable;
  - replace, through the search of W3-4;
  - ask about a price or a smaller quantity when the server answers `customer_approval_required`.
- Awaiting lines are shown and are not actionable.
- Complete, with its key reused on a retry.
- Tests: each request body, the typo guard's bounds, the refusal texts, the key on a retry.

**W3-15. App: the Customer's order.**

- App feature `orders`. The order shows:
  - each line's purchase, and what was replaced;
  - the final amount once shopping completes;
  - the payment on delivery.
- Pending approvals show the proposal in the Customer's words, with approve and reject. The key is reused on a retry, and an expired approval is said so.
- The cancellation request, with its reason and its state.
- The refresh of `DL-54` (14).
- "My orders" marks the orders waiting for the Customer.
- Tests: each approval type's words, the decision body, the expired and resolved refusals, the request's states.

**W3-16. App: the Courier's area.**

- App feature `courier`. The Courier's area replaces the placeholder shell with:
  - current deliveries;
  - a delivery with the order number, recipient, address, notes, wish, payment method and amount to collect;
  - accept and set off;
  - delivered, with the cash amount confirmed;
  - not delivered, with a reason;
  - calls to the recipient and, without a handoff point, to the Shopper;
  - opening the point in the map app (`DL-54` (15));
  - the refresh of `DL-54` (14).
- Tests: DTOs, the cash mismatch text with the expected amount, the reasons, both languages at phone width.

**W3-17. Closure.**

- Closure per `tasks/README.md` section 4, with a committed `tasks/scripts/wave3_api_walkthrough.py`, the panel and the emulator.
- The scenario:
  1. The Customer places two cash orders, and the Operator assigns a Shopper to the first.
  2. The Shopper accepts and starts, then:
     - buys a fixed line, and an estimate within the tolerance;
     - asks about a price above the tolerance;
     - replaces one line automatically, and another with approval;
     - asks about a smaller quantity;
     - marks one line unavailable.
  3. The Customer approves one request and rejects another. One approval is left to expire, and the Operator removes its line.
  4. Shopping completes with the final amount.
  5. The Operator assigns a Courier. The first delivery fails and returns to the board; a second Courier delivers and collects the exact cash.
  6. The second order's cancellation is requested during shopping and approved.
  7. The Admin corrects a price.
  8. The attention list and the summary strip follow each step.

## Risks and housekeeping

| Item | Status |
|---|---|
| Push for every event of this wave is Wave 4's (`DL-37` (15)). Until then the screens refresh themselves while open (`DL-54` (14)). A Shopper, Courier or Customer with the app closed learns nothing until they open it, so the Operator calls; the ten-minute approval item exists for that | Accepted for the wave |
| A started shopping whose Shopper is blocked, and a delivery on the way whose Courier is blocked, cannot move to someone else (`BR-ASSIGN-002`). The attention list shows them (`DL-54` (12)), and the Customer's cancellation request is the way out. If it proves common, whether an Operator may move a started order is the Owner's question | Accepted for the wave |
| The handoff point is server configuration, on by default (interview 1.1, option A). The Owner confirms at deployment whether it exists at launch | Open for Wave 4 |
| Carried from Wave 2: a build whose MapKit key Yandex refuses aborts at launch (`DL-53` (1)). Before the map returns, MapKit must start only when the map is opened | Open, before the map returns |
| Carried from Wave 2: in Customer mode a Shopper's or Courier's app bar holds six actions, and the title shortens on a phone. The Shopper's and Courier's own areas of this wave must not repeat it | Open for Wave 4 (P3) |
| Carried from Wave 2: the MapKit key and the free tier's fitness (`DL-36`) | Open, Owner |
| Carried from Wave 2, for Wave 4: CORS in production, device pruning, the push token change stream, reorder's stored answer | Open for Wave 4 |
| Carried from Wave 2, for Wave 5: a payment attempt's outcome is not guarded by the idempotency key; Paynet and xazna have no adapters | Open for Wave 5 |
| Carried from Wave 2: iOS needs a Mac; browser tests run in CI only | Open until a Mac exists and the local runner works |
| Wave 2 risk rows this plan takes on (`DL-54`): the Courier assignment (W3-7), an estimate line added by an edit billed at its own markup (W3-3), the self-order mark after shopping completes ((13)), a Shopper blocked after an assignment ((12)), the attention list's height (W3-11) | Planned in Wave 3 |

## Independent-review findings not acted on

None yet.

## Closure

Not yet.
