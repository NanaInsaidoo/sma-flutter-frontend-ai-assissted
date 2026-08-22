import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/presentation/payment_reversals_content.dart';

void main() {
  Future<void> openPendingReversal(
    WidgetTester tester, {
    required int currentUserId,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/fee-adjustments/approvers')) {
          return http.Response(
            jsonEncode([
              {'id': 7, 'name': 'Nana Boateng', 'role': 'ADMINISTRATOR'},
              {'id': 8, 'name': 'Akosua Owusu', 'role': 'ADMINISTRATOR'},
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'id': 41,
              'paymentId': 6,
              'paymentReference': 'RCPT-20260821-006',
              'customStudentId': 'STU-001-1730',
              'studentName': 'Ama Serwaa Ofori',
              'termId': 3,
              'amount': 100,
              'status': 'PENDING_APPROVAL',
              'reason': 'Duplicate payment entered for audit testing',
              'requestedBy': '7',
              'requesterName': 'Nana Boateng',
              'approverId': 8,
              'approverName': 'Akosua Owusu',
              'createdAt': '2026-08-22T09:00:00',
            },
          ]),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 900,
            child: SingleChildScrollView(
              child: PaymentReversalsContent(
                api: api,
                customSchoolId: 'SMA-DEMO-001',
                currentTermId: 3,
                currentUserId: currentUserId,
                onChanged: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ama Serwaa Ofori'));
    await tester.pumpAndSettle();
  }

  testWidgets('requester sees requester actions but not approval actions', (
    tester,
  ) async {
    await openPendingReversal(tester, currentUserId: 7);

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Change approver'), findsOneWidget);
    expect(find.text('Reject'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('assigned approver sees approval actions only', (tester) async {
    await openPendingReversal(tester, currentUserId: 8);

    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Change approver'), findsNothing);
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
  });
}
