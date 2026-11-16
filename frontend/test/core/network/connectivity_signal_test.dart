import 'dart:async';

import 'package:baraka_bozor/core/network/connectivity_signal.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it speaks only when every result was none and one is not', () async {
    final StreamController<List<ConnectivityResult>> changes =
        StreamController<List<ConnectivityResult>>();
    int regained = 0;
    final StreamSubscription<void> sub = PluginConnectivitySignal(
      changes.stream,
    ).regained.listen((_) => regained++);

    changes.add(<ConnectivityResult>[ConnectivityResult.none]);
    await pumpEventQueue();
    expect(regained, 0, reason: 'the first report only says where we stand');

    changes.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(regained, 1);

    changes.add(<ConnectivityResult>[
      ConnectivityResult.wifi,
      ConnectivityResult.mobile,
    ]);
    await pumpEventQueue();
    expect(regained, 1, reason: 'still online');

    changes.add(<ConnectivityResult>[ConnectivityResult.none]);
    changes.add(<ConnectivityResult>[ConnectivityResult.mobile]);
    await pumpEventQueue();
    expect(regained, 2);

    await sub.cancel();
  });

  test('a first report of being online is not a return', () async {
    final StreamController<List<ConnectivityResult>> changes =
        StreamController<List<ConnectivityResult>>();
    int regained = 0;
    final StreamSubscription<void> sub = PluginConnectivitySignal(
      changes.stream,
    ).regained.listen((_) => regained++);

    changes.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(regained, 0);
    await sub.cancel();
  });
}
