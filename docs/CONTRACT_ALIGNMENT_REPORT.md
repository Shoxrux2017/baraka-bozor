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

24. **AUD-024 Wave 0 specification decisions** (2026-09-22) — closed `S-3`, `S-4`, `S-5`, `S-16`, `S-17` and `S-19`. Project Owner decided all six. Wave 0 now has no open specification decision.

    **`S-16` — machine codes for 400, 502, 503.** `09` §3 assigned those statuses a meaning while §54 defined no `code` for any of them, so a client could not tell its own bug from a provider outage, and the implementation rendered any unmapped client error as a scope-safe `404 resource_not_found` — masking client bugs as "not found". Added `malformed_request` for `400`, and `provider_unavailable` for **both** `502` and `503`, since the client behaves identically for either and a second code would add a branch nobody takes. Recorded that `provider_unavailable`'s `message` must not carry the provider's own error text, which can contain endpoint names, merchant identifiers or raw payloads that root `AGENTS.md` §6 forbids exposing. Changed: `09` §54.

    **`S-17` — `request_id`.** The envelope declared it and nothing emitted it. The backend now generates one per request, writes it to that request's log entries, and returns it in **error responses only**, matching §3's description of an error envelope. No HTTP header, no change to successful responses, nothing for the client to send. Changed: `09` §3.

    **`S-5` — the Cart at OTP verify.** `04` §2 step 7 and `09` §7 required verify to create a Cart, but the Cart is a Wave 2 table, so a Wave 0 task could not. The Cart is now created **lazily on first Cart access**: one place owns the one-active-Cart rule in `08` §9, Wave 0 has nothing to retrofit, and Wave 2 does not return to change an accepted login endpoint. **This removes a step from an already-specified flow** rather than only clarifying one. Nothing depends on it yet — no Cart table, no Cart endpoint, no test — so no PASS evidence is invalidated. Changed: `04` §2, `09` §7.

    **`S-19` — a blocked Customer at OTP verify.** `09` §7 said verify "creates Customer if absent", and after `AUD-023` the active-Customer index permits a blocked row beside an active one, so the text allowed creating a new active account and thereby **escaping a block with one SMS**. Verify now resolves only the active Customer account, creates one only when none is active, and returns `account_blocked` otherwise. The OTP request in §6 is deliberately unchanged: it still sends the SMS, because §6 promises not to disclose account existence and the refusal belongs at verify. The alternative leaks account status to anyone who can type a phone number. The cost is not one SMS: §6 permits five sends per phone per hour indefinitely and the block does not stop them, which the record now states. The review also found the check order unstated — an implementer reading `account_blocked` as a pre-check would have turned it into an account-status oracle for anyone able to type a phone number, the exact disclosure this reasoning rules out. `09` §7 now fixes the order explicitly. Changed: `09` §7. Note the MVP exposes no endpoint that blocks a Customer, so the case is unreachable today — the ambiguity is closed before it can be reached rather than after. Changed: `04` §2 as well.

    **`S-4` — staff login hardening and token lifetime.** `09` §6 fixed the OTP policy to the digit while §8 had no rate limit, no lockout, no token expiry and no revocation mechanics. Resolved as: **5 failed attempts per phone per minute and 20 per IP per minute**, both `429 rate_limited`, a successful login clearing the phone counter; **no account lockout**; **a sliding 30-day token lifetime** measured from last use; **unlimited concurrent tokens** per Staff member; and **two independent revocation barriers** on blocking — delete every token *and* re-check account status on each request — with `401 account_blocked` for a valid token on a blocked account.

    Two of those are security judgements worth recording rather than just stating. A lockout was rejected because it would let anyone who knows an Admin's phone number disable that Admin, routing around the protection `BR-ROLE-008` gives the last active Admin — a weapon rather than a defence. Both rate limits are required together: per-phone alone lets an attacker walk a list of phones, per-IP alone lets one office lock itself out. Changed: `09` §8, `07` §8.

    **`S-3` — locale and message language.** No locked document had said anything about languages. Resolved as **Uzbek and Russian** for the client, with the API `message` a **developer-facing English string the user never sees**. Two rules already locked made this the coherent choice — `09` §3's "Flutter branches on `code`, not message text" and `frontend/AGENTS.md` §8's "never use translated UI text as a control value" — and it has a large consequence: **the backend performs no locale negotiation at all.** No `Accept-Language`, no server-side translation files, no tests for them. That whole layer never comes into existence, and `07` §30 now says so explicitly so nobody adds it out of habit.

    It follows that **a value a message would need travels as data, not inside prose**: an error about a minimum order amount carries the amount as a field. Otherwise the client is permanently tied to server-side text in exactly the places that matter most, money and quantities. Recorded in `09` §3 as a rule rather than repeated per endpoint.

    Catalog names and descriptions become **bilingual** — `08` §6 and §7 gain `name_uz`, `name_ru`, `description_uz?`, `description_ru?`, and both name columns are indexed in **both** §6 and §7, because a single-language index would make Customer search miss a Product in the other language. The first pass rewrote §6's index clause and left §7 naming `lower(name)`, a column the same diff deleted — so Products, which is what Customer search actually searches, had the defect the rationale describes. Found by the independent review and fixed. Changed: `07` §27 and §30, `08` §6 and §7, `03` §5 and §8.

    **Two corrections the independent review forced here.** First, the amendment originally cited `02` §10 as fixing both MVP languages. It does not: §10 is Device Surfaces and says nothing about language, and no locked document fixed a language set before this entry. `AUD-024` is the first, and `08` now cites `07` §27 instead. Second, **the paired-column representation is a choice this amendment made without authority.** The Project Owner decided the catalog is bilingual; two columns per field rather than a JSONB map or a `translations` table is a database/schema contract reserved by root `AGENTS.md` §3, and it decides whether a third language is later a migration of every catalog table and index. It stands in `08` pending sign-off and is tracked as `S-25`.

    **Changed, by category.** A **database/schema contract**: the catalog gains per-language columns. **API semantics**: two new error codes, `request_id` now emitted, `account_blocked` added to OTP verify, a rate limit and a token lifetime where there were none. **A flow**: `04` §2 loses its Cart step. No money, quantity or rounding rule; no Order, Approval, Payment, Refund or Delivery lifecycle state; no concurrency, idempotency or replay policy; no role capability, ownership or assignment scope.

    **Evidence validity** per `tasks/README.md` §13. There is no `users` or catalog migration, no authentication endpoint, no Cart and no API fixture yet, so nothing on those surfaces is affected. **But `S-16` and `S-17` do invalidate accepted evidence, which this entry first recorded incorrectly as "nothing is invalidated".** `S01-BE-001` is Accepted (PR #2) and its suite asserts the behaviour these decisions replace, in five places:

    - `backend/tests/Unit/Exceptions/ApiExceptionRendererTest.php:32` — unmapped `400` becomes `404 resource_not_found`, which `malformed_request` replaces;
    - the same file `:35` and `:36` — unmapped `502` and `503` carry `server_error`, which `provider_unavailable` replaces;
    - `backend/tests/Feature/Api/V1/ApiFoundationTest.php:136` — `503` responds `server_error`;
    - `backend/tests/Feature/Api/V1/ApiFoundationTest.php:170` — asserts the error body has exactly `message`, `code`, `errors`, so it asserts `request_id` is **absent**, which `S-17` now requires present.

    Under `tasks/README.md` §13 a public-API change normally invalidates the corresponding surface, and two of these six decisions are error-contract changes reaching a merged accepted one. The minimum rerun is those two test classes, after `S01-BE-003` and `W0-BE-012` bring the renderer into conformance; the Project Owner decides whether more is warranted. The implementation the decisions reach is `backend/app/Exceptions/ApiExceptionRenderer.php`, and its interim rule survives in part: `S-16` replaces it for `400`, `502` and `503` only, while `405` and `409` continue to fold to a scope-safe `404` because `CODE_BY_STATUS` still lacks `409`, for which `business_conflict` already exists in §54. That remainder, and the now-false `S-16` comment in the renderer, are tracked as a Wave 0 risk row.

    **Existence privacy is preserved, not changed.** `S-19` engages it most directly: `09` §6 still does not disclose whether an account exists, and `account_blocked` is reachable only with possession of the OTP. No scope-safe not-found behaviour is weakened anywhere.

    **Bookkeeping.** Status lines stamped on `03`, `04`, `07`, `08` and `09`. `02`, `05` and `06` are unchanged and unstamped. `tasks/WAVE_00_TASK_INDEX.md` records the entry gate, drops the resolved decisions from seven task rows, closes six risk rows and adds two, and adds the sections these decisions landed in to its planning inputs. `docs/SPEC_DECISIONS_BACKLOG.md` marks six rows Resolved and opens eleven.

    **Four questions the bilingual choice raises are opened rather than guessed**: `S-21` whether both languages are required, `S-22` what a Customer sees when theirs is empty, `S-23` whether search matches across both, and `S-24` which name enters the historical Order snapshot. The first three are Wave 1; `S-24` is Wave 2 and matters most, because the snapshot columns — `order_items.product_name_snapshot` and `order_items.fulfilled_product_name_snapshot` in `08` §14, and `customer_approvals.replacement_name_snapshot` in `08` §17, under the boundary `07` §13 states — must keep historical Orders stable, and a wrong choice there is not cheaply reversible once Orders exist. An earlier draft of this entry cited `08` §13, which is `orders` and holds no product name.

    **Independent review.** One reviewer, holding no implementation context, reviewed the amendment against the resolution procedure. No `P1`. Ten `P2` and eighteen `P3` findings; all were verified against the documents before action, and all were accepted — none was found wrong.

    Seven `P2` findings are fixed in this entry and the documents it amends: the `products` index naming a deleted column, the false `02` §10 citation, this entry's incorrect evidence-validity conclusion, `07` §30's "returns one language" contradicting the bilingual catalog it shipped beside, the unstated OTP check order, the unrecorded no-lockout residual, and the `provider_unavailable` / `payment_provider_unavailable` collision. The other three are **not** fixed by edit, because each is a decision reserved to the Project Owner that the amendment either made or left unasked: the catalog storage shape (`S-25`), the Catalog API shape (`S-26`), and the language-selection mechanism (`S-27`, whose unauthorised assertion "switchable by the user" is withdrawn from `07` §27).

    The `P3` findings are resolved in place, except three left deliberately: `docs/SPEC_DECISIONS_BACKLOG.md` has pre-existing blank lines inside two wave tables, which this branch did not worsen and does not own; the stale `S-16` comment in `ApiExceptionRenderer.php` is a backend file outside a documentation change and is tracked as a Wave 0 risk row; and no acceptance criterion is added for the `S-19` refusal, because the MVP exposes no endpoint that blocks a Customer, so no criterion is verifiable yet — the negative test belongs to `S01-BE-004`.

    **This entry reopened Wave 0.** `S-28` — whether the new rate limit extends to `/auth/change-password` — blocks `S01-BE-004`, so the statement that Wave 0 held no open specification decision was true only until the review read the amendment.

25. **AUD-025 `S-28` change-password rate limit** (2026-09-22) — Project Owner decided, twice: once on the rule and again on how it is counted, after the independent review found the first answer created a lockout.

    **The gap.** `S-4`'s declared scope in the register was "`07` §8, `09` §8–§11", and `AUD-024` amended only `09` §8 and `07` §8. So §10 `change-password`, which also verifies a password and had no limit, was an approved scope left incomplete rather than a question nobody asked. The review of `AUD-024` found it; it was opened as `S-28`.

    **Resolved as: 5 failed `current_password` checks per bearer token per minute, `429 rate_limited`.** Same threshold and same code as §8. `new_password` is validated first, so a rejected `new_password` never reaches the `current_password` check and never consumes the counter. A successful change clears that token's counter.

    **Why the limit is needed at all, and why not on §8's reasoning.** A stolen token grants access, not the password. Unlimited attempts let its holder convert temporary access into the credential itself — usable elsewhere, and surviving the token revocation that blocking performs. `09` §10 constrains only length, 10–128, with no complexity rule, which makes the unbounded case worse rather than better.

    **The first answer was per account, and it was wrong.** The independent review graded it `P1` and every link was verified before acting. Keyed to the account, the holder of a stolen token keeps the counter saturated and the legitimate owner can never change their password — the one action that removes the attacker's access. The contract offers no escape: §11 logout revokes only the caller's own token; all tokens are deleted only on blocking (`07` §8), which `BR-ROLE-008` forbids for the last active Admin; an Admin reset sets the gate and routes the victim back to this endpoint (§44); and under the gate only `/auth/me`, `/auth/change-password` and `/auth/logout` are reachable. **For the last active Admin that is a permanent lockout with no remedy** — structurally the weapon `AUD-024` rejected when it refused account lockout, with "holds a token" replacing "knows the phone". Recorded in full rather than repaired quietly, because the first draft of this entry stated there was no residual to record.

    **Keying to the token costs no protection**, which is why it is the fix rather than a compromise. A token is issued only by staff login, which requires the password being guessed, so an attacker cannot widen their budget; one stolen token gets five failures a minute either way. Residual accepted: several stolen tokens for one account get five a minute each. That presupposes a larger breach than this limit addresses, and the per-account key that would cap it is what creates the lockout.

    **No per-IP limit here.** §8 needs one because an unauthenticated caller can walk a list of phones; this endpoint requires a valid token. An attacker holding tokens for many accounts is the analogous case, and a per-IP limit **would** cap it — an earlier draft of this entry claimed such a limit "bounds nothing extra", which was false by §8's own reasoning. It is judged not worth a second counter, because it presupposes mass token theft and because a per-IP counter here would inherit the shared-address residual §8 records.

    **Codes for §10 are still unspecified and were not invented here.** §6, §7 and §8 each carry a `Codes:` line; §10 never has. The new rule names outcomes — a failed `current_password` check versus a rejected `new_password` — that the contract assigns no code to. `invalid_credentials` by analogy with §8 is the obvious reading, and this amendment treats an obvious reading as not a decision. `S01-BE-003`'s contract must settle it or raise it; tracked as a Wave 0 risk.

    **Changed, by category.** **API semantics**: one endpoint gains a rate limit, an existing error code, and a stated validation order. No new error code was needed — `rate_limited` is already in §54 — though a per-token counter is new code to write. No database or schema contract; no money, quantity or rounding rule; no Order, Approval, Payment, Refund or Delivery lifecycle state; no concurrency, idempotency or replay policy; no role capability, ownership, assignment or existence-privacy rule.

    **Evidence validity** per `tasks/README.md` §13: nothing is invalidated. `/auth/change-password` does not exist — no route, no test, no fixture — and `W0-BE-012` has not written the fixture directory yet. Distinct from `AUD-024`, which did invalidate accepted error-envelope assertions.

    **Which task this blocked was recorded wrongly, and the review caught that too.** The register and the wave index named `S01-BE-004`. `S01-BE-004` is Customer OTP; `S01-BE-003` builds staff login, logout, me and the first-login password gate, so `S01-BE-003` is what builds this endpoint. The mis-assignment came from `AUD-024`'s review and was carried forward here without checking. Corrected in both files: while `S-28` was open the gate protected nothing, because the task that needed the answer was never marked blocked.

    **Independent review.** One reviewer with no implementation context: one `P1`, five `P2`, seven `P3`. Every finding was re-verified in the locked documents before acting; none was wrong. The `P1` is the lockout above and it changed the decision. The `P2`s: the per-account signpost in §8 contradicting §8's own per-phone and per-IP keys; "bounds nothing extra" being false; the `S01-BE-003`/`S01-BE-004` mix-up; and the claim that Wave 0 held no open decision being written **before** this amendment's own review — `AUD-024`'s exact error, in the sentence congratulating itself for avoiding it. That sentence is withdrawn. The remaining `P2` notes that `S-29`, which governs the very length-only password rule this entry leans on, is filed in Wave 1 although `09` §10 is built in Wave 0; the placement is pre-existing and accepted, and is left as it stands with the dependency now stated. `P3`s resolved in place, except the §10 `Codes:` line, which is reported above rather than invented.

    **Bookkeeping.** Status line stamped on `09`. `docs/SPEC_DECISIONS_BACKLOG.md`: row marked Resolved, `Blocks` corrected to `S01-BE-003`, one change-log row. `tasks/WAVE_00_TASK_INDEX.md`: the entry gate records every Wave 0 decision resolved, the `S-28` risk row closes, a new risk row tracks the missing §10 codes, and one change-log row. No task row needed unblocking: `S01-BE-004` was never the dependency and `S01-BE-003` was already `Draft`.

26. **AUD-026 Flutter directory layout** (2026-09-22) — Project Owner decided. `07` §27 named the layers and the features but not the directories, so the first frontend task would have chosen a layout for the whole client as a side effect of scaffolding, and every later wave would have inherited it without anyone deciding it.

    **Resolved as: `lib/features/<feature>/{data,domain,application,presentation}` for features, `lib/core/` for everything no single feature owns, `lib/app/` for the root router and root providers.**

    The layer names are not new — `frontend/AGENTS.md` §2 already requires `data/domain/application/presentation` boundaries "where they provide real ownership". This fixes where they sit. `lib/app/` is not new either: `tasks/OWNERSHIP.md` already names `frontend/lib/app/router.dart` and `frontend/lib/app/providers.dart`. What was genuinely undecided was `features/` versus a flat tree, and whether cross-feature code has one home or several.

    **One home for shared code, `core/`, and the reason is concrete.** `frontend/AGENTS.md` §7 requires one configured API client for base URL, bearer token, timeouts, envelope parsing and safe logging. Two plausible homes for shared code is how a codebase acquires a second Dio client, which §2 forbids outright. `core/` holds network, theme, error-envelope parsing, the `code`-to-text mapping the client owns under §27, and localization.

    **Decided before the scaffold rather than inside it.** Renaming a layout later touches every feature at once, and in a wave model that means every frontend track simultaneously. Raised while preparing the `S01-FE-001` worktree.

    **Changed, by category.** **Cross-feature architecture**, which root `AGENTS.md` §3 reserves to the Project Owner. No API semantics; no database or schema contract; no money, quantity or rounding rule; no lifecycle state; no concurrency, idempotency or replay policy; no role capability, ownership, assignment or existence-privacy rule; no backend behaviour of any kind.

    **Evidence validity** per `tasks/README.md` §13: nothing is invalidated. No Flutter project exists — `frontend/` holds only `AGENTS.md` — so there is no test, build or accepted evidence to reach. `S01-FE-001` is the first task that touches it and has not started.

    **Bookkeeping.** Status line stamped on `07`. No task row changes: `S01-FE-001` was already unblocked by the Flutter SDK being installed, and this removes an open choice from its contract rather than a dependency.

27. **AUD-027 `core/` subdirectories are examples, not a closed list** (2026-09-23) — Project Owner decided. `AUD-026` illustrated `lib/core/` with "network, theme, error-envelope parsing, the code-to-text mapping, localization". `S01-FE-001` delivered `core/storage/`, `core/config/` and `core/routing/` as well, and its independent review raised the gap as `R-09`.

    **The rule was never broken.** `AUD-026`'s rule is that nothing cross-feature lives outside `core/`, and all three sit inside it. None belongs to a single feature: the token store is read by every request, the API configuration owns one client for the whole app, and the routing directory is the `D-8` registry that collects fragments from every feature. What misled was the illustration, which could be read as exhaustive.

    **Resolved as:** the names in `07` §27 are examples. The test for a new `core/` subdirectory is whether one feature owns the thing — if one does it belongs to that feature, if none does it belongs in `core/` — and a track needs no approval to add one that passes. Recorded so the next frontend track does not stop and ask the same question.

    **Changed, by category.** **Cross-feature architecture**, reserved by root `AGENTS.md` §3, clarified rather than altered: no directory moves and no code changes. Nothing else.

    **Evidence validity** per `tasks/README.md` §13: nothing is invalidated. The wording is brought in line with an implementation that already satisfied the rule.

    **Bookkeeping.** Status line stamped on `07`. No task row or ownership change; `S01-FE-001` records `R-09` as resolved in its own review table.

## External Integration Gates

Not unresolved business-contract defects: concrete SMS vendor, Flutter map/tile provider, Firebase credentials, official Payme/Paynet/xazna/Click merchant protocols/credentials. These are provider implementation gates. The implementing agent must not invent them; missing material causes `BLOCKED`.

Since `AUD-022` these gates carry two further facts. Published protocol documentation and credentials are separate: the former permits a thin adapter, the latter remains mandatory for verification and Wave 5 closure. And some gates require a registered legal entity — the SMS contract with its alpha-name, and every merchant agreement — which does not yet exist, so they are Wave 5. Provider selection, the map/tile package and the Firebase project do not require one. The full table is in `tasks/README.md` Section 16.

## Result

All product/architecture/database/client-API decisions needed to materialize the locked Stage 0 specification are synchronized. Provider-specific raw protocols remain intentionally outside generic BarakaBozor API until official provider material exists.
