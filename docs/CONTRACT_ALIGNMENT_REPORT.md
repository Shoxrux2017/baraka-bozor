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

## External Integration Gates

Not unresolved business-contract defects: concrete SMS vendor, Flutter map/tile provider, Firebase credentials, official Payme/Paynet/xazna/Click merchant protocols/credentials. These are provider implementation gates. Codex must not invent them; missing material causes `BLOCKED`.

## Result

All product/architecture/database/client-API decisions needed to materialize the locked Stage 0 specification are synchronized. Provider-specific raw protocols remain intentionally outside generic BarakaBozor API until official provider material exists.
