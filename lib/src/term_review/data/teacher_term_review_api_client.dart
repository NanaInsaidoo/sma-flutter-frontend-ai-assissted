import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../domain/teacher_term_review_models.dart';

class TeacherTermReviewApiClient implements TeacherTermReviewRepository {
  TeacherTermReviewApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;
  @override
  Future<TeacherReviewDashboard> getDashboard(String s) async {
    final j = _map(
      await _send('GET', '/api/v2/teacher-term-reviews/school/$s/dashboard'),
    );
    return TeacherReviewDashboard(
      termId: _i(j['termId']),
      status: '${j['windowStatus']}',
      opensOn: _date(j['opensOn']),
      deadline: _date(j['deadline']),
      total: _i(j['total']),
      notStarted: _i(j['notStarted']),
      draft: _i(j['draft']),
      submitted: _i(j['submitted']),
      closed: _i(j['closed']),
      teachers: (j['teachers'] as List? ?? []).whereType<Map>().map((e) {
        final r = Map<String, dynamic>.from(e);
        return TeacherReviewRow(
          teacherUserId: _i(r['teacherUserId']),
          name: '${r['teacherName']}',
          role: '${r['role']}'.replaceAll('_', ' '),
          status: '${r['status']}',
        );
      }).toList(),
    );
  }

  @override
  Future<TeacherReviewWindow> release(
    String s, {
    required int? actorUserId,
    required DateTime opensOn,
    required DateTime deadline,
  }) async => _window(
    _map(
      await _send(
        'POST',
        '/api/v2/teacher-term-reviews/school/$s/release',
        body: {
          'actorUserId': actorUserId,
          'opensOn': _ds(opensOn),
          'deadline': _ds(deadline),
        },
      ),
    ),
  );
  @override
  Future<TeacherReviewWindow> close(
    String s, {
    required int? actorUserId,
  }) async => _window(
    _map(
      await _send(
        'POST',
        '/api/v2/teacher-term-reviews/school/$s/close',
        body: {'actorUserId': actorUserId},
      ),
    ),
  );
  @override
  Future<TeacherTermReview> getTeacherReview(String s, int u) async => _review(
    _map(
      await _send('GET', '/api/v2/teacher-term-reviews/school/$s/teacher/$u'),
    ),
  );
  @override
  Future<TeacherTermReview> saveDraft(
    String s,
    int u,
    TeacherTermReviewInput i,
  ) => _save(s, u, 'draft', i);
  @override
  Future<TeacherTermReview> submit(String s, int u, TeacherTermReviewInput i) =>
      _save(s, u, 'submit', i);
  Future<TeacherTermReview> _save(
    String s,
    int u,
    String a,
    TeacherTermReviewInput i,
  ) async => _review(
    _map(
      await _send(
        'PUT',
        '/api/v2/teacher-term-reviews/school/$s/teacher/$u/$a',
        body: _body(i),
      ),
    ),
  );
  @override
  Future<TeacherTermReview> reopen(
    String s,
    int u, {
    required int? actorUserId,
    required String reason,
  }) async => _review(
    _map(
      await _send(
        'POST',
        '/api/v2/teacher-term-reviews/school/$s/teacher/$u/reopen',
        body: {'actorUserId': actorUserId, 'reason': reason},
      ),
    ),
  );
  Map<String, Object?> _body(TeacherTermReviewInput i) => {
    'reflection': i.reflection,
    'leadership': i.leadership,
    'recommendations': i.recommendations.map((e) => e.toJson()).toList(),
    'damageConfirmed': i.damageConfirmed,
    'recommendationsSubmitted': i.recommendationsSubmitted,
    'seriousConcern': i.seriousConcern,
    'seriousConcernDetails': i.seriousConcernDetails,
  };
  TeacherReviewWindow _window(Map<String, dynamic> j) => TeacherReviewWindow(
    termId: _i(j['termId']),
    status: '${j['windowStatus']}',
    opensOn: _date(j['opensOn']),
    deadline: _date(j['deadline']),
  );
  TeacherTermReview _review(Map<String, dynamic> j) => TeacherTermReview(
    termId: _i(j['termId']),
    status: '${j['windowStatus']}',
    opensOn: _date(j['opensOn']),
    deadline: _date(j['deadline']),
    reviewStatus: '${j['status']}',
    reflection: _sm(j['reflection']),
    leadership: _sm(j['leadership']),
    recommendations: (j['recommendations'] as List? ?? [])
        .whereType<Map>()
        .map(
          (e) => NextTermRecommendation.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList(),
    damageConfirmed: j['damageConfirmed'] == true,
    recommendationsSubmitted: j['recommendationsSubmitted'] == true,
    seriousConcern: j['seriousConcern'] == true,
    seriousConcernDetails: '${j['seriousConcernDetails'] ?? ''}',
    assessmentIncompleteCount: _i(j['assessmentIncompleteCount']),
    evaluationIncompleteCount: _i(j['studentEvaluationsIncompleteCount']),
  );
  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    Future<http.Response> go() {
      final h = {
        'Content-Type': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      };
      final u = Uri.parse('${ApiConfig.baseUrl}$path');
      return method == 'POST'
          ? _client.post(u, headers: h, body: jsonEncode(body))
          : method == 'PUT'
          ? _client.put(u, headers: h, body: jsonEncode(body))
          : _client.get(u, headers: h);
    }

    var r = await go();
    if ((r.statusCode == 401 || r.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      r = await go();
    }
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(_error(r));
    return r;
  }

  Map<String, dynamic> _map(http.Response r) =>
      Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  Map<String, String> _sm(Object? o) =>
      (o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{}).map(
        (k, v) => MapEntry(k, '$v'),
      );
  String _error(http.Response r) {
    try {
      final j = jsonDecode(r.body);
      if (j is Map) return '${j['message'] ?? j['detail'] ?? j['error']}';
    } catch (_) {}
    return 'Unable to save teacher term review.';
  }

  int _i(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
  DateTime? _date(Object? v) {
    if (v == null) return null;
    if (v is List && v.length >= 3) {
      return DateTime(_i(v[0]), _i(v[1]), _i(v[2]));
    }
    return DateTime.tryParse('$v');
  }

  String _ds(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
