# BarakaBozor client

One Flutter codebase for every role of `docs/02-user-roles.md`: the Customer,
Shopper and Courier mobile app (Android now, iOS later) and the Operator,
Admin and Manager web panel. The design is in `docs/07-architecture.md`
section 27 onward; the engineering rules in `AGENTS.md` next to this file.

## Layout

```text
lib/
  app/        root providers and the route registry
  core/       network, storage, session, routing guard, localization, theme
  features/   one directory per feature: auth, shells, then the product features
test/         mirrors lib/; test/support holds the fakes and the app harness
```

Every feature contributes its routes through one fragment
(`lib/features/<feature>/presentation/<feature>_routes.dart`) that
`lib/app/router.dart` lists; `test/app/route_registry_test.dart` fails when a
fragment exists but is not listed.

## Commands

Run from this directory, with the Flutter version `.github/workflows/frontend.yml`
pins.

```text
flutter pub get
flutter gen-l10n                                 # after editing lib/core/localization/l10n/*.arb
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release                      # the panel
flutter build apk --debug                        # the mobile app
```

The API base URL is a build-time value:
`--dart-define=BB_API_BASE_URL=https://.../api/v1` (default
`http://localhost:8000/api/v1`, see `lib/core/config/api_config.dart`).

The Google Maps key is a build-time value too, never committed. Keep it in
`frontend/.env.maps` (gitignored), one line `GOOGLE_MAPS_API_KEY=<key>`, and
add `--dart-define-from-file=.env.maps` to the Android build:

```text
flutter build apk --dart-define=BB_API_BASE_URL=https://.../api/v1 --dart-define-from-file=.env.maps
```

A build without the key, the web and iOS have no map and take the address
point as coordinates (`DL-86` (2)).

Push needs the Firebase values, build-time too and never committed. Keep them
in `frontend/.env.firebase` (gitignored), one `KEY=value` per line:
`FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
`FIREBASE_ANDROID_APP_ID` and `FIREBASE_ANDROID_API_KEY` for Android today, and
`FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_API_KEY` and `FIREBASE_IOS_BUNDLE_ID` once
an iOS app is registered. The values come from the Firebase console's Android
app (or its `google-services.json`). Add one more define to the Android build:

```text
flutter build apk --dart-define=BB_API_BASE_URL=https://.../api/v1 --dart-define-from-file=.env.maps --dart-define-from-file=.env.firebase
```

A build without them registers no device and receives no push; the web build
never does (`DL-115`).

## Strings

The client owns every user-facing string, in Uzbek (Latin) and Russian. They
live in `lib/core/localization/l10n/app_uz.arb` and `app_ru.arb`; the
generated classes under `lib/core/localization/generated/` are committed, and
CI fails when they are out of date. Error text is rendered from the API's
machine `code` through `core/localization/failure_text.dart`, never from the
API `message`.
