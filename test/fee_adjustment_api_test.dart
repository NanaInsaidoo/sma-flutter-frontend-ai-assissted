import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';

void main() {
  test('fee adjustment list uses the paginated term-scoped endpoint', () async {
    late http.Request captured;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"content":[],"number":2,"size":20,"totalElements":55,"totalPages":3}',
          200,
        );
      }),
    );

    final page = await api.getFeeAdjustmentsPage(
      customSchoolId: 'SCH-001',
      termId: 44,
      page: 2,
      size: 20,
    );

    expect(captured.method, 'GET');
    expect(
      captured.url.path,
      endsWith('/api/schools/SCH-001/fee-adjustments/paginated'),
    );
    expect(captured.url.queryParameters['termId'], '44');
    expect(captured.url.queryParameters['page'], '2');
    expect(captured.url.queryParameters['size'], '20');
    expect(page.totalElements, 55);
    expect(page.totalPages, 3);
  });

  test(
    'create, update, and delete use the documented adjustment contract',
    () async {
      final requests = <http.Request>[];
      final api = FeeApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') return http.Response('', 204);
          final body = request.body.isEmpty
              ? const <String, dynamic>{}
              : jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': body['id'] ?? 42,
              'customStudentId': body['customStudentId'] ?? 'STU-001',
              'studentName': 'Kwame Asante',
              'termId': body['termId'] ?? 44,
              'feeId': body['feeId'] ?? 5,
              'feeName': 'Tuition fee',
              'adjustmentType': 'Discount',
              'amount': body['amount'] ?? -50,
              'description': body['description'] ?? 'Sibling discount',
              'status': body['status'] ?? 'PENDING',
            }),
            200,
          );
        }),
      );

      await api.createFeeAdjustment(
        customSchoolId: 'SCH-001',
        customStudentId: 'STU-001',
        termId: 44,
        feeId: 5,
        amount: -50,
        description: 'Sibling discount',
      );
      await api.updateFeeAdjustment(
        customSchoolId: 'SCH-001',
        adjustmentId: 42,
        status: 'APPROVED',
      );
      await api.deleteFeeAdjustment(
        customSchoolId: 'SCH-001',
        adjustmentId: 42,
      );

      expect(requests.map((request) => request.method), [
        'POST',
        'PUT',
        'DELETE',
      ]);
      final create = jsonDecode(requests[0].body) as Map<String, dynamic>;
      expect(create['customStudentId'], 'STU-001');
      expect(create['termId'], 44);
      expect(create['feeId'], 5);
      expect(create['amount'], -50);
      expect(create['status'], 'PENDING');

      final update = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(update, {'id': 42, 'status': 'APPROVED'});
      expect(requests[2].url.path, endsWith('/fee-adjustments/42'));
    },
  );
}
