# Owner interview, 2026-09-24

Working record of the product interview between the Project Owner and the implementing agent (Claude Code). Each answer here is a Project Owner decision. The decisions are folded into `docs/01–09` by the documentation overhaul that follows the interview; until then this file is the authority for them.

Format: topic, then each question with the option chosen and its consequence.

## Topic 1. Physical operation

**1.1 Handoff from Shopper to Courier: a handoff point near the market (option A).** The Shopper leaves the packed order, labelled with the order number, at a fixed point by the market; the Courier collects it there. The system needs only the `ready_for_delivery` state and the order number on the Courier's screen. If no such point exists at launch, fallback B applies: the Courier sees the Shopper's phone number and they meet at the market.

**1.2 A Shopper may hold several orders at once (option B).** Admin may assign several orders to one Shopper; each is shopped and recorded separately. No merged shopping list in the MVP.

**1.3 Timing: as soon as possible inside working hours, plus a free-text wish (option В).** Admin sets working hours in business settings. An order placed outside them is accepted and the Customer sees that it will be collected after opening. Checkout carries an optional free-text "desired delivery time" that the Shopper and Courier see. No delivery slots in the MVP.

**1.4 No purchase proof in the MVP (option A).** The Shopper's recorded purchase price is the record. Cash handling and reimbursement are outside the system. Receipt or item photos are not collected.

## Topic 2. Catalog and pricing

**2.1 Revenue: service fee plus a markup on goods (option Б).** Business settings gain a markup percentage. The price the Customer sees is the market price entered by Admin plus the markup; the service fee and delivery fee stay as separate lines. Snapshots keep the displayed price, so a later markup change never rewrites an existing order.

**2.2 Two price modes: `fixed` and `estimate` (option Б).** `fixed`: the Customer pays exactly the shown price, prepaid before shopping. `estimate`: the Customer sees an approximate price and pays after shopping at the actual purchase price (plus markup); if the actual price exceeds the estimate by more than the configured tolerance percentage (business setting, default 15%), the Shopper must obtain Customer approval before buying at that price. The former `range` and `at_purchase` modes are removed; no product is ever shown without a price. The estimate also serves as the reference for the typo guard (former S-35).

**2.3 Both catalog languages required for names (option A).** `name_uz` and `name_ru` are mandatory on Categories and Products; descriptions are optional in both. Customer search matches both languages regardless of the interface language.

**2.4 Catalog entered by hand through the Admin surface (option A).** No spreadsheet import in the MVP. The Owner did not state the starting catalog size; the working assumption is fewer than 300 products and about 15–25 categories, flat, no nesting.

## Topic 3. Payment and refunds

**3.0 Owner's amendment: every order is paid after shopping. There is no prepaid flow.** At checkout the Customer chooses the payment method: cash to the Courier, or online. Cash: the order goes through shopping and delivery unpaid and the Courier records the cash received at handover. Online: once shopping is complete the Customer has 30 minutes to pay the final amount in the app. Consequences: the `checkout_payment_pending` state, the checkout Payment obligation, additional payments and overpayment refunds are all removed; `fixed` versus `estimate` now only says whether the shown price is guaranteed, not when it is paid.

**3.1 Cash to the Courier is accepted alongside online payment (option Б).** Cash orders need no payment provider and no refund. Courier cash accounting is outside the system.

**3.2 Online orders are paid after shopping, with an operator escape (option A).** If the 30 minutes pass unpaid the order becomes Operator attention, not auto-cancelled. The Operator may switch the order to cash on delivery, or cancel it. The switch is an explicit operator action recorded in history.

**3.3 Two payment providers at launch: Payme and Click (option Б).** Paynet and xazna come after launch. The system keeps the provider abstraction so adding one is an adapter, not a model change.

**3.4 Refunds are manual in the MVP, tracked by the system (option Б).** When a refund is due (an online-paid order cancelled before delivery), the system records the obligation and amount; an Admin performs it in the provider's merchant cabinet and marks it done with the provider's reference. Operators see outstanding refunds. Automated refunds arrive later, per provider capability.

## Topic 4. Order, substitutions, approvals, cancellation

**4.0 Default substitution policy is `allow_similar_substitution`** (agent's decision, not objected to). The Customer may change it per item.

**4.1 Minimum order amount is a business setting (option Б).** Checkout is refused below it; the refusal carries the minimum and the shortfall as data so the client can say how much is missing.

**4.2 The Customer may edit an order until shopping starts (option Б).** Add items, remove items, change quantities, notes and substitution policies while the order is `new` or `shopping_assigned` and the Shopper has not pressed start. Added lines take current catalog prices; lines that stay keep their price snapshots; fee and markup snapshots stay as at creation (precision added by `DL-6`). The minimum amount is re-checked and the change is recorded in order history. After shopping starts the order is read-only for the Customer.

**4.3 Approval timing stays as documented (option A).** 10 minutes after creation the pending approval becomes Operator attention; 30 minutes after creation it expires; an expired approval never counts as consent, and only an Operator or Admin resolves it, by removing the item. The Shopper continues with the other items meanwhile.

**4.4 Cancellation after shopping has started stays as documented (option A).** The Customer files a cancellation request; the Operator approves or rejects it. An approved cancellation costs the Customer nothing. Once the Courier is on the way, no normal cancellation.

## Topic 5. Delivery, addresses, maps

**5.1 Service area is a circle (option Б).** Business settings hold a centre point and a maximum distance in kilometres. An address whose point lies outside cannot be saved as a delivery address, and the refusal says so. Polygon zones are post-MVP.

**5.2 Maps: Yandex MapKit (option A).** The Flutter client uses Yandex MapKit for the address point picker and map display; the free tier (25 000 MAU, 25 000 search/routing requests per day, free-to-download apps) covers the MVP. The Owner obtains the developer account and API key. The backend stays map-neutral and stores only coordinates and text.

**5.3 Failed delivery is a Courier action (option Б).** The Courier marks "not delivered" with a reason (no answer, refused, wrong address). The order returns to `ready_for_delivery`, the assignment ends with that reason, and the order becomes Operator attention; the Operator reassigns a Courier later or cancels. Recorded in order history.

**5.4 One fixed delivery tariff (option A).** As documented; zone or distance pricing is post-MVP.

## Topic 6. Roles and workstations

**6.0 Agent decisions, not objected to:** a role opening the app on a surface that is not its own (an Admin on a phone) sees a screen saying which surface to use; the backend does not enforce surfaces. The Staff-to-Customer mode switch ships together with the Cart.

**6.1 Operator, Admin and Manager work in a web panel in the browser (option Б).** Built from the same Flutter code as a web target. The Windows desktop build decided on 2026-09-21 is withdrawn. Consequences: a web build target and hosting for it, CORS configuration, and a browser session strategy; no installer, no Windows signing.

**6.2 At launch the Admin does everything (option Б).** The Operator surface is the Admin's order board with catalog and staff management hidden, so an Operator account is a restricted Admin. Manager KPI screens are deferred until after launch. All six roles stay in the model and accounts of any role can be created.

**6.3 Operators and Admins both assign and reassign Shoppers and Couriers (option Б).** Before shopping starts and before delivery starts, as the lifecycle already limits.

**6.4 A Shopper or Courier may be assigned an order placed from their own phone number (option Б).** The assignment is allowed and the order carries an audit flag "self-order" visible to Operators and Admins in the board and in history. No refusal.

## Topic 7. Notifications and SMS

**7.0 Agent decisions, not objected to:** the Courier receives push for a new delivery assignment and for cancellation of an assigned order; `order_accepted` fires when the order is created; push titles and bodies are rendered by the backend from a two-language template set using the language the client reports for the user (stored on the user); a phone holding two accounts registers its push token once per account, so both roles are notified.

**7.1 SMS provider: Eskiz (option A).** Behind the existing `SmsGateway` abstraction. Contract and sender name follow the legal entity; until then the fake gateway.

**7.2 Test phone numbers with a fixed OTP (option A).** Server configuration lists test phone numbers and one fixed code that verifies for them without sending an SMS. Empty in production. This is how the Owner and app-store reviewers sign in before a real SMS provider exists; the rule that a real OTP is never emitted anywhere is unchanged.

**7.3 The Shopper calls the Customer from the app (option A).** A "call" button shows the Customer's phone to the Shopper only while the order is assigned to that Shopper and shopping is active. No in-app chat in the MVP.

**7.4 Push only, no SMS duplicates (option A).** Status notifications go by push alone. SMS is used only for the login code.

## Topic 8. Languages and appearance

**8.0 Agent decisions, not objected to:** money renders as `150 000 so'm` / `150 000 сум` by language; phones as `+998 90 123 45 67`; times in Asia/Tashkent.

**8.1 Uzbek is written in Latin script (option A).** One Uzbek variant in the catalog and the interface.

**8.2 Language is switchable in the app, defaulting to the device language (option A).** Uzbek when the device is Uzbek, Russian when Russian, otherwise Uzbek. The choice is stored on the device and reported to the server for push texts.

**8.3 No brand assets exist (option Б).** The client ships a neutral design: text logo "BarakaBozor", the green palette already in the scaffold, standard Material 3 components, with colours and logo replaceable in one place.

## Topic 9. Operator and Admin board, figures

**9.0 Agent decisions, not objected to:** orders carry a short human number (for example `1042`) shown to Customer, Shopper and Courier; every business setting (markup, service fee, delivery fee, minimum order, price tolerance, working hours, service area, delay threshold) is edited by Admin on one settings screen. *Correction under `DL-7`: the sentence as first presented also listed test phone numbers here; they are server configuration per 7.2, never an Admin setting.*

**9.1 Operators do not create orders on behalf of Customers (option A).** Orders come only from the Customer app in the MVP.

**9.2 The Admin board carries a summary strip (option Б).** Today's orders by status, today's sales total, and the count of orders needing attention, computed from the same order data. Manager KPI screens remain deferred.

## Topic 10. External services, hosting, launch

**10.1 Login codes go through Telegram Gateway first, SMS through Eskiz later as the fallback (option Б).** Both sit behind the same code-delivery abstraction; the request response tells the client which channel carried the code. Telegram Gateway needs no legal entity, so a pilot with real Customers is possible before it exists. Eskiz is added when the legal entity and contract exist, for Customers without Telegram.

**10.2 The backend runs at a hosting provider in Uzbekistan (option A).** One Ubuntu VPS with Docker for the pilot; the Owner picks the provider. Deployment is written for any Ubuntu server so the provider can change.

**10.3 A personal Google Play developer account now, closed testing from the first usable builds (option A).** Twelve testers for fourteen days unlocks production before the pilot. Firebase project on the Owner's Google account. Apple and iOS after the legal entity and a Mac.

**10.4 Cash-first pilot (option Б).** Order of work: foundation, catalog and accounts, cart and order on cash, shopping and delivery, pilot readiness with real push and Telegram login, then online payment providers last. No target date was given.

## What the Owner did not answer

- Starting catalog size (2.4): assumed under 300 products.
- Target pilot date (10.4): none given; planning proceeds by dependency order.
