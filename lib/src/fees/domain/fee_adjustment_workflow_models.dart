enum FeeAdjustmentWorkflowType { discount, surcharge }

enum FeeAdjustmentWorkflowStatus {
  draft,
  pending,
  changesRequested,
  approved,
  rejected,
  complete,
  reversed,
  cancelled,
}

class WorkflowFeeAdjustment {
  const WorkflowFeeAdjustment({
    required this.id,
    required this.customStudentId,
    required this.studentName,
    required this.className,
    required this.feeItem,
    required this.type,
    required this.amount,
    required this.reason,
    required this.status,
    required this.createdOn,
    required this.createdBy,
    this.reviewedOn,
    this.reviewedBy,
    this.reviewNote,
  });

  final String id;
  final String customStudentId;
  final String studentName;
  final String className;
  final String feeItem;
  final FeeAdjustmentWorkflowType type;
  final double amount;
  final String reason;
  final FeeAdjustmentWorkflowStatus status;
  final DateTime createdOn;
  final String createdBy;
  final DateTime? reviewedOn;
  final String? reviewedBy;
  final String? reviewNote;

  WorkflowFeeAdjustment copyWith({
    String? id,
    FeeAdjustmentWorkflowType? type,
    String? reason,
    FeeAdjustmentWorkflowStatus? status,
    DateTime? createdOn,
    String? createdBy,
    DateTime? reviewedOn,
    String? reviewedBy,
    String? reviewNote,
    bool clearReview = false,
  }) {
    return WorkflowFeeAdjustment(
      id: id ?? this.id,
      customStudentId: customStudentId,
      studentName: studentName,
      className: className,
      feeItem: feeItem,
      type: type ?? this.type,
      amount: amount,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      createdOn: createdOn ?? this.createdOn,
      createdBy: createdBy ?? this.createdBy,
      reviewedOn: clearReview ? null : reviewedOn ?? this.reviewedOn,
      reviewedBy: clearReview ? null : reviewedBy ?? this.reviewedBy,
      reviewNote: clearReview ? null : reviewNote ?? this.reviewNote,
    );
  }
}
