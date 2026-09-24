# BarakaBozor

BarakaBozor is a grocery-market purchasing and delivery service for one city in Uzbekistan:

```text
ONLINE BOZORLIK
+ XARIDCHI XODIM
+ YETKAZIB BERISH
+ NAQD YOKI ONLAYN TO'LOV
```

The Customer orders products and exact quantities in the app. The Customer does not choose a market or a seller. A company Shopper buys the goods at one wholesale market, a Courier delivers them, and the Customer pays after shopping, in cash to the Courier or online.

## Documents

```text
docs/
  INTERVIEW_2026-09-24.md   the Project Owner's product decisions
  DECISIONS.md              the decision log: what was decided and why
  01-business-overview.md
  02-user-roles.md
  03-features.md
  04-user-flows.md
  05-business-rules.md
  06-roadmap.md
  07-architecture.md
  08-database.md
  09-api-contracts.md
```

`01–09` describe the product and the technical design as they currently are and are kept current by the implementing agent. Frozen history of the earlier locked-specification period: `docs/CONTRACT_ALIGNMENT_REPORT.md`, `docs/SPEC_DECISIONS_BACKLOG.md`, `docs/FINAL_AUDIT_REPORT.md`.

## Engineering model

One implementing agent (Claude Code) plans, implements, tests, obtains an independent review, merges on a green CI run and reports once per wave. The Project Owner decides product questions the documents do not cover and checks the product in the app once per wave. Rules: `AGENTS.md`, `backend/AGENTS.md`, `frontend/AGENTS.md`; workflow: `tasks/README.md`.

## Technical baseline

```text
Backend:  Laravel 13 / PHP 8.4 / PostgreSQL 17 / Sanctum, in Docker
Frontend: Flutter / Riverpod / GoRouter / Dio — Android, iOS, web panel
API:      REST JSON under /api/v1
```

The backend is authoritative for identity, access, the order lifecycle, prices, quantities, approvals, payments, assignment and delivery state.

## Repository structure

```text
baraka-bozor/
  AGENTS.md
  docs/
  tasks/
  backend/     Laravel application; runs only inside docker/compose.yaml
  frontend/    Flutter application
  docker/      local development and test runtime
```

`docker/README.md` explains how to start the stack and run the backend checks.

## Status

Wave 0 (foundation) is in progress: the runtime, CI, the identity schema and the Flutter scaffold are merged; staff login, Customer login, authorization and the client's auth screens follow. The order of the remaining waves is in `docs/06-roadmap.md` Section 2 and `docs/DECISIONS.md` `DL-5`.
