abstract class ClassesRepository {
  Future<List<ClassGradeLevel>> getAllGradeLevels(String customSchoolId);

  Future<void> setGradeLevelActive({
    required String customSchoolId,
    required int gradeLevelId,
    required bool active,
  });

  Future<ClassGradeLevel> createCustomGradeLevel({
    required String customSchoolId,
    required String name,
    required int streamCount,
  });

  Future<ClassGradeLevel> updateCustomGradeLevel({
    required String customSchoolId,
    required ClassGradeLevel grade,
    required String name,
    required int displayOrder,
  });

  Future<List<ClassSubject>> getGradeSubjects({
    required String customSchoolId,
    required int gradeLevelId,
  });

  Future<ClassSubject> createCustomSubject({
    required String customSchoolId,
    required int gradeLevelId,
    required String name,
    required String code,
    required bool examinable,
  });

  Future<void> updateCustomSubject({
    required String customSchoolId,
    required ClassSubject subject,
  });

  Future<void> deleteCustomSubject({
    required String customSchoolId,
    required int subjectId,
  });

  Future<List<ClassGradeLevel>> getGradeStreams(String customSchoolId);

  Future<List<ClassGradeLevel>> getAllStreams(String customSchoolId);

  Future<void> createStream({
    required String customSchoolId,
    required int gradeLevelId,
    required String streamName,
  });

  Future<void> updateStreamCapacities({
    required String customSchoolId,
    required List<StreamCapacityUpdate> updates,
  });

  Future<void> deleteStreams({
    required String customSchoolId,
    required List<int> streamIds,
  });

  Future<List<ClassTeacherAssignment>> getClassTeachers({
    required String customSchoolId,
    required int streamId,
  });

  Future<ClassTeacherAssignment?> addClassTeacher({
    required String customSchoolId,
    required int streamId,
    required String staffId,
    required bool isPrimary,
  });

  Future<ClassTeacherAssignment?> updateClassTeacher({
    required String customSchoolId,
    required int classTeacherId,
    required bool isPrimary,
    required bool isActive,
  });

  Future<void> removeClassTeacher({
    required String customSchoolId,
    required int classTeacherId,
  });

  Future<ClassTeacherAssignment?> setPrimaryClassTeacher({
    required String customSchoolId,
    required int streamId,
    required int classTeacherId,
  });

  Future<List<SchoolStaffOption>> getSchoolStaff(String customSchoolId);

  Future<void> grantStaffRole({
    required String customSchoolId,
    required SchoolStaffOption staff,
    required String role,
  });

  Future<List<SubjectTeacherAssignment>> getSubjectTeacherAssignments({
    required String customSchoolId,
    required int streamId,
  });

  Future<SubjectTeacherAssignment> addSubjectTeacherAssignment({
    required String customSchoolId,
    required int streamId,
    required int gradeLevelId,
    required ClassSubject subject,
    required String staffId,
    DateTime? effectiveFrom,
    String? reason,
  });

  Future<void> removeSubjectTeacherAssignment({
    required String customSchoolId,
    required int streamId,
    required int assignmentId,
    DateTime? effectiveFrom,
    String? reason,
  });
}

class StreamCapacityUpdate {
  const StreamCapacityUpdate({required this.streamId, required this.capacity});

  final int streamId;
  final int capacity;
}

class ClassGradeLevel {
  const ClassGradeLevel({
    required this.id,
    required this.gradeLevelId,
    required this.name,
    required this.status,
    required this.streams,
    this.custom = false,
    this.studentCount = 0,
    this.displayOrder = 0,
    this.nextGradeLevelId,
    this.nextGradeLevelName,
  });

  final int id;
  final int gradeLevelId;
  final String name;
  final String status;
  final List<ClassStreamSummary> streams;
  final bool custom;
  final int studentCount;
  final int displayOrder;
  final int? nextGradeLevelId;
  final String? nextGradeLevelName;

  bool get active => status.trim().isEmpty || status.toUpperCase() == 'ACTIVE';
}

class ClassSubject {
  const ClassSubject({
    required this.id,
    required this.name,
    required this.code,
    required this.custom,
    required this.active,
    required this.examinable,
  });

  final int id;
  final String name;
  final String code;
  final bool custom;
  final bool active;
  final bool examinable;
}

class ClassStreamSummary {
  const ClassStreamSummary({
    required this.id,
    required this.name,
    required this.gradeLevelId,
    required this.teacherName,
    required this.enrolled,
    required this.capacity,
    required this.active,
  });

  final int id;
  final String name;
  final int gradeLevelId;
  final String teacherName;
  final int enrolled;
  final int? capacity;
  final bool active;
}

class ClassTeacherAssignment {
  const ClassTeacherAssignment({
    required this.id,
    required this.staffId,
    required this.name,
    required this.email,
    required this.role,
    required this.isPrimary,
    required this.isActive,
  });

  final int id;
  final String staffId;
  final String name;
  final String email;
  final String role;
  final bool isPrimary;
  final bool isActive;
}

class SchoolStaffOption {
  const SchoolStaffOption({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.roles,
    required this.status,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final List<String> roles;
  final String status;

  bool get active => status.trim().toUpperCase() == 'ACTIVE';

  bool hasRole(String requiredRole) => roles.any(
    (role) => role.trim().toUpperCase() == requiredRole.trim().toUpperCase(),
  );
}

class SubjectTeacherAssignment {
  const SubjectTeacherAssignment({
    required this.id,
    required this.streamId,
    required this.subjectId,
    required this.subjectType,
    required this.subjectName,
    required this.subjectCode,
    required this.staffId,
    required this.staffName,
    required this.active,
    this.effectiveFrom,
    this.changeReason = '',
  });
  final int id, streamId, subjectId;
  final String subjectType, subjectName, subjectCode, staffId, staffName;
  final bool active;
  final DateTime? effectiveFrom;
  final String changeReason;
}
