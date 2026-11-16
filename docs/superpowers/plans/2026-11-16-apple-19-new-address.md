# Apple Stage 19 — «Новый адрес» Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The new-address flow as the test draws it: «Новый адрес» with «Шаг 1 из 2 · точка на карте»; a pin that lifts while the Customer moves the map and drops with a squash and a light tap; the address Google knows under the pin, in the panel and under the preview (the Owner's item); the map opens where the phone is when the location is already allowed, else at the delivery address, and «Подтвердить точку» stays grey until the pin is placed; outside the delivery zone the map is dimmed behind a dashed edge and confirm is grey with how far; «Где я» says why it failed and offers the way out; a green «Найти» arrow with the answer right under the field; the map shrinks into the preview and grows back; the fields lead with «Далее», check on leaving, bring the first gap into view and shake it, and saving stays green with «Сохраняем…» then ✓; back from a filled map asks «Выйти без сохранения?»; large text and the screen reader are served.

**Architecture:** Two Customer endpoints: `GET /customer/service-area` (the zone's centre and radius, or null) and `POST /customer/address-search/reverse` (the address under a point, display only, under the search's limits and Google key). The client's address-search repository gains `addressAt` and `serviceArea`; `DeviceLocation` says why it failed and can read silently when already allowed; `AddressMap.picker` reports the start of the Customer's move and draws the zone. The map step owns the pin, the hint, the search answer, the panel (address, zone, why) and the confirm rule; the form owns the morph between the steps, the fields, the save sequence and the leave sheet. New shared pieces: `kitAppBar`'s subtitle and `Shake` in `core/`.

**Tech Stack:** Laravel 13 + PostgreSQL (`Http::fake`, `RateLimiter`, `Log::spy`); Flutter 3.47.5, flutter_riverpod 3.4.3, google_maps_flutter ^2.18.2 (`Polygon.holes`, `Polyline.patterns`), geolocator ^14.1.1 (`openAppSettings`, `openLocationSettings`); core `announce`, `SkeletonBar`, `showKitSheet`, `kitFilled`, `textScaleAt` (`DL-126`); flutter_test (`takeAnnouncements`, `meetsGuideline(iOSTapTargetGuideline)`, `NonlinearTextScaler`, `SystemChannels.platform` mock for haptics).

**Spec:** `tasks/APPLE_BATCH.md` stage 19 (`naddr-1` … `naddr-12`; `naddr-3` **Owner**; `naddr-3`, `naddr-5` **server**; `naddr-9`, `naddr-11`, `naddr-12` **repro**). The live test «Тест нового адреса - Apple», local copy `G:/tools/tmp/w-naddr/site/naddr.html` (CSS `.ab .stp .pin .psh .map.lift .sf .sib.go .sres .hint .pnl .pa .pat .ptx .zo .why .pbtn.off .pv .pvb.big .pvl .f .in .er .two.st .ft .sbtn .spin .shake .lsh .lgo .snk .sna`; script `rest`, `dropPin`, `submit`, `locate`, `canConfirm`, `go`, `animIn`, `save`, `toError`, `onBlur`, `onEnter`, `back`, `dirty`, `leaveText`, `hintGone`, `ptxText`, `zoText`, `stops`).

## Global Constraints

- Changes stay in `backend/`, `frontend/`, `docs/` and `tasks/`. No migration, no package; `pubspec.lock` and `composer.lock` untouched. Generated localizations come from `flutter gen-l10n`, never by hand.
- **Server** (`AGENTS.md` §5): both endpoints take a Customer session. Neither the point nor Google's answer is stored or logged; a provider failure logs only `address_search.provider_failed` with `reason` and `lookup: reverse`; the key never reaches a log or a message. Reverse lookups have their own counters with the search's numbers: 10 a minute and 30 a day per Customer (`address-reverse:minute:{id}`, `address-reverse:day:{id}`), a lookup counting when it starts. Same key, so the Owner's Google Cloud quota covers both. The zone on the phone is a preview: the server still refuses a saved point outside (`address_outside_service_area`, `_SaveFailure` unchanged).
- **Lookups from the phone** (Google content beside a Google map only): only on a movable map, only for a placed pin at rest, 400 ms after it came to rest with no new move, never again for a point within 15 m of the last looked-up one (its answer is reused); a newer move or lookup drops an older answer. The language sent is the app's (`uz` or `ru`).
- **Placed and confirmable.** A new address opens unplaced; the pin becomes placed by the Customer's own move coming to rest, a search's point, «Где я», or the silent fix at open. An edit's map, and the map reopened from the details, open placed; the coordinate-fields map counts as placed. `confirmable = placed && !outside && !moving && !locating`. Not placed or outside: the button is drawn off and does nothing; while moving or locating it keeps its green and ignores taps. `outside` is `zone != null && !zone.contains(point)` for the point at rest.
- New strings (ru / uz). Map step: `addressStepPoint` «Шаг 1 из 2 · точка на карте» / «2 qadamdan 1-chisi · xaritadagi nuqta»; `addressStepDetails` «Шаг 2 из 2 · подъезд и квартира» / «2 qadamdan 2-chisi · podyezd va xonadon»; `addressStepPointSpoken` «Новый адрес, шаг 1 из 2: точка на карте» / «Yangi manzil, 2 qadamdan 1-chisi: xaritadagi nuqta»; `addressStepDetailsSpoken` «Новый адрес, шаг 2 из 2: подъезд и квартира» / «Yangi manzil, 2 qadamdan 2-chisi: podyezd va xonadon»; `addressPointTextLarge` «Передвиньте карту, чтобы метка встала на вход в дом. Квартиру и подъезд укажете на следующем шаге.» / «Xaritani suring: belgi uy kirish joyida tursin. Xonadon va podyezdni keyingi qadamda kiritasiz.»; `addressOpenedAt` «Карта открыта у вашего адреса «{name}». Передвиньте её так, чтобы метка встала на вход нового дома.» / «Xarita «{name}» manzilingizda ochildi. Uni suring: belgi yangi uy kirish joyida tursin.»; `addressMoveFirst` «Сначала передвиньте карту к дому» / «Avval xaritani uyga suring»; `addressConfirmWhyMove` «недоступна: сначала передвиньте карту» / «hozircha yopiq: avval xaritani suring»; `addressConfirmWhyZone` «недоступна: сюда не возим» / «hozircha yopiq: bu yerga yetkazmaymiz»; `addressPlaceNoHouse` «Дом не определили — поставьте метку на здание» / «Uy aniqlanmadi — belgini binoga qo'ying»; `addressPlaceUnknown` «Адрес не определили» / «Manzil aniqlanmadi»; `addressPlaceUnknownHint` «Поставьте метку на здание» / «Belgini binoga qo'ying»; `addressPlaceLooking` «Ищем адрес» / «Manzil qidirilmoqda»; `addressOutsideZone` «Сюда пока не возим: до метки {distance} км, а возим в радиусе {radius} км. Передвиньте метку ближе к городу.» / «Bu yerga hozircha yetkazmaymiz: belgigacha {distance} km, biz esa {radius} km radiusda yetkazamiz. Belgini shaharga yaqinroq suring.»; `addressOutsideZoneSpoken` «Сюда пока не возим: {distance} километра, возим в радиусе {radius}» / «Bu yerga hozircha yetkazmaymiz: {distance} kilometr, {radius} kilometr radiusda yetkazamiz».
  - Search and «Где я»: `addressSearchGo` «Найти» / «Topish»; `addressSearchFoundAt` «Нашли: «{query}». Проверьте, что метка на вашем доме.» / ««{query}» topildi. Belgi uyingizda turganini tekshiring.»; `addressSearchNotFoundAt` «Не нашли «{query}». Передвиньте карту к дому сами.» / ««{query}» topilmadi. Xaritani uyga o'zingiz suring.»; `addressSearchDown` «Поиск сейчас не работает. Передвиньте карту сами.» / «Qidiruv hozir ishlamayapti. Xaritani o'zingiz suring.»; `addressFoundSpoken` «Нашли адрес. Метка передвинута» / «Manzil topildi. Belgi surildi»; `addressLocatedSpoken` «Метка там, где вы» / «Belgi siz turgan joyda»; `addressLocationDenied` «Доступ к геолокации запрещён. Разрешите в настройках или передвиньте карту сами.» / «Joylashuvga ruxsat berilmagan. Sozlamalarda ruxsat bering yoki xaritani o'zingiz suring.»; `addressLocationSettings` «Настройки» / «Sozlamalar»; `addressLocationOff` «Геолокация на телефоне выключена.» / «Telefonda joylashuv o'chirilgan.»; `addressLocationTurnOn` «Включить» / «Yoqish»; `addressLocationSlow` «Не нашли вас за 10 секунд. Передвиньте карту сами.» / «10 soniyada sizni topa olmadik. Xaritani o'zingiz suring.»; `addressLocationAgain` «Ещё раз» / «Yana bir bor».
  - Reader: `addressSearchSpoken` «Адрес словами. Найдём и передвинем метку» / «Manzil so'z bilan. Topib, belgini suramiz»; `addressMapSpoken` «Карта, метка в центре.» / «Xarita, belgi markazda.»; `addressMapPinSpoken` «Метка: {line}.» / «Belgi: {line}.»; `addressMapWaySpoken` «Без карты метку ставят поиском или кнопкой «Где я»» / «Xaritasiz belgi qidiruv yoki «Men qayerdaman» tugmasi bilan qo'yiladi»; `addressMyLocationSpoken` «Где я: поставить метку туда, где вы» / «Men qayerdaman: belgini siz turgan joyga qo'yish»; `fieldRequiredSpoken` «{label}, обязательное поле» / «{label}, majburiy maydon»; `fieldOptionalSpoken` «{label}, необязательно» / «{label}, ixtiyoriy»; `addressFieldMissingSpoken` «Заполните поле «{label}»» / ««{label}» maydonini to'ldiring»; `addressChangePointSpoken` «Изменить точку на карте» / «Xaritadagi nuqtani o'zgartirish».
  - Details and leaving: `addressOptional` «{label} · необязательно» / «{label} · ixtiyoriy»; `addressSaving` «Сохраняем…» / «Saqlanmoqda…»; `addressSavedButton` «Сохранено» / «Saqlandi»; `addressPinLine` «Метка: {line}» / «Belgi: {line}»; `addressLeaveTitle` «Выйти без сохранения?» / «Saqlamasdan chiqasizmi?»; `addressLeaveNamed` «Адрес не сохранится — «{name}», и всё, что вы ввели, пропадёт.» / ««{name}» manzili saqlanmaydi, kiritganlaringiz o'chib ketadi.»; `addressLeavePlain` «Адрес не сохранится, и всё, что вы ввели, пропадёт.» / «Manzil saqlanmaydi, kiritganlaringiz o'chib ketadi.»; `addressLeaveStay` «Продолжить ввод» / «Kiritishni davom ettirish»; `addressLeaveGo` «Выйти» / «Chiqish».
  - Reused: `addressNew`, `addressEdit`, `addressPointTitle` (the edit's map), `addressMapHint`, `addressPointText`, `addressSearchHint`, `addressWordsKept`, `addressMyLocation`, `addressLocationFailed`, `addressPointConfirm`, `addressChangePoint`, `fieldRequired`, the field labels. Removed when no longer used: `addressSearchFound`, `addressSearchNotFound`, `addressSearchUnavailable`.
- Drawing (from `naddr.html`). **Bar**: `kitAppBar` title 18 w700 `ink` with the subtitle 12 w500 `muted` height 1.3, 1 above, centred; toolbar height `max(56, 8 + 18 × 1.3 × textScaleAt(s, 18) + 1 + 12 × 1.3 × textScaleAt(s, 12))`. **Pin** 48 `Icons.location_on` `primary`, tip at the map's centre; shadow ellipse 14 × 6 `Color(0x47151D16)` at the centre. **Search field**: white, radius 14, elevation 3 shadow `0x33000000`, min height 50 (grows with the text), `Icons.search` 24 `muted` 14 from the left; suffix buttons 44 × 44 radius 11 — «Найти» `primary` fill with white `Icons.arrow_forward` (shown from 3 trimmed characters, not while searching), then × `muted` (while non-empty, not while searching); the spinner 20 alone while searching. **Result** 8 under the field: radius 12, padding 10 / 12, 8 gap, 13 `ink2` height 1.45, the query w700 `ink`; found white with shadow `0 2 10` `Color(0x1F151D16)` and `Icons.check_circle` 20 `primary`; not found `warningWash` with `Icons.travel_explore` 20 `warningDark`; unavailable `warningWash` with `Icons.cloud_off` 20 `warningDark`; the kept line 4 below, 13 w600 `primaryDark`. **Hint** 8 under the field or the result: radius 10, `Color(0xE6FFFFFF)`, padding 6 / 10, 12 `ink2` height 1.4. **«Где я»** as today (52, 16 from the right and bottom). **Panel** as today (white, radius 20 top, padding 16 / 20 / 16, at most half the height, its content scrolls) without a heading: the place row (min height 24, 8 below: filled `Icons.location_on` 24 `primary`, 10 gap; line 17 w700 `ink` height 1.35; sub 2 below, 13 `muted` height 1.4; while looking a `SkeletonBar` 62 % × 16, radius 6); the text 14 `ink2` height 1.45; the zone box 10 above (padding 12, radius 14, `dangerWash`, `Icons.wrong_location` 20 `danger`, 10 gap, 13 w500 `danger` height 1.45); the why line 12 above, 12 `ink2` height 1.4, centred; the button 54, radius 14, 16 w600, 14 above (8 under the why line); off: `line` fill and `muted` text. **Zone on the map**: outside dimmed `Color(0x21151D16)`, the edge `primary` 3 wide, dashes 12 / gaps 8. **Preview** 118 high, radius 16, the whole of it a button; the pill at 10 from its right and bottom: white, radius 22, min height 44, padding 0 / 14, shadow `0 1 4` `Color(0x33000000)`, `Icons.edit_location_alt_outlined` 20 `primary`, 6 gap, 14 w600 `ink`, at most the preview's width − 20, wrapping; under the preview, when the place is known, 8 above and 2 at the sides: filled `Icons.location_on` 18 `primary`, 6 gap, «Метка: …» 13 `ink2` height 1.4. **Fields** as today (label 12 w500 `muted`, 6 gap, fill `field`, radius 14, 14 below) without stars. **Save button** stays `primary` while saving: a 20 white spinner (stroke 2.5) or `Icons.check` 20, 10 gap, the text. **Leave sheet** (`showKitSheet`): the text 14 `ink2` height 1.5, 8 under the title; «Продолжить ввод» `kitFilled()` 22 below; «Выйти» a text button 50 high, 6 above, 16 w600 `danger`.
- Motion (none with reduced motion, `MediaQuery.disableAnimationsOf`, unless said). **Pin**: lifted while the Customer's move runs — up 14 in 160 ms `Cubic(0.2, 0.8, 0.2, 1)`, the shadow to scale 1.7 and 40 % opacity; at rest it drops from −14 through translate 0 with scale (1.07, 0.88) at 70 % to rest at 100 %, 280 ms `easeIn`, origin bottom centre. A fling's glide is Google's own. **Hint** fades out in 250 ms `easeOut` and never returns. **Result** comes in by opacity 0 → 1 and y −6 → 0 in 220 ms `Cubic(0.2, 0.8, 0.2, 1)` (reduced: opacity in 200 ms). **To the details**: the preview from the map's height, −16 margins and radius 0 to 118, 0 and 16 in 350 ms `Cubic(0.2, 0.8, 0.2, 1)`; the fields opacity 0 → 1 and y 48 → 0 in 320 ms after 80 ms, same curve; the footer y 100 % → 0 in 300 ms after 60 ms. **Back to the map**: the fields opacity 1 → 0 in 160 ms; the footer y 0 → 100 % in 260 ms `easeIn`; the preview grows back to the map's height, margins −16, radius 0 in 320 ms `Cubic(0.4, 0, 0.2, 1)`; then the map step, its panel rising from y 100 % in 300 ms `Cubic(0.2, 0.8, 0.2, 1)`. Reduced motion: the details fade in over 200 ms `easeOut`; back, they fade out over 160 ms `easeIn` and the map step fades in over 200 ms. **First gap**: the list scrolls so the field's label stands 12 below its top in 300 ms `Cubic(0.2, 0.8, 0.2, 1)` (a jump when reduced), then 20 ms later focus and `Shake` (x 0, −6, 5, −4, 2, 0 at 0 / 20 / 40 / 60 / 80 / 100 % of 360 ms `easeInOut`). **Saved**: ✓ «Сохранено» shows 450 ms (with reduced motion too), then the bar and the pop of `DL-137`.
- Haptics: `HapticFeedback.lightImpact` when the Customer's move comes to rest; `HapticFeedback.warningNotification` on a save with a gap.
- Snack bars: a «Где я» failure is a `SnackBar` of 4 s, with its action when it has one.
- Large text means `textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3` (`DL-126`); tests at large text use `NonlinearTextScaler(2)`, 320 × 640 for the map step and 360 × 640 for the details.
- Every face this branch draws passes `meetsGuideline(iOSTapTargetGuideline)` at 100 % and at `NonlinearTextScaler(2)` (batch rule): the map step (start, with a result, outside the zone), the details (with the preview line, saving), the leave sheet.
- Tests that pinned the old faces are rewritten, not deleted: «Точка доставки» as the new map's title and panel heading, the panel's amber notices and kept line, «Дом *», greyed fields and a grey button while saving, the step that drew no pin. No expectation about what reaches the server is dropped.
- Backend commands run as `docker compose -f docker/compose.yaml exec app …` from the repo root; PHPUnit with `--fail-on-warning`; never a destructive artisan command (`migrate:fresh`, `db:wipe`, `--env=testing` on the dev database). Flutter runs from PowerShell with `$env:TEMP='G:\tools\tmp'; $env:TMP='G:\tools\tmp'` and `G:\tools\flutter\bin\flutter.bat`; multi-file runs use `--concurrency=1`; no background jobs.
- Comments read like the surrounding code: short `///` docs in plain English that name `DL-138`. A test's first run is red, and the report quotes the red line.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `/security-review` once before the pull request: the branch sends a Customer's map point to Google through two new endpoints.

## Review Focus

1. The Customer moves the map again while a lookup is on its way: an answer for an older point never shows for a newer one, and a failed or limited lookup (`429`, `503`, no network) hides the row without blocking confirm. Task 5 tests `'a late answer for an older point is not shown'` and `'a failed lookup shows no row and confirm still works'`.
2. The zone is missing — unset, still loading or failed: nothing is called outside, confirm works, and the server's refusal still shows after saving. Task 5 test `'without a zone nothing is outside'`.
3. The silent fix at open arrives after the Customer touched the map, searched or pressed «Где я»: it moves nothing. Task 4 test `'a silent fix after a touch does not move the map'`.
4. Taps during a morph (a second confirm, back, the preview): one transition runs and the step ends where the last finished one says. Task 7 test `'a second confirm during the morph does nothing'`.
5. Back or the system back while saving, or with the leave sheet open: nothing leaves, nothing is lost, the save's answer still lands. Task 7 tests `'back while saving does nothing'` and `'system back asks too'`.

---

### Before the tasks (the lead)

- [x] **The test page.** Read 2026-11-16 from the local copy; this plan follows it. Its search answer named the house; ours answers only a point (`DL-86` (1)), so the line under the field quotes the Customer's words and the panel names the house under the pin (`DL-138` (7)).
- [x] **Google's price.** 2026-11-16, `developers.google.com/maps/billing-and-pricing`: Geocoding is an Essentials SKU with 10 000 free calls a month, forward and reverse together, then $5 per 1 000; the $200 monthly credit ended 2025-03-01. Quoted in `DL-138` (3).
- [ ] **Reproduce the repro items.** As in stages 11–18, the first red runs of these tests on main's code are the reproduction, quoted in `DL-138` (13): `naddr-9` — Task 6 `'saving with a gap brings it into view, focuses and shakes it'` (on main nothing scrolls); `naddr-11` — Task 4 `'large text drops the hint and the panel says it'` and Task 6 `'large text stacks house and apartment'`; `naddr-12` — Task 5 `'the map is one reader stop that names the pin'` and Task 6 `'a reader hears required and optional'` (on main «Дом *»).

### Task 1: The server names a point and gives the zone; the decision record

**Files:**
- Create: `backend/app/Modules/Customer/AddressSearch/PointAddress.php`, `backend/app/Modules/Customer/Actions/DescribePoint.php`, `backend/app/Modules/Customer/Http/Requests/AddressReverseRequest.php`, `backend/app/Modules/Customer/Http/Controllers/ServiceAreaController.php`
- Modify: `backend/app/Modules/Customer/AddressSearch/AddressGeocoder.php`, `GoogleGeocoder.php`, `UnconfiguredGeocoder.php`, `backend/app/Modules/Customer/Http/Controllers/AddressSearchController.php` (`reverse`), `backend/routes/api/v1/customer.php` (beside `address-search`)
- Test: create `backend/tests/Feature/Customer/AddressReverseApiTest.php`, `backend/tests/Feature/Customer/ServiceAreaApiTest.php` (Google faked as `AddressSearchApiTest` does)
- Docs: `docs/DECISIONS.md` (`DL-138`), `docs/09-api-contracts.md` §13 (two paragraphs), `docs/07-architecture.md` §11, `docs/03-features.md` §4 (one sentence), `docs/legal/privacy.ru.txt` and `privacy.uz.txt` (the Google line), `tasks/APPLE_BATCH.md` (row 18 → «Merged (PR #141)»)

**Interfaces:**
- Produces:
  - `AddressGeocoder::describe(string $latitude, string $longitude, string $language): ?PointAddress` — throws `GeocoderUnavailable`; `UnconfiguredGeocoder` always throws and sends nothing.
  - `final readonly class PointAddress { public function __construct(public string $line, public bool $houseKnown) }` — the line cut to 160 characters.
  - `DescribePoint::__invoke(User $customer, string $latitude, string $longitude, string $language): ?PointAddress`, `PER_MINUTE = 10`, `PER_DAY = 30` (Global Constraints, «Server»).
  - `POST /customer/address-search/reverse` (`customer.address-search.reverse`) body `latitude`, `longitude` (the create rules of `AddressRequest`), `language` (`in:uz,ru`); strict (an unknown field is `422`). Answers `{data: {line, house_known}}` or `{data: null}`; `429 rate_limited` with `Retry-After`; `503 provider_unavailable`.
  - `GET /customer/service-area` (`customer.service-area`) answers `{data: {latitude, longitude, radius_km}}` as `BusinessSettings` casts them (`"41.311081"`, `"10.00"`), or `{data: null}` while any of the three is unset.
- Google: `GET geocode/json` with `latlng` `"{lat},{lng}"`, `language`, `key`, timeouts as `locate`. The answer's first result whose `types` is not only `plus_code` gives the line from its `address_components`: route and `street_number` → `"{route}, {number}"`, house known; route and `premise` → `"{route}, {premise}"`, known; `premise` alone, known; route alone, not known; else the first of `neighborhood`, `sublocality_level_2`, `sublocality_level_1`, `sublocality`, `administrative_area_level_2`, `locality`, not known; none → null. `ZERO_RESULTS` → null; any other status, an HTTP or connection failure or an unreadable body → unavailable.

- [ ] **Step 1: Write the failing tests:**
  - `test_a_house_answers_its_street_and_number` — route «Navoiy ko'chasi», number «12»: `{line: "Navoiy ko'chasi, 12", house_known: true}`; `Http::assertSent` with `latlng=41.311081,69.240562`, `language=uz`, the key.
  - `test_a_street_without_a_number_is_not_a_house`; `test_a_premise_is_a_house`; `test_a_district_alone_is_named_without_a_house` («Qibray tumani»).
  - `test_plus_codes_are_skipped` — a `plus_code` result first, a route second: the route; only `plus_code` results: `null`.
  - `test_nothing_found_answers_null`.
  - `test_a_provider_failure_is_unavailable_and_reveals_nothing` — data set: connection, `500`, `REQUEST_DENIED`, unreadable: `503 provider_unavailable`; `Log::spy` sees only `address_search.provider_failed` with `reason` and `lookup`, and no logged value holds the coordinates or the key.
  - `test_without_a_key_the_lookup_is_unavailable` — `Http::assertNothingSent()`.
  - `test_the_point_and_language_are_validated` — a JSON number, seven decimals, `91`, `"en"`, a missing field, an unknown field: `422 validation_failed` on that field; nothing sent.
  - `test_only_a_customer_may_look_up` — as the search test checks it.
  - `test_lookups_are_limited_per_customer_apart_from_searches` — the 11th in a minute `429` with `Retry-After`; a search still answers; another Customer still looks up; the 31st in a day `429` (travel past the minute).
  - `ServiceAreaApiTest`: `test_the_configured_area_is_answered`, `test_an_unset_area_answers_null` (each of the three unset), `test_only_a_customer_may_read_it`.
- [ ] **Step 2: Run and see them fail** — `docker compose -f docker/compose.yaml exec app php artisan test --fail-on-warning --filter "AddressReverseApiTest|ServiceAreaApiTest"`; expected red: `404` for the unknown routes.
- [ ] **Step 3: Implement** the files listed.
- [ ] **Step 4: Run** the two new tests, `AddressSearchApiTest`, `pint --test`, `phpstan analyse` — green.
- [ ] **Step 5: Write `DL-138`** — «The Apple batch, stage 19: new address (2026-11-16, agent; item `naddr-3` Owner)», with these points (later tasks only add rulings to (14)):
  1. **The header** (`naddr-1`): «Новый адрес» with «Шаг 1 из 2 · точка на карте» / «Шаг 2 из 2 · подъезд и квартира» in the bar, spoken as one heading; the panel has no heading; the hint over the map fades after the first move. An edit keeps «Изменить адрес» and its map «Точка доставки», with no step line.
  2. **A living pin** (`naddr-2`): the step draws the pin; it lifts 14 px while the Customer's move runs and drops with a squash and a light tap when the map rests. A fling's glide is Google's own; nothing is added.
  3. **The address under the pin** (`naddr-3`, Owner 2026-10-26): `POST /customer/address-search/reverse` names the point through the search's Google key; display only, in the panel and under the preview, never put into the street, never stored or logged (Google's terms allow caching only coordinates, `DL-86` (1)); own counters with the search's numbers, 10 a minute and 30 a day per Customer, so moving the map never uses up the search; the same key and the Owner's Cloud quota cover both. Google's price as checked 2026-11-16 (Before the tasks). The phone asks only for a placed pin at rest on a Google map, 400 ms after it rests, never again within 15 m, in the app's language. The privacy draft now names the point among what Google receives.
  4. **Where the map opens** (`naddr-4`): where the phone is when the location was already allowed — read without asking, and only moving the map, superseding the "only when tapped" of `DL-86` (2) and `docs/07` §11 — else at the delivery address, else the city centre. Confirm is off with «Сначала передвиньте карту к дому» until the pin is placed by a move, a search, «Где я» or that fix.
  5. **The zone on the map** (`naddr-5`): `GET /customer/service-area` gives the centre and radius; outside is dimmed behind a dashed green edge; a pin at rest outside says «Сюда пока не возим: до метки 11,7 км, а возим в радиусе 10 км…», is spoken, and turns confirm off. The phone rounds the distance up to tenths with the server's haversine; the server still refuses a saved point outside. Without a zone nothing is outside.
  6. **«Где я»** (`naddr-6`): a refusal forever offers «Настройки», location off «Включить», ten seconds without a fix «Ещё раз»; a refusal now and any other failure keep the old words.
  7. **Search** (`naddr-7`): a green «Найти» arrow from three letters; the answer stands right under the field, with the kept words when not found. The search answers only a point (`DL-86` (1)), so «Нашли: «…»» quotes the Customer's words; the panel names the house.
  8. **Map and preview** (`naddr-8`): the map shrinks into the preview and the details rise (0.35 s); back, the preview grows into the map; reduced motion fades. The whole preview is a button, its pill 44 high with 14 px text.
  9. **The fields** (`naddr-9`): «Далее» walks the fields; leaving an empty required field says «Заполните поле» at once; a save with a gap brings the first one into view, focuses and shakes it with a warning tap; «· необязательно» replaces the stars; saving stays green with «Сохраняем…», then ✓ «Сохранено». `Shake` lives in `core/`.
  10. **Leaving** (`naddr-10`): back from a filled map asks «Выйти без сохранения?» with «Продолжить ввод» and a red «Выйти»; an untouched one closes at once.
  11. **Large text** (`naddr-11`): no hint over the map (the panel says it), the search field grows, house and apartment stack.
  12. **Screen reader** (`naddr-12`): the map is one stop that names the pin; the search, «Где я» and the zone are announced; fields say «обязательное поле» or «необязательно»; a gap is announced; a confirm that is off says why.
  13. **Reproduction**: the repro items' red runs on main, quoted per item.
  14. **Rulings** made while coding (added by later tasks).
- [ ] **Step 6: Docs** as listed under Files. `docs/09` §13: the reverse lookup (body, answer, `house_known`, display only, codes, limits counted apart from the search) and the service area (answer, `null` while unset, the server still checks a saved point). `docs/07` §11: the backend also names the point under the pin with the same key; «Где я» reads the position when tapped, and a new address opens at it when the permission was already given; the point under the pin is sent for its name and is neither stored nor logged; the map draws the zone from `GET /customer/service-area`. `docs/03` §4: «The map names the address under the pin, opens where the phone is when the location is already allowed, and shows the delivery zone before anything is filled in (`DL-138`).» Privacy, ru: «- Google — слова, которыми вы ищете адрес, и точку метки на карте, чтобы назвать улицу и дом под ней.»; uz: «- Google — xaritada manzil qidirgan so'zlaringiz va belgi nuqtasi — uning ostidagi ko'cha va uyni aytish uchun.»
- [ ] **Step 7: Commit** — `feat(addresses): the server names the point under the pin and gives the delivery zone (DL-138)`.

### Task 2: The client reads the zone, the address under a point and why the location failed

**Files:**
- Modify: `frontend/lib/features/addresses/domain/address_search.dart`, `frontend/lib/features/addresses/data/address_search_api.dart`, `frontend/lib/features/addresses/application/addresses_controllers.dart` (`serviceAreaProvider`), `frontend/lib/features/addresses/data/device_location.dart`
- Test: `frontend/test/features/addresses/address_search_api_test.dart`, `frontend/test/features/addresses/data/device_location_test.dart`; create `frontend/test/features/addresses/domain/service_area_test.dart`; support: `test/support/fake_address_search.dart` (`places` answers per point, `heldPlaces`, `placeFailure`, `lookups` sent with their language, `area` and `areaFailure`), `test/support/fake_device_location.dart` (`current()` keeps `hold`, `release` and `calls`, answering `outcome` in place of `point`; the silent read answers `silent`, or with `holdSilent` waits for `releaseSilent(GeoPoint?)`, counted in `silentCalls`; `settingsOpened`, `locationSettingsOpened`)

**Interfaces:**
- Produces:
  - `final class PointAddress { const PointAddress({required this.line, required this.houseKnown}); final String line; final bool houseKnown; }`
  - `final class ServiceArea { const ServiceArea({required this.centre, required this.radiusKm}); final GeoPoint centre; final String radiusKm; double distanceKmTo(GeoPoint point); bool contains(GeoPoint point); String distanceLabel(GeoPoint point); String get radiusLabel; }` — haversine, Earth radius 6371.0088 as `ServiceAreaPolicy`; inside when the distance ≤ the radius; `distanceLabel` rounds up to tenths with a decimal comma («11,7»); `radiusLabel` drops trailing zeros («10», «7,5», «12,25»).
  - On `AddressSearchRepository`: `Future<PointAddress?> addressAt(GeoPoint point, {required String language})` and `Future<ServiceArea?> serviceArea()`; both throw an `ApiFailure`. Parsing is strict: a line of 1–160 characters and a boolean; coordinates as `parse` holds them, a radius `^\d{1,4}(\.\d{1,2})?$` above 0.
  - `final FutureProvider<ServiceArea?> serviceAreaProvider` (autoDispose).
  - `enum LocationFailure { denied, deniedForever, serviceOff, timedOut, failed }`; `sealed class LocationOutcome`; `final class LocationFound extends LocationOutcome { const LocationFound(this.point); final GeoPoint point; }`; `final class LocationFailed extends LocationOutcome { const LocationFailed(this.reason); final LocationFailure reason; }`.
  - `DeviceLocation`: `Future<LocationOutcome> current()` (asks the permission when it is only denied); `Future<GeoPoint?> currentIfAllowed()` (never asks; a point only when the permission is already given and the service on, else `null`, every failure included); `Future<void> openAppSettings()`; `Future<void> openLocationSettings()`.

- [ ] **Step 1: Write the failing tests:**
  - API: `'addressAt sends the point and the language and reads the line'` (POST `/customer/address-search/reverse`, body `{latitude: '41.300000', longitude: '69.250000', language: 'ru'}`); `'addressAt reads null as nothing known'`; `'a line off the contract is a failure'` (empty, 161 characters, `house_known` missing or a string); `'serviceArea reads the centre and the radius'`; `'serviceArea reads null while unset'`; `'an area off the contract is a failure'` (radius `"0"`, `"abc"`, a seven-decimal latitude).
  - Domain: `'a point within the radius is inside, one 20 m beyond is outside'`; `'the distance is rounded up to tenths with a comma'` — centre `41.311081, 69.240562`, radius `"10.00"`, point `41.311081, 69.380000`: «11,7», not inside; `'the radius drops trailing zeros'`.
  - Device: `'service off is said as off'`; `'a refusal forever is said as such, also after asking'`; `'a refusal now is denied'`; `'ten seconds without a fix is timed out'`; `'any other failure is failed'`; `'the silent read never asks'` (permission denied: `null`, `requestPermission` never called); `'the silent read answers when already allowed'`; `'settings open through the platform'`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**; the point step's `_whereAmI` compiles against `LocationOutcome` (`LocationFailed` → today's `addressLocationFailed` bar until Task 5).
- [ ] **Step 4: Run** the new tests and `test/features/addresses/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): the client reads the zone and the address under a point, and says why the location failed (DL-138)`.

### Task 3: The map reports a move's start and draws the zone; the pin

**Files:**
- Create: `frontend/lib/features/addresses/presentation/map/map_pin.dart`
- Modify: `frontend/lib/features/addresses/presentation/map/address_map.dart`, `google_address_map.dart` (the picker draws no pin; the preview keeps its still one), `point_fields_address_map.dart`, `frontend/lib/features/addresses/presentation/address_point_step.dart` (passes the new arguments; draws `MapPin` still, unlifted, until Task 4), `test/support/fake_address_map.dart`
- Test: create `frontend/test/features/addresses/presentation/map_pin_test.dart`, `frontend/test/features/addresses/presentation/zone_overlay_test.dart`; modify `frontend/test/features/addresses/presentation/address_map_test.dart`

**Interfaces:**
- Consumes: `ServiceArea` (Task 2).
- Produces:
  - `AddressMap.picker({required GeoPoint initial, required PointMapMover mover, required bool enabled, required VoidCallback onMoveStarted, required ValueChanged<GeoPoint> onMoved, ServiceArea? zone})` — `onMoveStarted` when the Customer's own move starts (the classifier's start), never for a move the mover asked for; the picker draws no pin; the zone is drawn when given.
  - `({Polygon dim, Polyline edge}) zoneOverlay(ServiceArea zone)` in `google_address_map.dart` (`@visibleForTesting`): the circle as 72 points; `dim` an outer ring ±5° around the centre with the circle as its hole, fill `Color(0x21151D16)`, stroke 0; `edge` the circle closed (73 points), `KitColors.primary`, width 3, `[PatternItem.dash(12), PatternItem.gap(8)]`.
  - `MapPin({required bool lifted, required int drops, Key? key})` — fills its parent; the tip at the centre; motion as Global Constraints, «Pin».
  - `FakeAddressMap`: `fake-map-move` calls `onMoveStarted` then `onMoved(fakeDoor)`; `fake-map-start` calls only `onMoveStarted`; `fake-map-far` calls both with `fakeFar` (`41.311081, 69.380000`); `emitMove` stays a bare camera report; `zone` holds the last zone given.

- [ ] **Step 1: Write the failing tests:**
  - `'the pin lifts while lifted and drops with a squash'` — the icon's translation −14 at 160 ms; turned unlifted with `drops` + 1: the y scale ≈ 0.88 at 196 ms, identity at 280 ms.
  - `'reduced motion keeps the pin still'`.
  - `'the zone is a dimmed world with a hole and a dashed green edge'` — every hole point within 1 m of the radius by `distanceKmTo`; the outer ring holds the circle; the edge closed, `primary`, the pattern.
  - `'the fields map takes the move callbacks and the zone'` — still the coordinate fields; typing reports `onMoved`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**; `_GooglePicker` adds `polygons`/`polylines` from `zoneOverlay` and calls `onMoveStarted` from `onCameraMoveStarted` when `CameraMoveClassifier` says the move is the Customer's.
- [ ] **Step 4: Run** the new tests and `test/features/addresses/` — all pass (`'the step draws no pin of its own: the map owns it'` becomes `'the step draws the pin over a movable map and none over the fields'`).
- [ ] **Step 5: Commit** — `feat(addresses): the map draws the delivery zone and the step owns a pin that can lift (DL-138)`.

### Task 4: The map step — header, the living pin, where it opens and the confirm rule

**Files:**
- Modify: `frontend/lib/core/widgets/kit_app_bar.dart` (`subtitle`, `spokenTitle`, `toolbarHeight`), `frontend/lib/features/addresses/presentation/address_point_step.dart`, `frontend/lib/features/addresses/presentation/addresses_screens.dart` (bar, the step's arguments), both ARBs (the header and panel strings), regenerate
- Test: `frontend/test/features/addresses/address_point_step_test.dart`, `frontend/test/core/widgets/kit_app_bar_test.dart` (create if missing), the form tests in `frontend/test/features/addresses/customer_account_screens_test.dart` that read «Точка доставки»

**Interfaces:**
- Consumes: `MapPin`, `onMoveStarted` (Task 3); `DeviceLocation.currentIfAllowed` (Task 2); `deliveryAddressProvider`.
- Produces:
  - `kitAppBar({…, String? subtitle, String? spokenTitle, double? toolbarHeight})` — title and subtitle are one header node labelled `spokenTitle ?? '$title, $subtitle'`.
  - `AddressPointStep({required GeoPoint initial, required bool placed, Address? openedAt, required bool keepsWords, required ValueChanged<AddressPointResult> onConfirmed, Key? key})`.
  - `AddressPointResult({required GeoPoint point, String? words, PointAddress? place, required double mapHeight})` — `place` is filled in Task 5; `mapHeight` is the map area's height when confirmed (Task 7 morphs from it).
  - The form opens a new address with `initial: delivery?.point ?? defaultMapCentre`, `placed: false`, `openedAt: delivery` (`deliveryAddressProvider`'s value, read once); the edit's map and the map reopened from the details open with `placed: true`.

- [ ] **Step 1: Write the failing tests:**
  - `'a new address says its step in the bar and the panel has no heading'` — «Новый адрес» over «Шаг 1 из 2 · точка на карте», one header node «Новый адрес, шаг 1 из 2: точка на карте»; no «Точка доставки» anywhere; after confirm «Шаг 2 из 2 · подъезд и квартира».
  - `'the pin lifts while the Customer moves the map and drops with a light tap'` — `fake-map-start`: lifted; `fake-map-move`: dropped, `HapticFeedbackType.lightImpact` once; a search's move lifts nothing and taps nothing.
  - `'the hint fades after the first move'` — opacity 1; after `fake-map-start` 0 at 250 ms; stays 0 after more moves.
  - `'opened without a fix the map starts at the delivery address and confirm waits'` — the picker's initial is «Дом»'s point; the button off, `onPressed` null, «Сначала передвиньте карту к дому» above it; the panel «Карта открыта у вашего адреса «Дом». Передвиньте её так, чтобы метка встала на вход нового дома.»; after `fake-map-move` the button is green and confirms `fakeDoor`.
  - `'a search or Где я places the pin too'`.
  - `'opened with the location already allowed the map starts there'` — `silent` set: the mover's target is that point, confirm green; `calls` 0 (nothing asked).
  - `'a silent fix after a touch does not move the map'` — `holdSilent`, a pointer down on the map, `releaseSilent`: no target (Review Focus 3); the same after a search.
  - `'with no address the map starts at the city centre'`.
  - `'an edit's map and the way back from the details start placed'`.
  - `'large text drops the hint and the panel says it'` (**repro** `naddr-11`) — `NonlinearTextScaler(2)`, 320 × 640: no `address-point-hint`; the panel «Передвиньте карту, чтобы метка встала на вход в дом. Квартиру и подъезд укажете на следующем шаге.»; no overflow; the bar's title and subtitle both whole.
  - `kit_app_bar_test.dart`: `'a subtitle stands under the title and both are one heading'`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement**; the panel loses its heading; the confirm rule follows Global Constraints («Placed and confirmable»; `outside` stays false until Task 5).
- [ ] **Step 4: Run** `test/features/addresses/` and `test/core/widgets/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): the map step says its step, its pin lives and it opens where the address will be (DL-138)`.

### Task 5: The map step — what is under the pin, the zone, the search and «Где я»

**Files:**
- Create: `frontend/lib/features/addresses/presentation/address_point_parts.dart` (`SearchAnswer`, `PlaceRow`, `ZoneNotice`)
- Modify: `frontend/lib/features/addresses/presentation/address_point_step.dart`, both ARBs (search, place, zone, location, reader strings; remove the three unused), regenerate
- Test: `frontend/test/features/addresses/address_point_step_test.dart`

**Interfaces:**
- Consumes: `addressAt`, `serviceAreaProvider`, `LocationOutcome`, `openAppSettings`, `openLocationSettings` (Task 2); `zone:` (Task 3); the confirm rule (Task 4).
- Produces: `AddressPointResult.place` — the answer for the confirmed point when known. Keys: `address-point-place`, `address-outside-zone`, `address-search-go`, `address-search-result`, `address-point-map`.
- Behaviour beyond Global Constraints: the place row's node is a live region; while looking it reads «Ищем адрес»; a `null` answer shows «Адрес не определили» over «Поставьте метку на здание», a street-only one its line over «Дом не определили — поставьте метку на здание», a failure no row. Announcements: found «Нашли адрес. Метка передвинута»; not found and unavailable their own text; located «Метка там, где вы»; each rest outside `addressOutsideZoneSpoken`. The map stop is a container labelled «Карта, метка в центре.» + « Метка: {line}.» when known + « Без карты метку ставят поиском или кнопкой «Где я»», over the excluded map and pin; the search field «Адрес словами. Найдём и передвинем метку»; «Где я» «Где я: поставить метку туда, где вы»; a confirm that is off carries the hint `addressConfirmWhyMove` or `addressConfirmWhyZone`. The panel shows no amber notice and no kept line any more.

- [ ] **Step 1: Write the failing tests:**
  - `'the panel names the address under the pin once the map rests'` — skeleton after `fake-map-start`; after `fake-map-move` and 400 ms «Navoiy ko'chasi, 12», one lookup for `fakeDoor` in `ru`; the row is a live region.
  - `'a point without a house says to put the pin on a building'`; `'nothing known says so'`.
  - `'a failed lookup shows no row and confirm still works'` — `NetworkFailure` and `ApiRefusal` 429 (Review Focus 1).
  - `'a late answer for an older point is not shown'` — the first lookup held, a second move, the first released: its line never shows (Review Focus 1).
  - `'a rest within 15 m asks nothing again'`; `'the fields map looks nothing up'`; `'an unplaced pin is not looked up'`.
  - `'outside the zone the map says how far and confirm waits'` — `area` centre `41.311081, 69.240562`, radius `"10.00"`; `fake-map-far`: «Сюда пока не возим: до метки 11,7 км, а возим в радиусе 10 км. Передвиньте метку ближе к городу.», the button off with no why line, announcement «Сюда пока не возим: 11,7 километра, возим в радиусе 10»; the picker got the zone; `fake-map-move` back inside clears it.
  - `'without a zone nothing is outside'` — `areaFailure` set, and `area` null: `fake-map-far` confirms (Review Focus 2).
  - `'the green arrow searches and the answer stands under the field'` — two letters: no arrow; three: the arrow; its tap sends the query; found: «Нашли: «Chilonzor 9-kvartal, 14». Проверьте, что метка на вашем доме.» with the query bold; announcement «Нашли адрес. Метка передвинута».
  - `'not found and unavailable are said under the field with the kept words'` — «Не нашли «…». Передвиньте карту к дому сами.» and «Адрес словами сохраним…» (`addressWordsKept`); «Поиск сейчас не работает. Передвиньте карту сами.».
  - `'Где я says why it failed and offers the way out'` — `deniedForever`: `addressLocationDenied` with «Настройки» opening the app's settings; `serviceOff`: «Включить» opening the location settings; `timedOut`: «Ещё раз» reading again; `denied` and `failed`: `addressLocationFailed` without an action.
  - `'the map is one reader stop that names the pin'` (**repro** `naddr-12`) — label «Карта, метка в центре. Метка: Navoiy ko'chasi, 12. Без карты метку ставят поиском или кнопкой «Где я»»; the field's and «Где я»'s labels; the off button's hint.
  - `'the step holds at 320x640 with text x2'` extended — with an answer under the field and the zone notice: no overflow; `meetsGuideline(iOSTapTargetGuideline)` at 100 % and ×2.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/addresses/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): the map names the house under the pin, shows the zone and answers right under the search (DL-138)`.

### Task 6: The details — fields, the first gap and saving

**Files:**
- Create: `frontend/lib/core/widgets/shake.dart`
- Modify: `frontend/lib/features/addresses/presentation/addresses_screens.dart` (`_details`, `_field`, `_footer`, `_submit`), both ARBs (field, saving strings), regenerate
- Test: create `frontend/test/core/widgets/shake_test.dart`; the form tests in `frontend/test/features/addresses/customer_account_screens_test.dart`

**Interfaces:**
- Produces: `Shake({required int trigger, required Widget child, Key? key})` — each time `trigger` grows the child runs the keyframes of Global Constraints, «First gap»; nothing with reduced motion.
- Behaviour: required labels plain, optional ones `addressOptional` (apartment, landmark, note and «Как назвать адрес»); each field is one text-field node labelled `fieldRequiredSpoken` or `fieldOptionalSpoken`, its visible label excluded; street, house, apartment and landmark take `TextInputAction.next` to the next in that order, the note stays multiline, the label field takes `done`; leaving street or house empty shows «Заполните поле», typing clears it; a save with gaps marks each, scrolls and focuses the first, shakes it, taps `warningNotification` and announces `addressFieldMissingSpoken(label)`, and sends nothing; while saving the fields keep their look but are read-only, the chips and the preview do nothing, and the button stays green as Global Constraints draw it; at large text house and apartment stack, house first.

- [ ] **Step 1: Write the failing tests:**
  - `shake_test.dart`: `'a shake follows the keyframes once per trigger'` (x −6 at 72 ms, 0 at 360 ms); `'reduced motion does not shake'`.
  - `'optional fields say so and required ones carry no star'` — «Квартира или офис · необязательно», «Как назвать адрес · необязательно»; no «*».
  - `'a reader hears required and optional'` (**repro** `naddr-12`) — the house node «Дом, обязательное поле», a text field; «Квартира или офис, необязательно»; no separate label node.
  - `'Далее walks the fields'` — `TextInputAction.next` from street focuses house, then apartment, landmark, note.
  - `'leaving an empty required field says so at once'` — and typing clears it.
  - `'saving with a gap brings it into view, focuses and shakes it'` (**repro** `naddr-9`) — every field but house filled, the list at its end: after save, house's label 12 below the list's top at 300 ms, house focused, the shake moving at 400 ms, `HapticFeedbackType.warningNotification` once, announcement «Заполните поле «Дом»», no request.
  - `'saving stays green and ends with a check'` — save held: the button `primary` with a spinner and «Сохраняем…», the fields enabled and read-only; released: «Сохранено» with `Icons.check`; the bar «Адрес «…» добавлен» and the pop only after 450 ms.
  - `'a failed save gives the button back'` — «Сохранить адрес» and the failure line.
  - `'large text stacks house and apartment'` (**repro** `naddr-11`) — 360 × 640, ×2: house above apartment, same left; no overflow; `meetsGuideline(iOSTapTargetGuideline)`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/addresses/` and `test/core/widgets/` — all pass.
- [ ] **Step 5: Commit** — `feat(addresses): the address fields lead on, point at the first gap and save in green (DL-138)`.

### Task 7: The morph, the preview button and leaving without saving

**Files:**
- Create: `frontend/lib/features/addresses/presentation/address_leave_sheet.dart`, `frontend/test/features/addresses/address_form_flow_test.dart`
- Modify: `frontend/lib/features/addresses/presentation/addresses_screens.dart` (the step swap, `_preview`, back), `frontend/lib/features/addresses/presentation/address_point_step.dart` (`onTyped`, `panelRises`), both ARBs (preview and leave strings), regenerate

**Interfaces:**
- Consumes: `AddressPointResult.mapHeight`, `.place` (Tasks 4, 5).
- Produces:
  - `Future<bool> showAddressLeaveSheet(BuildContext context, {String? name})` — true for «Выйти»; keys `address-leave-sheet`, `address-leave-stay`, `address-leave-go`.
  - `AddressPointStep({…, ValueChanged<bool>? onTyped, bool panelRises = false})` — `onTyped` reports whether the search holds words (typed or sent); `panelRises` slides the panel up on its first frame.
  - The preview `address-preview` (one button: `addressChangePointSpoken`, plus «. Метка: {line}» when known), the pill `address-change-point`, the line `address-preview-place`.
- Behaviour: the morph and its reduced form as Global Constraints, «Motion»; while one runs, confirm, back and the preview do nothing. Back on the first map step of a new address — the bar's back and the system back — opens the sheet when anything was entered (search words, any field, a label chosen), naming the street or else the words; «Продолжить ввод» closes it only; «Выйти» leaves without sending; with nothing entered it leaves at once. Back while saving does nothing. An edit keeps its silent back.

- [ ] **Step 1: Write the failing tests** (`address_form_flow_test.dart`, the form over `FakeAddressMap`):
  - `'confirming shrinks the map into the preview'` — `address-preview` as high as the map on the first frame, between at 175 ms, 118 at 350 ms; the fields' opacity 0 at 80 ms, 1 at 400 ms.
  - `'Изменить точку grows the preview back into the map'` — the preview grows; after 320 ms the map step, its panel below at its first frame and in place at 300 ms.
  - `'reduced motion fades between the steps'`.
  - `'a second confirm during the morph does nothing'` — one details step; back during the morph is ignored too (Review Focus 4).
  - `'the whole preview is a button with a 44 pill'` — a tap on the preview's left half opens the map; the pill ≥ 44 high, 14 px text; the node «Изменить точку на карте. Метка: Navoiy ko'chasi, 12».
  - `'the place shows under the preview'` — «Метка: Navoiy ko'chasi, 12»; none when the lookup failed.
  - `'back from a filled map asks before leaving'` — search «Chilonzor 9-kvartal» sent, back: «Адрес не сохранится — «Chilonzor 9-kvartal», и всё, что вы ввели, пропадёт.»; «Продолжить ввод» keeps the words; back, «Выйти» closes; no address sent.
  - `'system back asks too'` — `tester.binding.handlePopRoute()` opens the sheet (Review Focus 5).
  - `'back from an untouched map closes at once'`.
  - `'back while saving does nothing'` — save held, back and system back: still on the form; released: the bar and the pop (Review Focus 5).
  - `'every face fits at large text and meets the tap target guideline'` — the sheet and the details with the preview line, ×2.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/addresses/`, `test/features/checkout/`, `test/features/catalog/`, `test/core/` (`--concurrency=1`) — all pass; `flutter analyze` clean; `dart format --set-exit-if-changed lib test` clean.
- [ ] **Step 5: Commit** — `feat(addresses): the map shrinks into its preview and a filled form asks before it is left (DL-138)`.

### After the tasks (the lead)

- [ ] The full backend suite, `pint --test`, `phpstan analyse`, and the full frontend suite through `test-runner`; the final `branch-reviewer` (opus) with this plan, BASE `241c9d35`, the ledger and the generated localizations to skip; one fix dispatch; a scoped re-review; residuals parked in APPLE_BATCH with a ruling.
- [ ] `/security-review`; push, pull request, both required checks green, merge.
- [ ] The walk on the `barakabozor` emulator with the Maps key: the pin lifting, the place under it, the zone's edge, «Где я» refused forever, the morph, a gap on save; 4–5 shots for the Owner.
