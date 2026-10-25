import '../../../core/storage/token_store.dart';
import 'push_event.dart';

/// The platform that issued a push token, as `docs/09-api-contracts.md`
/// section 27 names it.
enum PushPlatform {
  android('android'),
  ios('ios'),
  web('web');

  const PushPlatform(this.code);

  final String code;
}

/// A push token the device holds.
final class PushToken {
  const PushToken({required this.platform, required this.value});

  final PushPlatform platform;
  final String value;
}

/// Where the device's push token comes from: Firebase Cloud Messaging from
/// Wave 4 (`DL-17` (9)); until then a source that has none.
abstract interface class PushTokenSource {
  /// The token, or `null` while the device has none to give.
  Future<PushToken?> current();

  /// The token each time the platform replaces it.
  Stream<PushToken> get changes;
}

/// The source until Wave 4 brings FCM: no token, so nothing is registered.
final class NoPushTokenSource implements PushTokenSource {
  const NoPushTokenSource();

  @override
  Future<PushToken?> current() async => null;

  @override
  Stream<PushToken> get changes => const Stream<PushToken>.empty();
}

/// What arrives from the push service besides the token: pushes while the
/// app is open, taps on the system's own notification, and the permission.
abstract interface class PushInbox {
  /// Whether this build receives pushes at all; a build without Firebase
  /// neither asks for the permission nor marks it asked.
  bool get receivesPushes;

  /// Pushes that arrive while the app is in the foreground, which the system
  /// does not show by itself.
  Stream<IncomingPush> get foreground;

  /// The system notification the person tapped while the app was running in
  /// the background.
  Stream<PushTarget> get opened;

  /// The notification whose tap started the app, if one did.
  Future<PushTarget?> launchTarget();

  /// Asks the person for the permission to show notifications.
  Future<void> requestPermission();
}

/// The inbox of a build without push: nothing arrives and nothing is asked.
final class NoPushInbox implements PushInbox {
  const NoPushInbox();

  @override
  bool get receivesPushes => false;

  @override
  Stream<IncomingPush> get foreground => const Stream<IncomingPush>.empty();

  @override
  Stream<PushTarget> get opened => const Stream<PushTarget>.empty();

  @override
  Future<PushTarget?> launchTarget() async => null;

  @override
  Future<void> requestPermission() async {}
}

/// The channel the banners belong to, named in the app's language.
final class BannerChannel {
  const BannerChannel({required this.name, required this.description});

  final String name;
  final String description;
}

/// The banner the app draws itself for a push that arrives in the
/// foreground, and the taps on it.
abstract interface class BannerDisplay {
  /// Creates the channel, or renames it when the language changed.
  Future<void> prepare(BannerChannel channel);

  Future<void> show(IncomingPush push);

  /// A tap on a banner [show] drew.
  Stream<PushTarget> get taps;

  /// The banner whose tap started the app, if one did.
  Future<PushTarget?> launchTarget();
}

/// The display of a build without push: nothing is drawn.
final class NoBannerDisplay implements BannerDisplay {
  const NoBannerDisplay();

  @override
  Future<void> prepare(BannerChannel channel) async {}

  @override
  Future<void> show(IncomingPush push) async {}

  @override
  Stream<PushTarget> get taps => const Stream<PushTarget>.empty();

  @override
  Future<PushTarget?> launchTarget() async => null;
}

/// Registering and revoking a device (`docs/09` section 27), each on the
/// session it belongs to. Every method throws an `ApiFailure`.
abstract interface class PushDevicesRepository {
  /// The registered device's id.
  Future<String> register(SessionSlot slot, PushToken token);

  Future<void> revoke(SessionSlot slot, String deviceId);
}
