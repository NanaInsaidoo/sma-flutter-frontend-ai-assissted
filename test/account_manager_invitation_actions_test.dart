import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';
import 'package:school_management_app/src/platform/presentation/school_detail_screen.dart';

import 'support/fake_platform_repository.dart';

void main() {
  AccountManagerProfile manager(AccountManagerStatus status) {
    return AccountManagerProfile(
      id: '21',
      userId: '31',
      name: 'Ama Mensah',
      email: 'ama@example.com',
      phone: '+233241234567',
      region: 'Greater Accra',
      schoolCount: 0,
      activeSchoolCount: 0,
      status: status,
      lastActive: status == AccountManagerStatus.invited
          ? 'Not yet active'
          : '2026-08-22',
      joined: '2026-08-22',
      inviteMethod: 'Email',
      verified: true,
      bio: '',
      invitationDeliveryStatus: 'SENT',
      invitationLastSentAt: '2026-08-22T13:30:00',
      invitationSendCount: 1,
    );
  }

  Future<void> showManager(
    WidgetTester tester,
    AccountManagerStatus status,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountManagerDetailScreen(
            manager: manager(status),
            schools: const [],
            repository: FakePlatformRepository(),
            onBack: () {},
            onManagerUpdated: (_) {},
            onManagerDeleted: () {},
            onViewSchool: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invited manager only receives invitation actions', (
    tester,
  ) async {
    await showManager(tester, AccountManagerStatus.invited);

    expect(find.text('Resend invitation'), findsOneWidget);
    expect(find.text('Cancel invitation'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Sent · 1 attempt'), findsOneWidget);
    expect(find.text('Require password change'), findsNothing);
  });

  testWidgets(
    'activated manager receives required password change, not resend',
    (tester) async {
      await showManager(tester, AccountManagerStatus.active);

      expect(find.text('Require password change'), findsOneWidget);
      expect(find.text('Resend invitation'), findsNothing);
      expect(find.text('Cancel invitation'), findsNothing);
    },
  );
}
