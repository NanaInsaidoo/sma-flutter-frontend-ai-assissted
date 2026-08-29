import 'package:flutter/foundation.dart';

import '../domain/class_requirement_models.dart';
import '../domain/fee_models.dart';

abstract class ClassRequirementsRepository extends ChangeNotifier {
  List<ClassRequirementGroup> get groups;
  bool get isLoading;
  String? get errorMessage;
  List<StudentRequirementProgress> studentsForClass(String classGroupId);
  int get draftChangeCount;
  int draftChangeCountForClass(String classGroupId);
  RequirementNotificationPlan? get lastNotificationPlan;
  List<PriorTermRequirement> get priorTermRequirements;
  List<StudentCustomRequirement> get studentSpecificRequirements;
  List<StudentRequirementCandidate> get studentCandidates;
  int get unpublishedClassRequirementCount;
  int get unpublishedStudentRequirementCount;

  Future<void> load();
  Future<void> loadPriorTermRequirements();
  Future<void> loadStudentsForClass(String classGroupId);
  Future<ClassRequirementGroup> addClass(ClassRequirementGroup group);
  Future<ClassRequirementGroup> addRequirement(
    String classGroupId,
    ClassRequirementItem item, {
    String? revisionReason,
  });
  Future<ClassRequirementGroup> updateRequirement(
    String classGroupId,
    ClassRequirementItem item, {
    String? revisionReason,
  });
  Future<ClassRequirementGroup> deleteRequirement(
    String classGroupId,
    String requirementId, {
    String? revisionReason,
  });
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
  Future<void> loadStudentSpecificRequirements();
  Future<StudentCustomRequirement> updateStudentRequirement(
    StudentCustomRequirement requirement,
  );
  Future<void> deleteStudentRequirement(String requirementId);
  Future<List<FeeApprover>> getStudentRequirementApprovers();
  Future<StudentCustomRequirement> submitStudentRequirement(
    String requirementId,
    int approverId, {
    String note = '',
  });
  Future<StudentCustomRequirement> withdrawStudentRequirement(
    String requirementId,
  );
  Future<StudentCustomRequirement> approveStudentRequirement(
    String requirementId,
  );
  Future<StudentCustomRequirement> rejectStudentRequirement(
    String requirementId,
    String reason,
  );
  Future<StudentCustomRequirement> recordStudentRequirementReceived(
    String requirementId,
    int receivedQuantity,
  );
  void publishChanges(RequirementNotificationPlan notificationPlan);
  Future<ClassRequirementGroup> publishClass(
    String classGroupId,
    RequirementNotificationPlan notificationPlan,
  );
  Future<List<FeeApprover>> getApprovers();
  Future<ClassRequirementGroup> submitClass(
    String classGroupId,
    int approverId, {
    String note = '',
  });
  Future<ClassRequirementGroup> withdrawClass(String classGroupId);
  Future<ClassRequirementGroup> approveClass(String classGroupId);
  Future<ClassRequirementGroup> rejectClass(String classGroupId, String reason);
}
