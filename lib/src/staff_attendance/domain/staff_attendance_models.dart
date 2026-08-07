enum StaffAttendanceMark { unmarked, present, late, absent }

class StaffAttendancePerson {
  const StaffAttendancePerson({
    required this.id,
    required this.name,
    required this.role,
  });
  final String id;
  final String name;
  final String role;
  String get initials => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class StaffAttendanceEntry {
  const StaffAttendanceEntry({
    this.id,
    required this.person,
    this.mark = StaffAttendanceMark.unmarked,
    this.timeIn,
    this.excused,
    this.absenceReason,
    this.note = '',
    this.registerStatus = 'DRAFT',
  });

  final int? id;
  final StaffAttendancePerson person;
  final StaffAttendanceMark mark;
  final String? timeIn;
  final bool? excused;
  final String? absenceReason;
  final String note;
  final String registerStatus;

  StaffAttendanceEntry copyWith({
    StaffAttendanceMark? mark,
    String? timeIn,
    bool clearTimeIn = false,
    bool? excused,
    bool clearExcused = false,
    String? absenceReason,
    bool clearAbsenceReason = false,
    String? note,
    String? registerStatus,
  }) => StaffAttendanceEntry(
    id: id,
    person: person,
    mark: mark ?? this.mark,
    timeIn: clearTimeIn ? null : (timeIn ?? this.timeIn),
    excused: clearExcused ? null : (excused ?? this.excused),
    absenceReason: clearAbsenceReason
        ? null
        : (absenceReason ?? this.absenceReason),
    note: note ?? this.note,
    registerStatus: registerStatus ?? this.registerStatus,
  );
}

class StaffAttendanceContext {
  const StaffAttendanceContext({
    required this.termId,
    required this.termLabel,
    required this.academicYear,
  });
  final int termId;
  final String termLabel;
  final String academicYear;
}

class StaffAttendanceDayRecord {
  const StaffAttendanceDayRecord({
    required this.date,
    required this.expected,
    required this.present,
    required this.late,
    required this.excused,
    required this.unexcused,
    required this.status,
    this.recordedBy,
    this.eventName,
  });
  final DateTime date;
  final int expected;
  final int present;
  final int late;
  final int excused;
  final int unexcused;
  final String status;
  final String? recordedBy;
  final String? eventName;
}

class StaffAttendanceDashboardData {
  const StaffAttendanceDashboardData({
    required this.expectedStaffDays,
    required this.presentDays,
    required this.lateDays,
    required this.excusedAbsences,
    required this.unexcusedAbsences,
    required this.missingRegisters,
    required this.attendanceRate,
    required this.punctualityRate,
    required this.days,
  });
  final int expectedStaffDays;
  final int presentDays;
  final int lateDays;
  final int excusedAbsences;
  final int unexcusedAbsences;
  final int missingRegisters;
  final double attendanceRate;
  final double punctualityRate;
  final List<StaffAttendanceDayRecord> days;
}

class NonSchoolDayInput {
  const NonSchoolDayInput({
    required this.termId,
    required this.startDate,
    required this.endDate,
    required this.name,
    required this.type,
    required this.description,
  });
  final int termId;
  final DateTime startDate;
  final DateTime endDate;
  final String name;
  final String type;
  final String description;
}

abstract class StaffAttendanceRepository {
  Future<StaffAttendanceContext> getContext(String schoolId);
  Future<StaffAttendanceDashboardData> getDashboard({
    required String schoolId,
    required int termId,
  });
  Future<void> markNonSchoolDay({
    required String schoolId,
    required NonSchoolDayInput input,
  });
  Future<List<StaffAttendancePerson>> getActiveStaff(String schoolId);
  Future<List<StaffAttendanceEntry>> getDailyRegister({
    required String schoolId,
    required DateTime date,
    required List<StaffAttendancePerson> people,
  });
  Future<List<StaffAttendanceEntry>> saveDailyRegister({
    required String schoolId,
    required int termId,
    required DateTime date,
    required List<StaffAttendanceEntry> entries,
    required bool submit,
    String? correctionReason,
  });
}
