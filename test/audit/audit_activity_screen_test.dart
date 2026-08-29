import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/audit/data/audit_api_client.dart';
import 'package:school_management_app/src/audit/presentation/audit_activity_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  test('audit client sends server-side filters and parses snapshots', () async {
    Uri? requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(
        jsonEncode({
          'logs': [_record],
          'totalElements': 1,
          'totalPages': 1,
          'currentPage': 0,
          'pageSize': 20,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = AuditApiClient(accessToken: 'token', client: client);

    final page = await api.getAuditLogs(
      search: 'Nana',
      actionType: 'DELETE',
      startDate: DateTime(2026, 8, 1),
      endDate: DateTime(2026, 8, 31, 23, 59),
      scopeKey: 'school:SCHOOL-A',
    );

    expect(requested?.queryParameters['search'], 'Nana');
    expect(requested?.queryParameters['actionType'], 'DELETE');
    expect(requested?.queryParameters['startDate'], startsWith('2026-08-01'));
    expect(requested?.queryParameters['scopeKey'], 'school:SCHOOL-A');
    expect(page.logs.single.subjectName, 'Nana Boateng');
    expect(page.logs.single.actorName, 'Eric GoM');
  });

  testWidgets('administrator can review and open audit activity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/scopes')) {
        return http.Response(
          jsonEncode([
            {
              'value': 'platform',
              'label': 'Platform activity',
              'type': 'PLATFORM',
            },
            {
              'value': 'all-schools',
              'label': 'All schools',
              'type': 'ALL_SCHOOLS',
            },
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/statistics')) {
        return http.Response(
          jsonEncode({
            'totalLogs': 24,
            'createCount': 7,
            'editCount': 8,
            'accessChangeCount': 5,
            'failedLoginCount': 2,
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'logs': [_record],
          'totalElements': 1,
          'totalPages': 1,
          'currentPage': 0,
          'pageSize': 20,
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuditActivityScreen(
            repository: AuditApiClient(accessToken: 'token', client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Audit & Activity'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
    expect(find.text('Nana Boateng'), findsOneWidget);
    expect(find.text('Eric GoM'), findsOneWidget);
    expect(find.text('Platform activity'), findsOneWidget);
    expect(
      find.text('Account permanently deleted after testing.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Account permanently deleted after testing.'));
    await tester.pumpAndSettle();

    expect(find.text('Recorded change details'), findsOneWidget);
    expect(find.text('Technical details'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('custom date and time range is sent to the audit API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Uri? lastAuditRequest;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/scopes')) {
        return http.Response(
          jsonEncode([
            {
              'value': 'school:SCHOOL-A',
              'label': 'Alpha Academy',
              'type': 'SCHOOL',
            },
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/statistics')) {
        return http.Response(
          jsonEncode({
            'totalLogs': 0,
            'createCount': 0,
            'editCount': 0,
            'accessChangeCount': 0,
            'failedLoginCount': 0,
          }),
          200,
        );
      }
      lastAuditRequest = request.url;
      return http.Response(
        jsonEncode({
          'logs': [],
          'totalElements': 0,
          'totalPages': 0,
          'currentPage': 0,
          'pageSize': 20,
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuditActivityScreen(
            repository: AuditApiClient(accessToken: 'token', client: client),
            customRangePicker: (_, _, _) async => (
              DateTime(2026, 8, 20, 8, 15),
              DateTime(2026, 8, 22, 17, 45, 59),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('audit-period-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom range').last);
    await tester.pumpAndSettle();

    expect(lastAuditRequest?.queryParameters['scopeKey'], 'school:SCHOOL-A');
    expect(
      lastAuditRequest?.queryParameters['startDate'],
      '2026-08-20T08:15:00.000',
    );
    expect(
      lastAuditRequest?.queryParameters['endDate'],
      '2026-08-22T17:45:59.000',
    );
    expect(find.textContaining('Aug 20, 2026 at 8:15 AM'), findsOneWidget);
  });

  testWidgets('downloads only the selected audit records as CSV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? downloadedFileName;
    String? downloadedContents;

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/scopes')) {
        return http.Response(
          jsonEncode([
            {
              'value': 'platform',
              'label': 'Platform activity',
              'type': 'PLATFORM',
            },
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/statistics')) {
        return http.Response(
          jsonEncode({
            'totalLogs': 2,
            'createCount': 0,
            'editCount': 0,
            'accessChangeCount': 0,
            'failedLoginCount': 0,
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'logs': [_record, _otherRecord],
          'totalElements': 2,
          'totalPages': 1,
          'currentPage': 0,
          'pageSize': 20,
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuditActivityScreen(
            repository: AuditApiClient(accessToken: 'token', client: client),
            csvDownloader: (fileName, contents) async {
              downloadedFileName = fileName;
              downloadedContents = contents;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download selected (0)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('audit-select-41')));
    await tester.pump();

    expect(find.textContaining('1 selected'), findsOneWidget);
    expect(find.text('Download selected (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('audit-download-selected')));
    await tester.pumpAndSettle();

    expect(downloadedFileName, startsWith('audit_activity_selected_'));
    expect(downloadedFileName, endsWith('.csv'));
    expect(downloadedContents, contains('Nana Boateng'));
    expect(downloadedContents, contains('Eric GoM'));
    expect(
      downloadedContents,
      contains('Account permanently deleted after testing.'),
    );
    expect(downloadedContents, isNot(contains('Yaw Mensah')));
    expect(find.text('1 selected audit record downloaded.'), findsOneWidget);
  });

  testWidgets('custom range dialog stays clear at a compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(525, 350);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/scopes')) {
        return http.Response(
          jsonEncode([
            {
              'value': 'platform',
              'label': 'Platform activity',
              'type': 'PLATFORM',
            },
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/statistics')) {
        return http.Response(
          jsonEncode({
            'totalLogs': 1,
            'createCount': 0,
            'editCount': 0,
            'accessChangeCount': 0,
            'failedLoginCount': 0,
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'logs': [_record],
          'totalElements': 1,
          'totalPages': 1,
          'currentPage': 0,
          'pageSize': 20,
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuditActivityScreen(
            repository: AuditApiClient(accessToken: 'token', client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final period = find.byKey(const ValueKey('audit-period-filter'));
    await tester.ensureVisible(period);
    await tester.tap(period);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom range').last);
    await tester.pumpAndSettle();

    expect(find.text('Choose a date range'), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('Apply range'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _record = {
  'id': 41,
  'actionType': 'DELETE',
  'description': 'Account permanently deleted after testing.',
  'timestamp': '2026-08-22T09:30:00',
  'customSchoolId': 'platform',
  'subjectUserId': 17,
  'subjectUsername': 'nana.boateng',
  'subjectDisplayName': 'Nana Boateng',
  'subjectRole': 'ADMINISTRATOR',
  'performedByUserId': 3,
  'performedByUsername': 'eric.gom',
  'performedByDisplayName': 'Eric GoM',
  'ipAddress': '127.0.0.1',
  'userAgent': 'Test browser',
  'metadata': '{"reason":"duplicate test account"}',
};

const _otherRecord = {
  'id': 42,
  'actionType': 'EDIT',
  'description': 'Profile details updated.',
  'timestamp': '2026-08-22T09:45:00',
  'customSchoolId': 'platform',
  'subjectUserId': 18,
  'subjectUsername': 'yaw.mensah',
  'subjectDisplayName': 'Yaw Mensah',
  'subjectRole': 'ACCOUNT_MANAGER',
  'performedByUserId': 3,
  'performedByUsername': 'eric.gom',
  'performedByDisplayName': 'Eric GoM',
  'ipAddress': '127.0.0.1',
  'userAgent': 'Test browser',
  'metadata': '{"field":"phone"}',
};
