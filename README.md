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
                     real-stack execution, manual smoke, Wave closure
CI                 = checkpoint/integration execution when configured
```

Work runs in waves. Inside a wave several tracks run concurrently, each as its own implementing agent in its own git worktree, and each holding **one approved task at a time**. Track count is bounded by the wave's declared width in `tasks/WAVE_<N>_TASK_INDEX.md`, and the paths each track may touch are fixed in `tasks/OWNERSHIP.md`.

The implementing agent does not decide product behavior, API semantics, database contracts, security or lifecycle rules, money rules, concurrency policy, cross-feature architecture, dependency strategy, or UX. Those belong to the Project Owner, and so does every change to the locked specification.

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

The Laravel scaffold arrived through the first approved Wave 0 task. The Flutter scaffold is introduced through a later Wave 0 task.

## Current status

- Locked `docs/01–09`: PASS.
- Stage 0: CLOSED. Baseline delivered to `origin/main`.
- Execution model: six waves with concurrent tracks, approved 2026-09-21. Recorded in `docs/06-roadmap.md` Sections 1–2 and in `docs/superpowers/specs/2026-09-21-parallel-execution-model-design.md`.
- Wave 0 (Foundation): in progress. `S01-BE-001` Laravel API foundation is Accepted; the PostgreSQL runtime, required CI, module registries and auth core follow.
- Open specification questions are tracked in `docs/SPEC_DECISIONS_BACKLOG.md`, grouped by the wave that must resolve them.
- External gates: a real SMS path and merchant credentials are Wave 5 requirements and both depend on a registered legal entity, which does not yet exist. Waves 0–4 reach a demonstrable MVP without it, running behind a fake SMS gateway and a fake payment provider; push notifications reach a real Firebase integration in Wave 4, which needs no legal entity.
