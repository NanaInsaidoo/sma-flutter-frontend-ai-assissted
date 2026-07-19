import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/dashboard/data/dashboard_repository.dart';
import 'package:school_management_app/src/dashboard/domain/dashboard_models.dart';
import 'package:school_management_app/src/dashboard/presentation/administrator_dashboard.dart';
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
    expect(find.text('Bad state: No element'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    return DashboardSnapshot(
      schoolName: 'Test School',
      administratorName: 'Eric',
      term: 'Second Term',
      academicYear: '2026-2027',
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
      alerts: const [],
      events: const [],
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
}
