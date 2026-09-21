# BarakaBozor — Open Specification Decisions

## Purpose

The locked `docs/01–09` passed cross-document audit on 2026-09-07. A second read on 2026-09-21 found questions the specification does not answer, or answers in two incompatible ways. None of them contradicts the business model; each is a decision that has not been made yet.

This file is the register. Each entry is resolved with the Project Owner **at its Stage planning gate, before the first task that depends on it**. Meeting one of these mid-implementation is a stop-and-ask condition, not a judgement call.

Resolving an entry means: decide, update every affected locked document, append an `AUD-` entry to `docs/CONTRACT_ALIGNMENT_REPORT.md`, then mark the row `Resolved` here with the date.

Status values: `Open`, `Resolved`, `Withdrawn`.

## Group A — Stage 1

These block tasks already in the approved Stage 1 index.

| ID | Status | Blocks | Question |
|---|---|---|---|
| S-1 | Open | `S01-BE-002` | **Role immutability versus unique phone.** `02` §3 and `BR-ROLE-002` say a role change means blocking the old account and creating a new one. `08` §3 makes `phone` plainly unique, and the same person keeps the same phone, so the second account cannot exist. Options: partial unique index over active accounts, with login resolving the active row; a phone-release rule applied on block; or accept that a role change requires a different phone. Affects `02`, `05`, `08`. |
| S-2 | Open | `S01-FE-001` | **What "Desktop" means.** `02` §10 gives Operator, Admin and Manager a Desktop surface. No document says whether that is Flutter Web or a native desktop build. This decides the build targets, the Phase 2 "required target build", CORS configuration, and whether Sanctum runs in bearer-token or SPA-cookie mode. The mobile platform set needs the same answer; note that iOS release builds require macOS. Affects `02`, `07`, and the Stage 1 index. |
| S-3 | Open | `S01-FE-003`, `S01-FE-004` | **Locale and message language.** `frontend/AGENTS.md` §8 separates machine values from localized labels, and API `message` is human-readable, but no document fixes the MVP language set (uz / ru / en), `Accept-Language` handling, or which language backend messages use. Affects `07`, `09`. |
| S-4 | Open | `S01-BE-003` | **Staff login hardening and token lifetime.** `09` §6 fixes the OTP policy precisely. `09` §8 staff login has no rate limit and no lockout. Sanctum token expiry, maximum tokens per user, and the mechanics of revoking tokens when an account is blocked (`02` §12) are unspecified. Affects `07` §8, `09` §8–§11. |
| S-5 | Open | `S01-BE-004` | **OTP verify "ensures one active Cart".** `04` §2 step 7 and `09` §7 make Cart creation part of verify, but Cart is a Stage 3 table, so the Stage 1 task cannot do it. Decide whether Stage 1 omits the step and Stage 3 retrofits it, or whether Carts are instead created lazily on first Cart access. Affects `04`, `09`, and the Stage 1 acceptance map. |

## Group B — Later Stages

Not urgent. Each is listed against the Stage whose planning gate must resolve it.

| ID | Status | Stage | Question |
|---|---|---|---|
| S-6 | Open | 5–6 | **Is `approval_required` stored or derived?** `07` §15 and `BR-ORDER-004` call it a projection; `08` §13 stores the canonical states in `orders.status`, and that list includes it. Undefined: whether `order_status_history` records `shopping → approval_required → shopping`, and what happens when one of two pending approvals resolves. |
| S-7 | Open | 6 | **Item state after an approval is granted.** Does the Item return to `pending` so the Shopper can record the purchase, or go straight to `purchased`? `04` §16 says approval "changes billable quantity only", yet purchased quantity and price still have to be recorded afterwards. |
| S-8 | Open | 11 | **`staff-activity` KPI has no definition.** `09` §50 exposes the endpoint. `05` §20 and `01` §19 never say what it counts, although the final audit claims all KPI definitions are fixed. |
| S-9 | Open | 4–6 | **Enum-like columns with no vocabulary.** `substitution_resolution`, `removed_reason_code`, `order_status_history.reason_code`, assignment `ended_reason`, and refund `reason_code` have no allowed values. Separately, "compatible unit semantics" for a replacement (`01` §10, `03` §13) is never defined; identical `unit_code` is the obvious reading but is not stated. |
| S-10 | Open | 7 | **"Unknown" payment outcome has no persisted form.** `payment_outcome_unknown` and the reconciliation rules treat it as a real state, but `payment_attempts.status` allows only `pending`, `successful`, `failed`, `cancelled`. Either define the derivation (pending plus age, or `last_reconciled_at`) or add a state. |
| S-11 | Open | 4 | **`IdempotencyStore` crash recovery.** A retry arriving while a row is stuck in `processing` could conflict, wait, or resume. `07` §17 and `08` §28 do not say which, and a crashed request leaves exactly that row. |
| S-12 | Open | 10 | **When `order_accepted` fires.** At Order creation, at successful checkout payment, or at Shopper assignment? `01` §17, `03` §22 and `05` §18 name the event but never the moment. |
| S-13 | Open | 9 | **Price correction must mutate an unpaid obligation.** An Admin correction before the final payment lock (`BR-PRICE-006`, `09` §47) changes `final_total_uzs`, so an unpaid `final` or `additional` payment's `amount_uzs` must change with it. No document specifies mutating a payment obligation. |
| S-14 | Open | 3 | **Cart status `abandoned` is never produced.** `08` §9 defines it; no rule in `03`, `04` or `05` creates it. Either define the transition or drop the value. |
| S-15 | Open | 2 | **Product image delivery to the client.** `07` §10 covers storage. How Flutter fetches the bytes (public disk URL, signed URL, or an API endpoint) is unspecified, and it affects whether images are protected. |
| S-16 | Open | 1 | **Machine codes missing for `400`, `502` and `503`.** `09` §3 assigns HTTP `400` to a malformed protocol request and `502`/`503` to an external provider problem, but §54–§59 define no stable `code` for any of them, so a client cannot branch on them. `AUD-019` closed the same gap for `500` only. `400` becomes reachable with the first real request body; `502`/`503` with the first provider call. **Blocks `S01-BE-003`**, the first task to add a real endpoint. Until it is resolved, `S01-BE-001` renders any unmapped client error as a scope-safe `404 resource_not_found` and any unmapped server error with `server_error`. |
| S-17 | Open | 2 | **`request_id` is in the locked envelope but nothing emits it.** `09` Section 3 defines the error envelope as four keys including `request_id`. `S01-BE-001` emits the other three; adding the fourth needs a correlation-ID source, and no document says where one comes from or whether it is required. Decide before clients start reporting errors by reference. |

## Change Log

| Date | Change |
|---|---|
| 2026-09-21 | Register created from the repository review. S-1 to S-15 opened. |
| 2026-09-21 | S-16 opened during independent review of the workflow change. |
| 2026-09-21 | S-16 raised to Stage 1 and made a blocker for `S01-BE-003`; S-17 opened during independent review of `S01-BE-001`. |
