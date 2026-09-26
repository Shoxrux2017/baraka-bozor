import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/providers.dart';
import 'core/localization/app_language.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: BarakaBozorApp()));
}

class BarakaBozorApp extends ConsumerWidget {
  const BarakaBozorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);
    final AppLanguage? language = ref.watch(languageControllerProvider).value;

    return MaterialApp.router(
      // A brand name, not prose: it is the same in both client languages, so
      // it is not the localized text docs/07-architecture.md section 27 governs.
      title: 'BarakaBozor',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      routerConfig: router,
      // Until the stored preference is read the device language applies,
      // which is the same value for anyone who never chose one.
      locale: language?.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeResolutionCallback: (Locale? device, Iterable<Locale> supported) =>
          AppLanguage.forDevice(device ?? const Locale('uz')).locale,
      debugShowCheckedModeBanner: false,
    );
  }
}
