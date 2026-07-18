enum EnrolledStudentStatus { active, inactive, transferred }

class EnrolledStudent {
  const EnrolledStudent({
    required this.id,
    required this.name,
    required this.className,
    required this.gender,
    required this.dateOfBirth,
    required this.guardianName,
    required this.guardianRelationship,
    required this.guardianPhone,
    required this.householdId,
    required this.status,
    required this.enrolledOn,
    required this.newThisTerm,
    required this.attendanceRate,
    required this.feeBalance,
    required this.requirementsCompleted,
    required this.requirementsTotal,
    required this.countryOfBirth,
    required this.cityOfBirth,
    required this.religion,
    required this.address,
    required this.bloodGroup,
    required this.medicalAlerts,
    required this.medicalConditions,
    required this.allergies,
    required this.vaccinations,
    required this.householdMembers,
    required this.attendance,
    required this.fees,
    required this.feeAdjustments,
    required this.payments,
    required this.requirements,
    required this.documents,
    required this.activity,
  });

  final String id;
  final String name;
  final String className;
  final String gender;
  final DateTime dateOfBirth;
  final String guardianName;
  final String guardianRelationship;
  final String guardianPhone;
  final String householdId;
  final EnrolledStudentStatus status;
  final DateTime enrolledOn;
  final bool newThisTerm;
  final double attendanceRate;
  final double feeBalance;
  final int requirementsCompleted;
  final int requirementsTotal;
  final String countryOfBirth;
  final String cityOfBirth;
  final String religion;
  final String address;
  final String bloodGroup;
  final List<String> medicalAlerts;
  final List<StudentMedicalCondition> medicalConditions;
  final StudentAllergies allergies;
  final List<StudentVaccination> vaccinations;
  final List<StudentHouseholdMember> householdMembers;
  final List<StudentAttendanceEntry> attendance;
  final List<StudentFeeItem> fees;
  final List<StudentFeeAdjustment> feeAdjustments;
  final List<StudentPayment> payments;
  final List<StudentRequirement> requirements;
  final List<StudentDocument> documents;
  final List<StudentActivity> activity;

  int get requirementsOutstanding =>
      (requirementsTotal - requirementsCompleted).clamp(0, requirementsTotal);
}

class StudentMedicalCondition {
  const StudentMedicalCondition({
    required this.name,
    required this.hasCondition,
    this.notes = '',
  });

  final String name;
  final bool hasCondition;
  final String notes;
}

class StudentAllergies {
  const StudentAllergies({
    this.food = const [],
    this.medication = const [],
    this.environmental = const [],
  });

  final List<String> food;
  final List<String> medication;
  final List<String> environmental;
}

enum StudentVaccinationStatus { received, pending, notReceived }

class StudentVaccination {
  const StudentVaccination({
    required this.name,
    required this.status,
    required this.required,
    this.receivedOn,
    this.notes = '',
  });

  final String name;
  final StudentVaccinationStatus status;
  final bool required;
  final DateTime? receivedOn;
  final String notes;
}

enum StudentHouseholdMemberType { guardian, student }

class StudentHouseholdMember {
  const StudentHouseholdMember({
    required this.id,
    required this.name,
    required this.relationship,
    required this.type,
    this.subtitle = '',
    this.primary = false,
  });

  final String id;
  final String name;
  final String relationship;
  final StudentHouseholdMemberType type;
  final String subtitle;
  final bool primary;
}

class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.date,
    required this.status,
    this.note = '',
  });

  final DateTime date;
  final String status;
  final String note;
}

class StudentFeeItem {
  const StudentFeeItem({
    required this.name,
    required this.amount,
    required this.paid,
  });

  final String name;
  final double amount;
  final double paid;

  double get balance => amount - paid;
}

enum StudentFeeAdjustmentType { discount, surcharge }

enum StudentFeeAdjustmentStatus {
  draft,
  pending,
  changesRequested,
  approved,
  complete,
  rejected,
  reversed,
  cancelled,
}

class StudentFeeAdjustment {
  const StudentFeeAdjustment({
    required this.id,
    required this.feeName,
    required this.type,
    required this.amount,
    required this.description,
    required this.status,
    required this.createdOn,
    required this.createdBy,
  });

  final String id;
  final String feeName;
  final StudentFeeAdjustmentType type;
  final double amount;
  final String description;
  final StudentFeeAdjustmentStatus status;
  final DateTime createdOn;
  final String createdBy;

  bool get affectsBalance =>
      status == StudentFeeAdjustmentStatus.approved ||
      status == StudentFeeAdjustmentStatus.complete ||
      status == StudentFeeAdjustmentStatus.reversed;

  double get signedAmount =>
      type == StudentFeeAdjustmentType.discount ? -amount.abs() : amount.abs();

  StudentFeeAdjustment copyWith({
    String? id,
    String? feeName,
    StudentFeeAdjustmentType? type,
    double? amount,
    String? description,
    StudentFeeAdjustmentStatus? status,
    DateTime? createdOn,
    String? createdBy,
  }) {
    return StudentFeeAdjustment(
      id: id ?? this.id,
      feeName: feeName ?? this.feeName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      status: status ?? this.status,
      createdOn: createdOn ?? this.createdOn,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class StudentPayment {
  const StudentPayment({
    required this.date,
    required this.amount,
    required this.method,
    required this.receiptNumber,
  });

  final DateTime date;
  final double amount;
  final String method;
  final String receiptNumber;
}

enum StudentRequirementStatus { complete, partial, outstanding, waived }

class StudentRequirement {
  const StudentRequirement({
    required this.name,
    required this.requiredQuantity,
    required this.receivedQuantity,
    required this.unit,
    required this.status,
    this.note = '',
    this.isFromPreviousTerm = false,
    this.sourceTerm = '',
  });

  final String name;
  final int requiredQuantity;
  final int receivedQuantity;
  final String unit;
  final StudentRequirementStatus status;
  final String note;
  final bool isFromPreviousTerm;
  final String sourceTerm;
}

class StudentDocument {
  const StudentDocument({
    required this.name,
    required this.fileName,
    required this.status,
    required this.updatedOn,
  });

  final String name;
  final String fileName;
  final String status;
  final DateTime updatedOn;
}

class StudentActivity {
  const StudentActivity({
    required this.title,
    required this.description,
    required this.occurredOn,
  });

  final String title;
  final String description;
  final DateTime occurredOn;
}

abstract interface class StudentsRepository {
  Future<List<EnrolledStudent>> getEnrolledStudents();

  Future<EnrolledStudent> getStudent(String studentId);
}
