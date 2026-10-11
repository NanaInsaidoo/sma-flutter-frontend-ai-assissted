import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/attendance/domain/attendance_models.dart';
import 'package:school_management_app/src/classes/domain/class_models.dart';
import 'package:school_management_app/src/classes/presentation/grade_streams_screen.dart';

import 'support/fake_attendance_repository.dart';

void main() {
  testWidgets('keeps the overview compact and opens the class workspace', (
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
            attendanceRepository: FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom classes'), findsOneWidget);
    expect(find.text('GES grade levels'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Custom classes')).dy,
      lessThan(tester.getTopLeft(find.text('GES grade levels')).dy),
    );
    expect(find.text('Nursery 1'), findsOneWidget);
    expect(find.text('Basic 1'), findsOneWidget);
    expect(find.text('JHS 1'), findsOneWidget);
    expect(find.text('Basic 1 - Section 1'), findsNothing);
    expect(find.text('Basic 1 - Section 2'), findsNothing);
    expect(find.text('Add section'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-grade-10')));
    await tester.pumpAndSettle();

    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Subjects'), findsNothing);
    expect(find.text('Basic 1 - Section 1'), findsOneWidget);
    expect(find.text('Basic 1 - Section 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-stream-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stream-details-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('stream-tab-subjects')), findsOneWidget);
    expect(find.text('Basic 1 - Section 1'), findsWidgets);
    expect(find.text('Add class teacher'), findsOneWidget);
    expect(find.text('Add teacher'), findsNothing);
  });

  testWidgets('loads a section roster with the school class id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final attendanceRepository = _RecordingAttendanceRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeStreamsScreen(
            customSchoolId: 'SCHOOL-1',
            repository: _FakeClassesRepository(),
            attendanceRepository: attendanceRepository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-grade-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-stream-1')));
    await tester.pumpAndSettle();

    expect(attendanceRepository.requestedGradeLevelId, 10);
    expect(attendanceRepository.requestedStreamId, 1);
  });

  testWidgets('class configuration keeps custom classes above GES levels', (
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
    expect(find.text('Add custom class'), findsOneWidget);
    expect(find.text('Custom classes'), findsOneWidget);
    expect(find.text('GES grade levels'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Custom classes')).dy,
      lessThan(tester.getTopLeft(find.text('GES grade levels')).dy),
    );
    expect(find.text('Nursery 1'), findsOneWidget);
    expect(find.textContaining('CUSTOM ·'), findsNothing);
    expect(find.textContaining('Progresses to'), findsNothing);
    expect(find.text('Subjects'), findsNothing);
    expect(find.text('SHS 1'), findsNothing);
    expect(find.byKey(const ValueKey('grade-active-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('grade-active-11')), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
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
            attendanceRepository: FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('grade-active-11')));
    await tester.pumpAndSettle();

    expect(find.text('Activate JHS 1?'), findsOneWidget);
    expect(find.text('Create section and activate'), findsOneWidget);
    await tester.tap(find.text('Create section and activate'));
    await tester.pumpAndSettle();

    expect(repository.calls, equals(['activate:9']));
  });

  testWidgets('making a class inactive requires confirmation', (tester) async {
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
    await tester.tap(find.byKey(const ValueKey('grade-active-10')));
    await tester.pumpAndSettle();

    expect(find.text('Make Basic 1 inactive?'), findsOneWidget);
    expect(repository.calls, isEmpty);
    await tester.tap(find.text('Keep active'));
    await tester.pumpAndSettle();
    expect(repository.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('grade-active-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make inactive'));
    await tester.pumpAndSettle();

    expect(repository.calls, equals(['deactivate:3']));
  });

  testWidgets('a class with enrolled students cannot be made inactive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EnrolledClassesRepository();

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
    await tester.tap(find.byKey(const ValueKey('grade-active-10')));
    await tester.pumpAndSettle();

    expect(find.text('Cannot make Basic 1 inactive'), findsOneWidget);
    expect(
      find.textContaining('Transfer, promote, withdraw, or graduate'),
      findsOneWidget,
    );
    expect(find.text('Make inactive'), findsNothing);
    expect(repository.calls, isEmpty);
  });

  testWidgets('class activation preserves the user scroll position', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
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
    final inactiveSwitch = find.byKey(const ValueKey('grade-active-11'));
    await tester.ensureVisible(inactiveSwitch);
    await tester.pumpAndSettle();
    final scrollableFinder = find
        .descendant(
          of: find.byType(GradeStreamsScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    final before = scrollable.position.pixels;
    expect(before, greaterThan(0));

    await tester.tap(inactiveSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create section and activate'));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, closeTo(before, 1));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('main page contains all classes without a second manage page', (
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

    expect(find.text('Classes & Sections'), findsOneWidget);
    expect(find.text('Custom classes'), findsOneWidget);
    expect(find.text('GES grade levels'), findsOneWidget);
    expect(find.text('Add custom class'), findsOneWidget);
    expect(find.text('Manage classes'), findsNothing);
    expect(find.byKey(const ValueKey('grade-active-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('grade-active-11')), findsOneWidget);
  });

  testWidgets(
    'classes use one page scroll with status filters and level sort',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
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

      expect(find.byKey(const ValueKey('classes-page-scroll')), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
      expect(find.text('1 inactive'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Basic 1')).dy,
        lessThan(tester.getTopLeft(find.text('JHS 1')).dy),
      );

      await tester.tap(find.byKey(const ValueKey('class-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inactive first').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('JHS 1')).dy,
        lessThan(tester.getTopLeft(find.text('Basic 1')).dy),
      );

      expect(find.text('Status'), findsNothing);
      expect(find.text('Level'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    },
  );

  testWidgets('class workspace opens custom class form from the overview', (
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

    await tester.tap(find.text('Add custom class'));
    await tester.pumpAndSettle();

    expect(find.text('Add custom class'), findsWidgets);
    expect(find.text('Class name'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Position: Before KG1'), findsNothing);
    expect(find.textContaining('Progression is automatic'), findsNothing);
  });

  testWidgets('class workspace adds a section to the open class', (
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

    await tester.tap(find.byKey(const ValueKey('open-grade-10')));
    await tester.pumpAndSettle();

    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Subjects'), findsNothing);
    expect(find.text('Basic 1 - Section 1'), findsOneWidget);
    expect(find.text('Basic 1 - Section 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workspace-add-section-10')));
    await tester.pumpAndSettle();

    expect(find.text('Add section to Basic 1'), findsOneWidget);
    expect(find.text('Section name'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('class-workspace-section-name')),
          )
          .decoration
          ?.prefixText,
      'Basic 1 - ',
    );

    await tester.enterText(
      find.byKey(const ValueKey('class-workspace-section-name')),
      'Section 3',
    );
    await tester.tap(find.text('Add section').last);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('create-stream:3:Basic 1 - Section 3'));
  });

  testWidgets('section actions rename and delete without cluttering the row', (
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
            attendanceRepository: FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-grade-10')));
    await tester.pumpAndSettle();

    expect(find.text('Rename section'), findsNothing);
    expect(find.text('Delete section'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('section-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename section'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('rename-section-name')))
          .decoration
          ?.prefixText,
      'Basic 1 - ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rename-section-name')),
      'Gold',
    );
    await tester.tap(find.text('Save name'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('rename-stream:1:Basic 1 - Gold'));

    await tester.tap(find.byKey(const ValueKey('section-actions-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete section'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Basic 1 - Section 1?'), findsOneWidget);
    await tester.tap(find.text('Delete section'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('delete-streams:1'));
  });

  testWidgets('subject manager explains ownership and section assignment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClassesRepository(
      withSubjects: true,
      subjectTeacherAssignments: const [
        SubjectTeacherAssignment(
          id: 1,
          streamId: 9,
          subjectId: 101,
          subjectType: 'GES',
          subjectName: 'English Language',
          subjectCode: 'ENG-KG1',
          staffId: 'STAFF-1',
          staffName: 'Akosua Owusu',
          active: true,
        ),
        SubjectTeacherAssignment(
          id: 2,
          streamId: 9,
          subjectId: 101,
          subjectType: 'GES',
          subjectName: 'English Language',
          subjectCode: 'ENG-KG1',
          staffId: 'STAFF-2',
          staffName: 'Kwame Mensah',
          active: true,
        ),
        SubjectTeacherAssignment(
          id: 3,
          streamId: 9,
          subjectId: 101,
          subjectType: 'GES',
          subjectName: 'English Language',
          subjectCode: 'ENG-KG1',
          staffId: 'STAFF-3',
          staffName: 'Yaw Asante',
          active: true,
        ),
      ],
    );
    var openedAssessmentWorkspace = false;
    int? assessmentStreamId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeStreamsScreen(
            customSchoolId: 'SCHOOL-1',
            repository: repository,
            attendanceRepository: FakeAttendanceRepository(),
            onOpenAssessments: (streamId) {
              openedAssessmentWorkspace = true;
              assessmentStreamId = streamId;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-grade-9')));
    await tester.pumpAndSettle();

    expect(find.text('Subjects'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-stream-9')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stream-tab-assessments')), findsNothing);
    expect(openedAssessmentWorkspace, isFalse);
    await tester.tap(find.byKey(const ValueKey('stream-go-assessments')));
    await tester.pump();
    expect(openedAssessmentWorkspace, isTrue);
    expect(assessmentStreamId, 9);

    await tester.tap(find.byKey(const ValueKey('stream-detail-actions')));
    await tester.pumpAndSettle();
    expect(find.text('Rename section'), findsOneWidget);
    expect(find.text('Delete section'), findsOneWidget);
    await tester.tapAt(const Offset(1300, 900));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stream-tab-subjects')));
    await tester.pumpAndSettle();

    expect(find.text('Subjects'), findsWidgets);
    expect(find.text('English Language'), findsOneWidget);
    expect(find.text('Swahili'), findsOneWidget);
    expect(find.text('GES subjects'), findsOneWidget);
    expect(find.text('Custom subjects'), findsOneWidget);
    expect(find.byKey(const ValueKey('stream-add-subject')), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(find.text('Active'), findsNWidgets(2));
    expect(find.text('Academic term'), findsNothing);
    expect(find.byKey(const ValueKey('stream-subject-term')), findsNothing);
    expect(find.textContaining('Official curriculum'), findsNothing);
    expect(find.text('No teacher assigned'), findsWidgets);
    expect(find.text('Akosua Owusu +2 more'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    expect(find.text('Assign'), findsOneWidget);
    expect(find.text('Teachers'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stream-add-subject')));
    await tester.pumpAndSettle();
    expect(find.text('Add custom subject'), findsOneWidget);
    expect(find.text('Assess for final reports?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('Subject code (optional)'), findsNothing);
    expect(find.text('Where should this subject be taught?'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('stream-subject-name')),
      'Creative Arts',
    );
    await tester.tap(find.text('Yes'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-stream-add-subject')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-stream-add-subject')));
    await tester.pumpAndSettle();
    expect(
      repository.calls,
      contains('create-subject:100001:Creative Arts:true'),
    );
    expect(repository.calls, contains('save-subject-sections:303:1:9'));
    expect(find.textContaining('Which sections'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('stream-subject-enabled-202')));
    await tester.pumpAndSettle();
    expect(find.text('Make Swahili inactive?'), findsOneWidget);
    expect(
      find.textContaining(
        'Existing scores and historical reports will be kept',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-subject-deactivation')),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, contains('save-subject-sections:202:1:'));
  });

  testWidgets('new custom subject is added only to the open section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeClassesRepository(withSubjects: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradeStreamsScreen(
            customSchoolId: 'SCHOOL-1',
            repository: repository,
            attendanceRepository: FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-grade-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-stream-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stream-tab-subjects')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stream-add-subject')));
    await tester.pumpAndSettle();

    expect(find.text('Subject code (optional)'), findsNothing);
    expect(find.text('Where should this subject be taught?'), findsNothing);
    expect(find.byType(RadioListTile), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('stream-subject-name')),
      'Robotics',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-stream-add-subject')));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('create-subject:3:Robotics:false'));
    expect(repository.calls, contains('save-subject-sections:303:1:1'));
  });
}

class _RecordingAttendanceRepository extends FakeAttendanceRepository {
  int? requestedGradeLevelId;
  int? requestedStreamId;

  @override
  Future<AttendanceRoster> getRoster({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async {
    requestedGradeLevelId = gradeLevelId;
    requestedStreamId = streamId;
    return const AttendanceRoster(students: [], records: []);
  }
}

class _EnrolledClassesRepository extends _FakeClassesRepository {
  static const _enrolledGrade = ClassGradeLevel(
    id: 10,
    gradeLevelId: 3,
    name: 'Basic 1',
    status: 'ACTIVE',
    studentCount: 4,
    displayOrder: 1300,
    streams: [
      ClassStreamSummary(
        id: 1,
        name: 'Basic 1 - Section 1',
        gradeLevelId: 3,
        teacherName: 'Akosua Owusu',
        enrolled: 4,
        capacity: 35,
        active: true,
      ),
    ],
  );

  List<ClassGradeLevel> get _levels => const [
    _enrolledGrade,
    _FakeClassesRepository._customGrade,
    _FakeClassesRepository._activeGradeWithoutStreams,
  ];

  @override
  Future<List<ClassGradeLevel>> getAllGradeLevels(
    String customSchoolId,
  ) async => _levels;

  @override
  Future<List<ClassGradeLevel>> getAllStreams(String customSchoolId) async =>
      _levels;
}

class _FakeClassesRepository extends Fake implements ClassesRepository {
  _FakeClassesRepository({
    this.withSubjects = false,
    this.subjectTeacherAssignments = const [],
  });

  final bool withSubjects;
  final List<SubjectTeacherAssignment> subjectTeacherAssignments;
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
  }) async => withSubjects
      ? const [
          ClassSubject(
            id: 101,
            name: 'English Language',
            code: 'ENG-KG1',
            custom: false,
            active: true,
            examinable: true,
            schoolSubjectId: 101,
          ),
          ClassSubject(
            id: 202,
            name: 'Swahili',
            code: 'SWA1',
            custom: true,
            active: true,
            examinable: false,
            schoolSubjectId: 202,
          ),
        ]
      : const [];

  @override
  Future<void> createStream({
    required String customSchoolId,
    required int gradeLevelId,
    required String streamName,
  }) async {
    calls.add('create-stream:$gradeLevelId:$streamName');
  }

  @override
  Future<void> renameStream({
    required String customSchoolId,
    required int streamId,
    required String streamName,
  }) async {
    calls.add('rename-stream:$streamId:$streamName');
  }

  @override
  Future<void> deleteStreams({
    required String customSchoolId,
    required List<int> streamIds,
  }) async {
    calls.add('delete-streams:${streamIds.join(',')}');
  }

  @override
  Future<List<SubjectAcademicTerm>> getSubjectAcademicTerms(
    String customSchoolId,
  ) async => withSubjects
      ? const [
          SubjectAcademicTerm(
            id: 1,
            name: 'First Term',
            academicYear: '2026-2027',
            status: 'ACTIVE',
            current: true,
            closed: false,
          ),
        ]
      : const [];

  @override
  Future<SubjectTermAvailability> getSubjectTermAvailability({
    required String customSchoolId,
    required int schoolSubjectId,
    required int academicTermId,
  }) async => SubjectTermAvailability(
    schoolSubjectId: schoolSubjectId,
    academicTermId: academicTermId,
    status: 'ACTIVE',
    streamIds: const [9],
    availableSections: const [
      SubjectSectionOption(id: 9, name: 'Nursery 1 - Stream A', active: true),
    ],
  );

  @override
  Future<ClassSubject> createCustomSubject({
    required String customSchoolId,
    required int gradeLevelId,
    required String name,
    required String code,
    required bool examinable,
  }) async {
    calls.add('create-subject:$gradeLevelId:$name:$examinable');
    return ClassSubject(
      id: 303,
      name: name,
      code: code,
      custom: true,
      active: true,
      examinable: examinable,
      schoolSubjectId: 303,
    );
  }

  @override
  Future<SubjectTermAvailability> saveSubjectTermAvailability({
    required String customSchoolId,
    required int schoolSubjectId,
    required int academicTermId,
    required List<int> streamIds,
    required String status,
  }) async {
    calls.add(
      'save-subject-sections:$schoolSubjectId:$academicTermId:${streamIds.join(',')}',
    );
    return SubjectTermAvailability(
      schoolSubjectId: schoolSubjectId,
      academicTermId: academicTermId,
      status: status,
      streamIds: streamIds,
      availableSections: const [
        SubjectSectionOption(id: 9, name: 'Nursery 1 - Stream A', active: true),
      ],
    );
  }

  @override
  Future<List<SubjectTeacherAssignment>> getSubjectTeacherAssignments({
    required String customSchoolId,
    required int streamId,
  }) async => subjectTeacherAssignments;
}
