import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/shop/data/shop_api_client.dart';
import 'package:school_management_app/src/shop/presentation/shop_reconciliation_screen.dart';

void main() {
  late Map<String, dynamic> record;
  late Map<String, dynamic>? submitted;
  late List<Map<String, dynamic>> saves;
  Completer<void>? saveGate;
  late String? decided;
  late String? error;
  late List<Map<String, dynamic>> handovers;
  late bool legacyReportsRequested;
  late String? exportedName, exportedContents;
  setUp(() {
    submitted = null;
    saves = [];
    saveGate = null;
    decided = null;
    error = null;
    handovers = [];
    legacyReportsRequested = false;
    exportedName = null;
    exportedContents = null;
    record = {
      'id': 1,
      'staffId': 2,
      'staffName': 'Ama Cashier',
      'counterId': 3,
      'counterName': 'Adjoa Administrator',
      'status': 'DRAFT',
      'version': 0,
      'periodStart': null,
      'cutoff': '2026-09-04T16:00:00',
      'expectedCash': 100,
      'expectedMomo': 40,
      'cashVariance': 0,
      'momoVariance': 0,
      'investigation': 'NONE',
      'stock': [
        {
          'key': 'C:10',
          'id': 10,
          'itemName': 'Exercise books',
          'location': 'Shop counter',
          'expected': 15,
          'reserved': 1,
          'version': 0,
        },
      ],
    };
  });
  Widget app({
    int user = 3,
    bool admin = true,
    ShopReconciliationView view = ShopReconciliationView.counts,
    List<Map<String, dynamic>>? reconciliationStaff,
  }) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ShopReconciliationScreen(
          contextData: {
            'currentUserId': user,
            'isAdmin': admin,
            'inventoryApprovers': [
              {'id': 1, 'name': 'Kofi Reviewer'},
            ],
            'staff': [
              {'id': 1, 'name': 'Kofi Reviewer'},
              {'id': 2, 'name': 'Ama Cashier'},
              {'id': 3, 'name': 'Adjoa Administrator'},
            ],
            if (reconciliationStaff != null)
              'reconciliationStaff': reconciliationStaff,
          },
          onChanged: () {},
          view: view,
          csvDownloader: (name, contents) async {
            exportedName = name;
            exportedContents = contents;
            return true;
          },
          api: ShopApiClient(
            schoolId: 'SCH',
            client: MockClient((req) async {
              final path = req.url.path;
              dynamic body;
              if (path.endsWith('/period-reconciliations/start')) {
                body = record;
              } else if (path.endsWith('/submit')) {
                final gate = saveGate;
                saveGate = null;
                if (gate != null) await gate.future;
                if (error != null) {
                  return http.Response(jsonEncode({'message': error}), 409);
                }
                final input = jsonDecode(req.body) as Map<String, dynamic>;
                expectSync(input['version'], record['version']);
                saves.add(input);
                if (input['submit'] == true) submitted = input;
                record = {
                  ...record,
                  ...input,
                  'stock': [
                    for (final row in record['stock'])
                      {
                        ...row,
                        ...((input['stock'] as List).firstWhere(
                              (v) => v['key'] == row['key'],
                            )
                            as Map),
                      },
                  ],
                  'status': input['submit'] == true
                      ? 'AWAITING_SELLER_ACK'
                      : 'DRAFT',
                  'version': (record['version'] as int) + 1,
                };
                body = record;
              } else if (path.endsWith('/decision')) {
                decided = jsonDecode(req.body)['action'];
                if (path.contains('/cash-handovers/')) {
                  handovers[0]['status'] = decided == 'CONFIRM'
                      ? 'CONFIRMED'
                      : 'CANCELLED';
                  return http.Response(jsonEncode(handovers[0]), 200);
                }
                record = {
                  ...record,
                  'status': decided == 'CANCEL'
                      ? 'CANCELLED'
                      : decided == 'ACKNOWLEDGE'
                      ? 'PENDING_RESOLUTION'
                      : decided == 'DISPUTE'
                      ? 'DISPUTED'
                      : 'CLOSED_WITH_DIFFERENCES',
                  'investigation': decided == 'RESOLVE' ? 'RESOLVED' : 'OPEN',
                };
                body = record;
              } else if (path.endsWith('/period-reconciliations/1')) {
                body = record;
              } else if (path.endsWith('/period-reconciliations')) {
                body = [record];
              } else if (path.endsWith('/cash-handovers')) {
                if (req.method == 'POST') {
                  final input = jsonDecode(req.body) as Map<String, dynamic>;
                  final created = <String, dynamic>{
                    'id': handovers.length + 1,
                    'senderId': user,
                    'senderName': 'Ama Cashier',
                    'recipientId': input['recipientId'],
                    'recipientName': 'Kofi Reviewer',
                    'amount': input['amount'],
                    'note': input['note'],
                    'status': 'PENDING_RECEIPT',
                    'createdAt': '2026-09-05T09:30:00',
                    'version': 0,
                  };
                  handovers.insert(0, created);
                  body = created;
                } else {
                  body = handovers;
                }
              } else if (path.endsWith('/reconciliations')) {
                legacyReportsRequested = true;
                body = [];
              } else {
                body = [];
              }
              return http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        ),
      ),
    ),
  );
  Future<void> tap(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<void> fill(WidgetTester t, String key, String value) async {
    final f = find.byKey(ValueKey(key));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.enterText(f, value);
    await t.pumpAndSettle();
  }

  Future<void> startCount(WidgetTester t) async {
    await tap(t, find.byKey(const ValueKey('shop-start-reconciliation')));
    await tap(t, find.byKey(const ValueKey('recon-staff-2')));
    await tap(t, find.byKey(const ValueKey('recon-confirm-staff')));
  }

  Future<void> counts(WidgetTester t) async {
    await startCount(t);
    await fill(t, 'recon-count-C:10', '14');
    await fill(t, 'recon-note-C:10', 'One book missing after recount');
    await fill(t, 'recon-cash', '90');
    await fill(t, 'recon-cash-note', 'Cash counted twice, ten short');
    await fill(t, 'recon-momo', '45');
    await fill(t, 'recon-momo-note', 'Statement shows five extra');
    t
        .widget<DropdownButtonFormField<int>>(
          find.byKey(const ValueKey('recon-approver')),
        )
        .onChanged!(1);
    await t.pumpAndSettle();
  }

  testWidgets('start chooser lists only sellers who have received stock', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        reconciliationStaff: [
          {
            'id': 2,
            'name': 'Ama Cashier',
            'role': 'Seller',
            'assignedUnits': 14,
            'assignedItemCount': 2,
            'reconciliationOpen': false,
          },
        ],
      ),
    );
    await t.pumpAndSettle();

    await tap(t, find.byKey(const ValueKey('shop-start-reconciliation')));

    expect(find.text('Select seller to reconcile'), findsOneWidget);
    expect(
      find.text(
        'One seller is counted at a time. Only people who have received stock are listed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ama Cashier'), findsWidgets);
    expect(find.textContaining('14 units across 2 item types'), findsOneWidget);
    expect(find.text('Kofi Reviewer'), findsNothing);
    expect(
      t
          .widget<FilledButton>(
            find.byKey(const ValueKey('recon-confirm-staff')),
          )
          .onPressed,
      isNull,
    );

    await tap(t, find.byKey(const ValueKey('recon-staff-2')));
    expect(find.text('Start this count'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('recon-confirm-staff')));
    expect(find.byKey(const ValueKey('recon-count-table')), findsOneWidget);
  });

  testWidgets('draft autosaves and resumes while reservations remain visible', (
    t,
  ) async {
    record['pendingStockTransfers'] = ['Hand-back #7: 2 Books from Ama'];
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await startCount(t);
    expect(find.byKey(const ValueKey('recon-count-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('recon-pending-transfers')), findsNothing);
    await fill(t, 'recon-count-C:10', '14');
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpAndSettle();
    expect(saves.last['stock'][0]['counted'], 14);
    expect(submitted, isNull);
    expect(find.text('All changes saved'), findsOneWidget);
    await tap(t, find.widgetWithText(TextButton, 'Close'));
    await tap(t, find.byKey(const ValueKey('shop-open-period-1')));
    expect(
      t
          .widget<TextFormField>(find.byKey(const ValueKey('recon-count-C:10')))
          .controller!
          .text,
      '14',
    );
  });
  testWidgets('close flushes unsaved edits without waiting for debounce', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await startCount(t);
    await t.ensureVisible(find.byKey(const ValueKey('recon-count-C:10')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('recon-count-C:10')), '12');
    await t.pump();
    expect(
      t
          .widget<TextFormField>(find.byKey(const ValueKey('recon-count-C:10')))
          .controller!
          .text,
      '12',
    );
    t.widget<TextButton>(find.widgetWithText(TextButton, 'Close')).onPressed!();
    await t.pumpAndSettle();
    expect(
      saves,
      isNotEmpty,
      reason: t
          .widgetList<Text>(find.byType(Text))
          .map((v) => v.data)
          .join(' | '),
    );
    expect(saves.last['stock'][0]['counted'], 12);
    expect(find.textContaining('Count Ama Cashier'), findsNothing);
  });
  testWidgets('edits during saving serialize with the latest server version', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await startCount(t);
    await fill(t, 'recon-count-C:10', '12');
    final gate = Completer<void>();
    saveGate = gate;
    await t.pump(const Duration(milliseconds: 800));
    await t.pump();
    expect(find.text('Saving draft…'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('recon-count-C:10')), '13');
    gate.complete();
    await t.pumpAndSettle();
    expect(saves.map((s) => s['stock'][0]['counted']), [12, 13]);
    expect(record['version'], 2);
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpAndSettle();
  });
  testWidgets('failed autosave prevents close and supports retry', (t) async {
    error = 'Connection unavailable';
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await startCount(t);
    await fill(t, 'recon-count-C:10', '12');
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Not saved — Connection unavailable'),
      findsOneWidget,
    );
    await tap(t, find.widgetWithText(TextButton, 'Close'));
    expect(find.textContaining('Count Ama Cashier'), findsOneWidget);
    error = null;
    await tap(t, find.text('Retry saving'));
    expect(find.text('All changes saved'), findsOneWidget);
    expect(record['stock'][0]['counted'], 12);
  });
  testWidgets(
    'staff compares stock shortage and cash shortage plus money surplus before submitting',
    (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await counts(t);
      await tap(t, find.byKey(const ValueKey('recon-submit')));
      expect(find.text('Review the count'), findsOneWidget);
      expect(submitted, isNull);
      expect(find.text('1 short'), findsOneWidget);
      expect(find.text('GHS 10.00 short'), findsOneWidget);
      expect(find.text('GHS 5.00 extra'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('recon-submit')));
      expect(submitted?['countedCash'], 90);
      expect(submitted?['verifiedMomo'], 45);
      expect(submitted?['stock'][0]['counted'], 14);
      expect(submitted?['approverId'], 1);
      expect(find.text('Waiting for staff acknowledgement'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('stale balances show visible error and retain entered counts', (
    t,
  ) async {
    error = 'Stock changed while counting. Refresh the count and check again';
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await counts(t);
    await tap(t, find.byKey(const ValueKey('recon-submit')));
    await tap(t, find.byKey(const ValueKey('recon-submit')));
    expect(find.textContaining('Stock changed while counting'), findsOneWidget);
    expect(find.text('Review the count'), findsOneWidget);
    expect(submitted, isNull);
  });
  testWidgets('independent resolver must confirm before applying differences', (
    t,
  ) async {
    record = {
      ...record,
      'status': 'PENDING_RESOLUTION',
      'approverId': 1,
      'approverName': 'Kofi Reviewer',
      'countedCash': 90,
      'verifiedMomo': 45,
      'cashVariance': -10,
      'momoVariance': 5,
      'stock': [
        {
          'key': 'C:10',
          'itemName': 'Books',
          'location': 'Counter',
          'expected': 15,
          'counted': 14,
          'variance': -1,
          'note': 'One missing',
        },
      ],
    };
    await t.pumpWidget(app(user: 1, admin: true));
    await t.pumpAndSettle();
    await tap(t, find.byKey(const ValueKey('shop-open-period-1')));
    expect(find.text('GHS 10.00 short'), findsWidgets);
    expect(find.text('Your independent decision is required'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recon-review-decision-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recon-review-stock-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('recon-review-money-table')),
      findsOneWidget,
    );
    await tap(t, find.byKey(const ValueKey('recon-resolve')));
    expect(
      find.text('Confirm differences and close reconciliation?'),
      findsOneWidget,
    );
    expect(decided, isNull);
    await fill(t, 'recon-decision-note', 'Independent recount confirms it');
    await tap(t, find.widgetWithText(FilledButton, 'Confirm and close'));
    expect(decided, 'RESOLVE');
    expect(find.text('Closed — differences recorded'), findsOneWidget);
  });
  testWidgets('counted staff can acknowledge or dispute but cannot resolve', (
    t,
  ) async {
    record = {...record, 'status': 'AWAITING_SELLER_ACK', 'approverId': 1};
    await t.pumpWidget(app(user: 2, admin: false));
    await t.pumpAndSettle();
    await tap(t, find.byKey(const ValueKey('shop-open-period-1')));
    expect(find.text('Your confirmation is required'), findsOneWidget);
    expect(find.text('Acknowledge as correct'), findsOneWidget);
    expect(find.text('Report a problem'), findsOneWidget);
    expect(find.byKey(const ValueKey('recon-resolve')), findsNothing);
    expect(find.byKey(const ValueKey('recon-acknowledge')), findsOneWidget);
    expect(find.byKey(const ValueKey('recon-dispute')), findsOneWidget);
  });
  testWidgets(
    'count layout works on a narrow screen and can save an incomplete draft',
    (t) async {
      t.view.physicalSize = const Size(430, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await startCount(t);
      expect(t.takeException(), isNull);
      await tap(t, find.widgetWithText(TextButton, 'Save draft'));
      expect(saves.last['submit'], false);
      expect(saves.last['countedCash'], isNull);
    },
  );
  testWidgets(
    'discarding a draft requires confirmation and keeps a cancelled history record',
    (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await startCount(t);
      await tap(t, find.widgetWithText(TextButton, 'Discard draft'));
      expect(decided, isNull);
      expect(
        find.text(
          'No balances will change. The cancelled draft remains in your history.',
        ),
        findsOneWidget,
      );
      await tap(t, find.widgetWithText(FilledButton, 'Discard draft'));
      expect(decided, 'CANCEL');
      expect(find.text('cancelled'), findsOneWidget);
    },
  );
  testWidgets(
    'cash remittance table is sortable searchable and exports accounting data',
    (t) async {
      handovers = [
        {
          'id': 1,
          'senderId': 2,
          'senderName': 'Ama Cashier',
          'recipientId': 1,
          'recipientName': 'Kofi Reviewer',
          'amount': 20,
          'status': 'PENDING_RECEIPT',
          'createdAt': '2026-09-05T08:00:00',
          'note': 'End of shift',
          'version': 0,
        },
        {
          'id': 2,
          'senderId': 3,
          'senderName': 'Adjoa Seller',
          'recipientId': 1,
          'recipientName': 'Kofi Reviewer',
          'amount': 50,
          'status': 'CONFIRMED',
          'createdAt': '2026-09-04T16:00:00',
          'confirmedAt': '2026-09-04T16:10:00',
          'version': 1,
        },
      ];
      await t.pumpWidget(
        app(user: 1, admin: true, view: ShopReconciliationView.remittances),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'initial remittance layout');
      expect(
        find.byKey(const ValueKey('cash-remittance-table')),
        findsOneWidget,
      );
      expect(find.text('REM-000001'), findsOneWidget);
      expect(find.text('GHS 50.00'), findsWidgets);
      await fill(t, 'remittance-search', 'Adjoa');
      expect(t.takeException(), isNull, reason: 'filtered remittance layout');
      expect(find.text('REM-000001'), findsNothing);
      expect(find.text('REM-000002'), findsOneWidget);
      await fill(t, 'remittance-search', '');
      expect(
        t.takeException(),
        isNull,
        reason: 'cleared remittance filter layout',
      );
      await tap(t, find.text('Amount').first);
      final layoutError = t.takeException();
      expect(
        layoutError,
        isNull,
        reason: layoutError is FlutterError
            ? layoutError.toStringDeep()
            : '$layoutError',
      );
      await tap(t, find.byKey(const ValueKey('export-remittances')));
      expect(exportedName, startsWith('shop_cash_remittances_'));
      expect(exportedContents, contains('Cash custody transfer'));
      expect(exportedContents, contains('REM-000001'));
      expect(exportedContents, contains('Adjoa Seller'));
      expect(find.text('Cancel handover'), findsNothing);
      await tap(t, find.byKey(const ValueKey('view-remittance-1')));
      expect(find.text('Cash remittance details'), findsOneWidget);
      expect(
        find.text(
          'This is a transfer of cash custody. It is not additional income.',
        ),
        findsOneWidget,
      );
      await tap(t, find.text('Confirm receipt'));
      expect(find.text('Confirm cash received?'), findsOneWidget);
      expect(decided, isNull);
      await tap(t, find.widgetWithText(FilledButton, 'Confirm'));
      expect(decided, 'CONFIRM');
      expect(handovers[0]['status'], 'CONFIRMED');
    },
  );

  testWidgets('seller records a cash remittance from the remittance tab', (
    t,
  ) async {
    await t.pumpWidget(app(view: ShopReconciliationView.remittances));
    await t.pumpAndSettle();
    await tap(t, find.byKey(const ValueKey('shop-remit-cash')));
    expect(find.text('Remit collected cash'), findsWidgets);
    t
        .widget<DropdownButtonFormField<int>>(
          find.byType(DropdownButtonFormField<int>),
        )
        .onChanged!(1);
    await t.pump();
    await t.enterText(
      find.widgetWithText(TextField, 'Cash amount (GHS)'),
      '15',
    );
    await t.enterText(
      find.widgetWithText(TextField, 'Notes (optional)'),
      'Shift cash',
    );
    await tap(t, find.widgetWithText(FilledButton, 'Submit remittance'));
    expect(handovers, hasLength(1));
    expect(handovers.single['amount'], 15);
    expect(find.text('REM-000001'), findsOneWidget);
  });

  testWidgets('reconciliation contains counts only and omits legacy data', (
    t,
  ) async {
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text('Previous account reports'), findsNothing);
    expect(find.text('Reconciliation'), findsOneWidget);
    expect(find.text('Cash remittances'), findsNothing);
    expect(legacyReportsRequested, isFalse);
  });
}
