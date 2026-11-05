import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Curve _rise = Cubic(0.2, 0.8, 0.2, 1);

/// The page of a route that rises over the screen it was opened from, as a
/// full-screen dialog (`DL-134`): 340 ms up on [_rise], 260 ms down on
/// [Curves.easeIn]; with [reduced] motion a 200 ms fade each way. Key, name,
/// arguments and restoration id are the ones [appPage] gives.
Page<void> risingPage(
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
    fullscreenDialog: true,
    transitionDuration: Duration(milliseconds: reduced ? 200 : 340),
    reverseTransitionDuration: Duration(milliseconds: reduced ? 200 : 260),
    child: child,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (BuildContext context, Widget? child) {
            final bool leaving = animation.status == AnimationStatus.reverse;
            if (reduced) {
              return Opacity(
                opacity: (leaving ? Curves.easeIn : Curves.easeOut).transform(
                  animation.value,
                ),
                child: child,
              );
            }
            final double t = (leaving ? Curves.easeIn : _rise).transform(
              animation.value,
            );
            return FractionalTranslation(
              translation: Offset(0, 1 - t),
              child: child,
            );
          },
        ),
  );
}
