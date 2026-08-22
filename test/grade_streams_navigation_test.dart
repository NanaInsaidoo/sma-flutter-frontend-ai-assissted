import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/attendance/domain/attendance_models.dart';
import 'package:school_management_app/src/classes/domain/class_models.dart';
import 'package:school_management_app/src/classes/presentation/grade_streams_screen.dart';

void main() {
  testWidgets('opens the stream selected by name', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeStreamsScreen(
            customSchoolId: 'SCHOOL-1',
            repository: _FakeClassesRepository(),
            attendanceRepository: _FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basic 1 - Section 1'), findsOneWidget);
    expect(find.text('Basic 1 - Section 2'), findsOneWidget);

    await tester.tap(find.text('Basic 1 - Section 1'));
    await tester.pump();

    expect(find.text('Basic 1 - Section 1'), findsWidgets);
    expect(find.text('Basic 1 - Section 2'), findsNothing);
  });
}

class _FakeAttendanceRepository extends Fake implements AttendanceRepository {
  @override
  Future<AttendanceRoster> getRoster({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async => const AttendanceRoster(students: [], records: []);

  @override
  Future<AttendanceTermHistory> getTermHistory({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
  }) async => AttendanceTermHistory(
    termId: 1,
    teachingStartDate: DateTime(2026, 8, 1),
    teachingEndDate: DateTime(2026, 12, 18),
    expectedStudents: 0,
    days: const [],
  );
}

class _FakeClassesRepository extends Fake implements ClassesRepository {
  static const _grade = ClassGradeLevel(
    id: 10,
    gradeLevelId: 3,
    name: 'Basic 1',
    status: 'ACTIVE',
    streams: [
      ClassStreamSummary(
        id: 1,
        name: 'Basic 1 - Section 1',
        gradeLevelId: 3,
        teacherName: '',
        enrolled: 0,
        capacity: 35,
        active: true,
      ),
      ClassStreamSummary(
        id: 2,
        name: 'Basic 1 - Section 2',
        gradeLevelId: 3,
        teacherName: 'Akosua Owusu',
        enrolled: 0,
        capacity: 35,
        active: true,
      ),
    ],
  );

  @override
  Future<List<ClassGradeLevel>> getGradeStreams(String customSchoolId) async =>
      const [_grade];

  @override
  Future<List<ClassGradeLevel>> getAllStreams(String customSchoolId) async =>
      const [_grade];

  @override
  Future<List<ClassTeacherAssignment>> getClassTeachers({
    required String customSchoolId,
    required int streamId,
  }) async => const [];

  @override
  Future<List<SchoolStaffOption>> getSchoolStaff(String customSchoolId) async =>
      const [];

  @override
  Future<List<ClassSubject>> getGradeSubjects({
    required String customSchoolId,
    required int gradeLevelId,
  }) async => const [];

  @override
  Future<List<SubjectTeacherAssignment>> getSubjectTeacherAssignments({
    required String customSchoolId,
    required int streamId,
  }) async => const [];
}
