# BarakaBozor — Database

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `DL-2`–`DL-4` in `docs/DECISIONS.md`. The `users` and `customer_otp_challenges` tables are already migrated; every other table is created by the wave that first needs it, by forward migrations only.

## 1. Baseline

PostgreSQL 17. UUID primary keys on domain tables; `timestamptz` for every instant; business enums as `varchar` with `CHECK`; money `bigint` UZS; percentages `numeric(5,2)`; quantities `numeric(18,3)`; coordinates `numeric(9,6)` / `numeric(10,6)`. Named constraints. No hard deletes of history.

## 2. Table Map

```text
users                       customer_otp_challenges
customer_addresses
categories                  products                 product_images
carts                       cart_items
business_settings           payment_provider_settings
orders                      order_items              order_history
order_shopper_assignments   order_courier_assignments
customer_approvals          order_item_price_corrections
order_cancellation_requests
payments                    payment_attempts         provider_events
refunds
push_devices                notification_deliveries
idempotency_keys
```

Framework: `personal_access_tokens`, `cache`, `jobs`, `failed_jobs`, `job_batches`, `migrations`.

## 3. `users` (migrated)

`id, role, phone, full_name?, password?, status, must_change_password, password_changed_at?, last_login_at?, blocked_at?, created_by_user_id?, timestamps`, plus **`preferred_language varchar(2) NOT NULL DEFAULT 'uz'`** (`CHECK IN ('uz','ru')`, added by a Wave 0 migration).

Checks: role in the six values; status `active|blocked`; phone `^\+998[0-9]{9}$`; Customer has null password and no gate; Staff has a password; blocked implies `blocked_at`. Two partial unique indexes: `(phone) WHERE status='active' AND role='customer'` and `(phone) WHERE status='active' AND role<>'customer'`. Index `(role,status)`, `lower(full_name)`.

## 4. `customer_otp_challenges` (migrated)

`id, phone, purpose (customer_login), code_hash, failed_attempts ≥ 0, expires_at, consumed_at?, invalidated_at?, created_at`, plus **`channel varchar(16)`** (`CHECK IN ('telegram','sms','fake','test')`, added by a Wave 0 migration). Index `(phone, created_at)`, `expires_at`. No plaintext code.

## 5. `customer_addresses`

`id, customer_id → users, label?, latitude, longitude, street, house, apartment?, landmark?, delivery_note?, is_active, timestamps`. Checks: valid coordinate ranges, non-empty street and house. Index `(customer_id, is_active)`. The service-area check is application logic against `business_settings`.

## 6. `categories`

`id, name_uz, name_ru, description_uz?, description_ru?, sort_order, is_active, archived_at?, created_by_user_id, timestamps`. Non-empty names. Index `(is_active, sort_order)`, `lower(name_uz)`, `lower(name_ru)`.

## 7. `products`

`id, category_id → categories, name_uz, name_ru, description_uz?, description_ru?, unit_code, price_mode, market_price_uzs, is_active, sort_order, archived_at?, created_by_user_id, timestamps`.

Checks: unit in `kg, gram, piece, liter, package, box, bundle, meter`; `price_mode IN ('fixed','estimate')`; `market_price_uzs > 0`. Indexes `(category_id, is_active)`, `(is_active, sort_order)`, `lower(name_uz)`, `lower(name_ru)`.

The customer price is computed, never stored on the product: `half_up(market_price_uzs × (1 + markup_percent/100))`.

## 8. `product_images`

`id, product_id → products (unique), storage_key (unique), original_filename?, mime_type, size_bytes, timestamps`. Size 1..5 MB; MIME in JPEG, PNG, WebP.

## 9. `carts`

`id, customer_id, status (active|converted), timestamps`. Partial unique `(customer_id) WHERE status='active'`.

## 10. `cart_items`

`id, cart_id, product_id, quantity > 0, customer_note?, substitution_policy, timestamps`. Unique `(cart_id, product_id)`; policy in the three values. Unit precision validated by the application.

## 11. `business_settings`

Singleton `id = 1`: `markup_percent ≥ 0, service_fee_mode (fixed|percentage), service_fee_fixed_uzs?, service_fee_percent?, delivery_fee_uzs?, minimum_order_uzs?, price_tolerance_percent (default 15), opens_at time?, closes_at time?, service_centre_latitude?, service_centre_longitude?, service_radius_km?, delivery_delay_threshold_minutes (default 60), updated_by_user_id?, timestamps`. Cross-field check on the service-fee mode. Nullable fields stay null until Admin configures them; checkout is blocked while any needed value is null.

## 12. `payment_provider_settings`

`provider` PK in `payme, click, paynet, xazna`; `is_enabled`; `updated_by_user_id?`; timestamps. No secrets.

## 13. `orders`

```text
id uuid PK
order_number bigint unique, from sequence orders_order_number_seq
customer_id → users
source_cart_id → carts, unique
source_address_id → customer_addresses
status
payment_method            cash|online
delivery_time_note?       varchar(160)
recipient_name_snapshot, recipient_phone_snapshot
latitude_snapshot, longitude_snapshot, street_snapshot, house_snapshot,
apartment_snapshot?, landmark_snapshot?, delivery_note_snapshot?
markup_percent_snapshot, price_tolerance_percent_snapshot
service_fee_mode_snapshot, service_fee_fixed_uzs_snapshot?, service_fee_percent_snapshot?
delivery_fee_uzs_snapshot
delivery_delay_threshold_minutes_snapshot
final_merchandise_subtotal_uzs?, final_service_fee_uzs?, final_total_uzs?
shopping_started_at?, shopping_completed_at?,
ready_for_delivery_at?, on_the_way_at?, completed_at?, cancelled_at?
cancellation_reason_code?
created_at, updated_at
```

Status check on the nine values. Indexes `(customer_id, created_at)`, `(status, created_at)`, `(status, updated_at)`, `completed_at`, `cancelled_at`. The 30-minute online-payment attention instant lives on the payment row (Section 21).

## 14. `order_items`

```text
id, order_id → orders, product_id → products
product_name_uz_snapshot, product_name_ru_snapshot, unit_code_snapshot
price_mode_snapshot            fixed|estimate
market_price_uzs_snapshot
customer_unit_price_uzs_snapshot          fixed price, or the estimate
ordered_quantity > 0
purchased_quantity?
billable_quantity ≥ 0, ≤ ordered_quantity (or ≤ approved_quantity_cap when set)
customer_note_snapshot?, substitution_policy_snapshot
status                          pending|awaiting_customer|purchased|removed
approved_quantity_cap?
approved_unit_price_ceiling_uzs?
fulfilled_product_id? → products
fulfilled_product_name_uz_snapshot?, fulfilled_product_name_ru_snapshot?, fulfilled_unit_code_snapshot?
substitution_resolution?        automatic|approved
actual_market_price_uzs?
billable_unit_price_uzs?
line_total_uzs?
removed_reason_code?            unavailable|customer_rejected|approval_expired|customer_removed|operator_removed|order_cancelled
removed_at?
timestamps
```

Checks: purchased requires `purchased_quantity ≥ billable_quantity > 0`, a billable price, a line total and a fulfilled product; removed has billable quantity and line total zero and a reason. `actual_market_price_uzs` is required by the application for estimate items and replacements. Index `(order_id, status)`, `fulfilled_product_id`.

## 15. `order_history`

Append-only: `id, order_id, event_type, from_status?, to_status?, actor_type (user|system|payment_provider), actor_user_id?, reason_code?, note?, created_at`.

`event_type` in `status_changed, edited, payment_method_switched, price_corrected, shopper_assigned, shopper_reassigned, courier_assigned, courier_reassigned, delivery_failed, approval_requested, approval_decided, approval_expired, approval_resolved`. `reason_code` for cancellations in `customer_cancelled, cancellation_request_approved, unpaid_online, no_items_purchased, delivery_failed, system`. Index `(order_id, created_at)`.

## 16. `order_shopper_assignments`

`id, order_id, shopper_id → users, assigned_by_user_id, is_self_order, assigned_at, accepted_at?, started_at?, completed_at?, ended_at?, ended_reason? (completed|reassigned|order_cancelled), timestamps`. Partial unique `(order_id) WHERE ended_at IS NULL`. Index `(shopper_id) WHERE ended_at IS NULL`.

## 17. `order_courier_assignments`

`id, order_id, courier_id → users, assigned_by_user_id, is_self_order, assigned_at, accepted_at?, delivery_started_at?, delay_at?, completed_at?, ended_at?, ended_reason? (completed|reassigned|delivery_failed|order_cancelled), failed_reason_code? (no_answer|refused|wrong_address|other), failed_note?, timestamps`. Partial unique `(order_id) WHERE ended_at IS NULL`. Index `(courier_id) WHERE ended_at IS NULL`, `delay_at`.

## 18. `customer_approvals`

`id, order_id, order_item_id, type (price_over_tolerance|substitution|reduced_quantity), status (pending|approved|rejected|expired), requested_by_user_id, proposed_customer_unit_price_uzs?, proposed_actual_market_price_uzs?, proposed_quantity?, replacement_product_id?, replacement_name_uz_snapshot?, replacement_name_ru_snapshot?, replacement_unit_code_snapshot?, request_note?, attention_at, expires_at, resolved_by_user_id?, resolved_at?, resolution? (approved|rejected|remove_item), timestamps`.

Partial unique `(order_item_id) WHERE status='pending'`. Indexes `(order_id, status)`, `(status, attention_at)`, `(status, expires_at)`.

## 19. `order_item_price_corrections`

Append-only: `id, order_item_id, old_actual_market_price_uzs, new_actual_market_price_uzs, old_billable_unit_price_uzs, new_billable_unit_price_uzs, corrected_by_user_id, reason, created_at`.

## 20. `order_cancellation_requests`

`id, order_id, origin (customer|staff), requested_by_user_id, status (pending|approved|rejected), reason, resolved_by_user_id?, resolution_note?, resolved_at?, timestamps`. Partial unique `(order_id) WHERE status='pending'`.

## 21. `payments`

`id, order_id, method (cash|online), provider? (payme|click|paynet|xazna), amount_uzs > 0, status (unpaid|pending|paid|cancelled), attention_at?, paid_at?, cancelled_at?, recorded_by_user_id?, timestamps`.

Partial unique `(order_id) WHERE status <> 'cancelled'`: one live payment per order. Cash rows are created `paid` by the Courier's action with `recorded_by_user_id`. Online rows are created `unpaid` at shopping completion, are `pending` while an attempt is in flight or unknown, return to `unpaid` when that attempt fails, become `paid` on provider-confirmed success, and are `cancelled` when the Operator switches to cash or the order is cancelled unpaid.

## 22. `payment_attempts`

`id, payment_id, provider, status (pending|successful|failed|cancelled), provider_request_id (unique), provider_reference?, failure_code?, last_reconciled_at?, started_at, resolved_at?, timestamps`. Partial unique one `pending` and one `successful` per payment.

## 23. `provider_events`

`id, provider, event_key, payment_attempt_id?, payload_hash?, status (received|processed|ignored|failed), received_at, processed_at?, error_code?`. Unique `(provider, event_key)`. No raw sensitive payload.

## 24. `refunds`

`id, order_id, payment_id, amount_uzs > 0, status (pending|completed|failed), provider_reference?, note?, created_by_user_id?, completed_by_user_id?, completed_at?, timestamps`. A refund has one cause, the cancellation of an order with a paid online payment, so there is no reason column. Application check under the payment lock: sum of completed refunds ≤ paid amount.

## 25. `push_devices`

`id, user_id, platform (android|ios|web), push_token, last_seen_at?, revoked_at?, timestamps`. Unique `(push_token, user_id)`. Index `(user_id) WHERE revoked_at IS NULL`.

## 26. `notification_deliveries`

`id, user_id, push_device_id?, order_id?, approval_id?, type, status (queued|sent|failed), attempt_count, sent_at?, last_error_code?, timestamps`. `type` in the eleven values of `05` Section 18. Index `(user_id, created_at)`, `(status, created_at)`.

## 27. `idempotency_keys`

`id, actor_user_id, operation varchar(80), idempotency_key uuid, request_hash char(64), state (processing|completed), lease_expires_at, resource_type?, resource_id?, created_at, completed_at?`. Unique `(actor_user_id, operation, idempotency_key)`. Completed rows may be pruned after 30 days.

## 28. Deletion Strategy

`RESTRICT` on every business-history foreign key. Archive, block or deactivate current catalog, user and address rows; orders and everything under them are never deleted by a business operation.

## 29. Database versus Application Enforcement

Database: foreign keys, the phone-family indexes, one active cart, one live assignment per order, one pending approval per item, one pending cancellation request per order, one live payment per order, one pending and one successful attempt per payment, provider-event and idempotency uniqueness, positive amounts, enum checks, price-mode and status checks.

Application: role and ownership, unit precision, lifecycle transitions, price and ceiling semantics, approval necessity, same-unit replacement, rounding, refund sums, service area, working hours, the test-phone rule.

## 30. Deliberately Absent

Markets, cities, sellers, warehouses, inventory, promotions, bonuses, subscriptions, delivery zones, GPS tracks, chat, refund attempts.
