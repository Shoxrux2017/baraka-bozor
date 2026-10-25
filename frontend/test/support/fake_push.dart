import 'dart:async';

import 'package:baraka_bozor/features/notifications/domain/push.dart';
import 'package:baraka_bozor/features/notifications/domain/push_event.dart';

/// A [PushInbox] a test drives: pushes arrive and open through the
/// controllers, and the permission requests are counted.
class FakePushInbox implements PushInbox {
  final StreamController<IncomingPush> foregroundPushes =
      StreamController<IncomingPush>.broadcast();
  final StreamController<PushTarget> openedPushes =
      StreamController<PushTarget>.broadcast();

  @override
  bool receivesPushes = true;

  /// What the push that launched the app names, if any.
  PushTarget? launch;

  int permissionRequests = 0;

  @override
  Stream<IncomingPush> get foreground => foregroundPushes.stream;

  @override
  Stream<PushTarget> get opened => openedPushes.stream;

  @override
  Future<PushTarget?> launchTarget() async => launch;

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }
}

/// A [BannerDisplay] that records what it was asked to show.
class FakeBannerDisplay implements BannerDisplay {
  final List<IncomingPush> shown = <IncomingPush>[];
  final List<BannerChannel> prepared = <BannerChannel>[];
  final StreamController<PushTarget> tapped =
      StreamController<PushTarget>.broadcast();

  /// What the banner that launched the app names, if any.
  PushTarget? launch;

  @override
  Future<void> prepare(BannerChannel channel) async {
    prepared.add(channel);
  }

  @override
  Future<void> show(IncomingPush push) async {
    shown.add(push);
  }

  @override
  Stream<PushTarget> get taps => tapped.stream;

  @override
  Future<PushTarget?> launchTarget() async => launch;
}
