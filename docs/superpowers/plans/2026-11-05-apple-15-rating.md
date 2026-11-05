# Apple Stage 15 — «Оценка заказа» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a delivered order, «Как вам заказ?» has five 44 px stars; a tap lights them up to it with a buzz and the rating screen rises from below (and leaves downward). The screen names the order by three photos and «Помидоры, Лепёшка и ещё 2 · доставлен сегодня в 13:05»; the stars fill in a cascade, the tapped one pops, the word fades in, a finger can slide across them, and a screen reader meets one adjustable «Оценка: 2 из 5, Плохо». At 1–3 stars the photos fold away and «Что пошло не так? · Можно выбрать несколько» unfolds; reasons chosen and then hidden at 4–5 come back at 1–3 and are never sent at 4–5. The comment shows an example per reason and a counter only from 450; over 500 the button says «Сократите комментарий». «Отправить оценку» freezes the form, ends as ✓ «Оценка отправлена», and the order's «Ваша оценка» card flashes. «Нет связи — оценка не отправлена · Повторить» when nothing left the phone; a lost answer locks the form with «Отправить ещё раз» (the same body); «уже оценили» is a banner on the order; a closed window is a calm «Срок оценки прошёл» with «Вернуться к заказу». × and back keep a draft while the app runs («Оценка не отправлена · Продолжить» on the card). «Ваша оценка» shows its date and, after the Operator's call, «Оператор связался с вами сегодня в 15:40».

**Architecture:** The server adds `reviewed_at` to the Customer's rating (the column exists; no migration). On the client, `NetworkFailure` learns whether the request may have reached the server; pure rating rules, the draft and its per-account store live in `application/rate_draft.dart`. A shared `RatingStars` widget draws, animates and speaks the stars for the screen and the order card. The route uses a new `risingPage`. The screen splits into its state (`rate_order_screen.dart`), its form (`rate_order_form.dart`) and its footer (`rate_order_footer.dart`); it pops with a `RateExit`, and the order page plays the outcome (scroll to the top and the card's flash, or the «уже оценили» banner). The cancel sheet's chip and banner box become shared pieces.

**Tech Stack:** Laravel 13 + PostgreSQL, Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.1.2 (`CustomTransitionPage`), dio 5.11.1; core `announce`, `Fold`, `TimedBanner`, `textScaleAt`, `trimLikeServer`, `failureText`, `orderAtLower`, `KitStar`; orders `OrderMutation`, `RateController`; `HapticFeedback`; flutter_test (`tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, `tester.view.viewInsets`, the `SystemChannels.platform` mock for haptics, `SemanticsAction.increase/decrease`).

**Spec:** `tasks/APPLE_BATCH.md` stage 15 (`rate-2` … `rate-7`, `rate-8` **repro**, `rate-9` **repro**, `rate-10` **server**, `rate-11` **repro**; `rate-1` was stage 1); the live test «Тест оценки заказа - Apple» in Claude Design, local copy `G:/tools/tmp/w-rate/site/rate.html` — CSS at lines 14–248, template 251–364, script: `cardTap`, `openRate`, `choose`, `tapChip`, `send`, `go`, `resolve`, `succeed`, `already`, `leave`, `closeRate`, `stops`, `animOf`, `orderVals`, `ratedVals`, `rateVals` — it rules wherever this plan is silent; the review's memory note (2026-10-28); `DL-90` (1), `DL-91` (4), (5), `DL-92` (6), `DL-126`, `DL-131` (12), `DL-132` (12), `DL-133` (8), (10); `docs/03-features.md` (rating paragraph), `docs/04-user-flows.md` §36, `docs/09-api-contracts.md` §20, §49, §59, §60; `frontend/AGENTS.md`, `backend/AGENTS.md`.

## Global Constraints

- Changes stay in `backend/`, `frontend/`, `docs/` and `tasks/`. No package, no lockfile change, no migration. Generated localizations come from `flutter gen-l10n`, never by hand.
- New strings (ru / uz), the Russian the page's:
  - Card: `rateBlockHint` changes to «Свежесть, вес и доставка · оценить можно 7 дней» / «Yangilik, og'irlik va yetkazish · 7 kun ichida baholash mumkin»; `rateDraftLine` «Оценка не отправлена» / «Baho yuborilmadi»; `rateDraftContinue` «Продолжить» / «Davom etish».
  - Header: `rateNamesTwo` «{first}, {second}» (both); `rateNamesMore` «{first}, {second} и ещё {count}» / «{first}, {second} va yana {count} ta»; `rateHeaderSub` «{names} · доставлен {when}» / «{names} · {when} yetkazildi»; `rateHeaderSpoken` «Как вам заказ? Заказ № {number}, доставлен {when}: {names}» / «Buyurtma yoqdimi? Buyurtma № {number}, {when} yetkazildi: {names}»; `rateHint` changes to «Оцените всё: свежесть, вес и доставку» / «Hammasini baholang: yangilik, og'irlik va yetkazish».
  - Stars: `rateStarsSpokenLabel` «Оценка» / «Baho»; `rateStarsValue` «{stars} из 5, {word}» / «5 dan {stars}, {word}»; `rateStarsNone` «не выбрана» / «tanlanmagan»; `rateReasonsShown` «Появился вопрос: что пошло не так?» / «Savol paydo bo'ldi: nima noto'g'ri bo'ldi?»; `rateReasonsHidden` «Причины скрыты — они не отправятся.» / «Sabablar yashirildi — ular yuborilmaydi.»; `rateDraftRestored` «Черновик восстановлен.» / «Qoralama tiklandi.».
  - Reasons and comment: `rateWhatWrongMany` «Можно выбрать несколько» / «Bir nechtasini tanlash mumkin»; `rateExampleNotFresh` «Какой товар был несвежим?» / «Qaysi mahsulot yangi emas edi?»; `rateExampleWrongWeight` «Какой товар и насколько не тот вес?» / «Qaysi mahsulot va og'irligi qanchaga farq qildi?»; `rateExampleLate` «На сколько опоздал курьер?» / «Kuryer qancha kechikdi?»; `rateExampleRude` «Что случилось? Мы разберёмся» / «Nima bo'ldi? Biz aniqlaymiz»; `rateExampleMany` «Расскажите, что случилось» / «Nima bo'lganini aytib bering»; `rateCommentSpoken` «Комментарий, необязательно» / «Izoh, ixtiyoriy»; `rateOver` plural «На {count} знак / знака / знаков больше, чем можно» (one / few / many, other «знака») / «{count} ta belgi ortiqcha».
  - Footer: `rateSend` changes to «Отправить оценку» / «Bahoni yuborish»; `rateSending` changes to «Отправляем…» / «Yuborilmoqda…»; `rateSent` «Оценка отправлена» / «Baho yuborildi»; `rateShorten` «Сократите комментарий» / «Izohni qisqartiring»; `rateSendAgain` «Отправить ещё раз» / «Yana yuborish»; `rateUnsent` «Нет связи — оценка не отправлена» / «Aloqa yo'q — baho yuborilmadi»; `rateUnsure` «Ответ не дошёл — оценка могла сохраниться. Отправьте ещё раз: дважды она не сохранится.» / «Javob kelmadi — baho saqlangan bo'lishi mumkin. Yana yuboring: u ikki marta saqlanmaydi.»; `rateClosedTitle` «Срок оценки прошёл» / «Baholash muddati o'tdi»; `rateClosedText` «Оценить заказ можно в течение 7 дней после доставки.» / «Buyurtmani yetkazilgandan keyin 7 kun ichida baholash mumkin.»; `rateBackToOrder` «Вернуться к заказу» / «Buyurtmaga qaytish».
  - Spoken outcomes: `rateSendingSpoken` «Отправляем оценку…» / «Baho yuborilmoqda…»; `rateSentSpoken` «Оценка отправлена: {stars} из 5.» / «Baho yuborildi: 5 dan {stars}.»; `rateOperatorWillContact` «Оператор свяжется с вами.» / «Operator siz bilan bog'lanadi.»; `rateUnsentSpoken` «Оценка не отправлена: нет связи.» / «Baho yuborilmadi: aloqa yo'q.»; `rateUnsureSpoken` «Ответ не дошёл. Оценка могла сохраниться. Отправьте ещё раз.» / «Javob kelmadi. Baho saqlangan bo'lishi mumkin. Yana yuboring.».
  - Rated card and banner: `ratedOperatorWill` «Оператор свяжется с вами, чтобы разобраться» / «Operator vaziyatni aniqlash uchun siz bilan bog'lanadi»; `ratedOperatorCalled` «Оператор связался с вами {when}» / «Operator siz bilan {when} bog'landi»; `ratedAlreadyTitle` «Этот заказ уже оценили: {stars} из 5» / «Bu buyurtma allaqachon baholangan: 5 dan {stars}»; `ratedAlreadyHint` «Оценку отправили раньше — изменить её нельзя» / «Baho avval yuborilgan — uni o'zgartirib bo'lmaydi».
  - Reused: `rateTitle`, `rateBlockTitle` (the screen's title line too), `rateStar1`…`rateStar5`, `rateWhatWrong`, `rateComment`, `rateCommentHintGood`, `rateCommentHintBad`, `rateOperatorWillCall`, `rateStarsLabel` (card buttons), `ratedTitle`, `ratedThanks`, `ratedStarsLabel`, `cancelLeft` (the counter), `cancelChipSpokenOn` / `cancelChipSpokenOff` (a reason's announcement), `retryButton`, `failureText`, `orderAtLower` («сегодня в 13:13»). Removed when no longer used: `rateQuestion`, `rateWindowClosed`, `ratedThanksLow`.
- Drawing, from the page. **Screen** body padding 4/20/24. Photos: 8 above; tiles 56 × 56, radius 16, `page` ground, a 3 px white ring, each after the first 10 to the left over its neighbour, the picture 40 inside; with more than three lines the fourth tile says «+N» (N = lines − 3) 14 w700 `ink2`. Title `rateBlockTitle` 18 w700 `ink` line 1.3 centred, 16 above; the sub 13 line 1.4 `ink2` centred, 4 above; the hint 13 line 1.4 `muted` centred, 8 above. Stars 16 above: five 52 × 52 cells, glyph 44, centred. The word 16 w600 `ink` line 1.3, 4 above, centred, keeping one line's height when empty. Reasons: heading 16 w700 `ink` line 1.3, 20 above, with the note 13 w500 `muted` 2 under it; chips 10 under, in a `Wrap` 8 apart; a chip ≥ 44 high, padding 6/16, radius 22, `field` ground with a 1 px `outline` edge, 14 w500 `ink` line 1.25; chosen: `primaryWash`, a 1.5 px `primary` edge, 14 w600 `primaryDark`, `Icons.check` 18 before the words; colours change over 200 ms `Curves.easeOut`. Field label `rateComment` 13 w600 `ink` line 1.35, 20 above; the field 8 under it, `field` ground, radius 14, padding 14 at the sides, ≥ 50 high, 15 line 1.4 `ink`, placeholder `muted`, 1 to 5 lines then it scrolls, no built-in counter; over the limit a 1.5 px `danger` edge. Counter 12 line 1.35 `muted` at the end, 6 above, only from 450; over the limit `danger` w600. Operator note (1–3 stars) 16 above as now. Closed face: 40 above, centred: a 72 circle `page` with `Icons.schedule` 34 `muted`, the title 18 w700 `ink` line 1.3 18 under it, the text 14 line 1.45 `ink2` 8 under. **Footer** pinned under the body and above the keyboard: white, a 1 px `line` top edge, a soft shadow upwards (0, −6, blur 20, black at 6 %), padding 12/20/12 plus the bottom safe area. Red line (a sure refusal) 14 line 1.4 `danger`, 12 under it. Red strip (nothing sent): 12 under it, padding 6/6/6/12, radius 12, `dangerWash`, `Icons.wifi_off` 20 `danger`, 10, words 13 line 1.35 `ink2`, `retryButton` white ≥ 44 high, padding 0 14, radius 10, 14 w700 `danger`. Amber note (lost answer): 12 under it, padding 12, radius 14, `warningWash`, `Icons.sync_problem` 18 `warningDark`, 8, words 13 line 1.45 `ink`. Above 1.3 at 13 px a strip's button goes under its words at full width. Button full width, ≥ 54 high, radius 14, 16 w600 line 1.25, padding 6/12; green `primary` / white, off `buttonOff` / `muted`, colours change over 250 ms `Curves.easeOut`; sending: an 18 white spinner, 8, «Отправляем…»; sent: `Icons.check` 20, 8, «Оценка отправлена». **Order card** (`RateOrderCard`): as now (white, radius 16, the card shadow, padding 16, title 15 w700 centred), stars 8 under the title: five round 44 × 44 buttons 4 apart, glyph 34; hint 12 line 1.35 `muted` centred 8 under; the draft strip 12 under it: padding 6/6/6/12, radius 12, `warningWash`, `Icons.edit_note` 20 `warningDark`, 10, `rateDraftLine` 13 line 1.4 `ink`, `rateDraftContinue` white ≥ 44 high, padding 0 12, radius 10, 14 w700 `warningDark` (under the words above 1.3 at 13 px). **Rated card**: the head row `ratedTitle` 15 w700 `ink` with the date 12 `muted` at the end on the baseline (the date goes under it when they do not fit); stars 24, 2 apart, 8 under; reasons and comment as now; the note 12 above it, 13 line 1.4 `ink2`, with `Icons.support_agent` (low, not reviewed) or `Icons.check_circle` (low, reviewed) 18 `primaryDark` 8 before it, no icon at 4–5. **Banner**: the cancel banner's dark box (`ink2`, radius 16, padding 12/14, the kit shadow, icon 24 white, 12, title 15 w700 white over the hint 13 white at alpha 0.92) with `Icons.info`, placed where the cancel banner stands.
- Motion, none of it with reduced motion (`MediaQuery.disableAnimationsOf`) unless said: the route rises from the bottom in 340 ms `Cubic(0.2, 0.8, 0.2, 1)` and sinks in 260 ms `Curves.easeIn` (a 200 ms fade each way with reduced motion); a star change lights the stars between the old and the new value one by one, 35 ms apart, each growing from scale 0.55 and opacity 0.35 in 260 ms `Cubic(0.2, 0.8, 0.2, 1)`, and the chosen star pops 1 → 1.18 (35 %) → 0.97 (70 %) → 1 in 380 ms after the others started (reduced: the newly lit fade in 150 ms); a pressed star's glyph is at 0.9; the word rises 4 px with a fade in 200 ms `Curves.easeOut` at each change (a 150 ms fade with reduced motion); `Fold` for the photos with the hint and for the reasons (its own 260 ms, a fade with reduced motion); the form fades to 0.55 in 200 ms `Curves.easeOut` while sending; the closed face, the strip and the amber note rise 8 px with a fade in 260 ms `Cubic(0.2, 0.8, 0.2, 1)`; ✓ pops like the chosen star; the green button scales to 0.98 while pressed; ✓ stands 650 ms (500 ms with reduced motion), then the screen pops; the card's stars push the screen 300 ms after the tap (120 ms with reduced motion); the rated card flashes from `lineFlash` with a 2 px `primary` ring to white with its shadow in 1.6 s `Curves.easeOut` (with reduced motion too: colour, not movement); the page scrolls to the top in 300 ms `Curves.easeInOut` (a jump with reduced motion); the banner is `TimedBanner(fromBelow: true)`. Haptics, kept with reduced motion (`DL-129` (8)): `lightImpact` on a star tap (card and screen) and on ✓ (`DL-132` (12)); `selectionClick` on each change while a finger slides.
- Large text: a layout rule reads `textScaleAt(scaler, fontSize)` at the size of the text it holds (`DL-126`). Tests at large text use `NonlinearTextScaler(2)` on a 360 × 640 dp screen; the keyboard is `tester.view.viewInsets = const FakeViewPadding(bottom: 300)`.
- Every face this stage draws — the screen empty, at 2 stars with reasons, at 5, over the limit, sending, sent, the red line, the red strip, the locked face, the closed face; the order page with the rate card, with its draft strip, with the rated card (each note), with the banner — passes `meetsGuideline(iOSTapTargetGuideline)` at 100 % and at `NonlinearTextScaler(2)` (batch rule).
- The outcome is the server's (`frontend/AGENTS.md` §9): «Оценка отправлена» only for an answered order whose `rating` is filled; the banner's stars are the stored rating's; the locked face resends exactly the body sent (`docs/09` §49, no key).
- Tests that pinned the old screen (reasons erased at 4–5, «0 / 500», «Не более 500 символов», «Отправить», the red closed-window line over a dead form, «Нет подключения к интернету» above the button, the silent return on `order_already_rated`, the bounce off an unrated order past its window, the 40 px boxes, `ratedThanksLow`) are rewritten to the new rule, each named in the task's report; no other test is deleted or weakened.
- Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root; never a destructive artisan command (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database). PHPUnit runs with `--fail-on-warning`. Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; a full suite uses `--concurrency=2`; no background jobs.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-134`. A test's first run is red, and the report quotes the red line.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch answers a new field on the Customer's own order.

## Review Focus

1. A lost answer whose rating did land: «Отправить ещё раз» sends the identical body (same stars, reasons, trimmed comment), the server replays `200`, and the screen ends as ✓ «Оценка отправлена», not as «уже оценили». Task 6 test `'a resend after a lost answer sends the same body and ends as sent'`.
2. Reasons chosen at 2 stars, then 5, then sent: none are sent; at 2 again they come back chosen. Task 5 test `'reasons fold at 4 and come back at 2'`, Task 6 test `'at 5 the kept reasons are not sent'`.
3. Another account on the same phone never sees the first account's draft. Task 3 test `'another account starts with no drafts'`.
4. The screen opened from «Мои заказы» ends and returns to the list: no flash or banner is owed, nothing throws, the list card shows the stars. Task 7 test `'rating from the list returns to the list'`.
5. 200 % text on 360 × 640 with the keyboard up and the locked face: the amber note and «Отправить ещё раз» stay whole above the keyboard, the form scrolls, every target is 44. Task 6 test `'at large text with the keyboard up the locked footer stays whole'`.

---

### Before the tasks (the lead)

- [x] **The test page.** Read 2026-11-05 from the local copy; this plan follows it.
- [ ] **Reproduce `rate-8`, `rate-9`, `rate-11`.** The Owner dropped the emulator walks (2026-11-05); as in stages 11–14, the first red runs of the named tests on main's screen are the reproduction — Task 6 `'a lost answer locks the form'` (`rate-8`: on main the stars still change after it), Task 6 `'× keeps the draft for the card'` (`rate-9`), Task 4 `'a reader meets one adjustable rating'` (`rate-11`, run against main's screen through `rate_order_test.dart` before Task 5 replaces it) — and `DL-134` (13) quotes the red lines.

### Task 1: Server — `reviewed_at` on the Customer's rating; the decision record

**Files:**
- Modify: `backend/app/Modules/Orders/Http/Resources/CustomerOrderResource.php` (the `rating` object; the class docblock)
- Modify: `docs/09-api-contracts.md` §20 (`rating` is `{stars, reasons, comment, created_at, reviewed_at}`; `reviewed_at` the instant an Operator or Admin marked it reviewed, else `null`, `DL-134` (1)) and §60 (the Customer's order shows `reviewed_at`), `docs/03-features.md` (the rating paragraph: one sentence on the draft, the lost answer and the review's time, `DL-134`), `docs/04-user-flows.md` §36 (the Customer's order says when the Operator contacted them), `docs/DECISIONS.md` (new `DL-134`, below), `tasks/APPLE_BATCH.md` (stage 14's row «Merged (PR #136)»)
- Test: `backend/tests/Feature/Orders/RatingReviewApiTest.php`, `OrderRatingApiTest.php`

**Interfaces:**
- Produces: the Customer's `rating.reviewed_at` — ISO-8601 Zulu or `null`, on the detail and on every answer that renders the order resource (the rating's `201` and `200`). Who reviewed stays staff-side.

- [ ] **Step 1: Write the failing tests:**
  - `OrderRatingApiTest::test_a_new_rating_is_not_reviewed`: the `201` answer's `data.rating.reviewed_at` is `null` and the key is present.
  - `RatingReviewApiTest::test_the_customer_sees_when_the_rating_was_reviewed`: rate 2 as the Customer, review as an Operator at a frozen `now` (`$this->travelTo(...)`), then `GET /customer/orders/{order}` → `data.rating.reviewed_at` equals that instant as `toIso8601ZuluString()`; the rating object has exactly the keys `stars, reasons, comment, created_at, reviewed_at` (no reviewer).
- [ ] **Step 2: Run them and see them fail** — `docker compose -f docker/compose.yaml exec app php artisan test --fail-on-warning --filter "test_a_new_rating_is_not_reviewed|test_the_customer_sees_when_the_rating_was_reviewed"`; expected red: `Failed asserting that an array has the key 'reviewed_at'`.
- [ ] **Step 3: Implement** — `'reviewed_at' => self::instant($order->rating->reviewed_at)` after `created_at`; docblock and docs/09's JSON as listed.
- [ ] **Step 4: Write `DL-134`** — «The Apple batch, stage 15: rating (2026-11-05, agent)»:
  1. **The Customer's rating carries `reviewed_at`** (`rate-10`): the instant the Operator or Admin marked it reviewed (`DL-91` (5)), else `null`; the reviewer stays staff-side. The card says «Оператор связался с вами …» only for a low rating, as only those are called.
  2. **`NetworkFailure` says whether the request may have reached the server** (`mayHaveArrived`): `false` only when no connection was made — dio's `connectionTimeout`, or `connectionError` caused by a `SocketException` while connecting; a connection closed before the answer's headers is `connectionError` with an `HttpException` and counts as maybe arrived, as do timeouts after connecting and any other failure.
  3. **The rating screen rises from below as a full-screen dialog** (`rate-2`, `risingPage`): × and Android's back close it, iOS has no edge swipe for it; the page under it stands still.
  4. **Stars** (`rate-3`): a tap chooses on release, a horizontal drag from its start and at each move; a vertical drag scrolls. `lightImpact` on a tap, `selectionClick` per change while sliding, none for a screen reader's adjustment. On the screen a reader meets one adjustable control (`rate-11`); the card keeps five buttons, each opening the screen.
  5. **Reasons are one set kept while hidden** (`rate-5`): at 4–5 they fold and stay chosen; the body sends them only at 1–3, in the enum's order. Supersedes the UI half of `DL-92` (6).
  6. **The comment's example follows the reasons** (`rate-6`): none at 1–3 «Что случилось?», one its own example, several «Расскажите, что случилось», 4–5 «Что понравилось?»; the counter from 450 counts what the server keeps (`trimLikeServer`, code points).
  7. **Sending freezes the form** (`rate-7`); a filled `rating` in the answer ends as ✓ for 650 ms with `lightImpact` (`DL-132` (12)), then the screen pops with `RateExit.sent`; the order page scrolls to the top and flashes «Ваша оценка» once the shown order has the rating.
  8. **Failures** (`rate-8`): nothing sent → the red strip with «Повторить», the form stays editable; maybe arrived, `5xx`, a malformed or unexplained answer → the form locks and «Отправить ещё раз» sends the identical body (`docs/09` §49), until a sure answer; `order_already_rated` → the screen pops with `RateExit.already` and the order shows a banner with the stored stars once it has them; `rating_window_closed` → the calm face with «Вернуться к заказу»; another refusal → a red line, the form editable. An unrated completed order past its window opens on the calm face (supersedes «returns to the order» of `DL-92` (6) for that case); a rated or unfinished one still returns.
  9. **The draft** (`rate-9`) lives in `rateDraftsProvider`, per order, while the app runs, and starts empty for another account. Leaving the screen unsent with a reason or a comment keeps it, also from the locked face (the card shows it only while the server says the order can be rated); a sure outcome drops it. «Продолжить» opens the screen with the draft's stars, a star on the card with the tapped stars and the draft's reasons and comment.
  10. **The header names the order by what was bought** (`rate-4`): the lines not removed (all lines if every one was), the first three pictures, two names and «и ещё N»; «доставлен» is `completed_at` in Tashkent; the order number is spoken, not shown.
  11. **The rated card** reads as one node and shows the rating's date (`orderAtLower`).
  12. **Shared pieces:** the cancel sheet's chip becomes `KitChoiceChip` (white ground for the cancel, `field` for the rating) and its banner box `DarkNoticeBanner`, both in `orders/presentation/`.
  13. **How `rate-8`, `rate-9`, `rate-11` were reproduced:** by red tests on main's screen before its change, as in stages 11–14 (walks dropped by the Owner, 2026-11-05); each stays as the item's test. (The lead fills in the red lines from the reports.)
- [ ] **Step 5: Run** `RatingReviewApiTest`, `OrderRatingApiTest`, `CustomerOrderApiTest` and `pint --test`, `phpstan analyse` — green.
- [ ] **Step 6: Commit** — `feat(orders): the Customer's rating says when it was reviewed (DL-134)`.

### Task 2: Client data — `reviewedAt`; whether a failed request may have arrived

**Files:**
- Modify: `frontend/lib/features/orders/domain/customer_orders.dart` (`CustomerRating.reviewedAt`), `frontend/lib/features/orders/data/customer_orders_api.dart` (`_rating` reads the required key `reviewed_at`, value nullable), `frontend/lib/core/network/api_failure.dart`
- Modify: `frontend/test/support/fake_customer_orders_repository.dart` and the JSON fixtures that build a rating (add `'reviewed_at': null`)
- Test: `frontend/test/core/network/api_failure_test.dart`, `frontend/test/features/orders/data/customer_orders_api_test.dart`
- `tasks/APPLE_BATCH.md` Risks: one line — the app reads `rating.reviewed_at` as a required key, deploy the backend first (`DL-134`).

**Interfaces:**
- Produces: `CustomerRating.reviewedAt` (`DateTime?`); `const NetworkFailure({this.mayHaveArrived = true})` with `final bool mayHaveArrived`.

- [ ] **Step 1: Write the failing tests:**
  - `api_failure_test`: `'a connection never made has not arrived'` — `DioException(type: connectionTimeout)` and `DioException(type: connectionError, error: const SocketException('Failed host lookup'))` → `NetworkFailure` with `mayHaveArrived == false`; `'a connection that broke may have arrived'` — `connectionError` with `HttpException('Connection closed before full header was received')`, `receiveTimeout`, `sendTimeout`, `unknown` with a `SocketException` → `mayHaveArrived == true`.
  - `customer_orders_api_test`: a rating with `reviewed_at: '2026-09-28T10:40:00Z'` parses to that UTC instant; `null` to `null`; a rating without the key is a `FormatException` (as other required keys).
- [ ] **Step 2: Run and see them fail** (`flutter test test/core/network/api_failure_test.dart test/features/orders/data/customer_orders_api_test.dart`).
- [ ] **Step 3: Implement** — `fromDio` decides `mayHaveArrived` before the "no answer" return; `_rating` reads `json.nullableInstant('reviewed_at')` as a required key.
- [ ] **Step 4: Run them and the orders and network folders** — green.
- [ ] **Step 5: Commit** — `feat(orders): the rating's review time, and whether a failed request may have arrived (DL-134)`.

### Task 3: The draft and the rating's rules

**Files:**
- Create: `frontend/lib/features/orders/application/rate_draft.dart`
- Test: create `frontend/test/features/orders/application/rate_draft_test.dart`

**Interfaces:**
- Consumes: `NetworkFailure.mayHaveArrived` (Task 2), `trimLikeServer`, `RatingReason`, `customerAccountProvider`.
- Produces:
  - `const int rateCommentMax = 500; const int rateCounterFrom = 450;`
  - `bool isLowRating(int? stars)` — 1 to 3.
  - `final class RateBody { const RateBody({required this.stars, required this.reasons, required this.comment}); final int stars; final List<RatingReason> reasons; final String? comment; }` with value `==` / `hashCode`.
  - `final class RateDraft { const RateDraft({this.stars, this.reasons = const <RatingReason>{}, this.comment = ''}); final int? stars; final Set<RatingReason> reasons; final String comment; RateDraft copyWith({int? stars, Set<RatingReason>? reasons, String? comment}); int get length; bool get tooLong; bool get worthKeeping; RateBody? get body; RateExample get example; static const RateDraft empty; }` — `length` = code points of the trimmed comment; `worthKeeping` = a reason or a non-blank comment; `body` = `null` without stars, else reasons only when low, in `RatingReason.values` order, comment trimmed or `null` when empty.
  - `enum RateExample { good, bad, notFresh, wrongWeight, late, rude, many }`.
  - `enum RateFailure { unsent, unsure, already, closed, notRateable, refused }` and `RateFailure? rateFailureOf(ApiFailure? failure)` — `null` for `null` and `CancelledFailure`; `NetworkFailure` → `unsent` when `!mayHaveArrived` else `unsure`; `MalformedResponseFailure`, `UnexpectedFailure`, an `ApiRefusal` with `status >= 500` → `unsure`; codes `order_already_rated` → `already`, `rating_window_closed` → `closed`, `order_not_rateable` → `notRateable`; any other refusal → `refused`.
  - `class RateDrafts extends Notifier<Map<String, RateDraft>>` with `void keep(String orderId, RateDraft draft)` (stores it when `worthKeeping`, else removes the order's) and `void drop(String orderId)`; `build` watches `customerAccountProvider` and returns `{}`. `final NotifierProvider<RateDrafts, Map<String, RateDraft>> rateDraftsProvider` — not auto-disposed: it lives while the app runs.

- [ ] **Step 1: Write the failing tests** — `'the body sends reasons only at 1 to 3, in order'` (2 stars with `{late, notFresh}` → `[notFresh, late]`; 5 stars → `[]`; comment `'  да '` → `'да'`, `'   '` → `null`; no stars → `null`); `'length counts code points of the trimmed comment'` (`' 🍅🍅 '` → 2; 501 letters → `tooLong`); `'the example follows the reasons'` (5 → good; 2 none → bad; `{wrongWeight}` → wrongWeight; two → many); `'failures map to faces'` (each row above); `'a draft is kept only with a reason or words'`; `'another account starts with no drafts'` (keep for account `a`, switch `customerAccountProvider` to `b` → `{}`); `'drop removes the order's draft'`.
- [ ] **Step 2: Run and see them fail** (`flutter test test/features/orders/application/rate_draft_test.dart`: `Undefined name`).
- [ ] **Step 3: Implement** `rate_draft.dart`.
- [ ] **Step 4: Run** — green.
- [ ] **Step 5: Commit** — `feat(orders): the rating's draft and its rules (DL-134)`.

### Task 4: `RatingStars` and the rising page

**Files:**
- Create: `frontend/lib/features/orders/presentation/rating_stars.dart`, `frontend/lib/core/routing/rising_page.dart`
- Modify: `frontend/lib/features/orders/presentation/orders_routes.dart` (the rate route), `frontend/test/app/route_pages_test.dart` (`customer-order-rate` moves to a new `_risingNames`)
- Test: create `frontend/test/features/orders/presentation/rating_stars_test.dart`; extend `route_pages_test.dart`

**Interfaces:**
- Produces:
  - `enum RatingInput { tap, slide, reader }`.
  - `class RatingStars extends StatefulWidget { const RatingStars({required this.value, required this.onChanged, this.adjustable = false, this.cell = 52, this.glyph = 44, this.spacing = 0, this.keyPrefix = 'rate-star', this.enabled = true, super.key}); final int? value; final void Function(int stars, RatingInput how) onChanged; ... }` — star `i` has key `'$keyPrefix-$i'`. `adjustable: false` (the card): five buttons labelled `rateStarsLabel(i)`, taps only. `adjustable: true` (the screen): a horizontal drag as well, and one semantics node: label `rateStarsSpokenLabel`, value `rateStarsValue(n, word)` or `rateStarsNone`, `increasedValue` / `decreasedValue`, `onIncrease` (none → 1, at most 5), `onDecrease` (down to 1). The widget plays the cascade and pop of Global Constraints when `value` changes and the pop alone when the chosen star is tapped again; it buzzes as listed; `enabled: false` ignores input.
  - `Page<void> risingPage(GoRouterState state, Widget child, {required bool reduced})` — a `CustomTransitionPage<void>` with `fullscreenDialog: true`, the page key, name, arguments and restoration id as `appPage` gives them, 340 / 260 ms (200 / 200 reduced) and the rise or fade of Global Constraints. The rate route passes `MediaQuery.maybeDisableAnimationsOf(context) ?? false`.

- [ ] **Step 1: Write the failing tests** in `rating_stars_test.dart` (a host holding `value` and recording `onChanged`):
  - `'a tap chooses on release and buzzes'` — tap star 3 → `(3, tap)`, one `HapticFeedback.lightImpact`; nothing is chosen on the touch-down alone.
  - `'a slide changes under the finger and clicks'` — a horizontal drag from star 1 to star 4 → `(1, slide)` … `(4, slide)`, a `selectionClick` per change; past the fifth → 5, left of the first → 1.
  - `'a vertical drag chooses nothing'`.
  - `'the cascade lights one by one and the chosen pops'` — 0 → 4: 20 ms in, star 1 is at scale < 1; at 140 ms star 4 has started; at 700 ms every star is at scale 1; with `disableAnimations` no `Transform` scales.
  - `'a reader meets one adjustable rating'` — the screen mode exposes one node with `rateStarsSpokenLabel`, value «2 из 5, Плохо», `hasAction(SemanticsAction.increase)`; performing increase → `(3, reader)` and no haptic.
  - `'the card mode is five buttons'` — five nodes labelled «Оценить на N из 5».
  - In `route_pages_test.dart`: `'the rating rises as a full-screen dialog'` — the rate route's page is a `CustomTransitionPage` with `fullscreenDialog`, 340 / 260 ms, and 200 / 200 under `MediaQuery(disableAnimations: true)`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** both files and switch the route to `risingPage`.
- [ ] **Step 4: Run** the two test files and `rate_order_test.dart` — green (the old screen still uses its own stars until Task 5).
- [ ] **Step 5: Commit** — `feat(orders): rating stars that cascade, slide and speak as one; the rating screen rises (DL-134)`.

### Task 5: The screen's form — header, stars, reasons, comment

**Files:**
- Create: `frontend/lib/features/orders/presentation/rate_order_form.dart` (the scrolling form: header, stars and word, reasons, comment, note, the closed face), `frontend/lib/features/orders/presentation/kit_choice_chip.dart` (the cancel sheet's `_ChipButton`, made public with a `ground` of white or `field`)
- Modify: `frontend/lib/features/orders/presentation/rate_order_screen.dart` (holds a `RateDraft`, starts from `widget.stars` when 1–5 else the draft's stars, the draft's reasons and comment when one is kept for the order; announces `rateStarsValue` with `rateDraftRestored` when restored), `cancel_sheet_form.dart` (uses `KitChoiceChip`), the two ARB files
- Test: `frontend/test/features/orders/presentation/rate_order_test.dart`

**Interfaces:**
- Consumes: `RateDraft`, `RateExample`, `isLowRating`, `rateCommentMax`, `rateCounterFrom`, `rateDraftsProvider` (Task 3); `RatingStars`, `RatingInput` (Task 4).
- Produces: `class RateOrderForm extends StatelessWidget` with `{required CustomerOrder order, required RateDraft draft, required ValueChanged<RateDraft> onDraft, required void Function(int stars, RatingInput how) onStars, required TextEditingController comment, required bool frozen, required bool locked}`; keys `rate-stars` (the `RatingStars`), `rate-word`, `rate-reasons` (the folding block), `rate-reason-<code>`, `rate-comment`, `rate-counter`, `rate-header`; `KitChoiceChip({required String label, required bool chosen, required VoidCallback onTap, bool enabled = true, String? hint, Color ground = Colors.white})`.

- [ ] **Step 1: Write the failing tests** in `rate_order_test.dart`:
  - `'the header names what was bought'` — four lines, the fixture's `completed_at` today → three pictures, «+1», «Помидоры, Лепёшка и ещё 2 · доставлен сегодня в 13:05»; one line → its name alone; a reader hears `rateHeaderSpoken` once.
  - `'photos and hint fold at 1 to 3'` — at 5 they show; at 2 they have folded (`Fold` hidden) and «Что пошло не так?» with «Можно выбрать несколько» shows.
  - `'reasons fold at 4 and come back at 2'` — at 2 choose «Несвежее», 4 → the block folds and the reader hears «4 из 5, Хорошо. Причины скрыты — они не отправятся.»; 2 → «Несвежее» is chosen again and «… Появился вопрос: что пошло не так?» is heard.
  - `'the example follows the reasons'` — the field's hint for none / one / two reasons and at 5.
  - `'the counter shows from 450 and says how far over'` — 449 → none; 450 → «Осталось 50 знаков»; 520 → «На 20 знаков больше, чем можно» in `danger` and the field's `danger` edge.
  - `'a reason is announced chosen and not chosen'`, `'the word changes with the stars'`, `'a reader hears the field by its name'` (`rateCommentSpoken`).
  - Rewrite `'raising to 4 drops the reasons'` to the kept rule and `'a comment over 500 is refused before sending'` to the counter (the button's words come in Task 6).
  - Large text: `'at 200 % on 360 dp the form fits and every target is 44'` at 2 stars with two reasons chosen.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the form and the chip; the screen keeps its old footer for now.
- [ ] **Step 4: Run** `rate_order_test.dart` and the cancel sheet tests — green.
- [ ] **Step 5: Commit** — `feat(orders): the rating form names the order, keeps hidden reasons and counts near the limit (DL-134)`.

### Task 6: The screen's footer, sending and outcomes

**Files:**
- Create: `frontend/lib/features/orders/presentation/rate_order_footer.dart`
- Modify: `rate_order_screen.dart` (sending, faces, draft on leaving, `PopScope`, announcements, `RateExit`), the two ARB files
- Test: `frontend/test/features/orders/presentation/rate_order_test.dart`

**Interfaces:**
- Consumes: `RateBody`, `RateDraft.body`, `rateFailureOf`, `RateFailure`, `rateDraftsProvider` (Task 3); `RateController.rate` (unchanged).
- Produces: `enum RateExit { sent, already }` — what `context.push<RateExit>(AppPaths.customerOrderRate(...))` returns; `null` for every other leave. Footer keys `rate-send` (the button), `rate-strip` (with `rate-retry`), `rate-unsure`, `rate-failure`.
- Rules: the state holds `RateBody? _sent` while locked. «Отправить оценку» is off without stars; over the limit it is off and says «Сократите комментарий». While sending or showing ✓ the form is frozen and `PopScope(canPop: false)`. A sure refusal or `unsent` leaves the form editable; `unsure` locks it and the button sends `_sent` again; while locked a `refused` adds the red line and anything but a sure answer keeps the lock. `closed` replaces the form with the calm face, its button pops. `already` and `notRateable` pop at once (`RateExit.already` for the first). ×, back, and «Вернуться к заказу» on the closed face leave; leaving unsent keeps the draft (`rateDraftsProvider.keep`), a success, `already`, `closed` and `notRateable` drop it. An order already rated when the screen opens returns at once as now; a completed unrated order that cannot be rated opens on the closed face.

- [ ] **Step 1: Write the failing tests:**
  - `'sending freezes the form and ends with a check'` — with `orders.hold`: the button says «Отправляем…», a star tap and a chip tap change nothing, back does not pop; on the answer «Оценка отправлена», one `lightImpact`, the reader hears «Отправляем оценку…» and «Оценка отправлена: 2 из 5. Оператор свяжется с вами.»; after 650 ms the screen is gone and `push` returned `RateExit.sent`.
  - `'nothing sent shows the strip and stays editable'` — `rateFailure = NetworkFailure(mayHaveArrived: false)` → «Нет связи — оценка не отправлена» with «Повторить»; stars still change; «Повторить» sends the new body.
  - `'a lost answer locks the form'` — `NetworkFailure()` → the amber `rateUnsure`, the stars and chips ignore taps, the field is read-only, the button says «Отправить ещё раз».
  - `'a resend after a lost answer sends the same body and ends as sent'` — the fake records two identical sends; the second answers the rated order → ✓.
  - `'at 5 the kept reasons are not sent'`.
  - `'already rated pops with the outcome'` — `order_already_rated` → `RateExit.already`, the draft dropped.
  - `'a closed window shows the calm face'` — `rating_window_closed` → «Срок оценки прошёл», «Оценить заказ можно в течение 7 дней после доставки.», «Вернуться к заказу» pops; and `'an unrated order past its window opens on the calm face'`.
  - `'another refusal is a red line and the form stays'` — `ApiRefusal` 429.
  - `'× keeps the draft for the card'` and `'back keeps the draft'` — leave with «Несвежее» and «мятые» → the draft is kept; reopened from the list card with 3 stars → 3 stars, «Несвежее», «мятые».
  - `'at large text with the keyboard up the locked footer stays whole'` — `NonlinearTextScaler(2)`, 360 × 640, the field focused, the locked face: the amber note and the button lie above `640 − 300`, no overflow, `meetsGuideline(iOSTapTargetGuideline)`; the same for the strip.
  - Rewrite `'a closed window says so and keeps the screen'`, `'another failure is said above the button'`, `'$code returns to the order'`, `'the screen leaves at once for an order that cannot be rated'` to the rules above; keep `'two quick taps rate once'`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the footer and the screen's flow.
- [ ] **Step 4: Run** `rate_order_test.dart` and `order_cards_test.dart` — green.
- [ ] **Step 5: Commit** — `feat(orders): the rating sends with a frozen form, says every failure and keeps a draft (DL-134)`.

### Task 7: The order page — the rate card, the rated card, the outcome

**Files:**
- Create: `frontend/lib/features/orders/presentation/order_notice_banner.dart` (`DarkNoticeBanner`, the box taken from `OrderCancelledBanner`; `RatedAlreadyBanner`)
- Modify: `order_rating_card.dart` (`RateOrderCard`, `RatedOrderCard`), `orders_screens.dart` (opens the screen, plays `RateExit`), `cancel_outcome.dart` (`OrderCancelledBanner` on `DarkNoticeBanner`), the two ARB files
- Test: create `frontend/test/features/orders/presentation/order_rating_card_test.dart`; move the page's rating tests there from `rate_order_test.dart` (`'the page offers stars only while it can be rated'` and the group after it)

**Interfaces:**
- Consumes: `RatingStars` (Task 4), `rateDraftsProvider` (Task 3), `RateExit` (Task 6), `CustomerRating.reviewedAt` (Task 2), `TimedBanner`, `orderAtLower`.
- Produces: `RateOrderCard({required CustomerOrder order, required ValueChanged<int?> onOpen})` — `onOpen(stars)` for a star, `onOpen(null)` for «Продолжить»; `RatedOrderCard({required CustomerRating rating, required DateTime now, required int flash})` — flashes once each time `flash` takes a new value above 0; `DarkNoticeBanner({required IconData icon, required String title, required String hint, required Key boxKey})`; `RatedAlreadyBanner({required int stars})` (box key `rated-already-banner`).
- Rules: the page's `_rate(int? stars)` pushes `AppPaths.customerOrderRate(id, stars: stars)` and awaits `RateExit`; `sent` scrolls to the top as the cancel does and raises a pending flash, played once the shown order has a rating; `already` shows the banner once the shown order has a rating, with its stars, announced as title and hint. The card lights the tapped stars, buzzes and pushes after 300 ms only if its route is still current; back from the screen the stars are unlit.

- [ ] **Step 1: Write the failing tests:**
  - `'the card's stars light to the tap and the screen rises'` — tap the third: stars 1–3 filled, a `lightImpact`, after 300 ms the screen is pushed with 3 stars; back → unlit; 44 × 44 each.
  - `'a draft shows on the card and continues'` — with a kept draft: «Оценка не отправлена» and «Продолжить» → the screen with the draft's stars, reasons and comment; no strip once the order cannot be rated.
  - `'a sent rating flashes the rated card'` — after `RateExit.sent` the page is at the top and `RatedOrderCard` starts from `lineFlash`; 1.6 s later it is white.
  - `'already rated shows the banner with the stored stars'` — «Этот заказ уже оценили: 4 из 5» and «Оценку отправили раньше — изменить её нельзя», announced.
  - `'the rated card says when and what next'` — «сегодня в 13:13»; low unreviewed «Оператор свяжется с вами, чтобы разобраться»; low reviewed «Оператор связался с вами сегодня в 15:40» with `Icons.check_circle`; 5 stars «Спасибо за оценку!»; one semantics node with the whole phrase.
  - `'rating from the list returns to the list'` — from «Прошлые» via `OrderRateStars`, send → back on the list, no banner, no exception, the card shows five stars.
  - Large text: the order page with each card and with the banner at `NonlinearTextScaler(2)` on 360 × 640 — no overflow, `meetsGuideline(iOSTapTargetGuideline)`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the cards, the banner and the page's handling; `OrderCancelledBanner` keeps its key `cancel-banner`.
- [ ] **Step 4: Run** `order_rating_card_test.dart`, `rate_order_test.dart`, `order_cards_test.dart`, the cancel tests and `orders_screens` tests — green; then `flutter analyze` and `dart format --set-exit-if-changed lib test`.
- [ ] **Step 5: Commit** — `feat(orders): the order's rating cards light, keep a draft, flash and say when the Operator called (DL-134)`.

### After the tasks (the lead)

- [ ] Full suites (frontend `--concurrency=2`, backend), the final review, one fix wave, `/security-review`, the pull request, and the closing report with the red lines in `DL-134` (13).
