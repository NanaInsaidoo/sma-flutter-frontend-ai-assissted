import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/assessments/data/assessment_api_client.dart';
import 'package:school_management_app/src/assessments/presentation/report_print_package_dialog.dart';

void main() {
  testWidgets('opens with safe school-wide household defaults', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = AssessmentApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'totalStudents': 3,
            'readyReports': 2,
            'excludedReports': 1,
            'householdCount': 1,
            'classCount': 1,
            'unassignedHouseholdCount': 0,
            'students': [
              {
                'customStudentId': 'STU-1',
                'studentName': 'Ama Mensah',
                'gradeLevelId': 31,
                'gradeLevelName': 'JHS 3',
                'streamId': 9,
                'className': 'JHS 3 - Section 2',
                'householdId': 4,
                'householdName': 'Mensah Household',
                'ready': true,
                'readinessLabel': 'Ready',
              },
              {
                'customStudentId': 'STU-2',
                'studentName': 'Kofi Mensah',
                'gradeLevelId': 31,
                'gradeLevelName': 'JHS 3',
                'streamId': 9,
                'className': 'JHS 3 - Section 2',
                'householdId': 4,
                'householdName': 'Mensah Household',
                'ready': true,
                'readinessLabel': 'Ready',
              },
              {
                'customStudentId': 'STU-3',
                'studentName': 'Yaw Asante',
                'gradeLevelId': 31,
                'gradeLevelName': 'JHS 3',
                'streamId': 9,
                'className': 'JHS 3 - Section 2',
                'householdId': null,
                'householdName': '',
                'ready': false,
                'readinessLabel': 'Not published',
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showReportPrintPackageDialog(
                context: context,
                api: api,
                customSchoolId: 'SCHOOL-1',
                setup: _setup,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Prepare print package'), findsOneWidget);
    expect(find.text('Entire school'), findsOneWidget);
    expect(
      find.text('Only include reports ready for printing'),
      findsOneWidget,
    );
    expect(find.text('Household / family'), findsOneWidget);
    expect(find.text('One combined school PDF'), findsOneWidget);
    expect(
      find.textContaining('2 ready reports · 1 household'),
      findsOneWidget,
    );
    expect(find.textContaining('1 report excluded'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('household-cover-sheet')),
          )
          .value,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('organize-by-class')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('household-cover-sheet')), findsNothing);
    expect(find.textContaining('2 ready reports · 1 class'), findsOneWidget);
  });
}

const _setup = AssessmentFormSetup(
  streams: [
    AssessmentStreamOption(
      id: 9,
      gradeLevelId: 31,
      gradeName: 'JHS 3',
      streamName: 'Section 2',
      studentCount: 3,
    ),
  ],
  gradeLevels: [
    AssessmentGradeLevelOption(id: 31, name: 'JHS 3', status: 'ACTIVE'),
  ],
  subjects: [],
  academicYearId: 3,
  academicYearName: '2026-2027',
  termId: 7,
  termName: 'First Term',
  termSequence: 1,
  termClosed: false,
);
