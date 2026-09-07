# BarakaBozor — Database

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## 1. Baseline

PostgreSQL, one BarakaBozor business/market, not multi-tenant. Domain tables use UUID PKs; authoritative instants `timestamptz`; business enums constrained `varchar + CHECK`; money `bigint` integer UZS; quantity `numeric(18,3)` with unit-specific application precision rules.

## 2. Table Map

```text
users
customer_otp_challenges
customer_addresses
categories
products
product_images
carts
cart_items
business_settings
payment_provider_settings
orders
order_items
order_status_history
order_shopper_assignments
customer_approvals
order_item_price_corrections
order_cancellation_requests
payments
payment_attempts
provider_events
refunds
refund_attempts
order_courier_assignments
push_devices
notification_deliveries
idempotency_keys
```

Framework tables: Sanctum tokens, queue tables, migrations.

## 3. `users`

| Column | Type | Null |
|---|---|---:|
| id | uuid | no |
| role | varchar(24) | no |
| phone | varchar(20) | no |
| full_name | varchar(160) | yes |
| password | varchar(255) | yes |
| status | varchar(16) | no |
| must_change_password | boolean | no |
| password_changed_at | timestamptz | yes |
| last_login_at | timestamptz | yes |
| blocked_at | timestamptz | yes |
| created_by_user_id | uuid | yes |
| created_at | timestamptz | no |
| updated_at | timestamptz | no |

Constraints: unique phone; roles six approved; status active/blocked; Customer password null + no change gate; Staff password non-null. Index `(role,status)`, `lower(full_name)`. No hard-delete historical users.

## 4. `customer_otp_challenges`

`id, phone, purpose, code_hash, failed_attempts, expires_at, consumed_at, invalidated_at, created_at`. Purpose `customer_login`. Index `(phone,created_at)`, `expires_at`. No plaintext OTP.

## 5. `customer_addresses`

`id, customer_id, label?, latitude numeric(9,6), longitude numeric(10,6), street, house, apartment?, landmark?, delivery_note?, is_active, timestamps`.

Checks valid coordinates, non-empty street/house. Index `(customer_id,is_active)`.

## 6. `categories`

`id, name, description?, sort_order, is_active, archived_at?, created_by_user_id, timestamps`. Index active/sort and lower(name).

## 7. `products`

`id, category_id, name, description?, unit_code, price_mode, fixed_price_uzs?, min_price_uzs?, max_price_uzs?, is_active, sort_order, archived_at?, created_by_user_id, timestamps`.

Units: `kg, gram, piece, liter, package, box, bundle, meter`.

Pricing checks:

```text
fixed: fixed>0; min/max null
range: fixed null; min>0; max>=min
at_purchase: all price fields null
```

Indexes Category/active, active/sort, lower(name), price_mode.

## 8. `product_images`

One current image/Product: `id, product_id, storage_key, original_filename?, mime_type, size_bytes, timestamps`.

Unique product_id/storage_key; size 1..5MB; MIME restricted to JPEG/PNG/WebP. Bytes live in Filesystem.

## 9. `carts`

`id, customer_id, status active|converted|abandoned, timestamps`. Partial unique one active Cart/Customer.

## 10. `cart_items`

`id, cart_id, product_id, quantity numeric(18,3), customer_note?, substitution_policy, timestamps`.

Quantity >0; unique `(cart_id,product_id)`; substitution policy in approved three values. Unit-specific integer/fraction rule application validated.

## 11. `business_settings`

Singleton `id=1`: Service fee mode/value, Delivery fee, delivery delay threshold, updated_by, timestamps.

Service mode `fixed|percentage`; cross-field checks. Delay default 60. Required fees may be null until Admin config; checkout blocks while incomplete.

## 12. `payment_provider_settings`

`provider` PK (`payme|paynet|xazna|click`), `is_enabled`, updated_by, timestamps. No secrets.

## 13. `orders`

Key columns:

```text
id uuid PK
order_number unique
customer_id
source_cart_id unique
source_address_id
status
payment_flow prepaid|deferred
selected_payment_provider
recipient_name_snapshot
recipient_phone_snapshot
latitude/longitude_snapshot
street/house/apartment/landmark/delivery_note snapshots
service_fee_mode/fixed/percentage snapshots
delivery_fee_uzs_snapshot
final_merchandise_subtotal_uzs nullable
final_service_fee_uzs nullable
final_total_uzs nullable
shopping_started_at nullable
shopping_completed_at nullable
ready_for_delivery_at nullable
on_the_way_at nullable
completed_at nullable
cancelled_at nullable
created_at/updated_at
```

Status values are canonical states in Business Rules. Index Customer/date, status/date, status/update, completed_at, cancelled_at.

## 14. `order_items`

Key columns:

```text
id
order_id
product_id
product_name_snapshot
unit_code_snapshot
price_mode_snapshot
fixed/min/max price snapshots
ordered_quantity
purchased_quantity nullable
billable_quantity
customer_note_snapshot nullable
substitution_policy_snapshot
status
fulfilled_product_id nullable
fulfilled_product_name_snapshot nullable
fulfilled_unit_code_snapshot nullable
substitution_resolution nullable
purchase_unit_price_uzs nullable
billable_unit_price_uzs nullable
line_total_uzs nullable
removed_reason_code nullable
removed_at nullable
timestamps
```

States `pending|awaiting_customer|purchased|removed`.

Checks: ordered>0, billable>=0, billable<=ordered. Purchased requires purchased_quantity>=billable_quantity>0, billable price, line total, fulfilled Product. Procurement price may be null for ordinary fixed original Item and is required by application for dynamic/replacement contexts. Removed has billable=0 and line_total=0.

## 15. `order_status_history`

Append-only `id, order_id, from_status?, to_status, actor_type user|system|payment_provider, actor_user_id?, reason_code?, note?, created_at`. Index Order/date.

## 16. `order_shopper_assignments`

`id, order_id, shopper_id, assigned_by_user_id, assigned_at, accepted_at?, started_at?, completed_at?, ended_at?, ended_reason?, timestamps`.

Partial unique one current assignment where ended_at null. Index Shopper/current and Order/current.

## 17. `customer_approvals`

`id, order_id, order_item_id, type, status, requested_by_user_id, proposed_unit_price_uzs?, proposed_quantity?, replacement_product_id?, replacement_name_snapshot?, replacement_unit_snapshot?, request_note?, attention_at, expires_at, resolved_by_user_id?, resolved_at?, timestamps`.

Types `price_over_range|substitution|reduced_quantity`; states `pending|approved|rejected|expired`.

Partial unique one pending Approval/Item. Index Order/status, status/attention, status/expiry. Persist attention +10m and expiry +30m snapshots.

## 18. `order_item_price_corrections`

Append-only: `id, order_item_id, old/new purchase price, old/new billable price, corrected_by_user_id, reason, created_at`. Application enforces Admin/dynamic/pre-final-Payment.

## 19. `order_cancellation_requests`

`id, order_id, origin customer|staff|system, requested_by_user_id?, status pending|approved|rejected, reason, resolved_by_user_id?, resolution_note?, resolved_at?, timestamps`. Partial unique one pending/Order.

## 20. `payments`

Business obligation: `id, order_id, kind checkout|final|additional, provider, amount_uzs>0, status unpaid|pending|paid|cancelled, attention_at?, expires_at?, paid_at?, cancelled_at?, timestamps`.

Unique `(order_id,kind)`. Checkout expires +30m; final/additional gets +30m attention but no auto-cancel.

## 21. `payment_attempts`

`id, payment_id, status pending|successful|failed|cancelled, provider_request_id, provider_reference?, failure_code?, last_reconciled_at?, started_at, resolved_at?, timestamps`.

Unique provider_request_id; provider reference unique where applicable; partial unique one pending and one successful Attempt/Payment.

## 22. `provider_events`

`id, provider, event_key, payment_attempt_id?, refund_attempt_id?, payload_hash?, status received|processed|ignored|failed, received_at, processed_at?, error_code?`.

Unique `(provider,event_key)`. At most one target attempt. No sensitive raw payload by default.

## 23. `refunds`

`id, order_id, payment_id, kind order_adjustment|cancellation, amount_uzs>0, status pending|successful|failed, reason_code, created_by_user_id?, completed_at?, timestamps`.

Application under Payment lock enforces sum successful refunds <= successful paid amount.

## 24. `refund_attempts`

`id, refund_id, status pending|successful|failed, provider_request_id, provider_reference?, failure_code?, last_reconciled_at?, started_at, resolved_at?, timestamps`.

Partial unique one pending and one successful Attempt/Refund.

## 25. `order_courier_assignments`

`id, order_id, courier_id, assigned_by_user_id, assigned_at, accepted_at?, delivery_started_at?, delay_at?, completed_at?, ended_at?, ended_reason?, timestamps`.

Partial unique one current assignment. `delay_at` snapshots start + configured threshold. Index Courier/current, Order/current, delay_at.

## 26. `push_devices`

`id, user_id, platform android|ios, push_token, last_seen_at?, revoked_at?, timestamps`. Unique push_token.

## 27. `notification_deliveries`

`id, user_id, push_device_id?, order_id?, type, status queued|sent|failed, attempt_count, sent_at?, last_error_code?, timestamps`. Required five Customer notification types. Never controls Order state.

## 28. `idempotency_keys`

| Column | Type | Null |
|---|---|---:|
| id | uuid | no |
| actor_user_id | uuid | no |
| operation | varchar(80) | no |
| idempotency_key | uuid | no |
| request_hash | char(64) | no |
| state | varchar(20) | no |
| resource_type | varchar(60) | yes |
| resource_id | uuid | yes |
| created_at | timestamptz | no |
| completed_at | timestamptz | yes |

State `processing|completed`. Unique `(actor_user_id,operation,idempotency_key)`. Store request hash only, not sensitive body. Same key/different hash conflicts. Completed old infrastructure records may be cleaned after safe retention; business history unaffected.

## 29. Framework Tables

Use standard `personal_access_tokens`, `jobs`, `failed_jobs`, `job_batches`, `migrations` as applicable.

## 30. Deletion Strategy

Prefer RESTRICT/NO ACTION for business-history FKs. Archive/block/deactivate current Catalog/User/Address instead of cascading destruction. Orders/Items/Payments/Refunds/assignment/Approval/cancellation/status histories have no ordinary hard-delete business operation.

## 31. Database vs Application Enforcement

Database structural enforcement: FK, unique phone/order/source Cart, one active Cart, one current assignments, one pending Approval/cancellation, pricing shape, positive values, one pending/successful Payment Attempt, provider-event and idempotency uniqueness.

Application enforcement: roles, ownership/assignment, unit precision, lifecycle transitions, price semantics, Approval necessity, substitution compatibility, rounding formulas, Payment/refund aggregate limits, analytics definitions.

## 32. Index Families

Support active Catalog/name, Customer Orders/date/status, operational status/update, Shopper/Courier current assignments, Approval attention/expiry, Payment attention/expiry/reconciliation, Refund attention, Courier delay, Completed/Cancelled analytics, fulfilled Product analytics. Exact EXPLAIN refinements do not change public behavior.

## 33. Deliberately Absent MVP Tables

No markets/cities/vendors/Sellers/warehouses/inventory/promotions/bonuses/subscriptions/Courier GPS/dispatch/AI tables.
