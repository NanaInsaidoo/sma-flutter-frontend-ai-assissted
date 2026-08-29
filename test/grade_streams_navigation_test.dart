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

    expect(find.text('Custom early-years classes'), findsOneWidget);
    expect(find.text('GES grade levels'), findsOneWidget);
    expect(find.text('Nursery 1 - Stream A'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Custom early-years classes')).dy,
      lessThan(tester.getTopLeft(find.text('GES grade levels')).dy),
    );
    expect(find.text('Basic 1 - Section 1'), findsOneWidget);
    expect(find.text('Basic 1 - Section 2'), findsOneWidget);
    expect(find.text('JHS 1'), findsOneWidget);
    expect(find.text('No sections configured yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-section-11')), findsOneWidget);

    await tester.tap(find.text('Basic 1 - Section 1'));
    await tester.pump();

    expect(find.text('Basic 1 - Section 1'), findsWidgets);
    expect(find.text('Basic 1 - Section 2'), findsNothing);
  });

  testWidgets('class configuration keeps custom early-years above GES levels', (
    tester,
  ) async {
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage classes & subjects'));
    await tester.pumpAndSettle();

    expect(find.text('Add custom class'), findsOneWidget);
    expect(find.text('Custom early-years classes'), findsOneWidget);
    expect(find.text('GES grade levels'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Custom early-years classes')).dy,
      lessThan(tester.getTopLeft(find.text('GES grade levels')).dy),
    );
    expect(find.text('Nursery 1'), findsOneWidget);
    expect(find.text('1 section · 0 students'), findsOneWidget);
    expect(find.text('SHS 1'), findsNothing);
  });

  testWidgets('empty grade requires first-stream confirmation to activate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClassesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeStreamsScreen(
            customSchoolId: 'SCHOOL-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage classes & subjects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(find.text('Activate JHS 1?'), findsOneWidget);
    expect(find.text('Create section and activate'), findsOneWidget);
    await tester.tap(find.text('Create section and activate'));
    await tester.pumpAndSettle();

    expect(repository.calls, equals(['activate:9']));
  });

  testWidgets('add class or section offers both simple paths', (tester) async {
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-class-or-section')));
    await tester.pumpAndSettle();

    expect(find.text('Create a new class'), findsOneWidget);
    expect(find.text('Add a section to an existing class'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-section-choice')));
    await tester.pumpAndSettle();

    expect(find.text('Add section'), findsWidgets);
    expect(find.text('Class'), findsOneWidget);
    expect(find.text('Section name'), findsOneWidget);
  });

  testWidgets('new class choice opens the custom class form', (tester) async {
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-class-or-section')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-new-class-choice')));
    await tester.pumpAndSettle();

    expect(find.text('Add custom early-years class'), findsOneWidget);
    expect(find.text('Class name'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
  });

  testWidgets('class add-section action is locked to that class', (
    tester,
  ) async {
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-section-10')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('locked-section-class')), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    expect(find.text('Basic 1'), findsWidgets);
    expect(find.text('Section name'), findsOneWidget);
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
  final List<String> calls = [];

  static const _customGrade = ClassGradeLevel(
    id: 9,
    gradeLevelId: 100001,
    name: 'Nursery 1',
    status: 'ACTIVE',
    custom: true,
    displayOrder: 100,
    streams: [
      ClassStreamSummary(
        id: 9,
        name: 'Nursery 1 - Stream A',
        gradeLevelId: 100001,
        teacherName: '',
        enrolled: 0,
        capacity: 35,
        active: true,
      ),
    ],
  );

  static const _grade = ClassGradeLevel(
    id: 10,
    gradeLevelId: 3,
    name: 'Basic 1',
    status: 'ACTIVE',
    displayOrder: 1300,
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

  static const _activeGradeWithoutStreams = ClassGradeLevel(
    id: 11,
    gradeLevelId: 9,
    name: 'JHS 1',
    status: 'INACTIVE',
    displayOrder: 1900,
    streams: [],
  );

  static const _unsupportedSeniorGrade = ClassGradeLevel(
    id: 12,
    gradeLevelId: 12,
    name: 'SHS 1',
    status: 'INACTIVE',
    displayOrder: 2200,
    streams: [],
  );

  @override
  Future<List<ClassGradeLevel>> getAllGradeLevels(
    String customSchoolId,
  ) async => const [
    _grade,
    _customGrade,
    _activeGradeWithoutStreams,
    _unsupportedSeniorGrade,
  ];

  @override
  Future<List<ClassGradeLevel>> getGradeStreams(String customSchoolId) async =>
      const [
        _grade,
        _customGrade,
        _activeGradeWithoutStreams,
        _unsupportedSeniorGrade,
      ];

  @override
  Future<List<ClassGradeLevel>> getAllStreams(String customSchoolId) async =>
      const [
        _grade,
        _customGrade,
        _activeGradeWithoutStreams,
        _unsupportedSeniorGrade,
      ];

  @override
  Future<void> setGradeLevelActive({
    required String customSchoolId,
    required int gradeLevelId,
    required bool active,
  }) async {
    calls.add('${active ? 'activate' : 'deactivate'}:$gradeLevelId');
  }

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
