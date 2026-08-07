import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/assessments/data/assessment_api_client.dart';
import 'package:school_management_app/src/assessments/presentation/term_evaluation_workflow_screen.dart';

void main() {
  const setup = AssessmentFormSetup(
    streams: [],
    gradeLevels: [],
    subjects: [],
    academicYearId: 2,
    academicYearName: '2026-2027',
    termId: 7,
    termName: 'Second Term',
    termSequence: 2,
    termClosed: false,
  );

  Future<void> useWideScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'teacher answers one visible criterion per student and draft auto-saves',
    (tester) async {
      await useWideScreen(tester);
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'PUT') return http.Response('', 204);
          if (request.url.path.endsWith('/assignments/14')) {
            return http.Response(
              jsonEncode({
                'id': 14,
                'staffId': 'T-1',
                'staffName': 'Adwoa Teacher',
                'subjectName': 'Mathematics',
                'assignmentType': 'SUBJECT_TEACHER',
                'status': 'NOT_STARTED',
                'students': [
                  {'id': 'STU-1', 'name': 'Ama Mensah'},
                  {'id': 'STU-2', 'name': 'Kojo Mensah'},
                ],
                'ratings': <String, dynamic>{},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'released': true,
              'totalAssignments': 1,
              'submitted': 0,
              'incomplete': 1,
              'assignments': [
                {
                  'id': 14,
                  'staffId': 'T-1',
                  'staffName': 'Adwoa Teacher',
                  'subjectName': 'Mathematics',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'NOT_STARTED',
                  'studentCount': 2,
                  'completionPercent': 0,
                  'students': [
                    {'id': 'STU-1', 'name': 'Ama Mensah'},
                    {'id': 'STU-2', 'name': 'Kojo Mensah'},
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TermEvaluationWorkflowScreen(
            api: api,
            schoolId: 'SCHOOL-1',
            viewerName: 'Adwoa Teacher',
            viewerRole: 'TEACHER',
            setup: setup,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'How consistently does each student complete assigned homework?',
        ),
        findsOneWidget,
      );
      expect(find.text('Ama Mensah'), findsOneWidget);
      expect(find.text('Kojo Mensah'), findsOneWidget);
      expect(find.textContaining('Apply to'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Good').first);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      final save = requests.lastWhere((request) => request.method == 'PUT');
      expect(save.body, contains('"customStudentId":"STU-1"'));
      expect(save.body, contains('"criterion":"HOMEWORK_HABITS"'));
      expect(save.body, contains('"rating":"Good"'));
      expect(
        find.byKey(const ValueKey('evaluation-save-state')),
        findsOneWidget,
      );

      await tester.tap(find.text('Next criterion'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'How consistently does each student pay attention during lessons?',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('class teacher can finalize the consolidated wording directly', (
    tester,
  ) async {
    await useWideScreen(tester);
    late http.Request finalizeRequest;
    final calculated = {
      'HOMEWORK_HABITS': 'Good',
      'ATTENTIVENESS': 'Good',
      'TEAMWORK': 'Good',
      'CLASS_PARTICIPATION': 'Good',
      'RESPECT_AND_DISCIPLINE': 'Good',
      'NEATNESS': 'Good',
    };
    final api = AssessmentApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/finalize')) {
          finalizeRequest = request;
          return http.Response('{"status":"FINALIZED"}', 200);
        }
        if (request.url.path.endsWith('/review')) {
          return http.Response(
            jsonEncode({
              'calculated': calculated,
              'finalRatings': calculated,
              'comment': '',
              'status': 'PENDING',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'released': true,
            'totalAssignments': 1,
            'submitted': 1,
            'incomplete': 0,
            'assignments': [
              {
                'id': 15,
                'staffId': 'CLASS-1',
                'staffName': 'Adwoa Teacher',
                'subjectName': 'Class-teacher evaluation',
                'assignmentType': 'CLASS_TEACHER',
                'status': 'SUBMITTED',
                'studentCount': 1,
                'completionPercent': 100,
                'students': [
                  {'id': 'STU-1', 'name': 'Ama Mensah'},
                ],
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TermEvaluationWorkflowScreen(
          api: api,
          schoolId: 'SCHOOL-1',
          viewerName: 'Adwoa Teacher',
          viewerRole: 'TEACHER',
          setup: setup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ama Mensah'));
    await tester.pumpAndSettle();

    expect(find.text('Calculated: Good'), findsNWidgets(6));
    expect(find.textContaining('override'), findsNothing);
    await tester.enterText(
      find.byType(TextField).last,
      'Ama participated thoughtfully this term.',
    );
    await tester.tap(find.byKey(const ValueKey('finalize-student-evaluation')));
    await tester.pumpAndSettle();

    expect(finalizeRequest.url.queryParameters['staffId'], 'CLASS-1');
    expect(finalizeRequest.body, contains('"finalRatings"'));
    expect(
      finalizeRequest.body,
      contains('Ama participated thoughtfully this term.'),
    );
    expect(find.text('FINALIZED'), findsOneWidget);
  });
}
