# Customer Home Header (Redesign Part 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Customer's home (`/customer`, `CatalogHomeScreen`) gets the top of design 4a: a deep-green header with a curved bottom holding a white pill search, a round white cart button with an orange count, and the delivery address line ("Доставим сюда" + address in lime) that changes or adds the address; the old app bar goes, its buttons move to a floating bottom bar (orders, profile), the profile (logout) and the active-mode bar (back to staff).

**Architecture:** Brand colours and the Manrope font enter `core/theme` once. The delivery address is a device-remembered choice per Customer account (`DeliveryAddressChoice`, application layer, `PreferenceStore`), resolved against the active address list by `deliveryAddressProvider`; checkout preselects it. Presentation: `DeliveryAddressLine` and its sheet in the `addresses` feature, `CustomerHomeHeader` and `CustomerHomeNav` in the `catalog` feature. No server change.

**Tech Stack:** Flutter 3.47.5, Dart, flutter_riverpod 3, go_router, `flutter gen-l10n` (ARB in `frontend/lib/core/localization/l10n/`, template `app_uz.arb`).

**Spec:** Claude Design project "BarakaBozor — стиль покупателя", file `VariantJ.dc.html`, screen "4a · Главная" (the header and the floating nav only; category circles and the product grid are later parts). The Owner's reference screenshot of 2026-10-14 confirms the header: search pill + round cart with badge on dark green, a small caption and the address in lime with an arrow icon under it. Owner decision recorded as `DL-74`, engineering decisions as `DL-75` (Task 7).

## Global Constraints

- Work in `G:/project/baraka-bozor/frontend` on branch `task/redesign-1-home-header`. Never commit to `main`.
- Flutter is `G:/tools/flutter/bin/flutter`; before any flutter command set `TEMP` and `TMP` to `G:\tools\tmp` (C: is nearly full).
- Colours exactly: green `#0F3B2E`, lime `#B8E35A`, orange `#FF6A13`, ink `#1A1D21`, muted `#6B7280`. Font family `Manrope`.
- Generated files (`lib/core/localization/generated/`) are regenerated with `flutter gen-l10n`, never hand-edited. No new package in `pubspec.yaml` dependencies; `pubspec.lock` must not change.
- Keep the existing widget keys: `catalog-search`, `catalog-search-clear`, `open-cart`, `cart-count`, `open-orders`, `open-profile`, `logout-button`, `switch-to-staff-button`, `active-mode`.
- Uzbek strings use the ASCII apostrophe as the ARB files already do (`O'zbekcha`).
- Every widget test that renders the home also runs at a 320×640 window with `textScaleFactorTestValue = 2`, in `uz` and `ru`, and must raise no overflow (`tester.takeException()` is null).
- Never delete, skip or weaken a test. A test whose expectation moves (logout now on the profile) is rewritten to assert the new place.
- Verification per task: the focused tests named in the task, then `flutter analyze` and `dart format --set-exit-if-changed lib test` from `frontend/`. The full suite (`flutter test`) runs in Task 7.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

- Two Customer accounts on one phone: after the second signs in, the header must never show the first one's address, not even for a frame (choice keyed by account; list reload treated as loading). Test in Task 2.
- The chosen address was removed in the profile: the header falls back to the newest active address and checkout does not preselect the removed one. Tests in Task 2 and Task 6.
- Large text (scale 2) on a 320 px phone in both languages: header, address line, active-mode bar with its button, and the floating bar must not overflow; the last category must stay reachable above the floating bar. Tests in Task 4 and Task 5.
- The address list fails to load: the header offers a retry that reloads it, never a stale or foreign address, and the home stays usable. Test in Task 5.
- A checkout whose confirmation outcome is unknown keeps the address it was sent with, even if the header's choice differs. Test in Task 6.

---

### Task 1: Brand palette and the Manrope font

**Files:**
- Create: `frontend/lib/core/theme/brand_colors.dart`
- Create: `frontend/lib/core/theme/font_licenses.dart`
- Create: `frontend/assets/fonts/Manrope-Variable.ttf`, `frontend/assets/fonts/Manrope-OFL.txt` (downloaded)
- Modify: `frontend/lib/core/theme/app_theme.dart`, `frontend/lib/main.dart`, `frontend/pubspec.yaml`
- Test: `frontend/test/core/theme/app_theme_test.dart`, Create `frontend/test/core/theme/font_licenses_test.dart`

**Interfaces:**
- Produces: `abstract final class BrandColors { static const Color green, lime, orange, ink, muted; }`; `const Color appSeedColor = BrandColors.green;`; `const String appFontFamily = 'Manrope';`; `void registerFontLicenses()`.

- [ ] **Step 1: Download the font from Google Fonts' official repository**

```bash
cd /g/project/baraka-bozor/frontend
mkdir -p assets/fonts
curl -fsSL -o assets/fonts/Manrope-Variable.ttf "https://github.com/google/fonts/raw/main/ofl/manrope/Manrope%5Bwght%5D.ttf"
curl -fsSL -o assets/fonts/Manrope-OFL.txt "https://github.com/google/fonts/raw/main/ofl/manrope/OFL.txt"
od -A x -t x1 -N 4 assets/fonts/Manrope-Variable.ttf   # expect 00 01 00 00 (TrueType)
head -3 assets/fonts/Manrope-OFL.txt                  # expect the Manrope copyright line
ls -l assets/fonts
```

Flutter 3.47 maps `FontWeight` onto a variable font's `wght` axis, so one variable file serves weights 400–800.

- [ ] **Step 2: Write the failing tests**

Append to `test/core/theme/app_theme_test.dart` inside the group:

```dart
    test('takes its seed from the brand green (DL-75)', () {
      expect(appSeedColor, BrandColors.green);
    });

    test('sets the bundled Manrope as the font of every text style', () {
      for (final Brightness brightness in Brightness.values) {
        final TextTheme text = buildAppTheme(brightness).textTheme;
        expect(text.bodyMedium!.fontFamily, appFontFamily);
        expect(text.titleLarge!.fontFamily, appFontFamily);
      }
      expect(appFontFamily, 'Manrope');
    });
```

(add `import 'package:baraka_bozor/core/theme/brand_colors.dart';`)

Create `test/core/theme/font_licenses_test.dart`:

```dart
import 'package:baraka_bozor/core/theme/font_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled Manrope file is a font Flutter can load', () async {
    final FontLoader loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await loader.load();
  });

  test('the font licence (SIL OFL 1.1) is on the licences page', () async {
    registerFontLicenses();
    final List<LicenseEntry> entries = await LicenseRegistry.licenses.toList();
    final LicenseEntry manrope = entries.singleWhere(
      (LicenseEntry entry) => entry.packages.contains('Manrope'),
    );
    expect(
      manrope.paragraphs.map((LicenseParagraph p) => p.text).join('\n'),
      contains('SIL OPEN FONT LICENSE'),
    );
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/core/theme/` — Expected: compile errors (`BrandColors`, `appFontFamily`, `registerFontLicenses` undefined).

- [ ] **Step 4: Implement**

`lib/core/theme/brand_colors.dart`:

```dart
import 'package:flutter/painting.dart';

/// BarakaBozor's palette, from the Customer design the Owner chose on
/// 2026-10-14 (design 4a, `DL-74`). Every brand colour is named here, so a
/// change of colour is a change in one place (interview topic 8.3).
abstract final class BrandColors {
  /// The header's deep green, and the seed of the Material scheme.
  static const Color green = Color(0xFF0F3B2E);

  /// The delivery address on the header; later, what is in the cart.
  static const Color lime = Color(0xFFB8E35A);

  /// Counts and the screen's one main action.
  static const Color orange = Color(0xFFFF6A13);

  /// Text on white.
  static const Color ink = Color(0xFF1A1D21);

  /// Secondary text and inactive icons on white.
  static const Color muted = Color(0xFF6B7280);
}
```

`lib/core/theme/app_theme.dart` (replace the file body; keep the public names):

```dart
import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// The seed every Material colour in the client is derived from: the brand
/// green of design 4a (`DL-75`).
///
/// Public so a test can prove both schemes really come from this one value
/// rather than merely differing from each other.
const Color appSeedColor = BrandColors.green;

/// The interface font, bundled with the app (`assets/fonts`), so text looks
/// the same offline and on every device.
const String appFontFamily = 'Manrope';

/// Builds the Material 3 theme for [brightness]: one seed, the brand font.
/// Screens redesigned after design 4a take their brand colours from
/// [BrandColors]; component themes arrive with the parts that need them.
ThemeData buildAppTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    fontFamily: appFontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: appSeedColor,
      brightness: brightness,
    ),
  );
}
```

`lib/core/theme/font_licenses.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The licence that ships with the bundled Manrope font.
const String manropeLicenseAsset = 'assets/fonts/Manrope-OFL.txt';

/// Puts the bundled font's licence on the app's licences page: the SIL Open
/// Font License requires its notice to travel with the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(<String>[
      'Manrope',
    ], await rootBundle.loadString(manropeLicenseAsset));
  });
}
```

`lib/main.dart`: `import 'core/theme/font_licenses.dart';` and in `main()` call `registerFontLicenses();` before `runApp(...)`.

`pubspec.yaml`, under `flutter:` after `generate: true` (keep the existing comment):

```yaml
  fonts:
    - family: Manrope
      fonts:
        - asset: assets/fonts/Manrope-Variable.ttf
  assets:
    - assets/fonts/Manrope-OFL.txt
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/theme/` — Expected: all PASS. Then `flutter analyze` and `dart format --set-exit-if-changed lib test` — clean. `git diff --stat pubspec.lock` — empty.

- [ ] **Step 6: Commit**

```bash
git add frontend/assets/fonts frontend/lib/core/theme frontend/lib/main.dart frontend/pubspec.yaml frontend/test/core/theme
git commit -m "feat(redesign): brand palette and the bundled Manrope font

The Customer redesign (design 4a) sets the palette and the font. Manrope
is bundled as one variable TTF from google/fonts (OFL 1.1, licence on the
licences page) rather than fetched at runtime, so text is the same offline.
No package added."
```

---

### Task 2: The delivery address choice

**Files:**
- Create: `frontend/lib/features/addresses/application/delivery_address.dart`
- Modify: `frontend/lib/features/addresses/domain/addresses.dart` (add `Address.streetLine`), `frontend/lib/features/checkout/presentation/checkout_screen.dart` (use `streetLine`, delete `_addressLine`)
- Test: Create `frontend/test/features/addresses/application/delivery_address_test.dart`

**Interfaces:**
- Consumes: `preferenceStoreProvider` (`lib/app/providers.dart`), `customerAccountProvider` (`lib/core/session/customer_account.dart`, `Provider<String?>`), `addressesProvider` (`FutureProvider<List<Address>>`, newest first per `docs/09` section 13).
- Produces:
  - `String get streetLine` on `Address` → `'$street, $house'`.
  - `class DeliveryAddressChoice extends AsyncNotifier<String?>` with `DeliveryAddressChoice(this.account)`, `static String preferenceKey(String account)` → `'delivery_address.$account'`, `Future<void> choose(String addressId)`.
  - `deliveryAddressChoiceProvider` — `AsyncNotifierProvider.autoDispose.family<DeliveryAddressChoice, String?, String>`.
  - `deliveryAddressProvider` — `Provider.autoDispose<AsyncValue<Address?>>`.

- [ ] **Step 1: Write the failing tests**

`test/features/addresses/application/delivery_address_test.dart`:

```dart
import 'package:baraka_bozor/app/providers.dart';
import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/core/session/customer_account.dart';
import 'package:baraka_bozor/features/addresses/application/addresses_controllers.dart';
import 'package:baraka_bozor/features/addresses/application/delivery_address.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_customer_repositories.dart';
import '../../../support/in_memory_stores.dart';

/// The signed-in Customer account, switchable in a test.
class _Account extends Notifier<String?> {
  @override
  String? build() => 'c';

  void set(String? account) => state = account;
}

final NotifierProvider<_Account, String?> _account =
    NotifierProvider<_Account, String?>(_Account.new);

void main() {
  late InMemoryPreferenceStore store;
  late FakeAddressesRepository addresses;

  setUp(() {
    store = InMemoryPreferenceStore();
    addresses = FakeAddressesRepository(
      rows: <Address>[
        address(id: 'a-new', street: 'Navoiy', house: '5'),
        address(id: 'a-old', label: null),
      ],
    );
  });

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer(
      retry: (int retryCount, Object error) => null,
      overrides: [
        preferenceStoreProvider.overrideWithValue(store),
        addressesRepositoryProvider.overrideWithValue(addresses),
        customerAccountProvider.overrideWith((Ref ref) => ref.watch(_account)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(deliveryAddressProvider, (_, _) {});
    return c;
  }

  Future<AsyncValue<Address?>> settled(ProviderContainer c) async {
    for (int i = 0; i < 20 && c.read(deliveryAddressProvider).isLoading; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(deliveryAddressProvider);
  }

  test('with no choice the newest active address is the delivery address', () async {
    expect((await settled(container())).value?.id, 'a-new');
  });

  test('a choice is remembered on the device for that account', () async {
    final ProviderContainer first = container();
    await settled(first);
    await first.read(deliveryAddressChoiceProvider('c').notifier).choose('a-old');
    expect((await settled(first)).value?.id, 'a-old');
    expect(store.values[DeliveryAddressChoice.preferenceKey('c')], 'a-old');

    // A later launch reads it back.
    expect((await settled(container())).value?.id, 'a-old');
  });

  test('a chosen address no longer active falls back to the newest', () async {
    store.values[DeliveryAddressChoice.preferenceKey('c')] = 'a-removed';
    expect((await settled(container())).value?.id, 'a-new');
  });

  test('no addresses is no delivery address', () async {
    addresses.rows = <Address>[];
    final AsyncValue<Address?> value = await settled(container());
    expect(value.hasValue, isTrue);
    expect(value.value, isNull);
  });

  test('another account never starts from the first one\'s choice', () async {
    final ProviderContainer c = container();
    await settled(c);
    await c.read(deliveryAddressChoiceProvider('c').notifier).choose('a-old');
    await settled(c);

    c.read(_account.notifier).set('d');
    // Until the list and d's choice are read again, nothing is shown.
    expect(c.read(deliveryAddressProvider).isLoading, isTrue);
    expect((await settled(c)).value?.id, 'a-new');
  });

  test('without a Customer the delivery address stays loading', () async {
    final ProviderContainer c = container();
    c.read(_account.notifier).set(null);
    expect(c.read(deliveryAddressProvider).isLoading, isTrue);
  });

  test('a list that fails to load is an error, not an address', () async {
    addresses.loadFailure = const UnexpectedFailure();
    final AsyncValue<Address?> value = await settled(container());
    expect(value.hasError, isTrue);
    expect(value.hasValue, isFalse);
  });
}
```

Notes for the implementer: `FakeAddressesRepository.rows` is a public mutable field and `loadFailure` answers the next load once (see `test/support/fake_customer_repositories.dart`). If `UnexpectedFailure` lives elsewhere, import it from where `lib/core/network/api_failure.dart` exports it. If the `settled` loop needs more turns for the fake's `async` answers, raise the bound; never add a real delay.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/addresses/application/delivery_address_test.dart` — Expected: compile error, `delivery_address.dart` missing.

- [ ] **Step 3: Implement**

In `lib/features/addresses/domain/addresses.dart`, inside `Address` after the fields:

```dart
  /// The street and house as one line: how the home's header and checkout
  /// name an address.
  String get streetLine => '$street, $house';
```

In `checkout_screen.dart` delete `String _addressLine(Address address) => ...;` and replace its uses with `address.streetLine` (in `_calculate` and in `_Addresses`).

`lib/features/addresses/application/delivery_address.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/session/customer_account.dart';
import '../domain/addresses.dart';
import 'addresses_controllers.dart';

/// The address the Customer last chose to deliver to, remembered on this
/// device for their account (`DL-75`). It holds the id only: the address
/// itself always comes from the current active list.
class DeliveryAddressChoice extends AsyncNotifier<String?> {
  DeliveryAddressChoice(this.account);

  final String account;

  /// Per account, so a second Customer on the same phone never starts from
  /// the first one's choice.
  static String preferenceKey(String account) => 'delivery_address.$account';

  @override
  Future<String?> build() =>
      ref.read(preferenceStoreProvider).read(preferenceKey(account));

  Future<void> choose(String addressId) async {
    state = AsyncData<String?>(addressId);
    await ref
        .read(preferenceStoreProvider)
        .write(preferenceKey(account), addressId);
  }
}

final AsyncNotifierProviderFamily<DeliveryAddressChoice, String?, String>
deliveryAddressChoiceProvider = AsyncNotifierProvider.autoDispose
    .family<DeliveryAddressChoice, String?, String>(DeliveryAddressChoice.new);

/// The signed-in Customer's delivery address: the one they chose while it
/// is still among their active addresses, otherwise the newest of them, or
/// `null` when they have none.
///
/// Loading while there is no Customer and while the list or the choice
/// loads or reloads — a reload may still carry another account's list — so
/// one account's address is never shown to another (`frontend/AGENTS.md`
/// section 5).
final Provider<AsyncValue<Address?>> deliveryAddressProvider =
    Provider.autoDispose<AsyncValue<Address?>>((Ref ref) {
      final String? account = ref.watch(customerAccountProvider);
      if (account == null) {
        return const AsyncLoading<Address?>();
      }
      final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
      final AsyncValue<String?> chosen = ref.watch(
        deliveryAddressChoiceProvider(account),
      );
      if (addresses.isLoading || chosen.isLoading) {
        return const AsyncLoading<Address?>();
      }
      if (addresses.hasError) {
        return AsyncError<Address?>(addresses.error!, addresses.stackTrace!);
      }
      final List<Address> list = addresses.requireValue;
      final String? id = chosen.value;
      return AsyncData<Address?>(
        list.where((Address a) => a.id == id).firstOrNull ?? list.firstOrNull,
      );
    });
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/addresses/application/delivery_address_test.dart test/features/checkout/` — Expected: PASS. Then analyze + format.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/addresses frontend/lib/features/checkout/presentation/checkout_screen.dart frontend/test/features/addresses/application
git commit -m "feat(addresses): the delivery address the Customer chose, per account

Remembered on the device under the account's own key, resolved against the
active list (newest when nothing valid is chosen) and loading while the list
or the account changes, so no account sees another's address."
```

---

### Task 3: Logout on the profile, the way back to staff on the mode bar

**Files:**
- Modify: `frontend/lib/core/widgets/active_mode_bar.dart`, `frontend/lib/features/profile/presentation/profile_screen.dart`, `frontend/lib/features/catalog/presentation/catalog_screens.dart`
- Test: `frontend/test/features/catalog/catalog_screens_test.dart` (the two-sessions test), `frontend/test/features/addresses/customer_account_screens_test.dart` (new logout test)

**Interfaces:**
- Produces: `const ActiveModeBar({Widget? action, Key? key})` — `action` shows at the bar's end, only while the bar shows.

- [ ] **Step 1: Write the failing tests**

In `catalog_screens_test.dart`, the test `'with two sessions a phone-size window shows the mode on every screen'`: replace `expect(byKey('logout-button'), findsOneWidget);` with

```dart
        expect(
          find.descendant(
            of: find.byType(ActiveModeBar),
            matching: byKey('switch-to-staff-button'),
          ),
          findsOneWidget,
          reason: 'the way back to the staff area sits on the mode bar',
        );
        expect(byKey('logout-button'), findsNothing, reason: 'logout is on the profile');
```

(import `package:baraka_bozor/core/widgets/active_mode_bar.dart`). Keep the later `tap(byKey('switch-to-staff-button'))` and its expectation unchanged.

In `customer_account_screens_test.dart` add (next to the other profile tests, reusing its `openProfile` helper, `auth` and `byKey`):

```dart
  testWidgets('the profile logs the Customer out', (WidgetTester tester) async {
    await openProfile(tester);
    await tester.tap(byKey('logout-button'));
    await tester.pumpAndSettle();
    expect(auth.calls, contains('logout:customer'));
    expect(byKey('profile-list'), findsNothing);
  });
```

(Use the helper's real names in that file; `FakeAuthRepository.calls` records `logout:customer`, as `test/features/auth/presentation/staff_login_flow_test.dart:178` shows for staff.)

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/catalog/catalog_screens_test.dart test/features/addresses/customer_account_screens_test.dart` — Expected: FAIL (logout still on home, none on profile; switch not inside the bar).

- [ ] **Step 3: Implement**

`active_mode_bar.dart`: add the field and render it:

```dart
class ActiveModeBar extends ConsumerWidget {
  const ActiveModeBar({this.action, super.key});

  /// Shown at the bar's end, and only while the bar shows: the Customer's
  /// home puts the way back to the staff area here (`DL-75`).
  final Widget? action;
```

and in the `Row` after the `Expanded(child: Text(...))`: `if (action case final Widget action) Flexible(child: action),`.

`catalog_screens.dart` (`CatalogHomeScreen.build`): delete the `switch-to-staff-button` and `logout-button` `IconButton`s from the app bar actions; replace `const ActiveModeBar()` in the body with `const ActiveModeBar(action: _SwitchToStaffButton())`; add:

```dart
/// The way back to the staff area for a Shopper or Courier in Customer
/// mode, in one step (`docs/02-user-roles.md` section 10).
class _SwitchToStaffButton extends ConsumerWidget {
  const _SwitchToStaffButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      key: const ValueKey<String>('switch-to-staff-button'),
      onPressed: () => ref
          .read(sessionControllerProvider.notifier)
          .switchMode(SessionMode.staff),
      child: Text(
        AppLocalizations.of(context).switchToStaff,
        textAlign: TextAlign.end,
      ),
    );
  }
}
```

Remove the now-unused `session` locals/imports from `build` if analyze flags them.

`profile_screen.dart`: `appBar: AppBar(title: Text(l10n.profileTitle), actions: const <Widget>[_LogoutButton()]),` and add:

```dart
/// The way out of the Customer session, in the app bar so it is there
/// whatever state the profile is in.
class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    if (state is! SignedIn) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey<String>('logout-button'),
      icon: const Icon(Icons.logout),
      tooltip: AppLocalizations.of(context).logoutButton,
      onPressed: () => ref
          .read(sessionControllerProvider.notifier)
          .logout(state.activeMode),
    );
  }
}
```

(import `../../../core/session/session_state.dart`). Update `CatalogHomeScreen`'s and `ProfileScreen`'s doc comments to say where logout and the staff switch now are.

- [ ] **Step 4: Run the tests to verify they pass**

Run the two files from Step 2, plus `flutter test test/features/shells test/features/auth` (other users of `logout-button`/`switch-to-staff-button`) — Expected: PASS. Analyze + format.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib frontend/test
git commit -m "feat(customer): logout on the profile, back to staff on the mode bar

Frees the home's top for the new header (DL-75)."
```

---

### Task 4: The floating bar — home, orders, profile

**Files:**
- Create: `frontend/lib/features/catalog/presentation/customer_home_nav.dart`
- Modify: `frontend/lib/features/catalog/presentation/catalog_screens.dart`, both ARB files, regenerate l10n
- Test: Create `frontend/test/features/catalog/customer_home_test.dart`

**Interfaces:**
- Produces: `class CustomerHomeNav extends StatelessWidget` (`const CustomerHomeNav({super.key})`); ARB keys `homeNavHome`, `homeNavOrders`.

- [ ] **Step 1: Add the strings**

`app_uz.arb`: `"homeNavHome": "Bosh sahifa"`, `"homeNavOrders": "Buyurtmalar"`. `app_ru.arb`: `"homeNavHome": "Главная"`, `"homeNavOrders": "Заказы"`. Then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Create `test/features/catalog/customer_home_test.dart` with the setup of `catalog_screens_test.dart` (tokens with a Customer `'c'`, `FakeAuthRepository`, `FakeCatalogRepository` with several categories — enough that the list scrolls at 320×640 — and `appUnderTest`). Tests:

```dart
  testWidgets('the floating bar opens the orders and the profile over the home', (WidgetTester tester) async {
    await open(tester);
    expect(find.descendant(of: find.byType(CustomerHomeNav), matching: byKey('open-orders')), findsOneWidget);
    await tester.tap(byKey('open-orders'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeNav), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(byKey('open-profile'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeNav), findsNothing);
  });

  for (final Locale device in const <Locale>[Locale('uz'), Locale('ru')]) {
    testWidgets('large text on a small phone: the bar fits and the last section is reachable (${device.languageCode})', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, device: device);
      expect(tester.takeException(), isNull);
      final Finder last = byKey('category-${lastCategoryId}');
      await tester.scrollUntilVisible(last, 100);
      await tester.tap(last);   // fails if the bar covers it
      await tester.pumpAndSettle();
      expect(find.byType(CustomerHomeNav), findsNothing);
    });
  }
```

(`lastCategoryId` is the id of the last category in the fake catalog.) Also adjust any existing test that taps `open-orders`/`open-profile` only if it now fails for a reason other than location (the keys stay the same, so most should pass unchanged).

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/catalog/customer_home_test.dart` — Expected: compile error (`CustomerHomeNav` missing).

- [ ] **Step 4: Implement**

`customer_home_nav.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/theme/brand_colors.dart';

/// The home's floating bar (design 4a): the home itself, the Customer's
/// orders and their profile. Orders and the profile open over the home, so
/// the system back returns to it.
class CustomerHomeNav extends StatelessWidget {
  const CustomerHomeNav({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: const Color(0x29111827),
        shape: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: _CurrentTab(
                    icon: Icons.home_rounded,
                    label: l10n.homeNavHome,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Tab(
                    key: const ValueKey<String>('open-orders'),
                    icon: Icons.receipt_long_outlined,
                    label: l10n.homeNavOrders,
                    onTap: () => context.push(AppPaths.customerOrders),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Tab(
                    key: const ValueKey<String>('open-profile'),
                    icon: Icons.person_outline_rounded,
                    label: l10n.profileTitle,
                    onTap: () => context.push(AppPaths.customerProfile),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The screen the Customer is on: an orange pill.
class _CurrentTab extends StatelessWidget {
  const _CurrentTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const ShapeDecoration(
          color: BrandColors.orange,
          shape: StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Another screen: an icon over its name.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: BrandColors.muted),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BrandColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

In `CatalogHomeScreen.build`: delete the `open-orders` and `open-profile` `IconButton`s from the app bar; set `extendBody: true` and `bottomNavigationBar: const CustomerHomeNav()` on the `Scaffold`. The home's lists (`_Categories`' `ListView`, `ProductList`'s `ListView.builder`) set no explicit padding, so they already pad by `MediaQuery.padding.bottom`, which `extendBody` raises by the bar's height; if the test shows the last item covered, wrap the body's `Expanded` child so the bottom padding reaches the list (do not hard-code a height).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/catalog test/features/orders test/features/addresses` — Expected: PASS. Analyze + format.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib frontend/test
git commit -m "feat(catalog): the home's floating bar — home, orders, profile (design 4a)"
```

---

### Task 5: The green header — search, cart, delivery address

**Files:**
- Create: `frontend/lib/features/catalog/presentation/customer_home_header.dart`
- Create: `frontend/lib/features/addresses/presentation/delivery_address_widgets.dart`
- Modify: `frontend/lib/features/catalog/presentation/catalog_screens.dart`, `frontend/lib/features/cart/presentation/cart_widgets.dart` (`CartButton.onBrand`), both ARB files + `flutter gen-l10n`, `frontend/test/support/app_harness.dart` (a `preferences` parameter)
- Test: `frontend/test/features/catalog/customer_home_test.dart` (extend)

**Interfaces:**
- Consumes: `deliveryAddressProvider`, `deliveryAddressChoiceProvider`, `Address.streetLine` (Task 2); `ActiveModeBar(action:)`, `_SwitchToStaffButton` (Task 3); `CustomerHomeNav` (Task 4); `BrandColors` (Task 1).
- Produces: `class CustomerHomeHeader extends StatelessWidget` (`const CustomerHomeHeader({required Widget search, super.key})`); `class DeliveryAddressLine extends ConsumerWidget`; `Future<void> showDeliveryAddressSheet(BuildContext context)`; `const CartButton({bool onBrand = false, super.key})`; `appUnderTest(..., InMemoryPreferenceStore? preferences)`; ARB keys `deliveryAddressCaption`, `deliveryAddressAdd`, `deliveryAddressRetry`, `deliveryAddressSheetTitle`.

- [ ] **Step 1: Strings and the harness**

`app_uz.arb` / `app_ru.arb`:
- `deliveryAddressCaption`: `"Shu manzilga yetkazamiz"` / `"Доставим сюда"`
- `deliveryAddressAdd`: `"Yetkazish manzilini qo'shing"` / `"Добавить адрес доставки"`
- `deliveryAddressRetry`: `"Manzil yuklanmadi — qayta urinish"` / `"Адрес не загрузился — повторить"`
- `deliveryAddressSheetTitle`: `"Qayerga yetkazamiz?"` / `"Куда доставить?"`
- change `catalogSearchHint` to `"Qidirish: bodring, non…"` / `"Найти: огурцы, лепёшки…"`

Run `flutter gen-l10n`.

`test/support/app_harness.dart`: add `InMemoryPreferenceStore? preferences,` and use `preferenceStoreProvider.overrideWithValue(preferences ?? InMemoryPreferenceStore())`.

- [ ] **Step 2: Write the failing tests**

Extend `customer_home_test.dart` (pass `addresses:` and `preferences:` through `open`; for the add-address route override `mapPickerProvider` with a fake map exactly as `test/features/addresses/customer_account_screens_test.dart` does with its `_fakeMap` — copy that function):

```dart
  testWidgets('the header shows the search, the cart and the newest address', (WidgetTester tester) async {
    await open(tester);
    final Finder header = find.byType(CustomerHomeHeader);
    expect(find.descendant(of: header, matching: byKey('catalog-search')), findsOneWidget);
    expect(find.descendant(of: header, matching: byKey('open-cart')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Amir Temur, 12')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('the address line changes the delivery address, and it is remembered', (WidgetTester tester) async {
    addresses.rows = <Address>[address(id: 'a-1'), address(id: 'a-2', label: 'Ish', street: 'Bobur', house: '7')];
    await open(tester);
    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('delivery-address-a-2'));
    await tester.pumpAndSettle();
    expect(find.text('Bobur, 7'), findsOneWidget);
    expect(preferences.values[DeliveryAddressChoice.preferenceKey('c')], 'a-2');

    await tester.pumpWidget(const SizedBox());   // a later launch, same device
    await open(tester);
    expect(find.text('Bobur, 7'), findsOneWidget);
  });

  testWidgets('with no address the line adds one', (WidgetTester tester) async {
    addresses.rows = <Address>[];
    await open(tester);
    await tester.tap(find.text(l10n(tester).deliveryAddressAdd));
    await tester.pumpAndSettle();
    expect(find.byType(AddressFormScreen), findsOneWidget);
  });

  testWidgets('the sheet adds an address too', (WidgetTester tester) async {
    await open(tester);
    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('delivery-address-new'));
    await tester.pumpAndSettle();
    expect(find.byType(AddressFormScreen), findsOneWidget);
  });

  testWidgets('a list that failed to load offers a retry that reloads it', (WidgetTester tester) async {
    addresses.loadFailure = const UnexpectedFailure();
    await open(tester);
    expect(find.text(l10n(tester).deliveryAddressRetry), findsOneWidget);
    expect(find.text('Amir Temur, 12'), findsNothing);
    await tester.tap(byKey('delivery-address'));
    await tester.pumpAndSettle();
    expect(find.text('Amir Temur, 12'), findsOneWidget);
  });

  testWidgets('the cart button on the header counts the cart lines and opens the cart', (WidgetTester tester) async {
    // Seed FakeCartRepository with two lines as test/features/cart/presentation/cart_screens_test.dart does.
    await open(tester, cart: cartWithTwoLines);
    expect(find.descendant(of: byKey('open-cart'), matching: byKey('cart-count')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(byKey('open-cart'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerHomeHeader), findsNothing);
  });
```

Extend the large-text test of Task 4 so it also runs with two sessions (staff `'s'` Courier as in `catalog_screens_test.dart`) and checks the header's address, the mode bar and its `switch-to-staff-button` render without exception, and that typing in `catalog-search` still shows results (`typeAndPause` as in `catalog_screens_test.dart`).

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/catalog/customer_home_test.dart` — Expected: compile errors / FAIL.

- [ ] **Step 4: Implement**

`cart_widgets.dart` — `CartButton` gains the header's look:

```dart
class CartButton extends ConsumerWidget {
  const CartButton({this.onBrand = false, super.key});

  /// The home header's round white button on the brand green (design 4a);
  /// otherwise the plain app bar icon of the other screens.
  final bool onBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<Cart> cart = ref.watch(currentCartProvider);
    // The last count known for this account, a failed reload included.
    final int count = cart.value?.itemCount ?? 0;

    return IconButton(
      key: const ValueKey<String>('open-cart'),
      tooltip: l10n.cartBadge(count),
      style: onBrand
          ? IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: BrandColors.green,
              minimumSize: const Size.square(46),
            )
          : null,
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: onBrand ? BrandColors.orange : null,
        textColor: onBrand ? Colors.white : null,
        label: ExcludeSemantics(
          child: Text('$count', key: const ValueKey<String>('cart-count')),
        ),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      onPressed: () => context.push(CartPaths.cart),
    );
  }
}
```

`delivery_address_widgets.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/customer_account.dart';
import '../../../core/theme/brand_colors.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/addresses.dart';

/// Where the order goes, under the home's search (design 4a). Tapping it
/// changes the address, adds the first one, or reloads a list that failed.
class DeliveryAddressLine extends ConsumerWidget {
  const DeliveryAddressLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (String value, VoidCallback? onTap) = switch (ref.watch(
      deliveryAddressProvider,
    )) {
      AsyncData<Address?>(value: final Address address) => (
        address.streetLine,
        () => showDeliveryAddressSheet(context),
      ),
      AsyncData<Address?>() => (
        l10n.deliveryAddressAdd,
        () => context.push(AppPaths.customerNewAddress),
      ),
      AsyncError<Address?>() => (
        l10n.deliveryAddressRetry,
        () => ref.invalidate(addressesProvider),
      ),
      _ => ('…', null),
    };

    return InkWell(
      key: const ValueKey<String>('delivery-address'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.deliveryAddressCaption,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      value,
                      key: const ValueKey<String>('delivery-address-value'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BrandColors.lime,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.near_me_rounded,
                    size: 17,
                    color: BrandColors.lime,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Customer's active addresses to deliver to, and the way to add one.
Future<void> showDeliveryAddressSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheet) => _DeliveryAddressSheet(
        router: GoRouter.of(context),
      ),
    );

class _DeliveryAddressSheet extends ConsumerWidget {
  const _DeliveryAddressSheet({required this.router});

  /// The home's router: the sheet's own context is gone once it closes.
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? account = ref.watch(customerAccountProvider);
    final AsyncValue<Address?> current = ref.watch(deliveryAddressProvider);
    final List<Address> addresses = current.hasValue
        ? ref.watch(addressesProvider).requireValue
        : const <Address>[];

    return SafeArea(
      child: ListView(
        key: const ValueKey<String>('delivery-address-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.deliveryAddressSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<String>(
            groupValue: current.value?.id,
            onChanged: (String? id) {
              if (id == null || account == null) {
                return;
              }
              ref.read(deliveryAddressChoiceProvider(account).notifier).choose(id);
              Navigator.of(context).pop();
            },
            child: Column(
              children: <Widget>[
                for (final Address address in addresses)
                  RadioListTile<String>(
                    key: ValueKey<String>('delivery-address-${address.id}'),
                    value: address.id,
                    title: Text(address.label ?? address.streetLine),
                    subtitle: address.label == null
                        ? null
                        : Text(address.streetLine),
                  ),
              ],
            ),
          ),
          ListTile(
            key: const ValueKey<String>('delivery-address-new'),
            leading: const Icon(Icons.add_location_alt_outlined),
            title: Text(l10n.addressNew),
            onTap: () {
              Navigator.of(context).pop();
              router.push(AppPaths.customerNewAddress);
            },
          ),
        ],
      ),
    );
  }
}
```

`customer_home_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../addresses/presentation/delivery_address_widgets.dart';
import '../../cart/presentation/cart_widgets.dart';

/// The top of the Customer's home (design 4a): the brand green under the
/// status bar with a curved bottom, the [search] beside the cart, and where
/// the order goes. The active mode shows at its top while two sessions
/// exist (`docs/02-user-roles.md` section 10).
class CustomerHomeHeader extends StatelessWidget {
  const CustomerHomeHeader({
    required this.search,
    this.modeAction,
    super.key,
  });

  final Widget search;

  /// The active-mode bar's action (the way back to the staff area).
  final Widget? modeAction;

  /// How deep the bottom curve dips at its middle.
  static const double curveDepth = 46;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          DecoratedBox(
            decoration: BoxDecoration(
              color: BrandColors.green,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.elliptical(constraints.maxWidth / 2, curveDepth),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ActiveModeBar(action: modeAction),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: search),
                          const SizedBox(width: 10),
                          const CartButton(onBrand: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const DeliveryAddressLine(),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
```

Note: `modeAction` takes the `_SwitchToStaffButton` of Task 3; `_SwitchToStaffButton` stays private in `catalog_screens.dart`, and the home passes `modeAction: const _SwitchToStaffButton()`. Remove the body's own `ActiveModeBar` (the header carries it now).

`catalog_screens.dart` — `CatalogHomeScreen.build` becomes (search logic unchanged):

```dart
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the green header.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBody: true,
        bottomNavigationBar: const CustomerHomeNav(),
        body: Column(
          children: <Widget>[
            CustomerHomeHeader(
              modeAction: const _SwitchToStaffButton(),
              search: TextField(
                key: const ValueKey<String>('catalog-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    ProductListQuery.searchMaxLength,
                  ),
                ],
                style: const TextStyle(color: BrandColors.ink, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: l10n.catalogSearchHint,
                  hintStyle: const TextStyle(color: BrandColors.muted, fontSize: 14.5),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: BrandColors.ink),
                  suffixIcon: _query.isEmpty && _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey<String>('catalog-search-clear'),
                          icon: const Icon(Icons.clear, color: BrandColors.muted),
                          tooltip: l10n.catalogSearchClear,
                          onPressed: _clear,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(23),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onTyped,
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: _query.isEmpty
                    ? const _Categories()
                    : ProductList(query: ProductListQuery(search: _query)),
              ),
            ),
          ],
        ),
      ),
    );
```

Drop the app bar entirely (the language is on the profile; `LanguageMenuButton` import goes if unused). Remove the now-unused `session` locals and imports. Rewrite the class doc comment: the home is the green header (search, cart, delivery address) over the sections, with the floating bar; the profile holds the language and logout; the mode bar holds the way back to staff (`DL-75`).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/catalog test/features/cart test/features/addresses test/features/orders test/features/shells` — Expected: PASS, no overflow exceptions. Analyze + format.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib frontend/test
git commit -m "feat(catalog): the home's green header — search, cart, delivery address (design 4a)"
```

---

### Task 6: Checkout starts from the delivery address

**Files:**
- Modify: `frontend/lib/features/checkout/presentation/checkout_screen.dart`
- Test: `frontend/test/features/checkout/presentation/checkout_screen_test.dart`

**Interfaces:**
- Consumes: `deliveryAddressProvider`, `deliveryAddressChoiceProvider`, `customerAccountProvider`.

- [ ] **Step 1: Write the failing tests**

In `checkout_screen_test.dart`, with two addresses (`a-1` newest, `a-2`) and the file's existing way to open checkout:

```dart
  testWidgets('checkout opens with the delivery address chosen on the home', (WidgetTester tester) async {
    // preferences holds DeliveryAddressChoice.preferenceKey('c') = 'a-2'
    await openCheckout(tester);
    final RadioGroup<String> group = tester.widget(find.byType(RadioGroup<String>));
    expect(group.groupValue, 'a-2');
  });

  testWidgets('another address picked at checkout becomes the delivery address', (WidgetTester tester) async {
    await openCheckout(tester);           // starts on a-1, the newest
    await tester.tap(byKey('checkout-address-a-2'));
    await tester.pumpAndSettle();
    expect(preferences.values[DeliveryAddressChoice.preferenceKey('c')], 'a-2');
  });

  testWidgets('a confirmation whose outcome is unknown keeps the address it was sent with', (WidgetTester tester) async {
    // Reuse the file's existing "unknown outcome" setup (a sent PreparedCheckout for a-1),
    // with preferences choosing a-2: the checkout must show a-1 selected.
  });

  testWidgets('a chosen address since removed is not preselected', (WidgetTester tester) async {
    // preferences choose 'a-gone', rows are a-1 and a-2: a-1 (the newest) is selected.
  });
```

Fill the last two with the file's existing helpers (find the test that leaves a confirmation unknown and copy its setup). Use the names the file already uses for opening checkout; pass `preferences:` to `appUnderTest`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/checkout/presentation/checkout_screen_test.dart` — Expected: the new tests FAIL.

- [ ] **Step 3: Implement**

In `_CheckoutScreenState._checkout`:

```dart
    // Until the Customer picks here, the home's delivery address (`DL-75`).
    final String? selectedId =
        _addressId ?? ref.watch(deliveryAddressProvider).value?.id;
    final Address? address = list
        .where((Address a) => a.id == selectedId)
        .firstOrNull;
```

and in `onSelected`:

```dart
            onSelected: (String id) {
              setState(() => _addressId = id);
              _changed();
              final String? account = ref.read(customerAccountProvider);
              if (account != null) {
                ref
                    .read(deliveryAddressChoiceProvider(account).notifier)
                    .choose(id);
              }
            },
```

`_addressId` keeps its role for a sent confirmation (`initState` sets it from `sent?.request.addressId`, which wins). Imports: `../../addresses/application/delivery_address.dart`, `../../../core/session/customer_account.dart`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/checkout` — Expected: PASS. Analyze + format.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/checkout frontend/test/features/checkout
git commit -m "feat(checkout): start from the home's delivery address; a pick here becomes it"
```

---

### Task 7: Record, documents and the full run

**Files:**
- Modify: `docs/DECISIONS.md` (append `DL-74`, `DL-75`), `docs/03-features.md` (section 4), `docs/04-user-flows.md` (checkout step 1)
- Create: `tasks/REDESIGN_CUSTOMER.md`

- [ ] **Step 1: DECISIONS.md** — append at the end:

```markdown
## DL-74 — The Customer redesign, design 4a, and the delivery address on the home (2026-10-14, Owner)

1. **Redesign before Wave 4.** The Customer's screens are redesigned first, then the Shopper's, the Courier's and the panel take the same style. Business rules and the server stay as they are; a new feature a design suggests is put to the Owner one at a time.
2. **Design 4a.** The Owner chose design 4a of the Claude Design project "BarakaBozor — стиль покупателя" (`VariantJ.dc.html`): deep green `#0F3B2E`, lime `#B8E35A`, orange `#FF6A13`, the Manrope font, a green header with a curved bottom, round category pictures, a floating bottom bar. This supersedes the palette of interview topic 8.3; the text logo and "replaceable in one place" stand.
3. **The delivery address on the home.** Shown on a reference screenshot: the home's header names where the order goes, under the search; the Customer changes it there or adds the first address, and checkout starts from it.

## DL-75 — The Customer home's header, redesign part 1 (2026-10-14, agent)

1. **Brand values in one place.** `BrandColors` (`lib/core/theme/brand_colors.dart`) names the brand colours; the Material scheme is seeded from the brand green and the theme's font is Manrope. Manrope is bundled as one variable TTF from `google/fonts` (`ofl/manrope`, OFL 1.1, licence on the licences page) rather than fetched at runtime, so text is the same offline; no package is added.
2. **The header.** Green with an elliptical bottom curve 46 px deep; a white pill search (the home's search, unchanged in behaviour) beside a round white cart button with an orange count; the delivery address line under them. The status bar icons are light over it.
3. **The delivery address.** The id of the address the Customer chose is kept on the device per Customer account (`PreferenceStore`, key `delivery_address.<account>`); the shown address is that one while it is active, otherwise the newest active address, otherwise "add a delivery address". The list reloading counts as loading, so an account never sees another's address. The line opens a sheet to choose or add; a failed list offers a reload. Checkout preselects it; a pick at checkout becomes it; a confirmation whose outcome is unknown keeps the address it was sent with (`DL-50`). The server is unchanged: the order still takes the address checkout sends.
4. **The floating bar** (home, orders, profile) replaces the app bar's orders and profile buttons; orders and profile open over the home, so the system back returns to it.
5. **Where the rest of the app bar went** (supersedes `DL-30` (8) on this point): the language is on the profile (already there), logout moves to the profile's app bar, and the way back to the staff area becomes a button on the active-mode bar of the home, so it stays one step away (`docs/02` section 10).
```



- [ ] **Step 2: docs/03 and docs/04** — in `docs/03-features.md` section 4 add the sentence: "The Customer's home names the delivery address under its search; the choice is kept on the device per account, and checkout starts from it (`DL-74`, `DL-75`)." In `docs/04-user-flows.md`, checkout step 1, after "picks an own active address" add "(preselected: the delivery address chosen on the home, `DL-75`)".

- [ ] **Step 3: tasks/REDESIGN_CUSTOMER.md** — create:

```markdown
# Customer Redesign

Design 4a (`DL-74`), built part by part on the Customer's home first. Plan per part in `docs/superpowers/plans/`.

| Part | What | Status |
|---|---|---|
| 1 | Header: search, cart, delivery address; floating bar; theme and font (`DL-75`) | In Progress |
| 2 | Category circles on the header's arc | Planned |
| 3 | Product grid with the in-cart stepper | Planned |

## Risks

- None yet.

## Review findings not acted on

- None yet.
```

- [ ] **Step 4: Full verification**

From `frontend/`: `flutter gen-l10n` (no diff), `flutter analyze`, `dart format --set-exit-if-changed lib test`, `flutter test` (full suite). From the repo root: `git diff --check main...HEAD`. All must pass; report counts.

- [ ] **Step 5: Commit**

```bash
git add docs tasks
git commit -m "docs(redesign): record design 4a, the delivery address and part 1's decisions (DL-74, DL-75)"
```
