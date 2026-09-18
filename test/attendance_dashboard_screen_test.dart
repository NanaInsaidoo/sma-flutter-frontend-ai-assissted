import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/attendance/domain/attendance_models.dart';
import 'package:school_management_app/src/attendance/presentation/attendance_dashboard_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

import 'support/fake_attendance_repository.dart';

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    AttendanceRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(1440, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceDashboardScreen(
            customSchoolId: 'SCH-001',
            academicYear: '2025/2026',
            term: 'Term 2',
            repository: repository ?? FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens a class register from the dashboard and returns', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('School Attendance'), findsOneWidget);
    expect(
      find.text('22 classes have not submitted attendance today'),
      findsOneWidget,
    );
    expect(find.text('Overall attendance'), findsOneWidget);
    expect(find.text('Attendance by grade and stream'), findsOneWidget);

    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(find.text('Daily average this week'), findsNWidgets(2));

    final classRow = find.byKey(const ValueKey('attendance-class-11'));
    await tester.tap(classRow);
    await tester.pumpAndSettle();

    expect(find.text('KG 1 · Stream A'), findsOneWidget);
    expect(find.textContaining('15 students'), findsOneWidget);
    expect(find.text('Akua Bonsu'), findsWidgets);

    await tester.tap(find.byTooltip('Back to attendance dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('School Attendance'), findsOneWidget);
  });

  testWidgets('mark attendance chooser opens the selected class', (
    tester,
  ) async {
    await pumpDashboard(tester);

    await tester.tap(find.byKey(const ValueKey('mark-attendance')));
    await tester.pumpAndSettle();
    expect(find.text('Take attendance'), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lower Primary').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Basic 1 · Stream B').last);
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Basic 1 · Stream B'), findsOneWidget);
    expect(find.textContaining('15 students'), findsOneWidget);
  });

  testWidgets('pending class names stay behind a concise disclosure', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(
      find.byKey(const ValueKey('view-pending-attendance-classes')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pending-attendance-11')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('view-pending-attendance-classes')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending attendance (22)'), findsOneWidget);
    expect(find.byKey(const ValueKey('pending-attendance-11')), findsOneWidget);
    expect(find.text('Remind all'), findsOneWidget);
  });

  testWidgets('recent alerts removes submission duplicates and shows three', (
    tester,
  ) async {
    await pumpDashboard(tester, repository: _AlertsAttendanceRepository());

    final alertsCard = find.byKey(const ValueKey('attendance-alerts-card'));
    expect(
      find.descendant(of: alertsCard, matching: find.text('4 active')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: alertsCard,
        matching: find.text('Attendance not submitted'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: alertsCard, matching: find.text('Repeated absence')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: alertsCard, matching: find.text('Low attendance')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: alertsCard,
        matching: find.text('Late arrival pattern'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: alertsCard,
        matching: find.text('Attendance correction'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: alertsCard,
        matching: find.text('View all 4 alerts →'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('View all 4 alerts →'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance alerts (4)'), findsOneWidget);
    expect(find.text('Attendance correction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AlertsAttendanceRepository extends FakeAttendanceRepository {
  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    final overview = await super.getOverview(customSchoolId);
    return AttendanceDashboardOverview(
      currentDate: overview.currentDate,
      schoolDay: overview.schoolDay,
      today: overview.today,
      week: overview.week,
      month: overview.month,
      classes: overview.classes,
      streamsPending: overview.streamsPending,
      alerts: [
        AttendanceAlert(
          title: 'Attendance not submitted',
          message: 'Attendance has not been submitted today.',
          severity: 'medium',
          timestamp: DateTime(2026, 9, 16, 8),
          gradeId: 1,
          streamId: 11,
        ),
        AttendanceAlert(
          title: 'Repeated absence',
          message: 'A student has been absent for three school days.',
          severity: 'high',
          timestamp: DateTime(2026, 9, 16, 9),
          gradeId: 1,
          streamId: 11,
        ),
        AttendanceAlert(
          title: 'Low attendance',
          message: 'Class attendance is below the expected threshold.',
          severity: 'high',
          timestamp: DateTime(2026, 9, 16, 10),
        ),
        AttendanceAlert(
          title: 'Late arrival pattern',
          message: 'Several students have repeated late arrivals.',
          severity: 'medium',
          timestamp: DateTime(2026, 9, 16, 11),
        ),
        AttendanceAlert(
          title: 'Attendance correction',
          message: 'A submitted register was corrected.',
          severity: 'medium',
          timestamp: DateTime(2026, 9, 16, 12),
        ),
      ],
    );
  }
}
