import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/dashboard/data/dashboard_repository.dart';
import 'package:school_management_app/src/dashboard/domain/dashboard_models.dart';
import 'package:school_management_app/src/dashboard/presentation/administrator_dashboard.dart';
import 'package:school_management_app/src/readiness/data/school_readiness_repository.dart';
import 'package:school_management_app/src/readiness/domain/school_readiness.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('blocks dashboard and shows only incomplete setup work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dashboard = _TrackingDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: dashboard,
          readinessRepository: _FakeReadinessRepository(_incomplete),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finish setting up your school'), findsOneWidget);
    expect(find.text('Class structure'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Missing: Primary 1'), findsOneWidget);
    expect(dashboard.called, isFalse);
  });

  testWidgets('loads normal dashboard when existing setup is ready', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dashboard = _TrackingDashboardRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: dashboard,
          readinessRepository: _FakeReadinessRepository(
            SchoolReadiness.readySchool,
          ),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dashboard.called, isTrue);
    expect(find.text('Finish setting up your school'), findsNothing);
  });
}

const _incomplete = SchoolReadiness(
  ready: false,
  currentBlockingStep: 'TUITION_FEES',
  items: [
    SchoolReadinessItem(
      key: 'CLASS_STRUCTURE',
      label: 'Class structure',
      status: 'COMPLETED',
      required: true,
      detail: 'One active grade is configured.',
      missingGradeLevels: [],
    ),
    SchoolReadinessItem(
      key: 'TUITION_FEES',
      label: 'Tuition fees',
      status: 'INCOMPLETE',
      required: true,
      detail: 'Publish tuition fees.',
      missingGradeLevels: ['Primary 1'],
    ),
  ],
);

class _FakeReadinessRepository implements SchoolReadinessRepository {
  const _FakeReadinessRepository(this.value);
  final SchoolReadiness value;
  @override
  Future<SchoolReadiness> getReadiness(String customSchoolId) async => value;
}

class _TrackingDashboardRepository implements DashboardRepository {
  bool called = false;

  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    called = true;
    return DashboardSnapshot(
      schoolName: 'Test School',
      administratorName: 'Admin',
      term: 'First Term',
      academicTermId: 1,
      academicYear: '2026-2027',
      termStartDate: '1 Sep 2026',
      termEndDate: '18 Dec 2026',
      lastUpdated: DateTime(2026, 8, 2),
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
      alerts: const [],
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
  }) => throw UnimplementedError();

  @override
  Future<SchoolEvent> updateCalendarEvent({
    required String schoolId,
    required String eventId,
    required CalendarEventPayload event,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteCalendarEvent({
    required String schoolId,
    required String eventId,
  }) => throw UnimplementedError();
}
