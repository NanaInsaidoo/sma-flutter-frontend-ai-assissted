import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/presentation/fee_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets(
    'student quick action opens fee collection with student selected',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/allocation-options')) {
          return http.Response(
            jsonEncode({
              'customStudentId': 'STU-001',
              'studentName': 'Ama Mensah',
              'balance': 800,
              'items': [
                {
                  'assessmentId': 71,
                  'feeName': 'Tuition',
                  'outstandingAmount': 600,
                },
                {
                  'assessmentId': 72,
                  'feeName': 'Transport',
                  'outstandingAmount': 200,
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/academic-context/current')) {
          return http.Response(
            jsonEncode({
              'academicTerm': {
                'id': 44,
                'termType': {'name': 'First Term'},
              },
              'academicYear': {'year': '2026-2027'},
            }),
            200,
          );
        }
        if (path.endsWith('/api/academic-terms')) {
          return http.Response(
            jsonEncode([
              {
                'id': 44,
                'termName': 'First Term',
                'academicYear': '2026-2027',
                'isCurrentTerm': true,
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/fee-management/overview')) {
          return http.Response(
            jsonEncode({
              'termId': 44,
              'termName': 'First Term',
              'academicYear': '2026-2027',
              'collectionByClass': <dynamic>[],
              'outstandingArrears': <dynamic>[],
            }),
            200,
          );
        }
        if (path.endsWith('/fee-management/students')) {
          final search = request.url.queryParameters['search'];
          if (search != null) {
            expect(search, 'STU-001');
          }
          return http.Response(
            jsonEncode({
              'content': [
                {
                  'studentId': 1,
                  'customStudentId': 'STU-001',
                  'studentName': 'Ama Mensah',
                  'gradeLevelId': 7,
                  'className': 'Basic 6 · Stream A',
                  'totalFees': 1200,
                  'totalAdjustments': 0,
                  'paid': 400,
                  'balance': 800,
                  'paymentStatus': 'PARTIAL',
                },
              ],
              'totalElements': 1,
              'totalPages': 1,
              'currentPage': 0,
              'pageSize': 100,
            }),
            200,
          );
        }
        if (path.endsWith('/api/lookup/payment-methods')) {
          return http.Response(
            jsonEncode([
              {'id': 1, 'method': 'Cash', 'description': 'Cash payment'},
            ]),
            200,
          );
        }
        return http.Response('Not found: $path', 404);
      });
      var requestConsumed = false;
      var openRequest = true;
      String? requestedStudentId = 'STU-001';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FeeManagementScreen(
                customSchoolId: 'SCH-001',
                schoolName: 'Test School',
                accessToken: 'token',
                openRecordPaymentOnLoad: openRequest,
                recordPaymentStudentId: requestedStudentId,
                onRecordPaymentRequestConsumed: () {
                  requestConsumed = true;
                  setState(() {
                    openRequest = false;
                    requestedStudentId = null;
                  });
                },
                api: FeeApiClient(accessToken: 'token', client: client),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestConsumed, isTrue);
      expect(find.text('Collect Fees'), findsOneWidget);
      expect(find.text('Collecting fees from Ama Mensah'), findsOneWidget);
      expect(
        find.textContaining('STU-001 · Basic 6 · Stream A'),
        findsOneWidget,
      );
      final scopedAmountField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('payment-amount')),
          matching: find.byType(EditableText),
        ),
      );
      expect(scopedAmountField.focusNode.hasFocus, isTrue);
      expect(scopedAmountField.controller.text, isEmpty);
      expect(find.text('Fee item *'), findsOneWidget);
      await tester.tap(find.text('Save Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Select the fee item being paid.'), findsOneWidget);
      final feeField = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<int>,
      );
      await tester.ensureVisible(feeField);
      await tester.tap(feeField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuition · GH₵ 600.00 due').last);
      await tester.pumpAndSettle();
      expect(scopedAmountField.controller.text, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('payment-amount')),
        '1000',
      );
      await tester.pump();
      expect(
        find.text('Amount exceeds the selected fee item’s balance.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('overpayment-warning')), findsNothing);
      expect(find.text('Physical receipt (optional)'), findsOneWidget);
      expect(
        find.text('Images, PDF, DOC or DOCX · up to 5 MB.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FeeManagementScreen(
              key: const ValueKey('general-collection-screen'),
              customSchoolId: 'SCH-001',
              schoolName: 'Test School',
              accessToken: 'token',
              openRecordPaymentOnLoad: true,
              api: FeeApiClient(accessToken: 'token', client: client),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final studentSearchField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('payment-student-search')),
          matching: find.byType(EditableText),
        ),
      );
      expect(studentSearchField.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
