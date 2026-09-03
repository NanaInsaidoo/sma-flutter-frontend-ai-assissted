import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/leave/data/leave_api_client.dart';
import 'package:school_management_app/src/leave/presentation/leave_calendar.dart';
import 'package:school_management_app/src/leave/presentation/leave_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

LeaveJson _row(
  int id, {
  String start = '2027-01-04',
  String end = '2027-01-06',
}) => {
  'id': id,
  'staffUserId': id,
  'requesterId': id,
  'staffName': 'Employee $id',
  'typeName': 'Annual leave',
  'typeCode': 'ANNUAL',
  'startDate': start,
  'endDate': end,
  'status': 'APPROVED',
  'days': 3,
  'createdAt': '2027-01-01T09:00:00',
  'version': 1,
};

Future<void> _show(
  WidgetTester tester,
  Widget widget, {
  double width = 1200,
}) async {
  tester.view.physicalSize = Size(width, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'month grid includes leap day and starts on Monday across year boundaries',
    () {
      final leap = leaveCalendarDays(DateTime(2028, 2));
      expect(leap.first.weekday, DateTime.monday);
      expect(leap.length % 7, 0);
      expect(leap.where((day) => day.month == 2).length, 29);
      expect(
        leaveCalendarDays(DateTime(2027, 1)).first,
        DateTime(2026, 12, 28),
      );
      expect(leaveCalendarDays(DateTime(2026, 8)).length, 42);
    },
  );
  test('leave spans both months and includes start and end days only', () {
    final rows = [_row(1, start: '2026-12-31', end: '2027-01-02')];
    expect(leavesOnDay(rows, DateTime(2026, 12, 31)), hasLength(1));
    expect(leavesOnDay(rows, DateTime(2027, 1, 1)), hasLength(1));
    expect(leavesOnDay(rows, DateTime(2027, 1, 2)), hasLength(1));
    expect(leavesOnDay(rows, DateTime(2027, 1, 3)), isEmpty);
    expect(leavesOnDay(rows, DateTime(2026, 12, 30)), isEmpty);
  });
  test('calendar stops an early-return leave on its actual end date', () {
    final row = {
      ..._row(1, start: '2026-08-27', end: '2026-09-04'),
      'actualEndDate': '2026-08-31',
    };
    expect(leavesOnDay([row], DateTime(2026, 8, 31)), hasLength(1));
    expect(leavesOnDay([row], DateTime(2026, 9, 1)), isEmpty);
  });
  test(
    'calendar fetches every page with month overlap and stable scoped sorting',
    () async {
      final queries = <Map<String, String>>[];
      final api = LeaveApiClient(
        schoolId: 'SCH',
        client: MockClient((r) async {
          final q = r.url.queryParameters;
          queries.add(q);
          final page = int.parse(q['page']!);
          return http.Response(
            jsonEncode({
              'items': List.generate(
                page == 0 ? 100 : 5,
                (i) => _row(page * 100 + i),
              ),
              'total': 105,
              'counts': {'APPROVED': 105},
            }),
            200,
          );
        }),
      );
      final result = await api.calendar(
        month: DateTime(2028, 2),
        staffId: 7,
        status: 'APPROVED',
      );
      expect(result['items'], hasLength(105));
      expect(queries, hasLength(2));
      for (final q in queries) {
        expect(q['from'], '2028-02-01');
        expect(q['to'], '2028-02-29');
        expect(q['staffUserId'], '7');
        expect(q['status'], 'APPROVED');
        expect(q['size'], '100');
        expect(q['sortBy'], 'id');
        expect(q['direction'], 'asc');
      }
    },
  );
  for (final emptyPage in [true, false]) {
    test(
      'calendar refuses an incomplete or duplicate page: empty=$emptyPage',
      () async {
        final api = LeaveApiClient(
          schoolId: 'SCH',
          client: MockClient((r) async {
            final first = r.url.queryParameters['page'] == '0';
            return http.Response(
              jsonEncode({
                'items': first || !emptyPage ? [_row(1)] : [],
                'total': 2,
                'counts': {},
              }),
              200,
            );
          }),
        );
        await expectLater(
          api.calendar(month: DateTime(2027, 1)),
          throwsA(isA<LeaveApiException>()),
        );
      },
    );
  }
  for (final width in [1200.0, 390.0]) {
    testWidgets(
      'calendar entries and busy-day overflow open every leave at $width',
      (tester) async {
        int? selected;
        await _show(
          tester,
          LeaveCalendar(
            month: DateTime(2027, 1),
            rows: List.generate(5, (i) => _row(i + 1)),
            onMonthChanged: (_) {},
            onOpen: (r) => selected = r['id'],
            statusLabel: leaveLabel,
          ),
          width: width,
        );
        expect(find.text('January 2027'), findsOneWidget);
        final event = find.byKey(
          const ValueKey('leave-calendar-event-2027-01-04-1'),
        );
        await tester.ensureVisible(event);
        await tester.tap(event);
        await tester.pumpAndSettle();
        expect(selected, 1);
        final more = find.byKey(
          const ValueKey('leave-calendar-more-2027-01-04'),
        );
        await tester.ensureVisible(more);
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(find.text('Leave on 4 Jan 2027'), findsOneWidget);
        final fifth = find.byKey(const ValueKey('calendar-day-request-5'));
        await tester.ensureVisible(fifth);
        await tester.tap(fifth);
        await tester.pumpAndSettle();
        expect(selected, 5);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }
  testWidgets('month controls cross year boundaries', (tester) async {
    DateTime? month;
    await _show(
      tester,
      LeaveCalendar(
        month: DateTime(2026, 12),
        rows: [],
        onMonthChanged: (m) => month = m,
        onOpen: (_) {},
        statusLabel: leaveLabel,
      ),
    );
    await tester.tap(find.byTooltip('Next month'));
    expect(month, DateTime(2027, 1));
    await tester.tap(find.byTooltip('Previous month'));
    expect(month, DateTime(2026, 11));
    await tester.tap(find.text('This month'));
    expect(month, DateTime(DateTime.now().year, DateTime.now().month));
  });
  for (final personal in [true, false]) {
    testWidgets(
      'calendar keeps ${personal ? 'personal' : 'school-wide'} scope and opens real details',
      (tester) async {
        final now = DateTime.now();
        final start = DateTime(
          now.year,
          now.month,
          4,
        ).toIso8601String().split('T').first;
        final end = DateTime(
          now.year,
          now.month,
          6,
        ).toIso8601String().split('T').first;
        final queries = <Map<String, String>>[];
        var failMonth = false;
        final api = LeaveApiClient(
          schoolId: 'SCH',
          client: MockClient((r) async {
            Object response;
            if (r.url.path.endsWith('/context')) {
              response = {
                'currentUserId': 7,
                'canReview': true,
                'staff': [
                  {'id': 7, 'name': 'Employee 7'},
                  {'id': 8, 'name': 'Employee 8'},
                ],
                'types': [],
              };
            } else if (r.url.path.endsWith('/balances')) {
              response = [];
            } else if (r.url.path.endsWith('/leave/7')) {
              response = {
                ..._row(7, start: start, end: end),
                'reason': 'Calendar request details',
                'events': [],
              };
            } else {
              final q = r.url.queryParameters;
              queries.add(q);
              if (failMonth && q.containsKey('from')) {
                return http.Response('{"message":"Calendar unavailable"}', 500);
              }
              final inMonth =
                  !q.containsKey('from') ||
                  q['from']!.substring(0, 7) == start.substring(0, 7);
              final rows = inMonth
                  ? [
                      _row(7, start: start, end: end),
                      if (q['staffUserId'] == null)
                        _row(8, start: start, end: end),
                    ]
                  : [];
              response = {
                'items': rows,
                'total': rows.length,
                'counts': {'APPROVED': rows.length},
              };
            }
            return http.Response(jsonEncode(response), 200);
          }),
        );
        await _show(
          tester,
          SizedBox(
            height: 1400,
            child: LeaveManagementScreen(api: api, myLeave: personal),
          ),
        );
        await tester.ensureVisible(find.text('Calendar'));
        await tester.tap(find.text('Calendar'));
        await tester.pumpAndSettle();
        expect(find.byType(DataTable), findsNothing);
        expect(find.byType(LeaveCalendar), findsOneWidget);
        expect(queries.last['staffUserId'], personal ? '7' : null);
        expect(
          queries.last['from'],
          DateTime(now.year, now.month).toIso8601String().split('T').first,
        );
        expect(
          find.byKey(ValueKey('leave-calendar-event-$start-8')),
          personal ? findsNothing : findsOneWidget,
        );
        final event = find.byKey(ValueKey('leave-calendar-event-$start-7'));
        await tester.ensureVisible(event);
        await tester.tap(event);
        await tester.pumpAndSettle();
        expect(find.text('Calendar request details'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        failMonth = true;
        await tester.ensureVisible(find.byTooltip('Next month'));
        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        expect(find.text('Calendar unavailable'), findsOneWidget);
        expect(event, findsNothing);
        failMonth = false;
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(
          find.text('No leave requests for this month and these filters.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('List'));
        await tester.tap(find.text('List'));
        await tester.pumpAndSettle();
        expect(find.byType(DataTable), findsOneWidget);
        expect(queries.last.containsKey('from'), isFalse);
      },
    );
  }
}
