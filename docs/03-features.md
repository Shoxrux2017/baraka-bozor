# BarakaBozor — Features

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `docs/INTERVIEW_2026-09-24.md` and `DL-2`–`DL-5` in `docs/DECISIONS.md`.

## 1. MVP Feature Overview

```text
Authentication → Catalog → Cart and address → Checkout and order
→ Market shopping with approvals → Final amount
→ Delivery, cash at the door or online payment → History and reorder
```

Supporting features: the Admin and Operator web panel, notifications, business settings. Manager figures are deferred.

## 2. Authentication and Session

**Customer:** request a login code for a phone number; verify it; account created on first verified login; session bootstrap through `/auth/me`; logout. Codes go through Telegram Gateway when the number has Telegram, else SMS (fake gateway until a provider exists). Test phone numbers verify with a fixed code.

**Staff:** phone and password login; temporary password and mandatory first-login change; active or blocked enforcement; role-aware entry.

**Sessions:** bearer tokens, 30 days sliding, several per account; two sessions on one device for Customer mode.

## 3. Customer Profile

View and edit `full_name` and `preferred_language` (`uz` or `ru`). Checkout requires a non-empty name. The phone is the login identity and is not edited here.

## 4. Delivery Addresses

Create, list, edit and deactivate own addresses. Required: a point on the map inside the service area, street, house. Optional: label, apartment, landmark, note for the Courier. The map is Yandex MapKit in the client; the backend stores coordinates and text only and checks the service-area circle.

## 5. Catalog

Admin manages a flat list of categories and the products in them: bilingual names (required) and descriptions (optional), unit, price mode, market price, one image (JPEG, PNG or WebP, at most 5 MB), sort order, archive and restore. Customers list active categories and products, search by name in both languages at once, and see the customer price (market price plus markup). Images are served from public URLs.

## 6. Pricing

Two price modes, `fixed` and `estimate` (`01` Section 8). Business settings hold the markup percentage, the service fee (fixed or percentage), the delivery fee, the tolerance percentage and the minimum order amount. Everything is snapshotted into the order.

## 7. Quantity

`kg`, `liter`, `meter`: positive decimal with up to three decimals. `gram`, `piece`, `package`, `box`, `bundle`: positive integer. Ordered, purchased and billable quantities are distinct.

## 8. Cart

One active cart per Customer, created on first access. A product appears at most once; the Customer changes quantity, note and substitution rule, removes items, and sees current customer prices. The cart is not history.

## 9. Checkout Preview

Input: an own active address, the payment method (`cash` or `online`), an optional free-text delivery wish. Checks: non-empty name, address inside the service area, non-empty cart, active products, valid quantities, minimum order amount, complete settings, and for `online` at least one enabled provider. Output: the lines with their kind, merchandise subtotal, service fee, delivery fee, total, and whether the total is `final` (only fixed items) or an `estimate` (any estimate item), plus a note when the order falls outside working hours. A signed checkout token valid for five minutes binds the preview to the current state.

## 10. Order Creation

Idempotent. Snapshots products, quantities, notes, rules, prices, markup, tolerance, fees, recipient, address and payment method; converts the cart; creates a new empty cart in the same transaction; assigns the next order number; notifies the Customer.

## 11. Order Editing

Until shopping starts the Customer may replace the item set (add, remove, change quantities, notes, rules) and the delivery wish. Editing re-snapshots the changed lines at current prices, re-checks the minimum order amount, and writes an order history entry. Address and payment method are not editable; cancel and reorder instead.

## 12. Order Lifecycle

```text
new → shopping_assigned → shopping → [final_payment_pending] → ready_for_delivery
→ delivery_assigned → on_the_way → completed
cancelled from any non-terminal state under the cancellation rules
```

`final_payment_pending` exists only for online orders. "Awaiting a Customer decision" is derived from pending approvals, not a stored state. No generic status update exists.

## 13. Assignment

Operators and Admins assign one active Shopper to a `new` order (reassignment until shopping starts) and one active Courier to a `ready_for_delivery` order (reassignment until the Courier is on the way). An assignment whose assignee shares the Customer's phone number is allowed and flagged as a self-order on the board and in history.

## 14. Market Shopping

The Shopper accepts, starts, and per item: records purchased quantity and, for estimate items and replacements, the actual market price; marks unavailable; proposes a replacement; requests approval for a price over tolerance, a substitution needing consent, or a reduced quantity; continues with other items while one awaits the Customer; completes shopping when every item is `purchased` or `removed` and no approval is pending. If nothing was purchased the order is cancelled.

## 15. Availability and Substitution

Rules `allow_similar_substitution`, `contact_before_substitution`, `remove_if_unavailable`. A replacement must be active and have the same unit. Automatic replacement is allowed only under the first rule and only within the price ceiling; otherwise approval.

## 16. Customer Approval

Types `price_over_tolerance`, `substitution`, `reduced_quantity`; states `pending`, `approved`, `rejected`, `expired`. Ten minutes: Operator attention. Thirty minutes: expired. Approve applies the persisted proposal and returns the item to `pending` for the Shopper to record the purchase; reject removes the item; an expired approval can only be resolved by an Operator or Admin removing the item.

## 17. Final Amount

Each purchased item: billable unit price × billable quantity, rounded half-up to 1 UZS. Merchandise subtotal is the sum of rounded lines. Service fee: fixed, or the percentage of the subtotal rounded half-up. Total = subtotal + service fee + delivery fee. Computed once at shopping completion and again after an Admin price correction while the order is unpaid.

## 18. Payment

- **Cash:** the order goes to delivery unpaid; the Courier records the cash received at handover; the amount must equal the final total.
- **Online:** at shopping completion a payment obligation for the final total is created and the Customer is notified; the Customer starts an attempt with an enabled provider (Payme, Click; Paynet and xazna later); the provider's callback confirms success; 30 minutes unpaid becomes Operator attention; the Operator may switch to cash or cancel. Failed attempts may be retried; an uncertain outcome is reconciled with the provider before another attempt.

## 19. Refunds

Manual, tracked: an obligation is created when an online-paid order is cancelled; Admin marks it done with the provider reference or failed; Operators see outstanding refunds.

## 20. Cancellation

Before shopping starts: the Customer cancels directly. After shopping starts and before `on_the_way`: the Customer files a request, an Operator or Admin decides. `on_the_way` and later: no. Operators may cancel unpaid online orders after the 30-minute window and orders that could not be delivered.

## 21. Courier Delivery

Accept, start (`on_the_way`, delay snapshot), delivered with cash received for cash orders, or not delivered with a reason. Delay past the threshold is derived attention.

## 22. Operator and Admin Panel

Web panel. Order board with filters and the summary strip; attention list (pending and expired approvals, Customer no-response, unpaid online orders, outstanding refunds, delayed Couriers, failed deliveries, cancellation requests, self-orders); assignment; cancellation decisions; switch to cash; refund tracking; Admin-only catalog, staff, settings and provider enablement; audited price correction.

## 23. Notifications

Push through FCM behind an abstraction: Customer `order_accepted`, `approval_required`, `payment_required`, `courier_started`, `order_delivered`, `order_cancelled`; Shopper `shopping_assigned`, `approval_answered`, `shopping_order_cancelled`; Courier `delivery_assigned`, `delivery_cancelled`. Texts in the user's language from backend templates; payloads carry the event and an ID only. Delivery is best-effort and never changes order state. The Shopper's order screen also polls while the app is open.

## 24. History and Reorder

Own order history with snapshots. Reorder adds the original products at current prices and availability to the active cart, skips duplicates, reports unavailable products, never creates an order by itself.

## 25. Business Settings

Markup percentage, service fee mode and value, delivery fee, minimum order amount, tolerance percentage, working hours, service-area centre and radius, delivery delay threshold; provider enablement per provider. Edited by Admin on one screen. Test phone numbers and provider credentials are server configuration, not settings.

## 26. Deferred Past the Pilot

Manager figures and `staff-activity`; Paynet and xazna; automated refunds; iOS release; delivery zones and tariffs; spreadsheet import; everything in `01` Section 20.
