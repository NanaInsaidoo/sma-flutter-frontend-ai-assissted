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
}

class _FakeStaffAttendanceRepository implements StaffAttendanceRepository {
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
  }) async => StaffAttendanceDashboardData(
    expectedStaffDays: 2,
    presentDays: 0,
    lateDays: 0,
    excusedAbsences: 0,
    unexcusedAbsences: 0,
    missingRegisters: 1,
    attendanceRate: 0,
    punctualityRate: 0,
    days: [
      StaffAttendanceDayRecord(
        date: DateTime.now(),
        expected: 2,
        present: 0,
        late: 0,
        excused: 0,
        unexcused: 0,
        status: 'MISSING',
      ),
    ],
  );

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
