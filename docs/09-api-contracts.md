# BarakaBozor — API Contracts

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `DL-2`–`DL-4` in `docs/DECISIONS.md`. Endpoints marked *(later)* are not built before the wave that owns them.

## 1. General

Base `/api/v1`, HTTPS, JSON. Protected requests carry a Sanctum bearer token. IDs are UUID strings; money is integer UZS; quantities and percentages are decimal strings; instants are ISO-8601 UTC. Every `message` is developer English and is never shown to a user.

## 2. Success Envelope

Single resource: `{"data": {...}}`. Collection: `{"data": [...], "meta": {"pagination": {"page":1,"per_page":20,"total":0,"last_page":1}}}`. No body: `204`.

## 3. Error Envelope

```json
{
  "message": "Developer-facing English.",
  "code": "stable_machine_code",
  "errors": {},
  "details": {},
  "request_id": "req_..."
}
```

`errors` holds field errors for `validation_failed` and is `{}` otherwise. `details` carries machine-readable values a client needs to compose its own text (for example a minimum amount) and is omitted when empty. `request_id` is generated per request, written to that request's log lines, and returned in error responses only.

HTTP baseline: `200/201/204` success; `400 malformed_request` for a JSON body that cannot be read, a URL path that is not UTF-8, or text that is not UTF-8 or holds a NUL byte in the query string, the body or an uploaded file's name (`DL-24`); `401` unauthenticated or blocked; `403 forbidden`; `404 resource_not_found` (scope-safe); `409` lifecycle, business, idempotency or concurrency conflict; `413 payload_too_large` for a body above the server's limit (8 MiB); `422 validation_failed`; `429 rate_limited` with `Retry-After`; `502/503 provider_unavailable` for an external provider; `503 service_unavailable` for planned maintenance, with `Retry-After`; `500 server_error`. Any other client status folds to the scope-safe `404`; any other server status keeps its number with `server_error`. No response ever carries exception text, SQL, paths, class names, secrets or raw provider errors.

## 4. Strict Request Shape

Mutation endpoints reject unknown fields with `validation_failed`; an endpoint that takes no body refuses any field, and `{}` counts as no body. The query string of a mutation is not part of its shape (`DL-20` (2), `DL-31`). Clients never send roles, statuses, billable quantities, totals, prices (other than the Shopper's actual market price) or payment states.

## 5. Pagination

`page` (default 1), `per_page` (default 20, max 100), deterministic ordering.

# Authentication

## 6. Request Customer Login Code

`POST /auth/customer/code/request` `{"phone":"+998901234567"}`

Phone: E.164 `+998` plus nine digits. Policy: six digits, five-minute lifetime, five failed verifications, sixty seconds between sends, five sends per phone per hour. The response never discloses whether an account exists:

```json
{"data":{"channel":"telegram","expires_in_seconds":300,"resend_available_in_seconds":60}}
```

`channel` ∈ `telegram, sms, fake, test`. `fake` is what the development gateway reports; `test` means a configured test phone that needs no delivery. The client shows channel-specific text for `telegram` and `sms` and a generic "code sent" otherwise. Codes: `code_resend_too_soon`, `rate_limited`, `provider_unavailable`, `validation_failed`.

## 7. Verify Customer Login Code

`POST /auth/customer/code/verify` `{"phone":"+998901234567","code":"482913"}`

Resolves the active Customer account or creates one when none is active, then issues a token:

```json
{"data":{"token":"...","user":{"id":"...","role":"customer","phone":"+998901234567","full_name":null,"status":"active","must_change_password":false,"preferred_language":"uz"}}}
```

Codes: `code_invalid`, `code_expired`, `code_attempts_exhausted`, `account_blocked` (evaluated only after the code is valid, `401`). Never issues a staff session. A configured test phone accepts the configured fixed code.

## 8. Staff Login

`POST /auth/staff/login` `{"phone":"+998901234567","password":"..."}` → token plus the user object above with the staff role. Codes: `invalid_credentials`, `account_blocked`, `rate_limited` (five failures per phone per minute, twenty per IP per minute). A token unused for 30 days answers `401 authentication_required`; a valid token on a blocked account answers `401 account_blocked`.

## 9. Current Identity

`GET /auth/me` → the user object. `PATCH /auth/me` `{"preferred_language":"ru"}` for any role.

## 10. Change Staff Password

`POST /auth/change-password` `{"current_password":"...","new_password":"...","new_password_confirmation":"..."}`. New password 10–128 characters. `new_password` is validated first (`422 validation_failed`); a wrong `current_password` answers `401 invalid_credentials` and counts toward five failures per token per minute (`429 rate_limited`). Clears the gate.

## 11. Logout

`POST /auth/logout` → `204`, revokes the caller's token. While the gate is set only Sections 9–11 are reachable.

# Customer Profile and Addresses

## 12. Profile

`GET /customer/profile`, `PATCH /customer/profile` `{"full_name":"...","preferred_language":"uz"}`. A Customer session is required. The response is `{"data":{"id":"...","phone":"+998901234567","full_name":"Aziza Karimova","preferred_language":"uz"}}`. PATCH takes either field or both: `full_name` is trimmed and holds 1–120 characters and cannot be cleared; `preferred_language` is `uz` or `ru`. The phone is not editable (`DL-23`).

## 13. Addresses

`GET|POST /customer/addresses`, `GET|PATCH|DELETE /customer/addresses/{address}`, a Customer session and own addresses only. Body: `latitude`, `longitude` (decimal strings, at most six decimals, a JSON number is refused), `street` (1–160), `house` (1–40), optional `label` (60), `apartment` (40), `landmark` (160), `delivery_note` (300). PATCH takes any non-empty subset, but the two coordinates always together. The response carries `id, label, latitude, longitude, street, house, apartment, landmark, delivery_note, created_at, updated_at`, coordinates as six-decimal strings; create answers `201`, delete `204`. A point outside the service area answers `422 address_outside_service_area` with `details.max_distance_km` and `details.distance_km`; while the service area is not configured, create and an update that moves the point answer `409 checkout_configuration_incomplete`; an update that keeps the point is not checked again (`DL-23`). Delete always deactivates (`DL-17`); the list returns active addresses only, newest first, and a deactivated or foreign address is the scope-safe `404` everywhere.

# Catalog

## 14. Customer Catalog

`GET /catalog/categories?page=&per_page=`, `GET /catalog/products?category_id=&search=&page=&per_page=`, `GET /catalog/products/{product}`, all paginated lists in the envelope of Section 2. A Customer session is required (`DL-17`). A product is listed only while it and its category are active and unarchived, and otherwise its detail is the scope-safe `404`; a category is listed only while it is active, unarchived and holds at least one such product (`DL-22`). Both lists are ordered by `sort_order`, then `name_uz`, then `id`; a `category_id` the Customer cannot see gives an empty list, like one that does not exist. A category carries `id, name_uz, name_ru, description_uz, description_ru, sort_order`; a product never carries the market price.

Product:

```json
{"id":"...","category_id":"...","name_uz":"Pomidor","name_ru":"Помидор","description_uz":null,"description_ru":null,
 "unit_code":"kg","price_mode":"estimate","customer_unit_price_uzs":18400,"image_url":"https://.../storage/products/<uuid>.webp","is_active":true}
```

Search matches `name_uz` and `name_ru` as a substring, ignoring letter case, reading `ё` as `е` and every form of the Uzbek apostrophe (ʻ ‘ ’ `) as `'` (`DL-20`).

## 15. Admin Catalog

`GET|POST /admin/categories`, `GET|PATCH /admin/categories/{category}`, `POST .../archive`, `POST .../restore`; the same for `/admin/products`. Lists are paginated, ordered by `sort_order` then `name_uz`, and take `include_archived`; the product list also takes `category_id` and `search`. Product write body: `category_id, name_uz, name_ru, description_uz?, description_ru?, unit_code, price_mode, market_price_uzs, sort_order?, is_active?` (`sort_order` defaults to 0, `is_active` to true); an update takes any non-empty subset. Archive sets `archived_at` and `is_active = false`; restore clears `archived_at` and sets `is_active = true`; both are natural repeats; `is_active` alone hides an entry without archiving it, and `is_active: true` on an archived entry answers `409 business_conflict`. A product is created in, or moved to, an existing unarchived category only (`422 validation_failed` on `category_id`); an edit that re-sends the product's current category is not a move; archiving a category leaves its products as they are. Admin responses also carry `market_price_uzs`, the computed `customer_unit_price_uzs`, `image_url` (`null` without an image) and `archived_at`.

## 16. Product Image

`POST /admin/products/{product}/image` (multipart field `image`; JPEG, PNG or WebP judged by the bytes, not the file name; at most 5 MiB) replaces the current image under a fresh key, so `image_url` changes; two uploads for one product at once are serialized, and one that still collides answers `409 business_conflict`; `DELETE` removes it and is a natural repeat. A file field other than `image` is refused like an unknown field. Both answer the Admin product with `image_url` (`null` without an image). An archived product accepts an image.

# Cart and Checkout

## 17. Cart

`GET /customer/cart`, `POST /customer/cart/items` `{"product_id":"...","quantity":"5.000",` (a `kg` product) "customer_note":"...","substitution_policy":"allow_similar_substitution"}`, `PATCH /customer/cart/items/{item}`, `DELETE /customer/cart/items/{item}`. Duplicate product → `409 cart_item_already_exists`. Unit precision validated; a quantity is at most 9 999.999 for `kg`, `liter`, `meter` and 9 999 otherwise, and a cart holds at most 100 lines (`409 cart_full`). A hidden product and an unknown id both answer `409 product_unavailable`. Every call answers the whole cart — `201` for an added line, `200` otherwise, a removal included — as `{"id","items":[{"id","product_id","name_uz","name_ru","unit_code","price_mode","image_url","quantity","customer_note","substitution_policy","is_available","customer_unit_price_uzs","estimated_line_total_uzs"}],"item_count","estimated_subtotal_uzs"}`: current customer prices, a line's price and estimate `null` when its product is no longer available, and the subtotal over the available lines (`DL-37` (6), (20), `DL-40`). A quantity is answered with three decimals for `kg`, `liter`, `meter` (`"1.500"`) and as a whole number otherwise (`"2"`), unless an Admin has since changed the product to a whole unit, when it keeps its decimals and checkout refuses the line; the client sends a whole unit's quantity without a fraction. `cart_item_already_exists` carries `details.cart_item_id`, `cart_full` `details.max_lines`, `product_unavailable` `details.product_ids`. A line whose product is unavailable may be removed, not changed.

## 18. Checkout Preview

`POST /customer/checkout/preview` `{"address_id":"...","payment_method":"cash","delivery_time_note":"после 18:00"}`

```json
{"data":{
  "lines":[{"cart_item_id":"...","product_id":"...","name_uz":"...","name_ru":"...","unit_code":"kg","quantity":"5.000","price_mode":"estimate","customer_unit_price_uzs":18400,"line_total_uzs":92000}],
  "merchandise_subtotal_uzs":225000,"service_fee_uzs":11250,"delivery_fee_uzs":15000,"total_uzs":251250,
  "total_kind":"estimate",
  "outside_working_hours":true,"opens_at":"08:00",
  "checkout_token":"...","checkout_token_expires_at":"..."}}
```

`total_kind` ∈ `final, estimate`; an order's totals also take `none`, with every amount `null`, once it is cancelled (`DL-37` (10)). The preview also echoes `payment_method` and `delivery_time_note`; `opens_at` is `null` when the business is always open; `checkout_token_expires_at` is five minutes after the preview. Codes, checked in this order (`DL-37` (21), `DL-41`): `409 checkout_configuration_incomplete`; `409 customer_profile_incomplete`; the scope-safe `404` for an address that is not the Customer's own active one; `409 address_incomplete`; `422 address_outside_service_area` (`details` as in section 13); `409 cart_empty`; `409 product_unavailable` (`details.product_ids`, also for a line whose quantity no longer fits its product's unit); `409 minimum_order_not_reached` (`details.minimum_order_uzs`, `details.shortfall_uzs`, on the merchandise subtotal); `409 payment_method_unavailable`.

## 19. Create Order

`POST /customer/orders` with `Idempotency-Key: <UUID>`, body `{"checkout_token":"..."}`. Revalidates, snapshots, converts the cart, creates the new cart, assigns `order_number`, answers `201` with the order; a replay of the same key and token answers `201` with that order as it is now. Stale token → `409 checkout_snapshot_stale`: the token is not the Customer's, is past its five minutes, was made for a cart that has since been ordered, or no longer matches the checkout; a check of section 18 that now fails answers its own code (`DL-42`). Until the payment adapters of Wave 5 exist, `online` answers `409 payment_method_unavailable` at preview and creation whatever the provider switches say (`DL-37` (3)). Before shopping completes an order's `totals` are computed from its snapshots over the lines not removed and labelled like the preview; from completion they are the stored final amounts with the kind `final`; a cancelled order's totals are `null` with the kind `none` (`DL-37` (10)).

# Customer Orders

## 20. Orders

`GET /customer/orders`, `GET /customer/orders/{order}`. Own orders only; another Customer's order is the scope-safe `404`. The list is newest first and answers a summary per order — `id, order_number, status, payment_method, item_count, pending_approval_count, total_uzs, total_kind, created_at` (`pending_approval_count`, the pending approvals not past their expiry, from Wave 3, `DL-54` (8)) — and the detail answers the order resource (`DL-42`):

```json
{"id":"...","order_number":1042,"status":"shopping","payment_method":"cash",
 "pending_approval_count":1,"can_edit":false,"can_cancel_directly":false,"can_request_cancellation":true,
 "items":[...],"totals":{"merchandise_subtotal_uzs":225000,"service_fee_uzs":11250,"delivery_fee_uzs":15000,"total_uzs":251250,"total_kind":"estimate"},
 "address":{...},"delivery_time_note":"...","payment":null,"refunds":[],"timestamps":{...}}
```

An item carries `id, product_id, name_uz, name_ru, unit_code, price_mode, quantity` (ordered), `customer_note, substitution_policy, status, customer_unit_price_uzs, line_total_uzs` (the snapshotted price times the ordered quantity until the line is bought, then the stored total, `0` when removed), `billable_quantity` (`null` until bought or removed), `removed_reason_code`, `billable_unit_price_uzs` (what the Customer pays for one unit once the line is bought, else `null`; never the price paid at the market), and `replacement` (`{name_uz, name_ru}` of the replacement authorized or bought, else `null`; `null` for a removed line and while the line waits on a substitution question, open or expired) and `pending_approval` (the line's open question, `{id, type, proposed_customer_unit_price_uzs, proposed_quantity, replacement{name_uz, name_ru, customer_unit_price_uzs}|null, request_note, expires_at}`, else `null`) (`DL-57` (4), (6), `DL-59` (2)); removed lines are listed with their status. The order also carries `cancellation_reason_code`. `pending_approval_count` counts the open questions, those past their expiry left out (`DL-59` (2)). Until their waves, `payment` is `null`, `refunds` is empty and `can_request_cancellation` is `false`.

`payment` is `null` until one is made, then `{method, status, amount_uzs, paid_at}`: the cash the Courier took at the door, `paid` (`DL-64` (4)); `refunds` stays `[]` until Wave 5.

## 21. Edit Order

`PUT /customer/orders/{order}/items` `{"items":[{"product_id":"...","quantity":"2","customer_note":null,"substitution_policy":"contact_before_substitution"}],"delivery_time_note":"..."}` → the order. Allowed while `new` or `shopping_assigned` and shopping has not started; otherwise `409 order_editing_locked`. At least one and at most 100 items (`422` on `items`), each product once (`422` on the repeated `items.N.product_id`); `delivery_time_note` must be sent, `null` to clear it; a line's `customer_note` and `substitution_policy` default to none and `allow_similar_substitution` when left out. Lines that are gone stay as `removed` with `customer_removed`; an unchanged list is a natural repeat (`DL-37` (9)). A line that stays keeps its price and is held to the unit it was ordered in; an added product must be one the Customer may see (`409 product_unavailable`, naming it); an edit that lowers the merchandise must still reach the minimum (`409 minimum_order_not_reached`), and one that changes nothing is a natural repeat whatever the settings say now. Edits are throttled per Customer (`429 rate_limited`). Answers `200` with the order (`DL-43`).

## 22. Cancel or Request Cancellation

`POST /customer/orders/{order}/cancel` with `Idempotency-Key`, `{"reason":"..."}` (up to 300 characters; optional for a direct cancellation, required for a request, `DL-37` (13)). While `new` or `shopping_assigned` and shopping has not started: cancels at once, pending lines become `removed` with `order_cancelled`, the current Shopper assignment ends with `order_cancelled`, and the reason is kept on the history row; an already cancelled order is a natural repeat. Answers `200` with the order (`DL-43`). From `shopping` through `delivery_assigned` *(Wave 3)*: creates a pending request (`409 cancellation_already_pending` if one exists); until Wave 3 these states answer `409 order_cancellation_not_allowed`. From `on_the_way`: `409 order_cancellation_not_allowed`.

## 23. Approvals

`GET /customer/approvals?status=pending`, `GET /customer/approvals/{approval}`, `POST /customer/approvals/{approval}/decision` with `Idempotency-Key`, `{"decision":"approve"}` or `"reject"`. Own approvals only; another's is the scope-safe `404`. The list is paginated, newest first; `status` takes the five values, `pending` leaving out and `expired` taking in an approval past its expiry (`DL-54` (8)). Only an own pending approval is decided: an overdue one is expired first, and that stands, then `409 approval_expired`; a resolved one `409 approval_already_resolved`. The decision answers `200` with the approval (`DL-59`).

Approval resource (`status` also `cancelled` once its order is cancelled, `DL-54` (8)): `{id, order_id, order_number, type, status, item{id, name_uz, name_ru, unit_code, price_mode, quantity, customer_unit_price_uzs}, proposed_customer_unit_price_uzs, proposed_quantity, replacement{name_uz, name_ru, customer_unit_price_uzs}|null, request_note, expires_at, resolved_at, created_at}` — the Customer's prices only, never the price paid at the market (`BR-PRICE-001`); `status` reads `expired` once the approval is past its expiry (`DL-59` (1)). A price question whose `replacement` is `null` is about the original, and approving it drops the replacement the line shows. A decision on an order no longer being shopped, a line no longer waiting, or a replacement no longer on the line is `409 order_state_conflict`; the expiry and the decision are judged at one instant (`DL-59` (3)).

## 24. Payment *(online, Wave 5)*

`GET /customer/orders/{order}/payment` → the obligation with its attempts. `POST /customer/orders/{order}/payment/attempts` with `Idempotency-Key`, `{"provider":"payme"}` → the attempt and a provider-action union the client follows. Codes: `payment_method_not_online`, `payment_not_payable`, `payment_already_paid`, `payment_outcome_pending`, `payment_provider_disabled`, `payment_provider_unavailable`.

## 25. Refunds

`GET /customer/orders/{order}/refunds` → own refund records with status.

## 26. Reorder

`POST /customer/orders/{order}/reorder` with `Idempotency-Key` → `{"added_items":[...],"skipped_existing_items":[...],"unavailable_items":[...]}`. Never creates an order.

## 27. Push Devices

`POST /push-devices` `{"platform":"android","token":"..."}` (bound to the calling account), `DELETE /push-devices/{device}`. Any signed-in account past the password gate. `platform` is `android`, `ios` or `web`; `token` is trimmed and then 1–512 printable ASCII characters. Registering creates the device or refreshes it and revives it if revoked, and always answers `200` `{"data":{"id":"...","platform":"android","last_seen_at":"...","created_at":"..."}}`; the token is not echoed. Delete revokes the caller's own device and answers `204`, also when it is already revoked; another account's device is the scope-safe `404` (`DL-26`).

# Shopper

## 28. Assigned Orders

`GET /shopper/orders`, `GET /shopper/orders/{order}`. Current assignments only; any other order, a replaced Shopper's included, is the scope-safe `404` (`DL-54` (3)). The list is paginated, the longest-waiting assignment first, a row `{id, order_number, status, item_count, open_item_count, delivery_time_note, assignment{id, assigned_at, accepted_at, started_at}}`: `item_count` counts the lines the Shopper sees — every line but those the Customer removed before shopping — and `open_item_count` those still `pending` or `awaiting_customer`. The detail is `{id, order_number, status, delivery_time_note, customer_phone, assignment, can_accept, can_start, items}` — `customer_phone` the recipient's, `null` unless the order is `shopping` — with `items` oldest first:

```json
{"id":"...","product_id":"...","name_uz":"...","name_ru":"...","unit_code":"kg","price_mode":"estimate",
 "quantity":"2.000","approved_quantity_cap":null,"customer_note":"...","substitution_policy":"allow_similar_substitution","status":"pending",
 "market_price_uzs":16000,"customer_unit_price_uzs":18400,
 "bound":{"customer_unit_price_uzs":21160,"market_price_uzs":18400},
 "replacement":{"product_id":"...","name_uz":"...","name_ru":"...","market_price_uzs":15500,"substitution_resolution":"automatic",
                "bound":{"customer_unit_price_uzs":21160,"market_price_uzs":18400}},
 "purchase":{"product_id":"...","purchased_quantity":"2.000","billable_quantity":"2.000","actual_market_price_uzs":16000,"billable_unit_price_uzs":18400,"line_total_uzs":36800},
 "removed_reason_code":null,
 "pending_approval":{"id":"...","type":"price_over_tolerance","expires_at":"..."}}
```

`bound` is the bound of the original (`DL-54` (5)), `null` for a fixed line bought as itself; `replacement` is the authorized replacement, with its current market price and its own bound, or `null`, as it is for a removed line (`DL-57` (6)); each bound is the customer price and the highest market price within it under the line's markup (`DL-54` (6)); `purchase` is `null` until the line is bought, `pending_approval` while no question is pending. The resource never carries the address, the Customer's name or any amount the order owes (`docs/02` section 11, `DL-56`).

## 29. Accept and Start

`POST /shopper/orders/{order}/accept`, `POST /shopper/orders/{order}/start`, no body (`DL-31`); both answer `200` with the order of section 28. Natural no-op repeats. Start requires acceptance and a `shopping_assigned` order, else `409 order_state_conflict`; it moves the order to `shopping`, after which the Customer can no longer edit or cancel it directly (`DL-56` (3), (4)).

## 30. Record Purchase

`POST /shopper/orders/{order}/items/{item}/purchase` with `Idempotency-Key`

```json
{"purchased_quantity":"5.200","actual_market_price_uzs":16000,"fulfilled_product_id":"..."}
```

`actual_market_price_uzs` is required for estimate items and replacements, optional for fixed originals. The server computes the billable unit price. Above the bound of the product bought (`DL-54` (5)) → `409 customer_approval_required` with `details.approval_type` `price_over_tolerance`, `details.ceiling_customer_unit_price_uzs` (that bound) and `details.proposed_customer_unit_price_uzs`; a purchased quantity below the ordered quantity or the approved cap → the same code with `details.approval_type` `reduced_quantity` and `details.required_quantity` (`DL-54` (4)). `fulfilled_product_id` is the line's own product or the replacement authorized on it (`422` otherwise), and left out means the authorized replacement when there is one. The Customer sees the billable customer price, never the price paid. The purchase answers `200` with the order of section 28; a replay answers it as it is now. Codes: `shopping_not_active` (an order the caller holds is not `shopping`, or the caller has not started it; any other order is the scope-safe `404`), `item_already_resolved` (the line is not `pending`); a line the Shopper does not see — one the Customer removed, another order's — is the scope-safe `404` (`DL-57`).

## 31. Unavailable

`POST /shopper/orders/{order}/items/{item}/unavailable` `{"note":"..."}` (optional, up to 300 characters, kept on the history row) → the item removed with `unavailable`, whatever its rule, and the order of section 28. No key: a repeat meets `409 item_already_resolved`. When it leaves every line removed, the order is cancelled with `no_items_purchased` and answered as it now stands, cancelled and without the Shopper's assignment (`DL-54` (7), `DL-57`).

## 32. Price Approval

`POST /shopper/orders/{order}/items/{item}/price-approval` `{"actual_market_price_uzs":22000,"fulfilled_product_id":"...","note":"..."}` → a `price_over_tolerance` approval carrying the computed proposed customer price. `fulfilled_product_id` is optional and means what it means for a purchase (section 30); the approval names the replacement when it is about one (`DL-54` (5)). Only when the price exceeds the bound of that product; otherwise, and always for a fixed original, `409 approval_not_needed` (with `details.ceiling_customer_unit_price_uzs` when the product has a bound). The approval is `pending` with `attention_at` ten minutes and `expires_at` thirty minutes on; the line becomes `awaiting_customer`, and the answer is the order of section 28 (`DL-58`).

## 33. Substitution

`POST /shopper/orders/{order}/items/{item}/substitution` `{"replacement_product_id":"...","actual_market_price_uzs":11000,"note":"..."}` → either the item authorized for the replacement (`substitution_resolution: automatic`) or a `substitution` approval, according to the item's policy and ceiling. `GET /shopper/orders/{order}/items/{item}/replacements?search=&page=&per_page=` lists the products the Customer's catalog shows — active, in an active category — of the line's unit other than the original, with their market price (`DL-54` (17), `DL-58` (5)). A line carries one authorized replacement at a time: a new substitution replaces it; an approved price belongs to the product it was approved for, and a substitution is judged against the automatic ceiling of `BR-PRICE-005`, never against a price approved for another replacement (`DL-54` (5)). A replacement under `remove_if_unavailable` is `409 substitution_not_allowed`; an inactive one, or one in an inactive category, `409 product_unavailable` with `details.product_ids`; the original itself `422` on `replacement_product_id`; the replacement already authorized, proposed again, is a natural repeat within its bound and above it the purchase's `409 customer_approval_required`. Both outcomes answer the order of section 28 (`DL-58`).

## 34. Reduced Quantity

`POST /shopper/orders/{order}/items/{item}/reduced-quantity-approval` `{"proposed_quantity":"4.000","note":"..."}`; `0 < proposed <` the quantity billed — the ordered quantity, or a cap already approved — at the unit's precision, else `422` on `proposed_quantity`; answers the order of section 28 (`DL-58`).

## 35. Complete Shopping

`POST /shopper/orders/{order}/complete` with `Idempotency-Key`, no body. The overdue questions are expired first (`DL-60` (1)). An order the caller holds but is not shopping — not `shopping`, or not started — is `409 shopping_not_active`; any other order is the scope-safe `404`. Every item terminal, no pending approval, else `409 shopping_incomplete` with `details.item_ids`, the lines still open. Computes totals; cash → `ready_for_delivery`; online → `final_payment_pending` (Wave 5). The Shopper's assignment ends `completed`, so the order leaves the Shopper's list, and the answer is the order of section 28 with that assignment, `customer_phone` `null`. An order with nothing bought never reaches it: the action that removed its last line cancelled it (`DL-54` (7)); one met here, like an online order before Wave 5, is `409 order_state_conflict` (`DL-61` (3)). A replay after completion answers the order through the Shopper's ended assignment while it is the order's latest (`DL-54` (3)).

# Courier

## 36. Assigned Deliveries

`GET /courier/orders`, `GET /courier/orders/{order}`: the Courier's current assignments only; any other order, a replaced Courier's included, is the scope-safe `404` (`DL-54` (3)). The list is paginated, the longest-waiting assignment first, and a row is the order itself: `{id, order_number, status, recipient{full_name, phone}|null, address{latitude, longitude, street, house, apartment, landmark}|null, delivery_note, delivery_time_note, payment_method, amount_to_collect_uzs, cancellation_request_pending, assignment{id, assigned_at, accepted_at, delivery_started_at, delay_at}, can_accept, can_start}` — `amount_to_collect_uzs` the final total for cash and `null` online, `cancellation_request_pending` a boolean (`DL-54` (12)), and `shopper_phone`, the phone of the Shopper who bought the order, only while the server runs without a handoff point (`BR-DEL-006`, configuration `delivery.handoff_point`, `DL-54` (11)), otherwise absent (`DL-63`).

## 37. Accept, Start, Delivered, Not Delivered

`POST /courier/orders/{order}/accept`, `POST .../start` (→ `on_the_way`), `POST .../delivered` with `Idempotency-Key`, `{"cash_received_uzs":251250}` required for cash and must equal the total (`409 cash_amount_mismatch`, `details.expected_uzs`), `POST .../not-delivered` `{"reason_code":"no_answer","note":"..."}`. Accept and start answer the order of section 36, and each again is a natural repeat. Start needs the assignment accepted and the order `delivery_assigned` (`409 delivery_state_conflict`); it sets `on_the_way` with `on_the_way_at`, and the assignment's `delivery_started_at` and `delay_at`, the threshold snapshot after it (`BR-DEL-002`). Start is refused with `delivery_state_conflict` and `details.reason` `cancellation_request_pending` while a cancellation request is pending (`DL-54` (12)). Delivered needs a delivery that set off (`409 delivery_state_conflict`): `cash_received_uzs` missing on a cash order is `422`, and one unequal to the final total `409 cash_amount_mismatch`; it records the cash payment `paid` by the Courier, completes the order with `completed_at` and the assignment, and writes one `payment_recorded` row with the move. Not delivered needs a delivery that set off too: `reason_code` one of `no_answer`, `refused`, `wrong_address`, `other`, and a `note` of up to 300 characters, required with `other`; the assignment ends `delivery_failed` with them, and the order returns to `ready_for_delivery`, keeping its first `ready_for_delivery_at` and clearing `on_the_way_at` (`DL-55` (13)), with one `delivery_failed` row whose `details` hold the reason. A replay of delivered, delivered again with a new key, and a repeat of not-delivered whatever its reason, answer the order through the Courier's ended assignment while it is the order's latest (`DL-54` (3), `DL-64` (3)); every answer of delivered and not-delivered — the first one included, since the action ended the assignment — tells the outcome only, with `recipient`, `address`, `delivery_note` and `delivery_time_note` `null` and no `shopper_phone` (`DL-64` (7)); the list, the order, accept and start carry them. Codes: `delivery_state_conflict`; an order not in the Courier's current assignments is the scope-safe `404`, so `courier_not_assigned` and `delivery_not_ready` are not answered, as `shopper_not_assigned` is not (`DL-63` (4)).

# Operations (Operator and Admin)

## 38. Board

`GET /operations/orders?status=&attention=&awaiting_customer=&shopper_id=&courier_id=&payment_method=&from=&to=&search=&page=&per_page=`, newest first (`created_at`, then the order number). A row: `{id, order_number, created_at, status, payment_method, customer{full_name, phone}, item_count, pending_approval_count, total_uzs, total_kind, shopper{id, full_name}|null, courier{id, full_name}|null, is_self_order}` — the Customer as the order's recipient snapshot, the totals of `DL-37` (10), the current Shopper or else the one who completed the shopping, the current Courier or else the one who delivered, and the order's self-order mark: a self-order assignment that is current or whose assignee started work, however it ended (`DL-54` (14)). `awaiting_customer` is `true` for the orders with a pending approval not past its expiry and `false` for the others, and any other value is `422`; `pending_approval_count` counts the same approvals (`DL-54` (8)). The mark can come from an assignment the row does not name — a Shopper whose shopping was cancelled, a Courier whose delivery failed — which the detail shows with its flag. `status`, `payment_method` and `attention` take their values only, `shopper_id` and `courier_id` UUIDs matched against the Shopper and the Courier the row names (`DL-54` (14)), `awaiting_customer` `true` or `false`, and `from` and `to` dates `YYYY-MM-DD` of `created_at` in `Asia/Tashkent` from 2000 to 2999, `to` not before `from`; anything else is `422 validation_failed`. `search` (at most 100 characters) matches the Customer's name folded as the catalog search folds it, the order number when the term is digits only, and the phone digits when it holds three digits or more (`DL-44` (4)); `courier_id` and `awaiting_customer` from Wave 3.

`GET /operations/orders/{order}` → `{id, order_number, status, payment_method, delivery_time_note, customer{id, full_name, phone}, address{latitude, longitude, street, house, apartment, landmark, delivery_note}, items[{id, product_id, name_uz, name_ru, unit_code, price_mode, quantity, customer_note, substitution_policy, status, market_price_uzs, customer_unit_price_uzs, markup_percent, line_total_uzs, removed_reason_code, purchased_quantity, billable_quantity, actual_market_price_uzs, billable_unit_price_uzs, replacement{product_id, name_uz, name_ru, substitution_resolution}|null}] (the replacement `null` for a removed line, `DL-57` (6)), totals{merchandise_subtotal_uzs, service_fee_uzs, delivery_fee_uzs, total_uzs, total_kind}, shopper_assignments[{id, shopper{id, full_name, phone}, assigned_by{id, full_name}, is_self_order, assigned_at, accepted_at, started_at, completed_at, ended_at, ended_reason}], courier_assignments, approvals, cancellation_requests, payment, refunds, history[{id, event_type, from_status, to_status, actor_type, actor{id, role, full_name}|null, reason_code, note, details, created_at}], cancellation_reason_code, timestamps{created_at, shopping_started_at, shopping_completed_at, ready_for_delivery_at, on_the_way_at, completed_at, cancelled_at}}`, lines, assignments and history oldest first. `approvals`, oldest first, are `{id, item_id, type, status, proposed_customer_unit_price_uzs, proposed_actual_market_price_uzs, proposed_quantity, replacement{product_id, name_uz, name_ru}|null, request_note, requested_by{id, full_name}, attention_at, expires_at, resolution, resolved_by{id, full_name}|null, resolved_at, created_at}` (`DL-58` (4)); `courier_assignments`, oldest first, are `{id, courier{id, full_name, phone}, assigned_by{id, full_name}, is_self_order, assigned_at, accepted_at, delivery_started_at, delay_at, completed_at, ended_at, ended_reason, failed_reason_code, failed_note}` (`DL-62` (4)); `payment` is `null` until one is made, then `{id, method, provider, status, amount_uzs, paid_at, recorded_by{id, full_name}|null}` (`DL-64` (4)); `refunds` are `[]` until Wave 5 (`DL-44` (5)).

`GET /operations/summary` → `{day, open_by_status{new, shopping_assigned, shopping, final_payment_pending, ready_for_delivery, delivery_assigned, on_the_way}, completed_today, cancelled_today, sales_today_uzs, attention_count}`: every open order by its current status whatever day it was placed, today's completed and cancelled orders by `completed_at` and `cancelled_at`, today's sales (the sum of `final_total_uzs` of orders completed today) and the attention count; the day is `Asia/Tashkent` (`DL-37` (16)).

`GET /operations/attention` → items `{type, order_id, order_number, since, shopper{id, full_name}|null, courier{id, full_name}|null}`, one per open order and type, the longest-waiting first, as one page of the collection envelope (`DL-44` (7), `DL-60` (3)). `approval_pending` is since the earliest question past its ten minutes and not expired; `approval_expired` since the earliest expiry still unresolved, a question past its expiry that nothing has written yet included; `courier_delayed` since the delivery's `delay_at`, naming the Courier; `delivery_failed` since the latest failure, naming its Courier; `self_order` since the earliest assignment that marks the order, naming the Shopper and the Courier whose assignments mark it; `staff_blocked` since the earliest block, naming the one blocked (`DL-62` (3)). The types are `approval_pending` (a pending approval past its ten minutes), `approval_expired`, `payment_overdue`, `refund_outstanding`, `courier_delayed`, `delivery_failed`, `cancellation_request`, `self_order` and `staff_blocked` (an open order whose current Shopper or Courier is blocked) (`DL-54` (13)); each arrives with the wave that creates its state — `self_order` in Wave 2, `payment_overdue` and `refund_outstanding` in Wave 5, the rest in Wave 3 — and the list's `attention` filter takes the types built so far.

## 39. Assignment

`POST /operations/orders/{order}/shopper-assignment` `{"shopper_id":"..."}` assigns an order that is `new`; `PUT` with `{"shopper_id":"...","replaces_assignment_id":"..."}` reassigns before shopping starts, replacing the named assignment — the entry of the order's `shopper_assignments` whose `ended_at` is null — only while it is the current one; any other id, unknown or another order's included, is `409 order_state_conflict`, and the client reloads the order; the current Shopper again is a natural repeat; an id that is not a Shopper is `422 validation_failed` (`DL-37` (14)); a blocked Shopper is `409 staff_not_active`, even when current. The Shopper is checked first, then the repeat, then the order's state; both answer `200` with the order as `GET /operations/orders/{order}` shows it, and the history row's `details` carry the assignment, the Shopper and `is_self_order`, and on a reassignment the previous assignment and Shopper (`DL-45`). `POST /operations/orders/{order}/courier-assignment` `{"courier_id":"..."}` assigns an order that is `ready_for_delivery`; `PUT` with `{"courier_id":"...","replaces_assignment_id":"..."}` reassigns before `on_the_way`, as for the Shopper (`DL-54` (10)). Codes: `order_state_conflict`, `staff_not_active`; `shopper_not_assigned` and `courier_not_assigned` are not answered (`DL-63` (4)). The pickers: `GET /operations/shoppers` answers the active Shoppers as `{id, full_name, phone, current_assignment_count}`, paginated and ordered by name, for Operator and Admin, because `/admin/staff` is Admin-only; `GET /operations/couriers` does the same for Couriers from Wave 3 (`DL-37` (11)).

## 40. Approvals and Cancellation Requests

`POST /operations/approvals/{approval}/resolve-expired` `{"resolution":"remove_item","note":"..."}` — `remove_item` is the only resolution (`BR-APP-007`); the approval is expired first when overdue, then its line removed with `approval_expired` and the order answered as `GET /operations/orders/{order}` shows it; the order is cancelled when nothing is left to buy. A question not yet expired is `409 approval_not_expired`, one the Customer or a cancellation resolved `409 approval_already_resolved`, an order no longer shopped or a line no longer waiting `409 order_state_conflict`; the same removal again is a natural repeat (`DL-60` (2)). `GET /operations/cancellation-requests`, `GET .../{request}`, `POST .../{request}/decision` `{"decision":"approve","note":"..."}`. The same decision on a decided request is a natural repeat; the other decision, or any decision on a `closed` request, is `409 cancellation_request_already_decided` (`DL-54` (12), (19)).

## 41. Operator Cancellation and Switch to Cash

`POST /operations/orders/{order}/cancel` `{"reason_code":"delivery_failed","note":"..."}` for an order back in `ready_for_delivery` after a failed delivery (Wave 3), and `{"reason_code":"unpaid_online"}` for an order in `final_payment_pending` (Wave 5). Any other state answers `409 order_state_conflict`; while a cancellation request is pending, `409 cancellation_already_pending`, and the Operator decides the request instead (`DL-54` (12)). A paid online payment creates a refund obligation.

`POST /operations/orders/{order}/switch-to-cash` `{"note":"..."}` *(Wave 5)* while `final_payment_pending` and unpaid → cancels the obligation, sets `ready_for_delivery`, writes `payment_method_switched`.

## 42. Refunds

`GET /operations/refunds`, `GET /operations/refunds/{refund}`; Admin only: `POST /admin/refunds/{refund}/complete` `{"provider_reference":"..."}`, `POST /admin/refunds/{refund}/fail` `{"note":"..."}`.

# Admin

## 43. Staff

`GET|POST /admin/staff` (the list takes `role`, `status`, `page`, `per_page`), `GET|PATCH /admin/staff/{user}`, `POST .../block`, `POST .../activate`, `POST .../reset-password`. Create body `{"full_name":"...","phone":"+998...","role":"shopper"}` with `full_name` 1–120 characters; create and reset return the temporary password once. Block and reset-password delete every token of the account (`DL-17`). PATCH accepts `full_name` only, never `role`. Codes: `self_block_not_allowed`, `last_active_admin_required`, `self_reset_not_allowed`, `phone_already_active`.

A staff account is `{"id":"...","role":"shopper","phone":"+998901112233","full_name":"Dilnoza Karimova","status":"active","must_change_password":true,"last_login_at":null,"blocked_at":null,"created_at":"...","updated_at":"..."}`. Create (`201`) and reset-password (`200`) answer `{"data":{"user":{...},"temporary_password":"7pQx9KmT3wZe"}}` with `Cache-Control: no-store`; every other endpoint answers the account. The role is any staff role, never `customer`; the phone is `+998` and nine digits. The list is newest first. A Customer's id is the scope-safe `404`. Blocking a blocked account and activating an active one are natural repeats (Section 49). An Admin cannot reset their own password here (`409 self_reset_not_allowed`); they use `POST /auth/change-password` (`DL-25`).

## 44. Business Settings

`GET|PATCH /admin/settings/business` — every field of `08` Section 11 except the id and the last editor, plus `updated_at`; unset values are `null`. Money is a JSON integer; percentages, coordinates and the radius are decimal strings; `opens_at` and `closes_at` are `HH:MM` in `Asia/Tashkent`. `PATCH` takes any non-empty subset (an empty body is `422` on `body`) and checks the merged row: the value of the service-fee mode not chosen must be `null`, working hours and the centre come in pairs, opening and closing differ; a refusal is `422 validation_failed` on the field that must change. `GET /admin/settings/payment-providers` answers the four rows `{provider, is_enabled, updated_at}` in the order payme, click, paynet, xazna, in the collection envelope of Section 2 as one page. `PATCH /admin/settings/payment-providers/{provider}` `{"is_enabled":true}` takes a strict boolean; `{provider}` is constrained to the four values, anything else is the scope-safe `404` (`DL-17`, `DL-19`).

## 45. Price Correction

`POST /admin/orders/{order}/items/{item}/price-correction` `{"actual_market_price_uzs":15000,"reason":"..."}` for a bought line billed from the price paid — an estimate original or a replacement — while the order is unpaid and the Courier has not set off; recomputes the line and, once shopping has completed, the final amounts (from Wave 5 an unpaid obligation too); an order `on_the_way`, completed or cancelled is `409 price_correction_locked`, a line not bought or billed at its fixed snapshot `409 price_correction_not_applicable`, a price whose customer price exceeds the bound of the product bought `409 price_correction_above_ceiling`; the current price again is a natural repeat (`DL-54` (18)).

# Providers *(Wave 5)*

## 46. Provider-Facing Endpoints

One route set per provider exactly as its official documentation requires; nothing invented. Common internal flow: validate → derive event key → deduplicate → normalize → apply under lock. A client redirect is never proof of payment.

# Manager *(later)*

## 47. Figures

`GET /manager/figures/summary`, `/top-products`, `/staff-activity` with `from`/`to`, definitions in `05` Section 20.

# Idempotency and Concurrency

## 48. Required `Idempotency-Key`

Create order, customer approval decision, cancel order, record purchase, complete shopping, initiate payment attempt, courier delivered, reorder. Scope `(actor, operation, key)` plus a request hash over the operation, the route parameters and the body, so one key used on two orders is `idempotency_key_reused` (`DL-37` (5)). Same key and hash → same result; same key inside the processing lease → `409 idempotency_in_progress`; different hash → `409 idempotency_key_reused`; missing → `400 idempotency_key_required`; a key that is not a UUID → `422 validation_failed` on `Idempotency-Key`. A replay answers the resource as it is now, with the status of the original success (`DL-39`).

## 49. Natural Repeats

Accept an accepted assignment, start a started one, deliver a completed one from the same assignment, block a blocked account, activate an active account, an order edit that changes nothing, assign the current Shopper again, cancel a cancelled order, the same decision on a decided cancellation request, the same automatic replacement again, a price correction to the current price: current resource, no duplicate history. A replay of completion or delivered, and a repeat of not-delivered, reach the order through the caller's assignment the action ended, while it is the order's latest of its kind (`DL-54` (3)).

## 50. Concurrency

The backend decides from locked state; a stale client receives a `409` with a stable code and refreshes.

# Error Codes

## 51. Common

`validation_failed`, `malformed_request`, `authentication_required`, `forbidden`, `resource_not_found`, `business_conflict`, `payload_too_large`, `rate_limited`, `provider_unavailable`, `service_unavailable`, `idempotency_key_required`, `idempotency_key_reused`, `idempotency_in_progress`, `server_error`.

## 52. Auth

`invalid_credentials`, `account_blocked`, `password_change_required`, `code_invalid`, `code_expired`, `code_attempts_exhausted`, `code_resend_too_soon`.

## 53. Catalog, Cart, Checkout, Editing

`product_unavailable`, `product_archived`, `cart_item_already_exists`, `cart_full`, `cart_empty`, `customer_profile_incomplete`, `address_incomplete`, `address_outside_service_area`, `minimum_order_not_reached`, `checkout_snapshot_stale`, `checkout_configuration_incomplete`, `payment_method_unavailable`, `order_editing_locked`.

## 54. Order, Shopping, Approval

`order_state_conflict`, `order_cancellation_not_allowed`, `cancellation_already_pending`, `staff_not_active`, `shopper_not_assigned` (not answered, `DL-63` (4)), `shopping_not_active`, `item_already_resolved`, `replacement_unit_mismatch`, `substitution_not_allowed`, `customer_approval_required`, `approval_not_needed`, `shopping_incomplete`, `approval_not_pending`, `approval_not_expired`, `approval_expired`, `approval_already_resolved`, `cancellation_request_already_decided`.

## 55. Payment and Refund

`payment_method_not_online`, `payment_not_payable`, `payment_already_paid`, `payment_outcome_pending`, `payment_provider_disabled`, `payment_provider_unavailable`, `payment_outcome_unknown`, `cash_amount_mismatch`, `refund_not_allowed`, `refund_already_completed`.

## 56. Delivery and Admin

`courier_not_assigned` and `delivery_not_ready` (not answered, `DL-63` (4)), `delivery_state_conflict`, `last_active_admin_required`, `self_block_not_allowed`, `self_reset_not_allowed`, `phone_already_active`, `price_correction_locked`, `price_correction_not_applicable`, `price_correction_above_ceiling`.

## 57. Provider Safety

Never expose raw provider errors, signatures, secrets, SQL, traces or card data. Normalize to the codes above; filter secrets from logs.
