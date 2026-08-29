import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/expenses/data/finance_api_client.dart';
import 'package:school_management_app/src/expenses/presentation/expenses_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('expense quick action opens a new requisition after loading', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      final body = request.url.path.endsWith('/academic-context/current')
          ? {
              'data': {'academicTermId': 10},
            }
          : request.url.path.endsWith('/finance/overview')
          ? {
              'data': {
                'cycle': {'status': 'ACTIVE'},
                'pockets': {'cash': 1000, 'momo': 500},
              },
            }
          : {'data': <dynamic>[]};
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    var consumed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            role: 'BURSAR',
            openNewRequisitionOnLoad: true,
            onNewRequisitionRequestConsumed: () => consumed = true,
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(consumed, isTrue);
    expect(find.text('New requisition'), findsWidgets);
    expect(find.text('Request approval before spending.'), findsOneWidget);
    expect(find.text('Submit request'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
