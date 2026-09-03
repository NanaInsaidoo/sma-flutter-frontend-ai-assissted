import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/students/data/api_students_repository.dart';
import 'package:school_management_app/src/students/domain/student_models.dart';
import 'package:school_management_app/src/students/presentation/students_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

Future<EnrolledStudent> loadStudent(Map<String, dynamic> placement) {
  final client = MockClient((request) async {
    expect(request.method, 'GET');
    final path = request.url.path;
    Object body;
    if (path.endsWith('/current-term/SCHOOL')) {
      body = {
        'id': 1,
        'academicYear': {'name': '2026-2027'},
        'termType': {'name': 'First Term'},
        'startDate': '2026-08-25',
        'endDate': '2026-12-11',
      };
    } else if (path.endsWith('/students/S-1')) {
      body = {
        'customStudentId': 'S-1',
        'firstName': 'Ama',
        'lastName': 'Test',
        'dateOfBirth': '2020-01-02',
        'status': 'ACTIVE',
        ...placement,
      };
    } else if (path.contains('/attendance/student/')) {
      body = {'attendanceRate': 0, 'recentAttendanceRecords': []};
    } else if (path.endsWith('/fee-account')) {
      body = {'termId': 1, 'customStudentId': 'S-1'};
    } else {
      // Documents, fee adjustments, reversals and requirements are empty.
      body = [];
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return ApiStudentsRepository(
    customSchoolId: 'SCHOOL',
    accessToken: 'test',
    client: client,
  ).getStudent('S-1');
}

void main() {
  final cases = <(String, Map<String, dynamic>, String)>[
    (
      'section name containing the grade is not discarded',
      {'gradeName': 'KG1', 'streamName': 'KG1 - Section 1'},
      'KG1 - Section 1',
    ),
    (
      'section-only name is combined with the class',
      {'gradeName': 'KG1', 'streamName': 'Section 2'},
      'KG1 · Section 2',
    ),
    (
      'empty alias cannot hide the full section name',
      {'gradeName': 'KG1', 'streamAlias': '', 'streamName': 'KG1 - Section 1'},
      'KG1 - Section 1',
    ),
    (
      'nested section is retained',
      {
        'gradeLevel': {'name': 'Basic 2'},
        'stream': {'name': 'Section 3'},
      },
      'Basic 2 · Section 3',
    ),
    (
      'alias is used when no section name exists',
      {'gradeName': 'KG1', 'streamAlias': 'A'},
      'KG1 · A',
    ),
    (
      'missing section is explicitly pending',
      {'gradeName': 'KG1'},
      'KG1 · Section pending',
    ),
  ];
  for (final (description, placement, expected) in cases) {
    test(description, () async {
      expect((await loadStudent(placement)).className, expected);
    });
  }

  testWidgets(
    'profile opened by admissions shows section in header and enrollment',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final student = await loadStudent({
        'gradeName': 'KG1',
        'streamName': 'KG1 - Section 1',
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StudentProfileView(
              student: student,
              term: 'First Term',
              academicYear: '2026-2027',
              onBack: () {},
              onOpenStudent: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('S-1 · KG1 - Section 1'), findsOneWidget);
      expect(find.text('CURRENT CLASS & SECTION'), findsOneWidget);
      expect(find.text('KG1 - Section 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
