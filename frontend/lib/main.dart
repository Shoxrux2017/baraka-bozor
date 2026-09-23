import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/providers.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: BarakaBozorApp()));
}

class BarakaBozorApp extends ConsumerWidget {
  const BarakaBozorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      // A brand name, not prose: it is the same in both client languages, so
      // it is not the localized text docs/07-architecture.md section 27 governs.
      title: 'BarakaBozor',
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
