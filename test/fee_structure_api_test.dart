import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';

void main() {
  const responseBody = '''
  {
    "structureId": 91,
    "gradeLevelId": 12,
    "levelCode": "B6",
    "fullName": "Basic 6",
    "studentCount": 42,
    "version": 1,
    "status": "DRAFT",
    "totalPerTerm": 450,
    "feeItems": []
  }
  ''';

  FeeStructureItem item(
    String name,
    double amount, {
    String status = 'ACTIVE',
  }) => FeeStructureItem(
    feeId: 0,
    categoryId: 0,
    category: 'TUITION',
    feeName: name,
    amount: amount,
    description: '',
    status: status,
    dueDate: null,
  );

  test('loads structures from the versioned term-scoped route', () async {
    late http.Request captured;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response('[$responseBody]', 200);
      }),
    );

    await api.getFeeStructuresForTerm(customSchoolId: 'SCH-001', termId: 44);

    expect(captured.method, 'GET');
    expect(captured.url.path, endsWith('/api/schools/SCH-001/fee-structures'));
    expect(captured.url.queryParameters['academicTermId'], '44');
  });

  test('creates a draft with ordered fee items', () async {
    late http.Request captured;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(responseBody, 201);
      }),
    );

    await api.saveFeeStructure(
      customSchoolId: 'SCH-001',
      structureId: 0,
      gradeLevelId: 12,
      termId: 44,
      feeItems: [item('Tuition fee', 400), item('ICT levy', 50)],
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    final items = body['feeItems'] as List<dynamic>;
    expect(captured.method, 'POST');
    expect(body['academicTermId'], 44);
    expect(body['gradeLevelId'], 12);
    expect((items[0] as Map<String, dynamic>)['displayOrder'], 0);
    expect((items[1] as Map<String, dynamic>)['displayOrder'], 1);
  });

  test(
    'updates an existing structure without changing its class or term',
    () async {
      late http.Request captured;
      final api = FeeApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          captured = request;
          return http.Response(responseBody, 200);
        }),
      );

      await api.saveFeeStructure(
        customSchoolId: 'SCH-001',
        structureId: 91,
        gradeLevelId: 12,
        termId: 44,
        feeItems: [
          item('Tuition fee', 450),
          item('ICT levy', 50, status: 'INACTIVE'),
        ],
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(captured.method, 'PUT');
      expect(captured.url.path, endsWith('/fee-structures/91'));
      expect(body.keys, ['feeItems']);
      final items = body['feeItems'] as List<dynamic>;
      expect((items.last as Map<String, dynamic>)['active'], false);
    },
  );

  test('publishes and deletes through lifecycle routes', () async {
    final requests = <http.Request>[];
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        requests.add(request);
        return request.method == 'DELETE'
            ? http.Response('', 204)
            : http.Response(responseBody, 200);
      }),
    );

    await api.publishFeeStructure(customSchoolId: 'SCH-001', structureId: 91);
    await api.deleteFeeStructure(customSchoolId: 'SCH-001', structureId: 92);

    expect(requests[0].method, 'POST');
    expect(requests[0].url.path, endsWith('/fee-structures/91/publish'));
    expect(requests[1].method, 'DELETE');
    expect(requests[1].url.path, endsWith('/fee-structures/92'));
  });
}
