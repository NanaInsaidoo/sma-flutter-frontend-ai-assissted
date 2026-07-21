import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/class_models.dart';

class ClassesApiClient implements ClassesRepository {
  ClassesApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<List<ClassGradeLevel>> getGradeStreams(String customSchoolId) async {
    final response = await _send(
      'GET',
      '/api/grade-levels/school/$customSchoolId',
    );
    final grades = _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(_gradeFromJson)
        .where((grade) => grade.id > 0 && grade.name.isNotEmpty)
        .toList();

    final missingStreamGrades = grades
        .where((grade) => grade.streams.isEmpty)
        .toList();
    if (missingStreamGrades.isEmpty) return grades;

    final hydrated = await Future.wait(
      grades.map((grade) async {
        if (grade.streams.isNotEmpty) return grade;
        final path = _withQuery(
          '/api/grade-levels/school/$customSchoolId/streams',
          {'gradeLevelId': '${grade.id}'},
        );
        final streamResponse = await _send('GET', path);
        final streams = _extractList(_decode(streamResponse))
            .whereType<Map<String, dynamic>>()
            .map(
              (json) => _streamFromJson(json, fallbackGradeLevelId: grade.id),
            )
            .where((stream) => stream.id > 0 && stream.name.isNotEmpty)
            .toList();
        return ClassGradeLevel(
          id: grade.id,
          gradeLevelId: grade.gradeLevelId,
          name: grade.name,
          status: grade.status,
          streams: streams,
        );
      }),
    );
    return hydrated;
  }

  @override
  Future<List<ClassGradeLevel>> getAllStreams(String customSchoolId) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _send(
      'GET',
      '/api/grade-levels/school/$encoded/all-streams',
    );
    return _gradeLevelsFromAllStreams(_extractList(_decode(response)));
  }

  @override
  Future<void> createStream({
    required String customSchoolId,
    required int gradeLevelId,
    required String streamName,
  }) async {
    final body = <String, dynamic>{
      'name': streamName,
      'alias': streamName,
      'gradeLevelId': gradeLevelId,
      'isActive': true,
    };
    await _send(
      'POST',
      _withQuery('/api/grade-levels/school/$customSchoolId/streams', {
        'gradeLevelId': '$gradeLevelId',
      }),
      body: body,
    );
  }

  @override
  Future<void> updateStreamCapacities({
    required String customSchoolId,
    required List<StreamCapacityUpdate> updates,
  }) async {
    if (updates.isEmpty) return;
    await _send(
      'PUT',
      '/api/grade-levels/school/$customSchoolId/streams/batch-capacity',
      body: {
        'updates': updates
            .map(
              (update) => {
                'streamId': update.streamId,
                'capacity': update.capacity,
              },
            )
            .toList(),
      },
    );
  }

  @override
  Future<void> deleteStreams({
    required String customSchoolId,
    required List<int> streamIds,
  }) async {
    if (streamIds.isEmpty) return;
    await _send(
      'DELETE',
      '/api/grade-levels/school/$customSchoolId/streams/batch',
      body: streamIds,
    );
  }

  @override
  Future<List<ClassTeacherAssignment>> getClassTeachers({
    required String customSchoolId,
    required int streamId,
  }) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _send(
      'GET',
      '/api/grade-levels/school/$encoded/streams/$streamId/class-teachers',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(_classTeacherFromJson)
        .where((teacher) => teacher.id > 0)
        .toList();
  }

  @override
  Future<ClassTeacherAssignment?> addClassTeacher({
    required String customSchoolId,
    required int streamId,
    required String staffId,
    required bool isPrimary,
  }) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _send(
      'POST',
      '/api/grade-levels/school/$encoded/streams/$streamId/class-teachers',
      body: {'staffId': staffId, 'isPrimary': isPrimary},
    );
    return _nullableClassTeacherFromResponse(response);
  }

  @override
  Future<ClassTeacherAssignment?> updateClassTeacher({
    required String customSchoolId,
    required int classTeacherId,
    required bool isPrimary,
    required bool isActive,
  }) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _send(
      'PUT',
      '/api/grade-levels/school/$encoded/class-teachers/$classTeacherId',
      body: {'isPrimary': isPrimary, 'isActive': isActive},
    );
    return _nullableClassTeacherFromResponse(response);
  }

  @override
  Future<void> removeClassTeacher({
    required String customSchoolId,
    required int classTeacherId,
  }) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    await _send(
      'DELETE',
      '/api/grade-levels/school/$encoded/class-teachers/$classTeacherId',
    );
  }

  @override
  Future<ClassTeacherAssignment?> setPrimaryClassTeacher({
    required String customSchoolId,
    required int streamId,
    required int classTeacherId,
  }) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _send(
      'PUT',
      '/api/grade-levels/school/$encoded/streams/$streamId/class-teachers/$classTeacherId/set-primary',
    );
    return _nullableClassTeacherFromResponse(response);
  }

  @override
  Future<List<SchoolStaffOption>> getSchoolStaff(String customSchoolId) async {
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _send(
      'GET',
      '/api/user-management/schools/$encoded/users?page=0&size=100',
    );
    final decoded = _decode(response);
    final usersJson =
        decoded is Map<String, dynamic> && decoded['users'] != null
        ? decoded['users']
        : decoded;
    return _extractList(usersJson)
        .whereType<Map<String, dynamic>>()
        .map(_staffOptionFromJson)
        .where((staff) => staff.id.isNotEmpty)
        .toList();
  }

  ClassGradeLevel _gradeFromJson(Map<String, dynamic> json) {
    final nested = _map(json['gradeLevel']);
    final id = _integer(json['id']);
    final gradeLevelId = _integer(
      json['gradeLevelId'] ?? nested?['id'],
      fallback: id,
    );
    final name = _string(
      json['gradeName'] ??
          json['gradeLevelName'] ??
          json['name'] ??
          nested?['name'],
    );
    final streams = _extractList(json)
        .whereType<Map<String, dynamic>>()
        .map(
          (stream) => _streamFromJson(
            stream,
            fallbackGradeLevelId: id > 0 ? id : gradeLevelId,
          ),
        )
        .where((stream) => stream.id > 0 && stream.name.isNotEmpty)
        .toList();
    return ClassGradeLevel(
      id: id > 0 ? id : gradeLevelId,
      gradeLevelId: gradeLevelId,
      name: name,
      status: _string(json['status']),
      streams: streams,
    );
  }

  ClassStreamSummary _streamFromJson(
    Map<String, dynamic> json, {
    required int fallbackGradeLevelId,
  }) {
    return ClassStreamSummary(
      id: _integer(json['streamId'] ?? json['id']),
      name: _string(json['streamName'] ?? json['name'] ?? json['section']),
      gradeLevelId: _integer(
        json['gradeLevelId'] ?? json['schoolGradeLevelId'],
        fallback: fallbackGradeLevelId,
      ),
      teacherName: _string(
        json['classTeacherName'] ??
            json['classTeacher'] ??
            json['teacherName'] ??
            json['teacher'],
      ),
      enrolled: _integer(
        json['enrolled'] ??
            json['enrolledCount'] ??
            json['studentCount'] ??
            json['totalStudents'],
      ),
      capacity: _nullableInteger(
        json['capacity'] ?? json['streamCapacity'] ?? json['classCapacity'],
      ),
      active:
          json['isActive'] != false &&
          _string(json['status']).toUpperCase() != 'INACTIVE',
    );
  }

  List<ClassGradeLevel> _gradeLevelsFromAllStreams(List<dynamic> rows) {
    final grouped = <String, List<ClassStreamSummary>>{};
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final gradeName = _string(row['gradeLevelName'], fallback: 'Unassigned');
      final stream = ClassStreamSummary(
        id: _integer(row['streamId'] ?? row['id']),
        name: _string(row['streamName'] ?? row['name'] ?? row['section']),
        gradeLevelId: _integer(
          row['gradeLevelId'] ?? row['schoolGradeLevelId'],
        ),
        teacherName: _string(
          row['classTeacherName'] ??
              row['classTeacher'] ??
              row['teacherName'] ??
              row['teacher'],
        ),
        enrolled: _integer(
          row['enrolled'] ??
              row['enrolledCount'] ??
              row['studentCount'] ??
              row['totalStudents'],
        ),
        capacity: _nullableInteger(
          row['capacity'] ?? row['streamCapacity'] ?? row['classCapacity'],
        ),
        active:
            row['isActive'] != false &&
            _string(row['status']).toUpperCase() != 'INACTIVE',
      );
      if (stream.id > 0 && stream.name.isNotEmpty) {
        grouped
            .putIfAbsent(gradeName, () => <ClassStreamSummary>[])
            .add(stream);
      }
    }

    var syntheticGradeId = 1;
    return grouped.entries.map((entry) {
      final gradeLevelId = entry.value
          .map((stream) => stream.gradeLevelId)
          .firstWhere((id) => id > 0, orElse: () => 0);
      final id = gradeLevelId > 0 ? gradeLevelId : syntheticGradeId++;
      return ClassGradeLevel(
        id: id,
        gradeLevelId: gradeLevelId,
        name: entry.key,
        status: 'ACTIVE',
        streams: entry.value,
      );
    }).toList();
  }

  ClassTeacherAssignment? _nullableClassTeacherFromResponse(
    http.Response response,
  ) {
    final decoded = _decode(response);
    final map = decoded is Map<String, dynamic>
        ? (_map(decoded['data']) ?? decoded)
        : null;
    if (map == null) return null;
    final teacher = _classTeacherFromJson(map);
    return teacher.id > 0 ? teacher : null;
  }

  ClassTeacherAssignment _classTeacherFromJson(Map<String, dynamic> json) {
    final staff =
        _map(json['staff']) ??
        _map(json['user']) ??
        _map(json['teacher']) ??
        _map(json['staffMember']);
    final firstName = _string(json['firstName'] ?? staff?['firstName']);
    final middleName = _string(json['middleName'] ?? staff?['middleName']);
    final lastName = _string(json['lastName'] ?? staff?['lastName']);
    final composedName = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final role = json['role'] ?? staff?['role'];
    return ClassTeacherAssignment(
      id: _integer(
        json['classTeacherId'] ??
            json['assignmentId'] ??
            json['streamClassTeacherId'] ??
            json['id'],
      ),
      staffId: _string(
        json['staffId'] ??
            json['staffUuid'] ??
            json['userId'] ??
            staff?['staffId'] ??
            staff?['userId'] ??
            staff?['id'],
      ),
      name: _string(
        json['staffName'] ??
            json['teacherName'] ??
            json['name'] ??
            json['fullName'] ??
            staff?['fullName'] ??
            staff?['displayName'] ??
            staff?['name'] ??
            staff?['username'] ??
            composedName,
        fallback: 'Unnamed teacher',
      ),
      email: _string(json['staffEmail'] ?? json['email'] ?? staff?['email']),
      role: role is Map<String, dynamic>
          ? _string(role['name'] ?? role['roleName'] ?? role['code'])
          : _string(role),
      isPrimary:
          json['isPrimary'] == true ||
          json['primaryTeacher'] == true ||
          _string(json['primary']).toLowerCase() == 'true',
      isActive:
          json['isActive'] != false &&
          _string(json['status']).toUpperCase() != 'INACTIVE',
    );
  }

  SchoolStaffOption _staffOptionFromJson(Map<String, dynamic> json) {
    final firstName = _string(json['firstName']);
    final middleName = _string(json['middleName']);
    final lastName = _string(json['lastName']);
    final composedName = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final role = json['role'];
    final status = json['accountStatus'] ?? json['status'];
    return SchoolStaffOption(
      id: _string(json['userId'] ?? json['staffId'] ?? json['id']),
      name: _string(
        json['fullName'] ??
            json['name'] ??
            json['displayName'] ??
            json['username'] ??
            composedName,
        fallback: 'Unnamed staff',
      ),
      email: _string(json['email']),
      role: role is Map<String, dynamic>
          ? _string(role['name'] ?? role['roleName'] ?? role['code'])
          : _string(role),
      status: status is Map<String, dynamic>
          ? _string(status['name'] ?? status['status'] ?? status['code'])
          : _string(status),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    if (accessToken?.trim().isEmpty ?? true) {
      throw const ClassesApiException('Please sign in again to continue.');
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
        'PUT' => _client.put(uri, headers: headers, body: encodedBody),
        'DELETE' => _client.delete(uri, headers: headers, body: encodedBody),
        _ => throw ClassesApiException('Unsupported request: $method'),
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClassesApiException(_errorMessage(response));
    }
    return response;
  }

  dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) return const <dynamic>[];
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const ClassesApiException(
        'The classes service returned an invalid response.',
      );
    }
  }

  List<dynamic> _extractList(dynamic value) {
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      for (final key in [
        'content',
        'data',
        'streams',
        'items',
        'classTeachers',
        'teachers',
        'assignments',
        'results',
      ]) {
        final nested = value[key];
        if (nested is List) return nested;
        if (nested is Map<String, dynamic>) {
          final nestedList = _extractList(nested);
          if (nestedList.isNotEmpty) return nestedList;
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
    return 'Classes request failed (${response.statusCode}).';
  }

  static String _withQuery(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query).toString();

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map<String, dynamic> ? value : null;

  static String _string(dynamic value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? fallback : text;
  }

  static int _integer(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }

  static int? _nullableInteger(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}

class ClassesApiException implements Exception {
  const ClassesApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
