import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class AssessmentApiClient {
  AssessmentApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<AssessmentFormSetup> getFormSetup(String customSchoolId) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final responses = await Future.wait([
      _send('/api/grade-levels/school/$schoolPath/all-streams'),
      _send('/api/schools/$schoolPath/subjects?active=true'),
      _send('/api/schools/$schoolPath/academic-context/current'),
      _send('/api/grade-levels/school/$schoolPath'),
    ]);

    final streamsBody = _decodeBody(responses[0]);
    final streamValues = streamsBody is Map<String, dynamic>
        ? _list(streamsBody['data'])
        : _list(streamsBody);
    final rawStreams = streamValues
        .map(_map)
        .map(
          (item) => AssessmentStreamOption(
            id: _int(item['id']) ?? 0,
            gradeLevelId: _int(item['gradeLevelId']) ?? 0,
            gradeName: _string(item['gradeLevelName']),
            streamName: _string(item['name']).isNotEmpty
                ? _string(item['name'])
                : _string(item['alias']),
            studentCount: _int(item['studentCount']) ?? 0,
          ),
        )
        .where((item) => item.id > 0 && item.label.isNotEmpty)
        .toList();

    final subjects = _list(_decodeBody(responses[1]))
        .map(_map)
        .map(
          (item) => AssessmentSubjectOption(
            id: _int(item['id']) ?? 0,
            gradeLevelId: _int(item['gradeLevelId']) ?? 0,
            name: _string(item['subjectName']),
          ),
        )
        .where((item) => item.id > 0 && item.name.isNotEmpty)
        .toList();

    final context = _map(_decodeBody(responses[2]));
    final gradeLevelsBody = _decodeBody(responses[3]);
    final gradeLevelValues = gradeLevelsBody is Map<String, dynamic>
        ? _list(
            gradeLevelsBody['data'] ??
                gradeLevelsBody['gradeLevels'] ??
                gradeLevelsBody['content'] ??
                gradeLevelsBody['items'],
          )
        : _list(gradeLevelsBody);
    final gradeLevels = gradeLevelValues
        .map(_map)
        .map((item) {
          final nested = _map(item['gradeLevel']);
          final name = _string(
            item['gradeName'] ??
                item['gradeLevelName'] ??
                item['name'] ??
                nested['gradeName'] ??
                nested['gradeLevelName'] ??
                nested['name'],
          );
          return AssessmentGradeLevelOption(
            id: _int(item['gradeLevelId'] ?? item['id'] ?? nested['id']) ?? 0,
            name: name,
            status: _string(item['status']),
            displayOrder:
                _int(item['displayOrder'] ?? nested['displayOrder']) ?? 0,
          );
        })
        .where(
          (item) =>
              item.id > 0 &&
              item.name.isNotEmpty &&
              item.status.toUpperCase() != 'INACTIVE',
        )
        .toList();

    // The all-streams endpoint currently returns the school-grade row id while
    // subjects and the grade-level endpoint use the canonical GES grade id.
    // Reconcile by the shared grade name so valid subjects are not filtered out.
    final canonicalGradeIds = <String, int>{
      for (final grade in gradeLevels)
        grade.name.trim().toLowerCase(): grade.id,
    };
    final streams = rawStreams
        .map(
          (stream) => AssessmentStreamOption(
            id: stream.id,
            gradeLevelId:
                canonicalGradeIds[stream.gradeName.trim().toLowerCase()] ??
                stream.gradeLevelId,
            gradeName: stream.gradeName,
            streamName: stream.streamName,
            studentCount: stream.studentCount,
          ),
        )
        .toList();
    final year = _map(context['academicYear']);
    final term = _map(context['academicTerm']);
    final termId = _int(term['id']) ?? 0;
    final termName = _string(term['name']);
    return AssessmentFormSetup(
      streams: streams,
      gradeLevels: gradeLevels,
      subjects: subjects,
      academicYearId: _int(year['id']) ?? 0,
      academicYearName: _string(year['name']),
      termId: termId,
      termName: termName,
      termSequence:
          _int(term['sequence']) ??
          _termSequenceFromName(termName) ??
          (termId >= 1 && termId <= 3 ? termId : 0),
      termClosed: term['closed'] == true,
    );
  }

  Future<Map<String, dynamic>> createAssessment({
    required String customSchoolId,
    required Map<String, dynamic> body,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    return _map(
      _decodeBody(
        await _send(
          '/api/sba-new/schools/$schoolPath/assessments',
          method: 'POST',
          body: body,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> updateAssessment({
    required String customSchoolId,
    required String assessmentId,
    required Map<String, dynamic> body,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final assessmentPath = Uri.encodeComponent(assessmentId);
    return _map(
      _decodeBody(
        await _send(
          '/api/sba-new/schools/$schoolPath/assessments/$assessmentPath',
          method: 'PUT',
          body: body,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getAssessments({
    required String customSchoolId,
    required int streamId,
    required int term,
    required int academicYearId,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final query = Uri(
      queryParameters: {
        'streamId': '$streamId',
        'term': '$term',
        'academicYearId': '$academicYearId',
        'page': '0',
        'size': '100',
      },
    ).query;
    final decoded = _map(
      _decodeBody(
        await _send('/api/sba-new/schools/$schoolPath/assessments?$query'),
      ),
    );
    return _list(decoded['assessments']).map(_map).toList();
  }

  Future<Map<String, dynamic>> getAssessment({
    required String customSchoolId,
    required String assessmentId,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final assessmentPath = Uri.encodeComponent(assessmentId);
    return _map(
      _decodeBody(
        await _send(
          '/api/sba-new/schools/$schoolPath/assessments/$assessmentPath',
        ),
      ),
    );
  }

  Future<void> deleteAssessment({
    required String customSchoolId,
    required String assessmentId,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final assessmentPath = Uri.encodeComponent(assessmentId);
    await _send(
      '/api/sba-new/schools/$schoolPath/assessments/$assessmentPath',
      method: 'DELETE',
    );
  }

  Future<AssessmentScoreSheetData> getScoreSheet({
    required String customSchoolId,
    required String assessmentId,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final assessmentPath = Uri.encodeComponent(assessmentId);
    final decoded = _map(
      _decodeBody(
        await _send(
          '/api/sba-new/schools/$schoolPath/assessments/$assessmentPath/scores',
        ),
      ),
    );
    final assessment = _map(decoded['assessment']);
    return AssessmentScoreSheetData(
      assessment: assessment,
      students: _list(decoded['scores'])
          .map(_map)
          .map(
            (item) => AssessmentStudentScore(
              studentId: _string(item['studentId']),
              firstName: _string(item['firstName']),
              lastName: _string(item['lastName']),
              score: _double(item['score']),
              maxScore: _double(item['maxScore']),
              percentage: _double(item['percentage']),
              status: _string(item['status']),
              remarks: _string(item['remarks']),
            ),
          )
          .where((item) => item.studentId.isNotEmpty)
          .toList(),
    );
  }

  Future<Map<String, dynamic>> saveScoreSheet({
    required String customSchoolId,
    required String assessmentId,
    required String submittedBy,
    required List<Map<String, dynamic>> scores,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final assessmentPath = Uri.encodeComponent(assessmentId);
    return _map(
      _decodeBody(
        await _send(
          '/api/sba-new/schools/$schoolPath/assessments/$assessmentPath/scores',
          method: 'PUT',
          body: {
            'assessmentId': assessmentId,
            'submittedBy': submittedBy,
            'scores': scores,
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> resetStudentScore({
    required String customSchoolId,
    required String assessmentId,
    required String studentId,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    final assessmentPath = Uri.encodeComponent(assessmentId);
    final studentPath = Uri.encodeComponent(studentId);
    return _map(
      _decodeBody(
        await _send(
          '/api/sba-new/schools/$schoolPath/assessments/$assessmentPath/scores/$studentPath',
          method: 'DELETE',
        ),
      ),
    );
  }

  Future<List<CurriculumIndicatorData>> getCurriculumIndicators({
    required String grade,
    required String subject,
  }) async {
    final gradePath = Uri.encodeComponent(grade);
    final subjectPath = Uri.encodeComponent(subject);
    final response = await _send(
      '/api/sba-new/curriculum/$gradePath/$subjectPath',
    );
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const [];

    final indicators = <CurriculumIndicatorData>[];
    for (final strandValue in _list(decoded['strands'])) {
      final strand = _map(strandValue);
      final strandName = _string(strand['name']);
      for (final substrandValue in _list(strand['substrands'])) {
        final substrand = _map(substrandValue);
        final substrandName = _string(substrand['name']);
        for (final indicatorValue in _list(substrand['indicators'])) {
          final indicator = _map(indicatorValue);
          final code = _string(indicator['code']);
          if (code.isEmpty) continue;
          indicators.add(
            CurriculumIndicatorData(
              id: _int(indicator['id']),
              code: code,
              description: _string(indicator['description']),
              strand: _string(indicator['strand']).isNotEmpty
                  ? _string(indicator['strand'])
                  : strandName,
              substrand: _string(indicator['substrand']).isNotEmpty
                  ? _string(indicator['substrand'])
                  : substrandName,
            ),
          );
        }
      }
    }
    return indicators;
  }

  Future<Map<String, dynamic>> getStreamReportReadiness({
    required String customSchoolId,
    required int streamId,
    required int term,
    required int academicYearId,
    int? academicTermId,
  }) async {
    final query = Uri(
      queryParameters: {
        'term': '$term',
        'academicYearId': '$academicYearId',
        if (academicTermId != null) 'academicTermId': '$academicTermId',
      },
    ).query;
    return _map(
      _decodeBody(
        await _send(
          '/api/grades/stream/$streamId/readiness?$query',
          extraHeaders: {'X-School-ID': customSchoolId},
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getStreamGrades({
    required String customSchoolId,
    required int streamId,
    required int term,
    required int academicYearId,
  }) async {
    final query = Uri(
      queryParameters: {'term': '$term', 'academicYearId': '$academicYearId'},
    ).query;
    return _list(
      _decodeBody(
        await _send(
          '/api/grades/stream/$streamId/all-subjects?$query',
          extraHeaders: {'X-School-ID': customSchoolId},
        ),
      ),
    ).map(_map).toList();
  }

  Future<Map<String, dynamic>> generateStreamReports({
    required String customSchoolId,
    required int streamId,
    required int term,
    required int academicYearId,
    required String generatedBy,
    List<String> customStudentIds = const [],
    String? vacationOverrideReason,
  }) async {
    return _map(
      _decodeBody(
        await _send(
          '/api/grades/stream/generate-reports',
          method: 'POST',
          extraHeaders: {'X-School-ID': customSchoolId},
          body: {
            'streamId': streamId,
            'term': term,
            'academicYearId': academicYearId,
            // Draft generation is allowed for completed subjects. The API
            // still applies strict validation when a report is finalized.
            'strictMode': false,
            'finalize': false,
            'generatedBy': generatedBy,
            if (customStudentIds.isNotEmpty)
              'customStudentIds': customStudentIds,
            if (vacationOverrideReason?.trim().isNotEmpty == true)
              'vacationOverrideReason': vacationOverrideReason!.trim(),
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> getStudentReportCard({
    required String customSchoolId,
    required String customStudentId,
    required int termId,
    required int academicYearId,
  }) async {
    final studentPath = Uri.encodeComponent(customStudentId);
    final query = Uri(
      queryParameters: {
        'customSchoolId': customSchoolId,
        'termId': '$termId',
        'academicYearId': '$academicYearId',
      },
    ).query;
    return _map(
      _decodeBody(
        await _send('/api/report-cards/student/$studentPath/data?$query'),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> getStudentEvaluations({
    required String customStudentId,
    required int termId,
  }) async {
    final studentPath = Uri.encodeComponent(customStudentId);
    final query = Uri(queryParameters: {'termId': '$termId'}).query;
    return _list(
      _decodeBody(
        await _send('/api/student-evaluations/student/$studentPath?$query'),
      ),
    ).map(_map).toList();
  }

  Future<void> saveStudentEvaluations({
    required String customSchoolId,
    required String customStudentId,
    required int termId,
    required String evaluatedBy,
    required List<Map<String, dynamic>> evaluations,
  }) async {
    final existing = await getStudentEvaluations(
      customStudentId: customStudentId,
      termId: termId,
    );
    if (existing.isEmpty) {
      final query = Uri(queryParameters: {'evaluatedBy': evaluatedBy}).query;
      await _send(
        '/api/student-evaluations?$query',
        method: 'POST',
        body: {
          'customStudentId': customStudentId,
          'customSchoolId': customSchoolId,
          'termId': '$termId',
          'evaluations': evaluations,
        },
      );
      return;
    }

    final studentPath = Uri.encodeComponent(customStudentId);
    final query = Uri(
      queryParameters: {
        'customSchoolId': customSchoolId,
        'termId': '$termId',
        'evaluatedBy': evaluatedBy,
      },
    ).query;
    await _send(
      '/api/student-evaluations/$studentPath?$query',
      method: 'PUT',
      body: evaluations,
    );
  }

  Future<Map<String, dynamic>> publishStudentReportCard({
    required String customSchoolId,
    required String customStudentId,
    required int termId,
    required int term,
    required int academicYearId,
    required String publishedBy,
  }) async {
    final studentPath = Uri.encodeComponent(customStudentId);
    final query = Uri(
      queryParameters: {
        'customSchoolId': customSchoolId,
        'termId': '$termId',
        'term': '$term',
        'academicYearId': '$academicYearId',
        'publishedBy': publishedBy,
      },
    ).query;
    return _map(
      _decodeBody(
        await _send(
          '/api/report-cards/student/$studentPath/publish?$query',
          method: 'POST',
        ),
      ),
    );
  }

  Future<List<int>> getStudentReportCardPdf({
    required String customSchoolId,
    required String customStudentId,
    required int termId,
    required int academicYearId,
  }) async {
    final studentPath = Uri.encodeComponent(customStudentId);
    final query = Uri(
      queryParameters: {
        'customSchoolId': customSchoolId,
        'termId': '$termId',
        'academicYearId': '$academicYearId',
        'download': 'false',
      },
    ).query;
    final response = await _send(
      '/api/report-cards/student/$studentPath/pdf?$query',
      extraHeaders: const {'Accept': 'application/pdf'},
    );
    if (response.bodyBytes.isEmpty) {
      throw const AssessmentApiException(
        'The report PDF could not be generated.',
      );
    }
    return response.bodyBytes;
  }

  Future<List<Map<String, dynamic>>> getReportCardRemarks({
    required String customSchoolId,
    required int termId,
  }) async {
    final schoolPath = Uri.encodeComponent(customSchoolId);
    return _list(
      _decodeBody(
        await _send('/api/report-card-remarks/school/$schoolPath/term/$termId'),
      ),
    ).map(_map).toList();
  }

  Future<Map<String, dynamic>> saveReportCardRemarks({
    required String submittedBy,
    required Map<String, dynamic> body,
  }) async {
    final query = Uri(queryParameters: {'submittedBy': submittedBy}).query;
    return _map(
      _decodeBody(
        await _send(
          '/api/report-card-remarks?$query',
          method: 'POST',
          body: body,
        ),
      ),
    );
  }

  Future<http.Response> _send(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, String> extraHeaders = const {},
    bool retry = true,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const AssessmentApiException('Please sign in again to continue.');
    }

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        ...extraHeaders,
      };
      final response =
          await (method == 'POST'
                  ? _client.post(uri, headers: headers, body: jsonEncode(body))
                  : method == 'PUT'
                  ? _client.put(uri, headers: headers, body: jsonEncode(body))
                  : method == 'DELETE'
                  ? _client.delete(uri, headers: headers)
                  : _client.get(uri, headers: headers))
              .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      if (response.statusCode == 401 && retry && onRefreshAccessToken != null) {
        final refreshed = await onRefreshAccessToken!();
        if (refreshed != null && refreshed.isNotEmpty) {
          accessToken = refreshed;
          return _send(
            path,
            method: method,
            body: body,
            extraHeaders: extraHeaders,
            retry: false,
          );
        }
      }
      throw AssessmentApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw const AssessmentApiException(
        'The assessment request timed out. Please try again.',
      );
    } on AssessmentApiException {
      rethrow;
    } catch (_) {
      throw const AssessmentApiException(
        'Unable to complete the assessment request right now.',
      );
    }
  }

  Future<Map<String, dynamic>> releaseTermEvaluations({
    required String schoolId,
    required int termId,
    required String actor,
  }) async {
    final q = Uri(
      queryParameters: {
        'customSchoolId': schoolId,
        'termId': '$termId',
        'actor': actor,
      },
    ).query;
    return _map(
      _decodeBody(
        await _send(
          '/api/term-evaluations/release?$q',
          method: 'POST',
          body: const {},
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> getTermEvaluationDashboard({
    required String schoolId,
    required int termId,
  }) async {
    final q = Uri(
      queryParameters: {'customSchoolId': schoolId, 'termId': '$termId'},
    ).query;
    return _map(_decodeBody(await _send('/api/term-evaluations/dashboard?$q')));
  }

  Future<void> saveTermEvaluationAssignment({
    required int assignmentId,
    required String schoolId,
    required String staffId,
    required List<Map<String, dynamic>> students,
  }) async {
    final q = Uri(
      queryParameters: {'customSchoolId': schoolId, 'staffId': staffId},
    ).query;
    await _send(
      '/api/term-evaluations/assignments/$assignmentId?$q',
      method: 'PUT',
      body: {'students': students},
    );
  }

  Future<Map<String, dynamic>> getTermEvaluationAssignment({
    required int assignmentId,
    required String schoolId,
  }) async {
    final q = Uri(queryParameters: {'customSchoolId': schoolId}).query;
    return _map(
      _decodeBody(
        await _send('/api/term-evaluations/assignments/$assignmentId?$q'),
      ),
    );
  }

  Future<void> submitTermEvaluationAssignment({
    required int assignmentId,
    required String schoolId,
    required String staffId,
  }) async {
    final q = Uri(
      queryParameters: {'customSchoolId': schoolId, 'staffId': staffId},
    ).query;
    await _send(
      '/api/term-evaluations/assignments/$assignmentId/submit?$q',
      method: 'POST',
      body: const {},
    );
  }

  Future<void> reopenTermEvaluationAssignment({
    required int assignmentId,
    required String schoolId,
    required String actor,
    required String reason,
  }) async {
    final q = Uri(
      queryParameters: {'customSchoolId': schoolId, 'actor': actor},
    ).query;
    await _send(
      '/api/term-evaluations/assignments/$assignmentId/reopen?$q',
      method: 'POST',
      body: {'reason': reason},
    );
  }

  Future<Map<String, String>> getConsolidatedEvaluation({
    required String studentId,
    required String schoolId,
    required int termId,
  }) async {
    final q = Uri(
      queryParameters: {'customSchoolId': schoolId, 'termId': '$termId'},
    ).query;
    final body = _map(
      _decodeBody(
        await _send(
          '/api/term-evaluations/students/${Uri.encodeComponent(studentId)}/consolidated?$q',
        ),
      ),
    );
    return body.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<Map<String, dynamic>> getTermEvaluationReview({
    required String studentId,
    required String schoolId,
    required int termId,
  }) async {
    final q = Uri(
      queryParameters: {'customSchoolId': schoolId, 'termId': '$termId'},
    ).query;
    return _map(
      _decodeBody(
        await _send(
          '/api/term-evaluations/students/${Uri.encodeComponent(studentId)}/review?$q',
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> suggestTermEvaluationComment({
    required String studentId,
    required String schoolId,
    required int termId,
    required Map<String, String> finalRatings,
    int variant = 0,
  }) async {
    final q = Uri(
      queryParameters: {
        'customSchoolId': schoolId,
        'termId': '$termId',
        'variant': '$variant',
      },
    ).query;
    return _map(
      _decodeBody(
        await _send(
          '/api/term-evaluations/students/${Uri.encodeComponent(studentId)}/comment-suggestion?$q',
          method: 'POST',
          body: {'finalRatings': finalRatings},
        ),
      ),
    );
  }

  Future<void> finalizeTermEvaluationReview({
    required String studentId,
    required String schoolId,
    required int termId,
    required String staffId,
    required Map<String, String> finalRatings,
    String? comment,
  }) async {
    final q = Uri(
      queryParameters: {
        'customSchoolId': schoolId,
        'termId': '$termId',
        'staffId': staffId,
      },
    ).query;
    await _send(
      '/api/term-evaluations/students/${Uri.encodeComponent(studentId)}/finalize?$q',
      method: 'POST',
      body: {'finalRatings': finalRatings, 'comment': comment},
    );
  }

  Future<void> requestEvaluationOverride({
    required String studentId,
    required String schoolId,
    required int termId,
    required String actor,
    required String criterion,
    required String proposedRating,
    required String reason,
  }) async {
    final q = Uri(
      queryParameters: {
        'customSchoolId': schoolId,
        'termId': '$termId',
        'actor': actor,
      },
    ).query;
    await _send(
      '/api/term-evaluations/students/${Uri.encodeComponent(studentId)}/overrides?$q',
      method: 'POST',
      body: {
        'criterion': criterion,
        'proposedRating': proposedRating,
        'reason': reason,
      },
    );
  }

  Future<void> decideEvaluationOverride({
    required int overrideId,
    required bool approve,
    required String actor,
    required String reason,
  }) async {
    final q = Uri(
      queryParameters: {'approve': '$approve', 'actor': actor},
    ).query;
    await _send(
      '/api/term-evaluations/overrides/$overrideId/decision?$q',
      method: 'POST',
      body: {'reason': reason},
    );
  }

  Future<void> acceptConsolidatedEvaluation({
    required String studentId,
    required String schoolId,
    required int termId,
    required String actor,
    String? comment,
  }) async {
    final q = Uri(
      queryParameters: {
        'customSchoolId': schoolId,
        'termId': '$termId',
        'actor': actor,
      },
    ).query;
    await _send(
      '/api/term-evaluations/students/${Uri.encodeComponent(studentId)}/accept?$q',
      method: 'POST',
      body: {'comment': comment},
    );
  }

  Future<void> remindTermEvaluationTeacher({
    required int assignmentId,
    required String schoolId,
    required int termId,
    required String actor,
    String? message,
  }) async {
    final q = Uri(
      queryParameters: {
        'customSchoolId': schoolId,
        'termId': '$termId',
        'actor': actor,
      },
    ).query;
    await _send(
      '/api/term-evaluations/assignments/$assignmentId/remind?$q',
      method: 'POST',
      body: {'message': message},
    );
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) return const <String, dynamic>{};
    return jsonDecode(response.body);
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is String && body.trim().isNotEmpty) return body.trim();
      if (body is List &&
          body.isNotEmpty &&
          body.first is String &&
          (body.first as String).trim().isNotEmpty) {
        return (body.first as String).trim();
      }
      if (body is Map<String, dynamic>) {
        final message = body['message'] ?? body['error'] ?? body['detail'];
        if (message is String && message.trim().isNotEmpty) return message;
      }
    } catch (_) {
      final raw = response.body.trim();
      if (raw.isNotEmpty) return raw;
    }
    return response.statusCode == 404
        ? 'The requested assessment resource was not found.'
        : 'Unable to complete the assessment request.';
  }

  static List<dynamic> _list(dynamic value) => value is List ? value : const [];
  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : const {};
  static String _string(dynamic value) => value?.toString().trim() ?? '';
  static int? _int(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
  static double? _double(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  static int? _termSequenceFromName(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('first') || normalized.contains('term 1')) return 1;
    if (normalized.contains('second') || normalized.contains('term 2')) {
      return 2;
    }
    if (normalized.contains('third') || normalized.contains('term 3')) return 3;
    return null;
  }
}

class AssessmentScoreSheetData {
  const AssessmentScoreSheetData({
    required this.assessment,
    required this.students,
  });

  final Map<String, dynamic> assessment;
  final List<AssessmentStudentScore> students;
}

class AssessmentStudentScore {
  const AssessmentStudentScore({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.status,
    required this.remarks,
  });

  final String studentId;
  final String firstName;
  final String lastName;
  final double? score;
  final double? maxScore;
  final double? percentage;
  final String status;
  final String remarks;

  String get name =>
      [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');
}

class AssessmentFormSetup {
  const AssessmentFormSetup({
    required this.streams,
    required this.gradeLevels,
    required this.subjects,
    required this.academicYearId,
    required this.academicYearName,
    required this.termId,
    required this.termName,
    required this.termSequence,
    required this.termClosed,
  });

  final List<AssessmentStreamOption> streams;
  final List<AssessmentGradeLevelOption> gradeLevels;
  final List<AssessmentSubjectOption> subjects;
  final int academicYearId;
  final String academicYearName;
  final int termId;
  final String termName;
  final int termSequence;
  final bool termClosed;
}

class AssessmentGradeLevelOption {
  const AssessmentGradeLevelOption({
    required this.id,
    required this.name,
    required this.status,
    this.displayOrder = 0,
  });

  final int id;
  final String name;
  final String status;
  final int displayOrder;
}

class AssessmentStreamOption {
  const AssessmentStreamOption({
    required this.id,
    required this.gradeLevelId,
    required this.gradeName,
    required this.streamName,
    required this.studentCount,
  });

  final int id;
  final int gradeLevelId;
  final String gradeName;
  final String streamName;
  final int studentCount;

  String get label => [
    gradeName,
    streamName,
  ].where((part) => part.trim().isNotEmpty).join(' - ');
}

class AssessmentSubjectOption {
  const AssessmentSubjectOption({
    required this.id,
    required this.gradeLevelId,
    required this.name,
  });

  final int id;
  final int gradeLevelId;
  final String name;
}

class CurriculumIndicatorData {
  const CurriculumIndicatorData({
    required this.id,
    required this.code,
    required this.description,
    required this.strand,
    required this.substrand,
  });

  final int? id;
  final String code;
  final String description;
  final String strand;
  final String substrand;
}

class AssessmentApiException implements Exception {
  const AssessmentApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
