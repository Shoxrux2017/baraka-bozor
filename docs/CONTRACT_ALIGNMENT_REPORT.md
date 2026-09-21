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

## External Integration Gates

Not unresolved business-contract defects: concrete SMS vendor, Flutter map/tile provider, Firebase credentials, official Payme/Paynet/xazna/Click merchant protocols/credentials. These are provider implementation gates. The implementing agent must not invent them; missing material causes `BLOCKED`.

Since `AUD-022` these gates carry two further facts. Published protocol documentation and credentials are separate: the former permits a thin adapter, the latter remains mandatory for verification and Wave 5 closure. And some gates require a registered legal entity — the SMS contract with its alpha-name, and every merchant agreement — which does not yet exist, so they are Wave 5. Provider selection, the map/tile package and the Firebase project do not require one. The full table is in `tasks/README.md` Section 16.

## Result

All product/architecture/database/client-API decisions needed to materialize the locked Stage 0 specification are synchronized. Provider-specific raw protocols remain intentionally outside generic BarakaBozor API until official provider material exists.
