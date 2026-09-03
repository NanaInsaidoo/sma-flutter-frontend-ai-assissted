import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/staff_attendance/domain/staff_attendance_models.dart';
import 'package:school_management_app/src/staff_attendance/presentation/staff_attendance_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('late opens a focused editable arrival time immediately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StaffAttendanceScreen(
            schoolId: 'SCH-1',
            repository: _FakeStaffAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('take-staff-attendance')));
    await tester.pumpAndSettle();

    final lateButton = find.widgetWithText(OutlinedButton, 'Late').first;
    await tester.ensureVisible(lateButton);
    await tester.pumpAndSettle();
    await tester.tap(lateButton);
    await tester.pumpAndSettle();

    final arrival = find.byKey(const ValueKey('late-arrival-time'));
    expect(arrival, findsOneWidget);
    expect(
      find.text('Enter the actual arrival time, for example 08:25.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(arrival).focusNode?.hasFocus ?? true,
      isTrue,
    );

    await tester.enterText(arrival, '8:25');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Arrival 08:25'), findsOneWidget);
  });

  testWidgets('records an excused absence and submits the complete register', (
    tester,
  ) async {
    final repository = _FakeStaffAttendanceRepository();
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StaffAttendanceScreen(
            schoolId: 'SCH-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff attendance'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('take-staff-attendance')));
    await tester.pumpAndSettle();
    expect(find.text('2 not marked'), findsOneWidget);
    await tester.tap(find.text('Mark all present'));
    await tester.pump();
    expect(find.text('0 not marked'), findsOneWidget);

    final absentButton = find.widgetWithText(OutlinedButton, 'Absent').first;
    await tester.ensureVisible(absentButton);
    await tester.pumpAndSettle();
    await tester.tap(absentButton);
    await tester.pumpAndSettle();
    expect(find.text('Absence details'), findsOneWidget);
    await tester.tap(find.text('Excused').last);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sick').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Excused · Sick'), findsOneWidget);
    expect(find.text('0 not marked'), findsOneWidget);

    final submit = find.byKey(const ValueKey('submit-staff-attendance'));
    await tester.ensureVisible(submit);
    final submitButton = tester.widget<FilledButton>(submit);
    expect(submitButton.onPressed, isNotNull);
    submitButton.onPressed!.call();
    await tester.pumpAndSettle();
    expect(repository.saveCount, 1);
    expect(repository.lastSubmitted, isTrue);
    expect(find.text('Staff attendance submitted.'), findsOneWidget);
  });

  testWidgets('compacts missing registers and opens the complete list', (
    tester,
  ) async {
    final days = List.generate(
      5,
      (index) => StaffAttendanceDayRecord(
        date: DateTime(2026, 8, 31 - index),
        expected: 10,
        present: 0,
        late: 0,
        excused: 0,
        unexcused: 0,
        status: 'MISSING',
      ),
    );
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StaffAttendanceScreen(
            schoolId: 'SCH-1',
            repository: _FakeStaffAttendanceRepository(dashboardDays: days),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-missing-register-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-missing-register-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-missing-register-3')),
      findsNothing,
    );
    expect(find.text('+ 2 more'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('more-missing-registers')));
    await tester.pumpAndSettle();

    expect(find.text('Unresolved attendance days'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('all-missing-register-4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('attendance register table sorts each useful column', (
    tester,
  ) async {
    final days = [
      StaffAttendanceDayRecord(
        date: DateTime(2026, 8, 31),
        expected: 9,
        present: 7,
        late: 1,
        excused: 1,
        unexcused: 0,
        status: 'SUBMITTED',
      ),
      StaffAttendanceDayRecord(
        date: DateTime(2026, 8, 30),
        expected: 2,
        present: 0,
        late: 0,
        excused: 0,
        unexcused: 2,
        status: 'MISSING',
      ),
      StaffAttendanceDayRecord(
        date: DateTime(2026, 8, 29),
        expected: 5,
        present: 4,
        late: 0,
        excused: 1,
        unexcused: 0,
        status: 'DRAFT',
      ),
    ];
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StaffAttendanceScreen(
            schoolId: 'SCH-1',
            repository: _FakeStaffAttendanceRepository(dashboardDays: days),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    DataTable table() => tester.widget<DataTable>(
      find.byKey(const ValueKey('staff-attendance-register-table')),
    );
    String firstExpected() => (table().rows.first.cells[1].child as Text).data!;

    expect(
      table().columns.take(7).every((column) => column.onSort != null),
      isTrue,
    );
    expect(firstExpected(), '9');

    await tester.tap(
      find.byKey(const ValueKey('staff-attendance-sort-expected')),
    );
    await tester.pump();
    expect(firstExpected(), '2');

    await tester.tap(
      find.byKey(const ValueKey('staff-attendance-sort-expected')),
    );
    await tester.pump();
    expect(firstExpected(), '9');
    expect(tester.takeException(), isNull);
  });
}

class _FakeStaffAttendanceRepository implements StaffAttendanceRepository {
  _FakeStaffAttendanceRepository({this.dashboardDays});

  final List<StaffAttendanceDayRecord>? dashboardDays;
  int saveCount = 0;
  bool? lastSubmitted;
  final people = const [
    StaffAttendancePerson(id: 'STF-1', name: 'Ama Mensah', role: 'Teacher'),
    StaffAttendancePerson(id: 'STF-2', name: 'Kofi Owusu', role: 'Bursar'),
  ];

  @override
  Future<StaffAttendanceContext> getContext(String schoolId) async =>
      const StaffAttendanceContext(
        termId: 9,
        termLabel: 'First Term',
        academicYear: '2026-2027',
      );
  @override
  Future<StaffAttendanceDashboardData> getDashboard({
    required String schoolId,
    required int termId,
  }) async {
    final days =
        dashboardDays ??
        [
          StaffAttendanceDayRecord(
            date: DateTime.now(),
            expected: 2,
            present: 0,
            late: 0,
            excused: 0,
            unexcused: 0,
            status: 'MISSING',
          ),
        ];
    return StaffAttendanceDashboardData(
      expectedStaffDays: 2,
      presentDays: 0,
      lateDays: 0,
      excusedAbsences: 0,
      unexcusedAbsences: 0,
      missingRegisters: days.where((day) => day.status == 'MISSING').length,
      attendanceRate: 0,
      punctualityRate: 0,
      days: days,
    );
  }

  @override
  Future<void> markNonSchoolDay({
    required String schoolId,
    required NonSchoolDayInput input,
  }) async {}
  @override
  Future<List<StaffAttendancePerson>> getActiveStaff(String schoolId) async =>
      people;
  @override
  Future<List<StaffAttendanceEntry>> getDailyRegister({
    required String schoolId,
    required DateTime date,
    required List<StaffAttendancePerson> people,
  }) async =>
      people.map((person) => StaffAttendanceEntry(person: person)).toList();
  @override
  Future<List<StaffAttendanceEntry>> saveDailyRegister({
    required String schoolId,
    required int termId,
    required DateTime date,
    required List<StaffAttendanceEntry> entries,
    required bool submit,
    String? correctionReason,
  }) async {
    saveCount += 1;
    lastSubmitted = submit;
    return entries
        .map(
          (entry) =>
              entry.copyWith(registerStatus: submit ? 'SUBMITTED' : 'DRAFT'),
        )
        .toList();
  }
}
