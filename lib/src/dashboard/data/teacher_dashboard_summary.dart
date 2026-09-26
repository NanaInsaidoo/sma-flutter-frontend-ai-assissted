import '../../assessments/data/assessment_api_client.dart';
import '../../assessments/domain/teacher_assessment_scope.dart';
import '../../attendance/data/attendance_api_client.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../incidents/data/incident_api_client.dart';
import '../../incidents/domain/incident_models.dart';
import '../../leave/data/leave_api_client.dart';
import 'teacher_workspace_api_client.dart';

class TeacherAttendanceSummary {
  const TeacherAttendanceSummary({
    required this.schoolDay,
    required this.assignedClasses,
    required this.submittedClasses,
    required this.calendarMessage,
  });

  final bool schoolDay;
  final int assignedClasses;
  final int submittedClasses;
  final String calendarMessage;

  int get pendingClasses => assignedClasses - submittedClasses;
}

class TeacherAssessmentSummary {
  const TeacherAssessmentSummary({
    required this.totalAssessments,
    required this.incompleteAssessments,
    required this.outstandingScores,
  });

  final int totalAssessments;
  final int incompleteAssessments;
  final int outstandingScores;
}

class TeacherLeaveUpdate {
  const TeacherLeaveUpdate({
    required this.id,
    required this.typeName,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final int id;
  final String typeName;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
}

class TeacherDashboardSummary {
  const TeacherDashboardSummary({
    required this.workspace,
    this.attendance,
    this.assessments,
    this.lateConcerns,
    this.upcomingLeave,
    this.myIncidents,
  });

  final TeacherWorkspaceSnapshot workspace;
  final TeacherAttendanceSummary? attendance;
  final TeacherAssessmentSummary? assessments;
  final List<AttendanceLateConcern>? lateConcerns;
  final List<TeacherLeaveUpdate>? upcomingLeave;
  final List<IncidentRecord>? myIncidents;
}

class TeacherDashboardSummaryLoader {
  const TeacherDashboardSummaryLoader({
    required this.schoolId,
    required this.displayName,
    required this.workspaceApi,
    required this.attendanceApi,
    required this.assessmentApi,
    required this.leaveApi,
    required this.incidentApi,
  });

  final String schoolId;
  final String displayName;
  final TeacherWorkspaceApiClient workspaceApi;
  final AttendanceApiClient attendanceApi;
  final AssessmentApiClient assessmentApi;
  final LeaveApiClient leaveApi;
  final IncidentApiClient incidentApi;

  Future<TeacherDashboardSummary> load() async {
    final workspace = await workspaceApi.get(schoolId);
    final results = await Future.wait<Object?>([
      _safe(() => _attendance(workspace)),
      _safe(() => _assessments(workspace)),
      _safe(() => _lateConcerns(workspace)),
      _safe(_leave),
      _safe(_incidents),
    ]);
    return TeacherDashboardSummary(
      workspace: workspace,
      attendance: results[0] as TeacherAttendanceSummary?,
      assessments: results[1] as TeacherAssessmentSummary?,
      lateConcerns: results[2] as List<AttendanceLateConcern>?,
      upcomingLeave: results[3] as List<TeacherLeaveUpdate>?,
      myIncidents: results[4] as List<IncidentRecord>?,
    );
  }

  Future<T?> _safe<T>(Future<T> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  Future<TeacherAttendanceSummary> _attendance(
    TeacherWorkspaceSnapshot workspace,
  ) async {
    final overview = await attendanceApi.getOverviewForDate(
      schoolId,
      DateTime.now(),
    );
    final classTeacherStreamIds = workspace.classes
        .where((assignment) => assignment.active && assignment.classTeacher)
        .map((assignment) => assignment.streamId)
        .toSet();
    final classes = overview.classes
        .where((item) => classTeacherStreamIds.contains(item.streamId))
        .toList();
    return TeacherAttendanceSummary(
      schoolDay: overview.schoolDay,
      assignedClasses: classTeacherStreamIds.length,
      submittedClasses: classes.where((item) => item.submitted).length,
      calendarMessage: overview.calendarMessage,
    );
  }

  Future<TeacherAssessmentSummary> _assessments(
    TeacherWorkspaceSnapshot workspace,
  ) async {
    final setup = scopeAssessmentSetupForTeacher(
      await assessmentApi.getFormSetup(schoolId),
      workspace,
    );
    final registers = await Future.wait(
      setup.streams.map(
        (stream) => assessmentApi.getAssessments(
          customSchoolId: schoolId,
          streamId: stream.id,
          term: setup.termSequence,
          academicYearId: setup.academicYearId,
        ),
      ),
    );
    final assessments = registers.expand((items) => items).toList();
    var incomplete = 0;
    var outstandingScores = 0;
    for (final assessment in assessments) {
      final entered = _integer(assessment['scoresEntered']);
      final total = _integer(assessment['totalStudents']);
      if (entered < total) incomplete++;
      outstandingScores += (total - entered).clamp(0, total);
    }
    return TeacherAssessmentSummary(
      totalAssessments: assessments.length,
      incompleteAssessments: incomplete,
      outstandingScores: outstandingScores,
    );
  }

  Future<List<AttendanceLateConcern>> _lateConcerns(
    TeacherWorkspaceSnapshot workspace,
  ) async {
    final classes = workspace.classes
        .where((assignment) => assignment.active)
        .toList();
    final results = await Future.wait(
      classes.map(
        (assignment) => attendanceApi.getLateConcerns(
          customSchoolId: schoolId,
          gradeLevelId: assignment.gradeLevelId,
          streamId: assignment.streamId,
          date: DateTime.now(),
        ),
      ),
    );
    final unique = <String, AttendanceLateConcern>{};
    for (final concern in results.expand((items) => items)) {
      unique[concern.customStudentId] = concern;
    }
    return unique.values.toList()..sort(
      (left, right) =>
          right.consecutiveLateDays.compareTo(left.consecutiveLateDays),
    );
  }

  Future<List<TeacherLeaveUpdate>> _leave() async {
    final context = await leaveApi.context();
    final currentUserId = _integer(context['currentUserId']);
    final today = _dateOnly(DateTime.now());
    final response = await leaveApi.list(
      staffId: currentUserId,
      from: today,
      page: 0,
      size: 25,
      sortBy: 'startDate',
      direction: 'asc',
    );
    const visibleStatuses = {
      'APPROVED',
      'PENDING_APPROVAL',
      'ON_LEAVE',
      'CHANGE_PENDING_APPROVAL',
      'NEEDS_REVISION',
    };
    final values = (response['items'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where(
          (value) => visibleStatuses.contains(
            '${value['status'] ?? ''}'.toUpperCase(),
          ),
        )
        .map((value) {
          final start = DateTime.tryParse('${value['startDate'] ?? ''}');
          final end = DateTime.tryParse('${value['endDate'] ?? ''}');
          if (start == null || end == null) return null;
          return TeacherLeaveUpdate(
            id: _integer(value['id']),
            typeName:
                '${value['typeName'] ?? value['leaveTypeName'] ?? 'Leave'}',
            startDate: start,
            endDate: end,
            status: '${value['status'] ?? ''}',
          );
        })
        .whereType<TeacherLeaveUpdate>()
        .toList();
    values.sort((left, right) => left.startDate.compareTo(right.startDate));
    return values;
  }

  Future<List<IncidentRecord>> _incidents() async {
    final response = await incidentApi.getIncidents(page: 0, size: 50);
    final normalizedName = displayName.trim().toLowerCase();
    final values = response.items
        .where(
          (incident) =>
              incident.reportedByName.trim().toLowerCase() == normalizedName,
        )
        .toList();
    values.sort(
      (left, right) => right.incidentDate.compareTo(left.incidentDate),
    );
    return values;
  }
}

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
