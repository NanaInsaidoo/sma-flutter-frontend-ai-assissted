class BursarTermClosure {
  const BursarTermClosure({
    required this.termId,
    required this.status,
    required this.expectedFees,
    required this.collectedFees,
    required this.waivedFees,
    required this.approvedAdjustments,
    required this.outstandingFees,
    required this.pendingAdjustmentCount,
    required this.pendingReversalCount,
    required this.teacherRecommendations,
    required this.consolidatedRecommendations,
    required this.feesReviewed,
    required this.paymentsReconciled,
    required this.pettyCashClosed,
    required this.recommendationsReviewed,
    required this.cashTotal,
    required this.bankTotal,
    required this.mobileMoneyTotal,
    required this.discrepancyExplanation,
    required this.unresolvedItems,
    this.snapshotLocked = false,
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
    this.reviewReason = '',
  });
  final int termId, pendingAdjustmentCount, pendingReversalCount;
  final String status, discrepancyExplanation, unresolvedItems;
  final bool snapshotLocked;
  final DateTime? submittedAt, approvedAt;
  final int? approvedBy;
  final String reviewReason;
  final double expectedFees,
      collectedFees,
      waivedFees,
      approvedAdjustments,
      outstandingFees,
      cashTotal,
      bankTotal,
      mobileMoneyTotal;
  final bool feesReviewed,
      paymentsReconciled,
      pettyCashClosed,
      recommendationsReviewed;
  final List<Map<String, dynamic>> teacherRecommendations,
      consolidatedRecommendations;
  bool get locked => status == 'SUBMITTED' || status == 'APPROVED';
  double get reconciliationTotal => cashTotal + bankTotal + mobileMoneyTotal;
  double get difference => reconciliationTotal - collectedFees;
}

class BursarTermClosureInput {
  const BursarTermClosureInput({
    required this.actorUserId,
    required this.feesReviewed,
    required this.paymentsReconciled,
    required this.pettyCashClosed,
    required this.recommendationsReviewed,
    required this.cashTotal,
    required this.bankTotal,
    required this.mobileMoneyTotal,
    required this.discrepancyExplanation,
    required this.unresolvedItems,
    required this.consolidatedRecommendations,
  });
  final int? actorUserId;
  final bool feesReviewed,
      paymentsReconciled,
      pettyCashClosed,
      recommendationsReviewed;
  final double cashTotal, bankTotal, mobileMoneyTotal;
  final String discrepancyExplanation, unresolvedItems;
  final List<Map<String, dynamic>> consolidatedRecommendations;
}

abstract class BursarTermClosureRepository {
  Future<BursarTermClosure> get(String schoolId);
  Future<BursarTermClosure> saveDraft(
    String schoolId,
    BursarTermClosureInput input,
  );
  Future<BursarTermClosure> submit(
    String schoolId,
    BursarTermClosureInput input,
  );
  Future<BursarTermClosure> approve(
    String schoolId, {
    required int? actorUserId,
    String? reason,
  });
  Future<BursarTermClosure> returnToBursar(
    String schoolId, {
    required int? actorUserId,
    required String reason,
  });
  Future<BursarTermClosure> reopen(
    String schoolId, {
    required int? actorUserId,
    required String reason,
  });
}
