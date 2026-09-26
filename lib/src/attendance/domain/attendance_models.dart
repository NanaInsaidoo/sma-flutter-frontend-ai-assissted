enum AttendanceMark { unmarked, present, absent, late }

enum AttendanceRegisterStatus {
  notSubmitted,
  awaitingAcknowledgment,
  complete,
  nonSchoolDay,
}

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
    this.gender = '',
    this.dateOfBirth,
  });

  final String customStudentId;
  final String firstName;
  final String lastName;
  final int gradeLevelId;
  final int streamId;
  final String streamName;
  final String gender;
  final DateTime? dateOfBirth;

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

class AttendanceLateConcern {
  const AttendanceLateConcern({
    required this.customStudentId,
    required this.fullName,
    required this.consecutiveLateDays,
    required this.totalMinutesLate,
    required this.latestLateDate,
    this.escalated = false,
    this.escalationId,
    this.escalatedAt,
  });

  final String customStudentId;
  final String fullName;
  final int consecutiveLateDays;
  final int totalMinutesLate;
  final DateTime latestLateDate;
  final bool escalated;
  final int? escalationId;
  final DateTime? escalatedAt;
}

class AttendanceRoster {
  const AttendanceRoster({required this.students, required this.records});

  final List<AttendanceStudent> students;
  final List<AttendanceRecord> records;

  bool get hasExistingAttendance => records.isNotEmpty;
}

class AttendanceEntryContext {
  const AttendanceEntryContext({
    required this.date,
    required this.currentDate,
    required this.futureDate,
    required this.schoolDay,
    required this.assignedClassTeacher,
    required this.permissionAffirmationRequired,
    this.calendarMessage = '',
    this.submitted = false,
    this.registerStatus = AttendanceRegisterStatus.notSubmitted,
    this.revision = 0,
    this.submittedAt,
    this.submittedBy = '',
    this.acknowledgedAt,
    this.acknowledgedBy = '',
    this.acknowledgmentNote = '',
  });

  final DateTime date;
  final DateTime currentDate;
  final bool futureDate;
  final bool schoolDay;
  final bool assignedClassTeacher;
  final bool permissionAffirmationRequired;
  final String calendarMessage;
  final bool submitted;
  final AttendanceRegisterStatus registerStatus;
  final int revision;
  final DateTime? submittedAt;
  final String submittedBy;
  final DateTime? acknowledgedAt;
  final String acknowledgedBy;
  final String acknowledgmentNote;
}

enum AttendanceDayStatus { completed, missing, nonSchoolDay }

class AttendanceDaySummary {
  const AttendanceDaySummary({
    required this.date,
    required this.status,
    required this.expectedStudents,
    this.markedStudents = 0,
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.eventName = '',
    this.eventDescription = '',
  });

  final DateTime date;
  final AttendanceDayStatus status;
  final int expectedStudents;
  final int markedStudents;
  final int present;
  final int absent;
  final int late;
  final String eventName;
  final String eventDescription;
}

class AttendanceTermHistory {
  const AttendanceTermHistory({
    required this.termId,
    required this.teachingStartDate,
    required this.teachingEndDate,
    required this.expectedStudents,
    required this.days,
  });

  final int termId;
  final DateTime teachingStartDate;
  final DateTime teachingEndDate;
  final int expectedStudents;
  final List<AttendanceDaySummary> days;
}

class AttendanceReportOption {
  const AttendanceReportOption({
    required this.customStudentId,
    required this.studentName,
    required this.gradeLevelId,
    required this.gradeName,
    required this.streamId,
    required this.streamName,
    this.householdId,
    this.householdName = '',
  });

  final String customStudentId;
  final String studentName;
  final int gradeLevelId;
  final String gradeName;
  final int streamId;
  final String streamName;
  final int? householdId;
  final String householdName;
}

class AttendanceReportStudent {
  const AttendanceReportStudent({
    required this.customStudentId,
    required this.studentName,
    this.gradeLevelId = 0,
    required this.gradeName,
    this.streamId = 0,
    required this.streamName,
    required this.markedDays,
    required this.present,
    required this.absent,
    required this.late,
    this.lateMinutes = 0,
    required this.attendanceRate,
    required this.absenceRate,
    this.householdId,
    this.householdName = '',
    this.matchingDates = const [],
  });

  final String customStudentId;
  final String studentName;
  final int gradeLevelId;
  final String gradeName;
  final int streamId;
  final String streamName;
  final int markedDays;
  final int present;
  final int absent;
  final int late;
  final int lateMinutes;
  final double attendanceRate;
  final double absenceRate;
  final int? householdId;
  final String householdName;
  final List<DateTime> matchingDates;
}

class AttendanceGeneratedReport {
  const AttendanceGeneratedReport({
    required this.startDate,
    required this.endDate,
    required this.criterion,
    required this.studentsIncluded,
    required this.present,
    required this.absent,
    required this.late,
    required this.attendanceRate,
    required this.students,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String criterion;
  final int studentsIncluded;
  final int present;
  final int absent;
  final int late;
  final double attendanceRate;
  final List<AttendanceReportStudent> students;
}

class AttendanceDashboardOverview {
  const AttendanceDashboardOverview({
    required this.currentDate,
    required this.schoolDay,
    required this.today,
    required this.week,
    required this.month,
    this.term = const AttendancePeriodSummary(
      attendanceRate: 0,
      present: 0,
      absent: 0,
      late: 0,
      totalStudents: 0,
    ),
    required this.classes,
    required this.alerts,
    required this.streamsPending,
    this.calendarMessage = '',
    this.recentSchoolDates = const [],
  });

  final DateTime currentDate;
  final bool schoolDay;
  final AttendancePeriodSummary today;
  final AttendancePeriodSummary week;
  final AttendancePeriodSummary month;
  final AttendancePeriodSummary term;
  final List<AttendanceClassSummary> classes;
  final List<AttendanceAlert> alerts;
  final int streamsPending;
  final String calendarMessage;
  final List<DateTime> recentSchoolDates;
}

class AttendancePeriodSummary {
  const AttendancePeriodSummary({
    required this.attendanceRate,
    required this.present,
    required this.absent,
    required this.late,
    required this.totalStudents,
    this.studentsNeedingAttention = 0,
  });

  final double attendanceRate;
  final int present;
  final int absent;
  final int late;
  final int totalStudents;
  final int studentsNeedingAttention;
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
    this.registerStatus = AttendanceRegisterStatus.notSubmitted,
    this.revision = 0,
    this.submittedAt,
    this.submittedBy = '',
    this.acknowledgedAt,
    this.acknowledgedBy = '',
    this.acknowledgmentNote = '',
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
  final AttendanceRegisterStatus registerStatus;
  final int revision;
  final DateTime? submittedAt;
  final String submittedBy;
  final DateTime? acknowledgedAt;
  final String acknowledgedBy;
  final String acknowledgmentNote;
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

  Future<AttendanceDashboardOverview> getOverviewForDate(
    String customSchoolId,
    DateTime date,
  ) => getOverview(customSchoolId);

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

  Future<AttendanceEntryContext> getEntryContext({
    required String customSchoolId,
    required int streamId,
    required DateTime date,
  });

  Future<List<AttendanceLateConcern>> getLateConcerns({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async => const [];

  Future<AttendanceLateConcern> escalateLateConcern({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required String customStudentId,
    required DateTime date,
    required String note,
  }) => throw UnimplementedError('Late-attendance escalation is unavailable.');

  Future<AttendanceTermHistory> getTermHistory({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
  });

  Future<void> markNonSchoolDay({
    required String customSchoolId,
    required int termId,
    required DateTime date,
    required String name,
    required String type,
    String? description,
  });

  Future<void> acknowledgeAttendance({
    required String customSchoolId,
    required DateTime date,
    required List<int> streamIds,
    String? note,
  });

  Future<void> saveAttendance({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
    required List<AttendanceEntry> entries,
    required bool updateExisting,
    String? vacationOverrideReason,
    bool permissionAffirmed = false,
    String? authorizationStatement,
    String? correctionReason,
  });
}

abstract interface class AttendanceReportRepository {
  Future<List<AttendanceReportOption>> getAttendanceReportOptions({
    required String customSchoolId,
  });

  Future<AttendanceGeneratedReport> generateAttendanceReport({
    required String customSchoolId,
    required String criterion,
    List<int> streamIds = const [],
    List<String> studentIds = const [],
    int? householdId,
    DateTime? startDate,
    DateTime? endDate,
    double? absenteeismThreshold,
  });
}
