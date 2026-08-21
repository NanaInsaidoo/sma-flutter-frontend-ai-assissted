import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';

void main() {
  test('core fee reads are scoped to the selected academic term', () async {
    final requests = <http.Request>[];
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/fee-management/overview')) {
          return http.Response('''
            {
              "termId": 44,
              "termName": "Second Term",
              "academicYear": "2025/2026",
              "collectionByClass": [],
              "outstandingArrears": []
            }
            ''', 200);
        }
        if (request.url.path.endsWith('/fee-management/students')) {
          return http.Response('''
            {
              "content": [],
              "totalElements": 0,
              "totalPages": 0,
              "currentPage": 0,
              "pageSize": 20
            }
            ''', 200);
        }
        return http.Response('[]', 200);
      }),
    );

    await api.getFeeManagementOverview(customSchoolId: 'SCH-001', termId: 44);
    await api.getFeeManagementStudents(
      customSchoolId: 'SCH-001',
      termId: 44,
      gradeLevelId: 9,
      paymentStatus: 'NO_FEES',
      search: 'Ama',
      page: 0,
      size: 20,
    );
    await api.getFeeManagementClasses(customSchoolId: 'SCH-001', termId: 44);
    await api.getFeeManagementArrears(customSchoolId: 'SCH-001', termId: 44);

    expect(requests, hasLength(4));
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.url.queryParameters['termId'], '44');
    }
    expect(requests[1].url.queryParameters['page'], '0');
    expect(requests[1].url.queryParameters['size'], '20');
    expect(requests[1].url.queryParameters['gradeLevelId'], '9');
    expect(requests[1].url.queryParameters['paymentStatus'], 'NO_FEES');
    expect(requests[1].url.queryParameters['search'], 'Ama');
  });

  test(
    'cheque clearance and rejection use the controlled payment actions',
    () async {
      final requests = <http.Request>[];
      final api = FeeApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('''
          {
            "id": 21,
            "amount": 250,
            "netAmount": 250,
            "paymentMethodName": "CHEQUE",
            "referenceNumber": "RCPT-20260817-001",
            "receivedBy": "Bursar",
            "termId": 2,
            "status": "COMPLETED",
            "statusReason": "Cheque cleared",
            "chequeNumber": "001122",
            "chequeBank": "Example Bank",
            "chequeDate": "2026-08-17"
          }
        ''', 200);
        }),
      );

      final cleared = await api.clearPendingPayment(
        paymentId: 21,
        notes: 'Cleared on bank statement',
      );
      await api.rejectPendingPayment(
        paymentId: 22,
        reason: 'Returned unpaid by bank',
      );

      expect(cleared.status, 'COMPLETED');
      expect(cleared.chequeNumber, '001122');
      expect(requests[0].method, 'POST');
      expect(requests[0].url.path, endsWith('/api/payments/21/verify'));
      expect(
        requests[0].url.queryParameters['verificationNotes'],
        'Cleared on bank statement',
      );
      expect(requests[1].method, 'PUT');
      expect(requests[1].url.path, endsWith('/api/payments/22/status'));
      expect(requests[1].url.queryParameters['status'], 'FAILED');
      expect(
        requests[1].url.queryParameters['statusReason'],
        'Returned unpaid by bank',
      );
    },
  );
}
