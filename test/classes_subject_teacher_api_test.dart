import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/classes/data/classes_api_client.dart';
import 'package:school_management_app/src/classes/domain/class_models.dart';

void main() {
  test('lists, adds, and removes multiple stream subject teachers', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode([
          {'id': 1, 'streamId': 8, 'subjectId': 3, 'subjectType': 'GES', 'subjectName': 'Mathematics', 'subjectCode': 'B4-MATH', 'staffId': 'T1', 'staffName': 'Ama Mensah', 'active': true},
          {'id': 2, 'streamId': 8, 'subjectId': 3, 'subjectType': 'GES', 'subjectName': 'Mathematics', 'subjectCode': 'B4-MATH', 'staffId': 'T2', 'staffName': 'Kofi Asare', 'active': true},
        ]), 200);
      }
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'id': 3, 'streamId': 8, 'subjectId': 3, 'subjectType': 'GES', 'subjectName': 'Mathematics', 'subjectCode': 'B4-MATH', 'staffId': 'T3', 'staffName': 'Yaa Boateng', 'active': true}), 200);
      }
      return http.Response('', 204);
    });
    final api = ClassesApiClient(accessToken: 'token', client: client);
    final rows = await api.getSubjectTeacherAssignments(customSchoolId: 'SCH', streamId: 8);
    expect(rows.map((r) => r.staffName), ['Ama Mensah', 'Kofi Asare']);
    await api.addSubjectTeacherAssignment(customSchoolId: 'SCH', streamId: 8, gradeLevelId: 4,
      subject: const ClassSubject(id: 3, name: 'Mathematics', code: 'B4-MATH', custom: false, active: true, examinable: true), staffId: 'T3');
    await api.removeSubjectTeacherAssignment(customSchoolId: 'SCH', streamId: 8, assignmentId: 1, reason: 'Timetable changed');
    expect(requests.map((r) => r.method), ['GET', 'POST', 'DELETE']);
    expect(requests[1].body, contains('"subjectType":"GES"'));
  });
}
