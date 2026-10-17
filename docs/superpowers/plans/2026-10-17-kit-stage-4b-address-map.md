# Kit Stage 4b — Address, Google Map and the Courier's Buttons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer sets a delivery address the way drawings 21, 21а, 22, 22а and 22б of `kit/04-korzina-adres.dc.html` show: a Google map with the pin, or the address typed in words, then a short form. The Courier gets the address card of drawing 22в with "Открыть в Яндексе" and "Скопировать адрес". Yandex MapKit leaves the app.

**Architecture:**
- **Server.** New `POST /customer/address-search` (`docs/09` §13). The backend asks the Google Geocoding API with a server key and answers only a point, or nothing. The key never reaches the app, and the query, the key and Google's answer are never logged or stored.
- **Client.**
  - `yandex_mapkit` is replaced by `google_maps_flutter`, behind a new `AddressMap` interface: a picker and a small preview. Tests use a fake, and a build without a key gets the existing coordinate fields.
  - `geolocator` powers "где я".
  - A new address is two steps on one screen: the map step (22/22б), then the form (22а). An edit opens the form, and "Изменить точку" goes back to the map.
  - The delivery-address sheet is rebuilt as 21/21а.
  - The Courier's address becomes the 22в card. `MapLinks` opens Yandex Navigator; when it is not installed, a Yandex Maps link opens instead.

**Tech Stack:** Laravel 13 + PostgreSQL (PHPUnit, Pint, PHPStan), all inside Docker. Flutter 3.47.5 (Dart 3.13), Riverpod 3, go_router, `flutter gen-l10n` (template `app_uz.arb`), Montserrat, `KitColors`. New packages: `google_maps_flutter ^2.18.2` and `geolocator ^14.1.1`.

**Spec:** `kit/04-korzina-adres.dc.html` in the Claude Design project "BarakaBozor — стиль покупателя", screens 21, 21а, 22, 22а, 22б and 22в. The Owner approved it on 2026-10-17. His decisions are `DL-84` items 2–4, already in `docs/DECISIONS.md`.

## Global Constraints

- Branch `task/kit-4b-address` from `main` `dd9ca1c`. Never commit to `main`.
- **Backend.** Every command runs in the container, from the repo root: `docker compose -f docker/compose.yaml exec app php artisan test --filter=…`, `… exec app vendor/bin/pint --test`, `… exec app vendor/bin/phpstan analyse`.
- **Flutter.** Use `G:/tools/flutter/bin/flutter` with `TEMP`/`TMP` = `G:\tools\tmp`, run from `frontend/`. Run `flutter analyze` and `dart format --set-exit-if-changed lib test`. APK builds also need `GRADLE_USER_HOME=G:\tools\gradle-home`.
- **Keys.**
  - The app's key comes from the gitignored `frontend/.env.maps` (`GOOGLE_MAPS_API_KEY=`) through `--dart-define-from-file=.env.maps`.
  - The server's key comes from `GOOGLE_MAPS_GEOCODING_KEY` in the gitignored `backend/.env`.
  - Neither key is ever printed, logged, committed or put into a test. Tests use the literal `test-geocoding-key`.
  - Check a key's presence by comparison only (`grep -c '=.\+' file`).
- **What Google gives is never stored.** A search only moves the camera. The address keeps the point the Customer confirmed and the Customer's own words (`DL-84` item 2). Google's formatted address is never read.
- **Privacy.** The server never logs the typed query or Google's answer. The device's location is read only when the Customer taps "где я", only moves the camera, and is never sent until the Customer confirms the point.
- **Kit look.** Colours only from `KitColors`; Montserrat. Sizes follow the drawing on a 375-wide screen. The Google logo stays uncovered: the "где я" button sits bottom right, the logo is bottom left.
- **Large text.** Every new or rebuilt screen state has a widget test at 320×640 with `textScaleFactorTestValue = 2`, in `uz` and `ru`, without an exception. Pattern: `test/features/catalog/customer_home_test.dart:236-248`.
- **Packages.** Only the two packages above are added, and only `yandex_mapkit` is removed. `pubspec.lock` changes only through `flutter pub get`. `composer.lock` stays unchanged.
- **Generated files.** `ios/Runner/GeneratedPluginRegistrant.m` and the l10n output are regenerated, never hand-edited.
- **Localization.** Texts are in Uzbek (the template) and Russian, exactly as each task lists them. A key the change leaves unused is deleted from both `.arb` files.
- **Decisions.** `DL-86` (agent) goes into `docs/DECISIONS.md`. Task 1 creates it with item 1; each later task appends its own item. The affected `docs/01–09` section is updated in the same task.
- **Tests.** Never delete, skip or weaken a test. A test whose flow changed is rewritten to assert the new flow; Task 4 gives the mapping.
- **Commits** end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **A search answered late.** The Customer types an address, then drags the map, or types again, before the answer arrives. Only the latest query's answer may move the map, and only if the Customer has not moved it since. Task 3 test: "a late answer does not move a map the Customer moved".
2. **"Где я" refused.** Location permission is denied, location services are off, or the reading times out. The map stays where it is, a snackbar says so, and the button works again. Task 3 test: "a refused location says so and leaves the map".
3. **Back between the steps.** On a new address, back from the form returns to the map with the point kept, and back from the map leaves. On an edit, back from the map returns to the form unchanged. The same holds for the system back gesture, and back is ignored while a save runs. Task 4 test: "back walks the steps".
4. **A provider failure tells nothing.** Google refusing, timing out or exceeding its quota answers `503 provider_unavailable`. The key, the query and Google's answer appear neither in the response nor in any log line. Task 1 test: "a provider failure is unavailable and reveals nothing".
5. **No Yandex Navigator on the phone.** "Открыть в Яндексе" falls back to the Yandex Maps link. When nothing opens either, a snackbar shows the address. Task 6 test: "without the Navigator the Yandex Maps link opens".

---

### Task 1: The server looks up a typed address

**Files:**
- Create in `backend/app/Modules/Customer/`:
  - `AddressSearch/AddressGeocoder.php`
  - `AddressSearch/GoogleGeocoder.php`
  - `AddressSearch/UnconfiguredGeocoder.php`
  - `AddressSearch/GeocoderUnavailable.php`
  - `AddressSearch/LocatedPoint.php`
  - `Actions/SearchAddress.php`
  - `Http/Controllers/AddressSearchController.php`
  - `Http/Requests/AddressSearchRequest.php`
  - `CustomerServiceProvider.php` (found by `ModuleProviderRegistry`; never listed by hand)
- Create `backend/tests/Feature/Customer/AddressSearchApiTest.php`.
- Modify:
  - `backend/routes/api/v1/customer.php`
  - `backend/config/services.php`
  - `backend/.env.example`: add `GOOGLE_MAPS_GEOCODING_KEY=`
  - `docs/09-api-contracts.md` §13, `docs/07-architecture.md` §11, `docs/DECISIONS.md`

**Interfaces:**
- Produces `POST /api/v1/customer/address-search`:
  - Access: a Customer session (`AuthServiceProvider::PROTECTED`, `RequireRole::of(Role::Customer)`); route name `customer.address-search`.
  - Body: `{"query": string}`, trimmed, 3–200 characters.
  - Answer: `200 {"data": {"latitude": "41.299512", "longitude": "69.240146"}}`, or `200 {"data": null}` when nothing useful was found.
  - Refusals: `503 provider_unavailable` when Google cannot answer or no key is set; `429 rate_limited` with `Retry-After`; `422 validation_failed`.
- `interface AddressGeocoder { public function locate(string $query, ?SearchBounds $bounds): ?LocatedPoint; }`. It throws `GeocoderUnavailable`.
  - `SearchBounds` is a `final readonly class` in `AddressSearch/` with `south, west, north, east` floats.
  - `LocatedPoint` is a `final readonly class` with `string $latitude, string $longitude`, each written by `number_format($x, 6, '.', '')`.
- `config('services.google_maps.geocoding_key')` reads `env('GOOGLE_MAPS_GEOCODING_KEY')`. `CustomerServiceProvider` binds `GoogleGeocoder` when the key is non-empty, `UnconfiguredGeocoder` (always throws) otherwise.

- [ ] **Step 1: Failing tests** in `AddressSearchApiTest`.
  - Set up as `AddressesApiTest`: centre `41.311081, 69.240562`, radius `5.00`. `config(['services.google_maps.geocoding_key' => 'test-geocoding-key'])` and `Http::fake()` against `maps.googleapis.com/maps/api/geocode/json*`.
  - `test_a_found_address_answers_its_point`:
    - Google answers `status OK`, result types `["street_address"]`, location `41.2995123, 69.2401456`.
    - Expect `200`, data `{latitude: "41.299512", longitude: "69.240146"}`.
    - `Http::assertSent`: query `address` = `Navoiy 5`, `components` = `country:UZ`, `region` = `uz`, `key` = `test-geocoding-key`, `bounds` = `41.266165,69.180765|41.355997,69.300359`.
    - The bounds formula: the circle's box, `±radius/111.32` degrees of latitude and `±radius/(111.32·cos(centre latitude))` of longitude, six decimals.
  - `test_nothing_found_answers_null`: `ZERO_RESULTS` gives `200`, `data` `null`.
  - `test_a_match_of_the_whole_city_is_nothing_found`: types `["locality","political"]` gives `null`. The same holds for `country`, `administrative_area_level_1` and `administrative_area_level_2`, each through a data provider.
  - `test_a_provider_failure_is_unavailable_and_reveals_nothing`, with a data provider over five failures:
    - `REQUEST_DENIED`, `OVER_QUERY_LIMIT` and `OVER_DAILY_LIMIT`;
    - HTTP `500`;
    - `Http::fake` throwing `ConnectionException('cURL error 28 for …key=test-geocoding-key')`.

    Each answers `503 provider_unavailable`. The response body contains neither `test-geocoding-key` nor `Navoiy`. `Log::spy()`: no logged message or context contains either string.
  - `test_without_a_key_the_search_is_unavailable`: key `null` gives `503`, and `Http::assertNothingSent()`.
  - `test_without_a_service_area_the_search_is_not_bounded`: area unset; the request has no `bounds`, and the search still answers.
  - `test_the_query_is_validated`: missing, `"ab"`, 201 characters, a JSON number and an unknown extra field each give `422 validation_failed`.
  - `test_only_a_customer_may_search`: a guest gets `401`, a Shopper `403`.
  - `test_searches_are_limited_per_customer`:
    - 10 in a minute pass and the 11th is `429 rate_limited` with `Retry-After`; another Customer still passes;
    - after `travel(61)->seconds()` the window reopens;
    - once the 30th of the day has passed, the 31st is refused even after the minute window reopens.

  Run `docker compose -f docker/compose.yaml exec app php artisan test --filter=AddressSearch`. Expected: FAIL.
- [ ] **Step 2: Implement.**
  - **`SearchAddress::__invoke(User $customer, string $query): ?LocatedPoint`.**
    - Reserves `address-search:minute:{id}` (10 per 60 s), then `address-search:day:{id}` (30 per 86 400 s), the way `RequestCustomerLoginCode::reserve` does.
    - Builds `SearchBounds` from `BusinessSettings::current()` when the centre and radius are set, `null` otherwise.
    - Calls the geocoder and turns `GeocoderUnavailable` into `ApiException::unavailable('provider_unavailable')`.
  - **`GoogleGeocoder`.**
    - Request: `Http::timeout(5)->connectTimeout(3)->acceptJson()->get(...)` with the parameters above.
    - Statuses: a non-2xx answer, an unreadable body or any status other than `OK`/`ZERO_RESULTS` throws `GeocoderUnavailable`.
    - Catch `ConnectionException`/`RequestException` and throw `GeocoderUnavailable` without their message. Their message carries the URL with the key.
    - Logging: one `Log::warning('address_search.provider_failed', ['reason' => <Google status or HTTP status>])`, and nothing else.
    - Mark the key and the query `#[\SensitiveParameter]`.
  - **`AddressSearchController::store`** returns `response()->json(['data' => $point ? ['latitude' => …, 'longitude' => …] : null])`.
- [ ] **Step 3: Run** the filter, `pint --test` and `phpstan analyse`. Expected: PASS.
- [ ] **Step 4: Docs.**
  - **`docs/09` §13.** Add a paragraph: "`POST /customer/address-search` looks up an address typed in words (`DL-86` item 1): body `query` (3–200). It answers `{data: {latitude, longitude}}`, the point to move the map to, or `{data: null}` when nothing narrower than a city was found. The point is a suggestion: an address keeps the point the Customer confirms. `503 provider_unavailable` while the lookup cannot answer; `429 rate_limited` past 10 a minute or 30 a day per Customer."
  - **`docs/07` §11.** Replace the backend's sentence "the backend has no map dependency" with: "The backend looks up a typed address through the Google Geocoding API with its own key (`GOOGLE_MAPS_GEOCODING_KEY`), bounded to the service area's box, and answers only the point; it stores and logs neither the query nor Google's answer, which the Geocoding terms allow to be cached for at most 30 days."
  - **`docs/DECISIONS.md`.** Append:

```markdown
## DL-86 — Address, Google map and the Courier's buttons, kit stage 4b (2026-10-17, agent)

1. **A typed address is looked up by the backend**, not the app: the Geocoding API is a web service whose key Google advises keeping on a server behind an IP restriction, which an app's key cannot have. `POST /customer/address-search` answers only a point for the map to move to, bounded to the service area's box and to Uzbekistan; a match no narrower than a city counts as nothing found, because it says nothing about the house. Ten searches a minute and thirty a day per Customer, under the Owner's daily quota in Google Cloud, keep the lookup within Google's free monthly allowance. Neither the query nor Google's answer is logged or stored; a provider failure logs only Google's status.
```

- [ ] **Step 5: Commit**: `feat(addresses): the server looks up a typed address`.

---

### Task 2: Google Maps replaces Yandex MapKit in the app

**Files:**
- Create:
  - `frontend/lib/features/addresses/presentation/map/address_map.dart`: the interface, the provider and `PointMapMover`.
  - `frontend/lib/features/addresses/presentation/map/google_address_map.dart`
  - `frontend/lib/features/addresses/presentation/map/point_fields_address_map.dart`: wraps the existing `point_fields.dart`.
  - `frontend/lib/features/addresses/data/device_location.dart`
  - `frontend/test/support/fake_address_map.dart`
- Delete: `map/map_picker.dart`, `map/yandex_map_picker.dart`, `map/yandex_map_picker_stub.dart`, `android/app/src/main/kotlin/uz/barakabozor/app/MainApplication.kt`.
- Modify:
  - `frontend/pubspec.yaml` (remove `yandex_mapkit`; add `google_maps_flutter: ^2.18.2`, `geolocator: ^14.1.1`)
  - `android/app/build.gradle.kts` (remove the MapKit `buildConfigField`, `buildFeatures.buildConfig` and the `maps.mobile` dependency; add `manifestPlaceholders["googleMapsApiKey"] = dartDefines["GOOGLE_MAPS_API_KEY"] ?: ""`; update the comments)
  - `android/gradle.properties` (remove `yandexMapkit.variant`)
  - `android/app/src/main/AndroidManifest.xml`:
    - drop `android:name=".MainApplication"` and the `tools:node="remove"` location block;
    - declare `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION`;
    - add `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${googleMapsApiKey}"/>`.
  - `MainActivity.kt` becomes a plain `class MainActivity : FlutterActivity()`.
  - `ios/Runner/Info.plist`: `NSLocationWhenInUseUsageDescription` = "Yetkazish nuqtasini siz turgan joyga qo'yish uchun".
  - `addresses_screens.dart`: the inline picker takes `addressMapProvider` (interim; Task 4 rebuilds it).
  - The three tests that override `mapPickerProvider` (`customer_account_screens_test.dart:88`, `catalog/customer_home_test.dart:98`, `checkout/checkout_screen_test.dart:104`).
  - `frontend/README.md` (the key section: `.env.maps`)
  - `docs/07` (line 26, line 29, §11 client part), `docs/06` (lines 16, 61), `docs/DECISIONS.md`

**Interfaces:**
- Produces in `address_map.dart`:

```dart
/// Asks a shown map to move — the typed-address search and "где я" use it.
class PointMapMover extends ChangeNotifier {
  GeoPoint? get target;
  void moveTo(GeoPoint point); // sets target, notifies
}

abstract interface class AddressMap {
  /// A real map the camera of which can be moved; false for the coordinate fields.
  bool get movable;
  /// Fills its parent. Reports the point under the pin each time the
  /// Customer's own move comes to rest, never after a move [mover] asked for.
  Widget picker({required GeoPoint initial, required PointMapMover mover, required bool enabled, required ValueChanged<GeoPoint> onMoved});
  /// A still map centred on [point] with the pin, sized by its parent.
  Widget preview({required GeoPoint point});
}

const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
final Provider<AddressMap> addressMapProvider; // Google when the key is set and the target is Android (not web), the fields otherwise
const GeoPoint defaultMapCentre; // moved here unchanged from map_picker.dart
```

- Produces `abstract interface class DeviceLocation { Future<GeoPoint?> current(); }`, `GeolocatorDeviceLocation({GeolocatorPlatform? platform})` (defaults to `GeolocatorPlatform.instance`, so a test injects a fake) and `deviceLocationProvider`.
- The interim form (until Task 4) puts the picker in a `SizedBox(height: 280)` with the old hint above it, as the Yandex picker had.
  - `current()` returns `null` when services are off, permission is denied or denied forever, the reading takes over 10 s, or a `PlatformException` is thrown.
  - It asks for permission only from `current()`.
- Produces in the test support: `class FakeAddressMap implements AddressMap`.
  - `movable` is configurable, default `true`.
  - The picker shows `Text('${initial.latitude},${initial.longitude}', key: 'fake-map-initial')`, a `TextButton` `fake-map-move` that calls `onMoved(fakeDoor)` with `fakeDoor = GeoPoint(latitude: '41.300000', longitude: '69.250000')`, and `Text` `fake-map-target` with the mover's target.
  - The preview shows `Text` `fake-map-preview` with the point.

- [ ] **Step 1: Failing tests.**
  - `test/features/addresses/presentation/address_map_test.dart`:
    - Without `GOOGLE_MAPS_API_KEY`, `addressMapProvider` is the fields map with `movable == false`.
    - The fields map's picker still shows `point-latitude`/`point-longitude`, and its preview shows the point's text.
  - `device_location_test.dart` against an injected `GeolocatorPlatform` fake:
    - denied gives `null`;
    - denied forever gives `null` without asking;
    - services off gives `null`;
    - a timeout gives `null`;
    - granted gives `GeoPoint.fromDegrees(...)`.

  Run `flutter test test/features/addresses`. Expected: FAIL.
- [ ] **Step 2: Implement** the files above.
  - **Google picker.** `GoogleMap` with:
    - `zoomControlsEnabled`, `myLocationButtonEnabled`, `mapToolbarEnabled`, `compassEnabled`, `rotateGesturesEnabled` and `tiltGesturesEnabled` all `false`;
    - an `EagerGestureRecognizer`, as the Yandex picker had;
    - initial zoom 16, and `animateCamera(CameraUpdate.newLatLngZoom(target, 17))` when the mover notifies.

    A move counts as the Customer's when `onCameraMoveStarted` fires while no mover move is running; `onCameraIdle` then reports the last `onCameraMove` target. This keeps `DL-23` (3): the app's own move never rounds a stored point.
  - **Google preview.** `liteModeEnabled: true`, every gesture off, inside `IgnorePointer`, with the centred pin icon.
- [ ] **Step 3: Switch the tests** to `addressMapProvider.overrideWithValue(FakeAddressMap())`. Run `flutter test`. Expected: the whole suite passes.
- [ ] **Step 4: Builds.**
  - Run `flutter build apk --debug --dart-define=BB_API_BASE_URL=http://10.0.2.2:8001/api/v1`. Expected: it succeeds with no key.
  - If `frontend/.env.maps` has a key, also build with `--dart-define-from-file=.env.maps`. Check that the merged manifest `build/app/intermediates/merged_manifests/debug/…/AndroidManifest.xml` has a non-empty `com.google.android.geo.API_KEY`, by `grep -c` and never by printing it.
  - Run `flutter build web --release`. Expected: it succeeds.
- [ ] **Step 5: Docs.**
  - **`docs/07`.**
    - Line 26 becomes "Google Maps (`google_maps_flutter`) for the address picker; a typed address is looked up through the backend".
    - Line 29: the reason for API 26 is "the Owner's choice (`DL-33` (10))", with no MapKit.
    - §11's client part: Google Maps through the key in `frontend/.env.maps`. A build without the key, the web and iOS take the point as coordinates until the iOS key is wired on the first Mac build. The Google logo is never covered. "Где я" reads the device's position only on tap. Drop the MapKit sentences.
  - **`docs/06`.** Line 16 says "addresses with the map picker". Line 61 becomes `| Google Maps keys: the app's (Maps SDK for Android) and the server's (Geocoding API) | 4 | Owner |`.
  - **README.** `.env.maps` replaces `.env.mapkit`, with the build command.
  - **`DL-86` item 2:** "**Google Maps in the app** (`DL-84` item 2) behind one `AddressMap`: the picker and a still preview. A build without the key, the web and iOS show the coordinate fields; iOS waits for its key until the first build on a Mac, since an iOS map without one aborts. Google's SDK starts only when a map is shown, so the launch-time abort of `DL-53` (1) and its engine workaround are gone. The Customer may move the map to where they are with \"где я\", which asks for the location then and only moves the camera. This supersedes `DL-33` (4) and (9), `DL-36` and `DL-53` (1)."
- [ ] **Step 6: Commit**: `feat(addresses): Google Maps replaces Yandex MapKit` (reason in the body: the Owner's `DL-84`; `geolocator` for "где я").

---

### Task 3: The map step — pin, typed address, "где я"

**Files:**
- Create:
  - `frontend/lib/features/addresses/domain/address_search.dart`: `AddressSearchRepository`.
  - `frontend/lib/features/addresses/data/address_search_api.dart`
  - `frontend/lib/features/addresses/presentation/address_point_step.dart`
  - `frontend/test/features/addresses/address_point_step_test.dart`
  - `frontend/test/support/fake_address_search.dart`
  - test support for `FakeDeviceLocation`
- Modify: `addresses_controllers.dart` (the repository provider) and both `.arb` files.

**Interfaces:**
- Consumes: Task 1's endpoint, and Task 2's `AddressMap`, `PointMapMover`, `DeviceLocation`.
- Produces:
  - `abstract interface class AddressSearchRepository { Future<GeoPoint?> locate(String query); }`. It throws `ApiFailure`.
  - `addressSearchRepositoryProvider`.
  - `final class AddressPointResult { final GeoPoint point; final String? words; }`
  - `class AddressPointStep extends ConsumerStatefulWidget`, with `initial`, `onConfirmed: ValueChanged<AddressPointResult>` and `confirmLabel` fixed to `addressPointConfirm`. It fills the screen body; the host gives the app bar.
- Layout (drawing 22):
  - **The map**, `Expanded`, holds a `Stack` of:
    - the picker;
    - the search field `address-search-field` (16 from the sides, 14 from the top, height 50, radius 14), with the clear `address-search-clear` and the progress `address-search-busy`;
    - the hint `address-point-hint` under it;
    - the pin and its shadow in the centre (the pin's tip on the point);
    - "где я" `address-my-location` (52, round, primary, 16 from the bottom right).
  - **The panel** under the map:
    - the title `addressPointTitle`;
    - the text `addressPointText`, or the not-found box `address-search-not-found` / the unavailable box `address-search-unavailable` (the drawing's orange box), followed by `address-words-kept`;
    - the button `address-point-confirm` (height 54, radius 14, primary).
  - **A map that is not movable** (the fields) shows them inside a `Form` in place of the map, without the search field or "где я". Confirm validates them first.
- Behaviour:
  - **Search.** Submitting the field (`TextInputAction.search`) with at least 3 trimmed characters calls `locate`.
    - A point moves the mover there, sets the point and turns the hint into `addressSearchFound`.
    - `null` shows not found.
    - An `ApiFailure` (503, 429, network) shows unavailable.

    The submitted words are kept for `AddressPointResult.words` whatever the answer; clearing the field forgets them and returns to the start.
  - **Late answers.** Only the latest search's answer counts, and none counts once `onMoved` fired after it was sent.
  - **"Где я"** calls `current()`, disabled while it runs. A point moves the map there (same late-answer rule). `null` shows the snackbar `addressLocationFailed`.
  - **Confirm** calls `onConfirmed(AddressPointResult(point: current point, words: kept words))`.
- Texts (`uz` / `ru`):

| Key | uz | ru |
|---|---|---|
| addressPointTitle | Yetkazish nuqtasi | Точка доставки |
| addressSearchHint | Yoki manzilni yozing: ko'cha, uy | Или напишите адрес: улица, дом |
| addressMapHint (replace text) | Xaritani suring: belgi uyingiz kirish joyida tursin | Передвиньте карту, чтобы метка встала на вход в ваш дом |
| addressSearchFound | Belgini tekshiring: kuryer aynan unga keladi | Проверьте метку: курьер приедет точно к ней |
| addressPointText | Kuryer belgiga keladi. Xonadon, podyezd va mo'ljalni keyingi qadamda kiritasiz. | Курьер приедет к метке. Квартиру, подъезд и ориентир укажете на следующем шаге. |
| addressSearchNotFound | Xaritada bunday manzil topilmadi. Xaritani surib, belgini uyingizga o'zingiz qo'ying. | На карте такого адреса не нашлось. Передвиньте карту и поставьте метку на свой дом сами. |
| addressSearchUnavailable | Manzil qidiruvi hozir ishlamayapti. Xaritani surib, belgini o'zingiz qo'ying. | Поиск адреса сейчас не работает. Передвиньте карту и поставьте метку сами. |
| addressWordsKept | Yozgan manzilingizni kuryer uchun saqlaymiz | Ваш адрес словами сохраним для курьера |
| addressMyLocation | Men qayerdaman | Где я |
| addressLocationFailed | Joylashuvingizni aniqlab bo'lmadi. Xaritani o'zingiz suring. | Не удалось определить, где вы. Передвиньте карту сами. |
| addressSearchClear | Tozalash | Очистить |
| addressPointConfirm | Nuqtani tasdiqlash | Подтвердить точку |

- [ ] **Step 1: Failing tests.**
  - **`address_search_api_test.dart`** (the `FakeHttpClientAdapter` pattern of `addresses_api_test.dart`):
    - it posts `{"query": "Navoiy 5"}` to `/customer/address-search`;
    - `data` with a point parses to `GeoPoint('41.299512','69.240146')`;
    - `data: null` gives `null`;
    - `503` throws `ApiRefusal` `provider_unavailable`.
  - **`address_point_step_test.dart`**, with `FakeAddressMap`, `FakeAddressSearch` (answers set per query, completers for late answers) and `FakeDeviceLocation`:
    - "the pin starts where it was given and confirms where it was left": `fake-map-initial` shows the initial point; after `fake-map-move`, confirm gives `fakeDoor` and `words` `null`.
    - "a typed address moves the map and is kept": `Navoiy 5` answered with a point; `fake-map-target` shows it, the hint is `addressSearchFound`, and confirm gives that point and `words` `Navoiy 5`.
    - "nothing found asks for the pin and keeps the words": the not-found box and `address-words-kept` show, and confirm gives the initial point with the words.
    - "an unavailable search says so": a `503` and a network failure each show the unavailable box.
    - "two characters search nothing".
    - "clearing forgets the words".
    - "a late answer does not move a map the Customer moved" (Review Focus 1): the answer completes after `fake-map-move`, so the target stays unset and the point stays `fakeDoor`. Also "an older answer after a newer search is ignored".
    - "where am I moves the map" and "a refused location says so and leaves the map" (Review Focus 2): `null` gives the snackbar, the point is unchanged, and the button is enabled again.
    - "without a map the point is typed": `FakeAddressMap(movable: false)` hides the search and "где я"; confirm with an empty field shows `fieldRequired` and does not confirm.
    - "the step holds at 320×640 with text ×2", in `uz` and `ru`, in the start, not-found and unavailable states.

  Run `flutter test test/features/addresses`. Expected: FAIL.
- [ ] **Step 2: Implement.** Run `flutter gen-l10n` for the texts.
- [ ] **Step 3: Run** the tests, `flutter analyze` and `dart format --set-exit-if-changed lib test`. Expected: PASS.
- [ ] **Step 4: `DL-86` item 3:** "**The map step** (drawings 22, 22б): the pin in the centre, the address in words above, and \"где я\". A typed address moves the map; nothing found, or a lookup that cannot answer, leaves the pin to the Customer. Either way the words are kept and offered to the form, so the Courier still reads them. Only the latest search's answer moves the map, and none once the Customer has moved it."
- [ ] **Step 5: Commit**: `feat(addresses): the map step with the typed address`.

---

### Task 4: A new address in two steps, and the kit form

**Files:**
- Modify:
  - `frontend/lib/features/addresses/presentation/addresses_screens.dart`: `AddressFormScreen` and `_AddressForm`.
  - `frontend/test/features/addresses/customer_account_screens_test.dart`
  - flows in `catalog/customer_home_test.dart` and `checkout/checkout_screen_test.dart` that add an address
  - both `.arb` files
  - `docs/03-features.md:31`, `docs/04-user-flows.md:56`, `docs/DECISIONS.md`
- Create: `frontend/lib/features/addresses/presentation/address_label_chips.dart`

**Interfaces:**
- Consumes: Task 3's `AddressPointStep`, `AddressPointResult`; Task 2's `addressMapProvider.preview`.
- Produces: unchanged routes and the unchanged pop contract: a new address pops with the saved `Address` (`DL-75`).
- The host:
  - `_AddressFormState` keeps the controllers, `_point`, `_sentPoint` and `_step` (`point` | `details`).
  - A new address starts on `point`, an edit on `details`.
  - The app bar title is `addressPointTitle` on `point`, otherwise `addressNew` / `addressEdit`.
  - `PopScope`:
    - back from `details` of a new address returns to `point` with `_point` kept;
    - back from `point` of an edit returns to `details` with nothing changed;
    - otherwise back pops;
    - nothing moves while the save runs.
  - Confirming the point sets `_point` and goes to `details`. On a new address whose street is empty, the street takes the words, cut to 160 characters.
- The form (drawing 22а), in order:
  1. The preview `address-preview` (height 118, radius 16), with the chip `address-change-point` (bottom right, `addressChangePoint`, disabled while saving), which goes to `point`.
  2. `field-street` `addressFieldStreet` *.
  3. A row of two: `field-house` `addressHouse` * and `field-apartment` `addressFieldApartment`.
  4. `field-landmark` `addressLandmark`, hint `addressLandmarkHint`.
  5. `field-delivery_note` `addressFieldNote`, hint `addressNoteHint`, three lines, counter `n / 300`.
  6. "Как назвать адрес" `addressLabelTitle`: the chips `label-home` (`addressLabelHome`, home icon), `label-work` (`addressLabelWork`, work icon) and `label-custom` (`addressLabelCustom`, edit icon).
     - A chip sets the label to its word; tapping the chosen one clears it.
     - "Своё" shows `field-label` (`addressLabelName`, 60).
     - An existing label equal to the current language's home or work word selects that chip; any other label selects "Своё" with its text; no label selects none.
     - A new address starts with none.
  7. The footer bar (`c-foot` of the drawing) holds `address-save` `addressSaveButton`, with `_SaveFailure` above it.
- Lengths and validation are as today (street 160 *, house 40 *, apartment 40, landmark 160, note 300, label 60).
- Texts:

| Key | uz | ru |
|---|---|---|
| addressFieldStreet | Ko'cha, massiv yoki mavze | Улица, массив или квартал |
| addressFieldApartment | Xonadon yoki ofis | Квартира или офис |
| addressLandmarkHint | Masalan: 64-maktab qarshisida | Например: напротив школы № 64 |
| addressFieldNote | Kuryerga izoh | Комментарий курьеру |
| addressNoteHint | Podyezd, qavat, domofon kodi | Подъезд, этаж, код домофона |
| addressLabelTitle | Manzil nomi | Как назвать адрес |
| addressLabelHome | Uy | Дом |
| addressLabelWork | Ish | Работа |
| addressLabelCustom | Boshqa | Своё |
| addressLabelName | Nomi | Название |
| addressChangePoint | Nuqtani o'zgartirish | Изменить точку |
| addressSaveButton | Manzilni saqlash | Сохранить адрес |

  `addressStreet`, `addressApartment`, `addressDeliveryNote`, `addressLabel` and `addressMapUnavailable` are deleted if nothing else uses them; check with `grep`.

- [ ] **Step 1: Rewrite the existing tests to the new flow, then add the new ones.**
  - **Mapping.** Every flow that opens a new address now meets the map step first: `fake-map-move` there if the test moved the pin, then `address-point-confirm`, then the fields. This covers `fillNewAddress` and the tests at lines 203, 235, 247, 281, 377, 402, 424 and 444 of `customer_account_screens_test.dart`, plus the add-address flows of the home and checkout tests.
  - The coordinate tests (lines 353, 534, 545, 556, 567) enter the point fields on the map step and confirm there.
  - The edit tests (299, 319, 700) start on the form and find `fake-map-preview` with the stored point.
  - **New tests:**
    - "typed words fill an empty street": confirm with words `квартал Ц-5, дом 12` gives `field-street` that text.
    - "an edit keeps its street when the point changes": `address-change-point`, then `fake-map-move` and confirm; the street is unchanged and the save sends `fakeDoor`.
    - "back walks the steps" (Review Focus 3): new address: form → back → map step showing the same point (`fake-map-initial`) → back → the list; edit: change point → back → form with the old point; system back via `tester.binding.handlePopRoute()` too; while a save is pending, back does not leave.
    - "the label chips": Дом selected sends `Uy` (in `uz`), tapping again sends `null`; Своё shows `field-label` and sends its text; an address labelled `Ofis` opens with Своё and `Ofis`.
    - "a point outside the area is refused on the form": the existing distances text, shown above the button.
    - "the form holds at 320×640 with text ×2", in `uz` and `ru`, with a 160-character street and a 60-character custom label.

  Run `flutter test test/features/addresses test/features/catalog test/features/checkout`. Expected: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the full `flutter test`, `flutter analyze` and `dart format --set-exit-if-changed lib test`. Expected: PASS.
- [ ] **Step 4: Docs.**
  - **`docs/03:31`.** "The map is Yandex M…" becomes "The point is set on a Google map, or found from the address typed in words and checked by the Customer; the words fill the street (`DL-84` item 2, `DL-86`)."
  - **`docs/04:56`.** "places a point on the Yandex map" becomes "places the pin on the map, or types the address and checks where the map put the pin, then enters the street and house…".
  - **`DL-86` item 4:** "**A new address is two steps** on one screen (drawings 22 and 22а): the point, then the details under a still preview with \"Изменить точку\". An edit opens on the details. Back walks the steps. The label is chosen from Дом, Работа or Своё, and stored as the word, since the label is the Customer's own text."
- [ ] **Step 5: Commit**: `feat(addresses): a new address in two steps with the kit form`.

---

### Task 5: The delivery-address sheet

**Files:**
- Create: `frontend/lib/core/formatting/address_format.dart`
- Modify:
  - `frontend/lib/features/addresses/presentation/delivery_address_widgets.dart`: `_DeliveryAddressSheet`.
  - `frontend/lib/features/cart/presentation/cart_address_card.dart:28-29`: the second line.
  - the sheet's tests in `customer_home_test.dart` and `cart_screens_test.dart`
  - both `.arb` files
- Test: `frontend/test/features/addresses/delivery_address_sheet_test.dart`, `frontend/test/core/formatting/address_format_test.dart`

**Interfaces:**
- Produces: `String addressFullLine(AppLocalizations l10n, {required String street, required String house, String? apartment})`.
  - It gives `"street, house"`, plus `", кв. 5"` / `", 5-xonadon"` through `addressApartmentShort(apartment)` when the apartment is digits only, or `", <apartment>"` as typed otherwise.
  - Task 6 uses it too.
- The sheet (drawings 21, 21а):
  - **Header.** The title `deliveryAddressSheetTitle` (new text below), with a close button `delivery-address-close` (28, round, outlined).
  - **One card per address**, `delivery-address-{id}` (radius 16, the chosen one with a 1.5 primary border):
    - a radio;
    - the bold title: label, or `street, house` when there is none;
    - the line: `addressFullLine` with a label, or only the apartment part without one (drawing: "ул. Навои, 30" / "кв. 12"), and none when that is empty;
    - "Ориентир: …" `addressLandmarkLine` when set;
    - the ⋮ `delivery-address-menu-{id}`.
  - **Behaviour.**
    - Tapping a card chooses it and closes, as today.
    - The menu offers `delivery-address-edit-{id}` (`addressMenuEdit`), which closes the sheet and pushes `AppPaths.customerAddress(id)`, and `delivery-address-delete-{id}` (`addressRemove`, in the danger colour).
    - Delete asks `addressRemoveConfirm` (`address-remove-confirm`), then removes through `addressListActionsProvider`. The sheet stays open, and a failure shows in it through `FailureMessage`.
  - **"Добавить новый адрес"** `delivery-address-new` (`addressAddNew`; 54 high, primary, plus icon) works as today.
- Texts:

| Key | uz | ru |
|---|---|---|
| deliveryAddressSheetTitle (replace text) | Yetkazish manzili | Адрес доставки |
| addressAddNew | Yangi manzil qo'shish | Добавить новый адрес |
| addressMenuEdit | O'zgartirish | Изменить |
| addressLandmarkLine | Mo'ljal: {landmark} | Ориентир: {landmark} |
| addressApartmentShort | {apartment}-xonadon | кв. {apartment} |

- [ ] **Step 1: Failing tests.**
  - **`address_format_test`:** `14` + `5` gives `Чиланзар, 14, кв. 5` (ru) and `…, 5-xonadon` (uz); `Офис 3` stays as typed; `null` and blank give no apartment part.
  - **`delivery_address_sheet_test`:**
    - "the cards show the label, the line and the landmark": the three addresses of the drawing, with Дом chosen.
    - "choosing a card closes the sheet": the choice is stored.
    - "edit opens the address".
    - "delete asks, removes and stays": the chosen address deleted falls back to the newest.
    - "a refused delete shows in the sheet".
    - "close closes".
    - "the sheet holds at 320×640 with text ×2", in `uz` and `ru`, with a 60-character label and a 160-character street.
  - **Cart card:** its second line now shows the apartment (`cart_screens_test` at the card's existing test).

  Run them. Expected: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the full `flutter test`, `flutter analyze` and `dart format`. Expected: PASS.
- [ ] **Step 4: `DL-86` item 5:** "**The delivery-address sheet** (drawings 21, 21а): a card per address with its label, its full line and its landmark, and a menu to edit or delete it. A deletion asks first and keeps the sheet open; deleting the chosen address falls back to the newest (`DL-75`). The cart's address card shows the apartment too."
- [ ] **Step 5: Commit**: `feat(addresses): the kit delivery-address sheet`.

---

### Task 6: The Courier's address card with Yandex and copy

**Files:**
- Modify:
  - `frontend/lib/core/platform/map_links.dart`: `YandexRouteLinks` replaces `GeoMapLinks`.
  - `frontend/lib/features/courier/presentation/courier_screens.dart`:
    - the detail's address, landmark and note lines (around 300–310) become `_AddressCard`;
    - `courier-open-map` in `_Contacts` leaves;
    - `addressLine` uses `addressFullLine`.
  - `android/app/src/main/AndroidManifest.xml` `<queries>`: replace the `geo` intent with `<package android:name="ru.yandex.yandexnavi"/>` and a `VIEW` intent for `https`.
  - `test/core/platform/map_links_test.dart`, `test/features/courier/presentation/courier_screens_test.dart`
  - both `.arb` files
  - `tasks/REDESIGN_CUSTOMER.md`, `docs/DECISIONS.md`

**Interfaces:**
- Consumes: Task 5's `addressFullLine`.
- Produces: `class YandexRouteLinks implements MapLinks`, with `const YandexRouteLinks({this.launch = _launchExternal})`.
  - `open(lat, lng)` first tries `yandexnavi://build_route_on_map?lat_to={lat}&lon_to={lng}`.
  - When that is not opened (`false` or `PlatformException`), it tries `https://yandex.uz/maps/?rtext=~{lat}%2C{lng}&rtt=auto`.
  - It returns `false` only when both fail. Both open with `LaunchMode.externalApplication`.
- The card (drawing 22в), `courier-address-card`, a white card with radius 16 and the kit shadow:
  - the caps label `courierAddressTitle`;
  - the bold `courier-address` = `addressFullLine`;
  - `courierLandmark` when set, and `courierNoteLine` when there is a note;
  - `courier-open-yandex`: primary, 50 high, navigation icon, `courierOpenYandex`; it calls `mapLinksProvider.open`, and on `false` shows the snackbar `courierMapFailed(line)`;
  - `courier-copy-address`: outlined, content-copy icon, `courierCopyAddress`; it puts the bold line on the clipboard (`Clipboard.setData`) and shows the snackbar `courierAddressCopied`.
- Texts:

| Key | uz | ru |
|---|---|---|
| courierAddressTitle | Yetkazish manzili | Адрес доставки |
| courierNoteLine | Kuryerga: {note} | Курьеру: {note} |
| courierOpenYandex | Yandexda ochish | Открыть в Яндексе |
| courierCopyAddress | Manzilni nusxalash | Скопировать адрес |
| courierAddressCopied | Manzil nusxalandi | Адрес скопирован |
| courierMapFailed (replace text) | Yandex ochilmadi. Manzil: {address} | Не удалось открыть Яндекс. Адрес: {address} |

  `courierOpenMap`, `courierAddress` and `courierDeliveryNote` are deleted if no other screen uses them.

- [ ] **Step 1: Failing tests.**
  - **`map_links_test`:**
    - "the Navigator gets a route to the point": the first URI is exactly `yandexnavi://build_route_on_map?lat_to=41.311081&lon_to=69.240562`.
    - "without the Navigator the Yandex Maps link opens" (Review Focus 5): the first launch `false`, then `https://yandex.uz/maps/?rtext=~41.311081%2C69.240562&rtt=auto`, and `true`.
    - "a PlatformException counts as not opened".
    - "nothing opens either: false".
  - **`courier_screens_test`** (rewrite the `courier-open-map` tests at lines 240 and 250):
    - "the card shows the line, the landmark and the note".
    - "open in Yandex asks for the point": `FakeMapLinks` gets the order's coordinates.
    - "a failed open shows the address".
    - "copy puts the line on the clipboard and says so": mock `SystemChannels.platform` `Clipboard.setData`, then read back `Чиланзар, 9-й квартал, 14, кв. 5`.
    - "the order holds at 320×640 with text ×2", in `uz` and `ru`.

  Run `flutter test test/core/platform test/features/courier`. Expected: FAIL.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** the full `flutter test`, `flutter analyze`, `dart format` and `flutter build apk --debug …`. Expected: PASS.
- [ ] **Step 4: Docs and tracker.**
  - **`DL-86` item 6:** "**The Courier's address** (drawing 22в, `DL-84` item 3): a card with the full line, the landmark and the note, then \"Открыть в Яндексе\" and \"Скопировать адрес\". The first opens Yandex Navigator with a route to the pin and, when the Navigator is missing, the same route on Yandex Maps, the app or the browser. The Navigator is called without the signature its documentation describes for version 2.40 and later; if it refuses such calls on a Courier's phone, the app is registered with Yandex and the server signs the link. The copy is the line as shown. The `geo:` link of `DL-54` (16) is replaced."
  - **`tasks/REDESIGN_CUSTOMER.md`.**
    - Row 4 becomes `Merged (PR #94, #NN)`; the merge commit fills in the number.
    - Known gaps gain:
      - the iOS Google key and `GMSServices` on the first Mac build;
      - the server key's IP restriction at deployment;
      - the Play signing SHA-1 on the app's key at the first Play upload;
      - the Navigator signature if a Courier's phone refuses.
- [ ] **Step 5: Commit**: `feat(courier): the address card with Yandex and copy`.

---

## After the tasks

1. `test-runner` runs the full backend suite and the full frontend suite.
2. `branch-reviewer` (opus) reviews `dd9ca1c..HEAD`, then one fix wave and a scoped re-review.
3. `/security-review`: the branch adds an external provider call with Customer input, a location permission and a key.
4. Push, open the PR, merge on both required checks.
5. Walk the real stack on the emulator with the keys:
   - the map shows and moves;
   - "Navoiy 5" moves the map;
   - garbage shows not found;
   - "где я" with the permission denied, then granted (the emulator's location);
   - save an address;
   - the sheet's menu;
   - the Courier's buttons (no Navigator on the emulator, so the browser opens Yandex Maps);
   - copy.

   Take 4–5 screenshots for the Owner.
