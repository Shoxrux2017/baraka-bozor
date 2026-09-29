# Wave 3 — Fulfilment

Status: **In progress** (planned 2026-09-28). Plan under workflow v6 (`tasks/README.md`). Scope from `docs/06-roadmap.md` sections 2 and 3; engineering decisions for the wave in `DL-54`.

## Goal

An order placed on cash reaches the Customer's door:

1. **Shopping.** The Operator or Admin assigns a Shopper, who accepts, starts, and records each line at the market: a fixed price as promised, an estimate at the price actually paid. A line may also be found missing or replaced, or the Shopper asks the Customer about a higher price, a replacement or a smaller quantity.
2. **Approvals.** The Customer decides in the app. An approval nobody answers reaches the Operator after ten minutes and expires after thirty.
3. **Delivery.** Shopping completes with the final amount. The Operator assigns a Courier, who accepts, sets off, and either hands the order over and collects the cash or marks it not delivered.
4. **Cancellation.** After shopping starts, the Customer may ask to cancel, and the Operator decides.
5. **Attention and correction.** The attention list carries every type this wave can produce, and the Admin may correct a mistyped purchase price before the Courier sets off.

Online payment, push and deployment stay in Waves 5 and 4.

## Owner gate

None (`docs/06` section 5). The MapKit key (`DL-36`) blocks nothing here: no staff screen embeds the map, and the Courier opens the delivery point in the phone's own map app (`DL-54` (16)).

## Tasks

| # | Task | Status |
|---|---|---|
| W3-1 | Schema: `order_courier_assignments`, `customer_approvals`, `order_cancellation_requests`, `order_item_price_corrections`, `payments`; the history events; models and factories | Merged |
| W3-2 | Shopper API: assigned orders, accept, start | Merged |
| W3-3 | Shopper API: record a purchase, mark a line unavailable | Merged |
| W3-4 | Shopper API: ask about a price, a replacement or a smaller quantity; the replacement search | Merged |
| W3-5 | Approvals: the Customer's list, detail and decision | Merged |
| W3-6 | Approvals: expiry, the scheduled command, the Operator's removal of an expired line, their attention types and the board's filter | Merged |
| W3-7 | Shopper API: complete shopping with the final amounts | Merged |
| W3-8 | Operations API: the Courier picker, assignment and reassignment; the board's Courier; the self-order mark; blocked assignees | Merged |
| W3-9 | Courier API: deliveries, accept, start; the delay | Merged |
| W3-10 | Courier API: delivered with cash, not delivered | Merged |
| W3-11 | Cancellation requests and their decision; the Operator's cancellation after a failed delivery | Merged |
| W3-12 | Admin API: price correction | Merged |
| W3-13 | Panel: the board — Courier assignment, attention types and filters, the attention list's height, the block confirmation | Merged |
| W3-14 | Panel: the order page — purchases, approvals, cancellation requests, the Courier, the cash payment, price correction | Merged |
| W3-15 | App: the Shopper's area — assigned orders, accept, start, refresh, call the Customer | Merged |
| W3-16 | App: the Shopper at the market — buy, unavailable, replace, ask the Customer, complete | Merged |
| W3-17 | App: the Customer's order while it is shopped and delivered — approvals, the cancellation request | Merged |
| W3-18 | App: the Courier's area — deliveries, accept, set off, delivered with cash, not delivered | Merged |
| W3-19 | Wave closure: full suites, builds, real-stack walkthrough of the wave's scenario, Owner checklist and report | Planned |

The order of work:

- **Backend** first, in the order of the table.
- **Panel** after W3-12.
- **App**, for the Shopper after W3-7, for the Customer and the Courier after W3-11.

As in Waves 1 and 2, the split is by layer (`DL-54` (22)). Each backend task that changes an answer a merged screen reads also changes that screen's reading in the same pull request (`DL-54` (21)).

## Task notes

**W3-1. Schema.**

- Forward migrations as `docs/08` sections 17 to 21 describe them, with the conventions of `DL-18` and `DL-38`: UUID keys, `timestamptz`, named checks that name their null cases, and `RESTRICT` foreign keys.
- Partial unique indexes:
  - one current Courier assignment per order;
  - one pending approval per item;
  - one pending cancellation request per order;
  - one live payment per order.
- `payments` is created whole: provider, statuses, `attention_at` (`DL-54` (2)).
- Forward migrations of Wave 2's tables (`DL-54` (2)):
  - the `order_history` event check gains the Wave 3 events;
  - `order_items` gains `approved_replacement_price_uzs`, only on a line with an authorized replacement.
- Checks that hold for any writer:
  - **Courier assignments.** An ended assignment has its reason, and a failed one its failure reason. A delivery start follows acceptance, and `delay_at` comes with the start.
  - **Approval proposals** match their type:
    - a price for `price_over_tolerance`, with a replacement and its snapshots when it is about one;
    - a quantity for `reduced_quantity`;
    - a replacement with its snapshots for `substitution`.
  - **Approval statuses** hold their columns:
    - `pending` has no resolver, instant or resolution;
    - `approved` and `rejected` have the Customer as resolver, the instant, and the resolution of the same name;
    - `expired` has no resolution until an Operator removes the line; then it has `remove_item`, with that Operator and instant;
    - `cancelled` has the instant and no resolution, and a resolver only when a user's action cancelled the order.
  - **Cancellation requests.** A decided request has its resolver and instant; a `closed` one has its instant.
  - **Payments.** A cash payment is `paid`, with its recorder.
  - **Price corrections** are append-only, like `order_history`.
- Models, and factories able to build an order at any step of the wave.
- Tests:
  - each check and index, by a row only it refuses (`DL-38` (8));
  - a rollback through `RollsBackMigrations`.

**W3-2. Assigned orders, accept, start.**

- `GET /shopper/orders` (current assignments, oldest first) and `GET /shopper/orders/{order}` (`docs/09` section 28).
- The detail carries:
  - the lines, with their notes, rules, and market and customer price snapshots;
  - the bound of each product a line may be bought with, as both a customer and a market price (`DL-54` (6));
  - the authorized replacement with its current market price, the cap, and a pending approval with its expiry;
  - the order number and the delivery wish;
  - `customer_phone`, only while the order is `shopping`. The address never.
- `POST .../accept` and `POST .../start` (`BR-ASSIGN-003`):
  - both are natural repeats;
  - accept writes `shopper_accepted`;
  - start sets `shopping`, `shopping_started_at` and the assignment's `started_at` under the order lock, which closes the Customer's editing (`BR-ORDER-004`).
- A Shopper with no current assignment for the order gets the scope-safe `404`, including a replaced Shopper (`DL-54` (3)).
- Tests:
  - scope: another Shopper, a replaced one, a Courier, a Customer;
  - the phone's window;
  - start before accept, and the repeats;
  - an edit racing the start.

**W3-3. Record a purchase, mark a line unavailable.**

- `POST /shopper/orders/{order}/items/{item}/purchase` (`Idempotency-Key`) and `.../unavailable` (`docs/09` sections 30 and 31; `DL-54` (4) and (7)).
- Under the order lock:
  - the order is `shopping`, and the assignment is the caller's and started (`409 shopping_not_active`);
  - the line is `pending` (`409 item_already_resolved`).
- The billable quantity, price and line total come from `MoneyCalculator`.
- Buying the original copies its names and unit from the line, not from the catalog (`DL-55` (12)).
- Writes:
  - a purchase writes `item_purchased`;
  - unavailable removes the line with `unavailable`, whatever its rule, and writes `item_unavailable`.
- The Customer's order and the board's order show each line's purchase:
  - the quantity billed, and on the board also the quantity bought (`DL-57` (4));
  - the billable customer price (the board also shows the price paid);
  - the replacement.
- Tests:
  - a fixed line bought as itself is billed at its snapshot, whatever was paid;
  - an estimate within the tolerance, at the ceiling, and one UZS above it;
  - a purchase below the ordered quantity, and below a cap;
  - excess not billed (`docs/04` section 15);
  - an estimate line added by an edit, billed at its own markup (Wave 2 risk row);
  - the authorized replacement bought with and without `fulfilled_product_id`, and the original bought instead, which drops the authorization;
  - a replay;
  - the original bought after an Admin changed its product's unit;
  - the last line marked unavailable cancels the order and closes a pending request.

**W3-4. Ask about a price, a replacement or a smaller quantity.**

- The three questions (`docs/09` sections 32 to 34; `docs/04` sections 16 to 19; `BR-PRICE-004`, `BR-PRICE-005`; `DL-54` (5)):
  - `POST .../price-approval`;
  - `.../substitution`;
  - `.../reduced-quantity-approval`.
- Each question is asked under the order lock, on a `pending` line.
- **A price question** is allowed only above the current ceiling of the product named (`409 approval_not_needed`).
- **A substitution**:
  - must be to an active product of the same unit, not the original;
  - refusals: `409 replacement_unit_mismatch`, `409 product_unavailable`, `409 substitution_not_allowed` under `remove_if_unavailable`;
  - under `allow_similar_substitution` and within the automatic ceiling, it is authorized at once and writes `item_substituted`;
  - otherwise it is a `substitution` approval;
  - a new substitution replaces an earlier one.
- **A reduced quantity** lies strictly between zero and the ordered quantity, at the unit's precision.
- **Each approval**:
  - carries the persisted proposal, with both names snapshotted, and `attention_at` and `expires_at` (`DL-54` (8));
  - writes `approval_requested`;
  - sets the line to `awaiting_customer`.
- `GET /shopper/orders/{order}/items/{item}/replacements?search=` (`DL-54` (17)).
- The board's order detail lists the approvals (`docs/09` section 38).
- Tests:
  - each branch of the substitution, per rule and ceiling;
  - a replacement's approved price is not carried to another replacement, and the original's approved ceiling survives a new one;
  - the same automatic replacement again, and a different one;
  - a fixed original's automatic ceiling, and a price question about a fixed original refused;
  - a second question on an awaiting line;
  - the proposal's values;
  - the timers, under a controlled clock.

**W3-5. The Customer's approvals.**

- `GET /customer/approvals?status=pending`, `GET /customer/approvals/{approval}` and `POST .../decision` (`Idempotency-Key`) (`docs/09` section 23; `BR-APP-001` to `BR-APP-011`; `DL-54` (8)).
- A decision:
  - approve applies the proposal onto the line and returns it to `pending`;
  - reject removes the line with `customer_rejected`;
  - `approval_decided` is written either way;
  - an overdue approval is expired first, in a transaction of its own, then refused with `409 approval_expired`. This task writes that shared step, and W3-6 runs it before every other action;
  - a repeated decision answers from what is stored and never writes the approval again (`DL-55` (2));
  - an already resolved approval is `409 approval_already_resolved`.
- The Customer's order carries each line's pending approval, and the list carries `pending_approval_count`. A line with a pending substitution shows the question's replacement, not an earlier authorized one (`DL-58` (3)).
- Approving a price question about the original drops a replacement authorized on the line, as buying the original does (`DL-54` (4)), since the Shopper named the original. The Shopper may propose that replacement again, and `BR-PRICE-005` then judges it against the raised ceiling; record the decision in `DECISIONS.md` with the task.
- Tests:
  - an approval at 29:59 is approved, and at 30:00 refused with the expiry kept, under a controlled clock;
  - a decision racing the expiry, which the Shopper's next action cannot reach while the line awaits;
  - another Customer's approval is the scope-safe `404`;
  - a replay;
  - each proposal applied;
  - rejecting the last line cancels the order.

**W3-6. Expiry and the Operator's removal.**

- **Expiry** (`DL-54` (8)):
  - the step of W3-5, made the first step of every action on an order, the merged ones of W3-3 and W3-4 included;
  - `approvals:expire`, scheduled every minute in `routes/console.php`;
  - derived on every read — the Shopper's list and detail, the Customer's order and approvals, and the board's `approvals[].status` and counts — so an approval past its expiry is shown and counted as expired.
- `POST /operations/approvals/{approval}/resolve-expired`:
  - removes the line with `approval_expired` and writes `approval_resolved`;
  - an approval not yet expired is `409 approval_not_expired`;
  - an order no longer open is `409 order_state_conflict`, and its expired approvals leave the attention list (`DL-55` (11));
  - the same removal again is a natural repeat, answered from what is stored without writing the approval (`DL-55` (2)).
- Attention types `approval_pending` and `approval_expired`.
- The board's `awaiting_customer` filter and each row's `pending_approval_count`.
- The panel reads every attention type of `docs/09` section 38, and nullable `shopper` and `courier`, with the words for this task's types. It shows a type it has no words for yet generically, so the later tasks' types never break it (`DL-54` (21)).
- Tests:
  - the command, run twice;
  - expiry on the way through an action that then refuses;
  - the read before any write;
  - the Operator removing the last line cancels the order;
  - the attention item's `since`;
  - the board's filter.

**W3-7. Complete shopping.**

- `POST /shopper/orders/{order}/complete` (`Idempotency-Key`) (`docs/09` section 35; `docs/04` section 22).
- Every line must be `purchased` or `removed`, with no pending approval; otherwise `409 shopping_incomplete`.
- The final amounts come from `MoneyCalculator` over the rounded lines, with the snapshotted fee rule (`BR-MONEY-003` to `006`).
- The order becomes `ready_for_delivery`, with `shopping_completed_at` and `ready_for_delivery_at`. The assignment ends `completed`.
- From then on, the totals are the stored final amounts (`DL-37` (10)).
- A replay answers through the ended assignment while no later Shopper holds the order (`DL-54` (3)).
- The online branch comes with Wave 5.
- Tests:
  - the amounts for fixed, estimate, excess, capped and replaced lines, in both fee modes, checked against the database's own checks (`DL-38` (2));
  - a replay after the assignment ended;
  - the incomplete refusals.

**W3-8. Courier assignment and the board.**

- `GET /operations/couriers` and `POST|PUT /operations/orders/{order}/courier-assignment` (`docs/09` section 39; `DL-54` (10)).
- The board:
  - the `courier_id` filter;
  - a row's Courier, and the detail's `courier_assignments`;
  - the `shopper_id` and `courier_id` filters matching the person a row names;
  - the self-order mark, and a row's Shopper and Courier, as `DL-54` (14) sets them;
  - the `staff_blocked` attention type (`DL-54` (13)).
- The panel reads the rows and items that no longer have a current Shopper (`DL-54` (21)).
- Tests:
  - each refusal, the repeat, and the stale reassignment;
  - a block racing the assignment;
  - the mark:
    - after shopping completes;
    - after a replacement before the start;
    - after a Courier's failed delivery;
    - after a cancellation.

**W3-9. Deliveries, accept, start.**

- `GET /courier/orders` and `GET /courier/orders/{order}` (`docs/09` section 36), with `shopper_phone` per `DL-54` (11).
- `accept` and `start` are natural repeats: accept writes `courier_accepted`, and start sets `on_the_way` with `delay_at`.
- Attention type `courier_delayed`, with its words in the panel (`DL-54` (21)).
- Tests:
  - scope;
  - the handoff setting both ways;
  - start before accept;
  - the delay, under a controlled clock.

**W3-10. Delivered, not delivered.**

- `delivered` (`Idempotency-Key`) and `not-delivered` (`docs/09` section 37; `docs/04` sections 28 and 29; `DL-54` (11)).
- Delivered:
  - writes the cash payment, and `payment_recorded`;
  - completes the order and the assignment, in one transaction.
- The Customer's order and the board's order show the payment.
- Not delivered returns the order to `ready_for_delivery`, with `delivery_failed`, and clears `on_the_way_at` (`DL-55` (13)). History rows per `DL-54` (23).
- A replay of delivered, and a repeat of not-delivered, answer through the ended assignment (`DL-54` (3)).
- Attention type `delivery_failed`, with its words in the panel.
- Tests:
  - the cash mismatch, with its expected amount;
  - the replay and the repeat after the assignment ended, and the scope-safe `404` once another Courier holds the order;
  - a failed delivery, reassigned and then delivered;
  - the summary's completed count and sales.

**W3-11. Cancellation requests.**

- The request branch of `POST /customer/orders/{order}/cancel` (`docs/09` section 22; reason required), with `can_request_cancellation`.
- `GET /operations/cancellation-requests`, `GET .../{request}` and `POST .../{request}/decision` (section 40; `DL-54` (12)).
- `POST /operations/orders/{order}/cancel` with `delivery_failed` (section 41), refused while a request is pending.
- The Courier's start is refused while a request is pending.
- `cancellation_requested` and `cancellation_request_decided` are written.
- The Customer's order carries its latest request, and the board's detail its `cancellation_requests`.
- Attention type `cancellation_request`, with its words in the panel.
- History rows per `DL-54` (23).
- Tests:
  - the state window, `shopping` to `delivery_assigned`;
  - one pending request per order;
  - approving in each state ends the right assignment and closes pending approvals;
  - reject;
  - the same and the other decision repeated;
  - the Courier's start refused while pending;
  - the Operator's cancellation only after a failed delivery and with no request pending;
  - a decision on a `closed` request;
  - a request closed by the last line removed;
  - a race: the Shopper's purchase and unavailable line waiting on an approved request's cancellation (`DL-57` review).

**W3-12. Price correction.**

- `POST /admin/orders/{order}/items/{item}/price-correction` (`docs/09` section 45; `DL-54` (18)).
- Tests:
  - an estimate line and a replacement are corrected, with the totals recomputed before and after completion;
  - refused:
    - a fixed line bought as itself;
    - a line not bought;
    - a price above the ceiling;
    - an order on the way, and a completed one;
    - the Operator;
  - the current price again.

**W3-13. Panel: the board.**

- Feature `operations`:
  - the Courier picker and assignment on the order page, with the rules of `DL-48`;
  - the board's Courier column, and the Courier and `awaiting_customer` filters;
  - the words for every attention type of the wave;
  - the attention list, given its own height and folding past a few items (Wave 2 risk row).
- The staff screen's block confirmation gives a Shopper's or Courier's count of current orders, from the pickers' `current_assignment_count` (`DL-45` (1)), since a started one cannot then move (risk list).
- Tests: request bodies and verbs, refusal texts, the attention words, the narrow window.

**W3-14. Panel: the order page.**

- The page shows:
  - each line's purchase, with the price paid;
  - the approvals, with their proposal and timers;
  - the cancellation requests;
  - the Courier assignments, with a failed delivery's reason;
  - the cash payment;
  - the price corrections, in the history.
- Actions, where the rules allow: remove an expired line, decide a request, cancel after a failed delivery, and for the Admin correct a price.
- Each action runs through a controller per order with `AccountMutation` (`DL-28`); a `409` reloads the order.
- Tests: each action's body, its refusals, what the Operator does not see.

**W3-15. App: the Shopper's area.**

- App feature `shopper`. The Shopper's area replaces the placeholder shell with:
  - the list of current orders;
  - an order with its lines, the order number and the delivery wish;
  - accept and start;
  - the call button to the Customer while shopping. This adds `url_launcher` and the manifest's `<queries>` (`DL-54` (16)).
  - the refresh of `DL-54` (15).
- Customer mode stays reachable, without crowding the app bar (Wave 2 risk row).
- Tests:
  - DTOs from `docs/09`;
  - the refresh stops on a failure;
  - the phone's window;
  - both languages, at phone width and with large text.

**W3-16. App: the Shopper at the market.**

- Per line:
  - **Buy:** the quantity by unit, and the price per unit for an estimate or a replacement, with the typo guard (`DL-54` (20));
  - **Unavailable;**
  - **Replace:** through the search of W3-4;
  - **Ask** about a price or a smaller quantity when the server answers `customer_approval_required`.
- Awaiting lines are shown and are not actionable.
- Complete, with its key reused on a retry. The screen that follows tells the Shopper to label the package with the order number and take it to the handoff point.
- Tests: each request body, the typo guard's bounds, the refusal texts, the key on a retry.

**W3-17. App: the Customer's order.**

- App feature `orders`. The order shows:
  - each line's purchase, and what was replaced;
  - the final amount once shopping completes;
  - the payment on delivery.
- Pending approvals:
  - show the proposal in the Customer's words;
  - offer approve and reject, with the key reused on a retry;
  - an expired one is said so.
- The cancellation request, with its reason and its state.
- The refresh of `DL-54` (15).
- "My orders" marks the orders waiting for the Customer.
- Tests: each approval type's words, the decision body, the expired and resolved refusals, the request's states.

**W3-18. App: the Courier's area.**

- App feature `courier`. The Courier's area replaces the placeholder shell with:
  - current deliveries;
  - a delivery with the order number, recipient, address, notes, wish, payment method and amount to collect;
  - accept, and set off (with the reason when a cancellation request holds it);
  - delivered, with the cash amount confirmed;
  - not delivered, with a reason;
  - calls to the recipient and, without a handoff point, to the Shopper;
  - opening the point in the map app (`DL-54` (16));
  - the refresh of `DL-54` (15).
- The answers to delivered and not-delivered carry no recipient, address or notes (`DL-64` (7)): the app keeps what it showed before and reads only the outcome.
- Tests: DTOs, the cash mismatch text with the expected amount, the reasons, both languages at phone width.

**W3-19. Closure.**

- Closure per `tasks/README.md` section 4, with:
  - a committed `tasks/scripts/wave3_api_walkthrough.py`;
  - the panel;
  - the emulator.
- The expired approval is made by moving its instants back 31 minutes in the development database, through `psql` in the `db` container, and then running `approvals:expire`. This is a walkthrough setup, not a clock in the application.
- The scenario:
  1. The Customer places two cash orders, and the Operator assigns a Shopper.
  2. The Shopper accepts and starts, then:
     - buys a fixed line, and an estimate within the tolerance;
     - asks about a price above it;
     - replaces a line automatically, and another with approval;
     - asks about a smaller quantity;
     - marks one line unavailable.
  3. The Customer approves one question and rejects another. One approval expires, and the Operator removes its line.
  4. The Admin corrects a price.
  5. Shopping completes with the final amount.
  6. The Operator assigns a Courier. A first delivery fails and returns to the board; a second Courier delivers and collects the exact cash.
  7. The second order's cancellation is requested during shopping and approved.
  8. The attention list and the summary strip follow each step.

## Risks and housekeeping

| Item | Status |
|---|---|
| Push for every event of this wave is Wave 4's (`DL-37` (15)). Until then the screens refresh themselves while open (`DL-54` (15)). A Shopper, Courier or Customer with the app closed learns nothing until they open it, so the Operator calls; the ten-minute approval item exists for that | Accepted for the wave |
| A started shopping whose Shopper is blocked, and a delivery on the way whose Courier is blocked, cannot move to someone else (`BR-ASSIGN-002`). The attention list shows both (`DL-54` (13)). A started shopping ends by the Customer's cancellation request. A delivery on the way has no way out but the Admin unblocking the Courier, so the block confirmation names the person's current orders (W3-13). The documents settle this; changing it would be the Owner's decision | Accepted for the wave |
| A weighed line bought below its ordered weight needs the Customer's approval (`BR-QTY-005`), so the Shopper buys at or above it and the company absorbs the excess (`BR-QTY-004`). If the pilot shows short weights to be common, a tolerance for them is the Owner's decision | Open, Owner, after the pilot |
| The handoff point is the server configuration `delivery.handoff_point`, on by default (interview 1.1, option A). The Owner confirms at deployment whether it exists at launch | Open for Wave 4 |
| For Wave 5: the `unpaid_online` cancellation must close or refuse a pending cancellation request, as the last line removed does (`DL-54` (12)) | Open for Wave 5 |
| The scheduler runs nowhere until Wave 4 deploys one; until then expiry is written by actions and derived by reads (`DL-54` (8)) | Open for Wave 4 |
| Carried from Wave 2: a build whose MapKit key Yandex refuses aborts at launch (`DL-53` (1)). Before the map returns, MapKit must start only when the map is opened | Open, before the map returns |
| Carried from Wave 2: in Customer mode a Shopper's or Courier's app bar holds six actions, and the title shortens on a phone. The areas of W3-15 and W3-18 must not repeat it; the Shopper's area keeps two, the language and one menu (`DL-69` (5)), and the Courier's does the same (`DL-72` (1)); Customer mode's own app bar remains | Open for Wave 4 (P3) |
| Carried from Wave 2: the MapKit key and the free tier's fitness (`DL-36`) | Open, Owner |
| Carried from Wave 2, for Wave 4: CORS in production, device pruning, the push token change stream, reorder's stored answer | Open for Wave 4 |
| Carried from Wave 2, for Wave 5: a payment attempt's outcome is not guarded by the idempotency key, and Paynet and xazna have no adapters | Open for Wave 5 |
| Carried from Wave 2: iOS needs a Mac, which also brings the Apple Maps link (`DL-54` (16)); browser tests run in CI only | Open until a Mac exists and the local runner works |
| Until W3-17, the merged app labels a bought line with its ordered price beside the bought total, for example 18 400 a kg next to a total billed at 19 550. W3-17 shows the price to pay and the replacement (`DL-57` (4)) | Closed by W3-17 (`DL-71` (1)) |
| Wave 2 risk rows this plan takes on: the Courier assignment (W3-8), an estimate line added by an edit billed at its own markup (W3-3), the self-order mark after shopping completes (`DL-54` (14)), a Shopper blocked after an assignment (`DL-54` (13)), and the attention list's height (W3-13) | Planned in Wave 3 |
| From W3-7 until W3-8, completing a self-order's shopping drops its mark from the board and the attention list, and the row names no Shopper: both still read only the current assignment. W3-8 comes next and restores them as `DL-54` (14) sets them; no walkthrough runs between the two | Closed by W3-8 |

## Independent-review findings not acted on

| Task | Finding | Why not acted on |
|---|---|---|
| W3-9 (P3) | No test proves that an action's answer loads the Courier's own assignment rather than any current one | Closed by W3-10: the answer now keeps the assignment the action read under the order lock, or ended (`DL-64` (5)), and the delivered test fails when the answer reads it again |
| W3-10 (P3) | No race test of delivered against not-delivered, or of two delivered with different keys | Both take the order lock and read the caller's assignment again under it, which `CourierReplacedRaceTest` proves for the Courier's actions; the first to commit ends the assignment, so the second finds none and answers its natural repeat or the scope-safe `404`; and `payments_order_live_unique` refuses a second live payment whatever happens |

## Closure

Not yet.
