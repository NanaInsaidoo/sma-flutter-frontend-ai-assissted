import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/attendance/presentation/attendance_dashboard_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

import 'support/fake_attendance_repository.dart';

void main() {
  Future<void> pumpDashboard(WidgetTester tester) async {
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
            repository: FakeAttendanceRepository(),
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
}
