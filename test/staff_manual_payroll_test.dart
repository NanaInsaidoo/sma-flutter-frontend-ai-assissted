import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';
import 'package:school_management_app/src/staff/presentation/staff_screen.dart';

void main() {
  testWidgets('manual onboarding captures only the salary payment account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeStaffApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffScreen(
            openAddStaffOnLoad: true,
            customSchoolId: 'SCH-1',
            accessToken: 'token',
            apiClient: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('First name *'), 'Sena');
    await tester.enterText(_field('Last name *'), 'Owusu');
    await tester.enterText(_field('Phone *'), '+233241234567');
    await tester.tap(find.byKey(const Key('staff-job-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teacher').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Department *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teaching').last);
    await tester.pumpAndSettle();
    await tester.tap(_field('Expected start date *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('SALARY PAYMENT ACCOUNT'), findsOneWidget);
    expect(find.text('Basic pay (GH¢) *'), findsNothing);
    expect(find.text('SSNIT number'), findsNothing);
    await tester.tap(find.byKey(const Key('staff-payment-bank')));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Bank name *'), 'GCB Bank');
    await tester.enterText(_field('Account name *'), 'Sena Owusu');
    await tester.enterText(_field('Account number *'), '1234567890');
    await tester.enterText(_field('Confirm account number *'), '1234567890');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.savedPaymentAccount?['paymentMethod'], 'BANK');
    expect(api.savedPaymentAccount?['accountNumber'], '1234567890');
    expect(find.text('RESUME DOCUMENT'), findsOneWidget);
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

class _FakeStaffApi extends StaffApiClient {
  _FakeStaffApi()
    : super(
        accessToken: 'token',
        client: MockClient((_) async => throw UnimplementedError()),
      );

  Map<String, dynamic>? savedPaymentAccount;

  @override
  Future<List<StaffUserRecord>> getSchoolStaffUsers({
    required String customSchoolId,
    int page = 0,
    int size = 100,
  }) async => const [];

  @override
  Future<List<StaffProfileRecord>> getSchoolStaffProfiles(
    String customSchoolId,
  ) async => const [];

  @override
  Future<Map<String, List<String>>> getStaffAssignments(
    String customSchoolId,
  ) async => const {};

  @override
  Future<List<StaffLookupOption>> getDepartments(String customSchoolId) async =>
      const [StaffLookupOption(id: '1', name: 'Teaching')];

  @override
  Future<List<StaffJobTitleOption>> getJobTitles(String customSchoolId) async =>
      const [
        StaffJobTitleOption(
          id: '1',
          name: 'Teacher',
          authorityName: 'Teacher',
          baseRole: 'TEACHER',
        ),
      ];

  @override
  Future<StaffOnboardingResult> initiateOnboarding({
    required Map<String, dynamic> body,
  }) async => const StaffOnboardingResult(
    staffId: 'STAFF-1',
    invitationToken: 'invite-token',
    invitationStatus: 'PENDING',
    invitationMaskedPhone: '***4567',
  );

  @override
  Future<void> savePaymentAccount({
    required String customSchoolId,
    required String staffId,
    required Map<String, dynamic> body,
  }) async {
    savedPaymentAccount = body;
  }
}
