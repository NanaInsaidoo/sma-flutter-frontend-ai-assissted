import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/domain/fee_models.dart';
import 'package:school_management_app/src/fees/presentation/fee_management_screen.dart';

void main() {
  testWidgets(
    'household collects one explicitly selected item and resets for the next payment',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var posts = 0;
      String? posted;
      final student = {
        'customStudentId': 'STU-1',
        'studentName': 'Ama',
        'balance': 80,
        'items': [
          {'assessmentId': 71, 'feeName': 'Tuition', 'outstandingAmount': 60},
          {'assessmentId': 72, 'feeName': 'Books', 'outstandingAmount': 20},
        ],
      };
      final api = FeeApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          final path = request.url.path;
          Object response;
          if (path.endsWith('/academic-context/current')) {
            response = {'id': 1, 'name': 'First Term'};
          } else if (path.contains('/households/')) {
            response = {
              'householdId': 9,
              'termId': 1,
              'students': [
                student,
                {...student, 'customStudentId': 'STU-2', 'studentName': 'Kojo'},
              ],
            };
          } else if (path.endsWith('/allocation-options')) {
            response = student;
          } else if (path.endsWith('/payment-methods')) {
            response = [
              {'id': 1, 'method': 'Cash'},
            ];
          } else if (path.endsWith('/api/payments') &&
              request.method == 'POST') {
            posts++;
            posted = request.body;
            response = {
              'paymentId': 1,
              'receiptNumber': 'TEST-RECEIPT',
              'studentName': 'Ama',
              'amount': 15,
              'paymentMethod': 'Cash',
              'status': 'COMPLETED',
              'balance': 65,
            };
          } else {
            return http.Response('Unexpected request: $path', 404);
          }
          return http.Response(jsonEncode(response), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showHouseholdFeeCollection(
                  context: context,
                  api: api,
                  customSchoolId: 'SCH-1',
                  householdId: 9,
                ),
                child: const Text('Receive payment'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Receive payment'));
      await tester.pumpAndSettle();
      expect(find.text('Collect Fees'), findsOneWidget);
      expect(find.textContaining('Split'), findsNothing);
      final amount = find.byKey(const ValueKey('payment-amount'));
      String amountText() =>
          tester.widget<TextFormField>(amount).controller!.text;
      await tester.enterText(
        find.byKey(const ValueKey('payment-student-search')),
        'Am',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ama'), findsOneWidget);
      await tester.tap(find.text('Ama'));
      await tester.pumpAndSettle();
      expect(amountText(), isEmpty);
      await tester.tap(find.text('Save Payment'));
      await tester.pumpAndSettle();
      expect(find.text('Select the fee item being paid.'), findsOneWidget);
      expect(posts, 0);
      final feeField = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<int>,
      );
      await tester.ensureVisible(feeField);
      await tester.tap(feeField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuition · GH₵ 60.00 due').last);
      await tester.pumpAndSettle();
      expect(amountText(), isEmpty);
      await tester.enterText(amount, '15');
      final methodField = find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String>,
      );
      await tester.ensureVisible(methodField);
      await tester.tap(methodField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash').last);
      await tester.pumpAndSettle();
      final receiptField = find.widgetWithText(
        TextFormField,
        'Physical Receipt Number *',
      );
      await tester.ensureVisible(receiptField);
      await tester.enterText(receiptField, 'TEST-PAPER-1');
      const pickerChannel = MethodChannel(
        'miguelruivo.flutter.plugins.filepicker',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var fileName = 'receipt.docx';
      messenger.setMockMethodCallHandler(pickerChannel, (call) async {
        expect(
          call.arguments['allowedExtensions'],
          containsAll(['pdf', 'doc', 'docx', 'jpg', 'png']),
        );
        expect(call.arguments['allowMultipleSelection'], false);
        return [
          {
            'name': fileName,
            'size': 3,
            'bytes': Uint8List.fromList([1, 2, 3]),
          },
        ];
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(pickerChannel, null),
      );
      await tester.ensureVisible(find.text('Attach'));
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();
      expect(find.text('receipt.docx'), findsOneWidget);
      fileName = 'receipt.pdf';
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(find.text('receipt.pdf'), findsOneWidget);
      expect(find.text('receipt.docx'), findsNothing);
      await tester.tap(find.byTooltip('Remove receipt attachment'));
      await tester.pumpAndSettle();
      expect(find.text('Physical receipt (optional)'), findsOneWidget);
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Payment'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(posted, contains('name="assessmentId"\r\n\r\n71'));
      expect(posted, contains('name="amount"\r\n\r\n15.00'));
      expect(posted, contains('name="customStudentId"\r\n\r\nSTU-1'));
      expect(posted, contains('filename="receipt.pdf"'));
      expect(find.text('Tuition'), findsOneWidget);
      expect(find.text('Receipt TEST-RECEIPT'), findsOneWidget);
      await tester.ensureVisible(find.text('Record another'));
      await tester.tap(find.text('Record another'));
      await tester.pumpAndSettle();
      expect(amountText(), isEmpty);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('payment-student-search')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  }.entries) {
    test(
      'receipt ${entry.key} uses correct media type and upload errors never drop the attachment',
      () async {
        var attempts = 0;
        final api = FeeApiClient(
          accessToken: 'test-token',
          client: MockClient((request) async {
            attempts++;
            expect(request.body, contains('Content-Type: ${entry.value}'));
            expect(request.body, contains('filename="receipt.${entry.key}"'));
            expect(request.body, contains('name="assessmentId"\r\n\r\n71'));
            return http.Response(
              jsonEncode({'message': 'Failed to upload receipt photo'}),
              400,
            );
          }),
        );
        await expectLater(
          api.recordPayment(
            FeePaymentRequest(
              assessmentId: 71,
              customStudentId: 'STU-1',
              customSchoolId: 'SCH-1',
              payerName: 'Ama',
              amount: 15,
              paymentDate: DateTime(2026, 8, 30),
              paymentMethodId: 1,
              referenceNumber: 'PAPER-1',
              receivedBy: 'Admin',
              description: '',
              termId: 1,
              physicalReceiptNumber: 'PAPER-1',
              idempotencyKey: 'test-key',
              receiptPhotoBytes: [1, 2, 3],
              receiptPhotoFileName: 'receipt.${entry.key}',
            ),
          ),
          throwsA(isA<FeeApiException>()),
        );
        expect(attempts, 1);
      },
    );
  }
}
