import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/assessments/data/assessment_api_client.dart';

void main() {
  group('AssessmentApiClient curriculum lookup', () {
    test('flattens strands and substrands into indicators', () async {
      late Uri requestedUri;
      final client = MockClient((request) async {
        requestedUri = request.url;
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('''
          {
            "grade": "Grade 5",
            "subject": "Mathematics",
            "strands": [{
              "name": "Number",
              "substrands": [{
                "name": "Algebra",
                "indicators": [{
                  "id": 12,
                  "code": "B5.1.2.1",
                  "description": "Represent unknown numbers."
                }]
              }]
            }]
          }
          ''', 200);
      });
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: client,
      );

      final result = await api.getCurriculumIndicators(
        grade: 'Grade 5',
        subject: 'Mathematics',
      );

      expect(
        requestedUri.path,
        endsWith('/api/sba-new/curriculum/Grade%205/Mathematics'),
      );
      expect(result, hasLength(1));
      expect(result.single.id, 12);
      expect(result.single.code, 'B5.1.2.1');
      expect(result.single.strand, 'Number');
      expect(result.single.substrand, 'Algebra');
    });

    test('surfaces the backend message when lookup fails', () async {
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient(
          (_) async => http.Response(
            '{"message":"No curriculum configured for this subject"}',
            404,
          ),
        ),
      );

      expect(
        () => api.getCurriculumIndicators(
          grade: 'Grade 5',
          subject: 'Mathematics',
        ),
        throwsA(
          isA<AssessmentApiException>().having(
            (error) => error.message,
            'message',
            'No curriculum configured for this subject',
          ),
        ),
      );
    });
  });

  group('AssessmentApiClient assessment form', () {
    test('loads streams, configured subjects, and academic context', () async {
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/all-streams')) {
            return http.Response(
              '{"success":true,"data":[{"id":7,"name":"A","gradeLevelId":5,"gradeLevelName":"Grade 5","studentCount":31}]}',
              200,
            );
          }
          if (request.url.path.endsWith('/subjects')) {
            return http.Response(
              '[{"id":12,"gradeLevelId":5,"subjectName":"Mathematics","isActive":true}]',
              200,
            );
          }
          if (request.url.path.endsWith('/api/grade-levels/school/SCHOOL-1')) {
            return http.Response(
              '[{"gradeLevelId":5,"gradeLevelName":"Grade 5","status":"ACTIVE"},{"gradeLevelId":6,"gradeLevelName":"Grade 6","status":"ACTIVE"}]',
              200,
            );
          }
          return http.Response(
            '{"academicYear":{"id":2,"name":"2026-2027"},"academicTerm":{"id":4,"name":"Second Term","closed":false}}',
            200,
          );
        }),
      );

      final setup = await api.getFormSetup('SCHOOL-1');

      expect(setup.streams.single.label, 'Grade 5 - A');
      expect(setup.gradeLevels.map((grade) => grade.name), [
        'Grade 5',
        'Grade 6',
      ]);
      expect(setup.subjects.single.name, 'Mathematics');
      expect(setup.academicYearId, 2);
      expect(setup.termSequence, 2);
      expect(setup.termClosed, isFalse);
    });

    test('posts the assessment payload to the school endpoint', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            '{"success":true,"assessmentId":"ASM-100","assessment":{"assessmentId":"ASM-100"}}',
            201,
          );
        }),
      );

      final result = await api.createAssessment(
        customSchoolId: 'SCHOOL-1',
        body: {
          'streamId': 7,
          'schoolSubjectId': 12,
          'type': 'CAT1',
          'title': 'Fractions',
          'date': '2026-07-29',
          'maxScore': 10,
          'term': 2,
          'academicYearId': 2,
          'curriculumIndicatorCodes': ['B5.1.2.1'],
        },
      );

      expect(request.method, 'POST');
      expect(
        request.url.path,
        endsWith('/api/sba-new/schools/SCHOOL-1/assessments'),
      );
      expect(request.body, contains('"schoolSubjectId":12'));
      expect(result['assessmentId'], 'ASM-100');
    });

    test('loads and deletes persisted assessments', () async {
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') return http.Response('', 204);
          return http.Response(
            '{"assessments":[{"assessmentId":"ASM-100","title":"Fractions"}],"totalCount":1}',
            200,
          );
        }),
      );

      final assessments = await api.getAssessments(
        customSchoolId: 'SCHOOL-1',
        streamId: 7,
        term: 2,
        academicYearId: 3,
      );
      await api.deleteAssessment(
        customSchoolId: 'SCHOOL-1',
        assessmentId: 'ASM-100',
      );

      expect(assessments.single['assessmentId'], 'ASM-100');
      expect(requests.first.url.queryParameters['streamId'], '7');
      expect(requests.first.url.queryParameters['term'], '2');
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, endsWith('/assessments/ASM-100'));
    });

    test('updates assessment metadata and curriculum selections', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            '{"assessmentId":"ASM-100","title":"Fractions revised","description":"Updated notes","isOfficialSBA":true}',
            200,
          );
        }),
      );

      final result = await api.updateAssessment(
        customSchoolId: 'SCHOOL-1',
        assessmentId: 'ASM-100',
        body: {
          'title': 'Fractions revised',
          'type': 'CAT1',
          'date': '2026-07-30',
          'maxScore': 10,
          'term': 2,
          'description': 'Updated notes',
          'isOfficialSBA': true,
          'curriculumIndicatorCodes': ['B5.1.2.1'],
        },
      );

      expect(request.method, 'PUT');
      expect(request.url.path, endsWith('/assessments/ASM-100'));
      expect(request.body, contains('"description":"Updated notes"'));
      expect(request.body, contains('"isOfficialSBA":true'));
      expect(result['title'], 'Fractions revised');
    });

    test('loads GES report readiness for a stream', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            '{"streamId":7,"totalStudents":2,"overallStatus":{"studentsReadyForReport":1,"studentsNotReady":1},"studentReadinessDetails":[]}',
            200,
          );
        }),
      );

      final readiness = await api.getStreamReportReadiness(
        customSchoolId: 'SCHOOL-1',
        streamId: 7,
        term: 2,
        academicYearId: 3,
      );

      expect(request.url.path, endsWith('/api/grades/stream/7/readiness'));
      expect(request.url.queryParameters['term'], '2');
      expect(request.headers['X-School-ID'], 'SCHOOL-1');
      expect(readiness['totalStudents'], 2);
    });

    test('loads grades and generates selected student reports', () async {
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              '{"generationResults":{"reportsGenerated":1,"reportsNotGenerated":0}}',
              200,
            );
          }
          return http.Response(
            '[{"customStudentId":"STU-1","percentage":84,"grade":"HP"}]',
            200,
          );
        }),
      );

      final grades = await api.getStreamGrades(
        customSchoolId: 'SCHOOL-1',
        streamId: 7,
        term: 2,
        academicYearId: 3,
      );
      await api.generateStreamReports(
        customSchoolId: 'SCHOOL-1',
        streamId: 7,
        term: 2,
        academicYearId: 3,
        generatedBy: 'teacher-1',
        customStudentIds: const ['STU-1'],
        vacationOverrideReason: 'Vacation report preparation',
      );

      expect(grades.single['percentage'], 84);
      expect(requests.first.url.path, endsWith('/all-subjects'));
      expect(requests.last.url.path, endsWith('/stream/generate-reports'));
      expect(requests.last.headers['X-School-ID'], 'SCHOOL-1');
      expect(requests.last.body, contains('"customStudentIds":["STU-1"]'));
      expect(
        requests.last.body,
        contains('"vacationOverrideReason":"Vacation report preparation"'),
      );
    });

    test('loads and saves report-card remarks', () async {
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              '{"customStudentId":"STU-1","ignoreHeadTeacherRemarks":true}',
              200,
            );
          }
          return http.Response(
            '[{"customStudentId":"STU-1","classTeacherRemarks":"Good progress","promotedTo":"Grade 6"}]',
            200,
          );
        }),
      );

      final rows = await api.getReportCardRemarks(
        customSchoolId: 'SCHOOL-1',
        termId: 4,
      );
      await api.saveReportCardRemarks(
        submittedBy: 'teacher-1',
        body: {
          'customStudentId': 'STU-1',
          'customSchoolId': 'SCHOOL-1',
          'termId': 4,
          'ignoreHeadTeacherRemarks': true,
        },
      );

      expect(rows.single['promotedTo'], 'Grade 6');
      expect(requests.first.url.path, endsWith('/school/SCHOOL-1/term/4'));
      expect(requests.last.method, 'POST');
      expect(requests.last.url.queryParameters['submittedBy'], 'teacher-1');
      expect(requests.last.body, contains('"ignoreHeadTeacherRemarks":true'));
    });

    test(
      'publishes a report card through the guarded lifecycle endpoint',
      () async {
        late http.Request request;
        final api = AssessmentApiClient(
          accessToken: 'test-token',
          client: MockClient((value) async {
            request = value;
            return http.Response(
              '{"customStudentId":"STU-1","reportStatus":"PUBLISHED"}',
              200,
            );
          }),
        );

        final result = await api.publishStudentReportCard(
          customSchoolId: 'SCHOOL-1',
          customStudentId: 'STU-1',
          termId: 4,
          term: 2,
          academicYearId: 3,
          publishedBy: 'head-teacher-1',
        );

        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/student/STU-1/publish'));
        expect(request.url.queryParameters['termId'], '4');
        expect(result['reportStatus'], 'PUBLISHED');
      },
    );

    test('downloads the authenticated physical report-card PDF', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response.bytes(
            const [0x25, 0x50, 0x44, 0x46],
            200,
            headers: {'content-type': 'application/pdf'},
          );
        }),
      );

      final bytes = await api.getStudentReportCardPdf(
        customSchoolId: 'SCHOOL-1',
        customStudentId: 'STU-1',
        termId: 4,
        academicYearId: 3,
      );

      expect(request.url.path, endsWith('/student/STU-1/pdf'));
      expect(request.url.queryParameters['download'], 'false');
      expect(request.headers['Accept'], 'application/pdf');
      expect(bytes, const [0x25, 0x50, 0x44, 0x46]);
    });

    test('loads the roster and saves a partial score sheet', () async {
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'PUT') {
            return http.Response(
              '{"success":true,"assessmentId":"ASM-100","scoresEntered":1,"totalStudents":2,"completionStatus":"IN_PROGRESS"}',
              200,
            );
          }
          return http.Response('''
            {
              "assessment":{"assessmentId":"ASM-100","maxScore":10},
              "scores":[
                {"studentId":"STU-1","firstName":"Ama","lastName":"Boateng","score":8.5,"maxScore":10,"percentage":85,"status":"SUBMITTED","remarks":"Good work"},
                {"studentId":"STU-2","firstName":"Kojo","lastName":"Owusu","score":null,"maxScore":10}
              ]
            }
            ''', 200);
        }),
      );

      final sheet = await api.getScoreSheet(
        customSchoolId: 'SCHOOL-1',
        assessmentId: 'ASM-100',
      );
      final saved = await api.saveScoreSheet(
        customSchoolId: 'SCHOOL-1',
        assessmentId: 'ASM-100',
        submittedBy: 'teacher-1',
        scores: [
          {
            'studentId': 'STU-2',
            'score': 7,
            'maxScore': 10,
            'remarks': 'Improving',
          },
        ],
      );

      expect(sheet.students, hasLength(2));
      expect(sheet.students.first.name, 'Ama Boateng');
      expect(sheet.students.first.score, 8.5);
      expect(requests.last.method, 'PUT');
      expect(requests.last.body, contains('"submittedBy":"teacher-1"'));
      expect(requests.last.body, contains('"studentId":"STU-2"'));
      expect(saved['completionStatus'], 'IN_PROGRESS');
    });

    test('resets a persisted student score', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            '{"success":true,"scoresEntered":0,"completionStatus":"NOT_STARTED"}',
            200,
          );
        }),
      );

      final result = await api.resetStudentScore(
        customSchoolId: 'SCHOOL-1',
        assessmentId: 'ASM-100',
        studentId: 'STU-1',
      );

      expect(request.method, 'DELETE');
      expect(request.url.path, endsWith('/assessments/ASM-100/scores/STU-1'));
      expect(result['completionStatus'], 'NOT_STARTED');
    });

    test('creates evaluations when the student has none', () async {
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') return http.Response('[]', 200);
          return http.Response('{"success":true}', 201);
        }),
      );

      await api.saveStudentEvaluations(
        customSchoolId: 'SCHOOL-1',
        customStudentId: 'STU-1',
        termId: 4,
        evaluatedBy: 'teacher-1',
        evaluations: [
          {
            'criterion': 'HOMEWORK',
            'score': 8,
            'teacherComments': 'Consistent',
            'overallComment': 'Good progress',
          },
        ],
      );

      expect(requests, hasLength(2));
      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, endsWith('/api/student-evaluations'));
      expect(requests.last.url.queryParameters['evaluatedBy'], 'teacher-1');
      expect(requests.last.body, contains('"customStudentId":"STU-1"'));
      expect(requests.last.body, contains('"overallComment":"Good progress"'));
    });

    test('updates evaluations when the student already has entries', () async {
      final requests = <http.Request>[];
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response('[{"criterion":"HOMEWORK","score":5}]', 200);
          }
          return http.Response('{"success":true}', 200);
        }),
      );

      await api.saveStudentEvaluations(
        customSchoolId: 'SCHOOL-1',
        customStudentId: 'STU-1',
        termId: 4,
        evaluatedBy: 'teacher-1',
        evaluations: [
          {'criterion': 'HOMEWORK', 'score': 9},
        ],
      );

      expect(requests.last.method, 'PUT');
      expect(
        requests.last.url.path,
        endsWith('/api/student-evaluations/STU-1'),
      );
      expect(requests.last.body, contains('"score":9'));
    });
  });

  group('AssessmentApiClient term evaluations', () {
    test('loads an assignment with its saved student ratings', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response(
            '{"id":14,"staffId":"T-1","students":[{"id":"STU-1","name":"Ama Mensah"}],"ratings":{"STU-1":{"ATTENTIVENESS":"Good"}}}',
            200,
          );
        }),
      );

      final result = await api.getTermEvaluationAssignment(
        assignmentId: 14,
        schoolId: 'SCHOOL-1',
      );

      expect(request.method, 'GET');
      expect(request.url.path, endsWith('/term-evaluations/assignments/14'));
      expect(request.url.queryParameters['customSchoolId'], 'SCHOOL-1');
      expect((result['ratings'] as Map)['STU-1']['ATTENTIVENESS'], 'Good');
    });

    test(
      'saves a per-student draft without filling omitted criteria',
      () async {
        late http.Request request;
        final api = AssessmentApiClient(
          accessToken: 'test-token',
          client: MockClient((value) async {
            request = value;
            return http.Response('', 204);
          }),
        );

        await api.saveTermEvaluationAssignment(
          assignmentId: 14,
          schoolId: 'SCHOOL-1',
          staffId: 'T-1',
          students: [
            {
              'customStudentId': 'STU-1',
              'ratings': [
                {'criterion': 'ATTENTIVENESS', 'rating': 'Not observed'},
              ],
            },
          ],
        );

        expect(request.method, 'PUT');
        expect(request.url.queryParameters['staffId'], 'T-1');
        expect(request.body, contains('"customStudentId":"STU-1"'));
        expect(request.body, contains('"rating":"Not observed"'));
        expect(request.body, isNot(contains('HOMEWORK_HABITS')));
      },
    );

    test('finalizes the class-teacher wording and comment', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response('{"status":"FINALIZED"}', 200);
        }),
      );

      await api.finalizeTermEvaluationReview(
        studentId: 'STU/1',
        schoolId: 'SCHOOL-1',
        termId: 7,
        staffId: 'CLASS-1',
        finalRatings: {'ATTENTIVENESS': 'Excellent'},
        comment: 'Consistent progress.',
      );

      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/students/STU%2F1/finalize'));
      expect(request.url.queryParameters['termId'], '7');
      expect(request.url.queryParameters['staffId'], 'CLASS-1');
      expect(request.body, contains('"ATTENTIVENESS":"Excellent"'));
      expect(request.body, contains('"comment":"Consistent progress."'));
    });

    test('sends an audited headmaster final-wording correction', () async {
      late http.Request request;
      final api = AssessmentApiClient(
        accessToken: 'test-token',
        client: MockClient((value) async {
          request = value;
          return http.Response('{"status":"FINALIZED"}', 200);
        }),
      );

      await api.adjustFinalTermEvaluationWordings(
        studentId: 'STU/1',
        schoolId: 'SCHOOL-1',
        termId: 7,
        finalRatings: {'ATTENTIVENESS': 'Excellent'},
        reason: 'Verified against the signed class record',
      );

      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/students/STU%2F1/final-wordings'));
      expect(request.url.queryParameters['termId'], '7');
      expect(request.body, contains('"ATTENTIVENESS":"Excellent"'));
      expect(
        request.body,
        contains('Verified against the signed class record'),
      );
    });

    test(
      'requests a comment suggestion from the current final wording',
      () async {
        late http.Request request;
        final api = AssessmentApiClient(
          accessToken: 'test-token',
          client: MockClient((value) async {
            request = value;
            return http.Response(
              '{"available":true,"suggestion":"A positive comment."}',
              200,
            );
          }),
        );

        final result = await api.suggestTermEvaluationComment(
          studentId: 'STU/1',
          schoolId: 'SCHOOL-1',
          termId: 7,
          variant: 2,
          finalRatings: {'ATTENTIVENESS': 'Good'},
        );

        expect(request.method, 'POST');
        expect(
          request.url.path,
          endsWith('/students/STU%2F1/comment-suggestion'),
        );
        expect(request.url.queryParameters['variant'], '2');
        expect(request.body, contains('"finalRatings"'));
        expect(request.body, contains('"ATTENTIVENESS":"Good"'));
        expect(result['suggestion'], 'A positive comment.');
      },
    );
  });
}
