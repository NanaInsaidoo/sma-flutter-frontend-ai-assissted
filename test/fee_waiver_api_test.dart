import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';

void main() {
  const typeBody = '''
  {
    "id": 9,
    "name": "Partial bursary",
    "description": "Tuition support",
    "valueType": "PERCENTAGE",
    "defaultValue": 50,
    "scope": "SELECTED_FEE_ITEMS",
    "active": true
  }
  ''';

  const assignmentBody = '''
  {
    "id": 71,
    "academicTermId": 44,
    "customStudentId": "STU-044",
    "studentName": "Ama Mensah",
    "className": "Basic 6",
    "waiverTypeId": 9,
    "waiverType": "Partial bursary",
    "valueType": "PERCENTAGE",
    "value": 50,
    "scope": "SELECTED_FEE_ITEMS",
    "eligibleAmount": 500,
    "waivedAmount": 250,
    "reason": "Approved bursary",
    "status": "ACTIVE",
    "assessments": [
      {"assessmentId": 90, "feeName": "Tuition Fee", "amount": 500}
    ]
  }
  ''';

  test('loads waiver assignments for the selected academic term', () async {
    late http.Request captured;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('[$assignmentBody]', 200);
      }),
    );

    final waivers = await api.getStudentWaivers(
      customSchoolId: 'SCH-001',
      academicTermId: 44,
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, endsWith('/api/schools/SCH-001/student-waivers'));
    expect(captured.url.queryParameters['academicTermId'], '44');
    expect(waivers.single.waivedAmount, 250);
  });

  test('creates a waiver type with an explicit value and scope', () async {
    late http.Request captured;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(typeBody, 201);
      }),
    );

    await api.saveWaiverType(
      customSchoolId: 'SCH-001',
      name: 'Partial bursary',
      description: 'Tuition support',
      valueType: 'PERCENTAGE',
      defaultValue: 50,
      scope: 'SELECTED_FEE_ITEMS',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(captured.method, 'POST');
    expect(captured.url.path, endsWith('/api/schools/SCH-001/waiver-types'));
    expect(body['valueType'], 'PERCENTAGE');
    expect(body['defaultValue'], 50);
    expect(body['scope'], 'SELECTED_FEE_ITEMS');
  });

  test('creates and revokes a term-scoped student waiver', () async {
    final requests = <http.Request>[];
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        requests.add(request);
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response(assignmentBody, 201);
      }),
    );

    await api.saveStudentWaiver(
      customSchoolId: 'SCH-001',
      customStudentId: 'STU-044',
      academicTermId: 44,
      waiverTypeId: 9,
      value: 50,
      assessmentIds: const [90],
      reason: 'Approved bursary',
    );
    await api.revokeStudentWaiver(
      customSchoolId: 'SCH-001',
      customStudentId: 'STU-044',
      waiverId: 71,
    );

    final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(requests.first.method, 'POST');
    expect(
      requests.first.url.path,
      endsWith('/api/schools/SCH-001/students/STU-044/waivers'),
    );
    expect(body['academicTermId'], 44);
    expect(body['assessmentIds'], [90]);
    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.path, endsWith('/waivers/71'));
  });
}
