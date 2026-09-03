enum RequirementStatus { published, approved, pendingApproval, draft }

class RequirementCompletionSummary {
  const RequirementCompletionSummary({
    required this.activeObligations,
    required this.completedObligations,
    required this.completionPercentage,
  });

  const RequirementCompletionSummary.empty()
    : activeObligations = 0,
      completedObligations = 0,
      completionPercentage = 0;

  final int activeObligations;
  final int completedObligations;
  final double completionPercentage;

  factory RequirementCompletionSummary.fromJson(Map<String, dynamic> json) =>
      RequirementCompletionSummary(
        activeObligations: _asInt(json['activeObligations']),
        completedObligations: _asInt(json['completedObligations']),
        completionPercentage: _asDouble(json['completionPercentage']),
      );
}

enum RequirementItemChange { current, added, modified, removed }

enum PriorTermRequirementStatus {
  pending,
  fulfilled,
  carriedForward,
  convertedToCash,
  waived,
  writtenOff,
}

enum RequirementAdjustmentType {
  increasedQuantity,
  reducedQuantity,
  partialWaiver,
  fullWaiver,
  dueDateExtension,
  cashEquivalent,
}

class ClassRequirementItem {
  const ClassRequirementItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.estimatedUnitPrice,
    required this.dueDate,
    this.instructions = '',
    this.isOptional = false,
    this.itemKey = '',
    this.updatedSincePublished = false,
    this.changeType = RequirementItemChange.current,
    this.lifecycleAction = '',
    this.lifecycleAt,
    this.lifecycleBy = '',
  });

  final String id;
  final String name;
  final String category;
  final int quantity;
  final String unit;
  final double estimatedUnitPrice;
  final DateTime dueDate;
  final String instructions;
  final bool isOptional;
  final String itemKey;
  final bool updatedSincePublished;
  final RequirementItemChange changeType;
  final String lifecycleAction;
  final DateTime? lifecycleAt;
  final String lifecycleBy;

  String get identityKey => itemKey.isEmpty ? id : itemKey;

  factory ClassRequirementItem.fromJson(Map<String, dynamic> json) {
    return ClassRequirementItem(
      id: '${json['itemId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      category: '${json['category'] ?? ''}',
      quantity: _asInt(json['quantity']),
      unit: '${json['unit'] ?? ''}',
      estimatedUnitPrice: _asDouble(json['estimatedUnitPrice']),
      dueDate: _requirementDate(json['dueDate']) ?? DateTime.now(),
      instructions: '${json['instructions'] ?? ''}',
      isOptional: json['optional'] == true,
      itemKey: '${json['itemKey'] ?? ''}',
      updatedSincePublished: json['updatedSincePublished'] == true,
      changeType: switch ('${json['changeType'] ?? ''}'.toUpperCase()) {
        'ADDED' => RequirementItemChange.added,
        'MODIFIED' => RequirementItemChange.modified,
        'REMOVED' => RequirementItemChange.removed,
        _ => RequirementItemChange.current,
      },
      lifecycleAction: '${json['lifecycleAction'] ?? ''}',
      lifecycleAt: _requirementDate(json['lifecycleAt']),
      lifecycleBy: '${json['lifecycleBy'] ?? ''}',
    );
  }

  Map<String, dynamic> toRequestJson(int displayOrder) {
    return {
      if (int.tryParse(id) case final itemId?) 'itemId': itemId,
      'name': name.trim(),
      if (category.trim().isNotEmpty) 'category': category.trim(),
      'quantity': quantity,
      'unit': unit.trim(),
      'estimatedUnitPrice': estimatedUnitPrice,
      'dueDate': _dateOnly(dueDate),
      if (instructions.trim().isNotEmpty) 'instructions': instructions.trim(),
      'optional': isOptional,
      'displayOrder': displayOrder,
      'active': true,
    };
  }

  ClassRequirementItem copyWith({
    bool? updatedSincePublished,
    RequirementItemChange? changeType,
  }) {
    return ClassRequirementItem(
      id: id,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      estimatedUnitPrice: estimatedUnitPrice,
      dueDate: dueDate,
      instructions: instructions,
      isOptional: isOptional,
      itemKey: itemKey,
      updatedSincePublished:
          updatedSincePublished ?? this.updatedSincePublished,
      changeType: changeType ?? this.changeType,
      lifecycleAction: lifecycleAction,
      lifecycleAt: lifecycleAt,
      lifecycleBy: lifecycleBy,
    );
  }
}

DateTime? _requirementDate(dynamic value) {
  if (value is List && value.length >= 3) {
    final year = (value[0] as num?)?.toInt();
    final month = (value[1] as num?)?.toInt();
    final day = (value[2] as num?)?.toInt();
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }
  }
  return DateTime.tryParse('${value ?? ''}');
}

class ClassRequirementGroup {
  const ClassRequirementGroup({
    required this.id,
    required this.className,
    required this.studentCount,
    required this.items,
    required this.status,
    this.draftChangeCount = 0,
    this.hasPublishedVersion = false,
    this.publishedItems = const [],
    this.gradeLevelId = 0,
    this.assignedApproverId = 0,
    this.assignedApproverName = '',
    this.rejectionReason = '',
    this.revisionReason = '',
    this.createdBy = '',
    this.creatorOwned = false,
  });

  final String id;
  final String className;
  final int studentCount;
  final List<ClassRequirementItem> items;
  final RequirementStatus status;
  final int draftChangeCount;
  final bool hasPublishedVersion;
  final List<ClassRequirementItem> publishedItems;
  final int gradeLevelId;
  final int assignedApproverId;
  final String assignedApproverName;
  final String rejectionReason;
  final String revisionReason;
  final String createdBy;
  final bool creatorOwned;

  factory ClassRequirementGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawPublishedItems = json['publishedItems'];
    return ClassRequirementGroup(
      id: '${json['requirementId'] ?? ''}',
      className: '${json['className'] ?? ''}',
      studentCount: _asInt(json['studentCount']),
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => ClassRequirementItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      status: switch ('${json['status'] ?? ''}'.toUpperCase()) {
        'PUBLISHED' => RequirementStatus.published,
        'APPROVED' => RequirementStatus.approved,
        'PENDING_APPROVAL' => RequirementStatus.pendingApproval,
        _ => RequirementStatus.draft,
      },
      draftChangeCount: _asInt(json['draftChangeCount']),
      hasPublishedVersion: json['hasPublishedVersion'] == true,
      publishedItems: rawPublishedItems is List
          ? rawPublishedItems
                .whereType<Map>()
                .map(
                  (item) => ClassRequirementItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      gradeLevelId: _asInt(json['gradeLevelId']),
      assignedApproverId: _asInt(json['assignedApproverId']),
      assignedApproverName: '${json['assignedApproverName'] ?? ''}',
      rejectionReason: '${json['rejectionReason'] ?? ''}',
      revisionReason: '${json['revisionReason'] ?? ''}',
      createdBy: '${json['createdBy'] ?? ''}',
      creatorOwned: json['creatorOwned'] == true,
    );
  }

  ClassRequirementGroup copyWith({
    List<ClassRequirementItem>? items,
    RequirementStatus? status,
    int? draftChangeCount,
    bool? hasPublishedVersion,
    List<ClassRequirementItem>? publishedItems,
    int? gradeLevelId,
    int? assignedApproverId,
    String? assignedApproverName,
    String? rejectionReason,
    String? revisionReason,
    String? createdBy,
    bool? creatorOwned,
  }) {
    return ClassRequirementGroup(
      id: id,
      className: className,
      studentCount: studentCount,
      items: items ?? this.items,
      status: status ?? this.status,
      draftChangeCount: draftChangeCount ?? this.draftChangeCount,
      hasPublishedVersion: hasPublishedVersion ?? this.hasPublishedVersion,
      publishedItems: publishedItems ?? this.publishedItems,
      gradeLevelId: gradeLevelId ?? this.gradeLevelId,
      assignedApproverId: assignedApproverId ?? this.assignedApproverId,
      assignedApproverName: assignedApproverName ?? this.assignedApproverName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      revisionReason: revisionReason ?? this.revisionReason,
      createdBy: createdBy ?? this.createdBy,
      creatorOwned: creatorOwned ?? this.creatorOwned,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

int? _nullableInt(dynamic value) => value == null ? null : _asInt(value);

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class StudentRequirementAdjustment {
  const StudentRequirementAdjustment({
    required this.type,
    required this.reason,
    required this.notes,
    this.adjustedQuantity,
    this.extendedDueDate,
    this.paymentReference,
    this.adjustmentId = 0,
    this.workflowStatus,
    this.assignedApproverId,
    this.assignedApproverName = '',
    this.rejectionReason = '',
    this.creatorOwned = false,
  });

  final RequirementAdjustmentType type;
  final String reason;
  final String notes;
  final int? adjustedQuantity;
  final DateTime? extendedDueDate;
  final String? paymentReference;
  final int adjustmentId;
  final StudentSpecificRequirementStatus? workflowStatus;
  final int? assignedApproverId;
  final String assignedApproverName;
  final String rejectionReason;
  final bool creatorOwned;

  factory StudentRequirementAdjustment.fromJson(Map<String, dynamic> json) {
    final rawType = '${json['type'] ?? ''}'.toUpperCase();
    return StudentRequirementAdjustment(
      type: RequirementAdjustmentType.values.firstWhere(
        (type) => _adjustmentTypeName(type) == rawType,
        orElse: () => RequirementAdjustmentType.reducedQuantity,
      ),
      reason: '${json['reason'] ?? ''}',
      notes: '${json['notes'] ?? ''}',
      adjustedQuantity: json['adjustedQuantity'] == null
          ? null
          : _asInt(json['adjustedQuantity']),
      extendedDueDate: DateTime.tryParse('${json['extendedDueDate'] ?? ''}'),
      paymentReference: json['paymentReference']?.toString(),
      adjustmentId: _asInt(json['adjustmentId']),
      workflowStatus: json['workflowStatus'] == null
          ? null
          : _studentSpecificStatus('${json['workflowStatus']}'),
      assignedApproverId: _nullableInt(json['assignedApproverId']),
      assignedApproverName: '${json['assignedApproverName'] ?? ''}',
      rejectionReason: '${json['rejectionReason'] ?? ''}',
      creatorOwned: json['creatorOwned'] == true,
    );
  }

  Map<String, dynamic> toRequestJson() => {
    'type': _adjustmentTypeName(type),
    'reason': reason.trim(),
    'notes': notes.trim(),
    if (adjustedQuantity != null) 'adjustedQuantity': adjustedQuantity,
    if (extendedDueDate != null) 'extendedDueDate': _dateOnly(extendedDueDate!),
    if (paymentReference?.trim().isNotEmpty == true)
      'paymentReference': paymentReference!.trim(),
  };
}

enum StudentSpecificRequirementStatus {
  draft,
  pendingApproval,
  changesRequested,
  active,
  inactive,
}

class StudentRequirementCandidate {
  const StudentRequirementCandidate({
    required this.studentId,
    required this.studentName,
    required this.className,
  });

  final String studentId;
  final String studentName;
  final String className;

  factory StudentRequirementCandidate.fromJson(Map<String, dynamic> json) =>
      StudentRequirementCandidate(
        studentId: '${json['studentId'] ?? ''}',
        studentName: '${json['studentName'] ?? ''}',
        className: '${json['className'] ?? ''}',
      );
}

class StudentCustomRequirement {
  const StudentCustomRequirement({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.dueDate,
    required this.notes,
    this.studentId = '',
    this.studentName = '',
    this.className = '',
    this.receivedQuantity = 0,
    this.estimatedUnitPrice = 0,
    this.status = StudentSpecificRequirementStatus.draft,
    this.creatorOwned = false,
    this.canApprove = false,
    this.canWithdraw = false,
    this.assignedApproverId,
    this.assignedApproverName = '',
    this.requesterName = '',
    this.requesterNote = '',
    this.rejectionReason = '',
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.approvedAt,
  });

  final String id;
  final String name;
  final int quantity;
  final String unit;
  final DateTime dueDate;
  final String notes;
  final String studentId;
  final String studentName;
  final String className;
  final int receivedQuantity;
  final double estimatedUnitPrice;
  final StudentSpecificRequirementStatus status;
  final bool creatorOwned;
  final bool canApprove;
  final bool canWithdraw;
  final int? assignedApproverId;
  final String assignedApproverName;
  final String requesterName;
  final String requesterNote;
  final String rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;

  bool get isPublished => status == StudentSpecificRequirementStatus.active;

  factory StudentCustomRequirement.fromJson(Map<String, dynamic> json) {
    return StudentCustomRequirement(
      id: '${json['obligationId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      quantity: _asInt(json['quantity']),
      receivedQuantity: _asInt(json['receivedQuantity']),
      unit: '${json['unit'] ?? ''}',
      estimatedUnitPrice: _asDouble(json['estimatedUnitPrice']),
      dueDate: DateTime.tryParse('${json['dueDate'] ?? ''}') ?? DateTime.now(),
      notes: '${json['notes'] ?? ''}',
      studentId: '${json['studentId'] ?? ''}',
      studentName: '${json['studentName'] ?? ''}',
      className: '${json['className'] ?? ''}',
      status: _studentSpecificStatus('${json['workflowStatus'] ?? 'DRAFT'}'),
      creatorOwned: json['creatorOwned'] == true,
      canApprove: json['canApprove'] == true,
      canWithdraw: json['canWithdraw'] == true,
      assignedApproverId: _nullableInt(json['assignedApproverId']),
      assignedApproverName: '${json['assignedApproverName'] ?? ''}',
      requesterName: '${json['requesterName'] ?? ''}',
      requesterNote: '${json['requesterNote'] ?? ''}',
      rejectionReason: '${json['rejectionReason'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
      submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
      approvedAt: DateTime.tryParse('${json['approvedAt'] ?? ''}'),
    );
  }

  Map<String, dynamic> toRequestJson(int academicTermId) => {
    'academicTermId': academicTermId,
    'name': name.trim(),
    'quantity': quantity,
    'unit': unit.trim(),
    'estimatedUnitPrice': estimatedUnitPrice,
    'dueDate': _dateOnly(dueDate),
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
  };
}

StudentSpecificRequirementStatus _studentSpecificStatus(String raw) =>
    switch (raw.trim().toUpperCase()) {
      'PENDING_APPROVAL' => StudentSpecificRequirementStatus.pendingApproval,
      'CHANGES_REQUESTED' => StudentSpecificRequirementStatus.changesRequested,
      'ACTIVE' => StudentSpecificRequirementStatus.active,
      'INACTIVE' => StudentSpecificRequirementStatus.inactive,
      _ => StudentSpecificRequirementStatus.draft,
    };

class StudentRequirementProgress {
  const StudentRequirementProgress({
    required this.id,
    required this.name,
    required this.classGroupId,
    required this.receivedQuantities,
    required this.adjustments,
    required this.customRequirements,
    this.items = const [],
  });

  final String id;
  final String name;
  final String classGroupId;
  final Map<String, int> receivedQuantities;
  final Map<String, StudentRequirementAdjustment> adjustments;
  final List<StudentCustomRequirement> customRequirements;
  final List<StudentRequirementItemProgress> items;

  factory StudentRequirementProgress.fromJson(Map<String, dynamic> json) {
    final received = <String, int>{};
    final adjustments = <String, StudentRequirementAdjustment>{};
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final raw in rawItems.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final itemId = '${item['itemId'] ?? ''}';
        if (itemId.isEmpty) continue;
        received[itemId] = _asInt(item['receivedQuantity']);
        final adjustment = item['adjustment'];
        if (adjustment is Map) {
          adjustments[itemId] = StudentRequirementAdjustment.fromJson(
            Map<String, dynamic>.from(adjustment),
          );
        }
      }
    }
    final rawCustom = json['customRequirements'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => StudentRequirementItemProgress.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <StudentRequirementItemProgress>[];
    return StudentRequirementProgress(
      id: '${json['studentId'] ?? ''}',
      name: '${json['studentName'] ?? ''}',
      classGroupId: '${json['classRequirementId'] ?? ''}',
      receivedQuantities: received,
      adjustments: adjustments,
      customRequirements: rawCustom is List
          ? rawCustom
                .whereType<Map>()
                .map(
                  (item) => StudentCustomRequirement.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      items: items,
    );
  }

  StudentRequirementProgress copyWith({
    Map<String, int>? receivedQuantities,
    Map<String, StudentRequirementAdjustment>? adjustments,
    List<StudentCustomRequirement>? customRequirements,
  }) {
    return StudentRequirementProgress(
      id: id,
      name: name,
      classGroupId: classGroupId,
      receivedQuantities: receivedQuantities ?? this.receivedQuantities,
      adjustments: adjustments ?? this.adjustments,
      customRequirements: customRequirements ?? this.customRequirements,
      items: items,
    );
  }
}

class StudentRequirementItemProgress {
  const StudentRequirementItemProgress({
    required this.obligationId,
    required this.itemId,
    required this.itemKey,
    required this.baseQuantity,
    required this.requiredQuantity,
    required this.receivedQuantity,
    required this.status,
    required this.dueDate,
  });

  final String obligationId;
  final String itemId;
  final String itemKey;
  final int baseQuantity;
  final int requiredQuantity;
  final int receivedQuantity;
  final String status;
  final DateTime? dueDate;

  factory StudentRequirementItemProgress.fromJson(Map<String, dynamic> json) {
    return StudentRequirementItemProgress(
      obligationId: '${json['obligationId'] ?? ''}',
      itemId: '${json['itemId'] ?? ''}',
      itemKey: '${json['itemKey'] ?? ''}',
      baseQuantity: _asInt(json['baseQuantity']),
      requiredQuantity: _asInt(json['requiredQuantity']),
      receivedQuantity: _asInt(json['receivedQuantity']),
      status: '${json['status'] ?? ''}'.toUpperCase(),
      dueDate: DateTime.tryParse('${json['dueDate'] ?? ''}'),
    );
  }
}

String _adjustmentTypeName(RequirementAdjustmentType type) => switch (type) {
  RequirementAdjustmentType.increasedQuantity => 'INCREASED_QUANTITY',
  RequirementAdjustmentType.reducedQuantity => 'REDUCED_QUANTITY',
  RequirementAdjustmentType.partialWaiver => 'PARTIAL_WAIVER',
  RequirementAdjustmentType.fullWaiver => 'FULL_WAIVER',
  RequirementAdjustmentType.dueDateExtension => 'DUE_DATE_EXTENSION',
  RequirementAdjustmentType.cashEquivalent => 'CASH_EQUIVALENT',
};

class RequirementNotificationPlan {
  const RequirementNotificationPlan({
    required this.useDefaultPreference,
    required this.methods,
    required this.message,
  });

  final bool useDefaultPreference;
  final Set<String> methods;
  final String message;
}

class PriorTermRequirement {
  const PriorTermRequirement({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.originClassName,
    required this.originTerm,
    required this.itemName,
    required this.category,
    required this.originalQuantity,
    required this.receivedQuantity,
    required this.unit,
    required this.estimatedUnitPrice,
    this.status = PriorTermRequirementStatus.pending,
    this.carriedQuantity,
    this.convertedCashAmount,
    this.carriedDueDate,
    this.resolutionNotes = '',
    this.resolvedAt,
    this.guardianNotificationQueued = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String originClassName;
  final String originTerm;
  final String itemName;
  final String category;
  final int originalQuantity;
  final int receivedQuantity;
  final String unit;
  final double estimatedUnitPrice;
  final PriorTermRequirementStatus status;
  final int? carriedQuantity;
  final double? convertedCashAmount;
  final DateTime? carriedDueDate;
  final String resolutionNotes;
  final DateTime? resolvedAt;
  final bool guardianNotificationQueued;

  factory PriorTermRequirement.fromJson(Map<String, dynamic> json) {
    final rawStatus = '${json['status'] ?? 'PENDING'}'.toUpperCase();
    final status = switch (rawStatus) {
      'FULFILLED' => PriorTermRequirementStatus.fulfilled,
      'CARRIED_FORWARD' => PriorTermRequirementStatus.carriedForward,
      'CONVERTED_TO_CASH' => PriorTermRequirementStatus.convertedToCash,
      'WAIVED' => PriorTermRequirementStatus.waived,
      'WRITTEN_OFF' => PriorTermRequirementStatus.writtenOff,
      _ => PriorTermRequirementStatus.pending,
    };
    return PriorTermRequirement(
      id: '${json['id'] ?? ''}',
      studentId: '${json['studentId'] ?? ''}',
      studentName: '${json['studentName'] ?? ''}',
      originClassName: '${json['originClassName'] ?? ''}',
      originTerm: '${json['originTerm'] ?? ''}',
      itemName: '${json['itemName'] ?? ''}',
      category: '${json['category'] ?? ''}',
      originalQuantity: _asInt(json['originalQuantity']),
      receivedQuantity: _asInt(json['receivedQuantity']),
      unit: '${json['unit'] ?? ''}',
      estimatedUnitPrice: _asDouble(json['estimatedUnitPrice']),
      status: status,
      carriedQuantity: json['carriedQuantity'] == null
          ? null
          : _asInt(json['carriedQuantity']),
      convertedCashAmount: json['convertedCashAmount'] == null
          ? null
          : _asDouble(json['convertedCashAmount']),
      carriedDueDate: DateTime.tryParse('${json['carriedDueDate'] ?? ''}'),
      resolutionNotes: '${json['resolutionNotes'] ?? ''}',
      resolvedAt: DateTime.tryParse('${json['resolvedAt'] ?? ''}'),
      guardianNotificationQueued: json['guardianNotificationQueued'] == true,
    );
  }

  int get remainingQuantity {
    final remaining = originalQuantity - receivedQuantity;
    return remaining < 0 ? 0 : remaining;
  }

  double get estimatedOutstandingValue =>
      remainingQuantity * estimatedUnitPrice;

  PriorTermRequirement copyWith({
    int? receivedQuantity,
    PriorTermRequirementStatus? status,
    int? carriedQuantity,
    double? convertedCashAmount,
    DateTime? carriedDueDate,
    String? resolutionNotes,
    DateTime? resolvedAt,
    bool? guardianNotificationQueued,
  }) {
    return PriorTermRequirement(
      id: id,
      studentId: studentId,
      studentName: studentName,
      originClassName: originClassName,
      originTerm: originTerm,
      itemName: itemName,
      category: category,
      originalQuantity: originalQuantity,
      receivedQuantity: receivedQuantity ?? this.receivedQuantity,
      unit: unit,
      estimatedUnitPrice: estimatedUnitPrice,
      status: status ?? this.status,
      carriedQuantity: carriedQuantity ?? this.carriedQuantity,
      convertedCashAmount: convertedCashAmount ?? this.convertedCashAmount,
      carriedDueDate: carriedDueDate ?? this.carriedDueDate,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      guardianNotificationQueued:
          guardianNotificationQueued ?? this.guardianNotificationQueued,
    );
  }
}
