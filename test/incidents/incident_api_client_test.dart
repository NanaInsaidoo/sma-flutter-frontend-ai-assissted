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
}
