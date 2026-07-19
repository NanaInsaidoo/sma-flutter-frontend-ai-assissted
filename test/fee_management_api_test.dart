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
}
