import 'package:flutter/foundation.dart';

import '../domain/class_requirement_models.dart';

abstract class ClassRequirementsRepository extends ChangeNotifier {
  List<ClassRequirementGroup> get groups;
  bool get isLoading;
  String? get errorMessage;
  List<StudentRequirementProgress> studentsForClass(String classGroupId);
  int get draftChangeCount;
  int draftChangeCountForClass(String classGroupId);
  RequirementNotificationPlan? get lastNotificationPlan;
  List<PriorTermRequirement> get priorTermRequirements;

  Future<void> load();
  Future<void> loadPriorTermRequirements();
  Future<void> loadStudentsForClass(String classGroupId);
  Future<ClassRequirementGroup> addClass(ClassRequirementGroup group);
  Future<ClassRequirementGroup> addRequirement(
    String classGroupId,
    ClassRequirementItem item,
  );
  Future<ClassRequirementGroup> updateRequirement(
    String classGroupId,
    ClassRequirementItem item,
  );
  Future<ClassRequirementGroup> deleteRequirement(
    String classGroupId,
    String requirementId,
  );
  Future<void> recordPriorTermReceived({
    required String requirementId,
    required int quantity,
    required String notes,
  });
  Future<void> resolvePriorTermRequirement({
    required String requirementId,
    required PriorTermRequirementStatus status,
    int? carriedQuantity,
    double? convertedCashAmount,
    DateTime? carriedDueDate,
    required String notes,
    required bool notifyGuardian,
  });
  Future<void> recordReceived({
    required String studentId,
    required String requirementId,
    required int quantity,
  });
  Future<void> adjustRequirement({
    required String studentId,
    required String requirementId,
    required StudentRequirementAdjustment adjustment,
  });
  Future<void> addStudentRequirement({
    required String studentId,
    required StudentCustomRequirement requirement,
  });
  void publishChanges(RequirementNotificationPlan notificationPlan);
  Future<ClassRequirementGroup> publishClass(
    String classGroupId,
    RequirementNotificationPlan notificationPlan,
  );
}
