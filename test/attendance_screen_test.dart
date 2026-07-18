import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/attendance/domain/attendance_models.dart';
import 'package:school_management_app/src/attendance/presentation/attendance_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('marks a roster and submits completed attendance', (
    tester,
  ) async {
    final repository = _FakeAttendanceRepository();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceScreen(
            customSchoolId: 'SCH-001',
            academicYear: '2025/2026',
            term: 'Term 2',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Basic 2'), findsOneWidget);
    expect(find.text('Stream 2'), findsOneWidget);
    expect(find.text('Kofi Agyemang'), findsWidgets);
    expect(find.text('High absences'), findsOneWidget);
    expect(find.text('Frequently late'), findsOneWidget);
    expect(find.text('3 days straight'), findsOneWidget);
    expect(find.text('Mark 3 more students to submit.'), findsOneWidget);

    await tester.tap(find.text('High absences'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      'Kofi Agyemang',
    );

    await tester.tap(find.text('Mark all present'));
    await tester.pump();
    expect(find.text('All students have been marked.'), findsOneWidget);

    final lateButtons = find.byTooltip('Late');
    await tester.tap(lateButtons.first);
    await tester.pumpAndSettle();
    expect(find.text('How late was the student?'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('late-minutes')), '15');
    await tester.pump();
    await tester.tap(find.text('Mark late'));
    await tester.pumpAndSettle();
    expect(find.text('Arrived 15 minutes late today.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('submit-attendance')));
    await tester.pumpAndSettle();
    expect(repository.saveCount, 1);
    expect(repository.lastUpdateExisting, isFalse);
    expect(find.text('Attendance submitted successfully.'), findsOneWidget);
  });
}

class _FakeAttendanceRepository implements AttendanceRepository {
  int saveCount = 0;
  bool? lastUpdateExisting;

  @override
  Future<List<AttendanceGradeLevel>> getGradeLevels(
    String customSchoolId,
  ) async {
    return const [AttendanceGradeLevel(id: 2, name: 'Basic 2')];
  }

  @override
  Future<List<AttendanceStream>> getStreams({
    required String customSchoolId,
    required int gradeLevelId,
  }) async {
    return const [AttendanceStream(id: 22, name: 'Stream 2', gradeLevelId: 2)];
  }

  @override
  Future<AttendanceRoster> getRoster({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async {
    const students = [
      AttendanceStudent(
        customStudentId: 'STU-001',
        firstName: 'Kofi',
        lastName: 'Agyemang',
        gradeLevelId: 2,
        streamId: 22,
        streamName: 'Stream 2',
      ),
      AttendanceStudent(
        customStudentId: 'STU-002',
        firstName: 'David',
        lastName: 'Akoto',
        gradeLevelId: 2,
        streamId: 22,
        streamName: 'Stream 2',
      ),
      AttendanceStudent(
        customStudentId: 'STU-003',
        firstName: 'Afia',
        lastName: 'Frimpong',
        gradeLevelId: 2,
        streamId: 22,
        streamName: 'Stream 2',
      ),
    ];
    return const AttendanceRoster(students: students, records: []);
  }

  @override
  Future<void> saveAttendance({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
    required List<AttendanceEntry> entries,
    required bool updateExisting,
  }) async {
    saveCount += 1;
    lastUpdateExisting = updateExisting;
  }
}
