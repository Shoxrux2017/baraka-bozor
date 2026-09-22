# BarakaBozor — Stage 0 Contract Alignment Report

## Status

**S00-DOC-010 — COMPLETE**

Date: 2026-09-07

## Scope

Aligned canonical final versions of `01–09` against source TZ v1.1 and approved Stage 0 decisions.

## Applied Audit Corrections

1. **AUD-001 Payment lifecycle** — replaced overloaded `awaiting_payment` with `checkout_payment_pending` and `final_payment_pending`.
2. **AUD-002 Approval timing** — +10m Operator attention while pending; +30m expired.
3. **AUD-003 Approval outcomes** — approve exact proposal; reject removes Item; expired gives no consent and fallback is remove-only.
4. **AUD-004 Fixed procurement price** — ordinary fixed Customer billing uses fixed snapshot; Shopper actual price not required.
5. **AUD-005 Money rounding** — Product line and percentage Service fee half-up to 1 UZS; merchandise sums rounded lines.
6. **AUD-006 Approval does not freeze unrelated Shopping** — other eligible Items continue; completion blocked.
7. **AUD-007 Customer name** — authentication may precede name; checkout requires non-empty full_name.
8. **AUD-008 Address completeness** — coordinates + street + house required; apartment/landmark/note optional.
9. **AUD-009 Shopper/Courier acceptance** — explicit accept before start; reassignment only before work start.
10. **AUD-010 Admin security** — role immutable; no self-block/last-active-Admin block; reset another Staff, self change-password.
11. **AUD-011 Cart conversion** — Order creation converts source Cart + creates new active Cart atomically.
12. **AUD-012 Reorder merge** — original Product/current Catalog; existing Cart duplicate skipped/reported.
13. **AUD-013 Dynamic estimate** — explicit `final|estimate_range|contains_unknown`; at_purchase never gets fake total.
14. **AUD-014 KPI definitions** — synchronized gross sales/service revenue/AOV/fulfilment period formulas.
15. **AUD-015 Popular Product** — rank by Completed-Order count; quantity separate by unit.
16. **AUD-016 Product image** — one current image, JPEG/PNG/WebP, <=5 MB.
17. **AUD-017 First Admin** — controlled one-time Laravel/Artisan bootstrap; no public API.
18. **AUD-018 Persisted idempotency** — `IdempotencyStore`, `idempotency_keys` table, one normative public `Idempotency-Key` contract for approved high-risk Flutter mutations.

## Post-Lock Amendments

Changes applied after the 2026-09-07 lock. Each required Project Owner approval.

19. **AUD-019 `server_error` code** (2026-09-21) — `09` Section 54 listed no stable machine code for HTTP `500`, while Section 3 required one for every error category. Added `server_error` with an empty `errors` object and an explicit no-sensitive-detail rule. No behavior outside the 500 envelope changed.
21. **AUD-021 Static analysis in the backend baseline** (2026-09-21) — `07` Section 2 listed only PHPUnit and Pint. Added Larastan (PHPStan) so the required static check named in root `AGENTS.md` Section 11 has a concrete tool. Project Owner approved the dependency. No product behavior changed.
20. **AUD-020 Party-neutral wording** (2026-09-21) — `07` Section 36 and `09` Section 61 addressed a named implementer. Reworded to "the implementing agent". Pure rename; the provider-gate rules are unchanged.
22. **AUD-022 Wave execution model** (2026-09-21) — `06` Section 1 required strictly serial stages, each built backend-first, although `08` and `09` already fix the schema and the API contract for the whole MVP. Execution moved to six waves, each running up to five concurrent tracks. Project Owner approved the model and its two cross-feature architecture decisions: `D-8` per-module route registries, `D-9` a shared API fixture directory asserted from both the backend and the frontend side.

    Changed: `06` Sections 1, 2, 4, 10, 16, 17, 18 — wave graph, stage-to-wave map, the Wave 5 relocation of the SMS closure gate, separation of published protocol documentation from credentials, Definition of Done unit. `07` Sections 1, 3, 11, 23, 33, 36 — repository baseline, route registries, worktree layout, map-provider gate wave, OTP emission, shared fixtures, provider gates. `AGENTS.md` Sections 2, 8, 11, 13 and `README.md` — concurrent tracks, the two permitted non-speculative exceptions, wave checkpoints, an absolute force-push prohibition with forward-merge as the update path. `tasks/README.md` — Workflow v5, wave directories and IDs, wave planning with frozen decisions, worktree preflight, merge queue, wave Phase 2 and closure verdicts, the provider-gate table with its legal-entity column. New: `tasks/WAVE_00_TASK_INDEX.md`, `tasks/OWNERSHIP.md`. `tasks/STAGE_01_TASK_INDEX.md` marked superseded and frozen. `SPEC_DECISIONS_BACKLOG.md` regrouped by wave.

    Not changed: `01`, `02`, `03`, `04`, `05`, `08`, `09`. No product behavior, public API semantics, database contract, lifecycle rule, role or ownership rule, money or rounding rule, concurrency or idempotency policy. `AGENTS.md` Sections 6 and 7 are untouched, and `07` Section 23 was **tightened**: OTP values may not be emitted to a client, log or header in any environment, with no development carve-out. Severity definitions and the evidence-validity rules in `tasks/README.md` Sections 12–13 are unchanged in substance.

    Rationale, what the model deliberately keeps serial, and its risks: `docs/superpowers/specs/2026-09-21-parallel-execution-model-design.md`.

23. **AUD-023 Phone uniqueness and the Desktop surface** (2026-09-21) — closed `S-1` and `S-2` from `SPEC_DECISIONS_BACKLOG.md`. Project Owner decided both.

    **`S-1`.** `02` Section 3 required a role change to block the old account and create a new one, while `08` Section 3 made `phone` plainly unique and the person keeps the same number — so the new account could not exist.

    Changed: `08` Section 3 replaces plain uniqueness with **two** partial unique indexes, one per account family — `(phone) WHERE status = 'active' AND role = 'customer'` and `(phone) WHERE status = 'active' AND role <> 'customer'` — so the invariant is at most one active Customer account and at most one active Staff account per phone. The Project Owner decided that one person may hold both, so a company employee can order as a Customer; the families never collide because Staff authenticate with a password and Customers with an OTP, on separate endpoints. `08` Section 3 also records that the API still validates the phone so a duplicate returns `422 validation_failed` rather than a constraint violation. `08` Section 31's enforcement checklist follows, naming both indexes. `02` Section 3 states the new account reuses the same phone; `02` Section 12 forbids unblocking while another active account **of the same family** holds it and notes that the obvious remedy is unavailable when the conflicting account is the last active Admin. `05` gains `BR-ROLE-010`, which states the per-family invariant, that staff login resolves the active Staff account and Customer OTP verify the active Customer account, and that an unblock is refused only by another active account of the same family. `BR-ROLE-002` cites `08` Section 3. `04` Section 31's Admin-creates-Staff flow now validates against active **Staff** accounts only, and records that an active Customer account on the phone is not a conflict. `09` Section 8 states that staff login targets the active **Staff** account, and that neither a blocked Staff account nor an active Customer account on the same phone is the login target. `09` Section 7 records that Customer OTP verify resolves or creates the Customer account and never a Staff one, so no OTP path can issue a Staff session — `02` Section 13 invariant 1. `09` Section 44 gives Staff creation a `422 validation_failed` on a phone held by an active Staff account, and `activate` a `409 phone_already_active` when an unblock would break the invariant; Section 59 adds that code.

    Two alternatives rejected: releasing the phone on block destroys historical data, which root `AGENTS.md` Section 7 forbids; requiring a different phone would make a promotion depend on the person obtaining a second number.

    **Changed, by category.** A **database/schema contract**: plain uniqueness becomes two partial unique indexes. A **lifecycle rule**: unblocking is now refusable, as `409 phone_already_active`, which the Project Owner assigned. **Account existence**: one phone may now carry two active accounts in different families, which no previous text allowed.

    **Not changed**: no money, quantity or rounding rule; no Order, Approval, Payment, Refund or Delivery lifecycle state; no concurrency, idempotency or replay policy; no role capability, ownership or assignment scope; no existence-privacy behavior — both new refusals sit on Admin-only surfaces and neither can be used to probe Customer existence, because an active Customer account is explicitly not a conflict.

    **Evidence validity** per `tasks/README.md` Section 13: nothing is invalidated. There is no `users` migration, no authentication endpoint and no fixture in `tests/fixtures/api/` yet, so no existing PASS evidence covers the changed surface.

    **Three consequences were not foreseen when the decision was taken** and are opened as backlog rows rather than decided here: `S-18`, whether a Shopper or Courier may be assigned to an Order placed by a Customer account sharing their phone, which otherwise lets one human self-grant financial consent; `S-19`, what Customer OTP verify does when the only Customer account for a phone is blocked; and `S-20`, what `activate` returns on a write-time index rejection or two racing activations.

    **`S-2`.** `02` Section 10 gave Operator, Admin and Manager a "Desktop" surface without saying whether that meant a browser or an installed application, leaving build targets, CORS and the Sanctum mode undefined.

    Changed: `02` Section 10 defines Desktop as an installed Windows application and records that mobile means Android and iOS from one codebase. `07` Section 2 fixes the target set as Android, iOS and Windows with no web target. `07` Section 8 records that bearer-token mode applies on every surface, with no SPA-cookie mode and no CSRF surface. Android and Windows are required release targets from Wave 0; an iOS release build becomes required in Wave 5, because it needs macOS and an Apple Developer Program membership. iOS code is written from the start, so nothing is rewritten later.

    Deciding against a browser surface preserves the platform-secured token storage `07` Section 8 already required, which no browser provides, and removes CORS from the MVP entirely.

    Not changed by this half: no product behavior, money or quantity rule, rounding rule, lifecycle rule, concurrency or idempotency policy, and no API semantic. `backend/config/sanctum.php` still carries Laravel's default stateful-domain block, now inert; pruning it is a follow-up outside this amendment.

    **Bookkeeping.** `tasks/WAVE_00_TASK_INDEX.md` records both resolutions: `W0-BE-011` is no longer blocked by a decision, and `S01-FE-001` drops `S-2` and remains blocked on the absent Flutter SDK. Document status lines stamped on `02`, `04`, `05`, `07`, `08`, `09`.

## External Integration Gates

Not unresolved business-contract defects: concrete SMS vendor, Flutter map/tile provider, Firebase credentials, official Payme/Paynet/xazna/Click merchant protocols/credentials. These are provider implementation gates. The implementing agent must not invent them; missing material causes `BLOCKED`.

Since `AUD-022` these gates carry two further facts. Published protocol documentation and credentials are separate: the former permits a thin adapter, the latter remains mandatory for verification and Wave 5 closure. And some gates require a registered legal entity — the SMS contract with its alpha-name, and every merchant agreement — which does not yet exist, so they are Wave 5. Provider selection, the map/tile package and the Firebase project do not require one. The full table is in `tasks/README.md` Section 16.

## Result

All product/architecture/database/client-API decisions needed to materialize the locked Stage 0 specification are synchronized. Provider-specific raw protocols remain intentionally outside generic BarakaBozor API until official provider material exists.
