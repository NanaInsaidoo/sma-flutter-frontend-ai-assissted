import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';
import 'package:school_management_app/src/staff/presentation/staff_screen.dart';

void main() {
  testWidgets('onboarding shows invited staff and separates search emptiness', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffScreen(
            customSchoolId: 'SCH-1',
            accessToken: 'token',
            apiClient: _OnboardingQueueApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active Staff'), findsNothing);
    expect(find.text('Active Teacher'), findsOneWidget);
    expect(find.text('Invited Bursar'), findsNothing);
    expect(find.text('IN ONBOARDING'), findsOneWidget);
    expect(find.text('Draft, invited, or awaiting activation'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('staff-list-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('staff-onboarding-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Onboarding'));
    await tester.pumpAndSettle();

    expect(find.text('Invited Bursar'), findsOneWidget);
    expect(find.text('Active Teacher'), findsNothing);
    expect(find.text('Invited'), findsOneWidget);
    expect(find.text('No staff currently onboarding'), findsNothing);

    final search = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search staff onboarding',
    );
    await tester.enterText(search, 'missing person');
    await tester.pump();

    expect(find.text('No onboarding matches'), findsOneWidget);
    expect(
      find.textContaining('No onboarding records match "missing person"'),
      findsOneWidget,
    );
    expect(find.text('No staff currently onboarding'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _OnboardingQueueApi extends StaffApiClient {
  _OnboardingQueueApi()
    : super(
        accessToken: 'token',
        client: MockClient((_) async => throw UnimplementedError()),
      );

  @override
  Future<List<StaffUserRecord>> getSchoolStaffUsers({
    required String customSchoolId,
    int page = 0,
    int size = 100,
  }) async => const [
    StaffUserRecord(
      id: '1',
      userName: 'active.teacher',
      firstName: 'Active',
      middleName: '',
      lastName: 'Teacher',
      email: 'active@example.test',
      phoneNumber: '***0001',
      dateOfBirth: '1990-01-01',
      userType: 'STAFF',
      role: 'TEACHER',
      roles: ['TEACHER'],
      accountStatus: 'ACTIVE',
      mustChangePassword: false,
      lastLoginAt: '',
      createdAt: '2026-08-01',
      updatedAt: '2026-08-01',
    ),
  ];

  @override
  Future<List<StaffProfileRecord>> getSchoolStaffProfiles(
    String customSchoolId,
  ) async => const [
    StaffProfileRecord(
      staffId: 'STAFF-INVITED',
      userId: '',
      position: 'Bursar',
      departmentName: 'Finance',
      employmentType: 'PERMANENT',
      startDate: '2026-10-01',
      resumes: [],
      firstName: 'Invited',
      lastName: 'Bursar',
      email: 'invitee@example.test',
      invitationMaskedPhone: '***0002',
      invitationPrimaryRole: 'BURSAR',
      invitationRoles: ['BURSAR'],
      invitationToken: 'invite-token',
      invitationStatus: 'CODE_SENT',
      invitationDeliveryStatus: 'SENT',
      invitationSendCount: 1,
    ),
  ];

  @override
  Future<Map<String, List<String>>> getStaffAssignments(
    String customSchoolId,
  ) async => const {};

  @override
  Future<List<StaffActivityRecord>> getStaffActivity(String userId) async =>
      const [];
}
