import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/attendance_models.dart';

class AttendanceApiClient implements AttendanceRepository {
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
                  json['gradeLevelId'] ??
                  json['id'] ??
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
  Future<void> saveAttendance({
    required String customSchoolId,
    required int gradeLevelId,
    required int streamId,
    required DateTime date,
    required List<AttendanceEntry> entries,
    required bool updateExisting,
  }) async {
    final body = entries.map((entry) {
      final present = entry.mark != AttendanceMark.absent;
      return <String, dynamic>{
        if (updateExisting && entry.attendanceId?.isNotEmpty == true)
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
        if (entry.remarks.trim().isNotEmpty) 'remarks': entry.remarks.trim(),
      };
    }).toList();

    await _send(
      updateExisting ? 'PATCH' : 'POST',
      '/api/schools/$customSchoolId/attendance/bulk',
      body: body,
    );
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
      if (decoded is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'detail']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value.trim();
        }
      }
    } catch (_) {}
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

  static String _string(dynamic value) => '${value ?? ''}'.trim();

  static int _integer(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }
}

class AttendanceApiException implements Exception {
  const AttendanceApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
