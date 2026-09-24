# BarakaBozor — Roadmap

## Document Status

**Status:** current. Rewritten on 2026-09-24 to `DL-5` in `docs/DECISIONS.md` and topic 10 of `docs/INTERVIEW_2026-09-24.md`. The earlier stage and concurrent-track plans are history.

## 1. Principle

Build toward a **cash-first pilot** in the order below, one implementing agent, one wave at a time. A wave is planned in `tasks/WAVE_<N>.md`, built as a series of small pull requests, closed with the full suites, the real stack and the Owner's manual check.

## 2. Waves

| Wave | Name | Outcome | Owner gates |
|---:|---|---|---|
| 0 | Foundation | runtime, CI, identity, staff login, Customer login through the code-delivery abstraction (fake now, test numbers), authorization, client auth screens and role shells, web target | none |
| 1 | Catalog and account | Admin catalog in the web panel, Customer catalog and search, profile and language, addresses with the Yandex map picker and service-area check, staff management, business settings, push device registration | Yandex MapKit key |
| 2 | Cart and order on cash | cart, checkout with cash (online shown as unavailable), order creation, editing and direct cancellation, Shopper and Courier assignment, the Admin and Operator board with the summary strip | none |
| 3 | Fulfilment | shopping with fixed and estimate items, unavailability, substitution, approvals with timers, Operator attention, Courier delivery with cash collection and not-delivered, cancellation requests | none |
| 4 | Pilot readiness | real FCM push and every notification event, history and reorder, Telegram Gateway login with the fixed-code test numbers kept, deployment to the Owner's VPS with backups, Android closed testing, web panel hosting, end-to-end check on cash, the pilot | Firebase, Telegram Gateway, hosting, Google Play |
| 5 | Online payment | Payme and Click adapters from published protocols, the online flow with its 30-minute window and the Operator switch, provider reconciliation, manual refund tracking, Eskiz SMS fallback | legal entity, merchant agreements, Eskiz contract |
| later | — | Manager figures, Paynet and xazna, automated refunds, iOS release, delivery zones and tariffs, spreadsheet import, chat | Apple, a Mac |

A wave may start before the previous one's Owner check when nothing in it depends on the check's outcome; fixes from the check are ordinary tasks.

## 3. What Each Wave Contains

### Wave 0 — Foundation

Done: Laravel scaffold and error envelope, Docker runtime with PostgreSQL 17, CI as a required check, module route and provider registries, `users` and login-challenge tables, first-Admin command, Flutter scaffold with the route registry, one Dio client and the token store.

Remaining: the error renderer's final codes and `request_id`; staff login, logout, me, change-password with rate limits and the sliding token; Customer login behind the code-delivery gateway with the fake and the test numbers; six-role authorization with scope-safe denial; the client's session foundation with two session slots, auth screens, role shells, surface screen, and the web build.

### Wave 1 — Catalog and account

Categories and products with bilingual fields, price mode, market price, images on public URLs; Customer catalog and search; profile and `preferred_language`; addresses with the map picker and the circle check; staff create, block, unblock, reset; business settings and provider enablement; push device registration.

### Wave 2 — Cart and order on cash

Cart; checkout preview with the minimum amount, working-hours note and the payment-method choice; order creation with snapshots and the order number; order editing before shopping; direct cancellation; assignment endpoints and history; the board with filters, the attention list skeleton and the summary strip.

### Wave 3 — Fulfilment

Shopper accept and start; purchase recording for fixed and estimate items with the tolerance check; unavailable, replacement, approvals with the 10 and 30 minute timers and the Operator's expired-resolution; complete shopping with the final amounts; Courier accept, start, delivered with cash, not delivered; delay attention; cancellation requests and decisions; the attention list complete.

### Wave 4 — Pilot readiness

Notification events and templates, FCM adapter, Shopper polling; history and reorder; Telegram Gateway adapter; production configuration, deployment scripts, backups, TLS; Android release build into closed testing; web panel hosting; the end-to-end scenario on the real stack; the Owner's pilot checklist.

### Wave 5 — Online payment

Payment obligations and attempts, provider event deduplication, reconciliation; Payme and Click adapters; the Customer's payment screen with pending, failed and unknown states; the Operator's switch to cash and the unpaid attention; manual refund tracking; Eskiz SMS adapter as the code-delivery fallback.

## 4. Definition of Done for a Wave

The wave's behaviour is implemented with tests; backend rules are enforced server-side; the client uses the real API; CI is green on `main`; the full backend and frontend suites pass; the required targets build; the end-to-end scenario of the wave runs on the real stack; `docs/01–09`, `docs/DECISIONS.md` and the wave file are current; the Owner has received the wave report and the manual-check checklist.

## 5. External Gates

| Gate | Wave | Who |
|---|---:|---|
| Yandex MapKit API key | 1 | Owner |
| Firebase project, Android app registration | 4 | Owner |
| Telegram Gateway account and funding | 4 | Owner |
| Hosting in Uzbekistan, domain, TLS | 4 | Owner |
| Google Play personal account, twelve closed testers | 4 | Owner |
| Legal entity | 5 | Owner |
| Payme and Click merchant agreements and credentials | 5 | Owner |
| Eskiz contract and sender name | 5 | Owner |
| Apple Developer Program, a Mac | later | Owner |

Published provider documentation is enough to write a thin adapter ahead of credentials; credentials are needed to verify it. Never invent a protocol; never present a fake provider result as real.

## 6. Post-MVP Boundary

Not pulled into any wave: `01` Section 20.
