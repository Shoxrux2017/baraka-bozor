# BarakaBozor — Decision Log

## Purpose

One place for every decision that shapes the product or the engineering and that the code alone would not explain. Newest entries at the bottom. An entry is never edited after the fact; a later entry supersedes it and says so.

Who decides what, since 2026-09-24:

- **The Project Owner** decides product and business behaviour: what the service does for Customers, Shoppers, Couriers and staff, what is charged, and what is promised. The Owner is consulted only on a product question that neither the documents nor the interview of 2026-09-24 covers.
- **The implementing agent** (Claude Code) decides everything engineering: schema shapes, API details, error codes, concurrency, idempotency, libraries, structure, tests, deployment. It records each such decision here with its reason, so the Owner can overrule it later.

Earlier history: `docs/CONTRACT_ALIGNMENT_REPORT.md` (AUD-001 to AUD-029) and `docs/SPEC_DECISIONS_BACKLOG.md` (S-1 to S-43) are frozen records of the period when every decision went to the Owner. Every open item of that backlog is resolved below.

## DL-1 — Single implementing agent, full delegation (2026-09-24, Owner)

The three-party model (a planning agent, an implementing agent, the Owner merging) is retired. Claude Code is the only implementing agent: it plans, implements, verifies, obtains an independent review from a clean subagent, merges on a green CI run, runs the real stack, and reports once per wave. The Owner keeps one thing: a manual check of the product in the app once per wave, from a checklist the agent writes.

**Why:** the Owner was answering a question per task, and most of those questions were engineering. **Consequence:** `AGENTS.md`, `tasks/README.md` and the wave bookkeeping are rewritten for one implementer; concurrent-track machinery (`tasks/OWNERSHIP.md`, per-track worktrees, path ownership) is retired.

## DL-2 — Product decisions of the 2026-09-24 interview (Owner)

Recorded in full in `docs/INTERVIEW_2026-09-24.md`; `docs/01–09` are rewritten to match. The changes that alter the previously locked model:

1. **No prepaid flow.** Every order is paid after shopping. The Customer chooses cash to the Courier or online payment at checkout. Online: 30 minutes to pay after shopping completes, then Operator attention; the Operator may switch the order to cash or cancel it.
2. **Two price modes,** `fixed` and `estimate`, replacing `fixed`/`range`/`at_purchase`. `estimate` pays the actual purchase price; above the tolerance percentage the Shopper needs Customer approval first.
3. **Markup on goods** as a business setting, plus service fee and delivery fee.
4. **Cash accepted;** manual refunds tracked by the system; Payme and Click first, Paynet and xazna later.
5. **Web panel in the browser** for Operator, Admin and Manager instead of a Windows desktop application. Mobile stays Android and iOS.
6. **Admin does everything at launch;** Operator is a restricted Admin; Manager KPI screens deferred; Operators may assign; self-orders allowed with an audit flag.
7. **Order editing** by the Customer until shopping starts; minimum order amount; approval timing and cancellation rules as documented.
8. **Delivery:** handoff point by the market, several orders per Shopper, ASAP inside working hours plus a free-text wish, service area as a circle, Yandex MapKit, one fixed tariff, "not delivered" Courier action.
9. **Notifications:** push only; Courier gets push; Shopper polls in the foreground and gets push; Shopper calls the Customer from the app; Telegram Gateway for login codes first, Eskiz SMS fallback later; test phone numbers with a fixed code.
10. **Uzbek in Latin script,** in-app language switch defaulting to the device language, neutral design without brand assets.
11. **Cash-first pilot** as the order of work; hosting in Uzbekistan; personal Google Play account with closed testing now.

## DL-3 — Engineering resolutions of the former backlog (2026-09-24, agent)

Each former `S-` item, what was decided, and why. Owner-decided items are marked.

| Former | Decision |
|---|---|
| S-6 | `approval_required` is **derived**, not stored. `orders.status` stays `shopping` while an item awaits the Customer; the API exposes `pending_approval_count` and the board filters on `customer_approvals.status = pending`. No history rows for entering and leaving a derived state. |
| S-7 | After an approval is **granted** the item returns to `pending` with the approved result recorded on it (approved unit-price ceiling, authorized replacement product, or approved quantity cap); the Shopper then records the purchase as for any item. After a rejection the item is `removed`. |
| S-8 | `staff-activity` is deferred with the Manager screens. When built: per Staff member and period, count of shopping runs completed, deliveries completed, and average duration of each. |
| S-9 | Vocabularies fixed: `order_items.substitution_resolution` ∈ `automatic, approved`; `order_items.removed_reason_code` ∈ `unavailable, customer_rejected, approval_expired, customer_removed, operator_removed, order_cancelled`; `order_status_history.reason_code` ∈ `customer_cancelled, cancellation_request_approved, operator_cancelled, unpaid_online, no_items_purchased, delivery_failed, system`; assignment `ended_reason` ∈ `completed, reassigned, delivery_failed, order_cancelled`; `refunds.reason_code` ∈ `cancellation, correction`. A replacement must have the **same `unit_code`** as the original. |
| S-10 | "Unknown" payment outcome is **derived**: a `pending` attempt older than the provider timeout (15 minutes) with no result. A reconciliation job asks the provider; no new persisted state. |
| S-11 | An idempotency row in `processing` holds a **60-second lease**. A retry inside the lease gets `409 idempotency_in_progress`; a retry after it takes the row over and runs the operation again. |
| S-12 | `order_accepted` fires when the order is created (Owner, topic 7). |
| S-13 | An Admin price correction recomputes the order totals; an **unpaid** online payment obligation follows the new total. A paid obligation locks the correction (`price_correction_locked`). |
| S-14 | Cart status `abandoned` is dropped. Carts are `active` or `converted`. |
| S-15 | Product images are served from **public URLs** (local public disk in development, S3-compatible storage in production) with cache headers. They are not secret. |
| S-18 | Allowed with an audit flag (Owner, topic 6). |
| S-20 | `activate` validates then writes; a unique-index violation from a race is mapped to `409 phone_already_active`. |
| S-21–S-23 | Both names required, search across both languages (Owner, topic 2). |
| S-24 | Order item snapshots keep **both** names: `product_name_uz_snapshot`, `product_name_ru_snapshot`, and the same pair for the fulfilled product and for an approval's replacement. |
| S-25 | Bilingual catalog values are **paired columns** (`name_uz`, `name_ru`). A third language is not planned; when it comes, it is one migration. |
| S-26 | The Catalog API returns both languages; Admin writes accept both. The client picks the one to display. |
| S-27 | In-app switch, device default (Owner, topic 8). The client reports the choice; `users.preferred_language` ∈ `uz, ru` stores it for push texts. |
| S-29 | Password rule stays length 10–128 with the existing rate limits. No complexity rule, no breach list, no alerting in the MVP. |
| S-30 | Payment endpoints return `payment_provider_unavailable`; every other provider failure (Telegram, SMS, FCM) returns `provider_unavailable`. |
| S-31 | The error envelope gains an optional **`details`** object for machine-readable values, for example `{"minimum_order_uzs": 50000, "shortfall_uzs": 12000}`. `errors` stays the validation channel. |
| S-32 | A role on a surface that is not its own sees a client screen naming the right surface; the backend does not enforce surfaces (Owner, topic 6). |
| S-33 | Operators assign (Owner, topic 6). |
| S-34 | No offline queue. A Shopper action that cannot reach the server fails with a retry prompt and nothing is stored locally. |
| S-35 | Typo guard: an `estimate` price above the tolerance already needs approval. In addition the client asks the Shopper to confirm a price more than three times or less than a third of the estimate before sending it. |
| S-36 | `push_devices` is unique on `(push_token, user_id)`. A device holding two accounts has two rows. Logging out of one account revokes only that account's row. |
| S-37 | The Customer-mode switch ships with the Cart. Logging out of one mode ends only that session. Customer mode is not reachable while the Staff first-login gate is set. |
| S-38 | Role immutability is an application rule proven by a test (already decided). |
| S-39–S-43 | Notification events and codes: Customer `order_accepted, approval_required, payment_required, courier_started, order_delivered, order_cancelled`; Shopper `shopping_assigned, approval_answered, shopping_order_cancelled`; Courier `delivery_assigned, delivery_cancelled`. Push title and body come from a two-language template set on the backend, chosen by `users.preferred_language`; the payload carries the event type and the order or approval ID and no Customer data. |
| `09` §10 codes | Wrong `current_password` returns `401 invalid_credentials`; a `new_password` that fails the rule returns `422 validation_failed`. |
| Sanctum SPA config | Bearer tokens on every surface including the web panel; the web client keeps the token in browser storage through the same `TokenStore` port. CORS allows the panel's origin only. The unused Sanctum stateful-domain configuration is removed. |
| Error renderer | `400 malformed_request`, `409 business_conflict` (default for lifecycle conflicts without a more specific code), `502/503 provider_unavailable`, and `request_id` in every error response, replacing the interim rules of `S01-BE-001`. |
| D-9 shared fixtures | Retired as a mandatory mechanism. With one implementer the backend and the client are built by the same hands; the API examples live in `docs/09-api-contracts.md` and client DTO tests use those examples directly. |
| Windows build | Removed from the required targets (Owner, topic 6). Required targets: Android and web from the first client wave; iOS after the legal entity and a Mac. |

## DL-4 — Order lifecycle after the payment change (2026-09-24, agent)

States: `new, shopping_assigned, shopping, final_payment_pending, ready_for_delivery, delivery_assigned, on_the_way, completed, cancelled`. `checkout_payment_pending` is gone (no prepaid flow) and `approval_required` is derived (DL-3, S-6).

- Cash order: `shopping` → `ready_for_delivery` when shopping completes; the Courier records cash received when marking delivered.
- Online order: `shopping` → `final_payment_pending` when shopping completes; provider-confirmed payment → `ready_for_delivery`; 30 minutes unpaid → Operator attention; Operator may switch the order to cash (→ `ready_for_delivery`) or cancel.
- "Not delivered": `on_the_way` → `ready_for_delivery`, assignment ended with `delivery_failed`, Operator attention.
- Editing: allowed while `new` or `shopping_assigned` and shopping has not started; each edit re-snapshots the changed lines and writes history.

## DL-5 — Waves after the interview (2026-09-24, agent)

| Wave | Outcome |
|---:|---|
| 0 | Foundation: runtime, CI, identity, staff login, Customer login through the code-delivery abstraction (fake now), authorization, Flutter auth screens and role shells, web target |
| 1 | Catalog and account: Admin catalog in the web panel, Customer catalog and search, profile, addresses with the Yandex map picker, staff management, business settings, push device registration |
| 2 | Cart and order on cash: cart, checkout with cash or online choice (online disabled until Wave 5), order creation and editing, cancellation before shopping, assignment, the Admin board with its summary strip |
| 3 | Fulfilment: shopping, unavailability, substitution and approvals, Operator attention, courier delivery including "not delivered" and cash received, cancellation requests |
| 4 | Pilot readiness: real FCM push, notification events, history and reorder, Telegram Gateway login, deployment to the Owner's VPS, Android closed testing, web panel hosting, end-to-end check on cash |
| 5 | Online payment: Payme and Click adapters, the online flow with its 30-minute window and Operator switch, manual refund tracking, Eskiz SMS fallback |
| later | Manager KPI screens, Paynet and xazna, iOS release, delivery zones and tariffs, spreadsheet import, chat |
