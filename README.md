# BarakaBozor

BarakaBozor is an MVP grocery-market purchasing and delivery service built around the locked business model:

```text
ONLINE BOZORLIK
+ XARIDCHI XODIM
+ ONLINE TO'LOV
+ YETKAZIB BERISH
```

The Customer orders products and exact quantities from BarakaBozor. The Customer does not choose a market or market seller. Company staff purchases the goods at one wholesale market, the system controls pricing/payment, and a Courier delivers the completed order.

## MVP specification

The product and technical specification is locked in:

```text
docs/
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

`docs/FINAL_AUDIT_REPORT.md` records the final cross-document PASS.

## Engineering model

The project follows the same controlled implementation model used in TestLabUz:

```text
ChatGPT       = requirements, architecture, task design, review, Stage closure
Codex         = approved implementation contract + focused verification
Project Owner = routine Git/GitHub delivery, checkpoint execution, real-stack smoke
CI            = checkpoint/integration execution when configured
```

Codex implements one approved task at a time. It does not redesign product behavior, API, database, security, lifecycle, money rules, concurrency, or UX.

## Technical baseline

```text
Backend:  Laravel 13 / PHP 8.3+ / PostgreSQL / Sanctum
Frontend: Flutter / Riverpod / GoRouter / Dio / secure storage
API:      REST JSON under /api/v1
```

The backend is authoritative for role, access, Order lifecycle, prices, quantities, approvals, payments, refunds, fees, Shopper/Courier assignment, and delivery state.

## Repository structure

```text
baraka-bozor/
  AGENTS.md
  docs/
  tasks/
  backend/
  frontend/
```

Laravel and Flutter production scaffolds are intentionally not created in Stage 0. They are introduced through approved Stage 1 tasks.

## Current Stage status

- Locked `docs/01–09`: PASS.
- Engineering workflow: prepared.
- Repository foundation: prepared locally.
- GitHub baseline delivery: pending an empty GitHub repository and writable GitHub connection.
- Stage 1 implementation must not begin until Stage 0 Closure Review passes on real `origin/main`.
