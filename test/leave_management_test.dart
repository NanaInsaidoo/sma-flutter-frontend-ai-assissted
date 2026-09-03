import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/leave/data/leave_api_client.dart';
import 'package:school_management_app/src/leave/presentation/leave_management_screen.dart';
import 'package:school_management_app/src/staff_attendance/data/staff_attendance_api_client.dart';
import 'package:school_management_app/src/staff_attendance/domain/staff_attendance_models.dart';

class _LeaveApi extends LeaveApiClient {
  _LeaveApi({
    this.reviewer = true,
    this.empty = false,
    this.fail = false,
    this.editable = false,
  }) : super(schoolId: 'SCH');
  bool reviewer, empty, fail, editable;
  final actions = <String>[];
  final changeRequests = <LeaveJson>[];
  LeaveJson row = {
    'id': 10,
    'version': 3,
    'staffUserId': 1,
    'requesterId': 1,
    'staffName': 'Ama Teacher',
    'typeCode': 'ANNUAL',
    'typeName': 'Annual leave',
    'startDate': '2027-01-04',
    'endDate': '2027-01-06',
    'days': 3,
    'status': 'PENDING_APPROVAL',
    'canReview': true,
    'canEdit': false,
    'canCancel': true,
    'reason': 'Family plans',
    'notes': '',
    'events': [],
  };
  @override
  Future<LeaveJson> context() async {
    if (fail) throw LeaveApiException('Connection unavailable');
    return {
      'currentUserId': reviewer ? 2 : 1,
      'canReview': reviewer,
      'staff': [
        {'id': 1, 'name': 'Ama Teacher'},
        if (reviewer) {'id': 2, 'name': 'Head Teacher'},
      ],
      'types': [
        {'code': 'ANNUAL', 'name': 'Annual leave'},
        {'code': 'SICK', 'name': 'Sick leave'},
      ],
    };
  }

  @override
  Future<LeaveJson> list({
    int? staffId,
    String? status,
    String? from,
    String? to,
    int page = 0,
    int size = 25,
    String sortBy = 'createdAt',
    String direction = 'desc',
  }) async => {
    'items': empty
        ? []
        : [
            {
              ...row,
              'canReview': row['canReview'] == true && reviewer && !editable,
              'canEdit': editable || row['canEdit'] == true,
              'status': editable ? 'DRAFT' : row['status'],
            },
          ],
    'counts': {
      'PENDING_APPROVAL': empty ? 0 : 1,
      'APPROVED': 0,
      'REJECTED': 0,
      'ON_LEAVE': 0,
    },
    'total': empty ? 0 : 1,
  };
  @override
  Future<List<LeaveJson>> balances(int staffId, int year) async => [
    {
      'typeName': 'Annual leave',
      'allowance': null,
      'available': null,
      'approvedDays': 0,
      'takenDays': 0,
      'scheduledDays': 0,
      'pendingDays': 3,
    },
  ];
  @override
  Future<LeaveJson> detail(int id) async => {
    ...row,
    'canReview': row['canReview'] == true && reviewer && !editable,
    'canEdit': editable || row['canEdit'] == true,
    'status': editable ? 'DRAFT' : row['status'],
  };
  @override
  Future<LeaveJson> action(
    LeaveJson request,
    String action,
    String comment,
  ) async {
    actions.add(action);
    final changePending = row['changeStatus'] == 'PENDING_APPROVAL';
    row = {
      ...row,
      'status': changePending
          ? row['status']
          : action == 'APPROVE'
          ? 'APPROVED'
          : action == 'REJECT'
          ? 'REJECTED'
          : action == 'REVOKE'
          ? 'CANCELLED'
          : 'PENDING_APPROVAL',
      if (changePending)
        'changeStatus': action == 'APPROVE' ? 'APPROVED' : 'REJECTED',
      if (changePending && action == 'APPROVE')
        'actualEndDate': row['proposedActualEndDate'],
      if (changePending && action == 'APPROVE') 'days': 5,
      'canReview': false,
      if (!changePending && action == 'APPROVE') 'canRevoke': true,
      'version': 4,
    };
    return row;
  }

  @override
  Future<LeaveJson> requestChange(
    LeaveJson request, {
    required String type,
    DateTime? actualEndDate,
    required String reason,
  }) async {
    changeRequests.add({
      'type': type,
      'actualEndDate': actualEndDate?.toIso8601String().split('T').first,
      'reason': reason,
    });
    row = {
      ...row,
      'changeType': type,
      'changeStatus': 'PENDING_APPROVAL',
      'proposedActualEndDate': actualEndDate
          ?.toIso8601String()
          .split('T')
          .first,
      'changeReason': reason,
      'canRequestEarlyReturn': false,
      'canCorrectMistake': false,
      'canWithdraw': true,
      'version': 4,
    };
    return row;
  }

  @override
  Future<LeaveJson> save(LeaveJson body, {int? id}) async {
    final reopening = const {
      'PENDING_APPROVAL',
      'APPROVED',
    }.contains(row['status']);
    row = {
      ...row,
      ...body,
      if (reopening) 'status': 'DRAFT',
      'id': id ?? 10,
      'version': 4,
    };
    return row;
  }
}

Future<void> _screen(WidgetTester tester, _LeaveApi api) async {
  tester.view.physicalSize = const Size(1300, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LeaveManagementScreen(api: api, myLeave: !api.reviewer),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  final row = find.byKey(const ValueKey('leave-request-10'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dashboard shows real empty state and unconfigured balances', (
    tester,
  ) async {
    await _screen(tester, _LeaveApi(empty: true));
    expect(find.text('Leave Management'), findsOneWidget);
    expect(find.textContaining('No leave requests found'), findsOneWidget);
    await tester.tap(find.textContaining('My leave balances'));
    await tester.pumpAndSettle();
    expect(find.text('Not configured'), findsOneWidget);
    expect(find.text('Set allowance'), findsNothing);
  });
  testWidgets('loading error has a working retry', (tester) async {
    final api = _LeaveApi(fail: true);
    await _screen(tester, api);
    expect(find.text('Connection unavailable'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ama Teacher'), findsOneWidget);
  });
  testWidgets('reviewer approves without entering a comment', (tester) async {
    final api = _LeaveApi();
    await _screen(tester, api);
    await _open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();
    expect(api.actions, ['APPROVE']);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Approved'),
      ),
      findsOneWidget,
    );
    expect(find.text('Revoke approval'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await _open(tester);
    expect(find.text('Revoke approval'), findsOneWidget);
  });
  testWidgets('rejection asks for a reason only after Reject is clicked', (
    tester,
  ) async {
    final api = _LeaveApi();
    await _screen(tester, api);
    await _open(tester);
    expect(find.text('Decision comment'), findsNothing);
    expect(find.text('Request changes'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(api.actions, isEmpty);
    expect(find.text('Rejection reason'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a reason'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('leave-reject-reason')),
      'Staff coverage is unavailable',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(api.actions, ['REJECT']);
  });
  testWidgets('requester cannot see review controls', (tester) async {
    await _screen(tester, _LeaveApi(reviewer: false));
    await _open(tester);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Request changes'), findsNothing);
  });
  testWidgets('employee requests an early return with the actual last day', (
    tester,
  ) async {
    final api = _LeaveApi(reviewer: false);
    api.row = {
      ...api.row,
      'status': 'APPROVED',
      'startDate': '2026-08-27',
      'endDate': '2026-09-04',
      'days': 9,
      'requestedDays': 9,
      'canReview': false,
      'canCancel': false,
      'canRequestEarlyReturn': true,
      'canCorrectMistake': false,
    };
    await _screen(tester, api);
    await _open(tester);

    await tester.tap(find.text('Request early return'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Actual last day:'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('leave-change-reason')),
      'Returned to work earlier than planned',
    );
    await tester.tap(find.byKey(const ValueKey('submit-leave-change')));
    await tester.pumpAndSettle();

    expect(api.changeRequests.single['type'], 'EARLY_RETURN');
    expect(api.changeRequests.single['actualEndDate'], isNotNull);
    expect(find.text('Early return pending approval'), findsOneWidget);
  });

  testWidgets(
    'another approver revokes approved leave with an audited reason',
    (tester) async {
      final api = _LeaveApi();
      api.row = {
        ...api.row,
        'status': 'APPROVED',
        'canReview': false,
        'canCancel': false,
        'canRevoke': true,
        'canRequestEarlyReturn': false,
        'canCorrectMistake': true,
      };
      await _screen(tester, api);
      await _open(tester);

      expect(find.text('Correct mistaken leave'), findsNothing);
      expect(find.text('Request cancellation'), findsNothing);
      expect(find.text('Revoke approval'), findsOneWidget);
      await tester.tap(find.text('Revoke approval'));
      await tester.pumpAndSettle();
      expect(find.text('Reason for revoking approval'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('leave-revoke-reason')),
        'The approved leave is no longer valid',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(api.actions, ['REVOKE']);
      expect(api.row['status'], 'CANCELLED');
    },
  );

  testWidgets('requester edits future approved leave and resubmits it', (
    tester,
  ) async {
    final api = _LeaveApi(reviewer: false);
    api.row = {
      ...api.row,
      'status': 'APPROVED',
      'canReview': false,
      'canEdit': true,
      'canRevoke': false,
      'canRequestEarlyReturn': false,
      'canCorrectMistake': true,
    };
    await _screen(tester, api);
    await _open(tester);

    expect(find.text('Correct mistaken leave'), findsNothing);
    expect(find.text('Change leave'), findsOneWidget);
    await tester.tap(find.text('Change leave'));
    await tester.pumpAndSettle();
    expect(find.text('Change leave'), findsWidgets);
    expect(find.text('Save draft'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('leave-notes')),
      'Updated leave dates and notes',
    );
    await tester.tap(find.text('Submit changes for approval'));
    await tester.pumpAndSettle();

    expect(api.actions, ['SUBMIT']);
    expect(api.row['status'], 'PENDING_APPROVAL');
    expect(find.text('Change leave'), findsNothing);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await _open(tester);
    expect(find.text('Change leave'), findsOneWidget);
  });

  testWidgets('reviewer approves an early return and sees the actual leave', (
    tester,
  ) async {
    final api = _LeaveApi();
    api.row = {
      ...api.row,
      'status': 'APPROVED',
      'startDate': '2026-08-27',
      'endDate': '2026-09-04',
      'requestedDays': 9,
      'days': 9,
      'changeType': 'EARLY_RETURN',
      'changeStatus': 'PENDING_APPROVAL',
      'proposedActualEndDate': '2026-08-31',
      'changeReason': 'Returned to work',
      'canReview': true,
      'canCancel': false,
      'canRequestEarlyReturn': false,
      'canCorrectMistake': false,
    };
    await _screen(tester, api);
    await _open(tester);

    expect(find.text('Early return pending approval'), findsOneWidget);
    expect(find.text('Request changes'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(api.actions, ['APPROVE']);
    expect(
      find.text('Actual leave: 27 Aug 2026 – 31 Aug 2026 · 5 days taken'),
      findsOneWidget,
    );
  });
  testWidgets(
    'existing draft opens populated and can be edited and submitted',
    (tester) async {
      final api = _LeaveApi(reviewer: false, editable: true);
      await _screen(tester, api);
      await _open(tester);
      await tester.tap(find.text('Edit request'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text('4 Jan 2027'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text('6 Jan 2027'),
        ),
        findsOneWidget,
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'Updated family plans');
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(api.row['reason'], '');
      expect(api.row['notes'], 'Updated family plans');
      expect(api.row['startDate'], '2027-01-04');
      expect(api.row['endDate'], '2027-01-06');
      expect(api.actions, ['SUBMIT']);
    },
  );
  testWidgets(
    'new form requires leave type and notes and supports optional attachment',
    (tester) async {
      await _screen(tester, _LeaveApi(reviewer: false, empty: true));
      await tester.tap(find.text('Request leave'));
      await tester.pumpAndSettle();
      expect(find.text('Add supporting document'), findsOneWidget);
      expect(find.textContaining('Optional · PDF'), findsOneWidget);
      await tester.tap(find.text('Submit request'));
      await tester.pumpAndSettle();
      expect(find.text('Select a leave type'), findsOneWidget);
      expect(find.text('Enter notes'), findsOneWidget);
    },
  );
  test(
    'API sends scoped actions with version and refreshes expired authentication',
    () async {
      var attempts = 0;
      final api = LeaveApiClient(
        schoolId: 'SCH',
        accessToken: 'expired',
        onRefreshAccessToken: () async => 'renewed',
        client: MockClient((r) async {
          attempts++;
          if (attempts == 1) return http.Response('{}', 401);
          expect(r.headers['Authorization'], 'Bearer renewed');
          expect(r.url.path.endsWith('/schools/SCH/leave/10/actions'), true);
          expect(jsonDecode(r.body), {
            'action': 'APPROVE',
            'comment': '',
            'version': 3,
          });
          return http.Response('{"status":"APPROVED"}', 200);
        }),
      );
      expect(
        (await api.action({'id': 10, 'version': 3}, 'APPROVE', ''))['status'],
        'APPROVED',
      );
      expect(attempts, 2);
    },
  );
  test(
    'API sends a versioned early-return request with its actual end date',
    () async {
      final api = LeaveApiClient(
        schoolId: 'SCH',
        client: MockClient((request) async {
          expect(
            request.url.path,
            endsWith('/schools/SCH/leave/10/change-requests'),
          );
          expect(jsonDecode(request.body), {
            'type': 'EARLY_RETURN',
            'actualEndDate': '2026-08-31',
            'reason': 'Returned early',
            'version': 3,
          });
          return http.Response(
            '{"id":10,"changeStatus":"PENDING_APPROVAL"}',
            200,
          );
        }),
      );
      final result = await api.requestChange(
        {'id': 10, 'version': 3},
        type: 'EARLY_RETURN',
        actualEndDate: DateTime(2026, 8, 31),
        reason: 'Returned early',
      );
      expect(result['changeStatus'], 'PENDING_APPROVAL');
    },
  );
  test('multipart attachment retains MIME name bytes and version', () async {
    final api = LeaveApiClient(
      schoolId: 'SCH',
      client: MockClient((r) async {
        expect(r.headers['content-type'], contains('multipart/form-data'));
        expect(r.body, contains('name="version"'));
        expect(r.body, contains('filename="note.pdf"'));
        expect(r.body, contains('application/pdf'));
        expect(r.body, contains('%PDF-test'));
        return http.Response('{"id":10,"version":4}', 200);
      }),
    );
    expect(
      (await api.attach(
        {'id': 10, 'version': 3},
        'note.pdf',
        Uint8List.fromList(utf8.encode('%PDF-test')),
      ))['version'],
      4,
    );
  });
  test(
    'attendance overlays leave availability without inventing or overwriting attendance',
    () async {
      final api = StaffAttendanceApiClient(
        accessToken: 'test',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('/availability')
                  ? [
                      {'staffUserId': 1, 'endDate': '2027-01-06'},
                      {'staffUserId': 2, 'endDate': '2027-01-07'},
                    ]
                  : [
                      {
                        'id': 20,
                        'staffId': '1',
                        'status': 'PRESENT',
                        'registerStatus': 'SUBMITTED',
                      },
                    ],
            ),
            200,
          ),
        ),
      );
      final entries = await api.getDailyRegister(
        schoolId: 'SCH',
        date: DateTime(2027, 1, 4),
        people: [
          const StaffAttendancePerson(id: '1', name: 'One', role: 'Teacher'),
          const StaffAttendancePerson(id: '2', name: 'Two', role: 'Teacher'),
        ],
      );
      expect(entries.first.mark, StaffAttendanceMark.present);
      expect(entries.first.approvedLeaveEndDate, '2027-01-06');
      expect(entries.last.mark, StaffAttendanceMark.unmarked);
      expect(
        entries.last.copyWith(note: 'review').approvedLeaveEndDate,
        '2027-01-07',
      );
    },
  );
}
