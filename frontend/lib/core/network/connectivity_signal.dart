import 'package:connectivity_plus/connectivity_plus.dart';

/// Tells the retry screen the phone's network came back (`DL-136` (15)). It
/// says nothing about the server: the screen still asks it.
abstract interface class ConnectivitySignal {
  /// An event each time the phone goes from no network at all to some.
  Stream<void> get regained;
}

/// [ConnectivitySignal] over the platform's connectivity changes: an event
/// when every result was [ConnectivityResult.none] and one is not any more,
/// never for the first report, which only says where the phone stands.
class PluginConnectivitySignal implements ConnectivitySignal {
  PluginConnectivitySignal(this._changes);

  /// The signal over the real plugin.
  factory PluginConnectivitySignal.platform() =>
      PluginConnectivitySignal(Connectivity().onConnectivityChanged);

  final Stream<List<ConnectivityResult>> _changes;

  @override
  Stream<void> get regained {
    bool? wasOffline;
    return _changes
        .where((List<ConnectivityResult> results) {
          final bool offline = results.every(
            (ConnectivityResult r) => r == ConnectivityResult.none,
          );
          final bool back = wasOffline == true && !offline;
          wasOffline = offline;
          return back;
        })
        .map((List<ConnectivityResult> _) {});
  }
}
