import 'package:connectivity_plus/connectivity_plus.dart';

/// Tells the retry screen the phone's network came back (`DL-136` (15)). It
/// says nothing about the server: the screen still asks it.
abstract interface class ConnectivitySignal {
  /// An event each time a report shows some network and the one before did
  /// not: none at all, or no report yet.
  Stream<void> get regained;
}

/// [ConnectivitySignal] over the platform's connectivity changes: an event
/// when a report holds a result other than [ConnectivityResult.none] and the
/// previous report did not. With no report yet the phone counts as not online:
/// the plugin may say nothing on subscribe while offline, so the first report
/// may be the return itself. At worst one extra quiet check runs.
class PluginConnectivitySignal implements ConnectivitySignal {
  PluginConnectivitySignal(this._changes);

  /// The signal over the real plugin.
  factory PluginConnectivitySignal.platform() =>
      PluginConnectivitySignal(Connectivity().onConnectivityChanged);

  final Stream<List<ConnectivityResult>> _changes;

  @override
  Stream<void> get regained {
    bool wasOnline = false;
    return _changes
        .where((List<ConnectivityResult> results) {
          final bool offline = results.every(
            (ConnectivityResult r) => r == ConnectivityResult.none,
          );
          final bool back = !offline && !wasOnline;
          wasOnline = !offline;
          return back;
        })
        .map((List<ConnectivityResult> _) {});
  }
}
