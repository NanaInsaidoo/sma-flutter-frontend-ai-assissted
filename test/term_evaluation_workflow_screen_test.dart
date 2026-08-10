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

  testWidgets('class teacher confirms calculated wording and adds comment', (
    tester,
  ) async {
    await useWideScreen(tester);
    http.Request? finalizeRequest;
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
            request.url.path.endsWith('/comment-suggestion')) {
          final alternate = request.url.queryParameters['variant'] == '1';
          return http.Response(
            jsonEncode({
              'available': true,
              'suggestion': alternate
                  ? 'Ama has made steady progress. Continue the encouraging effort next term.'
                  : 'Ama has worked well this term. Her strengths include careful attentiveness. Keep up the positive effort next term.',
              'variant': request.url.queryParameters['variant'],
            }),
            200,
          );
        }
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
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.textContaining('override'), findsNothing);
    expect(find.text('Suggested class-teacher comment'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('use-evaluation-suggestion')));
    await tester.pump();
    TextField commentField() => tester.widget<TextField>(
      find.byKey(const ValueKey('evaluation-final-comment')),
    );
    expect(commentField().controller!.text, contains('Ama has worked well'));

    await tester.tap(
      find.byKey(const ValueKey('try-another-evaluation-suggestion')),
    );
    await tester.pumpAndSettle();
    expect(commentField().controller!.text, isEmpty);
    expect(find.textContaining('Ama has made steady progress'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('use-evaluation-suggestion')));
    await tester.pump();
    expect(
      commentField().controller!.text,
      contains('Ama has made steady progress'),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .byKey(const ValueKey('preview-student-evaluation'))
          .hitTestable()
          .last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Preview report-card comment'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('evaluation-comment-preview')),
      findsOneWidget,
    );
    expect(finalizeRequest, isNull);
    await tester.tap(find.byKey(const ValueKey('send-student-evaluation')));
    await tester.pumpAndSettle();

    final sentRequest = finalizeRequest;
    expect(sentRequest, isNotNull);
    expect(sentRequest!.url.queryParameters['staffId'], 'CLASS-1');
    expect(sentRequest.body, contains('"finalRatings"'));
    expect(sentRequest.body, contains('Ama has made steady progress.'));
    expect(commentField().readOnly, isTrue);
    expect(
      find.textContaining('combined wording cannot be changed'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('preview-student-evaluation')),
      findsNothing,
    );
  });

  testWidgets('headmaster alone can correct finalized wording with a reason', (
    tester,
  ) async {
    await useWideScreen(tester);
    http.Request? adjustmentRequest;
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
            request.url.path.endsWith('/final-wordings')) {
          adjustmentRequest = request;
          return http.Response('{"status":"FINALIZED"}', 200);
        }
        if (request.url.path.endsWith('/review')) {
          return http.Response(
            jsonEncode({
              'calculated': calculated,
              'finalRatings': calculated,
              'comment': 'Ama has worked well this term.',
              'status': 'FINALIZED',
              'audit': [
                {
                  'action': 'HEADMASTER_FINAL_WORDING_CHANGED',
                  'actor': 'Nana Headmaster',
                  'reason':
                      'HOMEWORK_HABITS: Satisfactory -> Good; reason: Verified against the signed class record',
                  'createdAt': [2026, 8, 7, 12, 30, 0],
                },
              ],
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
          viewerName: 'Nana Headmaster',
          viewerRole: 'HEADMASTER',
          setup: setup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review results'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ama Mensah'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Only the headmaster can correct the final report-card wording.',
      ),
      findsOneWidget,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(6));
    final comment = tester.widget<TextField>(
      find.byKey(const ValueKey('evaluation-final-comment')),
    );
    expect(comment.readOnly, isTrue);
    expect(find.text('Wording change history'), findsOneWidget);
    expect(find.text('Homework habits · Satisfactory -> Good'), findsOneWidget);
    expect(find.textContaining('Nana Headmaster'), findsOneWidget);
    expect(find.textContaining('07/08/2026 · 12:30'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('headmaster-wording-HOMEWORK_HABITS')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excellent').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('save-headmaster-wordings')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm final wording changes'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('headmaster-wording-reason')),
      'Verified against the signed class record',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-headmaster-wordings')));
    await tester.pumpAndSettle();

    expect(adjustmentRequest, isNotNull);
    expect(adjustmentRequest!.body, contains('"HOMEWORK_HABITS":"Excellent"'));
    expect(
      adjustmentRequest!.body,
      contains('Verified against the signed class record'),
    );
  });

  testWidgets('ordinary administrator cannot open final wording correction', (
    tester,
  ) async {
    await useWideScreen(tester);
    final api = AssessmentApiClient(
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
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
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TermEvaluationWorkflowScreen(
          api: api,
          schoolId: 'SCHOOL-1',
          viewerName: 'School Administrator',
          viewerRole: 'ADMINISTRATOR',
          setup: setup,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review results'), findsNothing);
    expect(find.text('Reopen'), findsOneWidget);
  });

  testWidgets(
    'headmaster can inspect report blockers and remind the responsible teacher',
    (tester) async {
      await useWideScreen(tester);
      http.Request? reminderRequest;
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/remind')) {
            reminderRequest = request;
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode({
              'released': true,
              'totalAssignments': 1,
              'submitted': 0,
              'incomplete': 1,
              'assignments': [
                {
                  'id': 24,
                  'staffId': 'T-2',
                  'staffName': 'Kojo Teacher',
                  'subjectName': 'Mathematics',
                  'streamName': 'JHS 1 Gold',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'IN_PROGRESS',
                  'studentCount': 1,
                  'completionPercent': 50,
                  'students': [
                    {'id': 'STU-9', 'name': 'Esi Boateng'},
                  ],
                },
              ],
              'readiness': {
                'released': true,
                'readyForReportCards': false,
                'totalStudents': 1,
                'readyStudents': 0,
                'blockedStudents': 1,
                'incompleteAssignments': 1,
                'students': [
                  {
                    'customStudentId': 'STU-9',
                    'studentName': 'Esi Boateng',
                    'streamName': 'JHS 1 Gold',
                    'reviewStatus': 'PENDING',
                    'ready': false,
                    'blockers': [
                      {
                        'type': 'MISSING_CONTRIBUTORS',
                        'title': 'Homework habits needs one more teacher',
                        'message':
                            'Kojo Teacher (Mathematics) has not submitted an observed rating.',
                      },
                    ],
                    'assignments': [
                      {
                        'assignmentId': 24,
                        'staffName': 'Kojo Teacher',
                        'subjectName': 'Mathematics',
                        'assignmentType': 'SUBJECT_TEACHER',
                        'status': 'IN_PROGRESS',
                        'completionPercent': 50,
                        'missingCriteria': ['Homework habits'],
                      },
                    ],
                  },
                ],
              },
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
            viewerName: 'Nana Headmaster',
            viewerRole: 'HEADMASTER',
            setup: setup,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report readiness'));
      await tester.pumpAndSettle();

      expect(
        find.text('1 student blocked from report generation'),
        findsOneWidget,
      );
      expect(find.text('Esi Boateng'), findsOneWidget);
      expect(find.textContaining('JHS 1 Gold'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('evaluation-readiness-STU-9')),
      );
      await tester.pumpAndSettle();
      expect(find.text('What is blocking this report'), findsOneWidget);
      expect(
        find.text('Homework habits needs one more teacher'),
        findsOneWidget,
      );
      expect(find.text('Teacher contributions'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Remind'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Remind'));
      await tester.pumpAndSettle();

      expect(reminderRequest, isNotNull);
      expect(reminderRequest!.url.path, endsWith('/assignments/24/remind'));
    },
  );

  testWidgets(
    'focused progress shows only assignments for the selected stream',
    (tester) async {
      await useWideScreen(tester);
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'released': true,
              'totalAssignments': 2,
              'submitted': 1,
              'incomplete': 1,
              'assignments': [
                {
                  'id': 31,
                  'streamId': 10,
                  'staffId': 'T-10',
                  'staffName': 'Kojo Pending',
                  'subjectName': 'Mathematics',
                  'streamName': 'Stream A',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'IN_PROGRESS',
                  'studentCount': 5,
                  'completionPercent': 40,
                  'students': const [],
                },
                {
                  'id': 32,
                  'streamId': 11,
                  'staffId': 'T-11',
                  'staffName': 'Esi Submitted',
                  'subjectName': 'English Language',
                  'streamName': 'Stream B',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'SUBMITTED',
                  'studentCount': 5,
                  'completionPercent': 100,
                  'students': const [],
                },
              ],
            }),
            200,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TermEvaluationWorkflowScreen(
            api: api,
            schoolId: 'SCHOOL-1',
            viewerName: 'Nana Headmaster',
            viewerRole: 'HEADMASTER',
            setup: setup,
            initialStreamId: 10,
            initialStreamName: 'Grade 1 - Grade 1 - Stream A',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Evaluation progress — Grade 1 - Stream A'),
        findsOneWidget,
      );
      expect(find.text('Teachers and assigned evaluations'), findsOneWidget);
      expect(find.textContaining('Kojo Pending'), findsOneWidget);
      expect(find.textContaining('Esi Submitted'), findsNothing);
      expect(find.text('Remind'), findsOneWidget);
      expect(find.text('Report readiness'), findsNothing);
    },
  );

  testWidgets(
    'management progress summarizes evaluation work by staff and class',
    (tester) async {
      await useWideScreen(tester);
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'released': true,
              'totalAssignments': 3,
              'submitted': 1,
              'incomplete': 2,
              'assignments': [
                {
                  'id': 41,
                  'streamId': 10,
                  'staffId': 'T-1',
                  'staffName': 'Ama Teacher',
                  'subjectName': 'Mathematics',
                  'streamName': 'Grade 1 - Stream A',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'IN_PROGRESS',
                  'studentCount': 5,
                  'completedStudentCount': 2,
                  'remainingStudentCount': 3,
                  'ratedCount': 24,
                  'requiredCount': 30,
                  'completionPercent': 80,
                },
                {
                  'id': 42,
                  'streamId': 11,
                  'staffId': 'T-1',
                  'staffName': 'Ama Teacher',
                  'subjectName': 'English Language',
                  'streamName': 'Grade 1 - Stream B',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'SUBMITTED',
                  'studentCount': 4,
                  'completedStudentCount': 4,
                  'remainingStudentCount': 0,
                  'ratedCount': 24,
                  'requiredCount': 24,
                  'completionPercent': 100,
                },
                {
                  'id': 43,
                  'streamId': 10,
                  'staffId': 'T-2',
                  'staffName': 'Kojo Teacher',
                  'subjectName': 'Class-teacher evaluation',
                  'streamName': 'Grade 1 - Stream A',
                  'assignmentType': 'CLASS_TEACHER',
                  'status': 'IN_PROGRESS',
                  'studentCount': 5,
                  'completedStudentCount': 1,
                  'remainingStudentCount': 4,
                  'ratedCount': 12,
                  'requiredCount': 30,
                  'completionPercent': 40,
                },
              ],
              'insights': {
                'totalStudents': 5,
                'studentsAnalyzed': 4,
                'studentsWithCompleteObservations': 3,
                'studentsMissingObservations': 2,
                'observationCompletenessPercent': 80,
                'notObservedPercent': 10,
                'overallDistribution': {
                  'Excellent': 6,
                  'Good': 10,
                  'Satisfactory': 5,
                  'Needs improvement': 1,
                },
                'criteria': [
                  {
                    'criterion': 'HOMEWORK_HABITS',
                    'label': 'Homework habits',
                    'observedStudents': 4,
                    'missingStudents': 1,
                    'needsSupportStudents': 1,
                    'distribution': {
                      'Excellent': 1,
                      'Good': 2,
                      'Satisfactory': 0,
                      'Needs improvement': 1,
                    },
                  },
                ],
              },
            }),
            200,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TermEvaluationWorkflowScreen(
            api: api,
            schoolId: 'SCHOOL-1',
            viewerName: 'Nana Headmaster',
            viewerRole: 'HEADMASTER',
            setup: setup,
            managementProgressOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student evaluation progress'), findsNWidgets(2));
      expect(find.text('71%'), findsOneWidget);
      expect(find.text('29%'), findsOneWidget);
      expect(find.byKey(const ValueKey('evaluation-by-staff')), findsOneWidget);
      expect(find.text('Ama Teacher'), findsOneWidget);
      expect(find.text('Kojo Teacher'), findsOneWidget);
      expect(find.text('89% done · 11% remaining'), findsOneWidget);

      await tester.tap(find.text('Evaluation by class'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('evaluation-by-class')), findsOneWidget);
      expect(find.text('Grade 1 - Stream A'), findsOneWidget);
      expect(find.text('Grade 1 - Stream B'), findsOneWidget);
      expect(find.text('60% done · 40% remaining'), findsOneWidget);
      expect(find.text('Remind'), findsNothing);

      await tester.tap(find.text('Evaluation insights'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('evaluation-insights')), findsOneWidget);
      expect(
        find.textContaining('Preliminary analysis: 7 of 14 assigned evaluations'),
        findsOneWidget,
      );
      expect(find.text('Students analyzed'), findsOneWidget);
      expect(find.text('4 of 5'), findsOneWidget);
      expect(find.text('Observed criteria in submitted work'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Homework habits'), findsOneWidget);
      expect(find.text('NEEDS SUPPORT'), findsOneWidget);
      expect(
        find.textContaining('Individual teacher ratings are not shown'),
        findsOneWidget,
      );
    },
  );

  testWidgets('headmaster locks and releases the evaluation entry window', (
    tester,
  ) async {
    await useWideScreen(tester);
    var locked = false;
    http.Request? lockRequest;
    final api = AssessmentApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/term-evaluations/lock')) {
          lockRequest = request;
          locked = true;
          return http.Response('{"status":"LOCKED"}', 200);
        }
        return http.Response(
          jsonEncode({
            'released': true,
            'cycleStatus': locked ? 'LOCKED' : 'RELEASED',
            'teacherEntryOpen': !locked,
            'locked': locked,
            'totalAssignments': 0,
            'submitted': 0,
            'incomplete': 0,
            'assignments': const [],
            'insights': {'totalStudents': 0, 'criteria': const []},
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
          viewerName: 'Nana Headmaster',
          viewerRole: 'HEADMASTER',
          setup: setup,
          managementProgressOnly: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Released'), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-evaluations')), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lock-evaluations')));
    await tester.pumpAndSettle();
    expect(find.text('Lock evaluations?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-lock-evaluations')));
    await tester.pumpAndSettle();

    expect(lockRequest, isNotNull);
    expect(lockRequest!.url.queryParameters['termId'], '7');
    expect(find.text('Locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('release-evaluations')), findsOneWidget);
  });
}
