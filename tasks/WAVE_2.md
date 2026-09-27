# Wave 2 — Cart and order on cash

Status: **Planned** (2026-09-27). Plan under workflow v6 (`tasks/README.md`). Scope from `DL-5` and `docs/06-roadmap.md` sections 2 and 3; engineering decisions for the wave in `DL-37`.

## Goal

The Customer can order: fill a cart from the catalog, check out to a saved address with cash (online shown as unavailable), see the order with its estimate or final total, edit it or cancel it until shopping starts. The Admin and the Operator see every order on a board in the web panel — filters, the summary strip, the attention list's first entries — and assign a Shopper, or reassign one, before shopping starts. A Shopper or Courier reaches their own cart through Customer mode. Shopping itself, the Shopper's screens and the Courier's assignment are Wave 3.

## Owner gate

None (`docs/06` section 5). The MapKit key the Owner set aside (`DL-36`) blocks nothing here: a build without it takes the address point as coordinates.

## Tasks

| # | Task | Status |
|---|---|---|
| W2-1 | Schema: `carts`, `cart_items`, `orders` with `orders_order_number_seq`, `order_items`, `order_history`, `order_shopper_assignments`, `idempotency_keys`; models and factories | Planned |
| W2-2 | Idempotency store: `IdempotencyStore` with the lease, replay and conflict rules, and the `Idempotency-Key` header check | Planned |
| W2-3 | Cart API: read, add, change, remove, with the quantity rules | Planned |
| W2-4 | Checkout preview: `WorkingHours`, `ServiceFeeCalculator`, the signed checkout token, every refusal | Planned |
| W2-5 | Order creation and the Customer's orders: create (idempotent), list, detail | Planned |
| W2-6 | Order editing and direct cancellation | Planned |
| W2-7 | Operations API: board list and detail, summary, attention, the Shopper picker, Shopper assignment and reassignment | Planned |
| W2-8 | Panel: the Operator's shell, the board inside the Admin's, and a reload that keeps its page | Planned |
| W2-9 | Panel: the board — list with filters, summary strip, attention, order detail with history, Shopper assignment | Planned |
| W2-10 | App: cart — add from the product screen, the cart screen | Planned |
| W2-11 | App: checkout — address, payment method, delivery wish, preview, confirm | Planned |
| W2-12 | App: my orders — list, detail, edit, cancel | Planned |
| W2-13 | Wave closure: full suites, builds, real-stack walkthrough of the wave's scenario, Owner checklist and report | Planned |

Backend first, in order; the panel after W2-7; the app after W2-6. As in Wave 1 the split is by layer (`tasks/README.md` section 2 prefers slices): the panel and the app consume the same order API, and each screen task then tests against a merged contract.

## Task notes

**W2-1.** Forward migrations exactly as `docs/08` sections 9, 10, 13 to 16 and 27 describe them, with the Wave 1 conventions (`DL-18`): UUID keys, `timestamptz`, named checks, `RESTRICT` foreign keys, partial unique indexes (`carts (customer_id) WHERE status='active'`, `order_shopper_assignments (order_id) WHERE ended_at IS NULL`). `orders_order_number_seq` starts at 1001 (`DL-37` (2)). `order_items` carries every column of section 14 now, although Wave 3 fills most of them, so no later migration reshapes a table with rows in it; the same for `orders`. The history `event_type` and `reason_code` checks take the full vocabularies of `DL-3` S-9. `order_courier_assignments`, `customer_approvals`, `order_cancellation_requests`, `order_item_price_corrections`, `payments` and below are created by the wave that first needs them. Models with casts, `$fillable` kept to what input may set (`DL-18` (2)), factories that can build an order in any of the nine states for later tests. Tests: every check, unique and partial index; the sequence; a rollback.

**W2-2.** `App\Support\Idempotency`, beside `Money` and `Scope`, because shopping, delivery and payment actions of later waves use it too: `begin(actor, operation, key, requestHash)` → `new | replay(resource) | in_progress | conflict`, `complete(resourceType, resourceId)`, per `docs/07` section 17 and `DL-3` S-11 — a 60-second lease, a takeover after it, `409 idempotency_in_progress` inside it, `409 idempotency_key_reused` for another hash, `400 idempotency_key_required` without the header. The key is a UUID; the request hash is SHA-256 over the canonical JSON of the validated body. `begin` and the operation's own writes share one transaction, so a crash leaves no completed key without its effect. Tests: each outcome, the lease boundary under a controlled clock, two concurrent requests with one key.

**W2-3.** `App\Modules\Orders` (cart, checkout and orders live together; `DL-37` (1)). `GET /customer/cart` creates the active cart on first access (`BR-CART-001`); `POST /customer/cart/items`, `PATCH|DELETE /customer/cart/items/{item}` per `docs/09` section 17. `QuantityPolicy` per `BR-QTY-001` with the bounds of `DL-37` (6); a product must be active in an active category to be added (`BR-CAT-003`, `product_unavailable`), and a product that becomes unavailable stays in the cart marked unavailable so the Customer sees why checkout refuses it. The response carries current customer prices, each line's estimate total and `estimated_subtotal_uzs` from the current markup (`BR-CART-003`). Duplicate product → `409 cart_item_already_exists`. Tests: unit precision per unit, the bounds, another Customer's item a scope-safe `404`, archived products, prices following the markup.

**W2-4.** `WorkingHours` in `Asia/Tashkent` (a pair where closing is before opening spans midnight); `ServiceFeeCalculator` per `BR-MONEY-005`. `POST /customer/checkout/preview` per `docs/09` section 18 with every check of `BR-CHK-001` to `BR-CHK-009` in the order the section lists its codes; `online` answers `409 payment_method_unavailable` in this wave whatever the enablement switches say (`DL-37` (3)). The signed token of `DL-37` (4). A foreign or deactivated address is the scope-safe `404`. Tests: each refusal with its `details`; `final` versus `estimate`; the working-hours note across midnight and at the boundaries; the token refused after five minutes and after any bound change (cart line, product price, markup, fee, address point, payment method, delivery wish).

**W2-5.** `POST /customer/orders` (`Idempotency-Key`, `{"checkout_token"}`): under the cart lock, recompute the bound state and compare with the token (`409 checkout_snapshot_stale` on any difference or expiry), re-run the preview's checks, then in one transaction create the order with every snapshot of `docs/07` section 13, its items, a `status_changed` history row (`null → new`), the cart `converted`, a new empty active cart (`BR-CHK-008`), and the next order number; answer `201` with the order resource of `docs/09` section 20. `GET /customer/orders` (own, newest first, paginated) and `GET /customer/orders/{order}` with `can_edit`, `can_cancel_directly`, `can_request_cancellation` computed from the state. No push yet (`DL-37` (10)). Tests: a replay returns the same order and creates nothing; the stale paths; snapshots unchanged after a catalog, markup and settings change; two concurrent creations from one cart make one order.

**W2-6.** `PUT /customer/orders/{order}/items` per `docs/09` section 21 and `DL-6`: under the order lock, while `new` or `shopping_assigned` with no started assignment, else `409 order_editing_locked`; lines that stay keep their price snapshots, added lines take current prices, fee and markup snapshots untouched, the minimum re-checked, one `edited` history row. `POST /customer/orders/{order}/cancel` (`Idempotency-Key`, optional `reason`, `DL-37` (9)) while `new` or `shopping_assigned`: `cancelled`, `cancelled_at`, reason `customer_cancelled`, the current Shopper assignment ended with `order_cancelled`, a history row. The request branch for later states arrives with Wave 3; until then those states answer `409 order_cancellation_not_allowed`. Tests: every lifecycle refusal, a replay, an edit that removes every line refused, snapshots of kept lines untouched while the catalog price moved.

**W2-7.** `GET /operations/orders` with the filters of `DL-37` (11), `GET /operations/orders/{order}` (history, assignments with `is_self_order`, the Customer's name and phone, the address), `GET /operations/summary`, `GET /operations/attention` (`self_order` in this wave), `GET /operations/shoppers` (`DL-37` (7)), `POST|PUT /operations/orders/{order}/shopper-assignment` per `docs/09` section 39 and `docs/04` section 11: under the order lock, an active Shopper (`409 staff_not_active`), `new` for a first assignment and `shopping_assigned` without a started assignment for a reassignment (`409 order_state_conflict`), the old assignment ended `reassigned`, history `shopper_assigned` / `shopper_reassigned`, `is_self_order` from the phones (`BR-ASSIGN-005`). Operator and Admin (`DL-12`). Tests: role refusals, each state refusal, the self-order flag, the summary's day boundary in `Asia/Tashkent`.

**W2-8.** The Operator's panel is the Admin's with catalog, staff and settings hidden (`docs/02` section 7): the board is feature `operations` under `/operations`, the Admin's shell lists it first beside its own sections and the Operator's lists only it (`DL-37` (12)). The session guard keeps the location it was asked for through the bootstrap, so a reload of a deep page returns there when the role may see it (the Wave 1 risk row). Tests: each role's navigation, a reload of a deep page for Admin and Operator, a deep page the role may not see going to its area's home.

**W2-9.** Panel feature `operations`: the board as a server-paginated table (number, time, Customer, status, total or estimate, Shopper, self-order mark) with the filters of W2-7, the summary strip above it, the attention list beside it; the order detail with items, snapshots, totals, address, delivery wish, history and assignments; assign or reassign a Shopper from `GET /operations/shoppers`. One `AdminMutation`-style controller per surface (`DL-28`), `AccountMutation` rules throughout. Tests: DTOs from `docs/09`, request bodies, the stale state answered `409` reloading the order, the narrow window.

**W2-10.** App feature `cart`: "add to cart" on the product screen with quantity by unit (a decimal field for `kg`, `liter`, `meter`, a stepper otherwise), note and substitution rule (default `allow_similar_substitution`); the cart screen with lines, change and remove, the estimate subtotal from the server; a cart badge in the Customer shell. Quantities are strings end to end; the client never sums money (`DL-37` (14)). Tests: DTOs, precision per unit, the duplicate answered by opening the existing line.

**W2-11.** App feature `checkout`: pick an active address (or add one), cash selected and online shown unavailable with its reason, the delivery wish (160), the preview with its lines, fee, delivery, total and the `estimate` label, the working-hours note; confirm sends the token with an `Idempotency-Key` generated once per confirmation and reused on a retry; `checkout_snapshot_stale` refreshes the preview and says so; each refusal code has its own text with the `details` values (the minimum and the shortfall). Tests: each refusal text, the key reused on a retry and new after a fresh preview, the stale path.

**W2-12.** App feature `orders`: list (newest first, paginated) and detail — status wording for the nine states, items with snapshots, totals as `estimate` or `final`, address, delivery wish; edit (the cart-like editor over the order's lines, sending the full list) and cancel with a confirmation, each shown only when the server's `can_edit` / `can_cancel_directly` says so, and a `409` answered by reloading the order. Tests: the state wordings, the edit body, the lock refusals.

**W2-13.** Closure per `tasks/README.md` section 4 with the committed walkthrough tooling (`DL-35`): a `tasks/scripts/wave2_api_walkthrough.py`, the panel and the emulator. The scenario: Admin completes the settings; a Customer fills a cart, is refused below the minimum and with online, orders with cash, edits the order, cancels a second one; the Operator sees both on the board, assigns a Shopper, reassigns, sees a self-order flagged when the Shopper orders from their own phone through Customer mode; the summary strip counts them.

## Risks and housekeeping

| Item | Status |
|---|---|
| Push notifications for `order_accepted`, `shopping_assigned` and `shopping_order_cancelled` are Wave 4's (`DL-37` (10)); until then a Shopper learns of an assignment only from the board or a phone call, and the Shopper's own screens are Wave 3 | Accepted for the wave |
| The courier assignment moves to Wave 3, where `ready_for_delivery` is first reachable (`DL-37` (8)) | Planned in Wave 3 |
| The MapKit key and the free tier's fitness (`DL-36`) | Open, Owner; nothing in the wave depends on it |
| Carried from Wave 1, for Wave 4: CORS for the API and for the image host in production, device pruning, the push token change stream | Open for Wave 4 |

## Independent-review findings not acted on

None yet.

## Closure

Not yet.
