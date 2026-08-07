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
}

class _Repo implements BursarTermClosureRepository {
  bool saved = false;
  final value = BursarTermClosure(
    termId: 1,
    status: 'NOT_STARTED',
    expectedFees: 1000,
    collectedFees: 800,
    waivedFees: 50,
    approvedAdjustments: 0,
    outstandingFees: 150,
    pendingAdjustmentCount: 1,
    pendingReversalCount: 1,
    teacherRecommendations: const [],
    consolidatedRecommendations: const [],
    feesReviewed: false,
    paymentsReconciled: false,
    pettyCashClosed: false,
    recommendationsReviewed: false,
    cashTotal: 0,
    bankTotal: 0,
    mobileMoneyTotal: 0,
    discrepancyExplanation: '',
    unresolvedItems: '',
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
  }) async => value;
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
  }) async => value;
}
