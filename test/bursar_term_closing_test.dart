import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/domain/bursar_term_closure_models.dart';
import 'package:school_management_app/src/term_review/presentation/bursar_term_closing_screen.dart';

void main() {
  testWidgets('bursar can review snapshot and save a draft', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BursarTermClosingScreen(
            schoolId: 'TEST',
            actorUserId: 4,
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finance term closure'), findsOneWidget);
    expect(find.text('Expected fees'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Save draft'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save draft'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repo.saved, isTrue);
    expect(find.text('Draft saved.'), findsOneWidget);
  });

  testWidgets('headmaster sees live totals while waiting for the bursar', (
    tester,
  ) async {
    await _openManagement(tester, _Repo());
    expect(find.text('Waiting for the bursar'), findsOneWidget);
    expect(find.text('Live totals for this term.'), findsOneWidget);
    expect(find.text('Expected fees'), findsOneWidget);
    expect(find.text('Payment reconciliation'), findsNothing);
    expect(find.text('Unresolved financial items'), findsNothing);
    expect(find.text('Approve finance closure'), findsNothing);
  });

  testWidgets('headmaster can return a blocked submission on a narrow screen', (
    tester,
  ) async {
    const blocker = 'Finish and close the open petty-cash reconciliation.';
    final repo = _Repo(status: 'SUBMITTED', pettyCashBlocker: blocker);
    await _openManagement(tester, repo, width: 320);
    expect(find.text('Ready for your review'), findsOneWidget);
    expect(find.text(blocker), findsOneWidget);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Payment reconciliation'),
      320,
      scrollable: scrollable,
    );
    expect(find.text('GH₵ 320.00'), findsOneWidget);
    expect(find.text('GH₵ 800.00'), findsWidgets);
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final approve = find.ancestor(
      of: find.text('Approve finance closure'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    expect(find.text('Replace damaged classroom locks'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Return to bursar'));
    await tester.pumpAndSettle();
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Return to bursar'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Complete the cash count.');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repo.returnedReason, 'Complete the cash count.');
    expect(find.text('Bursar preparing the closure'), findsOneWidget);
    expect(find.text('Approve finance closure'), findsNothing);
  });

  testWidgets('headmaster can approve a submitted reconciliation', (
    tester,
  ) async {
    final repo = _Repo(status: 'SUBMITTED');
    await _openManagement(tester, repo);
    final approve = find.text('Approve finance closure');
    await tester.scrollUntilVisible(
      approve,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(repo.approved, isTrue);
    expect(find.text('Finance closure approved'), findsOneWidget);
    expect(find.text('Reopen approved closure'), findsOneWidget);
  });
}

Future<void> _openManagement(
  WidgetTester tester,
  _Repo repo, {
  double width = 1140,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BursarTermClosingScreen(
          schoolId: 'TEST',
          actorUserId: 4,
          repository: repo,
          management: true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Repo implements BursarTermClosureRepository {
  _Repo({this.status = 'NOT_STARTED', this.pettyCashBlocker});

  bool saved = false;
  bool approved = false;
  String? returnedReason;
  String status;
  final String? pettyCashBlocker;

  BursarTermClosure get value => BursarTermClosure(
    termId: 1,
    status: status,
    expectedFees: 1000,
    collectedFees: 800,
    waivedFees: 50,
    approvedAdjustments: 0,
    outstandingFees: 150,
    pendingAdjustmentCount: status == 'NOT_STARTED' ? 1 : 0,
    pendingReversalCount: status == 'NOT_STARTED' ? 1 : 0,
    teacherRecommendations: const [],
    consolidatedRecommendations: const [
      {
        'name': 'Replace damaged classroom locks',
        'quantity': 2,
        'unitPrice': 10,
      },
    ],
    feesReviewed: false,
    paymentsReconciled: false,
    pettyCashClosed: false,
    recommendationsReviewed: false,
    cashTotal: status == 'NOT_STARTED' ? 0 : 320,
    bankTotal: status == 'NOT_STARTED' ? 0 : 280,
    mobileMoneyTotal: status == 'NOT_STARTED' ? 0 : 200,
    discrepancyExplanation: '',
    unresolvedItems: 'None',
    snapshotLocked: status == 'SUBMITTED' || status == 'APPROVED',
    pettyCashBlocker: pettyCashBlocker,
    reviewReason: returnedReason ?? '',
  );
  @override
  Future<BursarTermClosure> get(String s) async => value;
  @override
  Future<BursarTermClosure> saveDraft(
    String s,
    BursarTermClosureInput i,
  ) async {
    saved = true;
    return value;
  }

  @override
  Future<BursarTermClosure> submit(String s, BursarTermClosureInput i) async =>
      value;
  @override
  Future<BursarTermClosure> approve(
    String s, {
    required int? actorUserId,
    String? reason,
  }) async {
    approved = true;
    status = 'APPROVED';
    return value;
  }

  @override
  Future<BursarTermClosure> reopen(
    String s, {
    required int? actorUserId,
    required String reason,
  }) async => value;
  @override
  Future<BursarTermClosure> returnToBursar(
    String s, {
    required int? actorUserId,
    required String reason,
  }) async {
    returnedReason = reason;
    status = 'DRAFT';
    return value;
  }
}
