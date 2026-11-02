import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The page every route of the app is built on (`DL-124`). A page the person
/// opens comes in by the platform's transition from the theme: Cupertino's
/// slide with the back-swipe on iOS, the predictive-back transition on
/// Android. An [entry] page (the bootstrap, a sign-in screen, an area's home,
/// a tab, a page of the web panel) replaces what was shown in place, as a tab
/// switch does (`DL-118`).
Page<void> appPage(GoRouterState state, Widget child, {bool entry = false}) {
  final ValueKey<String> key = state.pageKey;
  final String? name = state.name ?? state.path;
  final Object arguments = <String, String>{
    ...state.pathParameters,
    ...state.uri.queryParameters,
  };
  if (entry) {
    return NoTransitionPage<void>(
      key: key,
      name: name,
      arguments: arguments,
      restorationId: key.value,
      child: child,
    );
  }
  return MaterialPage<void>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: key.value,
    child: child,
  );
}
