enum RequirementStatus { published, draft }

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
    this.updatedSincePublished = false,
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
  final bool updatedSincePublished;

  factory ClassRequirementItem.fromJson(Map<String, dynamic> json) {
    return ClassRequirementItem(
      id: '${json['itemId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      category: '${json['category'] ?? ''}',
      quantity: _asInt(json['quantity']),
      unit: '${json['unit'] ?? ''}',
      estimatedUnitPrice: _asDouble(json['estimatedUnitPrice']),
      dueDate: DateTime.tryParse('${json['dueDate'] ?? ''}') ?? DateTime.now(),
      instructions: '${json['instructions'] ?? ''}',
      isOptional: json['optional'] == true,
      updatedSincePublished: json['updatedSincePublished'] == true,
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

  ClassRequirementItem copyWith({bool? updatedSincePublished}) {
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
      updatedSincePublished:
          updatedSincePublished ?? this.updatedSincePublished,
    );
  }
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
    this.gradeLevelId = 0,
  });

  final String id;
  final String className;
  final int studentCount;
  final List<ClassRequirementItem> items;
  final RequirementStatus status;
  final int draftChangeCount;
  final bool hasPublishedVersion;
  final int gradeLevelId;

  factory ClassRequirementGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
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
      status: '${json['status'] ?? ''}'.toUpperCase() == 'PUBLISHED'
          ? RequirementStatus.published
          : RequirementStatus.draft,
      draftChangeCount: _asInt(json['draftChangeCount']),
      hasPublishedVersion: json['hasPublishedVersion'] == true,
      gradeLevelId: _asInt(json['gradeLevelId']),
    );
  }

  ClassRequirementGroup copyWith({
    List<ClassRequirementItem>? items,
    RequirementStatus? status,
    int? draftChangeCount,
    bool? hasPublishedVersion,
    int? gradeLevelId,
  }) {
    return ClassRequirementGroup(
      id: id,
      className: className,
      studentCount: studentCount,
      items: items ?? this.items,
      status: status ?? this.status,
      draftChangeCount: draftChangeCount ?? this.draftChangeCount,
      hasPublishedVersion: hasPublishedVersion ?? this.hasPublishedVersion,
      gradeLevelId: gradeLevelId ?? this.gradeLevelId,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

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
  });

  final RequirementAdjustmentType type;
  final String reason;
  final String notes;
  final int? adjustedQuantity;
  final DateTime? extendedDueDate;
  final String? paymentReference;

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

class StudentCustomRequirement {
  const StudentCustomRequirement({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.dueDate,
    required this.notes,
  });

  final String id;
  final String name;
  final int quantity;
  final String unit;
  final DateTime dueDate;
  final String notes;

  factory StudentCustomRequirement.fromJson(Map<String, dynamic> json) {
    return StudentCustomRequirement(
      id: '${json['obligationId'] ?? ''}',
      name: '${json['name'] ?? ''}',
      quantity: _asInt(json['quantity']),
      unit: '${json['unit'] ?? ''}',
      dueDate: DateTime.tryParse('${json['dueDate'] ?? ''}') ?? DateTime.now(),
      notes: '${json['notes'] ?? ''}',
    );
  }

  Map<String, dynamic> toRequestJson(int academicTermId) => {
    'academicTermId': academicTermId,
    'name': name.trim(),
    'quantity': quantity,
    'unit': unit.trim(),
    'estimatedUnitPrice': 0,
    'dueDate': _dateOnly(dueDate),
    if (notes.trim().isNotEmpty) 'notes': notes.trim(),
  };
}

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
    required this.itemId,
    required this.itemKey,
    required this.baseQuantity,
    required this.requiredQuantity,
    required this.receivedQuantity,
    required this.status,
    required this.dueDate,
  });

  final String itemId;
  final String itemKey;
  final int baseQuantity;
  final int requiredQuantity;
  final int receivedQuantity;
  final String status;
  final DateTime? dueDate;

  factory StudentRequirementItemProgress.fromJson(Map<String, dynamic> json) {
    return StudentRequirementItemProgress(
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
