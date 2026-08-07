import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../staff/data/staff_api_client.dart';
import '../domain/staff_attendance_models.dart';

class StaffAttendanceApiClient implements StaffAttendanceRepository {
  StaffAttendanceApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<StaffAttendanceContext> getContext(String schoolId) async {
    final response = await _send('GET', '/api/v1/current-term/$schoolId');
    final json = _map(response);
    final year = json['academicYear'] is Map
        ? Map<String, dynamic>.from(json['academicYear'])
        : const <String, dynamic>{};
    final type = json['termType'] is Map
        ? Map<String, dynamic>.from(json['termType'])
        : const <String, dynamic>{};
    return StaffAttendanceContext(
      termId: _int(json['id']) ?? 0,
      termLabel:
          (type['name'] ??
                  type['description'] ??
                  json['description'] ??
                  'Current term')
              .toString(),
      academicYear: (year['name'] ?? '').toString(),
    );
  }

  @override
  Future<List<StaffAttendancePerson>> getActiveStaff(String schoolId) async {
    final users = await StaffApiClient(
      accessToken: accessToken,
      onRefreshAccessToken: onRefreshAccessToken,
    ).getSchoolStaffUsers(customSchoolId: schoolId);
    return users
        .where((user) {
          final status = user.accountStatus.toUpperCase();
          return status != 'INACTIVE' &&
              status != 'DISABLED' &&
              status != 'SUSPENDED';
        })
        .map((user) {
          final name = [
            user.firstName,
            user.middleName,
            user.lastName,
          ].where((v) => v.trim().isNotEmpty).join(' ');
          return StaffAttendancePerson(
            id: user.id,
            name: name.isEmpty ? user.userName : name,
            role: user.role.replaceAll('_', ' '),
          );
        })
        .toList();
  }

  @override
  Future<StaffAttendanceDashboardData> getDashboard({
    required String schoolId,
    required int termId,
  }) async {
    final response = await _send(
      'GET',
      '/api/v2/staff-attendance/school/$schoolId/dashboard?termId=$termId',
    );
    final json = _map(response);
    final days = json['days'] is List ? json['days'] as List : const [];
    return StaffAttendanceDashboardData(
      expectedStaffDays: _int(json['expectedStaffDays']) ?? 0,
      presentDays: _int(json['presentDays']) ?? 0,
      lateDays: _int(json['lateDays']) ?? 0,
      excusedAbsences: _int(json['excusedAbsences']) ?? 0,
      unexcusedAbsences: _int(json['unexcusedAbsences']) ?? 0,
      missingRegisters: _int(json['missingRegisters']) ?? 0,
      attendanceRate: _double(json['attendanceRate']),
      punctualityRate: _double(json['punctualityRate']),
      days: days.whereType<Map>().map((raw) {
        final day = Map<String, dynamic>.from(raw);
        return StaffAttendanceDayRecord(
          date: _parseDate(day['date']),
          expected: _int(day['expected']) ?? 0,
          present: _int(day['present']) ?? 0,
          late: _int(day['late']) ?? 0,
          excused: _int(day['excused']) ?? 0,
          unexcused: _int(day['unexcused']) ?? 0,
          status: day['status']?.toString() ?? 'MISSING',
          recordedBy: day['recordedBy']?.toString(),
          eventName: day['eventName']?.toString(),
        );
      }).toList(),
    );
  }

  @override
  Future<void> markNonSchoolDay({
    required String schoolId,
    required NonSchoolDayInput input,
  }) async {
    await _send(
      'POST',
      '/api/v2/staff-attendance/school/$schoolId/non-school-day',
      body: {
        'termId': input.termId,
        'startDate': _date(input.startDate),
        'endDate': _date(input.endDate),
        'name': input.name,
        'type': input.type,
        'description': input.description,
      },
    );
  }

  @override
  Future<List<StaffAttendanceEntry>> getDailyRegister({
    required String schoolId,
    required DateTime date,
    required List<StaffAttendancePerson> people,
  }) async {
    final response = await _send(
      'GET',
      '/api/v2/staff-attendance/school/$schoolId/date/${_date(date)}',
    );
    final records = _list(response);
    return people.map((person) {
      Map<String, dynamic>? record;
      for (final item in records.whereType<Map>()) {
        final candidate = Map<String, dynamic>.from(item);
        if ('${candidate['staffId']}' == person.id) {
          record = candidate;
          break;
        }
      }
      if (record == null) return StaffAttendanceEntry(person: person);
      return StaffAttendanceEntry(
        id: _int(record['id']),
        person: person,
        mark: StaffAttendanceMark.values.firstWhere(
          (mark) =>
              mark.name.toUpperCase() == '${record!['status']}'.toUpperCase(),
          orElse: () => StaffAttendanceMark.unmarked,
        ),
        timeIn: record['timeIn']?.toString(),
        excused: record['excused'] as bool?,
        absenceReason: record['absenceReason']?.toString(),
        note: record['note']?.toString() ?? '',
        registerStatus: record['registerStatus']?.toString() ?? 'DRAFT',
      );
    }).toList();
  }

  @override
  Future<List<StaffAttendanceEntry>> saveDailyRegister({
    required String schoolId,
    required int termId,
    required DateTime date,
    required List<StaffAttendanceEntry> entries,
    required bool submit,
    String? correctionReason,
  }) async {
    final body = entries
        .where((entry) => entry.mark != StaffAttendanceMark.unmarked)
        .map(
          (entry) => {
            'staffId': entry.person.id,
            'schoolId': schoolId,
            'attendanceDate': _date(date),
            'termId': '$termId',
            'weekNumber': 0,
            'status': entry.mark.name.toUpperCase(),
            'timeIn': entry.mark == StaffAttendanceMark.late
                ? entry.timeIn
                : null,
            'excused': entry.mark == StaffAttendanceMark.absent
                ? entry.excused
                : null,
            'absenceReason': entry.mark == StaffAttendanceMark.absent
                ? entry.absenceReason
                : null,
            'note': entry.note.trim().isEmpty ? null : entry.note.trim(),
            'registerStatus': submit ? 'SUBMITTED' : 'DRAFT',
            if (correctionReason != null) 'correctionReason': correctionReason,
          },
        )
        .toList();
    await _send('PUT', '/api/v2/staff-attendance/daily-register', body: body);
    return getDailyRegister(
      schoolId: schoolId,
      date: date,
      people: entries.map((e) => e.person).toList(),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    Future<http.Response> send() {
      final headers = {
        'Content-Type': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      };
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      return (method == 'PUT'
              ? _client.put(uri, headers: headers, body: jsonEncode(body))
              : method == 'POST'
              ? _client.post(uri, headers: headers, body: jsonEncode(body))
              : _client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 20));
    }

    var response = await send();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffAttendanceException(_error(response));
    }
    return response;
  }

  Map<String, dynamic> _map(http.Response r) {
    final v = jsonDecode(r.body);
    return v is Map<String, dynamic> ? v : <String, dynamic>{};
  }

  List<dynamic> _list(http.Response r) {
    final v = jsonDecode(r.body);
    return v is List
        ? v
        : (v is Map && v['data'] is List ? v['data'] as List : const []);
  }

  String _error(http.Response r) {
    try {
      final v = jsonDecode(r.body);
      if (v is Map) {
        return (v['message'] ?? v['error'] ?? 'Unable to save attendance')
            .toString();
      }
    } catch (_) {}
    return 'Unable to save staff attendance (${r.statusCode}).';
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static int? _int(Object? value) =>
      value is int ? value : int.tryParse('$value');
  static double _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  static DateTime _parseDate(Object? value) {
    if (value is List && value.length >= 3) {
      return DateTime(
        _int(value[0]) ?? 0,
        _int(value[1]) ?? 1,
        _int(value[2]) ?? 1,
      );
    }
    return DateTime.parse(value.toString());
  }
}

class StaffAttendanceException implements Exception {
  const StaffAttendanceException(this.message);
  final String message;
  @override
  String toString() => message;
}
