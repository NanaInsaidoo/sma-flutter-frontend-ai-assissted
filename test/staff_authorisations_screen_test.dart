import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff_authorisations/data/staff_authorisation_api_client.dart';
import 'package:school_management_app/src/staff_authorisations/presentation/staff_authorisations_screen.dart';

void main() {
  testWidgets('shows safe configurable staff access workspace', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FakeAuthorisationApi();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffAuthorisationsScreen(
            customSchoolId: 'SCH-1',
            apiClient: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff roles & authorisations'), findsOneWidget);
    expect(find.text('Headmistress'), findsOneWidget);
    expect(
      find.textContaining('Same authority as School Leader'),
      findsOneWidget,
    );
    expect(find.textContaining('no self-grants'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-job-title')));
    await tester.pumpAndSettle();
    expect(find.text('Add job title'), findsWidgets);
    expect(find.text('Same authority as *'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Authority roles'));
    await tester.pumpAndSettle();
    expect(find.text('School Leader'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);

    await tester.tap(find.text('Individual access'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-access-selector')), findsOneWidget);
    expect(find.textContaining('without changing anyone else'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staff-access-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Ama Mensah · Bursar'), findsOneWidget);

    await tester.tap(find.text('Ama Mensah · Bursar'));
    await tester.pumpAndSettle();
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
  });

  testWidgets('scrolls page guidance away while keeping the tabs available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffAuthorisationsScreen(
            customSchoolId: 'SCH-1',
            apiClient: _FakeAuthorisationApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff roles & authorisations').hitTestable(), findsOne);
    await tester.fling(
      find.byType(NestedScrollView),
      const Offset(0, -320),
      1200,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Staff roles & authorisations').hitTestable(),
      findsNothing,
    );
    expect(find.text('Job titles').hitTestable(), findsOneWidget);
  });
}

class _FakeAuthorisationApi extends StaffAuthorisationApiClient {
  _FakeAuthorisationApi()
    : super(
        accessToken: 'token',
        client: MockClient((_) async => throw UnimplementedError()),
      );

  final leader = const AuthorityTemplateRecord(
    id: '1',
    key: 'SCHOOL_LEADER',
    name: 'School Leader',
    description: 'Academic and operational leadership.',
    baseRole: 'HEAD_TEACHER',
    builtIn: true,
    active: true,
    assignedUsers: 2,
    permissionRules: [],
  );

  final finance = const AuthorityTemplateRecord(
    id: '2',
    key: 'FINANCE',
    name: 'Finance',
    description: 'Finance preparation authority.',
    baseRole: 'BURSAR',
    builtIn: true,
    active: true,
    assignedUsers: 1,
    permissionRules: [],
  );

  @override
  Future<AuthorisationCatalog> getCatalog(String schoolId) async =>
      const AuthorisationCatalog(
        modules: ['FINANCE', 'USER_MANAGEMENT'],
        actions: ['VIEW', 'EDIT', 'MANAGE_ACCESS'],
        scopeTypes: ['SCHOOL', 'CLASS'],
        resources: ['*', 'PETTY_CASH_TOP_UP'],
      );

  @override
  Future<List<AuthorityTemplateRecord>> getAuthorities(String schoolId) async =>
      [leader, finance];

  @override
  Future<List<JobTitleRecord>> getJobTitles(
    String schoolId, {
    bool includeInactive = true,
  }) async => [
    JobTitleRecord(
      id: '8',
      name: 'Headmistress',
      description: '',
      systemDefault: true,
      active: true,
      version: 0,
      authority: leader,
    ),
  ];

  @override
  Future<List<StaffAccessUser>> getStaffUsers(String schoolId) async => const [
    StaffAccessUser(
      id: '14',
      name: 'Ama Mensah',
      userType: 'STAFF',
      role: 'BURSAR',
      accountStatus: 'ACTIVE',
    ),
  ];

  @override
  Future<List<PermissionExceptionRecord>> getPendingExceptions(
    String schoolId,
  ) async => const [];

  @override
  Future<List<AuthorityAssignmentRecord>> getPendingAssignments(
    String schoolId,
  ) async => const [];

  @override
  Future<EffectiveAccessRecord> getEffectiveAccess({
    required String schoolId,
    required String userId,
  }) async => const EffectiveAccessRecord(
    userId: '14',
    displayName: 'Ama Mensah',
    roles: ['TEACHER', 'Teacher'],
    authorities: [],
    exceptions: [],
    decisions: [],
  );
}
