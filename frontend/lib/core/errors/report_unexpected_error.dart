import 'package:flutter/foundation.dart';

/// Hands an error the application could not explain to Flutter's error
/// handler, where the console shows it in development and crash reporting
/// will receive it later. The caller has already put the interface back in
/// a usable state; this makes sure the error is not lost on the way.
void reportUnexpectedError(Object error, StackTrace stackTrace, String what) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'baraka_bozor',
      context: ErrorDescription(what),
    ),
  );
}
