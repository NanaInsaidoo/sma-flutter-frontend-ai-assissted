import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/leave/data/leave_api_client.dart';
import 'package:school_management_app/src/leave/presentation/leave_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

class _PersonalFixture {
  bool reviewer = true;
  final lists = <Map<String, String>>[];
  final balances = <String>[];
  final saves = <Map<String, dynamic>>[];
  Map<String, dynamic> row(int id) => {
    'id': id,
    'staffUserId': id,
    'requesterId': id,
    'version': 0,
    'staffName': id == 7 ? 'My Employee' : 'Other Employee',
    'typeName': 'Annual leave',
    'typeCode': 'ANNUAL',
    'startDate': '2027-01-04',
    'endDate': '2027-01-06',
    'days': 3,
    'status': 'PENDING_APPROVAL',
    'createdAt': '2027-01-01T09:00:00',
    'canReview': reviewer && id != 7,
    'canWithdraw': id == 7,
    'canCancel': false,
    'reason': 'Family plans',
    'events': [],
  };
  late final api = LeaveApiClient(
    schoolId: 'SCH',
    client: MockClient((request) async {
      final path = request.url.path;
      Object response;
      if (path.endsWith('/context')) {
        response = {
          'currentUserId': 7,
          'canReview': reviewer,
          'staff': [
            {'id': 7, 'name': 'My Employee'},
            if (reviewer) {'id': 8, 'name': 'Other Employee'},
          ],
          'types': [
            {'code': 'ANNUAL', 'name': 'Annual leave'},
          ],
        };
      } else if (path.endsWith('/balances')) {
        balances.add(path);
        response = [
          {
            'typeName': 'Annual leave',
            'allowance': 20,
            'available': 17,
            'approvedDays': 0,
            'pendingDays': 3,
          },
        ];
      } else if (path.endsWith('/leave') && request.method == 'GET') {
        final query = request.url.queryParameters;
        lists.add(query);
        final selected = query['staffUserId'];
        final items = [
          if (selected == null || selected == '7') row(7),
          if (selected == null || selected == '8') row(8),
        ];
        response = {
          'items': items,
          'total': items.length,
          'counts': {'PENDING_APPROVAL': items.length},
        };
      } else if (path.endsWith('/leave') && request.method == 'POST') {
        final body = Map<String, dynamic>.from(jsonDecode(request.body));
        saves.add(body);
        response = {...row(7), ...body, 'status': 'DRAFT'};
      } else if (path.endsWith('/leave/7')) {
        response = row(7);
      } else {
        return http.Response('Unexpected request $path', 404);
      }
      return http.Response(jsonEncode(response), 200);
    }),
  );
}

Future<void> _show(
  WidgetTester tester,
  _PersonalFixture f, {
  bool personal = true,
  bool embedded = false,
  int? staffId,
  double width = 1400,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: LeaveManagementScreen(
          api: f.api,
          myLeave: personal,
          embedded: embedded,
          staffUserId: staffId,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final reviewer in [true, false]) {
    testWidgets(
      'My Leave is own-only for reviewer=$reviewer and stays scoped after sorting',
      (tester) async {
        final f = _PersonalFixture()..reviewer = reviewer;
        await _show(tester, f, width: reviewer ? 1400 : 390);
        expect(find.text('My Leave'), findsOneWidget);
        expect(find.text('My requests'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        expect(find.text('My Employee'), findsOneWidget);
        expect(find.text('Other Employee'), findsNothing);
        expect(f.lists.single['staffUserId'], '7');
        expect(f.balances.single, endsWith('/staff/7/balances'));
        final header = find.byKey(const ValueKey('leave-sort-startDate'));
        await tester.ensureVisible(header);
        await tester.tap(header);
        await tester.pumpAndSettle();
        expect(f.lists.last['staffUserId'], '7');
        await tester.ensureVisible(
          find.byKey(const ValueKey('leave-status-PENDING_APPROVAL')),
        );
        await tester.tap(
          find.byKey(const ValueKey('leave-status-PENDING_APPROVAL')),
        );
        await tester.pumpAndSettle();
        expect(f.lists.last['staffUserId'], '7');
        expect(f.lists.last['status'], 'PENDING_APPROVAL');
        final row = find.byKey(const ValueKey('leave-request-7'));
        await tester.ensureVisible(row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('Withdraw request'), findsOneWidget);
        expect(find.text('Approve'), findsNothing);
        expect(find.text('Reject'), findsNothing);
      },
    );
  }

  testWidgets(
    'administrator personal form is locked to self and saves for self',
    (tester) async {
      final f = _PersonalFixture();
      await _show(tester, f);
      await tester.tap(find.text('Request leave'));
      await tester.pumpAndSettle();
      final locked = tester.widget<TextFormField>(
        find.byKey(const ValueKey('leave-request-locked-staff')),
      );
      expect(locked.initialValue, 'My Employee');
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.text('Other Employee'), findsNothing);
      final type = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annual leave').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('leave-notes')),
        'Personal leave',
      );
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(f.saves.single['staffUserId'], 7);
    },
  );

  testWidgets(
    'management remains school-wide with staff filter and on-behalf form',
    (tester) async {
      final f = _PersonalFixture();
      await _show(tester, f, personal: false);
      expect(f.lists.single.containsKey('staffUserId'), isFalse);
      expect(find.text('Leave Management'), findsOneWidget);
      expect(find.text('Other Employee'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      await tester.tap(find.text('Request leave'));
      await tester.pumpAndSettle();
      final staff = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<int>),
      );
      expect(
        tester.widget<DropdownButtonFormField<int>>(staff).onChanged,
        isNotNull,
      );
      expect(
        find.byKey(const ValueKey('leave-request-locked-staff')),
        findsNothing,
      );
    },
  );

  testWidgets('ordinary employee cannot open management directly', (
    tester,
  ) async {
    final f = _PersonalFixture()..reviewer = false;
    await _show(tester, f, personal: false);
    expect(find.textContaining('Open My Leave'), findsOneWidget);
    expect(f.lists, isEmpty);
    expect(f.balances, isEmpty);
    expect(find.text('Request leave'), findsNothing);
  });

  testWidgets(
    'management refresh clears school-wide records when review access is revoked',
    (tester) async {
      final f = _PersonalFixture();
      await _show(tester, f, personal: false);
      expect(find.text('Other Employee'), findsOneWidget);
      f.reviewer = false;
      await tester.tap(find.byTooltip('Refresh leave'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Open My Leave'), findsOneWidget);
      expect(find.text('Other Employee'), findsNothing);
      expect(f.lists.length, 1);
    },
  );

  testWidgets(
    'switching from management to personal discards school-wide scope',
    (tester) async {
      final f = _PersonalFixture();
      await _show(tester, f, personal: false);
      expect(find.text('Other Employee'), findsOneWidget);
      await _show(tester, f, personal: true);
      expect(find.text('Other Employee'), findsNothing);
      expect(f.lists.last['staffUserId'], '7');
    },
  );

  testWidgets('staff profile history keeps the selected staff scope', (
    tester,
  ) async {
    final f = _PersonalFixture();
    await _show(tester, f, personal: false, embedded: true, staffId: 8);
    expect(find.text('Leave history'), findsOneWidget);
    expect(f.lists.single['staffUserId'], '8');
    expect(f.balances.single, endsWith('/staff/8/balances'));
  });
}
