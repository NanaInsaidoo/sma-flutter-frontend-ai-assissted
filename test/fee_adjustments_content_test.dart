import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/presentation/fee_adjustments_content.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  Future<void> pumpAdjustments(
    WidgetTester tester, {
    required FeeApiClient api,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FeeAdjustmentsContent(
              api: api,
              customSchoolId: 'SCH-001',
              termId: 44,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads the real paginated queue and filters the current page', (
    tester,
  ) async {
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient(
        (request) async => http.Response(_pageJson(status: 'PENDING'), 200),
      ),
    );
    await pumpAdjustments(tester, api: api);

    expect(find.text('Fee Adjustments'), findsOneWidget);
    expect(find.text('Kwame Yaw Asante'), findsOneWidget);
    expect(find.text('Showing 1-1 of 1 adjustments'), findsOneWidget);
    expect(find.text('Prototype data'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('adjustments-search')),
      'no match',
    );
    await tester.pump();

    expect(find.text('Kwame Yaw Asante'), findsNothing);
    expect(
      find.text('No adjustments on this page match the filters.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('clear-adjustment-filters')), findsOneWidget);
  });

  testWidgets('approves a pending adjustment through the backend', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var approved = false;
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['id'], 42);
          expect(body['status'], 'APPROVED');
          approved = true;
          return http.Response(_adjustmentJson(status: 'APPROVED'), 200);
        }
        return http.Response(
          _pageJson(status: approved ? 'APPROVED' : 'PENDING'),
          200,
        );
      }),
    );
    await pumpAdjustments(tester, api: api);

    await tester.tap(find.text('Kwame Yaw Asante'));
    await tester.pumpAndSettle();
    expect(find.text('Adjustment review'), findsOneWidget);

    await tester.tap(find.byKey(const Key('adjustment-action-approve')));
    await tester.pumpAndSettle();

    expect(approved, isTrue);
    expect(find.text('Adjustment approved.'), findsOneWidget);
    expect(find.text('Approved'), findsWidgets);
    expect(requests.where((request) => request.method == 'PUT'), hasLength(1));
  });

  testWidgets('shows a useful empty state without fallback records', (
    tester,
  ) async {
    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient(
        (request) async => http.Response(
          '{"content":[],"number":0,"size":20,"totalElements":0,"totalPages":0}',
          200,
        ),
      ),
    );
    await pumpAdjustments(tester, api: api);

    expect(find.text('No fee adjustments for this term'), findsOneWidget);
    expect(find.text('Kwame Yaw Asante'), findsNothing);
  });
}

String _pageJson({required String status}) =>
    '{"content":[${_adjustmentJson(status: status)}],"number":0,"size":20,"totalElements":1,"totalPages":1}';

String _adjustmentJson({required String status}) =>
    '''
{
  "id": 42,
  "customStudentId": "STU-001",
  "studentId": 9,
  "studentName": "Kwame Yaw Asante",
  "termId": 44,
  "termName": "Second Term",
  "feeId": 5,
  "feeName": "Tuition fee",
  "adjustmentTypeId": 1,
  "adjustmentType": "Discount",
  "amount": -50,
  "description": "Sibling discount",
  "status": "$status",
  "createdByType": "ADMINISTRATOR",
  "createdById": 7,
  "createdDate": "2026-07-18T10:30:00",
  "updatedByType": "",
  "updatedById": null,
  "updatedDate": null
}
''';
