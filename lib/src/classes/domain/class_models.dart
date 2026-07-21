abstract class ClassesRepository {
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
  });

  final int id;
  final int gradeLevelId;
  final String name;
  final String status;
  final List<ClassStreamSummary> streams;
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
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String status;

  bool get active => status.trim().toUpperCase() == 'ACTIVE';
}
