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

  Future<void> openManagerWorkspace(
    WidgetTester tester,
    String workspace,
  ) async {
    await tester.tap(
      find.byKey(const ValueKey('evaluation-workspace-menu')).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(workspace).last);
    await tester.pumpAndSettle();
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
      await tester.tap(find.text('Start ratings'));
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

  testWidgets(
    'teacher can save a submitted update directly and clear all responses',
    (tester) async {
      await useWideScreen(tester);
      final requests = <http.Request>[];
      final ratings = {
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
          requests.add(request);
          if (request.method == 'PUT' || request.method == 'DELETE') {
            return http.Response('', 204);
          }
          if (request.url.path.endsWith('/assignments/14')) {
            return http.Response(
              jsonEncode({
                'id': 14,
                'staffId': 'T-1',
                'staffName': 'Adwoa Teacher',
                'subjectName': 'Mathematics',
                'assignmentType': 'SUBJECT_TEACHER',
                'status': 'SUBMITTED',
                'students': [
                  {'id': 'STU-1', 'name': 'Ama Mensah'},
                ],
                'ratings': {'STU-1': ratings},
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'released': true,
              'teacherEntryOpen': true,
              'totalAssignments': 1,
              'submitted': 1,
              'incomplete': 0,
              'assignments': [
                {
                  'id': 14,
                  'staffId': 'T-1',
                  'staffName': 'Adwoa Teacher',
                  'subjectName': 'Mathematics',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'SUBMITTED',
                  'studentCount': 1,
                  'completionPercent': 100,
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
      await tester.tap(find.text('Edit ratings'));
      await tester.pumpAndSettle();

      expect(find.text('Save update'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Excellent'));
      await tester.tap(find.text('Save update'));
      await tester.pumpAndSettle();

      expect(requests.any((request) => request.method == 'PUT'), isTrue);
      expect(find.text('Edit ratings'), findsOneWidget);

      await tester.tap(find.text('Edit ratings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Evaluation actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear responses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear responses'));
      await tester.pumpAndSettle();

      expect(requests.any((request) => request.method == 'DELETE'), isTrue);
      expect(find.text('All responses cleared'), findsOneWidget);
    },
  );

  testWidgets('class teacher confirms calculated wording and adds comment', (
    tester,
  ) async {
    await useWideScreen(tester);
    http.Request? saveCommentRequest;
    http.Request? submitClassRequest;
    var reviewStatus = 'PENDING';
    var savedComment = '';
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
        if (request.method == 'PUT' && request.url.path.endsWith('/comment')) {
          saveCommentRequest = request;
          savedComment =
              (jsonDecode(request.body) as Map<String, dynamic>)['comment']
                  ?.toString() ??
              '';
          reviewStatus = 'COMMENTS_IN_PROGRESS';
          return http.Response('{"status":"COMMENTS_IN_PROGRESS"}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/submit-comments')) {
          submitClassRequest = request;
          reviewStatus = 'SUBMITTED';
          return http.Response(
            '{"status":"READY_FOR_LEADERSHIP","studentsSubmitted":1}',
            200,
          );
        }
        if (request.url.path.endsWith('/review')) {
          return http.Response(
            jsonEncode({
              'calculated': calculated,
              'finalRatings': calculated,
              'comment': savedComment,
              'status': reviewStatus,
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
    await tester.tap(find.byKey(const ValueKey('teacher-stage-comments')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More actions'), findsNothing);
    await tester.tap(find.text('Add comments'));
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
      find.byKey(const ValueKey('save-student-comment')).hitTestable().last,
    );
    await tester.pumpAndSettle();

    expect(saveCommentRequest, isNotNull);
    expect(saveCommentRequest!.body, contains('Ama has made steady progress.'));
    expect(find.text('Student comments complete'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('submit-class-evaluation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('submit-class-evaluation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for approval').hitTestable());
    await tester.pumpAndSettle();
    expect(submitClassRequest, isNotNull);
    expect(find.text('Awaiting approval'), findsWidgets);
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
          return http.Response('{"status":"APPROVED"}', 200);
        }
        if (request.url.path.endsWith('/review')) {
          return http.Response(
            jsonEncode({
              'calculated': calculated,
              'finalRatings': calculated,
              'comment': 'Ama has worked well this term.',
              'status': 'APPROVED',
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
    await openManagerWorkspace(tester, 'Teacher progress');
    await tester.tap(find.text('Review results'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ama Mensah'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('approved and ready for report generation'),
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

  testWidgets(
    'administrator can review but cannot change final rating wording',
    (tester) async {
      await useWideScreen(tester);
      var reviewStatus = 'SUBMITTED';
      http.Request? startReviewRequest;
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
              request.url.path.endsWith('/leadership-review/start')) {
            startReviewRequest = request;
            reviewStatus = 'UNDER_REVIEW';
            return http.Response('{"status":"UNDER_REVIEW"}', 200);
          }
          if (request.url.path.endsWith('/review')) {
            return http.Response(
              jsonEncode({
                'calculated': calculated,
                'finalRatings': calculated,
                'comment': 'Ama has worked well this term.',
                'status': reviewStatus,
                'leadershipReviewer': reviewStatus == 'UNDER_REVIEW'
                    ? 'School Administrator'
                    : null,
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
            viewerName: 'School Administrator',
            viewerRole: 'ADMINISTRATOR',
            setup: setup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await openManagerWorkspace(tester, 'Teacher progress');
      expect(find.text('Review results'), findsOneWidget);
      expect(find.text('Reopen'), findsNothing);

      await tester.tap(find.text('Review results'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ama Mensah'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Start review'), findsOneWidget);
      final comment = tester.widget<TextField>(
        find.byKey(const ValueKey('evaluation-final-comment')),
      );
      expect(comment.readOnly, isTrue);

      await tester.drag(find.byType(ListView).last, const Offset(0, -1200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start review').hitTestable());
      await tester.pumpAndSettle();

      expect(startReviewRequest, isNotNull);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    },
  );

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
      await openManagerWorkspace(tester, 'Report readiness');

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

  testWidgets('leadership can select all eligible students and approve them', (
    tester,
  ) async {
    await useWideScreen(tester);
    http.Request? batchApprovalRequest;
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
            request.url.path.endsWith('/approve-batch')) {
          batchApprovalRequest = request;
          return http.Response(
            '{"approved":2,"skipped":[],"requested":2}',
            200,
          );
        }
        if (request.url.path.endsWith('/review')) {
          return http.Response(
            jsonEncode({
              'calculated': calculated,
              'finalRatings': calculated,
              'comment': 'Ready for approval.',
              'status': 'SUBMITTED',
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
                'streamId': 8,
                'streamName': 'JHS 1 - Section 3',
                'subjectName': 'Class-teacher evaluation',
                'assignmentType': 'CLASS_TEACHER',
                'status': 'SUBMITTED',
                'studentCount': 2,
                'completionPercent': 100,
                'students': [
                  {'id': 'STU-1', 'name': 'Ama Mensah'},
                  {'id': 'STU-2', 'name': 'Kojo Boateng'},
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
          viewerName: 'School Administrator',
          viewerRole: 'ADMINISTRATOR',
          setup: setup,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openManagerWorkspace(tester, 'Teacher progress');
    await tester.tap(find.text('Review results'));
    await tester.pumpAndSettle();

    expect(find.text('Select all eligible (2)'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('approve-selected-evaluations')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve selected').last);
    await tester.pumpAndSettle();

    expect(batchApprovalRequest, isNotNull);
    expect(batchApprovalRequest!.body, contains('STU-1'));
    expect(batchApprovalRequest!.body, contains('STU-2'));
  });

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
        find.text('Ratings & comments progress — Grade 1 - Stream A'),
        findsOneWidget,
      );
      expect(
        find.text('Teacher ratings & comment responsibilities'),
        findsOneWidget,
      );
      expect(find.textContaining('Kojo Pending'), findsOneWidget);
      expect(find.textContaining('Esi Submitted'), findsNothing);
      expect(find.text('Remind'), findsOneWidget);
      expect(find.text('Report readiness'), findsNothing);
    },
  );

  testWidgets(
    "combines a teacher's subjects into one responsibility for the same class",
    (tester) async {
      await useWideScreen(tester);
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'released': true,
              'totalAssignments': 2,
              'submitted': 0,
              'incomplete': 2,
              'assignments': [
                {
                  'id': 51,
                  'streamId': 10,
                  'staffId': 'T-1',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'English Language',
                  'streamName': 'JHS 1 - Section 3',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'NOT_STARTED',
                  'studentCount': 2,
                  'completionPercent': 0,
                },
                {
                  'id': 52,
                  'streamId': 10,
                  'staffId': 'T-1',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'Mathematics',
                  'streamName': 'JHS 1 - Section 3',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'NOT_STARTED',
                  'studentCount': 2,
                  'completionPercent': 0,
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
            initialStreamName: 'JHS 1 - Section 3',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sena Owusu'), findsOneWidget);
      expect(find.textContaining('Subject teacher'), findsOneWidget);
      expect(find.text('English Language, Mathematics'), findsOneWidget);
      expect(find.textContaining('TEACHER RESPONSIBILITIES'), findsOneWidget);
    },
  );

  testWidgets(
    'teacher dashboard opens all responsibilities and filters them by class',
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
                  'id': 61,
                  'streamId': 10,
                  'staffId': 'T-1',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'English Language',
                  'streamName': 'JHS 1 - Section 3',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'NOT_STARTED',
                  'studentCount': 2,
                  'completionPercent': 0,
                },
                {
                  'id': 62,
                  'streamId': 10,
                  'staffId': 'T-1',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'Mathematics',
                  'streamName': 'JHS 1 - Section 3',
                  'assignmentType': 'SUBJECT_TEACHER',
                  'status': 'NOT_STARTED',
                  'studentCount': 2,
                  'completionPercent': 0,
                },
                {
                  'id': 63,
                  'streamId': 11,
                  'staffId': 'T-1',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'Class-teacher evaluation',
                  'streamName': 'JHS 1 - Section 2',
                  'assignmentType': 'CLASS_TEACHER',
                  'status': 'SUBMITTED',
                  'studentCount': 3,
                  'completionPercent': 100,
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
            viewerName: 'Sena Owusu',
            viewerRole: 'CLASS_TEACHER',
            setup: setup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My evaluation responsibilities'), findsOneWidget);
      expect(find.text('Responsibilities by class'), findsOneWidget);
      expect(find.text('RATINGS COMPLETE'), findsOneWidget);
      expect(find.text('STUDENT COMMENTS'), findsOneWidget);
      expect(find.text('SUBMITTED FOR APPROVAL'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('teacher-responsibilities-table')),
        findsOneWidget,
      );
      expect(find.text('CLASS'), findsOneWidget);
      expect(find.text('RATINGS'), findsOneWidget);
      expect(find.text('ROLE'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('ACTION'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('teacher-evaluation-stage-tabs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('teacher-stage-comments')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('teacher-responsibility-class-filter')),
        findsOneWidget,
      );
      expect(find.text('English Language, Mathematics'), findsNothing);
      expect(find.textContaining('2 subjects'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('responsibility-class-JHS 1 - Section 2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('responsibility-class-JHS 1 - Section 3')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('teacher-stage-comments')));
      await tester.pumpAndSettle();

      expect(find.text('COMMENTS'), findsOneWidget);
      expect(find.text('APPROVAL STATUS'), findsOneWidget);
      expect(find.text('0 of 3 complete'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('teacher-stage-ratings')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('teacher-responsibility-class-filter')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownMenuItem<String>, 'JHS 1 - Section 2'),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('responsibility-class-JHS 1 - Section 2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('responsibility-class-JHS 1 - Section 3')),
        findsNothing,
      );
      expect(find.text('English Language, Mathematics'), findsNothing);
    },
  );

  testWidgets('approved class responsibility has one view-only action', (
    tester,
  ) async {
    await useWideScreen(tester);
    final api = AssessmentApiClient(
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'released': true,
            'teacherEntryOpen': true,
            'assignments': [
              {
                'id': 71,
                'streamId': 12,
                'staffId': 'T-1',
                'staffName': 'Sena Owusu',
                'subjectName': 'Class-teacher evaluation',
                'streamName': 'Creche - Section 1',
                'assignmentType': 'CLASS_TEACHER',
                'status': 'SUBMITTED',
                'workflowStatus': 'APPROVED',
                'studentCount': 3,
                'commentsCompleted': 3,
                'completionPercent': 100,
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
          viewerName: 'Sena Owusu',
          viewerRole: 'CLASS_TEACHER',
          setup: setup,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('teacher-stage-comments')));
    await tester.pumpAndSettle();

    expect(find.text('View comments'), findsOneWidget);
    expect(find.text('Continue comments'), findsNothing);
    expect(find.byTooltip('More actions'), findsNothing);
    expect(find.text('Edit ratings'), findsNothing);
  });

  testWidgets(
    'completed class comments can be submitted from the responsibility row',
    (tester) async {
      await useWideScreen(tester);
      http.Request? submission;
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/submit-comments')) {
            submission = request;
            return http.Response(
              '{"status":"READY_FOR_LEADERSHIP","studentsSubmitted":2}',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'released': true,
              'teacherEntryOpen': true,
              'assignments': [
                {
                  'id': 72,
                  'streamId': 13,
                  'staffId': 'T-1',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'Class-teacher evaluation',
                  'streamName': 'KG1 - Section 1',
                  'assignmentType': 'CLASS_TEACHER',
                  'status': 'SUBMITTED',
                  'workflowStatus': 'COMMENTS_COMPLETE',
                  'studentCount': 2,
                  'commentsCompleted': 2,
                  'completionPercent': 100,
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
            viewerName: 'Sena Owusu',
            viewerRole: 'CLASS_TEACHER',
            setup: setup,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('teacher-stage-comments')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('submit-responsibility-72')));
      await tester.pumpAndSettle();
      expect(
        find.text('Submit class evaluation for approval?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Submit for approval').last);
      await tester.pumpAndSettle();

      expect(submission, isNotNull);
      expect(
        find.text('Class evaluation submitted for approval.'),
        findsOneWidget,
      );
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
                  'commentsCompleted': 5,
                  'commentsSubmitted': 0,
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

      expect(find.text('Evaluations & comments'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('evaluation-approval-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('evaluation-workspace-menu')),
        findsOneWidget,
      );
      expect(find.text('Leadership approval'), findsOneWidget);
      expect(find.byKey(const ValueKey('evaluation-by-class')), findsNothing);

      await openManagerWorkspace(tester, 'Overview');

      expect(find.byKey(const ValueKey('evaluation-by-class')), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.text('Ratings & comments progress by class'), findsOneWidget);
      expect(find.text('Grade 1 - Stream A'), findsOneWidget);
      expect(find.text('Grade 1 - Stream B'), findsOneWidget);
      expect(find.text('3 of 10 complete'), findsOneWidget);
      expect(find.text('5 of 5 complete'), findsOneWidget);
      expect(find.text('Pending teacher submission'), findsOneWidget);
      expect(find.text('Class teacher not assigned'), findsOneWidget);
      expect(find.text('Setup required'), findsOneWidget);
      expect(find.text('Ready to submit'), findsNothing);
      expect(find.text('Remind'), findsNothing);

      final progressTable = find.byKey(
        const ValueKey('evaluation-progress-table'),
      );
      var table = tester.widget<DataTable>(progressTable);
      expect(table.sortColumnIndex, 1);
      expect(table.sortAscending, isFalse);

      await tester.tap(
        find.descendant(of: progressTable, matching: find.text('COMMENTS')),
      );
      await tester.pumpAndSettle();

      table = tester.widget<DataTable>(progressTable);
      expect(table.sortColumnIndex, 2);
      expect(table.sortAscending, isTrue);

      await tester.tap(find.text('By staff'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('evaluation-by-staff')), findsOneWidget);
      expect(find.text('Ratings & comments progress by staff'), findsOneWidget);
      expect(find.text('Ama Teacher'), findsOneWidget);
      expect(find.text('Kojo Teacher'), findsOneWidget);
      expect(find.text('6 of 9 complete'), findsOneWidget);
      expect(find.text('Not required'), findsWidgets);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('evaluation-insights')), findsOneWidget);
      expect(
        find.textContaining(
          'Preliminary analysis: 7 of 14 assigned evaluations',
        ),
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

  testWidgets(
    'class approval register previews comments and approves selected students',
    (tester) async {
      await useWideScreen(tester);
      http.Request? batchApprovalRequest;
      var batchApproved = false;
      final ratings = {
        'HOMEWORK_HABITS': 'Excellent',
        'ATTENTIVENESS': 'Good',
        'TEAMWORK': 'Good',
        'CLASS_PARTICIPATION': 'Satisfactory',
        'RESPECT_AND_DISCIPLINE': 'Satisfactory',
        'NEATNESS': 'Needs improvement',
      };
      final students = [
        {'id': 'STU-1', 'name': 'Kojo Boateng'},
        {'id': 'STU-2', 'name': 'Selina Opoku'},
        {'id': 'STU-3', 'name': 'Sena Owusu'},
        {'id': 'STU-4', 'name': 'Ama Mensah'},
      ];
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/approve-batch')) {
            batchApprovalRequest = request;
            batchApproved = true;
            return http.Response(
              '{"approved":2,"skipped":[],"requested":2}',
              200,
            );
          }
          if (request.url.path.endsWith('/review')) {
            final studentId = request
                .url
                .pathSegments[request.url.pathSegments.indexOf('students') + 1];
            final status =
                batchApproved && const {'STU-2', 'STU-3'}.contains(studentId)
                ? 'APPROVED'
                : switch (studentId) {
                    'STU-1' => 'APPROVED',
                    'STU-3' => 'UNDER_REVIEW',
                    'STU-4' => 'CHANGES_REQUESTED',
                    _ => 'SUBMITTED',
                  };
            return http.Response(
              jsonEncode({
                'calculated': ratings,
                'finalRatings': ratings,
                'comment': studentId == 'STU-2'
                    ? 'Selina is attentive, curious and increasingly confident when participating in group activities. She listens carefully to instructions and contributes thoughtful ideas during lessons.'
                    : 'A clear class-teacher comment.',
                'status': status,
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
                  'id': 81,
                  'streamId': 18,
                  'staffId': 'T-CLASS',
                  'staffName': 'Sena Owusu',
                  'subjectName': 'Class-teacher evaluation',
                  'streamName': 'Creche - Section 1',
                  'assignmentType': 'CLASS_TEACHER',
                  'status': 'SUBMITTED',
                  'studentCount': 4,
                  'completedStudentCount': 4,
                  'remainingStudentCount': 0,
                  'ratedCount': 24,
                  'requiredCount': 24,
                  'completionPercent': 100,
                  'commentsCompleted': 4,
                  'commentsSubmitted': 3,
                  'commentsApproved': 1,
                  'commentsRejected': 1,
                  'workflowStatus': 'REJECTED',
                  'students': students,
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
            managementProgressOnly: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rejected'), findsOneWidget);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(find.text('Class ratings & comments approval'), findsOneWidget);
      expect(find.text('Awaiting 2'), findsOneWidget);
      expect(find.text('Approved 1'), findsOneWidget);
      expect(find.text('Rejected 1'), findsOneWidget);
      expect(find.text('Expand to read the full comment'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('select-class-result-STU-1')),
            )
            .onChanged,
        isNull,
      );

      await tester.tap(
        find.byKey(const ValueKey('select-all-awaiting-class-results')),
      );
      await tester.pump();
      expect(find.text('Approve selected (2)'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('approve-selected-class-results')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').hitTestable().last);
      await tester.pumpAndSettle();

      expect(batchApprovalRequest, isNotNull);
      expect(batchApprovalRequest!.body, contains('STU-2'));
      expect(batchApprovalRequest!.body, contains('STU-3'));
      expect(batchApprovalRequest!.body, isNot(contains('STU-1')));
      expect(find.text('Awaiting 0'), findsOneWidget);
      expect(find.text('Approved 3'), findsOneWidget);
    },
  );

  testWidgets('headmaster releases evaluations once without a global lock', (
    tester,
  ) async {
    await useWideScreen(tester);
    var released = false;
    http.Request? releaseRequest;
    final api = AssessmentApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/term-evaluations/release')) {
          releaseRequest = request;
          released = true;
          return http.Response('{"status":"RELEASED"}', 200);
        }
        return http.Response(
          jsonEncode({
            'released': released,
            'cycleStatus': released ? 'RELEASED' : 'NOT_RELEASED',
            'teacherEntryOpen': released,
            'locked': false,
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

    expect(find.text('Locked'), findsOneWidget);
    expect(find.byKey(const ValueKey('release-evaluations')), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('release-evaluations')));
    await tester.pumpAndSettle();
    expect(find.text('Release evaluations?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-release-evaluations')));
    await tester.pumpAndSettle();

    expect(releaseRequest, isNotNull);
    expect(releaseRequest!.url.queryParameters['termId'], '7');
    expect(find.text('Released'), findsOneWidget);
    expect(find.byKey(const ValueKey('release-evaluations')), findsNothing);
    expect(find.byKey(const ValueKey('lock-evaluations')), findsNothing);
  });

  testWidgets(
    'manager sees a contextual update banner only when teaching setup changed',
    (tester) async {
      await useWideScreen(tester);
      var changesDetected = true;
      http.Request? syncRequest;
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/term-evaluations/sync')) {
            syncRequest = request;
            changesDetected = false;
            return http.Response('{"assignmentsCreated":1}', 200);
          }
          return http.Response(
            jsonEncode({
              'released': true,
              'cycleStatus': 'RELEASED',
              'teacherEntryOpen': true,
              'locked': false,
              'setupChangesDetected': changesDetected,
              'pendingAssignmentCount': changesDetected ? 1 : 0,
              'totalAssignments': changesDetected ? 1 : 0,
              'submitted': 0,
              'incomplete': changesDetected ? 1 : 0,
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

      expect(find.text('New class or teacher changes found'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-evaluations')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('update-evaluations')));
      await tester.pumpAndSettle();

      expect(syncRequest, isNotNull);
      expect(syncRequest!.url.queryParameters['termId'], '7');
      expect(find.text('New class or teacher changes found'), findsNothing);
      expect(
        find.text('Evaluations updated. 1 evaluation record was added.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'leadership approves a proposed score correction and regeneration',
    (tester) async {
      await useWideScreen(tester);
      var pending = true;
      http.Request? approvalRequest;
      final api = AssessmentApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          if (request.url.path.contains('/report-corrections/')) {
            if (request.method == 'POST' &&
                request.url.path.endsWith('/9/approve')) {
              approvalRequest = request;
              pending = false;
              return http.Response(
                '{"id":9,"status":"APPROVED_REGENERATED"}',
                200,
              );
            }
            return http.Response(
              pending
                  ? jsonEncode([
                      {
                        'id': 9,
                        'customStudentId': 'STU-1',
                        'assessmentId': 'ASM-1',
                        'assessmentTitle': 'Mathematics CAT 1',
                        'originalScore': 12,
                        'proposedScore': 15,
                        'reason': 'Transcription error',
                        'requestedBy': 'teacher@example.com',
                        'assignedApprover': 'head@example.com',
                      },
                    ])
                  : '[]',
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'released': true,
              'cycleStatus': 'RELEASED',
              'teacherEntryOpen': true,
              'totalAssignments': 0,
              'submitted': 0,
              'incomplete': 0,
              'assignments': const [],
              'readiness': {
                'readyStudents': 0,
                'blockedStudents': 0,
                'students': const [],
              },
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

      expect(find.textContaining('1 report correction needs'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('review-report-corrections')));
      await tester.pumpAndSettle();
      expect(find.textContaining('12 → 15'), findsOneWidget);
      expect(
        find.textContaining('Assigned to head@example.com'),
        findsOneWidget,
      );

      await tester.tap(find.text('Approve & regenerate').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve & regenerate').last);
      await tester.pumpAndSettle();

      expect(approvalRequest, isNotNull);
      expect(approvalRequest!.method, 'POST');
      expect(
        find.text('No correction requests are awaiting a decision.'),
        findsOneWidget,
      );
    },
  );
}
