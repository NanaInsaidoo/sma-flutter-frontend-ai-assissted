enum AttendanceMark { unmarked, present, absent, late }

class AttendanceGradeLevel {
  const AttendanceGradeLevel({required this.id, required this.name});

  final int id;
  final String name;
}

class AttendanceStream {
  const AttendanceStream({
    required this.id,
    required this.name,
    required this.gradeLevelId,
  });

  final int id;
  final String name;
  final int gradeLevelId;
}

class AttendanceStudent {
  const AttendanceStudent({
    required this.customStudentId,
    required this.firstName,
    required this.lastName,
    required this.gradeLevelId,
    required this.streamId,
    required this.streamName,
  });

  final String customStudentId;
  final String firstName;
  final String lastName;
  final int gradeLevelId;
  final int streamId;
  final String streamName;

  String get fullName => '$firstName $lastName'.trim();
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.customStudentId,
    required this.mark,
    this.attendanceId,
    this.minutesLate = 0,
    this.remarks = '',
  });

  final String customStudentId;
  final AttendanceMark mark;
  final String? attendanceId;
  final int minutesLate;
  final String remarks;
}

class AttendanceRoster {
  const AttendanceRoster({required this.students, required this.records});

  final List<AttendanceStudent> students;
  final List<AttendanceRecord> records;

  bool get hasExistingAttendance => records.isNotEmpty;
}

class AttendanceDashboardOverview {
  const AttendanceDashboardOverview({
    required this.currentDate,
    required this.today,
    required this.week,
    required this.month,
    required this.classes,
    required this.alerts,
    required this.streamsPending,
  });

  final DateTime currentDate;
  final AttendancePeriodSummary today;
  final AttendancePeriodSummary week;
  final AttendancePeriodSummary month;
  final List<AttendanceClassSummary> classes;
  final List<AttendanceAlert> alerts;
  final int streamsPending;
}

class AttendancePeriodSummary {
  const AttendancePeriodSummary({
    required this.attendanceRate,
    required this.present,
    required this.absent,
    required this.late,
    required this.totalStudents,
  });

  final double attendanceRate;
  final int present;
  final int absent;
  final int late;
  final int totalStudents;
}

class AttendanceClassSummary {
  const AttendanceClassSummary({
    required this.gradeId,
    required this.gradeName,
    required this.streamId,
    required this.streamName,
    required this.totalStudents,
    required this.teacherName,
    required this.present,
    required this.absent,
    required this.late,
    required this.attendanceRate,
    required this.submitted,
  });

  final int gradeId;
  final String gradeName;
  final int streamId;
  final String streamName;
  final int totalStudents;
  final String teacherName;
  final int present;
  final int absent;
  final int late;
  final double attendanceRate;
  final bool submitted;
}

class AttendanceAlert {
  const AttendanceAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.gradeId,
    this.streamId,
  });

  final String title;
  final String message;
  final String severity;
  final DateTime? timestamp;
  final int? gradeId;
  final int? streamId;
}

class AttendanceEntry {
  const AttendanceEntry({
    required this.student,
    this.mark = AttendanceMark.unmarked,
    this.attendanceId,
    this.minutesLate = 0,
    this.remarks = '',
  });

  final AttendanceStudent student;
  final AttendanceMark mark;
  final String? attendanceId;
  final int minutesLate;
  final String remarks;

  AttendanceEntry copyWith({
    AttendanceMark? mark,
    String? attendanceId,
    int? minutesLate,
    String? remarks,
  }) {
    return AttendanceEntry(
      student: student,
      mark: mark ?? this.mark,
      attendanceId: attendanceId ?? this.attendanceId,
      minutesLate: minutesLate ?? this.minutesLate,
      remarks: remarks ?? this.remarks,
    );
  }
}

abstract class AttendanceRepository {
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId);

  Future<List<AttendanceGradeLevel>> getGradeLevels(String customSchoolId);

  Future<List<AttendanceStream>> getStreams({
    required String customSchoolId,
    required int gradeLevelId,
  });

  Future<AttendanceRoster> getRoster({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  });

  Future<void> saveAttendance({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
    required List<AttendanceEntry> entries,
    required bool updateExisting,
  });
}
