import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class TeacherClassAssignment {
  const TeacherClassAssignment({
    required this.gradeLevelId,
    required this.gradeName,
    required this.streamName,
    required this.streamId,
    required this.primary,
    this.studentCount = 0,
    this.capacity,
    this.active = true,
    this.classTeacher = true,
  });

  final int gradeLevelId;
  final String gradeName;
  final String streamName;
  final int streamId;
  final bool primary;
  final int studentCount;
  final int? capacity;
  final bool active;
  final bool classTeacher;

  String get label {
    final stream = streamName.trim();
    final grade = gradeName.trim();
    if (stream.toLowerCase().startsWith(grade.toLowerCase())) return stream;
    return '$grade · $stream';
  }
}

class TeacherSubjectAssignment {
  const TeacherSubjectAssignment({
    required this.gradeLevelId,
    required this.gradeName,
    required this.streamId,
    required this.streamName,
    required this.subjectId,
    required this.subjectName,
    this.studentCount = 0,
    this.capacity,
    this.active = true,
  });

  final int gradeLevelId;
  final String gradeName;
  final int streamId;
  final String streamName;
  final int subjectId;
  final String subjectName;
  final int studentCount;
  final int? capacity;
  final bool active;

  String get label => '$subjectName · $gradeName';
}

class TeacherWorkspaceSnapshot {
  const TeacherWorkspaceSnapshot({
    required this.role,
    required this.assignedStudents,
    required this.classes,
    required this.subjects,
  });

  final String role;
  final int assignedStudents;
  final List<TeacherClassAssignment> classes;
  final List<TeacherSubjectAssignment> subjects;

  bool get isSubjectTeacher =>
      role.toUpperCase() == 'SUBJECT_TEACHER' && classes.isEmpty;

  List<TeacherClassAssignment> get assignedClasses {
    final byStream = <int, TeacherClassAssignment>{
      for (final assignment in classes) assignment.streamId: assignment,
    };
    for (final subject in subjects) {
      byStream.putIfAbsent(
        subject.streamId,
        () => TeacherClassAssignment(
          gradeLevelId: subject.gradeLevelId,
          gradeName: subject.gradeName,
          streamName: subject.streamName,
          streamId: subject.streamId,
          primary: false,
          studentCount: subject.studentCount,
          capacity: subject.capacity,
          active: subject.active,
          classTeacher: false,
        ),
      );
    }
    final result = byStream.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return result;
  }
}

class TeacherWorkspaceApiClient {
  TeacherWorkspaceApiClient({
    required String? accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _accessToken = accessToken,
       _client = client ?? http.Client();

  String? _accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<TeacherWorkspaceSnapshot> get(String schoolId) async {
    var response = await _client.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/schools/${Uri.encodeComponent(schoolId)}/teacher-workspace',
      ),
      headers: _headers,
    );
    if (response.statusCode == 401 && onRefreshAccessToken != null) {
      _accessToken = await onRefreshAccessToken!();
      response = await _client.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/schools/${Uri.encodeComponent(schoolId)}/teacher-workspace',
        ),
        headers: _headers,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Teacher assignments could not be loaded.');
    }
    final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return TeacherWorkspaceSnapshot(
      role: '${json['role'] ?? 'TEACHER'}',
      assignedStudents: _integer(json['assignedStudents']),
      classes: _list(json['classes']).map((raw) {
        final value = Map<String, dynamic>.from(raw as Map);
        return TeacherClassAssignment(
          gradeLevelId: _integer(value['gradeLevelId']),
          gradeName: '${value['gradeName'] ?? ''}',
          streamName: '${value['streamName'] ?? ''}',
          streamId: _integer(value['streamId']),
          primary: value['primary'] == true,
          studentCount: _integer(value['studentCount']),
          capacity: _nullableInteger(value['capacity']),
          active: value['active'] != false,
          classTeacher: value['classTeacher'] != false,
        );
      }).toList(),
      subjects: _list(json['subjects']).map((raw) {
        final value = Map<String, dynamic>.from(raw as Map);
        return TeacherSubjectAssignment(
          gradeLevelId: _integer(value['gradeLevelId']),
          gradeName: '${value['gradeName'] ?? ''}',
          streamId: _integer(value['streamId']),
          streamName: '${value['streamName'] ?? ''}',
          subjectId: _integer(value['subjectId']),
          subjectName: '${value['subjectName'] ?? ''}',
          studentCount: _integer(value['studentCount']),
          capacity: _nullableInteger(value['capacity']),
          active: value['active'] != false,
        );
      }).toList(),
    );
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (_accessToken?.trim().isNotEmpty == true)
      'Authorization': 'Bearer ${_accessToken!.trim()}',
  };
}

List<dynamic> _list(dynamic value) => value is List ? value : const [];

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int? _nullableInteger(dynamic value) {
  if (value == null) return null;
  return value is num ? value.toInt() : int.tryParse('$value');
}
