import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';

void main() {
  test('loads the school-wide payment reversal audit queue', () async {
    late http.Request captured;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode([
            {
              'id': 31,
              'paymentId': 12,
              'paymentReference': 'RCPT-12',
              'customStudentId': 'STU-1',
              'studentName': 'Ama Mensah',
              'termId': 9,
              'amount': 50,
              'status': 'PENDING_APPROVAL',
              'reason': 'Duplicate payment entered by mistake',
              'requestedBy': '16',
              'requesterName': 'Eric GoM',
              'approverId': 8,
              'approverName': 'Head Teacher',
            },
          ]),
          200,
        );
      }),
    );

    final rows = await api.getSchoolPaymentReversals(customSchoolId: 'SCH-1');

    expect(
      captured.url.path,
      endsWith('/api/payments/schools/SCH-1/reversals'),
    );
    expect(rows.single.studentName, 'Ama Mensah');
    expect(rows.single.requesterName, 'Eric GoM');
    expect(rows.single.termId, 9);
  });

  test(
    'creates and approves a payment reversal through the workflow API',
    () async {
      final requests = <http.Request>[];
      final api = FeeApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          requests.add(request);
          final body = request.body.isEmpty
              ? const <String, dynamic>{}
              : jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'id': 31,
              'paymentId': 12,
              'paymentReference': 'RCPT-12',
              'customStudentId': 'STU-1',
              'amount': 50,
              'status': body['action'] == 'APPROVE'
                  ? 'APPROVED'
                  : 'PENDING_APPROVAL',
              'reason': 'Duplicate payment entered by mistake',
              'approverId': 8,
              'approverName': 'Head Teacher',
              'reversalReference': body['action'] == 'APPROVE' ? 'REV-31' : '',
            }),
            200,
          );
        }),
      );

      final created = await api.createPaymentReversal(
        customSchoolId: 'SCH-1',
        paymentId: 12,
        reason: 'Duplicate payment entered by mistake',
        approverId: 8,
        submitForApproval: true,
      );
      final approved = await api.performPaymentReversalAction(
        customSchoolId: 'SCH-1',
        reversalId: created.id,
        action: 'APPROVE',
        reason: 'Verified against the bank record',
      );

      expect(
        requests[0].url.path,
        endsWith('/api/payments/schools/SCH-1/12/reversals'),
      );
      expect(jsonDecode(requests[0].body), {
        'reason': 'Duplicate payment entered by mistake',
        'approverId': 8,
        'submitForApproval': true,
      });
      expect(
        requests[1].url.path,
        endsWith('/api/payments/schools/SCH-1/reversals/31/actions'),
      );
      expect(approved.status, 'APPROVED');
      expect(approved.reversalReference, 'REV-31');
    },
  );
}
