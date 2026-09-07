# BarakaBozor — Business Overview

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-09-07.

## Source Provenance

This document formalizes the business requirements in **“BOZORLIK YETKAZIB BERISH XIZMATI — TZ v1.1” (29.08.2026)** and the approved Stage 0 product decisions. The source TZ remains the provenance for the original business idea; this `docs/01–09` set is the implementation contract after Stage 0 lock.

## 1. Project Name

**BarakaBozor**

## 2. Business Model

BarakaBozor is an online household-shopping and delivery service centered on one company-operated fulfilment process:

```text
ONLINE SHOPPING
+
COMPANY SHOPPER
+
ONLINE PAYMENT
+
DELIVERY
```

The Customer does **not** choose a market or an individual market Seller. In the MVP, BarakaBozor works with one large wholesale market. The Customer chooses the required Product and quantity; a company Shopper purchases the goods at the market; the system manages pricing, approvals, payment, and delivery; a Courier delivers the completed Order.

BarakaBozor is therefore **not a marketplace of independent Sellers** in the MVP. Market Sellers do not have platform accounts.

## 3. Problem Statement

Traditional market shopping can require substantial travel time, transport, physical effort, and coordination, especially for busy people, families with small children, elderly Customers, people without convenient transport, and Customers buying many categories at once.

BarakaBozor replaces the Customer's physical market trip with one controlled service flow:

```text
find Products
→ choose exact quantities
→ create Order
→ company purchases at market
→ calculate final amount
→ online payment
→ home delivery
```

## 4. Proposed Solution

1. The Customer authenticates and browses the Product Catalog.
2. The Customer selects Products and exact quantities.
3. The Customer chooses substitution preferences and may leave Product-specific notes.
4. The Customer prepares a Cart and selects a saved delivery Address.
5. The system creates an Order using current Product, pricing, Address, and fee snapshots.
6. An Admin assigns an active Shopper.
7. The Shopper purchases the Order at the wholesale market.
8. Unavailable Products, reduced quantities, substitutions, and price approvals are resolved through the approved rules.
9. The system calculates the authoritative final Order amount.
10. Payment is completed through an approved online Payment provider.
11. An Admin assigns an active Courier.
12. The Courier delivers the Order.
13. The Order becomes Completed and remains available in Customer history.

## 5. MVP Operating Boundary

The MVP supports one BarakaBozor business, one operating city/region, one wholesale market, many Customers and Staff users, and no Seller accounts or marketplace tenancy. Multi-city and multi-market operation is Post-MVP.

## 6. MVP Roles

The six approved MVP roles are:

1. `customer` — creates and pays for Orders and receives delivery;
2. `shopper` — purchases assigned Orders at the market;
3. `courier` — delivers assigned ready Orders;
4. `operator` — monitors and resolves permitted operational problems;
5. `admin` — manages Catalog, Staff, assignments, fees, and operational settings;
6. `manager` — read-only business analytics and KPI monitoring.

Each account has exactly one primary role in the MVP.

## 7. Catalog

The Catalog is Admin-managed and contains dynamic Categories and Products. Categories are not hard-coded enums.

Supported MVP unit codes:

```text
kg
gram
piece
liter
package
box
bundle
meter
```

Products have one current image in the MVP. Customer-facing Product images support JPEG, PNG, and WebP, with a backend-authoritative 5 MB maximum per image.

## 8. Pricing Model

Each Product uses one current pricing mode:

```text
fixed
range
at_purchase
```

### Fixed

The Customer sees one fixed unit price. The Order snapshots that price at checkout. For an ordinary non-substituted fixed Item, the Customer's billable unit price remains the fixed snapshot even if the company's actual market procurement cost differs.

### Range

The Customer sees an accepted minimum/maximum unit-price range. The actual purchased unit price becomes the billable unit price when it is within the accepted range. If the actual price is above the snapshotted maximum, Customer approval is required **before** the Shopper purchases that Item at the higher price.

### At Purchase

The Customer explicitly accepts that the unit price is unknown at checkout. The Shopper records the actual purchase unit price, and the Customer sees the authoritative final Order amount before deferred online payment. A separate pre-purchase price approval is not required for the original `at_purchase` Product.

Changing current Catalog pricing never rewrites historical Order pricing.

## 9. Quantity Principle

The Customer's ordered quantity is authoritative for the Customer contract.

```text
ordered_quantity
purchased_quantity
billable_quantity
```

If the Customer orders `5.000 kg` and the Shopper purchases `5.200 kg`, the Customer is not charged for the extra `0.200 kg`. The excess is an internal company matter.

Reducing the Customer's quantity requires Customer approval unless the whole unavailable Item is removed under the Customer's preselected `remove_if_unavailable` policy.

## 10. Product Availability and Substitution

For each Cart Item, the Customer chooses one policy:

```text
allow_similar_substitution
contact_before_substitution
remove_if_unavailable
```

A structured replacement must reference a current active Catalog Product and use compatible unit semantics.

Automatic similar substitution is allowed only within the approved price ceiling:

- original `fixed` → fixed-price snapshot;
- original `range` → max-price snapshot;
- original `at_purchase` → no automatic substitution; explicit Customer approval.

A replacement above the applicable ceiling requires Customer approval.

## 11. Customer Approval

Approval is used for `price_over_range`, `substitution`, and `reduced_quantity`.

A pending approval becomes an Operator-attention item after 10 minutes. If no Customer decision exists after 30 minutes, the approval expires. Expiration never means Customer consent.

For an expired approval, Operator/Admin may only remove the affected Item. They may not approve higher spending, substitution, or reduced quantity on the Customer's behalf.

## 12. Fees

BarakaBozor may charge a separate Service fee and Delivery fee. Service fee can be fixed or a percentage of final merchandise subtotal. Percentage calculations and Product line totals use half-up rounding to the nearest 1 UZS.

The MVP uses one fixed Delivery tariff. Zone- and distance-based delivery pricing are Post-MVP.

The Customer must see the understandable composition of the amount before payment.

## 13. Payment

Online Payment is mandatory in the MVP through:

```text
Payme
Paynet
xazna
Click
```

Two normal flows exist:

- fixed-only Order → prepaid before Shopping;
- any `range`/`at_purchase` Item → Shopping first, then authoritative final amount and deferred Payment.

Payment success is provider-authoritative. Flutter, Customer, Operator, and Admin cannot fabricate successful Payment state. Uncertain outcomes require reconciliation before another potentially duplicating charge is allowed.

## 14. Refunds and Adjustments

Refund is a separate financial operation. Examples include prepaid downward adjustment and approved paid-order cancellation.

A pending overpayment refund does not block Delivery when Customer payment already covers the authoritative final total. Failed/uncertain refunds become Operator/Admin attention and require provider-authoritative reconciliation/retry.

## 15. Cancellation

Before Shopping starts, Customer may cancel directly. After Shopping starts but before `on_the_way`, Customer creates a cancellation request that Operator/Admin may approve or reject. Normal cancellation is unavailable once `on_the_way`. Post-delivery returns/claims are Post-MVP.

## 16. Delivery

A ready, sufficiently paid Order is assigned to one active Courier. The Courier sees only required delivery data, accepts the assignment, starts delivery, and marks delivered after physical handover.

Real-time GPS, proof photos, signatures, and delivery OTP are not required in MVP.

## 17. Notifications

Customer notification attempts are required at least for Order accepted, approval required, Payment required, Courier started, and Order delivered. Notifications are not authoritative state.

## 18. History and Reorder

Customer can view historical Orders. `Reorder` uses the **original ordered Product**, not a historical replacement, and applies current availability/pricing. Existing Cart duplicates are skipped rather than overwritten.

## 19. Manager Analytics

Manager is read-only. MVP KPIs include Orders created, Completed, Cancelled, gross sales = sum `final_total_uzs` for Completed Orders, service revenue = sum `final_service_fee_uzs`, average Order value, average fulfilment time, Staff activity, and popular Products ranked by number of Completed Orders containing the Product with quantities shown separately by unit.

## 20. MVP Success Criterion

The MVP succeeds only when this real flow works:

```text
Customer authentication
→ Catalog
→ Cart/Address
→ Checkout/Order
→ Shopper market purchase
→ approval/final pricing where needed
→ online Payment
→ Courier delivery
→ Completed history
```

and Admin, Operator, and Manager can perform approved responsibilities without direct database manipulation.

## 21. Explicit Post-MVP Scope

Outside MVP: bonus/cashback, recurring shopping, AI recommendations, voice ordering, Telegram bot, live Courier GPS, automatic dispatch, multiple cities/markets, Seller marketplace accounts, complex promotions, warehouse/inventory planning, custom roles/multi-role accounts, and post-delivery claims/returns workflow.
