import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/reports/data/management_report_api_client.dart';
import 'package:school_management_app/src/reports/domain/data_export_models.dart';

void main() {
  test(
    'loads export options and sends the complete preview criteria',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/data-exports/options')) {
          return http.Response(
            jsonEncode({
              'datasets': [
                {
                  'code': 'FEES_PAYMENTS',
                  'label': 'Fees and payments',
                  'description': 'Recorded fee rows',
                },
              ],
              'terms': [
                {
                  'id': 4,
                  'academicYear': '2026-2027',
                  'term': 'Second Term',
                  'status': 'ACTIVE',
                  'current': true,
                  'startDate': '2026-10-12',
                  'endDate': '2027-04-30',
                },
              ],
              'classes': [
                {'id': 8, 'name': 'JHS 2'},
              ],
              'paymentMethods': [
                {'id': 3, 'name': 'Mobile Money'},
              ],
              'statusOptions': ['COMPLETED'],
              'canIncludeIdentities': true,
              'maximumRows': 250000,
            }),
            200,
          );
        }
        expect(request.url.path, endsWith('/data-exports/preview'));
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer token-1');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['datasets'], ['FEES_PAYMENTS']);
        expect(body['termIds'], [4]);
        expect(body['classIds'], [8]);
        expect(body['paymentMethodIds'], [3]);
        expect(body['minimumAmount'], 100.0);
        expect(body['anonymized'], isTrue);
        return http.Response(
          jsonEncode({
            'totalRecords': 27,
            'files': {'fee-payments.csv': 27},
            'overLimit': false,
            'period': '2026-10-12 to 2027-04-30',
          }),
          200,
        );
      });
      final api = ManagementReportApiClient(
        accessToken: 'token-1',
        client: client,
      );

      final options = await api.dataExportOptions('SMA-DEMO-001');
      final preview = await api.previewDataExport(
        'SMA-DEMO-001',
        const DataExportRequest(
          datasets: ['FEES_PAYMENTS'],
          termIds: [4],
          classIds: [8],
          statuses: ['COMPLETED'],
          paymentMethodIds: [3],
          minimumAmount: 100,
          allAvailable: false,
          anonymized: true,
          includeAnalysisColumns: true,
          includeDataDictionary: true,
        ),
      );

      expect(options.datasets.single.label, 'Fees and payments');
      expect(options.terms.single.current, isTrue);
      expect(preview.totalRecords, 27);
      expect(requests, hasLength(2));
    },
  );

  test('downloads a generated ZIP using the server filename', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/data-exports'));
      expect(request.headers['accept'], 'application/zip');
      return http.Response.bytes(
        const [80, 75, 3, 4],
        200,
        headers: {
          'content-type': 'application/zip',
          'content-disposition':
              'attachment; filename="school-analysis-data-20261015-120000.zip"',
        },
      );
    });
    final api = ManagementReportApiClient(
      accessToken: 'token-2',
      client: client,
    );

    final result = await api.createDataExport(
      'SMA-DEMO-001',
      const DataExportRequest(
        datasets: ['INCIDENTS'],
        termIds: [4],
        classIds: [],
        statuses: [],
        paymentMethodIds: [],
        allAvailable: false,
        anonymized: true,
        includeAnalysisColumns: true,
        includeDataDictionary: true,
      ),
    );

    expect(result.fileName, 'school-analysis-data-20261015-120000.zip');
    expect(result.bytes, [80, 75, 3, 4]);
  });
}
