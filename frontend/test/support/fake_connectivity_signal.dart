import 'dart:async';

import 'package:baraka_bozor/core/network/connectivity_signal.dart';

/// A [ConnectivitySignal] that stays silent until a test calls [regain].
class FakeConnectivitySignal implements ConnectivitySignal {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get regained => _controller.stream;

  /// The network came back.
  void regain() => _controller.add(null);
}
