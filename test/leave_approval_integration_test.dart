import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/approvals/data/approval_api_client.dart';
import 'package:school_management_app/src/approvals/presentation/approvals_screen.dart';
import 'package:school_management_app/src/leave/data/leave_api_client.dart';
import 'package:school_management_app/src/leave/presentation/leave_date_format.dart';
import 'package:school_management_app/src/leave/presentation/leave_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

class _Fixture {
  bool requester = false, conflict = false, legacyCancel = false;
  String status = 'PENDING_APPROVAL';
  int version = 2, inboxReads = 0, detailReads = 0;
  int total = 1;
  final listQueries = <Map<String, String>>[];
  final actions = <Map<String, dynamic>>[];
  final filters = <String?>[];
  Map<String, dynamic> get detail => {
    'id': 42,
    'version': version,
    'staffUserId': 11,
    'requesterId': 11,
    'staffName': 'Ama Teacher',
    'typeName': 'Annual leave',
    'typeCode': 'ANNUAL',
    'startDate': '2027-01-04',
    'endDate': '2027-01-06',
    'days': 3,
    'createdAt': '2027-01-01T09:00:00',
    'reason': 'Family commitment',
    'notes': 'Lesson coverage arranged',
    'attachmentName': 'support.pdf',
    'status': status,
    'canReview': !requester && status == 'PENDING_APPROVAL',
    'canEdit': false,
    'canCancel': legacyCancel,
    'canWithdraw': requester && status == 'PENDING_APPROVAL',
    'reviewComment': actions.isEmpty ? '' : actions.last['comment'],
    'events': [
      {
        'action': status == 'PENDING_APPROVAL' ? 'SUBMIT' : status,
        'actorName': 'Head Teacher',
        'occurredAt': '2027-01-01T09:00:00',
        'comment': actions.isEmpty ? '' : actions.last['comment'],
        'snapshot': jsonEncode({
          'startDate': [2027, 1, 4],
          'endDate': '2027-01-06',
        }),
      },
    ],
  };
  late final client = MockClient((request) async {
    final path = request.url.path;
    Object response;
    if (path.endsWith('/approvals')) {
      inboxReads++;
      final item = {
        'key': 'STAFF_LEAVE:42',
        'type': 'STAFF_LEAVE',
        'entityId': 42,
        'category': 'Staff leave',
        'title': 'Leave · Ama Teacher',
        'subtitle': '2027-01-04 – 2027-01-06',
        'status': status,
        'requesterName': 'Ama Teacher',
        'approverName': 'Head Teacher',
        'sourcePage': 'leave',
        'stateToken': 'leave:$version',
        'canApprove': !requester && status == 'PENDING_APPROVAL',
        'canReject': !requester && status == 'PENDING_APPROVAL',
        'canWithdraw': false,
      };
      response = {
        'myApprovals': requester ? [] : [item],
        'myRequests': requester ? [item] : [],
        'pendingMyApproval': !requester && status == 'PENDING_APPROVAL' ? 1 : 0,
        'pendingMyRequests': requester && status == 'PENDING_APPROVAL' ? 1 : 0,
      };
    } else if (path.endsWith('/leave/context')) {
      response = {
        'currentUserId': requester ? 11 : 22,
        'canReview': !requester,
        'staff': [
          {'id': 11, 'name': 'Ama Teacher'},
          {'id': 22, 'name': 'Head Teacher'},
        ],
        'types': [
          {'code': 'ANNUAL', 'name': 'Annual leave'},
        ],
      };
    } else if (path.endsWith('/leave/42/actions')) {
      final body = Map<String, dynamic>.from(jsonDecode(request.body));
      actions.add(body);
      if (conflict) {
        status = 'APPROVED';
        version++;
        return http.Response(
          jsonEncode({
            'message': 'This request has changed. Refresh before continuing',
          }),
          409,
        );
      }
      expect(body['version'], version);
      status = switch (body['action']) {
        'APPROVE' => 'APPROVED',
        'REJECT' => 'REJECTED',
        'WITHDRAW' => 'CANCELLED',
        _ => 'NEEDS_REVISION',
      };
      version++;
      response = detail;
    } else if (path.endsWith('/leave/42')) {
      detailReads++;
      response = detail;
    } else if (path.endsWith('/balances')) {
      response = [];
    } else if (path.endsWith('/leave')) {
      listQueries.add(request.url.queryParameters);
      filters.add(request.url.queryParameters['status']);
      final filter = filters.last;
      response = {
        'items': filter == null || filter == status ? [detail] : [],
        'total': filter == null || filter == status ? total : 0,
        'counts': {for (final s in leaveStatuses) s: s == status ? 1 : 0},
      };
    } else {
      return http.Response('Unexpected request: $path', 404);
    }
    return http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  LeaveApiClient get leave =>
      LeaveApiClient(schoolId: 'SCH', accessToken: 'test', client: client);
  ApprovalApiClient get approval =>
      ApprovalApiClient(accessToken: 'test', client: client);
}

Future<void> _show(
  WidgetTester tester,
  Widget child, {
  double width = 1200,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'real Spring date arrays are normalized for display editing and audit history',
    () async {
      final api = LeaveApiClient(
        schoolId: 'SCH',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'id': 42,
              'startDate': [2026, 8, 31],
              'endDate': [2026, 9, 24],
              'createdAt': [2026, 8, 31, 10, 5, 12, 123000000],
              'events': [
                {
                  'occurredAt': [2026, 8, 31, 11, 6, 13],
                  'snapshot': '{"startDate":"2026-08-31"}',
                },
              ],
            }),
            200,
          ),
        ),
      );
      final request = await api.detail(42);
      expect(request['startDate'], '2026-08-31');
      expect(request['endDate'], '2026-09-24');
      expect(DateTime.parse(request['createdAt']).millisecond, 123);
      expect(request['events'][0]['occurredAt'], '2026-08-31T11:06:13.000');
      expect(request['events'][0]['snapshot'], '{"startDate":"2026-08-31"}');
    },
  );
  testWidgets(
    'approval queue approves immediately without asking for a comment',
    (tester) async {
      final f = _Fixture();
      await _show(
        tester,
        ApprovalsScreen(
          schoolId: 'SCH',
          repository: f.approval,
          leaveApi: f.leave,
        ),
      );
      expect(find.text('4 Jan 2027 – 6 Jan 2027'), findsOneWidget);
      await tester.tap(find.text('Leave · Ama Teacher'));
      await tester.pumpAndSettle();
      expect(find.text('Leave request #42'), findsOneWidget);
      expect(find.text('Lesson coverage arranged'), findsOneWidget);
      expect(find.text('View support.pdf'), findsOneWidget);
      expect(find.text('Open source page'), findsNothing);
      expect(find.text('Decision comment'), findsNothing);
      expect(find.text('Request changes'), findsNothing);
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(f.actions.single['comment'], '');
      expect(f.inboxReads, greaterThan(1));
      expect(f.detailReads, 1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Leave · Ama Teacher'), findsOneWidget);
      await tester.tap(find.text('Leave · Ama Teacher'));
      await tester.pumpAndSettle();
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    },
  );
  testWidgets('approval queue asks for a reason after Reject is clicked', (
    tester,
  ) async {
    final f = _Fixture();
    await _show(
      tester,
      ApprovalsScreen(
        schoolId: 'SCH',
        repository: f.approval,
        leaveApi: f.leave,
      ),
    );
    await tester.tap(find.text('Leave · Ama Teacher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject').last);
    await tester.pumpAndSettle();
    expect(f.actions, isEmpty);
    expect(find.text('Rejection reason'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('leave-reject-reason')),
      'Staff coverage is unavailable',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(f.actions.single['action'], 'REJECT');
    expect(f.actions.single['comment'], 'Staff coverage is unavailable');
  });
  testWidgets('requester opens their requisition with no review permissions', (
    tester,
  ) async {
    final f = _Fixture()..requester = true;
    await _show(
      tester,
      ApprovalsScreen(
        schoolId: 'SCH',
        repository: f.approval,
        leaveApi: f.leave,
      ),
    );
    await tester.tap(find.text('My requests'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave · Ama Teacher'));
    await tester.pumpAndSettle();
    expect(find.text('Leave request #42'), findsOneWidget);
    expect(find.text('Lesson coverage arranged'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
    expect(find.text('Reject'), findsNothing);
    expect(f.actions, isEmpty);
  });
  testWidgets(
    'stale decision reloads current leave and removes obsolete review buttons',
    (tester) async {
      final f = _Fixture()..conflict = true;
      await _show(
        tester,
        ApprovalsScreen(
          schoolId: 'SCH',
          repository: f.approval,
          leaveApi: f.leave,
        ),
      );
      await tester.tap(find.text('Leave · Ama Teacher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(f.detailReads, 2);
      expect(
        find.textContaining('The latest request has been loaded'),
        findsOneWidget,
      );
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Approved'), findsWidgets);
    },
  );
  for (final width in [1200.0, 390.0]) {
    testWidgets(
      'leave dashboard shows every status and opens actionable details at $width',
      (tester) async {
        final f = _Fixture();
        await _show(tester, LeaveManagementScreen(api: f.leave), width: width);
        for (final s in leaveStatuses) {
          expect(find.byKey(ValueKey('leave-status-$s')), findsOneWidget);
        }
        final revised = find.byKey(
          const ValueKey('leave-status-NEEDS_REVISION'),
        );
        await tester.ensureVisible(revised);
        await tester.tap(revised);
        await tester.pumpAndSettle();
        expect(f.filters.last, 'NEEDS_REVISION');
        final pending = find.byKey(
          const ValueKey('leave-status-PENDING_APPROVAL'),
        );
        await tester.ensureVisible(pending);
        await tester.tap(pending);
        await tester.pumpAndSettle();
        expect(find.byType(DataTable), findsOneWidget);
        expect(find.text('4 Jan 2027'), findsOneWidget);
        expect(find.text('6 Jan 2027'), findsOneWidget);
        final row = find.byKey(const ValueKey('leave-request-42'));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('Leave request #42'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
        expect(
          find.text('4 Jan 2027 – 6 Jan 2027 · 3 calendar days'),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'pending approver has review actions but cannot cancel even with legacy flags',
    (tester) async {
      final f = _Fixture()..legacyCancel = true;
      await _show(tester, LeaveManagementScreen(api: f.leave));
      final row = find.byKey(const ValueKey('leave-request-42'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Request changes'), findsNothing);
      expect(find.text('Cancel request'), findsNothing);
      expect(find.text('Withdraw request'), findsNothing);
    },
  );
  testWidgets(
    'requester can withdraw pending leave with a reason from approvals',
    (tester) async {
      final f = _Fixture()..requester = true;
      await _show(
        tester,
        ApprovalsScreen(
          schoolId: 'SCH',
          repository: f.approval,
          leaveApi: f.leave,
        ),
      );
      await tester.tap(find.text('My requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave · Ama Teacher'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel request'), findsNothing);
      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();
      expect(find.text('Withdrawal reason'), findsOneWidget);
      expect(f.actions, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('leave-withdraw-reason')),
        'Leave no longer needed',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(f.actions.single['action'], 'WITHDRAW');
      expect(f.actions.single['comment'], 'Leave no longer needed');
      expect(find.text('Withdraw request'), findsNothing);
      expect(find.text('Cancelled'), findsWidgets);
      expect(f.inboxReads, greaterThan(1));
    },
  );
  testWidgets(
    'every table column sorts through the API and toggles direction',
    (tester) async {
      final f = _Fixture();
      await _show(tester, LeaveManagementScreen(api: f.leave));
      expect(f.listQueries.last['sortBy'], 'createdAt');
      expect(f.listQueries.last['direction'], 'desc');
      final fields = [
        'id',
        'staffName',
        'typeName',
        'startDate',
        'endDate',
        'days',
        'status',
        'createdAt',
      ];
      for (var i = 0; i < fields.length; i++) {
        final header = find.byKey(ValueKey('leave-sort-${fields[i]}'));
        await tester.ensureVisible(header);
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(f.listQueries.last['sortBy'], fields[i]);
        expect(f.listQueries.last['direction'], 'asc');
        expect(
          tester.widget<DataTable>(find.byType(DataTable)).sortColumnIndex,
          i,
        );
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(f.listQueries.last['direction'], 'desc');
      }
    },
  );
  testWidgets(
    'table sorting resets pagination and retains the selected status',
    (tester) async {
      final f = _Fixture()..total = 30;
      await _show(tester, LeaveManagementScreen(api: f.leave));
      await tester.tap(
        find.byKey(const ValueKey('leave-status-PENDING_APPROVAL')),
      );
      await tester.pumpAndSettle();
      final next = find.byTooltip('Next page');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(f.listQueries.last['page'], '1');
      final header = find.byKey(const ValueKey('leave-sort-days'));
      await tester.ensureVisible(header);
      await tester.tap(header);
      await tester.pumpAndSettle();
      expect(f.listQueries.last['page'], '0');
      expect(f.listQueries.last['status'], 'PENDING_APPROVAL');
      expect(f.listQueries.last['sortBy'], 'days');
    },
  );
  test('leave dates use month names and preserve calendar dates', () {
    expect(formatLeaveDate('2026-08-31'), '31 Aug 2026');
    expect(formatLeaveDate([2026, 9, 24]), '24 Sep 2026');
    expect(formatLeaveDate(DateTime(2026, 12, 31)), '31 Dec 2026');
    expect(formatLeaveDateTime([2026, 8, 31, 15, 6]), '31 Aug 2026 · 3:06 PM');
    expect(formatLeaveDateTime('2027-01-01T00:05:00'), '1 Jan 2027 · 12:05 AM');
    expect(formatLeaveDate(null), 'Not recorded');
    expect(formatLeaveDateTime('invalid'), 'Not recorded');
    expect(
      formatLeaveSummaryDates('Annual leave · 2026-12-31 – 2027-01-02'),
      'Annual leave · 31 Dec 2026 – 2 Jan 2027',
    );
  });
  testWidgets('leave history displays readable event and snapshot dates', (
    tester,
  ) async {
    final f = _Fixture();
    await _show(tester, LeaveManagementScreen(api: f.leave));
    final row = find.byKey(const ValueKey('leave-request-42'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity history'));
    await tester.pumpAndSettle();
    expect(find.text('1 Jan 2027 · 9:00 AM'), findsOneWidget);
    await tester.ensureVisible(find.text('submit · Head Teacher'));
    await tester.tap(find.text('submit · Head Teacher'));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 Jan 2027'), findsWidgets);
    expect(find.textContaining('[2027, 1, 4]'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'leave management summary includes draft revision and cancelled filters',
    (tester) async {
      final f = _Fixture();
      await _show(tester, LeaveManagementScreen(api: f.leave));
      for (final s in leaveStatuses) {
        expect(find.byKey(ValueKey('leave-status-$s')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('leave-status-CANCELLED')));
      await tester.pumpAndSettle();
      expect(f.filters.last, 'CANCELLED');
    },
  );
}
