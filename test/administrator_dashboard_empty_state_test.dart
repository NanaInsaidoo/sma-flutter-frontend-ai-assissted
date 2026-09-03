import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/dashboard/data/dashboard_repository.dart';
import 'package:school_management_app/src/dashboard/domain/dashboard_models.dart';
import 'package:school_management_app/src/dashboard/presentation/administrator_dashboard.dart';
import 'package:school_management_app/src/leave/presentation/leave_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('renders honest empty states when dashboard lists are empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: _EmptyDashboardRepository(),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No admissions recorded for this term yet.'), findsOne);
    expect(find.text('No upcoming events have been added.'), findsOne);
    expect(find.text('No recent activity to display.'), findsOne);
    expect(find.text('Final Report Management'), findsOneWidget);
    expect(find.text('Evaluation Management'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('My Leave'), findsOneWidget);
    expect(find.text('Leave Management'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-leave-panel')), findsNothing);
    expect(find.text('Staff leave'), findsNothing);
    expect(find.text('Find student'), findsOneWidget);
    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Record expense'), findsOneWidget);
    expect(find.text('Requests & approvals'), findsOneWidget);
    expect(find.text('More actions'), findsOneWidget);
    expect(find.text('Bad state: No element'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows three attention items and opens the complete list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final alerts = List.generate(
      5,
      (index) => SchoolAlert(
        title: 'Alert ${index + 1}',
        message: 'Attention message ${index + 1}',
        context: 'Attendance',
        level: AlertLevel.warning,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: _EmptyDashboardRepository(alerts: alerts),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-attention-item-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-attention-item-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-attention-item-3')),
      findsNothing,
    );
    expect(find.text('Alert 4'), findsNothing);
    expect(find.text('+ 2 more'), findsOneWidget);

    await tester.ensureVisible(find.text('+ 2 more'));
    await tester.tap(find.text('+ 2 more'));
    await tester.pumpAndSettle();

    expect(find.text('All attention items'), findsOneWidget);
    expect(find.text('Alert 4'), findsOneWidget);
    expect(find.text('Alert 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('all-attention-item-4')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'teacher workspace remains available when administrator metrics are forbidden',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _ForbiddenDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test School',
            userDisplayName: 'Adwoa Teacher',
            role: 'CLASS_TEACHER',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Adwoa Teacher'), findsOneWidget);
      expect(find.text('My Leave'), findsOneWidget);
      expect(find.text('Leave Management'), findsNothing);
      expect(find.byKey(const ValueKey('dashboard-leave-panel')), findsNothing);
      expect(find.text('Staff leave'), findsNothing);
      expect(find.text('Open assessments'), findsOneWidget);
      expect(find.text('Open term review'), findsOneWidget);
      expect(find.text('Staff Management'), findsNothing);
      expect(find.text('Fees & Requirements'), findsNothing);
      expect(find.text('Final Report Management'), findsNothing);
      expect(find.text('Evaluation Management'), findsNothing);
      expect(find.text('Dashboard data is not available yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('teacher and bursar can switch between their workspaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: _EmptyDashboardRepository(),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Adwoa Dual Role',
          role: 'CLASS_TEACHER',
          roles: const ['CLASS_TEACHER', 'BURSAR'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Open assessments'), findsOneWidget);
    expect(find.text('Fees & Requirements'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bursar').last);
    await tester.pumpAndSettle();

    expect(find.text('Fees & Requirements'), findsOneWidget);
    expect(find.text('My Leave'), findsOneWidget);
    expect(find.text('Leave Management'), findsOneWidget);
    expect(find.text('Expenses & Petty Cash'), findsOneWidget);
    expect(find.text('Find student'), findsOneWidget);
    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Record expense'), findsOneWidget);
    expect(find.text('Requests & approvals'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
    expect(find.text('Open assessments'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked active role returns user to an available workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget app(List<String> roles) => MaterialApp(
      theme: AppTheme.light,
      home: AdministratorDashboard(
        key: const ValueKey('role-aware-dashboard'),
        repository: _EmptyDashboardRepository(),
        schoolId: 'SCH-001',
        schoolName: 'Test School',
        userDisplayName: 'Adwoa Dual Role',
        role: 'CLASS_TEACHER',
        roles: roles,
      ),
    );

    await tester.pumpWidget(app(const ['CLASS_TEACHER', 'BURSAR']));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bursar').last);
    await tester.pumpAndSettle();
    expect(find.text('Expenses & Petty Cash'), findsOneWidget);

    await tester.pumpWidget(app(const ['CLASS_TEACHER']));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Open assessments'), findsOneWidget);
    expect(find.text('Expenses & Petty Cash'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reviewer navigation opens distinct personal and management pages',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _EmptyDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test school',
            role: 'ADMINISTRATOR',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Leave'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LeaveManagementScreen>(find.byType(LeaveManagementScreen))
            .myLeave,
        isTrue,
      );
      await tester.tap(find.text('Leave Management'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LeaveManagementScreen>(find.byType(LeaveManagementScreen))
            .myLeave,
        isFalse,
      );
    },
  );

  for (final role in [
    'HEAD_TEACHER',
    'HEADMASTER',
    'ADMIN',
    'SUBJECT_TEACHER',
    'ASSISTANT_HEAD_TEACHER',
    'SECRETARY',
    'STAFF',
    'OWNER',
  ]) {
    testWidgets('$role has the correct personal and management leave menus', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _EmptyDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test school',
            role: role,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Leave'), findsOneWidget);
      expect(
        find.text('Leave Management'),
        [
              'HEAD_TEACHER',
              'HEADMASTER',
              'ADMIN',
              'ASSISTANT_HEAD_TEACHER',
              'SECRETARY',
              'OWNER',
            ].contains(role)
            ? findsOneWidget
            : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _ForbiddenDashboardRepository extends _EmptyDashboardRepository {
  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) {
    throw Exception('Forbidden');
  }
}

class _EmptyDashboardRepository implements DashboardRepository {
  _EmptyDashboardRepository({this.alerts = const []});

  final List<SchoolAlert> alerts;

  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    return DashboardSnapshot(
      schoolName: 'Test School',
      administratorName: 'Eric',
      term: 'Second Term',
      academicTermId: 1,
      academicYear: '2026-2027',
      termStartDate: '1 Jul 2026',
      termEndDate: '31 Jul 2026',
      lastUpdated: DateTime(2026, 7, 19, 9),
      metrics: const [
        DashboardMetric(
          label: 'Students enrolled',
          value: '0',
          caption: 'Current enrolled students',
          change: '0 active',
          icon: Icons.groups_rounded,
          color: AppColors.green,
        ),
      ],
      admissions: const [],
      alerts: alerts,
      events: const [],
      calendarEvents: const [],
      activities: const [],
      attendance: const AttendanceSummary(
        total: 0,
        present: 0,
        absent: 0,
        late: 0,
      ),
      fees: const FeeSummary(collected: 0, outstanding: 0, waivers: 0),
    );
  }

  @override
  Future<List<CalendarEventType>> getCalendarEventTypes() async => const [];

  @override
  Future<SchoolEvent> createCalendarEvent({
    required String schoolId,
    required CalendarEventPayload event,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolEvent> updateCalendarEvent({
    required String schoolId,
    required String eventId,
    required CalendarEventPayload event,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCalendarEvent({
    required String schoolId,
    required String eventId,
  }) {
    throw UnimplementedError();
  }
}
