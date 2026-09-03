import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/incidents/data/incident_api_client.dart';
import 'package:school_management_app/src/incidents/domain/incident_models.dart';
import 'package:school_management_app/src/incidents/presentation/incidents_screen.dart';

void main() {
  testWidgets('closed incident is visibly read-only and offers reopen', (
    tester,
  ) async {
    final api = IncidentApiClient(
      customSchoolId: 'SCHOOL-1',
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'content': <Object>[],
            'number': 0,
            'totalPages': 0,
            'totalElements': 0,
          }),
          200,
        ),
      ),
    );
    final incident = IncidentRecord(
      incidentId: 'INC-100',
      customSchoolId: 'SCHOOL-1',
      incidentType: '1',
      incidentTypeName: 'Conduct',
      severity: 'MEDIUM',
      title: 'Closed incident',
      description: 'The final record.',
      incidentDate: DateTime(2026, 8, 29, 10),
      location: 'Classroom',
      status: 'CLOSED_RESOLVED',
      closureRequestStatus: 'APPROVED',
      closureApproverName: 'Adjoa Mensah',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncidentDetailView(api: api, initial: incident, onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('closed-incident-read-only-banner')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reopen-incident')), findsOneWidget);
    expect(find.byKey(const Key('close-incident')), findsNothing);
    expect(find.text('Add person'), findsNothing);
    expect(find.text('Add action'), findsNothing);
    expect(find.text('Post comment'), findsNothing);
    expect(
      find.text('Comments are read-only while this incident is closed.'),
      findsOneWidget,
    );
  });
}
