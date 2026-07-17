enum RequirementStatus { published, draft }

enum RequirementAdjustmentType {
  increasedQuantity,
  reducedQuantity,
  partialWaiver,
  fullWaiver,
  dueDateExtension,
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
  });

  final String id;
  final String className;
  final int studentCount;
  final List<ClassRequirementItem> items;
  final RequirementStatus status;
  final int draftChangeCount;
  final bool hasPublishedVersion;

  ClassRequirementGroup copyWith({
    List<ClassRequirementItem>? items,
    RequirementStatus? status,
    int? draftChangeCount,
    bool? hasPublishedVersion,
  }) {
    return ClassRequirementGroup(
      id: id,
      className: className,
      studentCount: studentCount,
      items: items ?? this.items,
      status: status ?? this.status,
      draftChangeCount: draftChangeCount ?? this.draftChangeCount,
      hasPublishedVersion: hasPublishedVersion ?? this.hasPublishedVersion,
    );
  }
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
}

class StudentRequirementProgress {
  const StudentRequirementProgress({
    required this.id,
    required this.name,
    required this.classGroupId,
    required this.receivedQuantities,
    required this.adjustments,
    required this.customRequirements,
  });

  final String id;
  final String name;
  final String classGroupId;
  final Map<String, int> receivedQuantities;
  final Map<String, StudentRequirementAdjustment> adjustments;
  final List<StudentCustomRequirement> customRequirements;

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
    );
  }
}

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
