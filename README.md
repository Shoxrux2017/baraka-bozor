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

The project is built by two parties under `AGENTS.md` and `tasks/README.md`:

```text
Implementing agent = requirements analysis, task contracts, implementation,
                     focused verification, branches and PRs;
                     obtains an independent review before every PR
Project Owner      = product decisions, approval, PR review and merge,
                     real-stack execution, manual smoke, Stage closure
CI                 = checkpoint/integration execution when configured
```

One approved task at a time. The implementing agent does not decide product behavior, API semantics, database contracts, security or lifecycle rules, money rules, concurrency policy, dependency strategy, or UX. Those belong to the Project Owner, and so does every change to the locked specification.

Because one agent both plans and implements, an independent reviewer with no implementation context reviews each diff before its pull request is opened.

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
- Stage 0: CLOSED. Baseline delivered to `origin/main`.
- Stage 1 (Authentication & Role-Based Entry): approved, implementation starting.
- Open specification questions are tracked in `docs/SPEC_DECISIONS_BACKLOG.md`.
- External gate: the SMS provider is still required before Stage 1 can close.
