import 'dart:convert';

import '../../../core/network/json_fields.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../auth/domain/app_user.dart';

/// The thirteen events a push can announce, each for the one role that
/// receives it (`docs/05-business-rules.md` section 18). The code is the
/// `event` member of the push's data (`BR-NOTIF-002`).
enum PushEvent {
  orderAccepted('order_accepted', UserRole.customer),
  approvalRequired('approval_required', UserRole.customer),
  paymentRequired('payment_required', UserRole.customer),
  shoppingCompleted('shopping_completed', UserRole.customer),
  courierStarted('courier_started', UserRole.customer),
  orderDelivered('order_delivered', UserRole.customer),
  orderCancelled('order_cancelled', UserRole.customer),
  cancellationRejected('cancellation_rejected', UserRole.customer),
  shoppingAssigned('shopping_assigned', UserRole.shopper),
  approvalAnswered('approval_answered', UserRole.shopper),
  shoppingOrderCancelled('shopping_order_cancelled', UserRole.shopper),
  deliveryAssigned('delivery_assigned', UserRole.courier),
  deliveryCancelled('delivery_cancelled', UserRole.courier);

  const PushEvent(this.code, this.recipient);

  final String code;
  final UserRole recipient;

  /// The event named by [code], or `null` for anything else, so an event a
  /// newer server adds opens nothing instead of failing.
  static PushEvent? tryParse(Object? code) {
    for (final PushEvent event in values) {
      if (event.code == code) {
        return event;
      }
    }
    return null;
  }
}

/// The order a push is about, as its data names it: the event and the order
/// id, nothing else (`BR-NOTIF-002`).
final class PushTarget {
  const PushTarget({required this.event, required this.orderId});

  final PushEvent event;
  final String orderId;

  /// The target in a push's data, or `null` when the event is unknown or the
  /// order id is not a UUID: a push the app cannot open is still shown.
  static PushTarget? fromData(Map<String, dynamic> data) {
    final PushEvent? event = PushEvent.tryParse(data['event']);
    if (event == null) {
      return null;
    }
    try {
      return PushTarget(
        event: event,
        orderId: JsonFields(data).uuid('order_id'),
      );
    } on FormatException {
      return null;
    }
  }

  /// The target in a banner's payload, which [payload] wrote.
  static PushTarget? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? fromData(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  /// What a local banner carries for its tap: the same two members.
  String get payload =>
      jsonEncode(<String, String>{'event': event.code, 'order_id': orderId});

  UserRole get role => event.recipient;

  /// A Customer push belongs to the Customer session, any other to the staff
  /// one (`DL-26`).
  SessionMode get mode =>
      role == UserRole.customer ? SessionMode.customer : SessionMode.staff;

  /// The order's screen in the recipient's area.
  String get path => switch (role) {
    UserRole.customer => AppPaths.customerOrder(orderId),
    UserRole.shopper => AppPaths.shopperOrder(orderId),
    _ => AppPaths.courierOrder(orderId),
  };

  /// The list the order's screen opens over, so Back returns to it.
  String get listPath => switch (role) {
    UserRole.customer => AppPaths.customerOrders,
    UserRole.shopper => AppPaths.shopper,
    _ => AppPaths.courier,
  };
}

/// A push that arrived while the app was in the foreground.
final class IncomingPush {
  const IncomingPush({
    required this.title,
    required this.body,
    this.tag,
    this.target,
  });

  final String title;
  final String body;

  /// What makes a second banner for the same push replace the first: the
  /// delivery id the server tags it with.
  final String? tag;
  final PushTarget? target;
}
