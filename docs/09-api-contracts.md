# BarakaBozor — API Contracts

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## 1. General Contract

Base `/api/v1`. Production uses HTTPS/JSON. Protected Flutter requests use Laravel Sanctum Bearer token.

Domain IDs are UUID strings. Money is JSON integer UZS. Quantity/percentage decimal values are JSON strings. Authoritative timestamps are ISO-8601 UTC.

## 2. Success Envelope

Single/mutation resource:

```json
{"data": {}}
```

Collection:

```json
{"data": [], "meta": {"pagination": {"page":1,"per_page":20,"total":0,"last_page":1}}}
```

No useful body → `204 No Content`.

## 3. Error Envelope

```json
{
  "message":"Human-readable message.",
  "code":"stable_machine_code",
  "errors":{},
  "request_id":"req_..."
}
```

Flutter branches on `code`, not message text.

HTTP baseline: 200/201/204 success, 400 malformed protocol, 401 unauthenticated, 403 capability denial, 404 scope-safe not found, 409 lifecycle/business/idempotency/concurrency conflict, 422 validation, 429 rate limit, 502/503 external provider problem, 500 unexpected server failure.

## 4. Strict Request Shape

Mutation endpoints reject unknown/protected fields. Clients never submit authoritative role/status/billable quantity/final total/Payment status unless exact endpoint explicitly allows field.

## 5. Pagination

Default `page=1`, `per_page=20`, maximum 100. Server-side.

# Authentication

## 6. Request Customer OTP

```text
POST /api/v1/auth/customer/otp/request
```

```json
{"phone":"+998901234567"}
```

MVP phone: Uzbekistan mobile E.164 `+998` + 9 digits.

OTP policy: 6 digits, 5-minute lifetime, max 5 failed verify attempts, 60-second resend interval, max 5 sends/phone/hour.

Response does not disclose account existence:

```json
{"data":{"expires_in_seconds":300,"resend_available_in_seconds":60}}
```

Codes: `otp_resend_too_soon`, `rate_limited`, `validation_failed`.

## 7. Verify Customer OTP

```text
POST /api/v1/auth/customer/otp/verify
```

```json
{"phone":"+998901234567","code":"482913"}
```

Success creates Customer if absent, ensures active Cart, issues token. Codes: `otp_invalid`, `otp_expired`, `otp_attempts_exhausted`.

## 8. Staff Login

```text
POST /api/v1/auth/staff/login
```

```json
{"phone":"+998901234567","password":"..."}
```

Customer account is not accepted. Success returns token + authoritative role/status/gate. Codes `invalid_credentials`, `account_blocked`.

## 9. Current Identity

```text
GET /api/v1/auth/me
```

Returns `id, role, phone, full_name, status, must_change_password`.

## 10. Change Staff Password

```text
POST /api/v1/auth/change-password
```

```json
{"current_password":"...","new_password":"...","new_password_confirmation":"..."}
```

Password 10–128 chars. Generated temporary password at least 12 random chars. First successful change clears `must_change_password`; endpoint also supports later Staff self-change.

## 11. Logout

`POST /api/v1/auth/logout` → revoke current token → 204.

While password-change gate true, only `/auth/me`, `/auth/change-password`, `/auth/logout` allowed.

# Customer Profile / Address

## 12. Profile

```text
GET   /api/v1/customer/profile
PATCH /api/v1/customer/profile
```

Editable request `{"full_name":"..."}`. Phone not ordinary profile edit.

## 13. Addresses

```text
GET    /api/v1/customer/addresses
POST   /api/v1/customer/addresses
GET    /api/v1/customer/addresses/{address}
PATCH  /api/v1/customer/addresses/{address}
DELETE /api/v1/customer/addresses/{address}
```

Create/update uses decimal-string coordinates plus required street/house and optional label/apartment/landmark/note. Delete safely deactivates if historical.

# Catalog

## 14. Customer Catalog

```text
GET /api/v1/catalog/categories
GET /api/v1/catalog/products
GET /api/v1/catalog/products/{product}
```

Filters: category_id, search, pagination. Pricing is discriminated union `fixed|range|at_purchase`.

## 15. Admin Catalog

```text
GET/POST  /api/v1/admin/categories
GET/PATCH /api/v1/admin/categories/{category}
POST      /api/v1/admin/categories/{category}/archive
POST      /api/v1/admin/categories/{category}/restore
GET/POST  /api/v1/admin/products
GET/PATCH /api/v1/admin/products/{product}
POST      /api/v1/admin/products/{product}/archive
POST      /api/v1/admin/products/{product}/restore
```

Pricing request cross-fields must exactly match selected mode.

## 16. Product Image

```text
POST   /api/v1/admin/products/{product}/image
DELETE /api/v1/admin/products/{product}/image
```

multipart/form-data; JPEG/PNG/WebP; max 5 MB; one current image.

# Cart / Checkout

## 17. Cart

```text
GET    /api/v1/customer/cart
POST   /api/v1/customer/cart/items
PATCH  /api/v1/customer/cart/items/{item}
DELETE /api/v1/customer/cart/items/{item}
```

Add request:

```json
{"product_id":"...","quantity":"5.000","customer_note":"...","substitution_policy":"contact_before_substitution"}
```

Duplicate Product → `409 cart_item_already_exists`. Unit-specific quantity validation applies.

## 18. Checkout Preview

```text
POST /api/v1/customer/checkout/preview
```

```json
{"address_id":"...","payment_provider":"click"}
```

Prerequisites: non-empty Customer name, own active complete Address, non-empty Cart, active Products, valid quantities, configured fees, provider enabled for new checkout.

Response pricing summary kinds:

### all fixed

```json
{"kind":"final","final_total_uzs":225000,"has_unknown_prices":false}
```

### fixed + range, no at_purchase

```json
{"kind":"estimate_range","estimated_min_total_uzs":220000,"estimated_max_total_uzs":260000,"has_unknown_prices":false}
```

### contains at_purchase

```json
{"kind":"contains_unknown","final_total_uzs":null,"estimated_min_total_uzs":null,"estimated_max_total_uzs":null,"has_unknown_prices":true}
```

Response also includes known fee/components where meaningful plus signed `checkout_token` and expiry. For percentage Service fee with unknown merchandise total, final Service fee is not presented as known.

Checkout token lifetime 5 minutes and bound to Customer/Cart/Address/Product/pricing/fees/provider state.

## 19. Create Order

```text
POST /api/v1/customer/orders
Idempotency-Key: <UUID>
```

Body `{"checkout_token":"..."}` only.

Backend revalidates, creates snapshots, creates prepaid/deferred Order, creates checkout Payment for prepaid, converts source Cart, creates new active Cart in one transaction.

```text
prepaid  → checkout_payment_pending
deferred → new
```

Stale token → `409 checkout_snapshot_stale`.

# Orders / Shopper

## 20. Customer Orders

```text
GET /api/v1/customer/orders
GET /api/v1/customer/orders/{order}
```

Own Orders only. Customer-safe projection includes snapshots, Items, totals, Payment/refund/delivery presentation, and backend-computed action guidance.

Machine states are canonical ten states from Business Rules. Customer presentation may map both payment states to `payment_pending`.

## 21. Admin Shopper Assignment

```text
POST /api/v1/admin/orders/{order}/shopper-assignment
PUT  /api/v1/admin/orders/{order}/shopper-assignment
```

Body `{"shopper_id":"..."}`. Only active Shopper; reassignment only before Shopping start.

## 22. Shopper Orders

```text
GET /api/v1/shopper/orders
GET /api/v1/shopper/orders/{order}
```

Current assigned scope only.

## 23. Shopper Accept / Start

```text
POST /api/v1/shopper/orders/{order}/accept
POST /api/v1/shopper/orders/{order}/start
```

Natural idempotent for same current assignment. Start requires acceptance.

## 24. Record Purchased Item

```text
POST /api/v1/shopper/orders/{order}/items/{item}/purchase
Idempotency-Key: <UUID>
```

Ordinary fixed original Item:

```json
{"purchased_quantity":"5.200","fulfilled_product_id":"..."}
```

Dynamic/replacement context additionally requires `purchase_unit_price_uzs`.

Client never sends billable quantity/price/line total. Range actual above approved ceiling without Approval → `customer_approval_required`.

## 25. Mark Unavailable

`POST /api/v1/shopper/orders/{order}/items/{item}/unavailable` and backend follows snapshotted policy.

## 26. Price Approval

```text
POST /api/v1/shopper/orders/{order}/items/{item}/price-approval
```

`{"proposed_unit_price_uzs":13500,"note":"..."}`. Valid when range price exceeds current approved ceiling.

## 27. Substitution

```text
POST /api/v1/shopper/orders/{order}/items/{item}/substitution
```

`{"replacement_product_id":"...","proposed_unit_price_uzs":11000,"note":"..."}`. Backend returns automatic authorized substitution context or creates Approval based on policy/ceiling.

## 28. Reduced Quantity Approval

```text
POST /api/v1/shopper/orders/{order}/items/{item}/reduced-quantity-approval
```

`{"proposed_quantity":"4.000","note":"..."}`; must satisfy unit precision and `0 < proposed < ordered`.

## 29. Complete Shopping

```text
POST /api/v1/shopper/orders/{order}/complete
Idempotency-Key: <UUID>
```

Backend locks, requires every Item terminal/no pending Approval, calculates authoritative rounded totals, and produces final/additional Payment/refund/ready outcome.

# Customer Approval

## 30. Approvals

```text
GET /api/v1/customer/approvals?status=pending
GET /api/v1/customer/approvals/{approval}
```

Own Orders only.

## 31. Decision

```text
POST /api/v1/customer/approvals/{approval}/decision
Idempotency-Key: <UUID>
```

`{"decision":"approve"}` or reject. Customer cannot alter persisted proposal. Reject removes Item. Only pending/non-expired own Approval may be decided.

## 32. Resolve Expired

```text
POST /api/v1/operations/approvals/{approval}/resolve-expired
```

Operator/Admin only. MVP accepts only `{"resolution":"remove_item","note":"..."}`.

# Payment / Refund

## 33. Customer Payments

```text
GET /api/v1/customer/orders/{order}/payments
GET /api/v1/customer/payments/{payment}
```

Own obligations/Attempts only.

## 34. Initiate Payment Attempt

```text
POST /api/v1/customer/payments/{payment}/attempts
Idempotency-Key: <UUID>
```

No amount/provider override. Obligation owns amount/provider. Response includes Attempt, provider, amount, status, and provider-action discriminated union. Exact provider action variants/fields are finalized from official merchant protocol in Stage 7.

Existing pending outcome → `payment_outcome_pending`.

## 35. Provider-Facing Endpoints

No invented universal webhook. Each Payme/Paynet/xazna/Click adapter follows official merchant docs for route/method/auth/signature/payload/response.

Common internal flow:

```text
validate provider request
→ derive provider event key
→ deduplicate
→ normalize outcome
→ lock/apply Payment/Attempt/Order
```

Client redirect is never Payment proof.

## 36. Refund Visibility

```text
GET /api/v1/customer/orders/{order}/refunds
GET /api/v1/operations/refunds
GET /api/v1/operations/refunds/{refund}
```

## 37. Retry Refund

```text
POST /api/v1/admin/refunds/{refund}/retry
Idempotency-Key: <UUID>
```

Only when provider/business state permits; amount server-owned.

# Cancellation

## 38. Customer Cancel

```text
POST /api/v1/customer/orders/{order}/cancel
Idempotency-Key: <UUID>
```

`{"reason":"..."}`. Before Shopping → immediate cancel/refund if needed. After Shopping before `on_the_way` → pending cancellation request. `on_the_way`/later → `order_cancellation_not_allowed`.

## 39. Operational Cancellation Requests

```text
GET /api/v1/operations/cancellation-requests
GET /api/v1/operations/cancellation-requests/{request}
POST /api/v1/operations/cancellation-requests/{request}/decision
```

Operator/Admin. Decision approve/reject; Refund amount never manually supplied.

# Courier

## 40. Admin Courier Assignment

```text
POST /api/v1/admin/orders/{order}/courier-assignment
PUT  /api/v1/admin/orders/{order}/courier-assignment
```

Only active Courier; Order ready; reassignment only before `on_the_way`.

## 41. Courier Orders

```text
GET /api/v1/courier/orders
GET /api/v1/courier/orders/{order}
```

Current assignment only; delivery PII projection only.

## 42. Courier Accept / Start / Delivered

```text
POST /api/v1/courier/orders/{order}/accept
POST /api/v1/courier/orders/{order}/start
POST /api/v1/courier/orders/{order}/delivered
```

Accept before start. Start → `on_the_way`; delivered → `completed`. Same-current-assignment safe repeat returns current state without duplicate history.

# Operations / Admin

## 43. Operations Order Board

```text
GET /api/v1/operations/orders
GET /api/v1/operations/orders/{order}
```

Operator/Admin filters: status, attention, Shopper, Courier, Payment state, dates, search, pagination. Attention includes approval pending/expired, Customer no-response, Payment failed/overdue/unknown, Refund failed/unknown, Courier delayed, cancellation request. No generic Order-status mutation endpoint.

## 44. Staff Management

```text
GET  /api/v1/admin/staff
POST /api/v1/admin/staff
GET  /api/v1/admin/staff/{user}
PATCH /api/v1/admin/staff/{user}
POST /api/v1/admin/staff/{user}/block
POST /api/v1/admin/staff/{user}/activate
POST /api/v1/admin/staff/{user}/reset-password
```

Create body `{"full_name":"...","phone":"+998...","role":"shopper"}`. Allowed Staff roles only. Create/reset returns generated temporary password once and sets gate. PATCH does not accept role. Admin cannot block self/last active Admin. Admin resets another Staff; self uses auth change-password.

## 45. Business Settings

```text
GET   /api/v1/admin/settings/business
PATCH /api/v1/admin/settings/business
```

Fields: Service fee mode/fixed/percentage, Delivery fee, delay threshold. Current settings never rewrite Order snapshots.

## 46. Payment Provider Enablement

```text
GET   /api/v1/admin/settings/payment-providers
PATCH /api/v1/admin/settings/payment-providers/{provider}
```

Body `{"is_enabled":true}`. Flag controls new checkout selection. Secrets never returned. Existing Order/Payment retains selected provider; disable does not silently substitute provider.

## 47. Dynamic Price Correction

```text
POST /api/v1/admin/orders/{order}/items/{item}/price-correction
```

New dynamic purchase price + reason. Admin only, audited, before relevant final Payment lock; otherwise `price_correction_locked`.

# History / Push / Analytics

## 48. Reorder

```text
POST /api/v1/customer/orders/{order}/reorder
Idempotency-Key: <UUID>
```

Uses original ordered Product and current Catalog, adds absent eligible Items to active Cart, returns `added_items`, `skipped_existing_items`, `unavailable_items`. Does not create Order.

## 49. Push Devices

```text
POST   /api/v1/push-devices
DELETE /api/v1/push-devices/{device}
```

Body platform `android|ios`, token. Bound to authenticated user.

## 50. Manager Analytics

```text
GET /api/v1/manager/analytics/summary
GET /api/v1/manager/analytics/top-products
GET /api/v1/manager/analytics/staff-activity
```

Filters from/to. Definitions:

- Orders created: created_at in period;
- Completed: completed_at in period;
- Cancelled: cancelled_at in period;
- gross sales: sum final_total_uzs Completed Orders;
- service revenue: sum final_service_fee_uzs Completed Orders;
- AOV: average final_total_uzs Completed Orders;
- average fulfilment: average completed_at-created_at;
- popular Product: count of Completed Orders containing fulfilled Product, quantities separate by unit.

Manager read-only.

# Idempotency / Concurrency

## 51. Required `Idempotency-Key`

UUID header required for:

```text
Create Order
Record Purchased Item
Customer Approval Decision
Complete Shopping
Initiate Payment Attempt
Customer Cancel
Retry Refund
Reorder
```

Persisted scope `(actor, operation, key)` + request hash. Same key/request → same logical result; same key/different request → `idempotency_key_reused`. Provider callbacks use provider-event identity.

## 52. Natural Idempotent Actions

No public key required for approved no-op target-state repeats: accept already accepted current assignment, start already started same assignment, delivered already completed same assignment context, block already blocked Staff, activate already active Staff. No duplicate history.

## 53. Concurrency

Backend uses current locked state. Stale Flutter mutation receives 409 stable state/business code and refreshes authoritative resource.

# Stable Error Vocabulary

## 54. Common

`validation_failed`, `authentication_required`, `forbidden`, `resource_not_found`, `business_conflict`, `rate_limited`, `idempotency_key_required`, `idempotency_key_reused`.

## 55. Auth

`invalid_credentials`, `account_blocked`, `password_change_required`, `otp_invalid`, `otp_expired`, `otp_attempts_exhausted`, `otp_resend_too_soon`.

## 56. Catalog/Cart/Checkout

`product_unavailable`, `product_archived`, `cart_item_already_exists`, `cart_empty`, `customer_profile_incomplete`, `address_incomplete`, `checkout_snapshot_stale`, `checkout_configuration_incomplete`.

## 57. Order/Shopper/Approval

`order_state_conflict`, `order_cancellation_not_allowed`, `cancellation_already_pending`, `shopper_not_assigned`, `shopping_not_active`, `item_already_resolved`, `customer_approval_required`, `shopping_incomplete`, `approval_not_pending`, `approval_expired`, `approval_already_resolved`.

## 58. Payment/Refund

`payment_not_payable`, `payment_already_paid`, `payment_outcome_pending`, `payment_provider_disabled`, `payment_provider_unavailable`, `payment_outcome_unknown`, `refund_not_allowed`, `refund_already_completed`, `refund_outcome_pending`.

## 59. Delivery/Admin

`courier_not_assigned`, `delivery_not_ready`, `delivery_state_conflict`, `last_active_admin_required`, `self_block_not_allowed`, `price_correction_locked`.

## 60. External Provider Safety

Never expose raw provider HTTP errors, signatures, merchant secrets, SQL, stack traces, or sensitive provider/card payloads to Flutter. Normalize safe codes and secret-filter logs.

## 61. External Integration Gates

Exact provider-specific callback/payment-action protocol is finalized only from official integration material. This does not authorize Codex to invent/generalize protocol. Missing external access blocks provider-specific implementation task/Stage closure.
