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

HTTP baseline: `200/201/204` success; `400 malformed_request`; `401` unauthenticated or blocked; `403 forbidden`; `404 resource_not_found` (scope-safe); `409` lifecycle, business, idempotency or concurrency conflict; `422 validation_failed`; `429 rate_limited` with `Retry-After`; `502/503 provider_unavailable` for an external provider; `503 service_unavailable` for planned maintenance, with `Retry-After`; `500 server_error`. Any other client status folds to the scope-safe `404`; any other server status keeps its number with `server_error`. No response ever carries exception text, SQL, paths, class names, secrets or raw provider errors.

## 4. Strict Request Shape

Mutation endpoints reject unknown fields with `validation_failed`. Clients never send roles, statuses, billable quantities, totals, prices (other than the Shopper's actual market price) or payment states.

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

`GET /customer/profile`, `PATCH /customer/profile` `{"full_name":"...","preferred_language":"uz"}`.

## 13. Addresses

`GET|POST /customer/addresses`, `GET|PATCH|DELETE /customer/addresses/{address}`. Body: `latitude`, `longitude` (decimal strings), `street`, `house`, optional `label`, `apartment`, `landmark`, `delivery_note`. A point outside the service area answers `422 address_outside_service_area` with `details.max_distance_km` and `details.distance_km`; while the service area is not configured, create and update answer `409 checkout_configuration_incomplete`. Delete always deactivates (`DL-17`); the list returns active addresses only.

# Catalog

## 14. Customer Catalog

`GET /catalog/categories`, `GET /catalog/products?category_id=&search=&page=&per_page=`, `GET /catalog/products/{product}`. A Customer session is required (`DL-17`); an archived or inactive product, or one in an inactive category, is a scope-safe `404`.

Product:

```json
{"id":"...","category_id":"...","name_uz":"Pomidor","name_ru":"Помидор","description_uz":null,"description_ru":null,
 "unit_code":"kg","price_mode":"estimate","customer_unit_price_uzs":18400,"image_url":"https://.../storage/products/<uuid>.webp","is_active":true}
```

Search matches `name_uz` and `name_ru` case-insensitively.

## 15. Admin Catalog

`GET|POST /admin/categories`, `GET|PATCH /admin/categories/{category}`, `POST .../archive`, `POST .../restore`; the same for `/admin/products`. Lists are paginated, ordered by `sort_order` then `name_uz`, and take `include_archived`; the product list also takes `category_id` and `search`. Product write body: `category_id, name_uz, name_ru, description_uz?, description_ru?, unit_code, price_mode, market_price_uzs, sort_order, is_active`. Archive sets `archived_at` and `is_active = false`; restore clears `archived_at` and sets `is_active = true`; both are natural repeats; `is_active` alone hides an entry without archiving it, and `is_active: true` on an archived entry answers `409 business_conflict`. A product is created in, or moved to, an unarchived category only (`422 validation_failed` on `category_id`); archiving a category leaves its products as they are. Admin responses also carry `market_price_uzs`, the computed `customer_unit_price_uzs` and `archived_at`.

## 16. Product Image

`POST /admin/products/{product}/image` (multipart, JPEG/PNG/WebP, ≤ 5 MB) replaces the current image; `DELETE` removes it.

# Cart and Checkout

## 17. Cart

`GET /customer/cart`, `POST /customer/cart/items` `{"product_id":"...","quantity":"5.000","customer_note":"...","substitution_policy":"allow_similar_substitution"}`, `PATCH /customer/cart/items/{item}`, `DELETE /customer/cart/items/{item}`. Duplicate product → `409 cart_item_already_exists`. Unit precision validated. The cart response carries current customer prices and an `estimated_subtotal_uzs`.

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

`total_kind` ∈ `final, estimate`. Codes: `customer_profile_incomplete`, `address_incomplete`, `address_outside_service_area`, `cart_empty`, `product_unavailable` (`details.product_ids`), `minimum_order_not_reached` (`details.minimum_order_uzs`, `details.shortfall_uzs`), `checkout_configuration_incomplete`, `payment_method_unavailable`.

## 19. Create Order

`POST /customer/orders` with `Idempotency-Key: <UUID>`, body `{"checkout_token":"..."}`. Revalidates, snapshots, converts the cart, creates the new cart, assigns `order_number`, answers `201` with the order. Stale token → `409 checkout_snapshot_stale`.

# Customer Orders

## 20. Orders

`GET /customer/orders`, `GET /customer/orders/{order}`. Own orders only. The order resource:

```json
{"id":"...","order_number":1042,"status":"shopping","payment_method":"cash",
 "pending_approval_count":1,"can_edit":false,"can_cancel_directly":false,"can_request_cancellation":true,
 "items":[...],"totals":{"merchandise_subtotal_uzs":null,"service_fee_uzs":null,"delivery_fee_uzs":15000,"total_uzs":null,"total_kind":"estimate"},
 "address":{...},"delivery_time_note":"...","payment":null,"refunds":[],"timestamps":{...}}
```

## 21. Edit Order

`PUT /customer/orders/{order}/items` `{"items":[{"product_id":"...","quantity":"2","customer_note":null,"substitution_policy":"contact_before_substitution"}],"delivery_time_note":"..."}` → the order. Allowed while `new` or `shopping_assigned` and shopping has not started; otherwise `409 order_editing_locked`. Codes as in Section 18 for products and the minimum amount.

## 22. Cancel or Request Cancellation

`POST /customer/orders/{order}/cancel` with `Idempotency-Key`, `{"reason":"..."}`. While `new` or `shopping_assigned`: cancels at once. From `shopping` through `delivery_assigned`: creates a pending request (`409 cancellation_already_pending` if one exists). From `on_the_way`: `409 order_cancellation_not_allowed`.

## 23. Approvals

`GET /customer/approvals?status=pending`, `GET /customer/approvals/{approval}`, `POST /customer/approvals/{approval}/decision` with `Idempotency-Key`, `{"decision":"approve"}` or `"reject"`. Only own pending approvals; `409 approval_expired`, `409 approval_already_resolved`.

Approval resource: `type`, `status`, the item with both names, `proposed_customer_unit_price_uzs`, `proposed_quantity`, `replacement` (product with both names and its customer price), `request_note`, `expires_at`.

## 24. Payment *(online, Wave 5)*

`GET /customer/orders/{order}/payment` → the obligation with its attempts. `POST /customer/orders/{order}/payment/attempts` with `Idempotency-Key`, `{"provider":"payme"}` → the attempt and a provider-action union the client follows. Codes: `payment_method_not_online`, `payment_not_payable`, `payment_already_paid`, `payment_outcome_pending`, `payment_provider_disabled`, `payment_provider_unavailable`.

## 25. Refunds

`GET /customer/orders/{order}/refunds` → own refund records with status.

## 26. Reorder

`POST /customer/orders/{order}/reorder` with `Idempotency-Key` → `{"added_items":[...],"skipped_existing_items":[...],"unavailable_items":[...]}`. Never creates an order.

## 27. Push Devices

`POST /push-devices` `{"platform":"android","token":"..."}` (bound to the calling account), `DELETE /push-devices/{device}`.

# Shopper

## 28. Assigned Orders

`GET /shopper/orders`, `GET /shopper/orders/{order}`. Current assignments only. While the order is `shopping` the resource carries `customer_phone`; it never carries the address.

## 29. Accept and Start

`POST /shopper/orders/{order}/accept`, `POST /shopper/orders/{order}/start`. Natural no-op repeats. Start requires acceptance.

## 30. Record Purchase

`POST /shopper/orders/{order}/items/{item}/purchase` with `Idempotency-Key`

```json
{"purchased_quantity":"5.200","actual_market_price_uzs":16000,"fulfilled_product_id":"..."}
```

`actual_market_price_uzs` is required for estimate items and replacements, optional for fixed originals. The server computes the billable unit price. Above the ceiling → `409 customer_approval_required` with `details.ceiling_customer_unit_price_uzs` and `details.proposed_customer_unit_price_uzs`. Codes: `shopping_not_active`, `item_already_resolved`, `replacement_unit_mismatch`.

## 31. Unavailable

`POST /shopper/orders/{order}/items/{item}/unavailable` `{"note":"..."}` → the item removed with `unavailable`.

## 32. Price Approval

`POST /shopper/orders/{order}/items/{item}/price-approval` `{"actual_market_price_uzs":22000,"note":"..."}` → a `price_over_tolerance` approval carrying the computed proposed customer price. Only when the price exceeds the current ceiling.

## 33. Substitution

`POST /shopper/orders/{order}/items/{item}/substitution` `{"replacement_product_id":"...","actual_market_price_uzs":11000,"note":"..."}` → either the item authorized for the replacement (`substitution_resolution: automatic`) or a `substitution` approval, according to the item's policy and ceiling.

## 34. Reduced Quantity

`POST /shopper/orders/{order}/items/{item}/reduced-quantity-approval` `{"proposed_quantity":"4.000","note":"..."}`; `0 < proposed < ordered`, unit precision.

## 35. Complete Shopping

`POST /shopper/orders/{order}/complete` with `Idempotency-Key`. Every item terminal, no pending approval, else `409 shopping_incomplete`. Computes totals; cash → `ready_for_delivery`; online → `final_payment_pending`; nothing purchased → `cancelled`.

# Courier

## 36. Assigned Deliveries

`GET /courier/orders`, `GET /courier/orders/{order}`: order number, recipient name and phone, address, delivery note, delivery time note, payment method, `amount_to_collect_uzs` for cash, status, and `shopper_phone` only while the server runs without a handoff point (`BR-DEL-006`), otherwise absent.

## 37. Accept, Start, Delivered, Not Delivered

`POST /courier/orders/{order}/accept`, `POST .../start` (→ `on_the_way`), `POST .../delivered` with `Idempotency-Key`, `{"cash_received_uzs":251250}` required for cash and must equal the total (`409 cash_amount_mismatch`, `details.expected_uzs`), `POST .../not-delivered` `{"reason_code":"no_answer","note":"..."}`. Codes: `courier_not_assigned`, `delivery_not_ready`, `delivery_state_conflict`.

# Operations (Operator and Admin)

## 38. Board

`GET /operations/orders?status=&attention=&shopper_id=&courier_id=&payment_method=&from=&to=&search=&page=`, `GET /operations/orders/{order}` (full projection with history, assignments, approvals, payment, refunds, `is_self_order`). `GET /operations/summary` → today's counts by status, today's sales, attention count. `GET /operations/attention` → items typed `approval_pending`, `approval_expired`, `customer_no_response`, `payment_overdue`, `refund_outstanding`, `courier_delayed`, `delivery_failed`, `cancellation_request`, `self_order`.

## 39. Assignment

`POST|PUT /operations/orders/{order}/shopper-assignment` `{"shopper_id":"..."}` (order `new`; reassignment before start). `POST|PUT /operations/orders/{order}/courier-assignment` `{"courier_id":"..."}` (order `ready_for_delivery`; reassignment before `on_the_way`). Codes: `order_state_conflict`, `staff_not_active`, `shopper_not_assigned`, `courier_not_assigned`.

## 40. Approvals and Cancellation Requests

`POST /operations/approvals/{approval}/resolve-expired` `{"resolution":"remove_item","note":"..."}`. `GET /operations/cancellation-requests`, `GET .../{request}`, `POST .../{request}/decision` `{"decision":"approve","note":"..."}`.

## 41. Operator Cancellation and Switch to Cash

`POST /operations/orders/{order}/cancel` `{"reason_code":"delivery_failed","note":"..."}` for an order back in `ready_for_delivery` after a failed delivery (Wave 3), and `{"reason_code":"unpaid_online"}` for an order in `final_payment_pending` (Wave 5). Any other state answers `409 order_state_conflict`. A paid online payment creates a refund obligation.

`POST /operations/orders/{order}/switch-to-cash` `{"note":"..."}` *(Wave 5)* while `final_payment_pending` and unpaid → cancels the obligation, sets `ready_for_delivery`, writes `payment_method_switched`.

## 42. Refunds

`GET /operations/refunds`, `GET /operations/refunds/{refund}`; Admin only: `POST /admin/refunds/{refund}/complete` `{"provider_reference":"..."}`, `POST /admin/refunds/{refund}/fail` `{"note":"..."}`.

# Admin

## 43. Staff

`GET|POST /admin/staff` (the list takes `role`, `status`, `page`, `per_page`), `GET|PATCH /admin/staff/{user}`, `POST .../block`, `POST .../activate`, `POST .../reset-password`. Create body `{"full_name":"...","phone":"+998...","role":"shopper"}` with `full_name` 1–120 characters; create and reset return the temporary password once. Block and reset-password delete every token of the account (`DL-17`). PATCH accepts `full_name` only, never `role`. Codes: `self_block_not_allowed`, `last_active_admin_required`, `phone_already_active`.

## 44. Business Settings

`GET|PATCH /admin/settings/business` — every field of `08` Section 11 except the id and the last editor, plus `updated_at`; unset values are `null`. Money is a JSON integer; percentages, coordinates and the radius are decimal strings; `opens_at` and `closes_at` are `HH:MM` in `Asia/Tashkent`. `PATCH` takes any non-empty subset (an empty body is `422` on `body`) and checks the merged row: the value of the service-fee mode not chosen must be `null`, working hours and the centre come in pairs, opening and closing differ; a refusal is `422 validation_failed` on the field that must change. `GET /admin/settings/payment-providers` answers the four rows `{provider, is_enabled, updated_at}` in the order payme, click, paynet, xazna, in the collection envelope of Section 2 as one page. `PATCH /admin/settings/payment-providers/{provider}` `{"is_enabled":true}` takes a strict boolean; `{provider}` is constrained to the four values, anything else is the scope-safe `404` (`DL-17`, `DL-19`).

## 45. Price Correction

`POST /admin/orders/{order}/items/{item}/price-correction` `{"actual_market_price_uzs":15000,"reason":"..."}` for a purchased estimate item while the order is unpaid; recomputes totals and an unpaid obligation; otherwise `409 price_correction_locked`.

# Providers *(Wave 5)*

## 46. Provider-Facing Endpoints

One route set per provider exactly as its official documentation requires; nothing invented. Common internal flow: validate → derive event key → deduplicate → normalize → apply under lock. A client redirect is never proof of payment.

# Manager *(later)*

## 47. Figures

`GET /manager/figures/summary`, `/top-products`, `/staff-activity` with `from`/`to`, definitions in `05` Section 20.

# Idempotency and Concurrency

## 48. Required `Idempotency-Key`

Create order, customer approval decision, cancel order, record purchase, complete shopping, initiate payment attempt, courier delivered, reorder. Scope `(actor, operation, key)` plus request hash. Same key and hash → same result; same key inside the processing lease → `409 idempotency_in_progress`; different hash → `409 idempotency_key_reused`; missing → `400 idempotency_key_required`.

## 49. Natural Repeats

Accept an accepted assignment, start a started one, deliver a completed one from the same assignment, block a blocked account, activate an active account: current resource, no duplicate history.

## 50. Concurrency

The backend decides from locked state; a stale client receives a `409` with a stable code and refreshes.

# Error Codes

## 51. Common

`validation_failed`, `malformed_request`, `authentication_required`, `forbidden`, `resource_not_found`, `business_conflict`, `rate_limited`, `provider_unavailable`, `service_unavailable`, `idempotency_key_required`, `idempotency_key_reused`, `idempotency_in_progress`, `server_error`.

## 52. Auth

`invalid_credentials`, `account_blocked`, `password_change_required`, `code_invalid`, `code_expired`, `code_attempts_exhausted`, `code_resend_too_soon`.

## 53. Catalog, Cart, Checkout, Editing

`product_unavailable`, `product_archived`, `cart_item_already_exists`, `cart_empty`, `customer_profile_incomplete`, `address_incomplete`, `address_outside_service_area`, `minimum_order_not_reached`, `checkout_snapshot_stale`, `checkout_configuration_incomplete`, `payment_method_unavailable`, `order_editing_locked`.

## 54. Order, Shopping, Approval

`order_state_conflict`, `order_cancellation_not_allowed`, `cancellation_already_pending`, `staff_not_active`, `shopper_not_assigned`, `shopping_not_active`, `item_already_resolved`, `replacement_unit_mismatch`, `customer_approval_required`, `shopping_incomplete`, `approval_not_pending`, `approval_expired`, `approval_already_resolved`.

## 55. Payment and Refund

`payment_method_not_online`, `payment_not_payable`, `payment_already_paid`, `payment_outcome_pending`, `payment_provider_disabled`, `payment_provider_unavailable`, `payment_outcome_unknown`, `cash_amount_mismatch`, `refund_not_allowed`, `refund_already_completed`.

## 56. Delivery and Admin

`courier_not_assigned`, `delivery_not_ready`, `delivery_state_conflict`, `last_active_admin_required`, `self_block_not_allowed`, `phone_already_active`, `price_correction_locked`.

## 57. Provider Safety

Never expose raw provider errors, signatures, secrets, SQL, traces or card data. Normalize to the codes above; filter secrets from logs.
