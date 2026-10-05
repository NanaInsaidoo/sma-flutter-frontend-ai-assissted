import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/incidents/data/incident_api_client.dart';
import 'package:school_management_app/src/incidents/presentation/incidents_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets(
    'incident type breakdown sizes to content and shows full labels',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = IncidentApiClient(
        customSchoolId: 'SCHOOL',
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.url.path.contains('/dashboard/stats')) {
            return http.Response(
              jsonEncode({
                'summary': {'total': 2},
                'metrics': {
                  'criticalOrHigh': 2,
                  'openOrPending': 0,
                  'resolved': 2,
                  'studentsInvolved': 2,
                },
                'trends': {'totalChange': '-'},
                'typeBreakdown': [
                  {'key': 'SUBSTANCE_ABUSE', 'count': 1, 'percentage': 50},
                  {'key': 'BULLYING', 'count': 1, 'percentage': 50},
                ],
                'severityBreakdown': [
                  {'key': 'HIGH', 'count': 2, 'percentage': 100},
                ],
                'weeklyTrend': [
                  {'label': 'This week', 'count': 2},
                ],
                'recentActivity': [],
              }),
              200,
            );
          }
          if (request.url.path.contains('/current-term/')) {
            return http.Response(
              jsonEncode({'startDate': '2026-08-25', 'endDate': '2026-12-11'}),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'content': [],
              'number': 0,
              'totalPages': 0,
              'totalElements': 0,
            }),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: IncidentsScreen(
              customSchoolId: 'SCHOOL',
              accessToken: 'token',
              reportedBy: 'Administrator',
              apiClient: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.text('By incident type');
      final card = find.ancestor(of: title, matching: find.byType(Card)).first;
      expect(tester.getSize(card).height, lessThan(180));

      final substance = tester.widget<Text>(find.text('Substance Abuse'));
      expect(substance.overflow, isNull);
      expect(
        tester.getSize(find.text('Substance Abuse')).width,
        greaterThanOrEqualTo(120),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
