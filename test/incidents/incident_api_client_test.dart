import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/incidents/data/incident_api_client.dart';
import 'package:school_management_app/src/incidents/domain/incident_models.dart';

void main() {
  test('posts and reads a threaded incident reply', () async {
    late Map<String, dynamic> postedBody;
    final client = MockClient((request) async {
      postedBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'incidentId': 'INC-1',
          'customSchoolId': 'SCHOOL-1',
          'incidentType': '1',
          'incidentTypeName': 'Conduct',
          'severity': 'MEDIUM',
          'title': 'Test',
          'description': 'Test incident',
          'incidentDate': '2026-07-30',
          'location': 'Classroom',
          'incidentStatus': 'OPEN',
          'updates': [
            {
              'updateId': 'UPD-REPLY',
              'parentUpdateId': 'UPD-PARENT',
              'note': 'Reply for @Eric GoM',
              'updatedBy': 'teacher',
              'updateDateTime': '2026-07-30T08:46:35',
              'type': 'STAFF_NOTE',
            },
          ],
        }),
        200,
      );
    });
    final api = IncidentApiClient(
      customSchoolId: 'SCHOOL-1',
      accessToken: 'token',
      client: client,
    );

    final incident = await api.addComment(
      'INC-1',
      'Reply for @Eric GoM',
      'STAFF_NOTE',
      parentUpdateId: 'UPD-PARENT',
      mentions: const [
        IncidentMention(id: '42', name: 'Eric GoM', personType: 'STAFF'),
      ],
    );

    expect(postedBody['parentUpdateId'], 'UPD-PARENT');
    expect(postedBody['note'], contains('@Eric GoM'));
    expect(postedBody['mentions'], [
      {'personId': '42', 'personType': 'STAFF', 'name': 'Eric GoM'},
    ]);
    expect(incident.updates.single.parentUpdateId, 'UPD-PARENT');
    expect(incident.updates.single.updateDateTime, isNotNull);
  });

  test(
    'combines student and staff mention results with person types',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/api/students/search')) {
          return http.Response(
            jsonEncode([
              {
                'customStudentId': 'STU-1',
                'firstName': 'Ama',
                'lastName': 'Boateng',
                'class_': 'Basic 5',
                'section': 'A',
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'users': [
              {
                'id': 'STAFF-1',
                'firstName': 'Ama',
                'lastName': 'Mensah',
                'userType': 'STAFF',
                'role': 'CLASS_TEACHER',
              },
            ],
          }),
          200,
        );
      });
      final api = IncidentApiClient(
        customSchoolId: 'SCHOOL-1',
        accessToken: 'token',
        client: client,
      );

      final results = await api.searchMentions('Ama');

      expect(results, hasLength(2));
      expect(results.first.name, 'Ama Boateng');
      expect(results.first.isStudent, isTrue);
      expect(results.last.name, 'Ama Mensah');
      expect(results.last.personType, 'STAFF');
    },
  );

  test('parses backend LocalDateTime arrays for action audit fields', () {
    final action = IncidentAction.fromJson({
      'actionId': 7,
      'actionTypeName': 'Parent contacted',
      'takenAt': [2026, 7, 30, 9, 15, 10],
      'updatedBy': 'eric.gom@gmail.com',
      'updatedAt': [2026, 7, 30, 10, 20, 30, 500000000],
    });

    expect(action.takenAt, DateTime(2026, 7, 30, 9, 15, 10));
    expect(action.updatedAt, DateTime(2026, 7, 30, 10, 20, 30, 500));
  });

  test('parses notified parties, closing status and edit attribution', () {
    final incident = IncidentRecord.fromJson({
      'incidentId': 'INC-2',
      'customSchoolId': 'SCHOOL-1',
      'incidentType': '1',
      'incidentTypeName': 'Conduct',
      'severity': 'HIGH',
      'title': 'Resolved incident',
      'description': 'Updated description',
      'incidentDate': '2026-08-29',
      'location': 'Classroom',
      'incidentStatus': 'CLOSED_RESOLVED',
      'notifiedParties': ['PARENT_GUARDIAN', 'POLICE', 'OTHER'],
      'otherNotifiedDetails': 'District social welfare officer',
      'edited': true,
      'lastEditedBy': 'Adjoa Mensah',
      'lastEditedAt': '2026-08-29T14:30:00',
      'closureRequestStatus': 'APPROVED',
      'requestedClosureStatus': 'CLOSED_RESOLVED',
      'closureRequestedByName': 'Kofi Nketia',
      'closureApproverId': 24,
      'closureApproverName': 'Adjoa Mensah',
      'closureNote': 'All follow-up actions are complete.',
      'closureRequestedAt': '2026-08-29T13:30:00',
    });

    expect(incident.status, 'CLOSED_RESOLVED');
    expect(incident.notifiedParties, containsAll(['POLICE', 'OTHER']));
    expect(incident.otherNotifiedDetails, 'District social welfare officer');
    expect(incident.lastEditedBy, 'Adjoa Mensah');
    expect(incident.lastEditedAt, DateTime(2026, 8, 29, 14, 30));
    expect(incident.closureRequestStatus, 'APPROVED');
    expect(incident.closureApproverName, 'Adjoa Mensah');
    expect(incident.closureRequestedAt, DateTime(2026, 8, 29, 13, 30));
  });

  test('submits closure for another approver and can reopen later', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/closure-approvers')) {
        return http.Response(
          jsonEncode([
            {'id': 24, 'name': 'Adjoa Mensah', 'role': 'Headmaster'},
          ]),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'incidentId': 'INC-2',
          'customSchoolId': 'SCHOOL-1',
          'incidentType': '1',
          'incidentTypeName': 'Conduct',
          'severity': 'HIGH',
          'title': 'Test incident',
          'description': 'Description',
          'incidentDate': '2026-08-29',
          'location': 'Classroom',
          'incidentStatus': request.url.path.endsWith('/reopen')
              ? 'OPEN'
              : 'ESCALATED',
          'closureRequestStatus': request.url.path.endsWith('/reopen')
              ? 'REOPENED'
              : 'PENDING_APPROVAL',
        }),
        200,
      );
    });
    final api = IncidentApiClient(
      customSchoolId: 'SCHOOL-1',
      accessToken: 'token',
      client: client,
    );

    final approvers = await api.getClosureApprovers();
    final pending = await api.requestClosure(
      'INC-2',
      resolved: false,
      note: 'Further work cannot continue.',
      approverId: approvers.single.id,
    );
    final reopened = await api.reopen('INC-2', 'New evidence received.');

    expect(approvers.single.name, 'Adjoa Mensah');
    expect(pending.closureRequestStatus, 'PENDING_APPROVAL');
    expect(reopened.status, 'OPEN');
    final closureBody = jsonDecode(requests[1].body) as Map<String, dynamic>;
    expect(closureBody['outcome'], 'CLOSED_UNRESOLVED');
    expect(closureBody['approverId'], 24);
    expect(jsonDecode(requests[2].body), {'comment': 'New evidence received.'});
  });

  test('downloads the prepared incident PDF', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/api/v1/incidents/INC-9/report'));
      expect(request.url.queryParameters['customSchoolId'], 'SCHOOL-1');
      return http.Response.bytes(
        [0x25, 0x50, 0x44, 0x46, 0x2D],
        200,
        headers: {'content-type': 'application/pdf'},
      );
    });
    final api = IncidentApiClient(
      customSchoolId: 'SCHOOL-1',
      accessToken: 'token',
      client: client,
    );

    final bytes = await api.downloadIncidentReport('INC-9');

    expect(bytes, [0x25, 0x50, 0x44, 0x46, 0x2D]);
  });
}
