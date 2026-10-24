import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import 'app/providers.dart';
import 'core/localization/app_language.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/font_licenses.dart';
import 'features/notifications/application/push_registrar.dart';
import 'features/notifications/data/push_setup.dart';

Future<void> main() async {
  registerFontLicenses();
  final List<Override> pushOverrides = await startPush();
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: pushOverrides,
      child: const BarakaBozorApp(),
    ),
  );
}

/// Riverpod retries a failed provider on its own unless told otherwise. The
/// app does not: a load that failed shows its reason and a retry the person
/// presses, and a refusal — a missing record, a refused query — would only
/// fail again (`DL-28` (12)).
Duration? noAutomaticRetry(int retryCount, Object error) => null;

class BarakaBozorApp extends ConsumerWidget {
  const BarakaBozorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    // Registers the device for push while any account is signed in.
    ref.watch(pushRegistrarProvider);
    final AppLanguage? language = ref.watch(languageControllerProvider).value;

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      // The kit and `DL-77` draw the light screens only; the dark theme stays
      // in code until the kit's dark screens exist.
      themeMode: ThemeMode.light,
      routerConfig: router,
      // Until the stored preference is read the device language applies,
      // which is the same value for anyone who never chose one. A person who
      // chose the other language could see one frame in the device language;
      // today that frame is the bootstrap screen, which shows no text.
      locale: language?.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (Locale? device, Iterable<Locale> supported) =>
          AppLanguage.forDevice(device ?? const Locale('uz')).locale,
      debugShowCheckedModeBanner: false,
    );
  }
}
