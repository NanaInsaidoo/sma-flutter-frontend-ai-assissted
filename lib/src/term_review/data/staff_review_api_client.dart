import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../domain/staff_review_models.dart';

class StaffReviewApiClient implements StaffReviewRepository {
  StaffReviewApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  @override
  Future<StaffReviewDashboardData> getDashboard(String schoolId) async {
    final json = _map(
      await _send(
        'GET',
        '/api/v2/staff-performance-reviews/school/$schoolId/dashboard',
      ),
    );
    return StaffReviewDashboardData(
      termId: _int(json['termId']) ?? 0,
      termName: '${json['termName'] ?? 'Current term'}',
      total: _int(json['total']) ?? 0,
      notStarted: _int(json['notStarted']) ?? 0,
      draft: _int(json['draft']) ?? 0,
      completed: _int(json['completed']) ?? 0,
      reviews: (json['reviews'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => _review(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  @override
  Future<StaffReview> getReview(String schoolId, String staffId) async =>
      _review(
        _map(
          await _send(
            'GET',
            '/api/v2/staff-performance-reviews/school/$schoolId/staff/$staffId',
          ),
        ),
      );

  @override
  Future<StaffReview> saveDraft(
    String schoolId,
    String staffId,
    StaffReviewInput input,
  ) async => _save(schoolId, staffId, 'draft', input);

  @override
  Future<StaffReview> complete(
    String schoolId,
    String staffId,
    StaffReviewInput input,
  ) async => _save(schoolId, staffId, 'complete', input);

  Future<StaffReview> _save(
    String schoolId,
    String staffId,
    String action,
    StaffReviewInput input,
  ) async {
    final response = await _send(
      'PUT',
      '/api/v2/staff-performance-reviews/school/$schoolId/staff/$staffId/$action',
      body: {
        'reviewerUserId': input.reviewerUserId,
        'ratings': input.ratings,
        'overallRating': input.overallRating,
        'strengths': input.strengths,
        'improvementAreas': input.improvementAreas,
        'trainingSupport': input.trainingSupport,
        'nextTermActions': input.nextTermActions,
        'formalFollowUp': input.formalFollowUp,
        'finalComments': input.finalComments,
      },
    );
    return _review(_map(response));
  }

  @override
  Future<StaffReview> reopen(
    String schoolId,
    String staffId, {
    required int? reviewerUserId,
    required String reason,
  }) async => _review(
    _map(
      await _send(
        'POST',
        '/api/v2/staff-performance-reviews/school/$schoolId/staff/$staffId/reopen',
        body: {'reviewerUserId': reviewerUserId, 'reason': reason},
      ),
    ),
  );

  StaffReview _review(Map<String, dynamic> json) => StaffReview(
    id: _int(json['id']),
    staffId: '${json['staffId'] ?? ''}',
    staffName: '${json['staffName'] ?? ''}',
    role: '${json['role'] ?? 'STAFF'}'.replaceAll('_', ' '),
    status: '${json['status'] ?? 'NOT_STARTED'}',
    ratings:
        (json['ratings'] is Map
                ? Map<String, dynamic>.from(json['ratings'])
                : const <String, dynamic>{})
            .map((key, value) => MapEntry(key, _int(value) ?? 0)),
    overallRating: _int(json['overallRating']),
    strengths: '${json['strengths'] ?? ''}',
    improvementAreas: '${json['improvementAreas'] ?? ''}',
    trainingSupport: '${json['trainingSupport'] ?? ''}',
    nextTermActions: '${json['nextTermActions'] ?? ''}',
    formalFollowUp: json['formalFollowUp'] == true,
    finalComments: '${json['finalComments'] ?? ''}',
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.tryParse('${json['updatedAt']}'),
  );

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
  }) async {
    Future<http.Response> go() {
      final headers = {
        'Content-Type': 'application/json',
        if (accessToken?.isNotEmpty == true)
          'Authorization': 'Bearer $accessToken',
      };
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      if (method == 'PUT') {
        return _client.put(uri, headers: headers, body: jsonEncode(body));
      }
      if (method == 'POST') {
        return _client.post(uri, headers: headers, body: jsonEncode(body));
      }
      return _client.get(uri, headers: headers);
    }

    var response = await go().timeout(const Duration(seconds: 20));
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      accessToken = await onRefreshAccessToken!();
      response = await go().timeout(const Duration(seconds: 20));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StaffReviewException(_error(response));
    }
    return response;
  }

  Map<String, dynamic> _map(http.Response response) {
    final value = jsonDecode(response.body);
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _error(http.Response response) {
    try {
      final v = jsonDecode(response.body);
      if (v is Map) return '${v['message'] ?? v['detail'] ?? v['error']}';
    } catch (_) {}
    return 'Unable to save staff review (${response.statusCode}).';
  }

  int? _int(Object? value) => value is int ? value : int.tryParse('$value');
}

class StaffReviewException implements Exception {
  const StaffReviewException(this.message);
  final String message;
  @override
  String toString() => message;
}
