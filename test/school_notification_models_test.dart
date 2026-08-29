import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/notifications/domain/school_notification_models.dart';

void main() {
  test('parses the backend notification inbox response', () {
    final inbox = SchoolNotificationInbox.fromJson({
      'unreadCount': 1,
      'notifications': [
        {
          'id': 2,
          'type': 'PAYMENT_OVERPAYMENT',
          'title': 'Overpayment recorded for Kojo Boateng',
          'message': 'GH₵ 1.00 was recorded as credit.',
          'sourceType': 'PAYMENT',
          'sourceId': 3,
          'createdAt': [2026, 8, 28, 17, 15, 19, 128345000],
          'read': false,
        },
      ],
    });

    expect(inbox.unreadCount, 1);
    expect(inbox.items, hasLength(1));
    expect(inbox.items.single.id, 2);
    expect(
      inbox.items.single.createdAt,
      DateTime(2026, 8, 28, 17, 15, 19, 128),
    );
    expect(inbox.items.single.read, isFalse);
  });

  test('keeps compatibility with an items payload', () {
    final inbox = SchoolNotificationInbox.fromJson({
      'unreadCount': 0,
      'items': [
        {'id': 7, 'createdAt': '2026-08-28T17:15:19', 'read': true},
      ],
    });

    expect(inbox.items.single.id, 7);
    expect(inbox.items.single.createdAt, DateTime(2026, 8, 28, 17, 15, 19));
  });
}
