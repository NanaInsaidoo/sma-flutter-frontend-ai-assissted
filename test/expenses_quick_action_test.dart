import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/approvals/data/approval_api_client.dart';
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
                'cycle': {
                  'status': 'ACTIVE',
                  'floatCeiling': 300,
                  'requisitionExpiryDays': 7,
                  'autoApprovePettyCash': true,
                  'autoApprovalLimit': 50,
                },
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
    for (final tab in const [
      'Overview',
      'Requisitions',
      'School Expenses',
      'Petty Cash',
      'Approvals',
      'Reports',
    ]) {
      expect(find.text(tab), findsWidgets);
    }
    expect(find.text('How will this purchase be funded?'), findsOneWidget);
    expect(find.text('School funds'), findsWidgets);
    expect(find.text('Petty cash'), findsWidgets);
    await tester.tap(find.text('Petty cash').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Cash or MoMo pocket balance is checked when actual spending is recorded',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Standard requests up to GH¢50 may be approved automatically',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Submit request'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a description.'), findsOneWidget);
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect(find.text('Select a category.'), findsOneWidget);
    expect(find.text('Explain why this request is needed.'), findsOneWidget);
    expect(find.text('Select an approver.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Expense register'), findsNothing);
    expect(find.text('Financial follow-ups'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top-up requester cannot select themselves as the approver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {
            'id': 12,
            'status': 'ACTIVE',
            'floatApprovedAmount': 1000,
            'floatCeiling': 300,
          },
          'pockets': {'cash': 0, 'momo': 0},
        };
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {
          'approvers': [
            {
              'id': 7,
              'name': 'Adjoa Mensah',
              'username': 'adjoa',
              'role': 'ADMINISTRATOR',
            },
            {
              'id': 8,
              'name': 'Kofi Nketia',
              'username': 'kofi',
              'role': 'ADMINISTRATOR',
            },
          ],
          'disbursers': <dynamic>[],
        };
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            recordedBy: 'Adjoa Mensah',
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();
    final requestTopUp = find.text('Request top-up');
    await tester.ensureVisible(requestTopUp);
    await tester.tap(requestTopUp);
    await tester.pumpAndSettle();

    expect(find.text('Request petty-cash top-up'), findsOneWidget);
    expect(
      find.textContaining('the requester cannot approve their own top-up'),
      findsOneWidget,
    );
    expect(find.text('Choose someone other than yourself.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('top-up-request-approver')));
    await tester.pumpAndSettle();
    expect(find.text('Kofi Nketia · ADMINISTRATOR'), findsOneWidget);
    expect(find.text('Adjoa Mensah · ADMINISTRATOR'), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'top-up request shows a blocking dialog when no independent approver exists',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {
              'id': 12,
              'status': 'ACTIVE',
              'floatApprovedAmount': 1000,
              'floatCeiling': 300,
            },
            'pockets': {'cash': 0, 'momo': 0},
          };
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {
            'approvers': [
              {
                'id': 7,
                'name': 'Adjoa Mensah',
                'username': 'adjoa',
                'role': 'ADMINISTRATOR',
              },
            ],
            'disbursers': <dynamic>[],
          };
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 7,
              role: 'ADMINISTRATOR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Petty Cash'));
      await tester.pumpAndSettle();
      final requestTopUp = find.text('Request top-up');
      await tester.ensureVisible(requestTopUp);
      await tester.tap(requestTopUp);
      await tester.pumpAndSettle();

      expect(find.text('Independent approver required'), findsOneWidget);
      expect(
        find.textContaining('You cannot approve your own top-up request'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Okay'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'assigned disburser can submit a cash and MoMo split without a UI error',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var disbursed = false;
      Map<String, dynamic>? disbursementBody;
      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {'status': 'ACTIVE', 'momoWalletNumber': '0240000000'},
            'pockets': {'cash': 100, 'momo': 50},
          };
        } else if (request.url.path.endsWith('/finance/top-ups')) {
          data = [
            {
              'id': 71,
              'transactionCode': 'TOP-71',
              'status': disbursed ? 'DISBURSED' : 'APPROVED',
              'requestedAmount': 1000,
              'approvedAmount': 1000,
              'requestedAt': '2026-09-10T09:00:00',
              'requesterName': 'Kofi Nketia',
              'requesterUserId': 88,
              'approverName': 'Head Teacher',
              'approverUserId': 99,
              'disburserName': 'Adjoa Mensah',
              'disburserUserId': 7,
              'receiverName': 'Kofi Nketia',
              'receiverUserId': 88,
              if (disbursed) 'cashAmount': 600,
              if (disbursed) 'momoAmount': 400,
              if (disbursed) 'momoWalletNumber': '0240000000',
            },
          ];
        } else if (request.url.path.endsWith('/finance/top-ups/71/disburse')) {
          disbursementBody = jsonDecode(request.body) as Map<String, dynamic>;
          disbursed = true;
          data = <String, dynamic>{};
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 7,
              role: 'BURSAR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('expense-tab-badge-Approvals')),
        findsOneWidget,
      );
      expect(find.text('1'), findsWidgets);

      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();
      expect(find.text('Disburse TOP-71'), findsOneWidget);
      expect(find.text('Approval history'), findsOneWidget);
      expect(find.text('TOP-71 · Petty-cash top-up'), findsOneWidget);
      expect(find.textContaining('Approved by Head Teacher'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'approvals queue');

      await tester.tap(find.widgetWithText(FilledButton, 'Disburse'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'disbursement dialog');
      final cash = find.byKey(const ValueKey('disbursement-cash-amount'));
      final momo = find.byKey(const ValueKey('disbursement-momo-amount'));
      await tester.enterText(cash, '600');
      expect(tester.takeException(), isNull, reason: 'cash edit');
      await tester.enterText(momo, '400');
      await tester.pump();

      expect(tester.widget<TextFormField>(cash).controller?.text, '600');
      expect(tester.widget<TextFormField>(momo).controller?.text, '400');
      expect(find.text('MoMo wallet number'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'MoMo edit');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'MoMo wallet number'),
        '0240000000',
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm disbursement'),
      );
      await tester.pump();
      final noteError = find.text('Add a disbursement note.');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('disbursement-reference')),
          matching: noteError,
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('disbursement-note')),
          matching: noteError,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Select receiver of funds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kofi Nketia · Requester').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Disbursement note'),
        'Mixed cash and MoMo disbursement.',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm disbursement'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'mixed disbursement');
      expect(
        find.text('Confirm the requester as the receiver of funds.'),
        findsNothing,
      );
      expect(find.text('Cash and MoMo must total GH¢1000.'), findsNothing);
      expect(find.text('Enter the MoMo wallet number.'), findsNothing);
      expect(find.text('Add a disbursement note.'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Confirm disbursement'),
        findsNothing,
        reason: 'the valid form should close after submission',
      );
      expect(disbursementBody?['cashAmount'], 600);
      expect(disbursementBody?['momoAmount'], 400);
      expect(disbursementBody?['receiverUserId'], 88);
      expect(find.text('Disburse TOP-71'), findsNothing);
    },
  );

  testWidgets(
    'top-up approver reviews a concise dialog before approval and disbursement',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var approved = false;
      var approvalCalls = 0;
      Map<String, dynamic>? approvalBody;
      Map<String, dynamic> topUp() => {
        'id': 72,
        'transactionCode': 'TOP-REVIEW-72',
        'status': approved ? 'APPROVED' : 'PENDING',
        'requestedAmount': 2000,
        if (approved) 'approvedAmount': 2000,
        'requestedAt': '2026-09-13T09:00:00',
        'createdAt': '2026-09-13T09:00:00',
        'updatedAt': approved ? '2026-09-13T10:00:00' : '2026-09-13T09:00:00',
        'requesterName': 'Adjoa Mensah',
        'requesterUserId': 8,
        'approverName': 'Kofi Approver',
        'approverUserId': 7,
        if (approved) 'approvedAt': '2026-09-13T10:00:00',
        if (approved) 'disburserName': 'Kofi Approver',
        if (approved) 'disburserUserId': 7,
        'expensesCount': 0,
      };

      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {
              'id': 12,
              'status': 'ACTIVE',
              'floatApprovedAmount': 2000,
            },
            'pockets': {'cash': 0, 'momo': 0},
          };
        } else if (request.method == 'POST' &&
            request.url.path.endsWith('/finance/top-ups/72/approve')) {
          approvalCalls++;
          approvalBody = jsonDecode(request.body) as Map<String, dynamic>;
          approved = true;
          data = topUp();
        } else if (request.url.path.endsWith('/finance/top-ups/72/events')) {
          data = [
            {
              'eventType': 'REQUESTED',
              'actor': 'Adjoa Mensah',
              'note': 'Restore the float for approved petty-cash spending.',
              'createdAt': '2026-09-13T09:00:00',
            },
            if (approved)
              {
                'eventType': 'APPROVED',
                'actor': 'Kofi Approver',
                'note': 'Request and supporting records verified.',
                'createdAt': '2026-09-13T10:00:00',
              },
          ];
        } else if (request.url.path.endsWith('/finance/top-ups')) {
          data = [topUp()];
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {
            'approvers': [
              {
                'id': 7,
                'name': 'Kofi Approver',
                'username': 'kofi',
                'role': 'ADMINISTRATOR',
              },
            ],
            'disbursers': [
              {
                'id': 7,
                'name': 'Kofi Approver',
                'username': 'kofi',
                'role': 'ADMINISTRATOR',
              },
            ],
          };
        } else if (request.url.path.endsWith('/finance/requisitions')) {
          data = {'content': <dynamic>[]};
        } else if (request.url.path.endsWith('/finance/transactions')) {
          data = {'content': <dynamic>[]};
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 7,
              role: 'ADMINISTRATOR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('TOP-REVIEW-72'), findsOneWidget);
      expect(find.text('GH¢2000'), findsOneWidget);
      expect(
        find.textContaining('Top-up request · Requested by Adjoa Mensah'),
        findsOneWidget,
      );
      expect(find.text('Review request'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
      expect(approvalCalls, 0);

      await tester.tap(find.byKey(const ValueKey('review-top-up-72')));
      await tester.pumpAndSettle();

      expect(
        find.text('Review this petty cash top-up before approval.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('TOP-REVIEW-72'),
        ),
        findsOneWidget,
      );
      expect(find.text('Top-up requested'), findsOneWidget);
      expect(find.text('REQUEST SUMMARY'), findsOneWidget);
      expect(find.text('REQUEST REASON'), findsOneWidget);
      expect(
        find.text('Restore the float for approved petty-cash spending.'),
        findsOneWidget,
      );
      expect(find.text('Current float'), findsOneWidget);
      expect(find.text('Float after top-up'), findsOneWidget);
      expect(find.text('Approved float'), findsOneWidget);
      expect(find.text('How this request moves'), findsNothing);
      expect(find.text('Approval & disbursement history'), findsNothing);
      expect(find.text('Cycle transactions'), findsNothing);
      expect(approvalCalls, 0);

      await tester.tap(find.byKey(const ValueKey('top-up-approval-disburser')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kofi Approver · ADMINISTRATOR').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('top-up-approval-note')),
        'Request and supporting records verified.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Approve request'));
      await tester.pumpAndSettle();

      expect(approvalCalls, 1);
      expect(approvalBody?['disburserUserId'], 7);
      expect(
        approvalBody?['notes'],
        'Request and supporting records verified.',
      );
      expect(find.widgetWithText(FilledButton, 'Disburse'), findsOneWidget);
      expect(
        find.text('Review this petty cash top-up before approval.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('approver must confirm before a requisition is approved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var approved = false;
    var approvalCalls = 0;
    Map<String, dynamic>? approvalBody;
    Map<String, dynamic> requisition() => {
      'id': 91,
      'requisitionCode': 'REQ-CONFIRM-1',
      'description': 'Science materials',
      'category': 'Supplies',
      'vendor': 'School supplier',
      'requestedBy': 'Ama Requester',
      'requesterUserId': 8,
      'approverName': 'Kofi Approver',
      'approverUserId': 7,
      'requestedAmount': 450,
      'approvedAmount': approved ? 450 : null,
      'requestedAt': '2026-09-10T09:00:00',
      'approvedAt': approved ? '2026-09-10T10:00:00' : null,
      'updatedAt': '2026-09-10T10:00:00',
      'status': approved ? 'APPROVED' : 'PENDING',
      'fundingSource': 'SCHOOL_FUNDS',
      'reason': 'Required for the science practical.',
    };

    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE'},
          'pockets': {'cash': 500, 'momo': 100},
        };
      } else if (request.method == 'GET' &&
          request.url.path.endsWith('/finance/requisitions')) {
        data = {
          'content': [requisition()],
        };
      } else if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/requisitions/91/approve')) {
        approvalCalls++;
        approvalBody = jsonDecode(request.body) as Map<String, dynamic>;
        approved = true;
        data = requisition();
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approvals'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(approvalCalls, 0);
    expect(find.text('Confirm requisition approval'), findsOneWidget);
    expect(find.text('REQ-CONFIRM-1'), findsOneWidget);
    expect(find.text('GH¢450'), findsOneWidget);
    expect(find.text('Ama Requester'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirm approval'));
    await tester.pumpAndSettle();

    expect(approvalCalls, 0);
    expect(find.text('Add an approval note.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Approval note *'),
      'Budget and request details verified.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm approval'));
    await tester.pumpAndSettle();

    expect(approvalCalls, 1);
    expect(approvalBody?['notes'], 'Budget and request details verified.');
    expect(find.text('No finance actions waiting'), findsOneWidget);
    expect(find.text('REQ-CONFIRM-1 · Science materials'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ratification shows the request and spend before affirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var ratified = false;
    var ratificationCalls = 0;
    Map<String, dynamic>? ratificationBody;
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE'},
          'pockets': {'cash': 500, 'momo': 300},
        };
      } else if (request.url.path.endsWith('/finance/requisitions')) {
        data = {
          'content': [
            {
              'id': 201,
              'requisitionCode': 'REQ-EMERGENCY-201',
              'description': 'Urgent plumbing repair',
              'category': 'Repairs & Maintenance',
              'vendor': 'Julius the plumber',
              'requestedBy': 'Adjoa Mensah',
              'requesterUserId': 8,
              'approverName': 'Kofi Approver',
              'approverUserId': 7,
              'requestedAmount': 90,
              'requestedAt': '2026-09-14T09:00:00',
              'updatedAt': '2026-09-14T09:00:00',
              'status': 'APPROVED',
              'fundingSource': 'PETTY_CASH',
              'reason': 'Stop an active leak in the kitchen.',
              'emergency': true,
              'verbalApprover': 'Yaw Asante',
            },
          ],
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {
          'content': [
            {
              'id': 601,
              'transactionCode': 'EXP-EMERGENCY-601',
              'transactionType': 'EXPENSE',
              'requisitionId': 201,
              'description': 'Urgent plumbing repair',
              'category': 'Repairs & Maintenance',
              'vendor': 'Julius the plumber',
              'requestedAmount': 90,
              'actualAmount': 110,
              'sourcePocket': 'MOMO',
              'paymentChannel': 'MOMO',
              'status': ratified ? 'RATIFIED' : 'PENDING_RATIFICATION',
              'requiresRatification': !ratified,
              'emergency': true,
              'receiptNumber': 'MOMO-7781',
              'receiptStorageKey': 'finance/SCH-001/receipts/601.pdf',
              'receiptFileName': 'plumbing-receipt.pdf',
              'transactionDate': '2026-09-14',
            },
          ],
        };
      } else if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/transactions/601/ratify')) {
        ratificationCalls++;
        ratificationBody = jsonDecode(request.body) as Map<String, dynamic>;
        ratified = true;
        data = <String, dynamic>{};
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approvals'));
    await tester.pumpAndSettle();

    expect(
      find.text('Urgent plumbing repair requires ratification'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ratify'));
    await tester.pumpAndSettle();

    expect(find.text('Review emergency expense'), findsOneWidget);
    expect(
      find.text('EXP-EMERGENCY-601 · approval after payment'),
      findsOneWidget,
    );
    expect(find.text('APPROVAL CHECK'), findsOneWidget);
    expect(find.text('Amount requested'), findsOneWidget);
    expect(find.text('GH¢90'), findsOneWidget);
    expect(find.text('Amount spent'), findsWidgets);
    expect(find.text('GH¢110'), findsWidgets);
    expect(find.text('Julius the plumber'), findsOneWidget);
    expect(find.text('Float - MoMo'), findsWidgets);
    expect(find.text('MOMO-7781'), findsOneWidget);
    expect(find.text('View receipt'), findsOneWidget);
    expect(find.text('Given by Yaw Asante'), findsOneWidget);
    expect(ratificationCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Affirm and ratify'));
    await tester.pumpAndSettle();
    expect(ratificationCalls, 0);
    expect(
      find.text('Confirm the approval statement before ratifying.'),
      findsOneWidget,
    );
    expect(
      find.text('Add a ratification note before continuing.'),
      findsOneWidget,
    );

    final affirmation = find.descendant(
      of: find.byKey(const ValueKey('ratification-affirmation')),
      matching: find.byType(Checkbox),
    );
    await tester.ensureVisible(affirmation);
    await tester.pumpAndSettle();
    await tester.tap(affirmation);
    final approvalNote = find.widgetWithText(TextFormField, 'Approval note *');
    await tester.ensureVisible(approvalNote);
    await tester.pumpAndSettle();
    await tester.enterText(
      approvalNote,
      'Emergency need and prior verbal authorisation verified.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Affirm and ratify'));
    await tester.pumpAndSettle();

    expect(ratificationCalls, 1);
    expect(
      ratificationBody?['note'],
      'Emergency need and prior verbal authorisation verified.',
    );
    expect(find.text('Review emergency expense'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual spend shows balances and requires variance affirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var actualSpendCalls = 0;
    Map<String, dynamic>? actualSpendBody;
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {
            'id': 12,
            'status': 'ACTIVE',
            'floatCeiling': 2000,
            'varianceTolerancePercent': 5,
            'captureTransactionFees': true,
          },
          'pockets': {'cash': 400, 'momo': 1500},
        };
      } else if (request.url.path.endsWith('/finance/requisitions')) {
        data = {
          'content': [
            {
              'id': 92,
              'requisitionCode': 'REQ-BALANCE-1',
              'description': 'Office supplies',
              'category': 'Supplies',
              'vendor': 'School supplier',
              'requestedBy': 'Ama Requester',
              'requesterUserId': 7,
              'approverName': 'Kofi Approver',
              'approverUserId': 8,
              'requestedAmount': 100,
              'approvedAmount': 100,
              'requestedAt': '2026-09-10T09:00:00',
              'approvedAt': '2026-09-10T10:00:00',
              'expiresAt': '2099-09-17T09:00:00',
              'status': 'APPROVED',
              'fundingSource': 'PETTY_CASH',
              'reason': 'Needed for daily administration.',
            },
          ],
        };
      } else if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/requisitions/92/actual-spend')) {
        actualSpendCalls += 1;
        actualSpendBody = jsonDecode(request.body) as Map<String, dynamic>;
        data = <String, dynamic>{};
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requisitions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record actual spend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record actual spend'));
    await tester.pumpAndSettle();

    final expenseFields = find.byType(TextFormField);
    EditableText editableTextAt(int index) => tester.widget<EditableText>(
      find.descendant(
        of: expenseFields.at(index),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableTextAt(0).readOnly, isTrue);
    expect(editableTextAt(2).readOnly, isTrue);
    expect(find.text('Float - Cash · GH¢400 available'), findsOneWidget);
    await tester.tap(find.text('Float - Cash · GH¢400 available'));
    await tester.pumpAndSettle();
    expect(find.text('Float - MoMo · GH¢1500 available'), findsOneWidget);
    await tester.tap(find.text('Float - MoMo · GH¢1500 available'));
    await tester.pumpAndSettle();
    expect(find.text('Were there MoMo charges?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('momo-charge-yes')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('momo-charge-amount')),
      '5',
    );
    await tester.enterText(expenseFields.at(1), '80');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Variance check')).style?.color,
      AppColors.red,
    );
    await tester.ensureVisible(find.text('Record spend'));
    await tester.tap(find.text('Record spend'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm actual spend'), findsOneWidget);
    expect(find.text('Float - MoMo · GH¢5 charge'), findsOneWidget);
    expect(find.text('Total MoMo deduction'), findsOneWidget);
    expect(find.text('GH¢85'), findsOneWidget);
    expect(find.textContaining('Variance review required.'), findsOneWidget);
    expect(actualSpendCalls, 0);

    await tester.tap(find.text('Affirm and record'));
    await tester.pumpAndSettle();
    expect(actualSpendCalls, 1);
    expect(actualSpendBody?['actualAmount'], 80);
    expect(actualSpendBody?['feeAmount'], 5);
    expect(actualSpendBody?['paymentChannel'], 'MOMO');
    expect(tester.takeException(), isNull);
  });

  testWidgets('school expense can be recorded with cash payment method', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? actualSpendBody;
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {
            'id': 12,
            'status': 'ACTIVE',
            'varianceTolerancePercent': 5,
          },
          'pockets': {'cash': 400, 'momo': 1500},
        };
      } else if (request.url.path.endsWith('/finance/requisitions')) {
        data = {
          'content': [
            {
              'id': 93,
              'requisitionCode': 'REQ-SCHOOL-CASH',
              'description': 'School bus repair',
              'category': 'Repairs & Maintenance',
              'vendor': 'Toyota',
              'requestedBy': 'Ama Requester',
              'requesterUserId': 7,
              'approverName': 'Kofi Approver',
              'approverUserId': 8,
              'requestedAmount': 30000,
              'approvedAmount': 30000,
              'requestedAt': '2026-09-10T09:00:00',
              'approvedAt': '2026-09-10T10:00:00',
              'expiresAt': '2099-09-17T09:00:00',
              'status': 'APPROVED',
              'fundingSource': 'SCHOOL_FUNDS',
              'reason': 'Repair the school bus.',
            },
          ],
        };
      } else if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/requisitions/93/actual-spend')) {
        actualSpendBody = jsonDecode(request.body) as Map<String, dynamic>;
        data = <String, dynamic>{};
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requisitions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record actual spend'));
    await tester.tap(find.text('Record actual spend'));
    await tester.pumpAndSettle();

    expect(find.text('Payment method'), findsOneWidget);
    await tester.tap(find.text('Bank transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Cash'), findsWidgets);
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record spend'));
    await tester.tap(find.text('Record spend'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm actual spend'), findsOneWidget);
    expect(find.text('Payment method'), findsWidgets);
    expect(find.text('Cash'), findsWidgets);
    await tester.tap(find.text('Confirm and record'));
    await tester.pumpAndSettle();

    expect(actualSpendBody?['paymentChannel'], 'SCHOOL_CASH');
    expect(actualSpendBody?.containsKey('pocket'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pocket transfer requires a concise final confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var transferCalls = 0;
    Map<String, dynamic>? transferBody;
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {
            'id': 12,
            'status': 'ACTIVE',
            'floatApprovedAmount': 2000,
            'floatCeiling': 2000,
          },
          'pockets': {'cash': 400, 'momo': 1500},
        };
      } else if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/pocket-transfers')) {
        transferCalls += 1;
        transferBody = jsonDecode(request.body) as Map<String, dynamic>;
        data = <String, dynamic>{};
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 1,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer pocket'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '200');
    await tester.enterText(fields.at(1), 'Agent withdrawal 001');
    await tester.enterText(fields.at(2), '10');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record transfer'));
    await tester.tap(find.text('Record transfer'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm pocket transfer'), findsOneWidget);
    expect(find.text('MoMo to Cash'), findsWidgets);
    expect(find.text('GH¢600'), findsOneWidget);
    expect(find.text('GH¢1290'), findsOneWidget);
    expect(find.text('GH¢1890'), findsWidgets);
    expect(
      find.text(
        'I confirm that this transfer direction and amount are correct.',
      ),
      findsOneWidget,
    );
    expect(transferCalls, 0);

    await tester.tap(find.text('Confirm transfer'));
    await tester.pumpAndSettle();
    expect(transferCalls, 1);
    expect(transferBody?['sourcePocket'], 'MOMO');
    expect(transferBody?['destinationPocket'], 'CASH');
    expect(transferBody?['amount'], 200);
    expect(transferBody?['feeAmount'], 10);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'variance review offers two outcomes and retains the audit note',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Map<String, dynamic>? reviewBody;
      final reviewHistory = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {'id': 12, 'status': 'ACTIVE'},
            'pockets': {'cash': 700, 'momo': 100},
          };
        } else if (request.url.path.endsWith('/finance/transactions')) {
          data = [
            {
              'id': 501,
              'transactionCode': 'EXP-VARIANCE-1',
              'transactionType': 'EXPENSE',
              'description': 'Repair classroom door',
              'category': 'Repairs & Maintenance',
              'vendor': 'School carpenter',
              'approvedAmount': 400,
              'actualAmount': 500,
              'sourcePocket': 'CASH',
              'paymentChannel': 'CASH',
              'status': 'TRANSACTION_PENDING_VARIANCE_REVIEW',
              'transactionDate': '2026-09-10',
            },
          ];
        } else if (request.method == 'POST' &&
            request.url.path.endsWith(
              '/finance/transactions/501/resolve-variance',
            )) {
          reviewBody = jsonDecode(request.body) as Map<String, dynamic>;
          reviewHistory.add({
            'eventType': 'VARIANCE_ACCEPTED',
            'author': 'Eric GoM',
            'note': reviewBody?['note'],
            'eventAmount': 100,
            'createdAt': '2026-09-10T13:00:00',
          });
          data = <String, dynamic>{};
        } else if (request.url.path.endsWith('/finance/notes')) {
          data = reviewHistory;
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 1,
              role: 'ADMINISTRATOR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approvals'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review variance'));
      await tester.pumpAndSettle();
      expect(find.text('Accept variance'), findsOneWidget);
      expect(find.text('Escalate to follow-up'), findsOneWidget);
      expect(find.text('Request correction'), findsNothing);
      await tester.ensureVisible(find.text('Save review'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(
        find.text('Add a review note to keep the decision auditable.'),
        findsOneWidget,
      );
      expect(reviewBody, isNull);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Review note *'),
        'The final supplier amount is valid.',
      );
      await tester.ensureVisible(find.text('Save review'));
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();

      expect(reviewBody?['outcome'], 'ACCEPT');
      expect(reviewBody?['note'], 'The final supplier amount is valid.');
      expect(find.text('Review variance'), findsOneWidget);

      await tester.ensureVisible(find.text('Review variance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review variance'));
      await tester.pumpAndSettle();
      expect(find.text('PREVIOUS REVIEW ACTIVITY'), findsOneWidget);
      expect(find.text('Variance accepted'), findsOneWidget);
      expect(
        find.textContaining('The final supplier amount is valid.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('petty cash shows audited administrator controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {
            'id': 12,
            'status': 'ACTIVE',
            'floatApprovedAmount': 1000,
            'floatCeiling': 300,
            'floatThreshold': 250,
            'varianceTolerancePercent': 5,
            'requisitionExpiryDays': 7,
            'autoApprovePettyCash': true,
            'autoApprovalLimit': 100,
            'captureTransactionFees': true,
            'selfDisburse': false,
          },
          'pockets': {'cash': 620, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/notes')) {
        data = [
          {
            'eventType': 'SETTINGS_UPDATED',
            'author': 'Eric GoM',
            'note': 'Automatic approval enabled up to GH₵ 100.00.',
            'createdAt': '2026-09-10T10:00:00',
          },
        ];
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 1,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();

    expect(find.text('GH¢720'), findsOneWidget);
    expect(find.text('Up to GH¢100'), findsOneWidget);
    expect(find.text('Request top-up'), findsOneWidget);
    expect(find.text('Request reconciliation'), findsNWidgets(2));
    expect(find.text('Petty cash controls'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Petty cash controls')).dy,
      lessThan(tester.getTopLeft(find.text('Petty cash expenses')).dy),
    );
    final settingsButton = find.text('Settings');
    await tester.ensureVisible(settingsButton);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();
    expect(find.text('Single petty-cash expense limit (GH¢)'), findsOneWidget);
    expect(find.text('Automatically approve small requests'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Settings updated'), findsOneWidget);
    expect(find.textContaining('Automatic approval enabled'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reconciliation request searches and selects eligible staff', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? submittedBody;
    final client = MockClient((request) async {
      dynamic data;
      if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/reconciliations')) {
        submittedBody = jsonDecode(request.body) as Map<String, dynamic>;
        data = {'id': 91};
      } else if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {
            'id': 12,
            'status': 'ACTIVE',
            'floatApprovedAmount': 1000,
            'floatCeiling': 300,
          },
          'pockets': {'cash': 600, 'momo': 200},
        };
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {
          'approvers': [
            {
              'id': 7,
              'name': 'Kofi Nketia',
              'username': 'kofi.nketia',
              'role': 'ADMINISTRATOR',
            },
          ],
          'disbursers': [
            {
              'id': 11,
              'name': 'Yaw Asante',
              'username': 'yaw.asante',
              'role': 'HEAD_TEACHER',
            },
          ],
        };
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            recordedBy: 'Kofi Nketia',
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request reconciliation').first);
    await tester.pumpAndSettle();

    final staffSearch = find.byKey(
      const ValueKey('reconciliation-assignee-search'),
    );
    expect(staffSearch, findsOneWidget);
    expect(find.text('Bursar / Accounts officer'), findsNothing);
    await tester.tap(staffSearch);
    await tester.pumpAndSettle();
    final searchInput = find.descendant(
      of: staffSearch,
      matching: find.byType(TextField),
    );
    await tester.enterText(searchInput, 'Yaw');
    await tester.pumpAndSettle();
    expect(find.text('Yaw Asante · HEAD_TEACHER · yaw.asante'), findsOneWidget);
    expect(find.textContaining('Kofi Nketia'), findsNothing);
    await tester.tap(find.text('Yaw Asante · HEAD_TEACHER · yaw.asante'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
    await tester.pumpAndSettle();

    expect(submittedBody, isNotNull);
    expect(submittedBody!['assignedToUserId'], 11);
    expect(submittedBody!['assignedTo'], 'Yaw Asante');
    expect(submittedBody!['reason'], 'Weekly petty cash close');
    expect(find.text('Request reconciliation'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'other reconciliation issue creates a follow-up without adjusting balances',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var followUpCalls = 0;
      var resolutionCalls = 0;
      Map<String, dynamic>? followUpBody;
      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {
              'id': 12,
              'status': 'ACTIVE',
              'floatApprovedAmount': 1000,
              'floatCeiling': 300,
            },
            'pockets': {'cash': 450, 'momo': 100},
          };
        } else if (request.url.path.endsWith('/finance/reconciliations')) {
          data = {
            'content': [
              {
                'id': 51,
                'reconciliationCode': 'REC-OTHER-51',
                'requestedAt': '2026-09-14T09:00:00',
                'requestedBy': 'Adjoa Mensah',
                'assignedTo': 'Administrator / Accounts',
                'reason': 'Routine cash count',
                'status': 'RECON_VARIANCE_OPEN',
                'expectedCash': 500,
                'expectedMomo': 100,
                'actualCash': 450,
                'actualMomo': 100,
                'confirmedAt': '2026-09-14T10:00:00',
              },
            ],
          };
        } else if (request.method == 'POST' &&
            request.url.path.endsWith('/finance/follow-ups')) {
          followUpCalls += 1;
          followUpBody = jsonDecode(request.body) as Map<String, dynamic>;
          data = {'id': 61, 'followUpCode': 'FUP-OTHER-61'};
        } else if (request.method == 'POST' &&
            request.url.path.contains('/finance/reconciliations/51/')) {
          resolutionCalls += 1;
          data = <String, dynamic>{};
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 1,
              role: 'ADMINISTRATOR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Petty Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reconciliations').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('REC-OTHER-51'));
      await tester.tap(find.text('REC-OTHER-51'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Close variance'));
      await tester.tap(find.text('Close variance'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Staff recovery'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other financial issue').last);
      await tester.pumpAndSettle();

      expect(find.text('Issue description'), findsOneWidget);
      expect(find.textContaining('leaves the variance open'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Create follow-up'));
      await tester.pumpAndSettle();
      expect(find.text('Describe the financial issue.'), findsOneWidget);
      expect(followUpCalls, 0);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Issue description'),
        'The source of the difference needs further investigation.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create follow-up'));
      await tester.pumpAndSettle();

      expect(followUpCalls, 1);
      expect(resolutionCalls, 0);
      expect(followUpBody?['type'], 'OTHER');
      expect(followUpBody?['relatedReference'], 'REC-OTHER-51');
      expect(
        followUpBody?['description'],
        'The source of the difference needs further investigation.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'requester edits a petty-cash requisition as a draft and resubmits it',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var status = 'PENDING';
      var editStarted = false;
      var draftUpdated = false;
      var resubmitted = false;
      Map<String, dynamic> requisition() => {
        'id': 81,
        'requisitionCode': 'REQ-EDIT-1',
        'description': 'Classroom markers',
        'category': 'Supplies',
        'vendor': 'Stationery shop',
        'requestedBy': 'requester@example.com',
        'requesterUserId': 7,
        'approverName': 'Adjoa Mensah',
        'approverUserId': 99,
        'requestedAmount': 120,
        'requestedAt': '2026-09-10T09:00:00',
        'expiresAt': status == 'DRAFT' ? null : '2026-09-17T09:00:00',
        'status': status,
        'fundingSource': 'PETTY_CASH',
        'reason': 'Markers are needed for lessons.',
        'notes': 'Markers are needed for lessons.',
        'emergency': false,
      };

      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {
              'status': 'ACTIVE',
              'floatApprovedAmount': 1000,
              'floatCeiling': 300,
              'floatThreshold': 250,
              'requisitionExpiryDays': 7,
              'autoApprovePettyCash': false,
            },
            'pockets': {'cash': 500, 'momo': 100},
          };
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {
            'approvers': [
              {
                'id': 99,
                'name': 'Adjoa Mensah',
                'username': 'adjoa@example.com',
                'role': 'HEAD_TEACHER',
              },
            ],
            'disbursers': <dynamic>[],
          };
        } else if (request.method == 'GET' &&
            request.url.path.endsWith('/finance/requisitions')) {
          data = {
            'content': [requisition()],
          };
        } else if (request.method == 'POST' &&
            request.url.path.endsWith('/finance/requisitions/81/edit')) {
          editStarted = true;
          status = 'DRAFT';
          data = requisition();
        } else if (request.method == 'PUT' &&
            request.url.path.endsWith('/finance/requisitions/81')) {
          draftUpdated = true;
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['fundingSource'], 'SCHOOL_FUNDS');
          expect(payload['requestedAmount'], 120);
          data = requisition();
        } else if (request.method == 'POST' &&
            request.url.path.endsWith('/finance/requisitions/81/submit')) {
          resubmitted = true;
          status = 'PENDING';
          data = requisition();
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 7,
              role: 'BURSAR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Requisitions'));
      await tester.pumpAndSettle();
      expect(find.text('Classroom markers'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit requisition'), findsOneWidget);
      expect(find.text('Cancel requisition'), findsOneWidget);
      await tester.tap(find.text('Edit requisition'));
      await tester.pumpAndSettle();

      expect(editStarted, isTrue);
      expect(find.text('Edit requisition'), findsOneWidget);
      expect(
        find.text(
          'REQ-EDIT-1 is now a draft. Save and resubmit it for approval.',
        ),
        findsOneWidget,
      );
      expect(find.text('Classroom markers'), findsWidgets);
      expect(find.text('Save and resubmit'), findsOneWidget);

      await tester.tap(find.text('School funds').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save and resubmit'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save and resubmit'));
      await tester.pumpAndSettle();

      expect(draftUpdated, isTrue);
      expect(resubmitted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'petty cash badges and overdue funds reminder show pending work',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final disbursedAt = DateTime.now()
          .subtract(const Duration(minutes: 25))
          .toIso8601String();
      Map<String, dynamic>? overageClosure;

      final client = MockClient((request) async {
        dynamic data;
        if (request.url.path.endsWith('/academic-context/current')) {
          data = {'academicTermId': 10};
        } else if (request.url.path.endsWith('/finance/overview')) {
          data = {
            'cycle': {
              'id': 12,
              'status': 'ACTIVE',
              'floatApprovedAmount': 1000,
            },
            'pockets': {'cash': 300, 'momo': 200},
          };
        } else if (request.url.path.endsWith('/finance/requisitions') ||
            request.url.path.endsWith('/finance/transactions')) {
          data = <dynamic>[];
        } else if (request.url.path.endsWith('/finance/reconciliations')) {
          data = [
            {
              'id': 71,
              'reconciliationCode': 'REC-71',
              'status': 'REQUESTED',
              'requestedAt': '2026-09-12T12:00:00',
            },
          ];
        } else if (request.method == 'POST' &&
            request.url.path.endsWith('/finance/follow-ups/81/close')) {
          overageClosure = jsonDecode(request.body) as Map<String, dynamic>;
          data = <String, dynamic>{};
        } else if (request.url.path.endsWith('/finance/follow-ups')) {
          data = [
            {
              'id': 81,
              'followUpCode': 'FUP-81',
              'type': 'FLOAT_OVERAGE',
              'status': 'OPEN',
              'amount': 50,
              'responsibleParty': 'Administrator / Accounts',
              'description': 'Move the excess out of petty cash.',
              'createdAt': '2026-09-12T12:00:00',
            },
          ];
        } else if (request.url.path.endsWith('/finance/top-ups')) {
          data = [
            {
              'id': 91,
              'transactionCode': 'TOP-91',
              'status': 'TOP_UP_DISBURSED',
              'requestedAmount': 500,
              'approvedAmount': 500,
              'cashAmount': 300,
              'momoAmount': 200,
              'requesterUserId': 1,
              'requesterName': 'Eric GoM',
              'disbursedAt': disbursedAt,
              'createdAt': '2026-09-12T11:00:00',
            },
          ];
        } else if (request.url.path.endsWith('/finance/top-up-actors')) {
          data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
        } else {
          data = <dynamic>[];
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ExpensesScreen(
              customSchoolId: 'SCH-001',
              accessToken: 'test-token',
              currentUserId: 1,
              role: 'ADMINISTRATOR',
              financeApi: FinanceApiClient(
                accessToken: 'test-token',
                client: client,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('overdue-funds-confirmation-banner')),
        findsOneWidget,
      );
      expect(find.text('Funds-received confirmation overdue'), findsOneWidget);
      expect(find.textContaining('Late by 10 minutes.'), findsOneWidget);
      final pettyCashBadge = find.byKey(
        const ValueKey('expense-tab-badge-Petty Cash'),
      );
      expect(
        find.descendant(of: pettyCashBadge, matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        tester.widget<Tooltip>(pettyCashBadge).message,
        '1 top-up request pending, 1 reconciliation pending, '
        '1 financial follow-up pending',
      );

      await tester.tap(find.text('Petty Cash'));
      await tester.pumpAndSettle();
      for (final entry in const {
        'Float & expenses': '1',
        'Reconciliations': '1',
        'Financial follow-ups': '1',
      }.entries) {
        final badge = find.byKey(ValueKey('expense-tab-badge-${entry.key}'));
        expect(
          find.descendant(of: badge, matching: find.text(entry.value)),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<Tooltip>(
              find.byKey(const ValueKey('expense-tab-badge-Float & expenses')),
            )
            .message,
        '1 top-up request pending',
      );
      expect(
        find.byKey(const ValueKey('petty-cash-control-count-Top-up requests')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('petty-cash-control-count-Reconciliations')),
        findsOneWidget,
      );

      await tester.tap(find.text('Financial follow-ups'));
      await tester.pumpAndSettle();
      expect(find.text('Record follow-up'), findsNothing);
      final followUpRow = find.byKey(const ValueKey('follow-up-FUP-81'));
      await tester.ensureVisible(followUpRow);
      tester
          .widget<InkWell>(
            find.descendant(of: followUpRow, matching: find.byType(InkWell)),
          )
          .onTap!();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Close follow-up'));
      await tester.pumpAndSettle();
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Close follow-up'),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.text('Close FUP-81'), findsOneWidget);
      expect(find.text('RETURN TO SCHOOL FUNDS'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('overage-cash-returned')),
        '30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('overage-momo-returned')),
        '20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('overage-return-reference')),
        'BANK-SLIP-204',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Resolution note'),
        'Excess returned to the school account and verified.',
      );
      expect(find.text('Amount ready to return'), findsOneWidget);
      await tester.ensureVisible(find.text('Record return & close'));
      await tester.tap(find.text('Record return & close'));
      await tester.pumpAndSettle();
      expect(overageClosure, isNotNull);
      expect(overageClosure!['cashAmount'], 30);
      expect(overageClosure!['momoAmount'], 20);
      expect(overageClosure!['reference'], 'BANK-SLIP-204');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('financial follow-up links to the related expense details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final followUpNotes = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'status': 'ACTIVE', 'floatApprovedAmount': 1000},
          'pockets': {'cash': 700, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = [
          {
            'id': 501,
            'transactionCode': 'EXP-2026-13FCB119',
            'transactionType': 'EXPENSE',
            'description': 'Mathematics textbooks',
            'category': 'Supplies',
            'actualAmount': 3000,
            'sourcePocket': 'CASH',
            'status': 'COMPLETED',
            'transactionDate': '2026-09-10',
          },
        ];
      } else if (request.url.path.endsWith('/finance/follow-ups')) {
        data = [
          {
            'id': 601,
            'followUpCode': 'FUP-2026-541787E9',
            'type': 'EXPENSE_VARIANCE',
            'transactionId': 501,
            'responsibleParty': 'Administrator / Accounts',
            'amount': 3000,
            'createdAt': '2026-09-10',
            'dueDate': '2026-09-17',
            'description': 'More information is needed for this variance.',
            'status': 'OPEN',
          },
        ];
      } else if (request.method == 'POST' &&
          request.url.path.endsWith('/finance/follow-ups/601/notes')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        followUpNotes.add({
          'author': 'Eric GoM',
          'note': body['note'],
          'createdAt': '2026-09-10T12:00:00',
        });
        data = <String, dynamic>{};
      } else if (request.url.path.endsWith('/finance/notes')) {
        data = request.url.queryParameters['parentType'] == 'FOLLOW_UP'
            ? followUpNotes
            : [
                {
                  'eventType': 'VARIANCE_CORRECTION_REQUESTED',
                  'author': 'Eric GoM',
                  'note': 'Corrected receipt requested.',
                  'createdAt': '2026-09-10T11:00:00',
                },
              ];
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 1,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Financial follow-ups'));
    await tester.pumpAndSettle();
    expect(find.text('Follow-up register'), findsOneWidget);
    final followUpRow = find.byKey(
      const ValueKey('follow-up-FUP-2026-541787E9'),
    );
    await tester.ensureVisible(followUpRow);
    final rowTapTarget = find.descendant(
      of: followUpRow,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(rowTapTarget).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('CASE DETAILS'), findsOneWidget);
    expect(find.text('Related expense'), findsOneWidget);
    expect(
      find.text('No investigation notes or evidence added yet.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Note or evidence reference'),
      'Supplier invoice requested from the bursar.',
    );
    await tester.ensureVisible(find.text('Save update'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save update'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Supplier invoice requested from the bursar.'),
      findsOneWidget,
    );
    expect(find.text('FUP-2026-541787E9'), findsWidgets);
    await tester.tap(find.text('EXP-2026-13FCB119').last);
    await tester.pumpAndSettle();

    expect(find.text('Mathematics textbooks'), findsOneWidget);
    expect(find.text('Expense ID'), findsOneWidget);
    expect(find.text('REVIEW HISTORY'), findsOneWidget);
    expect(find.text('Correction requested'), findsOneWidget);
    expect(find.textContaining('Corrected receipt requested.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary staff see their requisitions and resulting expenses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requestedPaths = <String>[];

    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/policy')) {
        data = {
          'status': 'ACTIVE',
          'floatCeiling': 300,
          'requisitionExpiryDays': 7,
          'autoApprovePettyCash': false,
          'pockets': {'cash': 250, 'momo': 50},
        };
      } else if (request.url.path.endsWith('/finance/requisitions')) {
        data = {
          'content': [
            {
              'id': 81,
              'requisitionCode': 'REQ-MINE-1',
              'description': 'Classroom markers',
              'category': 'Supplies',
              'requestedBy': 'staff@example.com',
              'requesterUserId': 7,
              'requestedAmount': 120,
              'requestedAt': '2026-09-10T09:00:00',
              'status': 'PENDING',
              'fundingSource': 'SCHOOL_FUNDS',
              'reason': 'Markers are needed for lessons.',
            },
            {
              'id': 82,
              'requisitionCode': 'REQ-MINE-2',
              'description': 'Approved classroom supplies',
              'category': 'Supplies',
              'vendor': 'Stationery shop',
              'requestedBy': 'staff@example.com',
              'requesterUserId': 7,
              'approverName': 'Head Teacher',
              'approverUserId': 8,
              'requestedAmount': 120,
              'approvedAmount': 120,
              'requestedAt': '2026-09-10T09:00:00',
              'approvedAt': '2026-09-10T10:00:00',
              'status': 'APPROVED',
              'fundingSource': 'PETTY_CASH',
              'reason': 'Supplies are needed for lessons.',
            },
          ],
        };
      } else if (request.url.path.endsWith('/finance/transactions/mine')) {
        data = {
          'content': [
            {
              'id': 91,
              'transactionCode': 'EXP-MINE-1',
              'transactionType': 'EXPENSE',
              'description': 'Markers purchased',
              'category': 'Supplies',
              'vendor': 'Stationery shop',
              'actualAmount': 110,
              'paymentChannel': 'BANK_TRANSFER',
              'status': 'COMPLETED',
              'transactionDate': '2026-09-11',
              'requisitionId': 81,
              'receiptNumber': 'RCT-91',
            },
          ],
        };
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            role: 'SECRETARY',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();
    final requisitionScroll = find.byKey(
      const ValueKey('finance-table-horizontal-scroll'),
    );
    expect(requisitionScroll, findsOneWidget);
    expect(tester.getSize(requisitionScroll).width, lessThan(980));
    expect(
      tester
          .getSize(
            find.descendant(
              of: requisitionScroll,
              matching: find.byType(Table),
            ),
          )
          .width,
      greaterThan(900),
    );
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pumpAndSettle();

    expect(find.text('Requisitions'), findsWidgets);
    expect(find.text('Classroom markers'), findsOneWidget);
    expect(find.text('New requisition'), findsWidgets);
    expect(find.text('My Expenses'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('School Expenses'), findsNothing);
    expect(find.text('Petty Cash'), findsNothing);
    expect(find.text('Approvals'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Request reconciliation'), findsNothing);
    expect(
      requestedPaths.any((path) => path.endsWith('/finance/transactions/mine')),
      isTrue,
    );
    expect(
      requestedPaths.any(
        (path) => path == '/api/schools/SCH-001/finance/transactions',
      ),
      isFalse,
    );
    expect(
      requestedPaths.any((path) => path.endsWith('/finance/overview')),
      isFalse,
    );
    await tester.tap(find.text('My Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Markers purchased'), findsOneWidget);
    expect(find.text('EXP-MINE-1 · Stationery shop'), findsOneWidget);
    expect(find.text('Record refund'), findsNothing);
    expect(find.text('Request reversal'), findsNothing);

    await tester.tap(find.text('Requisitions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record actual spend'));
    await tester.tap(find.text('Record actual spend'));
    await tester.pumpAndSettle();
    expect(find.text('Float - Cash · GH¢250 available'), findsOneWidget);
    expect(
      find.textContaining('The selected Cash pocket has GH¢250.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('manager overview labels and links both expense sources', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE'},
          'pockets': {'cash': 500, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {
          'content': [
            {
              'id': 1,
              'transactionCode': 'EXP-OLD',
              'transactionType': 'EXPENSE',
              'description': 'Older school expense',
              'category': 'Utilities',
              'vendor': 'ECG',
              'actualAmount': 50,
              'paymentChannel': 'BANK_TRANSFER',
              'status': 'COMPLETED',
              'transactionDate': '2026-09-08',
            },
            {
              'id': 2,
              'transactionCode': 'EXP-NEW',
              'transactionType': 'EXPENSE',
              'description': 'Recent MoMo expense',
              'category': 'Supplies',
              'vendor': 'Vendor',
              'actualAmount': 20,
              'sourcePocket': 'MOMO',
              'paymentChannel': 'FLOAT_MOMO',
              'status': 'COMPLETED',
              'transactionDate': '2026-09-10',
            },
          ],
        };
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 1,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('School Expenses'), findsWidgets);
    expect(find.text('Petty Cash Expenses'), findsOneWidget);
    expect(find.textContaining('Petty cash · MoMo pocket'), findsOneWidget);
    expect(find.textContaining('School funds · Utilities'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Recent MoMo expense')).dy,
      lessThan(tester.getTopLeft(find.text('Older school expense')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense registers are sortable and paginated', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final transactions = List.generate(10, (index) {
      final number = index + 1;
      return {
        'id': number,
        'transactionCode': 'EXP-$number',
        'transactionType': 'EXPENSE',
        'description': 'Petty expense $number',
        'category': 'Supplies',
        'vendor': 'Vendor $number',
        'actualAmount': number * 10,
        'sourcePocket': 'CASH',
        'paymentChannel': 'FLOAT_CASH',
        'status': 'COMPLETED',
        'transactionDate': '2026-09-${number.toString().padLeft(2, '0')}',
      };
    });
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE', 'floatApprovedAmount': 1000},
          'pockets': {'cash': 500, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {'content': transactions};
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 1,
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 1-8 of 10'), findsOneWidget);
    expect(find.text('Petty expense 10'), findsOneWidget);
    expect(find.text('Petty expense 1'), findsNothing);

    final next = find.byKey(const ValueKey('petty-cash-expenses-next'));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Showing 9-10 of 10'), findsOneWidget);
    expect(find.text('Petty expense 1'), findsOneWidget);

    final amountSort = find.byKey(const ValueKey('expense-sort-amount'));
    await tester.ensureVisible(amountSort);
    await tester.tap(amountSort);
    await tester.pumpAndSettle();
    expect(find.text('Showing 1-8 of 10'), findsOneWidget);
    expect(find.text('Petty expense 1'), findsOneWidget);
    expect(find.text('Petty expense 10'), findsNothing);

    await tester.tap(amountSort);
    await tester.pumpAndSettle();
    expect(find.text('Petty expense 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requester submits a full expense reversal for approval', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? reversalBody;
    var reversalRequested = false;
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE', 'floatApprovedAmount': 1000},
          'pockets': {'cash': 500, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {
          'content': [
            {
              'id': 15,
              'transactionCode': 'EXP-15',
              'transactionType': 'EXPENSE',
              'description': 'Duplicate classroom repair',
              'category': 'Repairs',
              'vendor': 'Maintenance Ltd',
              'actualAmount': 250,
              'sourcePocket': 'CASH',
              'paymentChannel': 'FLOAT_CASH',
              'status': 'COMPLETE',
              'transactionDate': '2026-09-10',
            },
            if (reversalRequested)
              {
                'id': 31,
                'transactionCode': 'REV-31',
                'transactionType': 'EXPENSE_REVERSAL',
                'parentTransactionId': 15,
                'requestedAmount': 250,
                'actualAmount': 0,
                'category': 'DUPLICATE_ENTRY',
                'notes': 'The invoice was entered twice in the register.',
                'status': 'PENDING_APPROVAL',
                'requesterName': 'Kofi Nketia',
                'requesterUserId': 10,
                'approverName': 'Adjoa Mensah',
                'approverUserId': 20,
                'createdAt': '2026-09-12T10:00:00',
                'transactionDate': '2026-09-12',
              },
          ],
        };
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {
          'approvers': [
            {
              'id': 20,
              'name': 'Adjoa Mensah',
              'username': 'adjoa',
              'role': 'Head teacher',
            },
          ],
          'disbursers': <dynamic>[],
        };
      } else if (request.url.path.endsWith(
        '/finance/transactions/15/reversals',
      )) {
        reversalBody = jsonDecode(request.body) as Map<String, dynamic>;
        reversalRequested = true;
        data = <String, dynamic>{};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 10,
            role: 'BURSAR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request reversal'));
    await tester.pumpAndSettle();

    expect(find.text('Request expense reversal'), findsOneWidget);
    expect(
      find.textContaining('Reversal is always for the full expense'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason and evidence *'),
      'The invoice was entered twice in the register.',
    );
    final approverDropdown = find.byKey(
      const ValueKey('expense-reversal-approver'),
    );
    await tester.ensureVisible(approverDropdown);
    await tester.tap(approverDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjoa Mensah · Head teacher').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('submit-expense-reversal')));
    await tester.pumpAndSettle();

    expect(reversalBody?['reasonCode'], 'DUPLICATE_ENTRY');
    expect(reversalBody?['approverUserId'], 20);
    expect(find.text('Pending reversal'), findsOneWidget);
    expect(find.text('REV-31'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assigned approver affirms an expense reversal', (tester) async {
    tester.view.physicalSize = const Size(1800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var approved = false;
    Map<String, dynamic>? approvalBody;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/approvals')) {
        return http.Response(
          jsonEncode({
            'pendingMyApproval': 1,
            'pendingMyRequests': 0,
            'myRequests': <dynamic>[],
            'myApprovals': [
              {
                'key': 'FINANCE_EXPENSE_REVERSAL:31',
                'type': 'FINANCE_EXPENSE_REVERSAL',
                'entityId': 31,
                'category': 'Expenses',
                'title': 'Expense reversal · REV-31',
                'subtitle': 'EXP-15',
                'status': 'PENDING_APPROVAL',
                'amount': 250,
                'requesterName': 'Kofi Nketia',
                'approverName': 'Adjoa Mensah',
                'requesterNote': 'The invoice was entered twice.',
                'submittedAt': '2026-09-12T10:00:00',
                'canApprove': true,
                'canReject': true,
                'canWithdraw': false,
                'sourcePage': 'expenses',
                'stateToken': 'PENDING_APPROVAL:1',
                'detailSections': [
                  {
                    'title': 'Expense reversal request',
                    'description': 'Review the original expense.',
                    'entries': [
                      {
                        'title': 'REV-31',
                        'subtitle': 'EXP-15',
                        'fields': [
                          {'label': 'Expense ID', 'value': 'EXP-15'},
                          {
                            'label': 'Description',
                            'value': 'Duplicate classroom repair',
                          },
                          {'label': 'Recorded amount', 'value': 'GH₵ 250.00'},
                          {'label': 'Amount to reverse', 'value': 'GH₵ 250.00'},
                          {
                            'label': 'Funding source',
                            'value': 'Petty cash · Cash pocket',
                          },
                          {'label': 'Payment channel', 'value': 'Cash'},
                          {'label': 'Payee', 'value': 'Maintenance Ltd'},
                          {'label': 'Receipt', 'value': 'Not available'},
                          {'label': 'Reason type', 'value': 'Duplicate entry'},
                          {
                            'label': 'Financial effect',
                            'value':
                                'Return GH₵ 250.00 to the Cash petty-cash pocket.',
                          },
                          {'label': 'Requester', 'value': 'Kofi Nketia'},
                          {'label': 'Approver', 'value': 'Adjoa Mensah'},
                        ],
                      },
                    ],
                  },
                ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith(
        '/approvals/FINANCE_EXPENSE_REVERSAL/31/actions',
      )) {
        approvalBody = jsonDecode(request.body) as Map<String, dynamic>;
        approved = true;
        return http.Response(
          jsonEncode({
            'pendingMyApproval': 0,
            'pendingMyRequests': 0,
            'myApprovals': <dynamic>[],
            'myRequests': <dynamic>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE', 'floatApprovedAmount': 1000},
          'pockets': {'cash': approved ? 750 : 500, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {
          'content': [
            {
              'id': 15,
              'transactionCode': 'EXP-15',
              'transactionType': 'EXPENSE',
              'description': 'Duplicate classroom repair',
              'category': 'Repairs',
              'vendor': 'Maintenance Ltd',
              'actualAmount': 250,
              'sourcePocket': 'CASH',
              'paymentChannel': 'FLOAT_CASH',
              'status': approved ? 'REVERSED' : 'COMPLETE',
              'transactionDate': '2026-09-10',
            },
            {
              'id': 31,
              'transactionCode': 'REV-31',
              'transactionType': 'EXPENSE_REVERSAL',
              'parentTransactionId': 15,
              'requestedAmount': 250,
              'actualAmount': approved ? -250 : 0,
              'category': 'DUPLICATE_ENTRY',
              'notes': approved
                  ? 'The invoice was entered twice.\nApproval: Verified against the invoice register.'
                  : 'The invoice was entered twice.',
              'status': approved ? 'COMPLETE' : 'PENDING_APPROVAL',
              'requesterName': 'Kofi Nketia',
              'requesterUserId': 10,
              'approverName': 'Adjoa Mensah',
              'approverUserId': 20,
              'confirmedBy': approved ? 'adjoa' : null,
              'confirmedAt': approved ? '2026-09-12T11:00:00' : null,
              'createdAt': '2026-09-12T10:00:00',
              'transactionDate': '2026-09-12',
            },
          ],
        };
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 20,
            role: 'HEAD_TEACHER',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
            approvalApi: ApprovalApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('expense-tab-badge-Approvals')),
      findsOneWidget,
    );
    await tester.tap(find.text('Approvals'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reverse expense'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('approve-expense-reversal-31')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('expense-reversal-compact-details')),
      findsOneWidget,
    );
    expect(find.text('Original expense'), findsOneWidget);
    expect(find.text('Why this is requested'), findsOneWidget);
    expect(approvalBody, isNull);
    await tester.tap(find.text('Approve').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Approve expense reversal'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Decision reason *'),
      'Verified against the invoice register.',
    );
    await tester.tap(find.text('Approve reversal'));
    await tester.pumpAndSettle();

    expect(approvalBody?['action'], 'APPROVE');
    expect(approvalBody?['reason'], 'Verified against the invoice register.');
    expect(find.text('REV-31 · Expense reversal'), findsOneWidget);
    expect(find.text('Approved'), findsWidgets);
    await tester.tap(find.text('Petty Cash'));
    await tester.pumpAndSettle();
    expect(find.text('Reversed'), findsOneWidget);
    expect(find.text('Duplicate classroom repair'), findsOneWidget);
    expect(find.text('REV-31'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance reports preview and export current-term records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? downloadedCsvName;
    String? downloadedCsv;
    String? downloadedPdfName;
    List<int>? downloadedPdf;
    final transactions = <Map<String, dynamic>>[
      {
        'id': 701,
        'transactionCode': 'EXP-REPORT-701',
        'transactionType': 'EXPENSE',
        'academicTermId': 10,
        'requisitionId': 601,
        'description': 'Emergency plumbing repair',
        'category': 'Repairs & Maintenance',
        'vendor': 'Julius Plumbing',
        'requestedAmount': 100,
        'approvedAmount': 100,
        'actualAmount': 110,
        'feeAmount': 2,
        'sourcePocket': 'MOMO',
        'paymentChannel': 'MOMO',
        'receiptNumber': 'RECEIPT-ABCDEFGHIJ-12345678',
        'status': 'TRANSACTION_PENDING_VARIANCE_REVIEW',
        'transactionDate': '2026-09-14',
      },
      {
        'id': 702,
        'transactionCode': 'EXP-REPORT-702',
        'transactionType': 'EXPENSE',
        'academicTermId': 10,
        'description': 'School bus service',
        'category': 'Transport',
        'vendor': 'Bus Garage',
        'actualAmount': 900,
        'paymentChannel': 'BANK_TRANSFER',
        'receiptNumber': 'INV-702',
        'status': 'COMPLETE',
        'transactionDate': '2026-09-13',
      },
      {
        'id': 703,
        'transactionCode': 'REF-REPORT-703',
        'transactionType': 'EXPENSE_REFUND',
        'academicTermId': 10,
        'parentTransactionId': 702,
        'actualAmount': -100,
        'destinationPocket': 'SCHOOL_FUNDS',
        'paymentChannel': 'BANK_TRANSFER',
        'receiptNumber': 'BANK-703',
        'notes': 'Supplier refund received.',
        'createdBy': 'Kofi Accounts',
        'status': 'COMPLETE',
        'transactionDate': '2026-09-15',
      },
      {
        'id': 704,
        'transactionCode': 'TRF-REPORT-704',
        'transactionType': 'POCKET_TRANSFER',
        'academicTermId': 10,
        'sourcePocket': 'MOMO',
        'destinationPocket': 'CASH',
        'actualAmount': 50,
        'feeAmount': 1,
        'status': 'COMPLETE',
        'transactionDate': '2026-09-12',
      },
    ];
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'id': 12, 'status': 'ACTIVE', 'floatApprovedAmount': 1000},
          'pockets': {'cash': 350, 'momo': 250},
        };
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {'content': transactions};
      } else if (request.url.path.endsWith('/finance/requisitions')) {
        data = {
          'content': [
            {
              'id': 601,
              'requisitionCode': 'REQ-REPORT-601',
              'description': 'Emergency plumbing repair',
              'category': 'Repairs & Maintenance',
              'vendor': 'Julius Plumbing',
              'requestedBy': 'Adjoa Mensah',
              'requesterUserId': 8,
              'approverName': 'Kofi Approver',
              'approverUserId': 7,
              'requestedAmount': 100,
              'approvedAmount': 100,
              'requestedAt': '2026-09-14T08:00:00',
              'approvedAt': '2026-09-14T08:30:00',
              'updatedAt': '2026-09-14T08:30:00',
              'expiresAt': '2026-09-21T08:00:00',
              'status': 'FULFILLED',
              'fundingSource': 'PETTY_CASH',
              'reason': 'Stop an active leak.',
            },
          ],
        };
      } else if (request.url.path.endsWith('/finance/top-ups')) {
        data = [
          {
            'id': 801,
            'transactionCode': 'TOP-REPORT-801',
            'status': 'CONFIRMED',
            'requestedAmount': 500,
            'approvedAmount': 500,
            'actualAmount': 500,
            'cashAmount': 300,
            'momoAmount': 200,
            'requesterName': 'Adjoa Mensah',
            'approverName': 'Kofi Approver',
            'disburserName': 'Ama Manager',
            'requestedAt': '2026-09-10T09:00:00',
            'updatedAt': '2026-09-10T10:00:00',
            'confirmedAt': '2026-09-10T11:00:00',
          },
        ];
      } else if (request.url.path.endsWith('/finance/reconciliations')) {
        data = [
          {
            'id': 901,
            'reconciliationCode': 'REC-REPORT-901',
            'status': 'CONFIRMED',
            'requestedAt': '2026-09-11T09:00:00',
            'confirmedAt': '2026-09-11T10:00:00',
            'expectedCash': 350,
            'expectedMomo': 250,
            'actualCash': 350,
            'actualMomo': 250,
          },
        ];
      } else if (request.url.path.endsWith('/finance/follow-ups')) {
        data = [
          {
            'id': 1001,
            'followUpCode': 'FUP-REPORT-1001',
            'type': 'EXPENSE_VARIANCE',
            'status': 'OPEN',
            'amount': 10,
            'responsibleParty': 'Administrator / Accounts',
            'description': 'Review the plumbing variance.',
            'createdAt': '2026-09-14T12:00:00',
          },
        ];
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            recordedBy: 'Kofi Accounts',
            role: 'ADMINISTRATOR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
            financeCsvDownloader: (name, contents) async {
              downloadedCsvName = name;
              downloadedCsv = contents;
              return true;
            },
            financePdfDownloader: (name, bytes) async {
              downloadedPdfName = name;
              downloadedPdf = bytes;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.text('Expense register'), findsOneWidget);
    expect(find.text('Petty cash ledger'), findsOneWidget);
    expect(find.text('Approvals & exceptions'), findsOneWidget);
    expect(find.text('Refunds & reversals'), findsOneWidget);
    expect(find.text('Audit pack'), findsOneWidget);
    expect(find.textContaining('still being prepared'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('open-expense-register-report')),
    );
    await tester.pumpAndSettle();
    expect(find.text('EXP-REPORT-701'), findsOneWidget);
    expect(find.text('Emergency plumbing repair'), findsOneWidget);
    expect(find.text('...12345678'), findsOneWidget);
    expect(find.text('RECEIPT-ABCDEFGHIJ-12345678'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('finance-report-search')),
      'EXP-REPORT-701',
    );
    await tester.pumpAndSettle();
    expect(find.text('EXP-REPORT-702'), findsNothing);
    await tester.tap(find.text('Download CSV'));
    await tester.pumpAndSettle();
    expect(downloadedCsvName, startsWith('expense-register-SCH-001-'));
    expect(downloadedCsv, contains('"Expense ID"'));
    expect(downloadedCsv, contains('"EXP-REPORT-701"'));
    expect(downloadedCsv, contains('"GHS 110.00"'));
    expect(downloadedCsv, contains('"RECEIPT-ABCDEFGHIJ-12345678"'));
    expect(downloadedCsv, isNot(contains('"...12345678"')));
    expect('EXP-REPORT-701'.allMatches(downloadedCsv!).length, 1);
    expect(downloadedCsv, isNot(contains('"EXP-REPORT-702"')));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-finance-audit-pack')));
    await tester.pumpAndSettle();
    expect(find.text('Finance audit pack'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    await tester.tap(find.text('Download PDF'));
    await tester.pumpAndSettle();

    expect(downloadedPdfName, startsWith('finance-audit-pack-SCH-001-'));
    expect(downloadedPdf, isNotNull);
    expect(downloadedPdf!.length, greaterThan(1000));
    expect(String.fromCharCodes(downloadedPdf!.take(4)), '%PDF');
    expect(tester.takeException(), isNull);
  });

  testWidgets('refund register stays focused on received refunds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final today = now.toIso8601String().split('T').first;
    final thisMonth =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
    final priorMonth = DateTime(
      now.year,
      now.month - 1,
      15,
    ).toIso8601String().split('T').first;
    final transactions = <Map<String, dynamic>>[
      {
        'id': 101,
        'transactionCode': 'EXP-OLD-101',
        'transactionType': 'EXPENSE',
        'academicTermId': 9,
        'cycleId': 9,
        'description': 'Old textbook purchase',
        'vendor': 'Book Supplier',
        'actualAmount': 100,
        'sourcePocket': 'CASH',
        'paymentChannel': 'CASH',
        'status': 'COMPLETE',
        'transactionDate': priorMonth,
      },
      {
        'id': 102,
        'transactionCode': 'EXP-CURRENT-102',
        'transactionType': 'EXPENSE',
        'academicTermId': 10,
        'cycleId': 10,
        'description': 'Current stationery purchase',
        'vendor': 'Stationery Supplier',
        'actualAmount': 100,
        'paymentChannel': 'BANK_TRANSFER',
        'status': 'COMPLETE',
        'transactionDate': thisMonth,
      },
      {
        'id': 103,
        'transactionCode': 'EXP-HISTORY-103',
        'transactionType': 'EXPENSE',
        'academicTermId': 9,
        'cycleId': 9,
        'description': 'Historical repair',
        'vendor': 'Repair Vendor',
        'actualAmount': 200,
        'sourcePocket': 'MOMO',
        'paymentChannel': 'MOMO',
        'status': 'COMPLETE',
        'transactionDate': priorMonth,
      },
      {
        'id': 201,
        'transactionCode': 'REF-201',
        'transactionType': 'EXPENSE_REFUND',
        'academicTermId': 10,
        'cycleId': 10,
        'parentTransactionId': 101,
        'description': 'Refund for old textbook purchase',
        'vendor': 'Book Supplier',
        'actualAmount': -100,
        'destinationPocket': 'SCHOOL_FUNDS',
        'paymentChannel': 'BANK_TRANSFER',
        'receiptNumber': 'BANK-201',
        'notes': 'Supplier returned the payment.',
        'createdBy': 'accounts.user',
        'status': 'COMPLETE',
        'transactionDate': today,
      },
      {
        'id': 202,
        'transactionCode': 'REF-202',
        'transactionType': 'EXPENSE_REFUND',
        'academicTermId': 10,
        'cycleId': 10,
        'parentTransactionId': 102,
        'description': 'Refund for stationery purchase',
        'vendor': 'Stationery Supplier',
        'actualAmount': -50,
        'destinationPocket': 'SCHOOL_FUNDS',
        'paymentChannel': 'CHEQUE',
        'receiptNumber': 'CHQ-202',
        'notes': 'Price adjustment received.',
        'createdBy': 'accounts.user',
        'status': 'COMPLETE',
        'transactionDate': thisMonth,
      },
    ];
    final client = MockClient((request) async {
      dynamic data;
      if (request.url.path.endsWith('/academic-context/current')) {
        data = {'academicTermId': 10};
      } else if (request.url.path.endsWith('/finance/overview')) {
        data = {
          'cycle': {'status': 'ACTIVE', 'floatCeiling': 500},
          'pockets': {'cash': 400, 'momo': 100},
        };
      } else if (request.url.path.endsWith('/finance/transactions') &&
          !request.url.queryParameters.containsKey('academicTermId')) {
        data = {'content': transactions};
      } else if (request.url.path.endsWith('/finance/transactions')) {
        data = {
          'content': transactions
              .where((item) => item['academicTermId'] == 10)
              .toList(),
        };
      } else if (request.url.path.endsWith('/finance/follow-ups')) {
        data = [
          {
            'id': 301,
            'followUpCode': 'FUP-301',
            'type': 'VENDOR_REFUND',
            'status': 'OPEN',
            'amount': 25,
            'description': 'Expected supplier return',
            'createdAt': '${today}T09:00:00',
          },
        ];
      } else if (request.url.path.endsWith('/finance/top-up-actors')) {
        data = {'approvers': <dynamic>[], 'disbursers': <dynamic>[]};
      } else {
        data = <dynamic>[];
      }
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ExpensesScreen(
            customSchoolId: 'SCH-001',
            accessToken: 'test-token',
            currentUserId: 7,
            role: 'BURSAR',
            financeApi: FinanceApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open-refunds-reversals-report')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Refunds & reversals'), findsWidgets);
    await tester.tap(find.text('Open refund register'));
    await tester.pumpAndSettle();

    expect(find.text('Received this term'), findsOneWidget);
    expect(find.text('Received this month'), findsOneWidget);
    expect(find.text('Current results'), findsOneWidget);
    expect(find.text('GH¢150'), findsWidgets);
    expect(
      find.textContaining('1 expected return under follow-up'),
      findsOneWidget,
    );
    expect(find.text('School funds'), findsWidgets);
    expect(find.text('REF-201'), findsOneWidget);
    expect(find.text('EXP-OLD-101'), findsOneWidget);
    expect(find.text('Find expense'), findsNothing);
    expect(find.text('Request reconciliation'), findsNothing);
    expect(find.text('New requisition'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
