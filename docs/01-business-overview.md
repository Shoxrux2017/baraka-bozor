# BarakaBozor — Business Overview

## Document Status

**Status:** current. Rewritten on 2026-09-24 to the Project Owner's decisions in `docs/INTERVIEW_2026-09-24.md` (`DL-2` in `docs/DECISIONS.md`). Maintained by the implementing agent; product changes go through the Owner.

## Source Provenance

Formalizes "BOZORLIK YETKAZIB BERISH XIZMATI — TZ v1.1" (29.08.2026), the Stage 0 decisions of 2026-09-07, and the Owner interview of 2026-09-24. Where they differ, the interview wins.

## 1. Project Name

**BarakaBozor**

## 2. Business Model

An online household-shopping and delivery service built around one company-operated fulfilment process:

```text
ONLINE SHOPPING
+ COMPANY SHOPPER AT ONE WHOLESALE MARKET
+ DELIVERY BY A COMPANY COURIER
+ PAYMENT AFTER SHOPPING, CASH OR ONLINE
```

The Customer does not choose a market or a seller. BarakaBozor works with one wholesale market in one city. The Customer chooses products and quantities; a company Shopper buys them at the market; the Customer pays after shopping, in cash to the Courier or online; a Courier delivers. Market sellers have no accounts. This is not a marketplace.

## 3. Problem Statement

A market trip costs travel, transport, effort and time. BarakaBozor replaces it with one controlled flow:

```text
find products → choose exact quantities → create order
→ company buys at the market → final amount is known
→ courier delivers → customer pays cash at the door, or online before delivery
```

## 4. How an Order Works

1. The Customer signs in with a phone number and a login code, browses the catalog, adds products with exact quantities, a note and a substitution rule per item.
2. At checkout the Customer picks a saved address inside the service area, a payment method (cash to the Courier, or online), and may add a free-text wish about the delivery time.
3. The system creates the order with price, fee, address and settings snapshots. Until shopping starts the Customer may still edit or cancel it.
4. An Operator or Admin assigns a Shopper. The Shopper accepts, goes to the market and, item by item, records what was bought and at what price.
5. If a product is missing, more expensive than the estimate allows, or available only in a smaller quantity, the item is resolved by the Customer's substitution rule or by the Customer's decision in the app.
6. When every item is bought or removed, the system computes the final amount.
7. Cash orders go straight to delivery. Online orders wait up to 30 minutes for the Customer to pay in the app; if payment does not arrive, an Operator calls, switches the order to cash, or cancels it.
8. The Shopper leaves the packed order at the handoff point by the market. An Operator or Admin assigns a Courier, who collects it, delivers it, and records the cash received when the order is a cash order.
9. The order is completed and stays in the Customer's history for reordering.

## 5. MVP Operating Boundary

One BarakaBozor business, one city, one wholesale market, one handoff point by the market, one service area drawn as a circle around a centre point, many Customers and staff. No seller accounts, no multi-city or multi-market operation, no warehouse.

## 6. Roles

```text
customer   orders and pays
shopper    buys assigned orders at the market
courier    delivers assigned orders and collects cash
operator   runs the order board: assignment, attention, cancellation decisions
admin      everything the operator does, plus catalog, staff, settings, refunds
manager    read-only business figures (screens deferred past the pilot)
```

One account has exactly one role. At launch one person may hold the Admin role and do everything; the Operator role is the same board with catalog, staff and settings hidden. See `02-user-roles.md`.

## 7. Catalog

Admin-managed categories (flat list) and products. Names are required in Uzbek (Latin script) and Russian; descriptions are optional in both. One image per product. Units:

```text
kg  gram  piece  liter  package  box  bundle  meter
```

`kg`, `liter` and `meter` accept up to three decimals; the others accept whole numbers.

## 8. Pricing

The company earns a **markup on goods** plus a **service fee** plus a **delivery fee**.

- Admin enters each product's **market price**, the price the company expects to pay at the market.
- The **customer price** is the market price plus the markup percentage from business settings, rounded half-up to 1 UZS. That is the only price the Customer sees.
- Each product has one of two **price modes**:
  - **`fixed`** — the customer price is guaranteed. The Customer pays the price snapshotted at order time whatever the Shopper actually paid.
  - **`estimate`** — the customer price is an estimate. The Customer pays the customer price computed from the price the Shopper actually paid (actual market price plus the markup snapshot). If that exceeds the estimate by more than the **tolerance percentage** from business settings, the Shopper needs the Customer's approval before buying at that price.
- The **service fee** is fixed or a percentage of the merchandise subtotal; the **delivery fee** is one fixed tariff. Both are business settings.
- Every price, markup, fee and tolerance is snapshotted into the order at creation. Later changes to the catalog or settings never rewrite an existing order; an edit before shopping prices only the lines the Customer adds.

The Customer sees the composition of the amount — merchandise, service fee, delivery fee — at checkout, and the final composition before paying online or at the door.

## 9. Quantity Principle

The Customer's ordered quantity is the contract.

```text
ordered_quantity     what the Customer asked for
purchased_quantity   what the Shopper physically bought
billable_quantity    what the Customer pays for, never above ordered
```

If the Customer orders 5.000 kg and the Shopper buys 5.200 kg, the Customer pays for 5.000 kg. Reducing the quantity requires the Customer's approval, unless the whole item is removed under the Customer's own "remove if unavailable" rule.

## 10. Availability and Substitution

Per cart item the Customer chooses one rule; the default is the first:

```text
allow_similar_substitution    the Shopper may replace with a similar product within the price ceiling
contact_before_substitution   any replacement needs the Customer's approval
remove_if_unavailable         a missing item is removed without asking
```

A replacement must be an active catalog product with the same unit. The automatic ceiling is the item's fixed customer price, or for an estimate item the estimate plus the tolerance. A replacement above the ceiling needs approval.

## 11. Customer Approval

Approval is asked for `price_over_tolerance`, `substitution` and `reduced_quantity`. The Customer decides in the app. Ten minutes after the request the pending approval becomes an Operator attention item; thirty minutes after the request it expires. Expiry never means consent: an Operator or Admin may then only remove the affected item. Meanwhile the Shopper continues with the other items.

## 12. Payment

Every order is paid **after shopping**. At checkout the Customer chooses:

- **cash** — the Courier collects the final amount at handover;
- **online** — once shopping is complete the Customer has 30 minutes to pay the final amount in the app through an enabled provider. Payme and Click come first; Paynet and xazna later. Payment success is provider-authoritative: nobody in the app can mark an online payment as paid.

An online order left unpaid after 30 minutes becomes Operator attention. The Operator may switch it to cash on delivery, or cancel it. No prepayment, no authorization holds, no additional payments.

## 13. Refunds

A refund arises only when an online-paid order is cancelled before delivery. The system records the refund obligation and its amount; an Admin performs it in the provider's merchant cabinet and marks it done with the provider's reference. Operators see outstanding refunds. Automation per provider comes after the pilot.

## 14. Cancellation

Before shopping starts the Customer cancels directly. After shopping starts and before the Courier is on the way, the Customer files a cancellation request that an Operator or Admin approves or rejects; an approved cancellation costs the Customer nothing. Once the Courier is on the way, no normal cancellation. Returns and claims after delivery are post-MVP.

## 15. Delivery

A shopped order that is paid (online) or payable at the door (cash) is assigned to one active Courier. The Courier collects the packed order at the handoff point, accepts the assignment, starts, delivers, and records the cash received for a cash order. Until a handoff point exists, the Courier instead sees the Shopper's phone number and they meet at the market (server configuration, topic 1.1 fallback). If delivery fails — nobody answers, the Customer refuses, the address is wrong — the Courier marks it not delivered with the reason; the order returns to the pool and an Operator reassigns it or cancels it.

Orders are collected and delivered as soon as possible inside the working hours in business settings. An order placed outside working hours is accepted and collected after opening; the Customer sees that at checkout. No delivery slots.

## 16. Notifications

Customers, Shoppers and Couriers receive push notifications for the events `05-business-rules.md` Section 18 lists. SMS is used only for login codes, and only as a fallback: login codes go through Telegram first. A Shopper's order screen also refreshes itself while the app is open.

## 17. History and Reorder

Customers see their past orders. Reorder puts the originally ordered products back into the cart at current prices and availability, skipping products already in the cart and reporting products no longer available.

## 18. Manager Figures

Deferred past the pilot. The Admin board shows a summary strip: today's orders by status, today's sales, orders needing attention.

## 19. MVP Success Criterion

The pilot succeeds when this works with real Customers on cash:

```text
sign in with a login code → catalog → cart and address → checkout
→ Shopper buys at the market, approvals where needed → final amount
→ Courier delivers and collects cash → completed order in history
```

with the Admin running assignment and the board in the browser, and then when online payment through Payme and Click joins it.

## 20. Explicitly Outside the MVP

Delivery slots and zones, distance tariffs, bonus and cashback, promotions, recurring orders, in-app chat, order creation by Operators, spreadsheet import, receipt photos, live GPS, automatic dispatch, multiple cities or markets, seller accounts, warehouse or inventory, custom roles, returns and claims, offline shopping mode, AI and voice ordering, Telegram bot ordering.
