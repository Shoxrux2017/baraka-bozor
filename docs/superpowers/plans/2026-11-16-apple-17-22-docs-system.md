# Apple Stages 17 + 22 — «Документы» и служебные экраны Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The terms and the privacy policy open under one name with a 24 px large title that hands over to the bar on scroll, readable 16/26 text in a 600 px column clear of the camera cutout, a skeleton the first time and the saved copy at once after that, calm centred states for «Документ не загрузился» and «Документ пока не опубликован», a red strip over a saved copy offline, a note when the text is in the other language, a scroll indicator, selectable text with «Копировать · Выделить всё», and a reader that hears one stop per item and the date in words. The app's start shows «Подключаемся…» after 1.5 s, confirms both sessions at once and stops waiting at 8 s; the wordmark glides into the sign-in (or the curtain fades into the first page), keeps its size at large text; «Нет связи» is grey and calm, tells no connection from a broken server, shows «Проверяем…» and «Связи пока нет · проверено в 9:41», checks itself and fades into the app; the wrong-surface screen names who signed in and offers «Войти как покупатель»; a reader hears every step.

**Architecture:** Client only — no server field, no migration; one new package, `connectivity_plus`, for the «network came back» event. Documents: a per-kind `LegalReader` notifier over a kept-alive in-memory `LegalCopies` replaces `legalDocumentProvider`; `LegalScreen` becomes a stateful page that drives the bar's title and hairline from its scroll, and draws loaded / skeleton / failed / unpublished faces. System screens: `SessionController` confirms slots in parallel under an 8 s cap and records why it could not (`UnreachableCause`) and when a pressed check failed; `UnreachableScreen` schedules its own quiet checks; a new `SessionHandoff` in `MaterialApp.router`'s builder draws the launch picture over the router and plays the handoff (glide to a `WordmarkLanding`, or a fade), and fades «Нет связи»'s last picture over the app. Routes keep replacing in place (`DL-124`).

**Tech Stack:** Flutter 3.47.5, flutter_riverpod 3.4.3, go_router 18.x, `connectivity_plus` (new); core `ListScrollIndicator` (`DL-127`), `SkeletonBar`, `RetryStrip`, `SubmitButton`, `announce`, `textScaleAt` (`DL-126`), `clockProvider`, `TashkentTime`; `AuthScaffold` / `AuthStatusScaffold`; flutter_test (`fakeAsync`, `tester.takeAnnouncements()`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, `tester.view.padding`).

**Spec:** `tasks/APPLE_BATCH.md` stage 17 (`docs-1` … `docs-9`; `docs-3`, `docs-7`, `docs-9` **repro**) and stage 22 (`sys-1` … `sys-10`; `sys-2`, `sys-3`, `sys-10` **repro**); no **Owner** item (`sys-2` keeps `DL-76` (3)). The live tests «Тест документов - Apple» and «Тест служебных экранов - Apple», local copies `G:/tools/tmp/w-docs/site/docs.html` (CSS `.lt .ed .lnote .nt .b.* .sk .est .ob .strip .sind`; script `open`, `answer`, `refresh`, `retry`, `stops`, `docVals`) and `G:/tools/tmp/w-sys/site/sys.html` (CSS `.bwm .bh .gspin .wm .eic .np .chk`; script `boot`, `go`, `glideTo`, `armAuto`, `check`, `unrWords`, `wrongWords`, `stops`). Pairing per `DL-123`: one branch `task/apple-17-22-docs-system`, one pull request.

## Global Constraints

- Changes stay in `frontend/`, `docs/` and `tasks/`. No backend change. One package added: `connectivity_plus` (`flutter pub add connectivity_plus`, the newest that resolves), the reason in its commit message; `pubspec.lock` changes only with it. Generated localizations come from `flutter gen-l10n`, never by hand.
- New strings (ru / uz):
  - Documents: `monthLong` `{month, select, m1{января} m2{февраля} m3{марта} m4{апреля} m5{мая} m6{июня} m7{июля} m8{августа} m9{сентября} m10{октября} m11{ноября} m12{декабря} other{}}` / `m1{yanvar} m2{fevral} m3{mart} m4{aprel} m5{may} m6{iyun} m7{iyul} m8{avgust} m9{sentabr} m10{oktabr} m11{noyabr} m12{dekabr}`; `dateLong` «{day} {month} {year}» / «{year}-yil {day}-{month}»; `legalEditionSpoken` «Редакция от {date} года» / «Tahrir: {date}»; `legalOnlyIn` «Этот документ пока только на {language, select, ru{русском} uz{узбекском} other{другом}} языке.» / «Bu hujjat hozircha faqat {language, select, ru{rus} uz{o'zbek} other{boshqa}} tilida.»; `legalLoadingSpoken` «Загружаем документ…» / «Hujjat yuklanmoqda…»; `legalLoading` «Загружаем…» / «Yuklanmoqda…»; `legalFailedTitle` «Документ не загрузился» / «Hujjat yuklanmadi»; `legalFailedOffline` «Нет связи с интернетом. Проверьте подключение и нажмите «Повторить».» / «Internet aloqasi yo'q. Ulanishni tekshirib, «Qayta urinish»ni bosing.»; `legalFailedOther` «Не удалось загрузить документ. Нажмите «Повторить».» / «Hujjatni yuklab bo'lmadi. «Qayta urinish»ni bosing.»; `legalUnpublishedTitle` «Документ пока не опубликован» / «Hujjat hali e'lon qilinmagan»; `legalUnpublishedBody` «Загляните позже.» / «Keyinroq qayta urinib ko'ring.»; `legalStaleOffline` «Нет связи — показана сохранённая копия» / «Aloqa yo'q — saqlangan nusxa ko'rsatildi»; `legalStaleFailed` «Не удалось обновить — показана сохранённая копия» / «Yangilab bo'lmadi — saqlangan nusxa ko'rsatildi»; `legalCopy` «Копировать» / «Nusxa olish»; `legalSelectAll` «Выделить всё» / «Hammasini tanlash».
  - Start and «Нет связи»: `bootConnecting` «Подключаемся…» / «Ulanmoqda…»; `unreachableOfflineTitle` «Нет связи» / «Aloqa yo'q»; `unreachableOfflineBody` «Проверьте мобильный интернет или Wi‑Fi. Приложение откроется само, когда связь появится.» / «Mobil internet yoki Wi‑Fi'ni tekshiring. Aloqa paydo bo'lganda ilova o'zi ochiladi.»; `unreachableServerTitle` «BarakaBozor сейчас недоступен» / «BarakaBozor hozir ishlamayapti»; `unreachableServerBody` «Интернет на телефоне в порядке. Попробуйте через пару минут — приложение тоже проверит само.» / «Telefoningizda internet bor. Bir necha daqiqadan so'ng urinib ko'ring — ilova ham o'zi tekshiradi.»; `unreachableChecking` «Проверяем…» / «Tekshirilmoqda…»; `unreachableCheckingSpoken` «Проверяем связь…» / «Aloqa tekshirilmoqda…»; `unreachableStillOffline` «Связи пока нет» / «Hali aloqa yo'q»; `unreachableStillDown` «BarakaBozor пока недоступен» / «BarakaBozor hali ishlamayapti»; `unreachableCheckedAt` «{result} · проверено в {time}» / «{result} · {time} da tekshirildi»; `unreachableCheckedAtSpoken` «{result}, проверено в {time}» / «{result}, {time} da tekshirildi»; `unreachableOpening` «Связь есть, открываем приложение» / «Aloqa bor, ilova ochilmoqda».
  - Wrong surface: `wrongSurfacePanelTitle` «Откройте панель на компьютере» / «Panelni kompyuterda oching»; `wrongSurfacePanelWho` «Вы вошли как {role, select, operator{оператор} admin{администратор} manager{менеджер} other{сотрудник}} — {name}. {role, select, operator{Оператор} admin{Администратор} manager{Менеджер} other{Сотрудник}} работает в панели управления, в браузере на компьютере.» / «Siz {role, select, operator{operator} admin{administrator} manager{menejer} other{xodim}} sifatida kirdingiz — {name}. {role, select, operator{Operator} admin{Administrator} manager{Menejer} other{Xodim}} boshqaruv panelida, kompyuterdagi brauzerda ishlaydi.»; `wrongSurfacePanelWhoNameless` — the same two sentences without « — {name}»; `wrongSurfacePanelShop` «На этом телефоне можно делать покупки — войдите как покупатель с тем же номером.» / «Bu telefonda xarid qilish mumkin — shu raqam bilan xaridor sifatida kiring.»; `wrongSurfaceSignInCustomer` «Войти как покупатель» / «Xaridor sifatida kirish»; `wrongSurfaceAppTitle` «Откройте приложение на телефоне» / «Ilovani telefonda oching»; `wrongSurfaceAppWho` «Вы вошли как {role, select, shopper{сборщик} courier{курьер} customer{покупатель} other{пользователь}} — {name}. {role, select, shopper{Сборщик работает} courier{Курьер работает} customer{Покупатель делает заказы} other{Этот аккаунт работает}} в приложении BarakaBozor на телефоне.» / «Siz {role, select, shopper{yig'uvchi} courier{kuryer} customer{xaridor} other{foydalanuvchi}} sifatida kirdingiz — {name}. {role, select, shopper{Yig'uvchi telefondagi BarakaBozor ilovasida ishlaydi} courier{Kuryer telefondagi BarakaBozor ilovasida ishlaydi} customer{Xaridor telefondagi BarakaBozor ilovasida buyurtma beradi} other{Bu hisob telefondagi BarakaBozor ilovasida ishlaydi}}.»; `wrongSurfaceAppWhoNameless` — without « — {name}»; `wrongSurfaceOtherAccount` «Войти другим аккаунтом» / «Boshqa akkaunt bilan kirish». `role` is `UserRole.code`.
  - Reused: `legalTerms`, `legalPrivacy` (now also the profile row), `legalEdition` (fed `dateLong`), `retryButton`, `back`.
  - Removed when no longer used: `legalNotPublishedYet`, `profilePrivacy`, `sessionUnreachableTitle`, `sessionUnreachableBody`, `wrongSurfaceTitle`, `wrongSurfaceMobile`, `wrongSurfaceWeb`, `wrongSurfaceWebTitle`.
- Drawing, documents (from `docs.html`). **Page** white; a column `ConstrainedBox(maxWidth: 600)` centred inside the safe area's left and right insets, padding 20 / 20 / 40 + the bottom inset. **Large title** first in the column: 24 bold `ink`, height 1.2, letter spacing −0.24, wraps, font size `24 + 14 × (textScaleAt(scaler, 16) − 1)` drawn with `TextScaler.noScaling`. **Date** 8 below: 13 `muted` height 1.4, 16 below it. **Language note** (only when the document's language differs from the interface's): `KitColors.page` box, radius 12, padding 10 / 12, `Icons.info_outline` 18 `muted`, 8 gap, 13 `ink2` height 1.45, 12 below the date, 16 below it. **Blocks**: paragraph 16 `ink2` height 26/16; 12 above a paragraph that follows a paragraph, 10 above one that follows an item; heading 18 w700 `ink` height 24/18, 28 above (6 when first), 8 below; item 16/26, 4 above (0 right after a heading), a 22-wide marker column holding a 6 px `ink2` dot at left 3, its centre 13 × the text scale below the item's top. Every size and gap × `scale` (the Admin's preview). **Bar**: `kitAppBar`'s 18 px title; a 1 px `KitColors.buttonOff` hairline as the bar's bottom. **Skeleton** (under the real large title): `SkeletonBar` in `KitColors.line`, radius 6 — a date bar 13 high × 40 %, then three groups of a heading bar 16 high × 55 % (26 above, 14 below) and four line bars 12 high at 100 / 96 / 92 / 60 % with 14 between; heights and gaps × `textScaleAt(scaler, 16)`. **Centred state** in the body: `QuietIcon` (64 circle `KitColors.chip`, icon 30 `ink2`; `Icons.wifi_off` for a network failure, `Icons.error_outline` for another, `Icons.description_outlined` unpublished), 16 below; title 18 w700 `ink` centred; 8 below, text 14 `ink2` height 1.5, max width 300; 20 below, a button min 200 × 52, radius 14, 16 w600 — «Повторить» `primary` fill / white text, busy: an 18 px white spinner then «Загружаем…»; «Назад» white with a 1 px `outline` and `ink` text; side padding 32 (80 in landscape), scrolls when tall. **Strip** over a copy: `RetryStrip` (`dangerWash`) between the large title and the date, 12 below the title; the date keeps its 8 above.
- Drawing, system screens (from `sys.html`). **Launch**: white; the wordmark 34 centred on the screen; the hint's row centred 38 below the screen's centre: an 18 px spinner (stroke 2, track `muted` at 25 %, arc `muted`), 10 gap, «Подключаемся…» 14 `muted` height 1.4. **Wordmark** everywhere: `BrandWordmark` ignores text scaling (`TextScaler.noScaling`), one line, no soft wrap; its semantics stay «BarakaBozor», header. **«Нет связи» / wrong surface** (`AuthStatusScaffold`, phone face): `QuietIcon` (`Icons.wifi_off` offline, `Icons.cloud_off` server, `Icons.computer` / `Icons.smartphone` wrong surface), 24 below; title 20 w700 `ink` height 1.25 centred; 10 below, body 15 `ink2` height 1.5, max width 320; a `note` 8 below it in the same style; 32 below, the button; a `footnote` 12 below the button: 13 `muted` height 1.4 centred. The wide-card face keeps its 22 / 14 sizes and swaps the halo for `QuietIcon`. The button is `SubmitButton` (green) on both screens.
- Motion, none of it with reduced motion (`MediaQuery.disableAnimationsOf`) unless said. Documents: the bar's title opacity `clamp((offset − (titleBottom − 26)) / 22, 0, 1)` where `titleBottom` is the large title's bottom in the scroll content; the hairline's `clamp(offset / 8, 0, 1)` (both follow the scroll also with reduced motion; with no large title the bar's title is 1 and the hairline follows the scroll); the text replacing a skeleton fades from 0 to 1 in 200 ms `easeOut` (the large title does not fade; a copy shown at once does not fade); `ListScrollIndicator` as built; `RetryStrip`'s own rise. Start: the launch wordmark fades in over 150 ms `easeOut` on the first frame; the hint fades in over 300 ms at 1.5 s. Handoff (one 540 ms controller with `AnimationBehavior.preserve`, so the platform's reduced motion does not cut it, `DL-134` Ruling (14)(a)): the ghost wordmark moves and scales from the launch wordmark to the landing in `Interval(0, 450/540)` with `Cubic(0.2, 0.8, 0.2, 1)`; the white and the hint fade out in `Interval(120/540, 380/540)` `easeOut`; the landing's own wordmark is hidden until 540 ms. Every other leave — and every leave with reduced motion — fades the curtain from 1 to 0 in 250 ms `easeOut`. «Нет связи»'s checked line fades in over 200 ms.
- Timing: the hint at 1.5 s; each check (start and every retry) capped at 8 s; a pressed check holds «Проверяем…» at least 800 ms (also when it succeeds); quiet checks 5, 10, 20 and 30 s apart, then every 30 s, the series restarting after each pressed check, and one at once on `AppLifecycleState.resumed` and on the network coming back. One check at a time. Timers are `Timer`s cancelled on completion and on dispose (`ref.onDispose`, `State.dispose`), so a test that ends mid-check leaves none pending.
- Haptics: `HapticFeedback.mediumImpact` when a pressed check finds no connection.
- Large text: layout rules read `textScaleAt(scaler, fontSize)` (`DL-126`); tests at large text use `NonlinearTextScaler(2)` on 360 × 640 dp (320 × 640 for the wordmark).
- Every face this branch draws passes `meetsGuideline(iOSTapTargetGuideline)` at 100 % and at `NonlinearTextScaler(2)` (batch rule): the document loaded, skeleton, failed, busy, unpublished, with the strip; «Нет связи» idle, busy, checked; both wrong-surface faces; the launch curtain.
- The server stays authoritative (`AGENTS.md` §5): a timed-out or failed check keeps every token (`DL-13` (4)); only a `401` clears a slot, as today; quiet checks re-run the same `/auth/me` confirmation; «Войти как покупатель» is the existing `logout(SessionMode.staff)`.
- Tests that pinned the old faces are rewritten, not deleted: the 14/15 px green headings and «•», the spinner and red error line of the legal screen, «Документ пока не опубликован.», «Конфиденциальность» on the profile, the green halo and the old words of the two status screens, the outlined «Выйти», the bootstrap's «wordmark, no spinner» and slots confirmed one after another. Tests that meet the sign-in or a first page during launch let the handoff end (`pump(const Duration(milliseconds: 600))`) — no expectation is dropped.
- `test/support/app_harness.dart` overrides `connectivitySignalProvider` with a silent fake by default, so no test touches the plugin.
- Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; multi-file runs use `--concurrency=1`; no background jobs. Never a destructive artisan command.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-136`. A test's first run is red, and the report quotes the red line.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch changes how stored sessions are confirmed and how a staff session ends on the phone.

## Review Focus

1. A pressed «Повторить» while a quiet check is already out (the network just came back): one `/auth/me` per slot, «Проверяем…» for at least 0.8 s from the press, the app opens once. Task 5 test `'a pressed retry joins a quiet check and holds 0.8 s'`.
2. The interface language switched while a document loads or shows a copy: the page follows the new language; the old language's answer never lands on it (it is kept only as that language's copy). Task 2 test `'an answer for another language is not shown'`.
3. A check that hits the 8 s cap and a `401` for one slot that arrives after it: both tokens stay at the cap; the late `401` clears only its slot; the state stays «Нет связи» until the next check decides. Task 5 test `'the cap keeps every token and a late refusal clears only its slot'`.
4. A flapping network and repeated returns to the app: never two checks at once, and no check or timer after the screen has gone. Task 6 tests `'a flapping network starts one check at a time'` and `'leaving the screen stops the checks'`.
5. A first answer that is not the sign-in — a panel reload into `/operations`, the wrong surface, «Нет связи» — and taps during any handoff: the curtain fades without a ghost and never swallows a tap. Task 8 tests `'a reload into a panel page fades the curtain'` and `'taps reach the page while the curtain leaves'`.

---

### Before the tasks (the lead)

- [x] **The test pages.** Read 2026-11-16 from the local copies; this plan follows them. The memory note that the start slid the next screen in is out of date: since `DL-124` the bootstrap and the sign-in are entry pages and the change is a cut.
- [ ] **Reproduce the repro items.** As in stages 11–16, the first red runs of these tests on main's code are the reproduction, quoted in `DL-136` (19): `docs-3` — Task 3 `'landscape keeps the text clear of the cutout in a 600 column'` (on main the text starts 20 from the screen's edge, under the cutout); `docs-7` — Task 3 `'scrolling shows a thin indicator'` (on main no `scroll-indicator`); `docs-9` — Task 1 `'a list item is one stop without its dot'` (on main «•» is its own node), Task 3 `'the date reads in words'`, Task 4 `'a first open shows the title and a skeleton, then fades the text in'` (on main a spinner without words); `sys-2` — Task 8 `'the wordmark glides to the sign-in'` (on main the sign-in's wordmark stands in its place on the first frame); `sys-3` — Task 8 `'the wordmark keeps its size at large text'` (on main 68 px on two lines); `sys-10` — Task 8 `'the start says Подключаемся… after 1.5 s'` and Task 6 `'a check is spoken and its result too'`.

### Task 1: The blocks and the decision record

**Files:**
- Modify: `frontend/lib/features/legal/presentation/legal_blocks.dart`
- Modify docs: `docs/DECISIONS.md` (`DL-136`), `docs/07-architecture.md` §2 (one line: `connectivity_plus` for the retry screen's «network came back», `DL-136` (15)), §28 (one sentence on the parallel confirmation, the 8 s cap and the retry screen's own checks), §29 (one sentence: the launch picture is a curtain over the router), `docs/03-features.md` (the documents paragraph: one sentence on the copy kept for the app's run and the states), `tasks/APPLE_BATCH.md` (row 16 → «Merged (PR #138)»)
- Test: create `frontend/test/features/legal/presentation/legal_blocks_test.dart`

**Interfaces:**
- Produces: `LegalBlocks(blocks, {scale})` and `LegalBlockList(blocks, {scale, padding, physics})` keep their signatures; only the drawing changes (Global Constraints, «Blocks»).

- [ ] **Step 1: Write the failing tests:**
  - `'body is 16/26 and headings are 18 bold ink'` — a paragraph's `TextStyle` fontSize 16, height 26/16, colour `ink2`; a heading's 18, w700, `ink`, height 24/18; a heading is a `Semantics(header: true)`.
  - `'spacing follows the kind of block'` — measured with `tester.getRect`: 12 between two paragraphs, 10 between an item and the next paragraph, 28 above a heading (6 above a first one), 8 below it, 4 between items, 0 between a heading and an item.
  - `'a list item is one stop without its dot'` (**repro** `docs-9`) — the semantics tree has a node labelled with the item's text and none labelled «•».
  - `'the dot is drawn 6 px, centred on the first line'` — the marker's box is 6 × 6, a circle in `ink2`, its centre 13 below the item's top and 6 from the item's left (3 + 3).
  - `'the preview scale shrinks everything'` — `scale: 0.5`: paragraph 8, heading 9, gap between paragraphs 6.
- [ ] **Step 2: Run and see them fail** (`flutter test test/features/legal/presentation/legal_blocks_test.dart`).
- [ ] **Step 3: Implement** the drawing in `_Block`; the dot is a `DecoratedBox` (no text); nothing else in the file changes.
- [ ] **Step 4: Write `DL-136`** — «The Apple batch, stages 17 + 22: documents and system screens (2026-11-16, agent)», with these points (later tasks only add rulings to (20)):
  1. **The document's name** (`docs-1`): the profile's row says «Политика конфиденциальности», the screen's own name. A 24 px large title opens the page and wraps; with large text it grows as `24 + 14 × (scale − 1)`, slower than the body but above the headings. As it passes under the bar the bar's 18 px title fades in over 22 px of scroll, and a 1 px hairline shows under the bar once text is under it. The date is in words: «Редакция от 19 октября 2026» / «Tahrir: 2026-yil 19-oktabr».
  2. **Reading text** (`docs-2`): body 16/26, headings 18/24 bold `ink` (not green: they are not links), 12 between paragraphs, a drawn 6 px dot; the Admin's preview draws the same at its scale.
  3. **Wide screens** (`docs-3`): a centred column at most 600 wide inside the safe area's sides; a `ListView` given its own padding ignores the cutout.
  4. **Opening** (`docs-4`): the first open shows the large title over a skeleton and the text fades in over 200 ms; a document shown once in this run of the app is kept per kind and interface language and opens at once from that copy while a silent load replaces it. The copy is kept in memory only: the documents are public and short, nothing else needs a store, and no storage package is added; after a restart the first open loads again.
  5. **Failures** (`docs-5`): without a copy, a centred state — grey icon, «Документ не загрузился», the reason (network or other), a green «Повторить» that reads «Загружаем…» while it loads; with a copy, the copy stays under the red strip «Нет связи — показана сохранённая копия · Повторить» («Не удалось обновить — …» for a failure other than the network); unpublished in both languages, «Документ пока не опубликован», «Загляните позже.» and «Назад», and that copy is dropped.
  6. **Language** (`docs-6`): a document whose language differs from the interface's says so in a grey note under the date: «Bu hujjat hozircha faqat rus tilida.» / «Этот документ пока только на узбекском языке.».
  7. **Scroll indicator** (`docs-7`): the core `ListScrollIndicator` (`DL-127`).
  8. **Selection** (`docs-8`): the page is one `SelectionArea` whose menu says «Копировать» and «Выделить всё» in the app's words; the column is not lazy, so «Выделить всё» takes the whole document (about thirty blocks).
  9. **The reader on documents** (`docs-9`): an item is one stop; the date is read in words with «года»; the skeleton reads «Загружаем документ…», announced on open; the large title is the page's heading and the bar's title is silent while it exists; the failure states and the strip are announced.
  10. **Start** (`sys-1`): the stored sessions are confirmed in parallel, and a check gives up after 8 s as «Нет связи», keeping every token (`DL-13` (4)); after 1.5 s a grey spinner and «Подключаемся…» appear under the wordmark and are announced.
  11. **The handoff** (`sys-2`, keeps `DL-76` (3)): the launch picture is a curtain over the router in `MaterialApp.router`'s builder; the bootstrap route itself is plain white. On the first answer the wordmark glides into the sign-in's wordmark (450 ms, no bounce) while the white fades; any other first page, and every handoff with reduced motion, fades the curtain out in 250 ms. Leaving «Нет связи» for the app fades that screen's last picture out over the app the same way. Routes still replace in place (`DL-124`): a route fade would start from black, because go_router removes the bootstrap page at once (`DL-135` (7)), and a `Hero` does not fly when the old page is completed rather than popped.
  12. **A fixed wordmark** (`sys-3`): the wordmark is a logo and ignores text scaling; a reader still hears it.
  13. **«Нет связи»** (`sys-4`, `sys-5`): a grey 64 px circle (`QuietIcon`, shared with the documents), title 20, body 15. No answer (a network failure or the 8 s cap) → «Нет связи / Проверьте мобильный интернет или Wi‑Fi. Приложение откроется само, когда связь появится.»; an answer that is an error → «BarakaBozor сейчас недоступен / Интернет на телефоне в порядке. Попробуйте через пару минут — приложение тоже проверит само.»
  14. **A pressed check** (`sys-6`): «Проверяем…» with a spinner for at least 0.8 s; a check that finds nothing writes «Связи пока нет · проверено в 9:41» (or «BarakaBozor пока недоступен · …») under the button with a medium haptic.
  15. **Checks of its own** (`sys-7`): the retry screen checks quietly 5, 10, 20 and 30 s apart, then every 30 s, and at once on returning to the app and when the phone's network comes back — `connectivity_plus`, the one new package, used for that event only; whether BarakaBozor answers is still decided by `/auth/me`. One check at a time; a press during a quiet check joins it. This supersedes `DL-28` (12) on this screen only: nothing else can be done there, and the check is the same harmless confirmation.
  16. **The wrong surface** (`sys-8`, `sys-9`): a grey icon. On a phone: «Откройте панель на компьютере», who signed in («Вы вошли как оператор — Азиз Каримов. Оператор работает в панели управления, в браузере на компьютере.»), «На этом телефоне можно делать покупки — войдите как покупатель с тем же номером.», and a green «Войти как покупатель» that ends the staff session on this phone: a Customer session already there opens the shop, otherwise the sign-in by number. The panel's twin: «Откройте приложение на телефоне», who, and a green «Войти другим аккаунтом» that ends the session and opens the panel's sign-in (a browser has no Customer side to offer).
  17. **The reader on system screens** (`sys-10`): «Подключаемся…» at 1.5 s; the busy button reads «Проверяем связь…»; then «Связи пока нет» / «BarakaBozor пока недоступен», or «Связь есть, открываем приложение».
  18. **Shared pieces:** core `QuietIcon`, `RetryStrip.busyLabel`, `kitAppBar(titleOpacity:, edgeOpacity:)`, `longDate`, `ConnectivitySignal`, `WordmarkLanding` with its registry.
  19. **How the repro items were reproduced:** by red tests on main's code, as in stages 11–16; each stays as the item's test (the lead fills in the red lines).
  20. **The lead's rulings while coding:** (none yet).
- [ ] **Step 5: Run** the new test and `test/features/admin/` (the preview) — green.
- [ ] **Step 6: Commit** — `feat(legal): reading text 16/26 with dark headings and a drawn dot; DL-136 (DL-136)`.

### Task 2: The reader's state and the saved copies

**Files:**
- Create: `frontend/lib/features/legal/application/legal_reader.dart`
- Modify: `frontend/test/support/fake_legal_repository.dart` (a per-call hold and answers per language, if it lacks them)
- Test: create `frontend/test/features/legal/application/legal_reader_test.dart`

**Interfaces:**
- Consumes: `legalRepositoryProvider`, `languageControllerProvider`, `ApiFailure`.
- Produces:
  - `final class LegalReading { const LegalReading({LegalDocument? document, bool unpublished = false, ApiFailure? failure, bool loading = false}); }` — `document` is the text on screen (fresh or the copy); `failure` is the last load's; `loading` is true while a load is out.
  - `final class LegalCopies { LegalDocument? of(LegalDocumentKind kind, AppLanguage language); void keep(LegalDocumentKind kind, AppLanguage language, LegalDocument document); void drop(LegalDocumentKind kind, AppLanguage language); }` and `final Provider<LegalCopies> legalCopiesProvider` (kept alive; a plain map, not provider state). Keyed by the interface language, not the document's.
  - `legalReaderProvider` — `NotifierProvider.autoDispose.family<LegalReader, LegalReading, LegalDocumentKind>`; `LegalReader.retry()` returns `Future<void>`.
- Rules: `build` watches the interface language; while it is unknown → `LegalReading(loading: true)`. With a copy → `LegalReading(document: copy, loading: true)` and a load; without → `LegalReading(loading: true)` and a load (started after `build` returns). A document → kept as the copy and shown; `null` → copy dropped, `unpublished: true`; a failure → the document on screen stays, `failure` set. `retry()` does nothing while loading; otherwise `loading: true` keeping the rest, and loads. An answer that comes after the language changed or the reader was disposed is not shown (it may still become its own language's copy).

- [ ] **Step 1: Write the failing tests:** `'a first open loads and keeps a copy'`; `'a second open shows the copy at once and refreshes it'` (the second answer's blocks replace the copy's); `'offline with a copy keeps the copy and the failure'`; `'offline without a copy has only the failure, and retry loads'`; `'unpublished drops the copy'`; `'an answer for another language is not shown'` (Review Focus 2: hold the ru answer, switch to uz, release: the uz reading never shows ru blocks); `'retry while loading sends nothing more'` (the repository saw one call).
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** `legal_reader.dart`.
- [ ] **Step 4: Run** the new test — green.
- [ ] **Step 5: Commit** — `feat(legal): a reader that keeps a copy per language and refreshes it quietly (DL-136)`.

### Task 3: The page

**Files:**
- Modify: `frontend/lib/features/legal/presentation/legal_screen.dart` (a `ConsumerStatefulWidget` on `legalReaderProvider`; loaded face only — until Task 4 the other states keep a plain spinner / the old `LoadFailure` / the old line), `frontend/lib/features/legal/application/legal_providers.dart` (`legalDocumentProvider` goes), `frontend/lib/core/widgets/kit_app_bar.dart`, `frontend/lib/features/profile/presentation/profile_rows.dart` (`legalPrivacy`), the two ARB files
- Create: `frontend/lib/core/formatting/long_date.dart`
- Test: `frontend/test/features/legal/presentation/legal_screen_test.dart`, `frontend/test/core/formatting/long_date_test.dart`; the profile tests that read «Конфиденциальность»

**Interfaces:**
- Consumes: `legalReaderProvider`, `LegalReading` (Task 2); `LegalBlocks` (Task 1); `ListScrollIndicator`.
- Produces: `AppBar kitAppBar({…, ValueListenable<double>? titleOpacity, ValueListenable<double>? edgeOpacity})` — with `titleOpacity` the title is drawn at that opacity and is silent to a reader; with `edgeOpacity` a 1 px `buttonOff` line is the bar's bottom at that opacity. `String longDate(AppLocalizations l10n, DateTime instant)` — the Tashkent date through `dateLong` and `monthLong`.
- Keys: `legal-screen` (scaffold, as now), `legal-title`, `legal-date`, `legal-language-note`, `legal-column`, `legal-scroll`.
- Rules: the column (title, date, note, blocks) is a `SingleChildScrollView` with a `ScrollController`, inside `SelectionArea` and `ListScrollIndicator(fullExtent: (m) => m.maxScrollExtent + m.viewportDimension)`; the large title's bottom comes from its `GlobalKey`. The selection menu's buttons come from `SelectableRegionState.contextMenuButtonItems` with the copy and select-all labels replaced by `legalCopy` / `legalSelectAll`. The date's semantics label is `legalEditionSpoken(longDate(…))`.

- [ ] **Step 1: Write the failing tests:**
  - `'the profile row and the screen share one name'` — the profile's privacy row reads «Политика конфиденциальности»; the opened screen's `legal-title` the same.
  - `'the large title is the heading and the bar title fades in on scroll'` — at offset 0 the bar's title opacity is 0 and has no semantics node, `legal-title` is a header; scrolled to the title's bottom − 15 → about 0.5; past it → 1; the hairline 0 at 0, 0.5 at 4, 1 at 8.
  - `'the title grows slower than the body at large text'` — `TextScaler.linear(2)`: title 38, a heading 36, a paragraph 32; the title wraps, nothing is cut.
  - `'the date reads in words'` (**repro** `docs-9`) — shown «Редакция от 19 октября 2026», read «Редакция от 19 октября 2026 года»; in Uzbek «Tahrir: 2026-yil 19-oktabr»; `long_date_test.dart` pins all twelve months in both languages and the Tashkent day at 21:30 UTC.
  - `'landscape keeps the text clear of the cutout in a 600 column'` (**repro** `docs-3`) — 700 × 360 dp, `tester.view.padding` left 48 dp: `legal-column` at most 600 wide, centred in the 652 between the cutout and the right edge; the first paragraph's left ≥ 48 + 20.
  - `'a document in another language says so'` — Uzbek interface, Russian document: `legal-language-note` «Bu hujjat hozircha faqat rus tilida.» under the date; same language: no note.
  - `'scrolling shows a thin indicator'` (**repro** `docs-7`) — after a drag `scroll-indicator` shows; 1.3 s after the last scroll its opacity is 0.
  - `'text can be selected and copied'` — a long press on a paragraph shows «Копировать» and «Выделить всё»; «Выделить всё» then «Копировать» puts text containing the first and the last block on the clipboard (`SystemChannels.platform` mock).
  - The guideline at 100 % and at `NonlinearTextScaler(2)` on the loaded page; the existing `'a long document holds at 320x640 with text x2'` stays green.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the page, `kitAppBar`'s two parameters, `longDate`, the strings and the profile row.
- [ ] **Step 4: Run** `legal_screen_test.dart`, `long_date_test.dart`, `test/features/profile/`, `test/core/widgets/` — green.
- [ ] **Step 5: Commit** — `feat(legal): one name, a large title that hands over to the bar, a 600 column clear of the cutout, selectable text (DL-136)`.

### Task 4: Loading, failures and the copy's strip

**Files:**
- Create: `frontend/lib/core/widgets/kit/quiet_icon.dart`, `frontend/lib/features/legal/presentation/legal_states.dart` (skeleton and centred state)
- Modify: `legal_screen.dart`, `frontend/lib/core/widgets/retry_strip.dart` (`busyLabel`), the two ARB files
- Test: `legal_screen_test.dart`, `frontend/test/core/widgets/quiet_icon_test.dart`, `retry_strip_test.dart`

**Interfaces:**
- Consumes: `LegalReading`, `LegalReader.retry()` (Task 2); the page (Task 3).
- Produces: `QuietIcon({required IconData icon, super.key})` — 64 circle `KitColors.chip`, the icon 30 `ink2`, silent to a reader. `RetryStrip(…, String? busyLabel)` — non-null: the button shows a 16 px spinner in its colour instead of «Повторить», takes no tap and reads `busyLabel`.
- Keys: `legal-skeleton`, `legal-failed`, `legal-retry`, `legal-unpublished`, `legal-back`, `legal-stale` (the strip's `stripKey`), `legal-stale-retry`.
- Rules: faces from `LegalReading` — a document → the page (with the strip when `failure` is set); none and `unpublished` → the unpublished state; none and `failure` → the failed state (busy while `loading`); none otherwise → the skeleton. The text fades in when a document arrives on a page that showed the skeleton. «Назад» pops, or goes to `AppPaths.bootstrap` when nothing is under the page. Announcements: «Загружаем документ…» when the skeleton first shows, «Документ не загрузился. {reason}», «Документ пока не опубликован», «Загружаем…» on a pressed retry, the strip's words when it first shows.

- [ ] **Step 1: Write the failing tests:**
  - `'a first open shows the title and a skeleton, then fades the text in'` (**repro** `docs-9`) — held answer: `legal-title` shown, `legal-skeleton` read «Загружаем документ…» and announced, no `CircularProgressIndicator`; released: at 100 ms the text's opacity is between 0.3 and 0.8, at 200 ms 1; with reduced motion 1 at once.
  - `'a second open is instant from the copy'` — open, back, open with a held answer: the text is there on the first frame, no skeleton, no announcement.
  - `'offline without a copy shows the centred state'` — `legal-failed`: `QuietIcon` `Icons.wifi_off`, «Документ не загрузился», «Нет связи с интернетом. Проверьте подключение и нажмите «Повторить».»; `legal-retry` → «Загружаем…» with a spinner, announced; the answer → the text.
  - `'a failure that is not the network says so'` — `UnexpectedFailure`: `Icons.error_outline`, «Не удалось загрузить документ. Нажмите «Повторить».».
  - `'offline with a copy keeps it under a strip'` — second open fails: the text stays, `legal-stale` «Нет связи — показана сохранённая копия», announced; `legal-stale-retry` busy, then the strip goes on success.
  - `'an unpublished document says to come back later'` — «Документ пока не опубликован», «Загляните позже.»; `legal-back` (white, `outline` frame) returns to the profile.
  - `quiet_icon_test.dart` `'a grey 64 circle with a silent icon'`; `retry_strip_test.dart` `'a busy strip spins, takes no tap and reads its label'`.
  - The guideline at 100 % and at `NonlinearTextScaler(2)` for the skeleton, failed, busy, unpublished and the strip.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the states, `QuietIcon`, `busyLabel`, the strings; drop `legalNotPublishedYet`.
- [ ] **Step 4: Run** `test/features/legal/`, `test/core/widgets/`, `test/features/profile/`, then `flutter analyze` — green.
- [ ] **Step 5: Commit** — `feat(legal): a skeleton, a copy at once, calm failure and unpublished states, a strip over the copy (DL-136)`.

### Task 5: Confirming sessions at once, the cap, the cause and the checks

**Files:**
- Modify: `frontend/lib/core/session/session_state.dart`, `frontend/lib/core/session/session_controller.dart`, `frontend/test/support/fake_auth_repository.dart` (a hold per slot and a call count per slot, if missing)
- Test: `frontend/test/core/session/session_controller_test.dart`

**Interfaces:**
- Produces: `enum UnreachableCause { offline, server }`; `SessionUnreachable({bool retrying = false, UnreachableCause cause = UnreachableCause.offline, DateTime? checkedAt})`; `Future<void> SessionController.retry({bool quiet = false})`; `static const Duration SessionController.checkCap = Duration(seconds: 8)` and `leastPressedCheck = Duration(milliseconds: 800)`.
- Rules: `_bootstrap` asks every stored slot at once; a `401` clears its slot as today; any `NetworkFailure` or the cap → `SessionUnreachable(cause: offline)`; otherwise any other `ApiFailure` → `cause: server`; otherwise `SignedIn` / `SignedOut` as today. The cap is a `Timer`; the bootstrap that hit it ignores later answers, except that a `401` still clears its slot. `retry`: does nothing unless the state is `SessionUnreachable`; a pressed retry sets `retrying: true` at once and holds the result until 800 ms after the press; one check runs at a time and a second call joins it (a press upgrades a quiet check). The result: success → that state; unreachable → `retrying: false`, its cause, and `checkedAt` = `clockProvider` now when a press is waiting on it, the old `checkedAt` refreshed to now when one was shown, else none; a throw → reported, `SessionUnreachable(cause: offline)` keeping `checkedAt`. Timers cancelled in `ref.onDispose`.

- [ ] **Step 1: Write the failing tests** (`fakeAsync`):
  - `'both slots are asked at once'` — with both held, the repository saw both `me` calls before either answers.
  - `'the cap keeps every token and a late refusal clears only its slot'` (Review Focus 3) — at 8 s `SessionUnreachable(cause: offline)` and both tokens stored; a `401` for the customer slot released at 9 s clears that slot only; the state is still unreachable.
  - `'an error answer is the server, no answer is offline'` — `ApiRefusal` 500 → `server`; `MalformedResponseFailure` → `server`; `NetworkFailure` → `offline`; a `401` on one slot and a user on the other → `SignedIn` with that one.
  - `'a pressed retry holds 0.8 s and stamps the time when it fails'` — answer in 50 ms: `retrying` until 800 ms, then `retrying: false` and `checkedAt` = the fake clock.
  - `'a pressed retry that succeeds still holds 0.8 s'`.
  - `'a quiet retry shows nothing and refreshes only a shown time'`.
  - `'a pressed retry joins a quiet check and holds 0.8 s'` (Review Focus 1) — one `me` per slot in all.
  - `'disposing mid-check leaves no timer'` — `container.dispose()`, then no pending timers.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**; the old tests about slots confirmed one after another are rewritten to the parallel order.
- [ ] **Step 4: Run** `test/core/session/`, `test/core/routing/session_redirect_test.dart`, `test/app/` — green.
- [ ] **Step 5: Commit** — `feat(session): stored sessions are confirmed at once, give up at 8 s and say why (DL-136)`.

### Task 6: «Нет связи»

**Files:**
- Modify: `frontend/pubspec.yaml`, `pubspec.lock` (`connectivity_plus`), `frontend/lib/app/providers.dart`, `frontend/lib/features/auth/presentation/unreachable_screen.dart`, `frontend/lib/features/auth/presentation/auth_scaffold.dart` (`AuthStatusScaffold`: `QuietIcon`, 20 / 15, `note`, `footnote`), `frontend/test/support/app_harness.dart`, the two ARB files
- Create: `frontend/lib/core/network/connectivity_signal.dart`, `frontend/test/support/fake_connectivity_signal.dart`
- Test: create `frontend/test/features/auth/presentation/unreachable_screen_test.dart`; `surface_and_unreachable_test.dart`

**Interfaces:**
- Consumes: `SessionUnreachable`, `UnreachableCause`, `retry({quiet})` (Task 5); `QuietIcon` (Task 4); `SubmitButton`; `announce`; `TashkentTime.time`.
- Produces: `abstract interface class ConnectivitySignal { Stream<void> get regained; }`; `PluginConnectivitySignal` over `Connectivity().onConnectivityChanged` — emits when the results go from all `ConnectivityResult.none` to anything else, never on the first event; `final Provider<ConnectivitySignal> connectivitySignalProvider`. `UnreachableView({required SessionUnreachable state, VoidCallback? onRetry, super.key})` — the screen's whole picture from the state alone; `onRetry` null draws it still (Task 8's handoff). `AuthStatusScaffold({…, String? note, Widget? footnote})`.
- Keys: `retry-button` (`SubmitButton.buttonKey`, as now), `unreachable-title`, `unreachable-checked`.
- Rules: `UnreachableScreen` is a `ConsumerStatefulWidget` with `WidgetsBindingObserver`; it runs the quiet series, the resume check and the network check (Global Constraints, «Timing»), restarts the series after a pressed check ends, and stops all of it in `dispose`. While busy the button reads «Проверяем…» and the reader hears only «Проверяем связь…». On a pressed check's end: unreachable → `mediumImpact` and announce the result («Связи пока нет» / «BarakaBozor пока недоступен»); success (any check) → announce «Связь есть, открываем приложение». The footnote shows while `checkedAt` is set: `unreachableCheckedAt(result, TashkentTime.time(checkedAt))`, read as `unreachableCheckedAtSpoken`.

- [ ] **Step 1: Write the failing tests:**
  - `'no answer says Нет связи with a grey icon'` — `QuietIcon` `Icons.wifi_off`, no `StatusHalo`; «Нет связи» 20, «Проверьте мобильный интернет или Wi‑Fi. Приложение откроется само, когда связь появится.» 15.
  - `'an error answer says BarakaBozor is down'` — `cause: server`: `Icons.cloud_off`, «BarakaBozor сейчас недоступен», «Интернет на телефоне в порядке. Попробуйте через пару минут — приложение тоже проверит само.».
  - `'a pressed retry shows Проверяем… then the checked time'` — the clock at 04:41 UTC: busy «Проверяем…» with a spinner; then `unreachable-checked` «Связи пока нет · проверено в 9:41» fading in, one `HapticFeedback.mediumImpact` on `SystemChannels.platform`.
  - `'a check is spoken and its result too'` (**repro** `sys-10`) — announcements «Проверяем связь…» then «Связи пока нет»; while busy no semantics label contains «недоступна»; a later success announces «Связь есть, открываем приложение».
  - `'the screen checks by itself at 5, 10, 20 and 30 s'` — `me` calls at 5 s, 15 s, 35 s, 65 s, then 95 s, none in between.
  - `'returning to the app or the network checks at once'` — `paused` → `resumed` makes a call; the fake signal's event makes a call.
  - `'a flapping network starts one check at a time'` (Review Focus 4) — a held answer, three network events and a resume: one call.
  - `'leaving the screen stops the checks'` — a check succeeds and the app opens; 60 s later no new call.
  - `'at large text the screen scrolls without overflow'` — 360 × 640, `NonlinearTextScaler(2)`, the server words and the checked line: no overflow; the guideline passes idle, busy and checked, and at 100 %.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**: add the package, the signal and its provider, the harness's silent fake, `AuthStatusScaffold`'s changes (the wrong-surface screen keeps working on them until Task 7), the view and the screen; the old unreachable strings go.
- [ ] **Step 4: Run** `test/features/auth/`, `test/core/session/`, `test/app/`, then `flutter analyze` — green; `flutter build web` still passes with the plugin and its Wasm dry run reports no incompatibility.
- [ ] **Step 5: Commit** — `feat(auth): a calm «Нет связи» that tells a dead network from a broken server and checks itself; connectivity_plus for the network event (DL-136)` — the message says why the package is added.

### Task 7: The wrong surface

**Files:**
- Modify: `frontend/lib/features/auth/presentation/wrong_surface_screen.dart`, the two ARB files
- Test: `frontend/test/features/auth/presentation/surface_and_unreachable_test.dart`

**Interfaces:**
- Consumes: `AuthStatusScaffold(note:)`, `QuietIcon` (Tasks 4, 6); `SubmitButton`; `SessionController.logout(SessionMode)`; `AppUser.role`, `AppUser.fullName`.
- Keys: `wrong-surface-text` (the who sentence, as now), `wrong-surface-button` (new, on the green button; `logout-button` is dropped from this screen and its tests move).
- Rules: on a phone the icon is `Icons.computer`, the title `wrongSurfacePanelTitle`, the body the who sentence (nameless when `fullName` is empty), the note `wrongSurfacePanelShop`, the button `wrongSurfaceSignInCustomer`; in a browser `Icons.smartphone`, `wrongSurfaceAppTitle`, its who sentence, no note, `wrongSurfaceOtherAccount`. Both buttons call `logout(session.activeMode)`; nothing shows while not signed in, as now.

- [ ] **Step 1: Write the failing tests:**
  - `'an Operator on a phone is told who and where'` — «Откройте панель на компьютере», «Вы вошли как оператор — Азиз Каримов. Оператор работает в панели управления, в браузере на компьютере.», «На этом телефоне можно делать покупки — войдите как покупатель с тем же номером.», `QuietIcon` `Icons.computer`; an Admin and a Manager get their words; no name → «Вы вошли как оператор. Оператор работает …».
  - `'Войти как покупатель ends the staff session and opens the sign-in'` — no Customer session: the phone sign-in shows, the staff token is gone.
  - `'with a Customer session on the phone it opens the shop'` — the Customer home shows and the customer token stays.
  - `'a Shopper in a browser is told to open the phone app'` — «Откройте приложение на телефоне», «Вы вошли как сборщик — …. Сборщик работает в приложении BarakaBozor на телефоне.», green «Войти другим аккаунтом» → the staff sign-in; a Customer in a browser gets the «покупатель» sentence.
  - The guideline at 100 % and `NonlinearTextScaler(2)` on both faces, no overflow at 360 × 640.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**; the old wrong-surface strings go.
- [ ] **Step 4: Run** `test/features/auth/`, `test/core/routing/` — green.
- [ ] **Step 5: Commit** — `feat(auth): the wrong surface names who signed in and offers «Войти как покупатель» (DL-136)`.

### Task 8: The launch curtain and the handoff

**Files:**
- Create: `frontend/lib/app/session_handoff.dart`, `frontend/lib/core/widgets/wordmark_landing.dart`
- Modify: `frontend/lib/main.dart` (`builder: (context, child) => SessionHandoff(child: child!)`), `frontend/lib/app/router.dart` (`_BootstrapScreen` plain white), `frontend/lib/core/widgets/brand_wordmark.dart` (fixed size), `frontend/lib/features/auth/presentation/auth_scaffold.dart` (the 26 and 30 wordmarks inside `WordmarkLanding`), the two ARB files
- Test: create `frontend/test/app/session_handoff_test.dart`; rewrite `test/app/bootstrap_screen_test.dart`; tests that meet the first page during launch settle the handoff

**Interfaces:**
- Consumes: `sessionControllerProvider` and its states (Task 5); `UnreachableView` (Task 6); `announce`.
- Produces: `final class WordmarkLandingRegistry { void attach(GlobalKey key); void detach(GlobalKey key); GlobalKey? get current; final ValueNotifier<bool> hidden; }`; `WordmarkLandingScope({required WordmarkLandingRegistry registry, required Widget child})` with `static WordmarkLandingRegistry? maybeOf(BuildContext context)`; `WordmarkLanding({required Widget child, super.key})` — attaches its own `GlobalKey` while mounted (the last attached is `current`), draws its child at opacity 0 (kept in layout) while `hidden` is true, and is just its child without a scope. `SessionHandoff({required Widget child, super.key})` — a `ConsumerStatefulWidget` that provides the scope around `child` and stacks the curtain over it. Keys: `launch-curtain`, `launch-wordmark`, `launch-hint`, `handoff-ghost`.
- Rules: the curtain shows from the first frame while the session has neither a value nor an error: white, the launch wordmark (fading in), the hint at 1.5 s (announced «Подключаемся…»). On the first value or error it waits for the end of the next frame (the router has built the page); if motion is allowed and `current` is laid out on screen, it glides (Global Constraints, «Motion») with `hidden` true until 540 ms; otherwise it fades out in 250 ms. When the state goes from `SessionUnreachable` to `SignedIn` or `SignedOut`, the curtain draws `UnreachableView(state: <the last unreachable state>)` and fades it out in 250 ms. While leaving, the curtain is `IgnorePointer` and silent to a reader; when done it leaves the tree. Nothing else (a logout, a mode switch) shows it.

- [ ] **Step 1: Write the failing tests:**
  - `'the start says Подключаемся… after 1.5 s'` (**repro** `sys-10`) — held answers: on the first frame `launch-wordmark`'s opacity is below 1, 1 at 150 ms; no `launch-hint` at 1.4 s; at 1.8 s the hint with a `muted` spinner and «Подключаемся…», announced once.
  - `'the wordmark glides to the sign-in'` (**repro** `sys-2`) — no stored session: at 225 ms of the leave `handoff-ghost`'s centre lies strictly between the screen's centre and the landing's centre and the landing's wordmark opacity is 0; at 540 ms no `launch-curtain` and the landing's opacity is 1.
  - `'other first pages cross-fade'` — a stored Customer session: the curtain's opacity at 125 ms between 0.3 and 0.7, gone at 250 ms, no ghost.
  - `'taps reach the page while the curtain leaves'` (Review Focus 5) — a tap on the home's search at 100 ms opens search.
  - `'reduced motion fades instead of gliding'` — no stored session, `disableAnimations`: no ghost; the curtain fades over 250 ms.
  - `'the wordmark keeps its size at large text'` (**repro** `sys-3`) — 320 × 640, `TextScaler.linear(2)`: the launch wordmark is one line under 50 high; the sign-in's is one line; a reader still finds «BarakaBozor».
  - `'leaving Нет связи fades its last picture over the app'` — unreachable, press retry, success: at 0 ms of the leave the curtain shows «Нет связи» and «Проверяем…» over the home, at 250 ms it is gone.
  - `'a first answer of Нет связи fades to the retry screen'` and `'a reload into a panel page fades the curtain'` (Review Focus 5) — web surface, an Operator's stored session, initial location `/operations`: the board shows when the curtain is gone; no ghost.
  - The guideline at 100 % and `NonlinearTextScaler(2)` on the curtain with the hint.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement** the registry and landing, the handoff, the builder, the plain bootstrap page, the fixed wordmark and the landings in `AuthScaffold`.
- [ ] **Step 4: Run** the full frontend suite (`--concurrency=1`), `flutter analyze` and `dart format --set-exit-if-changed lib test` — green; tests that broke only because the handoff had not ended are fixed by letting it end, and the report lists them.
- [ ] **Step 5: Commit** — `feat(app): the launch curtain says «Подключаемся…», glides the wordmark into the sign-in and fades «Нет связи» into the app (DL-136)`.

### After the tasks (the lead)

- [ ] `DL-136` (19) and (20) completed; the full suite, the final review, one fix wave, `/security-review`, the pull request, the walk on the emulator (start offline → «Нет связи» → network back; the sign-in glide; a document at 200 % and in landscape) with 3–5 shots, and the closing report.
