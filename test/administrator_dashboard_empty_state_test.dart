import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/dashboard/data/dashboard_repository.dart';
import 'package:school_management_app/src/dashboard/data/teacher_dashboard_summary.dart';
import 'package:school_management_app/src/dashboard/data/teacher_workspace_api_client.dart';
import 'package:school_management_app/src/dashboard/domain/dashboard_models.dart';
import 'package:school_management_app/src/dashboard/presentation/administrator_dashboard.dart';
import 'package:school_management_app/src/approvals/domain/approval_models.dart';
import 'package:school_management_app/src/leave/presentation/leave_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

ApprovalItem _pendingCorrection({required bool approver}) => ApprovalItem(
  key: 'REPORT_CORRECTION:91',
  type: 'REPORT_CORRECTION',
  entityId: 91,
  category: 'Score corrections',
  title: 'Score correction · English Language CAT1',
  subtitle: 'STU-E41A3E-4032 · 9.5/10 → 10/10',
  status: 'PENDING_APPROVAL',
  requesterName: 'Sena Owusu',
  approverName: 'Adjoa Mensah',
  reason: 'Transcription error',
  canApprove: approver,
  canReject: approver,
  canWithdraw: false,
  sourcePage: 'assessments',
);

void main() {
  testWidgets('assigned score correction appears in administrator attention', (
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
          userDisplayName: 'Adjoa Mensah',
          role: 'ADMINISTRATOR',
          approvalInboxLoader: () async => ApprovalInbox(
            pendingMyApproval: 1,
            pendingMyRequests: 0,
            myApprovals: [_pendingCorrection(approver: true)],
            myRequests: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Report correction awaiting your approval'),
      findsOneWidget,
    );
    expect(find.text('Requests & Approvals · My approvals'), findsOneWidget);
    expect(find.textContaining('1 approvals'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher requester sees correction in tasks and request count', (
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
          repository: _ForbiddenDashboardRepository(),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Sena Owusu',
          role: 'CLASS_TEACHER',
          teacherDashboardLoader: () async => _teacherSummary,
          approvalInboxLoader: () async => ApprovalInbox(
            pendingMyApproval: 0,
            pendingMyRequests: 1,
            myApprovals: const [],
            myRequests: [_pendingCorrection(approver: false)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Requests & Approvals'), findsOneWidget);
    expect(
      find.text('Your report correction is awaiting approval'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 active report correction request needs'),
      findsOneWidget,
    );
    expect(find.textContaining('0 approvals'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.text('Final Report Management'), findsOneWidget);
    expect(find.text('Evaluations & Comments'), findsOneWidget);
    expect(find.text('School Calendar'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('My Leave'), findsOneWidget);
    expect(find.text('Leave Management'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-leave-panel')), findsNothing);
    expect(find.text('Staff leave'), findsNothing);
    expect(find.text('Find student'), findsOneWidget);
    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Record expense'), findsOneWidget);
    expect(find.text('Requests & approvals'), findsOneWidget);
    expect(find.text('More actions'), findsOneWidget);
    expect(find.text('Student attendance'), findsOneWidget);
    expect(find.text('Term-to-date attendance'), findsOneWidget);
    expect(find.text('No attendance concerns'), findsOneWidget);
    expect(find.text('Bad state: No element'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a concise term attendance summary', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: _EmptyDashboardRepository(
            attendance: const AttendanceSummary(
              total: 100,
              present: 92,
              absent: 8,
              late: 4,
              studentsNeedingAttention: 3,
            ),
          ),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('92.0%'), findsOneWidget);
    expect(find.text('Term-to-date attendance'), findsOneWidget);
    expect(find.text('3 students need follow-up'), findsOneWidget);
    expect(find.text('Present'), findsNothing);
    expect(find.text('Absent'), findsNothing);
    expect(find.text('Late'), findsNothing);
  });

  testWidgets('shows three attention items and opens the complete list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final alerts = List.generate(
      5,
      (index) => SchoolAlert(
        title: 'Alert ${index + 1}',
        message: 'Attention message ${index + 1}',
        context: 'Attendance',
        level: AlertLevel.warning,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: _EmptyDashboardRepository(alerts: alerts),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-attention-item-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-attention-item-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dashboard-attention-item-3')),
      findsNothing,
    );
    expect(find.text('Alert 4'), findsNothing);
    expect(find.text('+ 2 more'), findsOneWidget);

    await tester.ensureVisible(find.text('+ 2 more'));
    await tester.tap(find.text('+ 2 more'));
    await tester.pumpAndSettle();

    expect(find.text('All attention items'), findsOneWidget);
    expect(find.text('Alert 4'), findsOneWidget);
    expect(find.text('Alert 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('all-attention-item-4')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'teacher workspace remains available when administrator metrics are forbidden',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _ForbiddenDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test School',
            userDisplayName: 'Adwoa Teacher',
            role: 'CLASS_TEACHER',
            teacherDashboardLoader: () async => _teacherSummary,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Teacher dashboard'), findsOneWidget);
      expect(find.text('My Leave'), findsOneWidget);
      expect(find.text('School Calendar'), findsOneWidget);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('My Students'), findsNothing);
      expect(find.text('Student Attendance'), findsNothing);
      expect(find.text('Assessments'), findsOneWidget);
      expect(find.text('Evaluations & Comments'), findsOneWidget);
      expect(find.text('Leave Management'), findsNothing);
      expect(find.byKey(const ValueKey('dashboard-leave-panel')), findsNothing);
      expect(find.text('Staff leave'), findsNothing);
      expect(find.text('My classes'), findsOneWidget);
      expect(find.text('Today’s attendance'), findsOneWidget);
      expect(find.text('Assessment tasks'), findsOneWidget);
      expect(find.text('Students needing attention'), findsOneWidget);
      expect(find.text('Your next tasks'), findsOneWidget);
      expect(find.text('Updates & notices'), findsOneWidget);
      expect(find.text('Pending teaching tasks'), findsNothing);
      expect(find.text('Staff Management'), findsNothing);
      expect(find.text('Fees & Requirements'), findsNothing);
      expect(find.text('My Requisitions & Expenses'), findsOneWidget);
      expect(find.text('Final Report Management'), findsNothing);
      expect(find.text('Evaluation Management'), findsNothing);
      expect(find.text('Dashboard data is not available yet.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'teacher without an active assignment does not see assessments or evaluations',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _ForbiddenDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test School',
            userDisplayName: 'Unassigned Teacher',
            role: 'CLASS_TEACHER',
            teacherDashboardLoader: () async => _unassignedTeacherSummary,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Assessments'), findsNothing);
      expect(find.text('Evaluations & Comments'), findsNothing);
      expect(find.text('No active classes assigned'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'subject-only teacher sees attendance access without a pending obligation',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _ForbiddenDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test School',
            userDisplayName: 'Kwame Subject Teacher',
            role: 'SUBJECT_TEACHER',
            teacherDashboardLoader: () async => _subjectTeacherSummary,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Class attendance'), findsOneWidget);
      expect(find.text('View attendance'), findsOneWidget);
      expect(
        find.text('Take attendance when properly authorized'),
        findsOneWidget,
      );
      expect(find.text('Today’s attendance'), findsNothing);
      expect(find.textContaining('Attendance is pending'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('teacher and bursar can switch between their workspaces', (
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
          userDisplayName: 'Adwoa Dual Role',
          role: 'CLASS_TEACHER',
          roles: const ['CLASS_TEACHER', 'BURSAR'],
          teacherDashboardLoader: () async => _teacherSummary,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Classes assigned'), findsOneWidget);
    expect(find.text('Fees & Requirements'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bursar').last);
    await tester.pumpAndSettle();

    expect(find.text('Fees & Requirements'), findsOneWidget);
    expect(find.text('My Leave'), findsOneWidget);
    expect(find.text('School Calendar'), findsOneWidget);
    expect(find.text('Leave Management'), findsOneWidget);
    expect(find.text('Expenses & Petty Cash'), findsOneWidget);
    expect(find.text('Find student'), findsOneWidget);
    expect(find.text('Record payment'), findsOneWidget);
    expect(find.text('Record expense'), findsOneWidget);
    expect(find.text('Requests & approvals'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
    expect(find.text('Open assessments'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('class and subject access share one Teacher workspace', (
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
          userDisplayName: 'Adwoa Teacher',
          role: 'CLASS_TEACHER',
          roles: const ['CLASS_TEACHER', 'SUBJECT_TEACHER', 'BURSAR'],
          teacherDashboardLoader: () async => _teacherSummary,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teacher'), findsNWidgets(2));
    expect(find.text('Class Teacher'), findsNothing);
    expect(find.text('Subject Teacher'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    final workspaceValues = tester
        .widgetList<DropdownMenuItem<String>>(
          find.byType(DropdownMenuItem<String>),
        )
        .map((item) => item.value)
        .toSet();
    expect(workspaceValues, {'CLASS_TEACHER', 'BURSAR'});
    expect(find.text('Teacher'), findsNWidgets(3));
    expect(find.text('Bursar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('school calendar menu opens the complete event list', (
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
          repository: _EmptyDashboardRepository(
            calendarEvents: [
              SchoolEvent(
                id: 'holiday-1',
                startDate: DateTime(2030, 10, 4),
                endDate: DateTime(2030, 10, 4),
                title: 'Founders Day',
                category: 'HOLIDAY',
                isSchoolDay: false,
              ),
              SchoolEvent(
                id: 'vacation-1',
                startDate: DateTime(2099, 12, 18),
                endDate: DateTime(2100, 1, 7),
                title: 'Christmas vacation',
                category: 'VACATION',
                isSchoolDay: false,
              ),
            ],
          ),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('School Calendar'), findsWidgets);
    expect(find.text('Upcoming Events'), findsOneWidget);
    expect(find.text('2 events'), findsWidgets);
    expect(find.text('Founders Day'), findsWidgets);
    expect(find.text('Christmas vacation'), findsWidgets);
    expect(find.text('Holiday'), findsWidgets);
    expect(find.text('Vacation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar events open and crowded days show a more control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final events = [
      SchoolEvent(
        id: 'event-1',
        startDate: DateTime(2099, 10, 4),
        endDate: DateTime(2099, 10, 4),
        title: 'Founders Day',
        category: 'HOLIDAY',
        description: 'School is closed for the public holiday.',
        isSchoolDay: false,
      ),
      SchoolEvent(
        id: 'event-2',
        startDate: DateTime(2099, 10, 4),
        endDate: DateTime(2099, 10, 4),
        title: 'Staff planning',
        category: 'MEETING',
      ),
      SchoolEvent(
        id: 'event-3',
        startDate: DateTime(2099, 10, 4),
        endDate: DateTime(2099, 10, 4),
        title: 'Fee reminder',
        category: 'PAYMENT',
      ),
      SchoolEvent(
        id: 'event-4',
        startDate: DateTime(2099, 10, 4),
        endDate: DateTime(2099, 10, 4),
        title: 'Late board meeting',
        category: 'MEETING',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: _EmptyDashboardRepository(calendarEvents: events),
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();

    final firstEvent = find.byKey(
      const ValueKey('calendar-event-2099-10-04-event-1'),
    );
    expect(firstEvent, findsOneWidget);
    await tester.tap(firstEvent);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-event-details')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-event-details')),
        matching: find.text('School is closed for the public holiday.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final more = find.byKey(const ValueKey('calendar-more-2099-10-04'));
    expect(more, findsOneWidget);
    expect(find.text('+2 more'), findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-day-events-2099-10-04')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-day-event-event-4')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('calendar-day-event-event-4')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('calendar-event-details')),
      findsOneWidget,
    );
    expect(find.text('Late board meeting'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hovering a calendar day adds an event for that date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _EmptyDashboardRepository(
      calendarEvents: [
        SchoolEvent(
          id: 'october-event',
          startDate: DateTime(2030, 10, 4),
          endDate: DateTime(2030, 10, 4),
          title: 'October event',
          category: 'EVENT',
        ),
      ],
      calendarEventTypes: const [
        CalendarEventType(id: 1, name: 'School Event'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: repository,
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();

    final day = find.byKey(const ValueKey('calendar-day-2030-10-03'));
    expect(day, findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('calendar-add-visibility-2030-10-03')),
          )
          .opacity,
      0,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(day));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('calendar-add-visibility-2030-10-03')),
          )
          .opacity,
      1,
    );
    final dayCell = find.ancestor(
      of: day,
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_CalendarDayCell',
      ),
    );
    final hoveredDay = tester.widget(dayCell) as dynamic;
    (hoveredDay.onAddEvent as VoidCallback).call();
    await tester.pumpAndSettle();

    expect(repository.calendarEventTypeRequests, 1);
    expect(find.text('Add calendar event'), findsOneWidget);
    expect(find.text('3 Oct 2030'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('event details offers confirmed deletion', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _EmptyDashboardRepository(
      calendarEvents: [
        SchoolEvent(
          id: 'delete-me',
          startDate: DateTime(2030, 10, 4),
          endDate: DateTime(2030, 10, 4),
          title: 'Founders Day',
          category: 'HOLIDAY',
          isSchoolDay: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: repository,
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calendar-event-2030-10-04-delete-me')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete event'), findsOneWidget);
    await tester.tap(find.text('Delete event'));
    await tester.pumpAndSettle();

    expect(find.text('Delete calendar event?'), findsOneWidget);
    expect(
      find.text('This will remove "Founders Day" from the school calendar.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedEventIds, ['delete-me']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hovering an occupied calendar day offers deletion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _EmptyDashboardRepository(
      calendarEvents: [
        SchoolEvent(
          id: 'hover-delete',
          startDate: DateTime(2030, 10, 4),
          endDate: DateTime(2030, 10, 4),
          title: 'Sports Day',
          category: 'SPORTS',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: repository,
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();

    final day = find.byKey(const ValueKey('calendar-day-2030-10-04'));
    final deleteVisibility = find.byKey(
      const ValueKey('calendar-delete-visibility-2030-10-04'),
    );
    expect(tester.widget<AnimatedOpacity>(deleteVisibility).opacity, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(day));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(deleteVisibility).opacity, 1);
    await tester.tap(find.byKey(const ValueKey('calendar-delete-2030-10-04')));
    await tester.pumpAndSettle();

    expect(find.text('Delete calendar event?'), findsOneWidget);
    expect(
      find.text('This will remove "Sports Day" from the school calendar.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedEventIds, ['hover-delete']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teaching staff have read-only school calendar access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EmptyDashboardRepository(
      calendarEvents: [
        SchoolEvent(
          id: 'read-only-event',
          startDate: DateTime(2030, 10, 4),
          endDate: DateTime(2030, 10, 4),
          title: 'Staff Meeting',
          category: 'MEETING',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: repository,
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Sena',
          role: 'SUBJECT_TEACHER',
          teacherDashboardLoader: () async => _teacherSummary,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('View only'), findsOneWidget);
    expect(find.text('Add Event'), findsNothing);
    expect(find.byTooltip('Edit event'), findsNothing);
    expect(find.byTooltip('Delete event'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('calendar-event-2030-10-04-read-only-event')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit event'), findsNothing);
    expect(find.text('Delete event'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event details show a concise change history', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _EmptyDashboardRepository(
      calendarEvents: [
        SchoolEvent(
          id: 'history-event',
          startDate: DateTime(2030, 10, 4),
          endDate: DateTime(2030, 10, 4),
          title: 'Open Day',
          category: 'EVENT',
        ),
      ],
      calendarEventChanges: [
        CalendarEventChange(
          action: 'UPDATED',
          actorName: 'Yaw Asante',
          actorRole: 'HEAD_TEACHER',
          summary: 'Changed dates',
          changedAt: DateTime(2030, 10, 1, 14, 30),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdministratorDashboard(
          repository: repository,
          schoolId: 'SCH-001',
          schoolName: 'Test School',
          userDisplayName: 'Eric',
          role: 'ADMINISTRATOR',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('School Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('calendar-event-2030-10-04-history-event')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 recorded change'), findsOneWidget);
    await tester.tap(find.text('Change history'));
    await tester.pumpAndSettle();
    expect(find.text('Changed dates'), findsOneWidget);
    expect(find.textContaining('Yaw Asante · Head Teacher'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoked active role returns user to an available workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget app(List<String> roles) => MaterialApp(
      theme: AppTheme.light,
      home: AdministratorDashboard(
        key: const ValueKey('role-aware-dashboard'),
        repository: _EmptyDashboardRepository(),
        schoolId: 'SCH-001',
        schoolName: 'Test School',
        userDisplayName: 'Adwoa Dual Role',
        role: 'CLASS_TEACHER',
        roles: roles,
        teacherDashboardLoader: () async => _teacherSummary,
      ),
    );

    await tester.pumpWidget(app(const ['CLASS_TEACHER', 'BURSAR']));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bursar').last);
    await tester.pumpAndSettle();
    expect(find.text('Expenses & Petty Cash'), findsOneWidget);

    await tester.pumpWidget(app(const ['CLASS_TEACHER']));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Classes assigned'), findsOneWidget);
    expect(find.text('My Requisitions & Expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reviewer navigation opens distinct personal and management pages',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _EmptyDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test school',
            role: 'ADMINISTRATOR',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Leave'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LeaveManagementScreen>(find.byType(LeaveManagementScreen))
            .myLeave,
        isTrue,
      );
      await tester.tap(find.text('Leave Management'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LeaveManagementScreen>(find.byType(LeaveManagementScreen))
            .myLeave,
        isFalse,
      );
    },
  );

  for (final role in [
    'HEAD_TEACHER',
    'HEADMASTER',
    'ADMIN',
    'SUBJECT_TEACHER',
    'ASSISTANT_HEAD_TEACHER',
    'SECRETARY',
    'STAFF',
    'OWNER',
  ]) {
    testWidgets('$role has the correct personal and management leave menus', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdministratorDashboard(
            repository: _EmptyDashboardRepository(),
            schoolId: 'SCH-001',
            schoolName: 'Test school',
            role: role,
            teacherDashboardLoader: role == 'SUBJECT_TEACHER'
                ? () async => _teacherSummary
                : null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My Leave'), findsOneWidget);
      expect(
        find.text('Leave Management'),
        [
              'HEAD_TEACHER',
              'HEADMASTER',
              'ADMIN',
              'ASSISTANT_HEAD_TEACHER',
              'SECRETARY',
              'OWNER',
            ].contains(role)
            ? findsOneWidget
            : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

const _teacherSummary = TeacherDashboardSummary(
  workspace: TeacherWorkspaceSnapshot(
    role: 'CLASS_TEACHER',
    assignedStudents: 24,
    classes: [
      TeacherClassAssignment(
        gradeLevelId: 11,
        gradeName: 'Basic 1',
        streamName: 'Section 1',
        streamId: 101,
        primary: true,
        studentCount: 24,
      ),
    ],
    subjects: [],
  ),
  attendance: TeacherAttendanceSummary(
    schoolDay: true,
    assignedClasses: 1,
    submittedClasses: 0,
    calendarMessage: '',
  ),
  assessments: TeacherAssessmentSummary(
    totalAssessments: 5,
    incompleteAssessments: 2,
    outstandingScores: 12,
  ),
  lateConcerns: [],
  upcomingLeave: [],
  myIncidents: [],
);

const _subjectTeacherSummary = TeacherDashboardSummary(
  workspace: TeacherWorkspaceSnapshot(
    role: 'SUBJECT_TEACHER',
    assignedStudents: 24,
    classes: [],
    subjects: [
      TeacherSubjectAssignment(
        gradeLevelId: 11,
        gradeName: 'Basic 1',
        streamId: 101,
        streamName: 'Section 1',
        subjectId: 7,
        subjectName: 'Mathematics',
      ),
    ],
  ),
  attendance: TeacherAttendanceSummary(
    schoolDay: true,
    assignedClasses: 0,
    submittedClasses: 0,
    calendarMessage: '',
  ),
  assessments: TeacherAssessmentSummary(
    totalAssessments: 2,
    incompleteAssessments: 1,
    outstandingScores: 4,
  ),
  lateConcerns: [],
  upcomingLeave: [],
  myIncidents: [],
);

const _unassignedTeacherSummary = TeacherDashboardSummary(
  workspace: TeacherWorkspaceSnapshot(
    role: 'CLASS_TEACHER',
    assignedStudents: 0,
    classes: [],
    subjects: [],
  ),
  attendance: TeacherAttendanceSummary(
    schoolDay: true,
    assignedClasses: 0,
    submittedClasses: 0,
    calendarMessage: '',
  ),
  assessments: TeacherAssessmentSummary(
    totalAssessments: 0,
    incompleteAssessments: 0,
    outstandingScores: 0,
  ),
  lateConcerns: [],
  upcomingLeave: [],
  myIncidents: [],
);

class _ForbiddenDashboardRepository extends _EmptyDashboardRepository {
  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) {
    throw Exception('Forbidden');
  }
}

class _EmptyDashboardRepository implements DashboardRepository {
  _EmptyDashboardRepository({
    this.alerts = const [],
    this.calendarEvents = const [],
    this.calendarEventTypes = const [],
    this.calendarEventChanges = const [],
    this.attendance = const AttendanceSummary(
      total: 0,
      present: 0,
      absent: 0,
      late: 0,
    ),
  });

  final List<SchoolAlert> alerts;
  final List<SchoolEvent> calendarEvents;
  final List<CalendarEventType> calendarEventTypes;
  final List<CalendarEventChange> calendarEventChanges;
  final AttendanceSummary attendance;
  int calendarEventTypeRequests = 0;
  final List<String> deletedEventIds = [];

  @override
  Future<DashboardSnapshot> getAdministratorDashboard(String schoolId) async {
    return DashboardSnapshot(
      schoolName: 'Test School',
      administratorName: 'Eric',
      term: 'Second Term',
      academicTermId: 1,
      academicYear: '2026-2027',
      termStartDate: '1 Jul 2026',
      termEndDate: '31 Jul 2026',
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
      alerts: alerts,
      events: const [],
      calendarEvents: calendarEvents,
      activities: const [],
      attendance: attendance,
      fees: const FeeSummary(collected: 0, outstanding: 0, waivers: 0),
    );
  }

  @override
  Future<List<CalendarEventType>> getCalendarEventTypes() async {
    calendarEventTypeRequests += 1;
    return calendarEventTypes;
  }

  @override
  Future<List<CalendarEventChange>> getCalendarEventHistory({
    required String schoolId,
    required String eventId,
  }) async => calendarEventChanges;

  @override
  Future<SchoolEvent> createCalendarEvent({
    required String schoolId,
    required CalendarEventPayload event,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SchoolEvent> updateCalendarEvent({
    required String schoolId,
    required String eventId,
    required CalendarEventPayload event,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCalendarEvent({
    required String schoolId,
    required String eventId,
  }) async {
    deletedEventIds.add(eventId);
  }
}
