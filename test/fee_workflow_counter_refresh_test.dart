import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/presentation/fee_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('fee workflow refresh notifies the dashboard counter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/academic-context/current')) {
        return http.Response(
          jsonEncode({
            'academicTerm': {
              'id': 44,
              'termType': {'name': 'First Term'},
            },
            'academicYear': {'year': '2026-2027'},
          }),
          200,
        );
      }
      if (path.endsWith('/api/academic-terms')) {
        return http.Response(
          jsonEncode([
            {
              'id': 44,
              'termName': 'First Term',
              'academicYear': '2026-2027',
              'isCurrentTerm': true,
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/fee-management/overview')) {
        return http.Response(
          jsonEncode({
            'termId': 44,
            'termName': 'First Term',
            'academicYear': '2026-2027',
            'collectionByClass': <dynamic>[],
            'outstandingArrears': <dynamic>[],
          }),
          200,
        );
      }
      return http.Response('Not found: $path', 404);
    });
    var refreshNotifications = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FeeManagementScreen(
            customSchoolId: 'SCH-001',
            schoolName: 'Test School',
            accessToken: 'token',
            onWorkflowChanged: () => refreshNotifications++,
            api: FeeApiClient(accessToken: 'token', client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(refreshNotifications, 0);

    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();

    expect(refreshNotifications, 1);
    expect(tester.takeException(), isNull);
  });
}
