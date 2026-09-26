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
    expect(find.text('No repeated lateness.'), findsOneWidget);
    expect(find.text('Mark 3 more students to submit.'), findsOneWidget);

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
    expect(find.text('No repeated lateness.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('submit-attendance')));
    await tester.pumpAndSettle();
    expect(repository.saveCount, 1);
    expect(repository.lastUpdateExisting, isFalse);
    expect(find.text('Attendance submitted successfully.'), findsOneWidget);
  });

  testWidgets(
    'future dates remain selectable but cannot be marked or submitted',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final futureDate = DateTime.now().add(const Duration(days: 2));
      final repository = _FakeAttendanceRepository(
        context: AttendanceEntryContext(
          date: futureDate,
          currentDate: DateTime.now(),
          futureDate: true,
          schoolDay: true,
          assignedClassTeacher: true,
          permissionAffirmationRequired: false,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AttendanceScreen(
              customSchoolId: 'SCH-001',
              initialDate: futureDate,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('future-attendance-blocked-message')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('submit-attendance')),
            )
            .onPressed,
        isNull,
      );
      expect(repository.saveCount, 0);
    },
  );

  testWidgets('non-class teacher must affirm authorization before submitting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeAttendanceRepository(
      context: AttendanceEntryContext(
        date: DateTime.now(),
        currentDate: DateTime.now(),
        futureDate: false,
        schoolDay: true,
        assignedClassTeacher: false,
        permissionAffirmationRequired: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceScreen(
            customSchoolId: 'SCH-001',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all present'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('submit-attendance')));
    await tester.tap(find.byKey(const ValueKey('submit-attendance')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm authorization'), findsOneWidget);
    expect(
      find.text(
        'I confirm that I have the proper authorization to take attendance for this class.',
      ),
      findsOneWidget,
    );
    expect(find.text('Confirm and Submit'), findsOneWidget);
    expect(find.textContaining('audit trail'), findsNothing);
    expect(repository.saveCount, 0);
    await tester.tap(
      find.byKey(const ValueKey('attendance-permission-affirmation')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('confirm-attendance-permission')),
    );
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.lastPermissionAffirmed, isTrue);
    expect(
      repository.lastAuthorizationStatement,
      'I confirm that I have the proper authorization to take attendance for this class.',
    );
  });

  testWidgets('past attendance requires an audited reason', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selectedDate = DateTime(2026, 9, 16);
    final repository = _FakeAttendanceRepository(
      context: AttendanceEntryContext(
        date: selectedDate,
        currentDate: DateTime(2026, 9, 18),
        futureDate: false,
        schoolDay: true,
        assignedClassTeacher: true,
        permissionAffirmationRequired: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceScreen(
            customSchoolId: 'SCH-001',
            initialDate: selectedDate,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark all present'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('submit-attendance')));
    await tester.tap(find.byKey(const ValueKey('submit-attendance')));
    await tester.pumpAndSettle();

    expect(find.text('Reason for past attendance'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('past-attendance-reason')),
      'Register completed after a network outage',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-past-attendance-reason')),
    );
    await tester.pumpAndSettle();

    expect(repository.lastCorrectionReason, contains('network outage'));
  });

  testWidgets('non-school day explains the calendar and opens it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calendarOpened = false;
    final repository = _FakeAttendanceRepository(
      context: AttendanceEntryContext(
        date: DateTime.now(),
        currentDate: DateTime.now(),
        futureDate: false,
        schoolDay: false,
        assignedClassTeacher: true,
        permissionAffirmationRequired: false,
        calendarMessage:
            'This date is not an official school day per the school calendar: Founders Day.',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceScreen(
            customSchoolId: 'SCH-001',
            repository: repository,
            onOpenCalendar: () => calendarOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('non-school-day-banner')), findsOneWidget);
    expect(find.textContaining('Founders Day'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('view-non-school-days')));
    expect(calendarOpened, isTrue);
  });

  testWidgets(
    'submitted attendance is read-only until edit and changes require a reason',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _FakeAttendanceRepository(
        context: AttendanceEntryContext(
          date: DateTime.now(),
          currentDate: DateTime.now(),
          futureDate: false,
          schoolDay: true,
          assignedClassTeacher: true,
          permissionAffirmationRequired: false,
          submitted: true,
          registerStatus: AttendanceRegisterStatus.awaitingAcknowledgment,
          revision: 1,
        ),
        records: const [
          AttendanceRecord(
            attendanceId: 'ATT-1',
            customStudentId: 'STU-001',
            mark: AttendanceMark.present,
          ),
          AttendanceRecord(
            attendanceId: 'ATT-2',
            customStudentId: 'STU-002',
            mark: AttendanceMark.present,
          ),
          AttendanceRecord(
            attendanceId: 'ATT-3',
            customStudentId: 'STU-003',
            mark: AttendanceMark.present,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AttendanceScreen(
              customSchoolId: 'SCH-001',
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Awaiting acknowledgment'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-submitted-attendance')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.ancestor(
                of: find.text('Mark all absent'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is OutlinedButton,
                ),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('edit-submitted-attendance')));
      await tester.pump();
      await tester.tap(find.byTooltip('Absent').first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('submit-attendance')));
      await tester.pumpAndSettle();

      expect(find.text('Reason for attendance change'), findsOneWidget);
      expect(repository.saveCount, 0);
      await tester.enterText(
        find.byKey(const ValueKey('attendance-change-reason')),
        'Guardian confirmed the learner was absent',
      );
      await tester.tap(
        find.byKey(const ValueKey('confirm-attendance-change-reason')),
      );
      await tester.pumpAndSettle();

      expect(repository.saveCount, 1);
      expect(repository.lastUpdateExisting, isTrue);
      expect(repository.lastCorrectionReason, contains('Guardian confirmed'));
    },
  );

  testWidgets('shows only repeated lateness and escalates with a note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeAttendanceRepository(
      lateConcerns: [
        AttendanceLateConcern(
          customStudentId: 'STU-001',
          fullName: 'Kofi Agyemang',
          consecutiveLateDays: 2,
          totalMinutesLate: 25,
          latestLateDate: DateTime(2026, 9, 18),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceScreen(
            customSchoolId: 'SCH-001',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Late for 2 consecutive school days'), findsOneWidget);
    expect(find.text('Absent today'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('escalate-lateness-STU-001')));
    await tester.pumpAndSettle();
    expect(find.text('Escalate to headmaster'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('lateness-escalation-note')),
      'Guardian has been reminded about the reporting time.',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-lateness-escalation')));
    await tester.pumpAndSettle();

    expect(
      repository.lastEscalationNote,
      contains('Guardian has been reminded'),
    );
    expect(find.text('Escalated'), findsOneWidget);
    expect(find.text('Escalated to the headmaster.'), findsOneWidget);
  });
}

class _FakeAttendanceRepository implements AttendanceRepository {
  _FakeAttendanceRepository({
    this.context,
    this.records = const [],
    this.lateConcerns = const [],
  });

  final AttendanceEntryContext? context;
  final List<AttendanceRecord> records;
  final List<AttendanceLateConcern> lateConcerns;
  int saveCount = 0;
  bool? lastUpdateExisting;
  bool? lastPermissionAffirmed;
  String? lastAuthorizationStatement;
  String? lastCorrectionReason;
  String? lastEscalationNote;

  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    return AttendanceDashboardOverview(
      currentDate: DateTime(2026, 7, 18),
      schoolDay: true,
      today: const AttendancePeriodSummary(
        attendanceRate: 0,
        present: 0,
        absent: 0,
        late: 0,
        totalStudents: 3,
      ),
      week: const AttendancePeriodSummary(
        attendanceRate: 0,
        present: 0,
        absent: 0,
        late: 0,
        totalStudents: 3,
      ),
      month: const AttendancePeriodSummary(
        attendanceRate: 0,
        present: 0,
        absent: 0,
        late: 0,
        totalStudents: 3,
      ),
      classes: const [],
      alerts: const [],
      streamsPending: 0,
    );
  }

  @override
  Future<AttendanceDashboardOverview> getOverviewForDate(
    String customSchoolId,
    DateTime date,
  ) => getOverview(customSchoolId);

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
    return AttendanceRoster(students: students, records: records);
  }

  @override
  Future<AttendanceEntryContext> getEntryContext({
    required String customSchoolId,
    required int streamId,
    required DateTime date,
  }) async =>
      context ??
      AttendanceEntryContext(
        date: date,
        currentDate: DateTime(date.year, date.month, date.day),
        futureDate: false,
        schoolDay: true,
        assignedClassTeacher: true,
        permissionAffirmationRequired: false,
      );

  @override
  Future<List<AttendanceLateConcern>> getLateConcerns({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async => lateConcerns;

  @override
  Future<AttendanceLateConcern> escalateLateConcern({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required String customStudentId,
    required DateTime date,
    required String note,
  }) async {
    lastEscalationNote = note;
    final concern = lateConcerns.firstWhere(
      (item) => item.customStudentId == customStudentId,
    );
    return AttendanceLateConcern(
      customStudentId: concern.customStudentId,
      fullName: concern.fullName,
      consecutiveLateDays: concern.consecutiveLateDays,
      totalMinutesLate: concern.totalMinutesLate,
      latestLateDate: concern.latestLateDate,
      escalated: true,
      escalationId: 7,
      escalatedAt: DateTime(2026, 9, 18, 9, 30),
    );
  }

  @override
  Future<AttendanceTermHistory> getTermHistory({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
  }) async => AttendanceTermHistory(
    termId: 1,
    teachingStartDate: DateTime(2026, 7, 1),
    teachingEndDate: DateTime(2026, 9, 30),
    expectedStudents: 3,
    days: const [],
  );

  @override
  Future<void> markNonSchoolDay({
    required String customSchoolId,
    required int termId,
    required DateTime date,
    required String name,
    required String type,
    String? description,
  }) async {}

  @override
  Future<void> acknowledgeAttendance({
    required String customSchoolId,
    required DateTime date,
    required List<int> streamIds,
    String? note,
  }) async {}

  @override
  Future<void> saveAttendance({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
    required List<AttendanceEntry> entries,
    required bool updateExisting,
    String? vacationOverrideReason,
    bool permissionAffirmed = false,
    String? authorizationStatement,
    String? correctionReason,
  }) async {
    saveCount += 1;
    lastUpdateExisting = updateExisting;
    lastPermissionAffirmed = permissionAffirmed;
    lastAuthorizationStatement = authorizationStatement;
    lastCorrectionReason = correctionReason;
  }
}
