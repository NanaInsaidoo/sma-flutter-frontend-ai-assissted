import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/attendance_models.dart';

class AttendanceApiClient
    implements AttendanceRepository, AttendanceReportRepository {
  AttendanceApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<AttendanceDashboardOverview> getOverview(String customSchoolId) async {
    return _getOverview(customSchoolId);
  }

  @override
  Future<AttendanceDashboardOverview> getOverviewForDate(
    String customSchoolId,
    DateTime date,
  ) async {
    return _getOverview(customSchoolId, date: date);
  }

  Future<AttendanceDashboardOverview> _getOverview(
    String customSchoolId, {
    DateTime? date,
  }) async {
    final response = await _send(
      'GET',
      date == null
          ? '/api/schools/$customSchoolId/attendance/overview'
          : _withQuery('/api/schools/$customSchoolId/attendance/overview', {
              'date': _date(date),
            }),
    );
    final json = _map(_decode(response));
    if (json == null) {
      throw const AttendanceApiException(
        'The attendance overview response was empty.',
      );
    }

    final schoolStats = _map(json['schoolStats']) ?? const {};
    final summary = _map(json['summary']) ?? const {};
    final todaySummary = _map(summary['today']) ?? const {};
    final todayStats = _map(schoolStats['today']) ?? const {};
    final weekStats = _map(schoolStats['week']) ?? const {};
    final monthStats = _map(schoolStats['month']) ?? const {};
    final termStats = _map(schoolStats['term']) ?? const {};

    final classes = _list(json['gradeStreamBreakdown'])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final teacher = _map(item['teacher']) ?? const {};
          final stats = _map(item['todayStats']) ?? const {};
          final submitted = stats['submitted'] == true;
          return AttendanceClassSummary(
            gradeId: _integer(item['gradeId']),
            gradeName: _string(item['grade']),
            streamId: _integer(item['streamId']),
            streamName: _string(item['stream']),
            totalStudents: _integer(item['totalStudents']),
            teacherName: _string(teacher['teacherName']),
            present: _integer(stats['present']),
            absent: _integer(stats['absent']),
            late: _integer(stats['late']),
            attendanceRate: _decimal(stats['rate']),
            submitted: submitted,
            registerStatus: _registerStatus(
              stats['registerStatus'],
              submitted: submitted,
              schoolDay: json['schoolDay'] != false,
            ),
            revision: _integer(stats['revision']),
            submittedAt: _dateTime(stats['submittedAt']),
            submittedBy: _string(stats['submittedBy']),
            acknowledgedAt: _dateTime(stats['acknowledgedAt']),
            acknowledgedBy: _string(stats['acknowledgedBy']),
            acknowledgmentNote: _string(stats['acknowledgmentNote']),
          );
        })
        .where((item) => item.gradeId > 0 && item.streamId > 0)
        .toList();

    final alerts = _list(json['alerts'])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final rawMessage = _string(item['message']);
          final explicitTitle = _string(item['title']);
          final separator = rawMessage.indexOf(':');
          final title = explicitTitle.isNotEmpty
              ? explicitTitle
              : separator > 0
              ? rawMessage.substring(0, separator).trim()
              : '';
          final message = explicitTitle.isEmpty && separator > 0
              ? rawMessage.substring(separator + 1).trim()
              : rawMessage;
          return AttendanceAlert(
            title: title,
            message: message,
            severity: _string(item['severity']),
            timestamp: DateTime.tryParse(_string(item['timestamp'])),
            gradeId: _nullableInteger(item['gradeId']),
            streamId: _nullableInteger(item['streamId']),
          );
        })
        .where((item) => item.message.isNotEmpty)
        .toList();

    return AttendanceDashboardOverview(
      currentDate: _dateTime(json['currentDate']) ?? DateTime.now(),
      schoolDay: json['schoolDay'] != false,
      today: AttendancePeriodSummary(
        attendanceRate: _decimal(todayStats['attendanceRate']),
        present: _integer(todayStats['present']),
        absent: _integer(todayStats['absent']),
        late: _integer(todayStats['late']),
        totalStudents: _integer(todayStats['totalStudents']),
      ),
      week: AttendancePeriodSummary(
        attendanceRate: _decimal(weekStats['attendanceRate']),
        present: _integer(weekStats['avgPresent']),
        absent: _integer(weekStats['avgAbsent']),
        late: _integer(weekStats['avgLate']),
        totalStudents: _integer(weekStats['totalStudents']),
      ),
      month: AttendancePeriodSummary(
        attendanceRate: _decimal(monthStats['avgAttendanceRate']),
        present: 0,
        absent: _integer(monthStats['totalAbsences']),
        late: _integer(monthStats['totalLateArrivals']),
        totalStudents: _integer(monthStats['totalStudents']),
      ),
      term: AttendancePeriodSummary(
        attendanceRate: _decimal(termStats['attendanceRate']),
        present: _integer(termStats['present']),
        absent: _integer(termStats['absent']),
        late: _integer(termStats['late']),
        totalStudents: _integer(termStats['totalRecords']),
        studentsNeedingAttention: _integer(
          termStats['studentsNeedingAttention'],
        ),
      ),
      classes: classes,
      alerts: alerts,
      streamsPending: _integer(todaySummary['streamsPending']),
      calendarMessage: _string(json['calendarMessage']),
      recentSchoolDates: _list(
        json['recentSchoolDates'],
      ).map(_dateTime).whereType<DateTime>().toList(),
    );
  }

  @override
  Future<List<AttendanceGradeLevel>> getGradeLevels(
    String customSchoolId,
  ) async {
    final response = await _send(
      'GET',
      '/api/grade-levels/school/$customSchoolId',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final nested = _map(json['gradeLevel']);
          return AttendanceGradeLevel(
            id: _integer(
              json['schoolGradeLevelId'] ??
                  json['id'] ??
                  json['gradeLevelId'] ??
                  nested?['id'],
            ),
            name: _string(
              json['gradeName'] ??
                  json['gradeLevelName'] ??
                  json['name'] ??
                  nested?['name'],
            ),
          );
        })
        .where((grade) => grade.id > 0 && grade.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<AttendanceStream>> getStreams({
    required String customSchoolId,
    required int gradeLevelId,
  }) async {
    final path = _withQuery(
      '/api/grade-levels/school/$customSchoolId/streams',
      {'gradeLevelId': '$gradeLevelId'},
    );
    final response = await _send('GET', path);
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map((json) {
          return AttendanceStream(
            id: _integer(json['streamId'] ?? json['id']),
            name: _string(
              json['streamName'] ?? json['name'] ?? json['section'],
            ),
            gradeLevelId: _integer(
              json['gradeLevelId'] ?? json['schoolGradeLevelId'],
              fallback: gradeLevelId,
            ),
          );
        })
        .where((stream) => stream.id > 0 && stream.name.isNotEmpty)
        .toList();
  }

  @override
  Future<AttendanceRoster> getRoster({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async {
    final results = await Future.wait([
      _send(
        'GET',
        _withQuery('/api/schools/$customSchoolId/attendance/students', {
          'gradeLevelId': '$gradeLevelId',
          'streamId': '$streamId',
        }),
      ),
      _send(
        'GET',
        _withQuery(
          '/api/schools/$customSchoolId/attendance/streams/$streamId',
          {'gradeLevelId': '$gradeLevelId', 'date': _date(date)},
        ),
        allowNotFound: true,
      ),
    ]);

    final students = _extractList(_decode(results[0]))
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => AttendanceStudent(
            customStudentId: _string(
              json['customStudentId'] ?? json['studentId'],
            ),
            firstName: _string(json['firstName']),
            lastName: _string(json['lastName']),
            gradeLevelId: _integer(
              json['gradeLevelId'],
              fallback: gradeLevelId,
            ),
            streamId: _integer(json['streamId'], fallback: streamId),
            streamName: _string(json['streamName']),
            gender: _string(json['gender']),
            dateOfBirth: _dateTime(json['dateOfBirth']),
          ),
        )
        .where(
          (student) =>
              student.customStudentId.isNotEmpty && student.fullName.isNotEmpty,
        )
        .toList();

    final records = results[1].statusCode == 404
        ? <AttendanceRecord>[]
        : _extractList(_decode(results[1]))
              .whereType<Map<String, dynamic>>()
              .map(_recordFromJson)
              .where((record) => record.customStudentId.isNotEmpty)
              .toList();

    return AttendanceRoster(students: students, records: records);
  }

  @override
  Future<AttendanceEntryContext> getEntryContext({
    required String customSchoolId,
    required int streamId,
    required DateTime date,
  }) async {
    final response = await _send(
      'GET',
      _withQuery(
        '/api/schools/$customSchoolId/attendance/streams/$streamId/entry-context',
        {'date': _date(date)},
      ),
    );
    final json = _map(_decode(response));
    if (json == null) {
      throw const AttendanceApiException(
        'The attendance rules could not be loaded.',
      );
    }
    return AttendanceEntryContext(
      date: _dateTime(json['date']) ?? date,
      currentDate: _dateTime(json['currentDate']) ?? DateTime.now(),
      futureDate: json['futureDate'] == true,
      schoolDay: json['schoolDay'] == true,
      assignedClassTeacher: json['assignedClassTeacher'] == true,
      permissionAffirmationRequired:
          json['permissionAffirmationRequired'] == true,
      calendarMessage: _string(json['calendarMessage']),
      submitted: json['submitted'] == true,
      registerStatus: _registerStatus(
        json['registerStatus'],
        submitted: json['submitted'] == true,
        schoolDay: json['schoolDay'] == true,
      ),
      revision: _integer(json['revision']),
      submittedAt: _dateTime(json['submittedAt']),
      submittedBy: _string(json['submittedBy']),
      acknowledgedAt: _dateTime(json['acknowledgedAt']),
      acknowledgedBy: _string(json['acknowledgedBy']),
      acknowledgmentNote: _string(json['acknowledgmentNote']),
    );
  }

  @override
  Future<List<AttendanceLateConcern>> getLateConcerns({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
  }) async {
    final response = await _send(
      'GET',
      _withQuery(
        '/api/schools/$customSchoolId/attendance/streams/$streamId/late-attention',
        {'gradeLevelId': '$gradeLevelId', 'date': _date(date)},
      ),
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(_lateConcernFromJson)
        .where((item) => item.customStudentId.isNotEmpty)
        .toList();
  }

  @override
  Future<AttendanceLateConcern> escalateLateConcern({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required String customStudentId,
    required DateTime date,
    required String note,
  }) async {
    final response = await _send(
      'POST',
      _withQuery(
        '/api/schools/$customSchoolId/attendance/streams/$streamId/'
        'late-attention/$customStudentId/escalations',
        {'gradeLevelId': '$gradeLevelId', 'date': _date(date)},
      ),
      body: {'note': note.trim()},
    );
    final json = _map(_decode(response));
    if (json == null) {
      throw const AttendanceApiException(
        'The repeated-lateness escalation response was empty.',
      );
    }
    return _lateConcernFromJson(json);
  }

  @override
  Future<AttendanceTermHistory> getTermHistory({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery(
        '/api/schools/$customSchoolId/attendance/streams/$streamId/term-history',
        {'gradeLevelId': '$gradeLevelId'},
      ),
    );
    final json = _map(_decode(response)) ?? const {};
    final days = _list(json['days']).whereType<Map<String, dynamic>>().map((
      item,
    ) {
      final rawStatus = _string(item['status']).toUpperCase();
      return AttendanceDaySummary(
        date: _dateTime(item['date']) ?? DateTime.now(),
        status: rawStatus == 'COMPLETED'
            ? AttendanceDayStatus.completed
            : rawStatus == 'NON_SCHOOL_DAY'
            ? AttendanceDayStatus.nonSchoolDay
            : AttendanceDayStatus.missing,
        expectedStudents: _integer(item['expectedStudents']),
        markedStudents: _integer(item['markedStudents']),
        present: _integer(item['present']),
        absent: _integer(item['absent']),
        late: _integer(item['late']),
        eventName: _string(item['eventName']),
        eventDescription: _string(item['eventDescription']),
      );
    }).toList();
    return AttendanceTermHistory(
      termId: _integer(json['termId']),
      teachingStartDate: _dateTime(json['teachingStartDate']) ?? DateTime.now(),
      teachingEndDate: _dateTime(json['teachingEndDate']) ?? DateTime.now(),
      expectedStudents: _integer(json['expectedStudents']),
      days: days,
    );
  }

  @override
  Future<List<AttendanceReportOption>> getAttendanceReportOptions({
    required String customSchoolId,
  }) async {
    final response = await _send(
      'GET',
      '/api/schools/$customSchoolId/attendance/report/options',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AttendanceReportOption(
            customStudentId: _string(item['customStudentId']),
            studentName: _string(item['studentName']),
            gradeLevelId: _integer(item['gradeLevelId']),
            gradeName: _string(item['gradeName']),
            streamId: _integer(item['streamId']),
            streamName: _string(item['streamName']),
            householdId: _nullableInteger(item['householdId']),
            householdName: _string(item['householdName']),
          ),
        )
        .where((item) => item.customStudentId.isNotEmpty)
        .toList();
  }

  @override
  Future<AttendanceGeneratedReport> generateAttendanceReport({
    required String customSchoolId,
    required String criterion,
    List<int> streamIds = const [],
    List<String> studentIds = const [],
    int? householdId,
    DateTime? startDate,
    DateTime? endDate,
    double? absenteeismThreshold,
  }) async {
    final query = <String, String>{
      'criterion': criterion,
      if (streamIds.isNotEmpty) 'streamIds': streamIds.join(','),
      if (studentIds.isNotEmpty) 'studentIds': studentIds.join(','),
      if (householdId != null) 'householdId': '$householdId',
      if (startDate != null) 'startDate': _date(startDate),
      if (endDate != null) 'endDate': _date(endDate),
      if (absenteeismThreshold != null)
        'absenteeismThreshold': '$absenteeismThreshold',
    };
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/attendance/report', query),
    );
    final json = _map(_decode(response));
    if (json == null) {
      throw const AttendanceApiException(
        'The attendance report response was empty.',
      );
    }
    final students = _list(json['students'])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AttendanceReportStudent(
            customStudentId: _string(item['customStudentId']),
            studentName: _string(item['studentName']),
            gradeLevelId: _integer(item['gradeLevelId']),
            gradeName: _string(item['gradeName']),
            streamId: _integer(item['streamId']),
            streamName: _string(item['streamName']),
            markedDays: _integer(item['markedDays']),
            present: _integer(item['present']),
            absent: _integer(item['absent']),
            late: _integer(item['late']),
            lateMinutes: _integer(item['lateMinutes']),
            attendanceRate: _decimal(item['attendanceRate']),
            absenceRate: _decimal(item['absenceRate']),
            householdId: _nullableInteger(item['householdId']),
            householdName: _string(item['householdName']),
            matchingDates: _list(
              item['matchingDates'],
            ).map((value) => _dateTime(value)).whereType<DateTime>().toList(),
          ),
        )
        .toList();
    return AttendanceGeneratedReport(
      startDate: _dateTime(json['startDate']) ?? DateTime.now(),
      endDate: _dateTime(json['endDate']) ?? DateTime.now(),
      criterion: _string(json['criterion']),
      studentsIncluded: _integer(json['studentsIncluded']),
      present: _integer(json['present']),
      absent: _integer(json['absent']),
      late: _integer(json['late']),
      attendanceRate: _decimal(json['attendanceRate']),
      students: students,
    );
  }

  @override
  Future<void> markNonSchoolDay({
    required String customSchoolId,
    required int termId,
    required DateTime date,
    required String name,
    required String type,
    String? description,
  }) async {
    await _send(
      'POST',
      '/api/v2/staff-attendance/school/$customSchoolId/non-school-day',
      body: {
        'termId': termId,
        'startDate': _date(date),
        'endDate': _date(date),
        'name': name,
        'type': type,
        if (description?.trim().isNotEmpty == true)
          'description': description!.trim(),
      },
    );
  }

  @override
  Future<void> acknowledgeAttendance({
    required String customSchoolId,
    required DateTime date,
    required List<int> streamIds,
    String? note,
  }) async {
    await _send(
      'POST',
      '/api/schools/$customSchoolId/attendance/acknowledgments',
      body: {
        'date': _date(date),
        'streamIds': streamIds,
        if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
      },
    );
  }

  @override
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
  }) async {
    Map<String, dynamic> payload(AttendanceEntry entry) {
      final present = entry.mark != AttendanceMark.absent;
      return <String, dynamic>{
        if (entry.attendanceId?.isNotEmpty == true)
          'attendanceId': entry.attendanceId,
        'customStudentId': entry.student.customStudentId,
        'gradeLevelId': '$gradeLevelId',
        'streamId': streamId,
        'attendanceStatus': present ? 'PRESENT' : 'ABSENT',
        'lateStatus': entry.mark == AttendanceMark.late ? 'LATE' : 'ON_TIME',
        'minutesLate': entry.mark == AttendanceMark.late
            ? entry.minutesLate
            : 0,
        'attendanceDate': _date(date),
        if (vacationOverrideReason?.trim().isNotEmpty == true)
          'vacationOverrideReason': vacationOverrideReason!.trim(),
        'permissionAffirmed': permissionAffirmed,
        if (authorizationStatement?.trim().isNotEmpty == true)
          'authorizationStatement': authorizationStatement!.trim(),
        if (correctionReason?.trim().isNotEmpty == true)
          'correctionReason': correctionReason!.trim(),
        if (entry.remarks.trim().isNotEmpty) 'remarks': entry.remarks.trim(),
      };
    }

    final endpoint = '/api/schools/$customSchoolId/attendance/bulk';
    if (!updateExisting) {
      await _send('POST', endpoint, body: entries.map(payload).toList());
      return;
    }

    await _send('PATCH', endpoint, body: entries.map(payload).toList());
  }

  AttendanceRecord _recordFromJson(Map<String, dynamic> json) {
    final attendanceStatus = _string(json['attendanceStatus']).toUpperCase();
    final lateStatus = _string(json['lateStatus']).toUpperCase();
    final mark = lateStatus == 'LATE'
        ? AttendanceMark.late
        : attendanceStatus == 'PRESENT'
        ? AttendanceMark.present
        : attendanceStatus == 'ABSENT'
        ? AttendanceMark.absent
        : AttendanceMark.unmarked;
    return AttendanceRecord(
      attendanceId: _string(json['attendanceId'] ?? json['id']),
      customStudentId: _string(json['customStudentId']),
      mark: mark,
      minutesLate: _integer(json['minutesLate']),
      remarks: _string(json['remarks']),
    );
  }

  AttendanceLateConcern _lateConcernFromJson(Map<String, dynamic> json) {
    return AttendanceLateConcern(
      customStudentId: _string(json['customStudentId']),
      fullName: _string(json['fullName']),
      consecutiveLateDays: _integer(json['consecutiveLateDays']),
      totalMinutesLate: _integer(json['totalMinutesLate']),
      latestLateDate: _dateTime(json['latestLateDate']) ?? DateTime.now(),
      escalated: json['escalated'] == true,
      escalationId: _nullableInteger(json['escalationId']),
      escalatedAt: _dateTime(json['escalatedAt']),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    bool allowNotFound = false,
  }) async {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const AttendanceApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken!.trim()}',
      };
      final encodedBody = body == null ? null : jsonEncode(body);
      return switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: encodedBody),
        'PATCH' => _client.patch(uri, headers: headers, body: encodedBody),
        _ => throw AttendanceApiException('Unsupported request: $method'),
      };
    }

    var response = await send().timeout(const Duration(seconds: 30));
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshed = await onRefreshAccessToken!();
      if (refreshed?.trim().isNotEmpty == true) {
        accessToken = refreshed!.trim();
        response = await send().timeout(const Duration(seconds: 30));
      }
    }

    if (allowNotFound && response.statusCode == 404) return response;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AttendanceApiException(_errorMessage(response));
    }
    return response;
  }

  dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) return const <dynamic>[];
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const AttendanceApiException(
        'The attendance service returned an invalid response.',
      );
    }
  }

  List<dynamic> _extractList(dynamic value) {
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      for (final key in ['content', 'data', 'students', 'records', 'items']) {
        final nested = value[key];
        if (nested is List) return nested;
        if (nested is Map<String, dynamic>) {
          final content = nested['content'];
          if (content is List) return content;
        }
      }
    }
    return const [];
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded.trim();
      }
      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is String &&
          (decoded.first as String).trim().isNotEmpty) {
        return (decoded.first as String).trim();
      }
      if (decoded is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'detail']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
    } catch (_) {
      final raw = response.body.trim();
      if (raw.isNotEmpty) return raw;
    }
    return 'Attendance request failed (${response.statusCode}).';
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _withQuery(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query).toString();

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map<String, dynamic> ? value : null;

  static List<dynamic> _list(dynamic value) =>
      value is List ? value : const <dynamic>[];

  static String _string(dynamic value) => '${value ?? ''}'.trim();

  static int _integer(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  static int? _nullableInteger(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double _decimal(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static DateTime? _dateTime(dynamic value) {
    if (value is List && value.length >= 3) {
      return DateTime(
        _integer(value[0]),
        _integer(value[1]),
        _integer(value[2]),
      );
    }
    return DateTime.tryParse(_string(value));
  }

  static AttendanceRegisterStatus _registerStatus(
    dynamic value, {
    required bool submitted,
    required bool schoolDay,
  }) {
    if (!schoolDay) return AttendanceRegisterStatus.nonSchoolDay;
    return switch (_string(value).toUpperCase()) {
      'AWAITING_ACKNOWLEDGMENT' =>
        AttendanceRegisterStatus.awaitingAcknowledgment,
      'COMPLETE' => AttendanceRegisterStatus.complete,
      'NON_SCHOOL_DAY' => AttendanceRegisterStatus.nonSchoolDay,
      _ =>
        submitted
            ? AttendanceRegisterStatus.awaitingAcknowledgment
            : AttendanceRegisterStatus.notSubmitted,
    };
  }
}

class AttendanceApiException implements Exception {
  const AttendanceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
