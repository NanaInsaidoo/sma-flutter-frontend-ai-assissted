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
    bool canAcknowledge = false,
    String? viewerRole,
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
            canAcknowledge: canAcknowledge,
            viewerRole: viewerRole,
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
    expect(find.text('Term attendance summary'), findsOneWidget);
    expect(find.text('Term-to-date attendance'), findsOneWidget);
    expect(find.text('Overall attendance'), findsOneWidget);
    expect(find.text('Attendance by grade and stream'), findsOneWidget);

    await tester.tap(find.text('Recent days'));
    await tester.pumpAndSettle();
    expect(
      find.text('Select one of the five most recent school days'),
      findsOneWidget,
    );
    expect(find.text('Selected date'), findsNWidgets(2));

    final classRow = find.byKey(const ValueKey('attendance-class-11'));
    await tester.ensureVisible(classRow);
    await tester.tap(classRow);
    await tester.pumpAndSettle();

    expect(find.text('KG 1 · Stream A'), findsOneWidget);
    expect(find.textContaining('15 students'), findsOneWidget);
    expect(find.text('Akua Bonsu'), findsWidgets);

    await tester.tap(find.byTooltip('Back to attendance dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('School Attendance'), findsOneWidget);
  });

  testWidgets('shows a concise term attendance summary above daily figures', (
    tester,
  ) async {
    await pumpDashboard(tester, repository: _TermSummaryAttendanceRepository());

    final summary = find.byKey(const ValueKey('term-attendance-summary'));
    expect(summary, findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text('92.5%')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.text('3 students need follow-up'),
      ),
      findsOneWidget,
    );
    expect(find.text('Overall attendance'), findsOneWidget);
    expect(find.text('Present'), findsWidgets);
    expect(find.text('Absent'), findsWidgets);
    expect(find.text('Late'), findsWidgets);
  });

  testWidgets('class teacher sees assigned attendance and authorized cover', (
    tester,
  ) async {
    await pumpDashboard(tester, viewerRole: 'CLASS_TEACHER');

    expect(find.text('My Class Attendance'), findsOneWidget);
    expect(find.text('Mark my class'), findsOneWidget);
    expect(find.text('Take another class'), findsOneWidget);
    expect(find.text('My reports'), findsOneWidget);
    expect(find.text('View reports'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('take-authorized-class-attendance')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Class and date'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<int>), findsWidgets);
  });

  testWidgets('subject teacher uses authorization and has no class report', (
    tester,
  ) async {
    await pumpDashboard(tester, viewerRole: 'SUBJECT_TEACHER');

    expect(find.text('My Class Attendance'), findsOneWidget);
    expect(find.text('Take attendance'), findsWidgets);
    expect(find.text('Use confirmed authorization'), findsOneWidget);
    expect(find.text('My reports'), findsNothing);
    expect(find.text('View reports'), findsNothing);
  });

  testWidgets('view reports opens class term analytics', (tester) async {
    final repository = _ReportAttendanceRepository();
    await pumpDashboard(tester, repository: repository);

    final viewReports = find.text('View reports');
    await tester.ensureVisible(viewReports);
    await tester.tap(viewReports);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('attendance-reports-page')),
      findsOneWidget,
    );
    expect(find.text('Attendance reports'), findsOneWidget);
    expect(find.text('Term overview'), findsOneWidget);
    expect(find.text('Create an attendance report'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('open-attendance-report-builder')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('close-attendance-report-builder')),
      findsOneWidget,
    );
    expect(find.text('Create attendance report'), findsOneWidget);
    expect(find.text('By student'), findsOneWidget);
    expect(find.text('By class'), findsOneWidget);
    expect(find.text('This term'), findsOneWidget);
    expect(find.text('Attendance percentage'), findsOneWidget);
    expect(find.text('All students — search to select'), findsOneWidget);
    await tester.tap(find.text('Date range'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('report-from-date-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('report-to-date-selector')),
      findsOneWidget,
    );
    await tester.tap(find.text('This term'));
    await tester.pumpAndSettle();

    final studentSelector = find.byKey(
      const ValueKey('report-student-selector'),
    );
    await tester.ensureVisible(studentSelector);
    await tester.pumpAndSettle();
    await tester.tap(studentSelector);
    await tester.pumpAndSettle();
    expect(find.text('Search by student, ID, or class'), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply 2'));
    await tester.pumpAndSettle();
    expect(find.text('2 students selected'), findsOneWidget);
    final termOverview = find.byKey(
      const ValueKey('term-attendance-report-overview'),
    );
    expect(
      find.descendant(of: termOverview, matching: find.text('Attendance rate')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: termOverview,
        matching: find.text('Students enrolled'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: termOverview,
        matching: find.text('Students needing attention'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: termOverview, matching: find.text('Present')),
      findsNothing,
    );
    expect(
      find.descendant(of: termOverview, matching: find.text('Absent')),
      findsNothing,
    );
    expect(
      find.descendant(of: termOverview, matching: find.text('Late')),
      findsNothing,
    );
    expect(find.text('Class term report'), findsOneWidget);
    expect(find.text('93.3%'), findsOneWidget);
    expect(find.text('Completed days'), findsOneWidget);
    expect(find.text('Missing days'), findsOneWidget);
    expect(find.text('Non-school days'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attendance-report-days-table')),
      findsOneWidget,
    );
    expect(find.text('Founders Day'), findsOneWidget);
    expect(repository.requestedStreamIds, [11]);

    await tester.tap(find.byKey(const ValueKey('generate-attendance-report')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('generated-attendance-report')),
      findsOneWidget,
    );
    expect(find.text('Student report results'), findsOneWidget);
    expect(find.text('Ama Boateng'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('export-attendance-report-pdf')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('export-attendance-report-excel')),
      findsOneWidget,
    );
    expect(repository.generatedCriteria, ['ALL']);

    await tester.tap(find.byTooltip('Back to attendance dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('School Attendance'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

    await tester.ensureVisible(find.text('View all 4 alerts →'));
    await tester.tap(find.text('View all 4 alerts →'));
    await tester.pumpAndSettle();

    expect(find.text('Attendance alerts (4)'), findsOneWidget);
    expect(find.text('Attendance correction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period tabs wrap cleanly on a narrow attendance view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AttendanceDashboardScreen(
            customSchoolId: 'SCH-001',
            repository: FakeAttendanceRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('attendance-period-tabs')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Recent days'));
    await tester.tap(find.text('Recent days'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('attendance-date-selector')),
      findsOneWidget,
    );
  });

  testWidgets('choose date selects one day and recognizes today', (
    tester,
  ) async {
    final repository = _FixedDateAttendanceRepository();
    await pumpDashboard(tester, repository: repository);

    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();

    expect(find.text('Select attendance date'), findsOneWidget);
    var calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.initialDate, DateTime(2026, 9, 18));
    expect(calendar.currentDate, DateTime(2026, 9, 18));

    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('17'),
      ),
    );
    await tester.tap(find.text('Show attendance'));
    await tester.pumpAndSettle();

    expect(repository.requestedDate, DateTime(2026, 9, 17));
    expect(find.text('Selected date: 17 Sep 2026'), findsOneWidget);
    final selectedDate = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('attendance-date-2026-09-17')),
    );
    expect(selectedDate.selected, isTrue);

    await tester.tap(find.byKey(const ValueKey('change-attendance-date')));
    await tester.pumpAndSettle();
    calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.initialDate, DateTime(2026, 9, 17));
    expect(calendar.currentDate, DateTime(2026, 9, 18));

    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('18'),
      ),
    );
    await tester.tap(find.text('Show attendance'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('attendance-date-selector')),
      findsNothing,
    );
    expect(find.text('Friday, 18 September 2026'), findsOneWidget);
  });

  testWidgets('management table shows all classes and filters immediately', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(
      find.byKey(const ValueKey('attendance-class-table')),
      findsOneWidget,
    );
    expect(find.text('22 of 22 classes'), findsOneWidget);
    expect(find.text('CLASS'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('LEVEL'), findsNothing);
    expect(find.text('TEACHER'), findsNothing);
    expect(find.text('SUBMITTED BY'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('attendance-class-search')),
      'Basic 1',
    );
    await tester.pumpAndSettle();

    expect(find.text('2 of 22 classes'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-class-31')), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-class-32')), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-class-11')), findsNothing);
  });

  testWidgets('management can select a table row for acknowledgment', (
    tester,
  ) async {
    final repository = _AcknowledgmentAttendanceRepository();
    await pumpDashboard(tester, repository: repository, canAcknowledge: true);

    final checkbox = find.byKey(
      const ValueKey('select-attendance-register-11'),
    );
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('attendance-selected-classes-bar')),
      findsOneWidget,
    );
    expect(find.text('1 register selected'), findsOneWidget);

    final acknowledge = find.byKey(
      const ValueKey('acknowledge-selected-attendance'),
    );
    await tester.ensureVisible(acknowledge);
    await tester.tap(acknowledge);
    await tester.pumpAndSettle();
    expect(find.text('Acknowledge 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('confirm-attendance-acknowledgment')),
    );
    await tester.pumpAndSettle();
    expect(repository.acknowledgedStreamIds, [11]);
  });

  testWidgets('management can acknowledge multiple submitted registers', (
    tester,
  ) async {
    final repository = _AcknowledgmentAttendanceRepository();
    await pumpDashboard(tester, repository: repository, canAcknowledge: true);

    await tester.tap(
      find.byKey(const ValueKey('acknowledge-attendance-registers')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acknowledge attendance registers'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('select-all-attendance-acknowledgments')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('attendance-acknowledgment-note')),
      'Registers reviewed against class totals',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-attendance-acknowledgment')),
    );
    await tester.pumpAndSettle();

    expect(repository.acknowledgedStreamIds, hasLength(2));
    expect(repository.acknowledgmentNote, contains('class totals'));
    expect(find.text('Complete · 2'), findsOneWidget);
  });

  testWidgets('non-school day shows why no registers are expected', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      repository: _NonSchoolDayAttendanceRepository(),
    );

    expect(find.textContaining('Founders Day'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attendance-workflow-non-school-day')),
      findsOneWidget,
    );
    expect(find.textContaining('classes have not submitted'), findsNothing);
  });
}

class _NonSchoolDayAttendanceRepository extends FakeAttendanceRepository {
  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    final overview = await super.getOverview(customSchoolId);
    return AttendanceDashboardOverview(
      currentDate: overview.currentDate,
      schoolDay: false,
      today: overview.today,
      week: overview.week,
      month: overview.month,
      classes: overview.classes,
      alerts: overview.alerts,
      streamsPending: 0,
      calendarMessage:
          'This date is not an official school day per the school calendar: Founders Day.',
    );
  }
}

class _TermSummaryAttendanceRepository extends FakeAttendanceRepository {
  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    final overview = await super.getOverview(customSchoolId);
    return AttendanceDashboardOverview(
      currentDate: overview.currentDate,
      schoolDay: overview.schoolDay,
      today: overview.today,
      week: overview.week,
      month: overview.month,
      term: const AttendancePeriodSummary(
        attendanceRate: 92.5,
        present: 740,
        absent: 60,
        late: 18,
        totalStudents: 800,
        studentsNeedingAttention: 3,
      ),
      classes: overview.classes,
      alerts: overview.alerts,
      streamsPending: overview.streamsPending,
      recentSchoolDates: overview.recentSchoolDates,
    );
  }
}

class _FixedDateAttendanceRepository extends FakeAttendanceRepository {
  static final DateTime today = DateTime(2026, 9, 18);
  DateTime? requestedDate;

  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    final overview = await super.getOverview(customSchoolId);
    return _copyOverview(overview, date: today);
  }

  @override
  Future<AttendanceDashboardOverview> getOverviewForDate(
    String customSchoolId,
    DateTime date,
  ) async {
    requestedDate = DateUtils.dateOnly(date);
    final overview = await super.getOverview(customSchoolId);
    return _copyOverview(overview, date: requestedDate!);
  }

  AttendanceDashboardOverview _copyOverview(
    AttendanceDashboardOverview overview, {
    required DateTime date,
  }) {
    return AttendanceDashboardOverview(
      currentDate: date,
      schoolDay: date.weekday <= DateTime.friday,
      today: overview.today,
      week: overview.week,
      month: overview.month,
      classes: overview.classes,
      alerts: overview.alerts,
      streamsPending: overview.streamsPending,
      recentSchoolDates: [
        DateTime(2026, 9, 17),
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 11),
      ],
    );
  }
}

class _AcknowledgmentAttendanceRepository extends FakeAttendanceRepository {
  List<int> acknowledgedStreamIds = const [];
  String? acknowledgmentNote;

  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    final overview = await super.getOverview(customSchoolId);
    final acknowledged = acknowledgedStreamIds.toSet();
    final classes = overview.classes.map((item) {
      final reviewable = item.streamId == 11 || item.streamId == 12;
      return AttendanceClassSummary(
        gradeId: item.gradeId,
        gradeName: item.gradeName,
        streamId: item.streamId,
        streamName: item.streamName,
        totalStudents: item.totalStudents,
        teacherName: item.teacherName,
        present: reviewable ? item.totalStudents : item.present,
        absent: 0,
        late: 0,
        attendanceRate: reviewable ? 100 : item.attendanceRate,
        submitted: reviewable,
        registerStatus: acknowledged.contains(item.streamId)
            ? AttendanceRegisterStatus.complete
            : reviewable
            ? AttendanceRegisterStatus.awaitingAcknowledgment
            : AttendanceRegisterStatus.notSubmitted,
        acknowledgedBy: acknowledged.contains(item.streamId)
            ? 'Head Teacher'
            : '',
      );
    }).toList();
    return AttendanceDashboardOverview(
      currentDate: overview.currentDate,
      schoolDay: overview.schoolDay,
      today: overview.today,
      week: overview.week,
      month: overview.month,
      classes: classes,
      alerts: overview.alerts,
      streamsPending: overview.streamsPending - 2,
    );
  }

  @override
  Future<AttendanceDashboardOverview> getOverviewForDate(
    String customSchoolId,
    DateTime date,
  ) => getOverview(customSchoolId);

  @override
  Future<void> acknowledgeAttendance({
    required String customSchoolId,
    required DateTime date,
    required List<int> streamIds,
    String? note,
  }) async {
    acknowledgedStreamIds = [...streamIds];
    acknowledgmentNote = note;
  }
}

class _ReportAttendanceRepository extends FakeAttendanceRepository
    implements AttendanceReportRepository {
  final List<int> requestedStreamIds = [];
  final List<String> generatedCriteria = [];

  @override
  Future<List<AttendanceReportOption>> getAttendanceReportOptions({
    required String customSchoolId,
  }) async => const [
    AttendanceReportOption(
      customStudentId: 'STU-001',
      studentName: 'Ama Boateng',
      gradeLevelId: 1,
      gradeName: 'KG 1',
      streamId: 11,
      streamName: 'Stream A',
      householdId: 7,
      householdName: 'Boateng Household',
    ),
    AttendanceReportOption(
      customStudentId: 'STU-002',
      studentName: 'Kofi Mensah',
      gradeLevelId: 1,
      gradeName: 'KG 1',
      streamId: 11,
      streamName: 'Stream A',
    ),
  ];

  @override
  Future<AttendanceGeneratedReport> generateAttendanceReport({
    required String customSchoolId,
    required String criterion,
    List<int> streamIds = const [],
    List<String> studentIds = const [],
    int? householdId,
    DateTime? startDate,
    DateTime? endDate,
    double? absenteeismThreshold,
  }) async {
    generatedCriteria.add(criterion);
    return AttendanceGeneratedReport(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 18),
      criterion: criterion,
      studentsIncluded: 1,
      present: 10,
      absent: 2,
      late: 1,
      attendanceRate: 75,
      students: const [
        AttendanceReportStudent(
          customStudentId: 'STU-001',
          studentName: 'Ama Boateng',
          gradeName: 'KG 1',
          streamName: 'Stream A',
          markedDays: 13,
          present: 10,
          absent: 2,
          late: 1,
          attendanceRate: 75,
          absenceRate: 15.4,
        ),
      ],
    );
  }

  @override
  Future<AttendanceTermHistory> getTermHistory({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
  }) async {
    requestedStreamIds.add(streamId);
    return AttendanceTermHistory(
      termId: 1,
      teachingStartDate: DateTime(2026, 9, 1),
      teachingEndDate: DateTime(2026, 12, 11),
      expectedStudents: 15,
      days: [
        AttendanceDaySummary(
          date: DateTime(2026, 9, 18),
          status: AttendanceDayStatus.completed,
          expectedStudents: 15,
          markedStudents: 15,
          present: 13,
          absent: 1,
          late: 1,
        ),
        AttendanceDaySummary(
          date: DateTime(2026, 9, 17),
          status: AttendanceDayStatus.missing,
          expectedStudents: 15,
        ),
        AttendanceDaySummary(
          date: DateTime(2026, 9, 16),
          status: AttendanceDayStatus.nonSchoolDay,
          expectedStudents: 15,
          eventName: 'Founders Day',
        ),
      ],
    );
  }
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
