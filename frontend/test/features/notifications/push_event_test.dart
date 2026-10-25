import 'package:baraka_bozor/core/routing/app_paths.dart';
import 'package:baraka_bozor/core/session/session_state.dart';
import 'package:baraka_bozor/features/auth/domain/app_user.dart';
import 'package:baraka_bozor/features/notifications/data/fcm_push_messaging.dart';
import 'package:baraka_bozor/features/notifications/domain/push_event.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

/// The thirteen events of `docs/05-business-rules.md` section 18 and the
/// target a push carries (`BR-NOTIF-002`: the event and the order, nothing
/// else).
void main() {
  const String orderId = '0192f0a0-0000-7000-8000-00000000c001';

  test('every event is for the recipient section 18 names', () {
    const Map<String, UserRole> expected = <String, UserRole>{
      'order_accepted': UserRole.customer,
      'approval_required': UserRole.customer,
      'payment_required': UserRole.customer,
      'shopping_completed': UserRole.customer,
      'courier_started': UserRole.customer,
      'order_delivered': UserRole.customer,
      'order_cancelled': UserRole.customer,
      'cancellation_rejected': UserRole.customer,
      'shopping_assigned': UserRole.shopper,
      'approval_answered': UserRole.shopper,
      'shopping_order_cancelled': UserRole.shopper,
      'delivery_assigned': UserRole.courier,
      'delivery_cancelled': UserRole.courier,
    };

    expect(PushEvent.values, hasLength(13));
    for (final MapEntry<String, UserRole> entry in expected.entries) {
      final PushEvent? event = PushEvent.tryParse(entry.key);
      expect(event, isNotNull, reason: entry.key);
      expect(event!.code, entry.key);
      expect(event.recipient, entry.value, reason: entry.key);
    }
  });

  test('an unknown event or a malformed order id is no target', () {
    expect(
      PushTarget.fromData(<String, dynamic>{
        'event': 'order_shipped',
        'order_id': orderId,
      }),
      isNull,
    );
    expect(
      PushTarget.fromData(<String, dynamic>{
        'event': 'order_accepted',
        'order_id': 'x',
      }),
      isNull,
    );
    expect(PushTarget.fromData(<String, dynamic>{'order_id': orderId}), isNull);
    expect(
      PushTarget.fromData(<String, dynamic>{'event': 'order_accepted'}),
      isNull,
    );
    expect(
      PushTarget.fromData(<String, dynamic>{
        'event': 'order_accepted',
        'order_id': 7,
      }),
      isNull,
    );
    expect(
      PushTarget.fromData(<String, dynamic>{'event': 42, 'order_id': orderId}),
      isNull,
    );
    expect(PushTarget.fromData(const <String, dynamic>{}), isNull);
  });

  test('a target survives its payload', () {
    final PushTarget target = PushTarget.fromData(<String, dynamic>{
      'event': 'delivery_assigned',
      'order_id': orderId,
    })!;

    final PushTarget? back = PushTarget.fromPayload(target.payload);

    expect(back, isNotNull);
    expect(back!.event, PushEvent.deliveryAssigned);
    expect(back.orderId, orderId);
    expect(PushTarget.fromPayload(null), isNull);
    expect(PushTarget.fromPayload(''), isNull);
    expect(PushTarget.fromPayload('not json'), isNull);
    expect(PushTarget.fromPayload('[1]'), isNull);
    expect(PushTarget.fromPayload('{"event":"order_accepted"}'), isNull);
  });

  test('each role has its order path, its list and its mode', () {
    const PushTarget customer = PushTarget(
      event: PushEvent.orderAccepted,
      orderId: orderId,
    );
    const PushTarget shopper = PushTarget(
      event: PushEvent.shoppingAssigned,
      orderId: orderId,
    );
    const PushTarget courier = PushTarget(
      event: PushEvent.deliveryCancelled,
      orderId: orderId,
    );

    expect(customer.role, UserRole.customer);
    expect(customer.mode, SessionMode.customer);
    expect(customer.path, AppPaths.customerOrder(orderId));
    expect(customer.listPath, AppPaths.customerOrders);
    expect(shopper.role, UserRole.shopper);
    expect(shopper.mode, SessionMode.staff);
    expect(shopper.path, AppPaths.shopperOrder(orderId));
    expect(shopper.listPath, AppPaths.shopper);
    expect(courier.role, UserRole.courier);
    expect(courier.mode, SessionMode.staff);
    expect(courier.path, AppPaths.courierOrder(orderId));
    expect(courier.listPath, AppPaths.courier);
  });

  group('a Firebase message as an incoming push', () {
    const Map<String, dynamic> data = <String, dynamic>{
      'event': 'order_accepted',
      'order_id': orderId,
    };

    test('takes the notification tag', () {
      final IncomingPush? push = FcmPushMessaging.incomingPushOf(
        const RemoteMessage(
          messageId: 'm-1',
          data: data,
          notification: RemoteNotification(
            title: 'Buyurtma qabul qilindi',
            body: 'Buyurtma 1001',
            android: AndroidNotification(tag: 'delivery-1'),
          ),
        ),
      );

      expect(push, isNotNull);
      expect(push!.title, 'Buyurtma qabul qilindi');
      expect(push.body, 'Buyurtma 1001');
      expect(push.tag, 'delivery-1');
      expect(push.target?.orderId, orderId);
      expect(push.target?.event, PushEvent.orderAccepted);
    });

    test('falls back to the message id without a tag', () {
      final IncomingPush? push = FcmPushMessaging.incomingPushOf(
        const RemoteMessage(
          messageId: 'm-1',
          data: data,
          notification: RemoteNotification(title: 'T', body: 'B'),
        ),
      );

      expect(push?.tag, 'm-1');
    });

    test('is nothing without a notification, a title or a body', () {
      expect(
        FcmPushMessaging.incomingPushOf(
          const RemoteMessage(messageId: 'm-1', data: data),
        ),
        isNull,
      );
      expect(
        FcmPushMessaging.incomingPushOf(
          const RemoteMessage(
            data: data,
            notification: RemoteNotification(title: '', body: 'B'),
          ),
        ),
        isNull,
      );
      expect(
        FcmPushMessaging.incomingPushOf(
          const RemoteMessage(
            data: data,
            notification: RemoteNotification(title: 'T'),
          ),
        ),
        isNull,
      );
    });
  });
}
