import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The page of a route that fades in over the screen it was opened from
/// (`DL-140`): 320 ms on [Curves.easeOut], 200 ms out; with [reduced] motion
/// 200 ms both ways. Key, name, arguments and restoration id are the ones
/// [appPage] gives.
Page<void> fadingPage(
  GoRouterState state,
  Widget child, {
  required bool reduced,
}) {
  final ValueKey<String> key = state.pageKey;
  return CustomTransitionPage<void>(
    key: key,
    name: state.name ?? state.path,
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: key.value,
    transitionDuration: Duration(milliseconds: reduced ? 200 : 320),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    child: child,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}
