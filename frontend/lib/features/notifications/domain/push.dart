import '../../../core/storage/token_store.dart';

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
}

/// The source until Wave 4 brings FCM: no token, so nothing is registered.
final class NoPushTokenSource implements PushTokenSource {
  const NoPushTokenSource();

  @override
  Future<PushToken?> current() async => null;
}

/// Registering and revoking a device (`docs/09` section 27), each on the
/// session it belongs to. Every method throws an `ApiFailure`.
abstract interface class PushDevicesRepository {
  /// The registered device's id.
  Future<String> register(SessionSlot slot, PushToken token);

  Future<void> revoke(SessionSlot slot, String deviceId);
}
