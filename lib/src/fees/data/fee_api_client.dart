import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/fee_models.dart';

class FeeApiClient {
  FeeApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<FeeSummary> getFeesWithStats(String customSchoolId) async {
    final response = await _send('GET', '/fees/school/$customSchoolId/stats');
    return FeeSummary.fromJson(_decodeMap(response));
  }

  Future<FeeSummary> getFeesByGradeWithStats({
    required String customSchoolId,
    required int gradeLevelId,
  }) async {
    final response = await _send(
      'GET',
      '/fees/school/$customSchoolId/grade/$gradeLevelId/stats',
    );
    return FeeSummary.fromJson(_decodeMap(response));
  }

  Future<List<FeeCategory>> getFeeCategories() async {
    final response = await _send('GET', '/fees/categories');
    return _decodeList(response)
        .whereType<Map<String, dynamic>>()
        .map(FeeCategory.fromJson)
        .where((category) => category.id > 0 && category.name.trim().isNotEmpty)
        .toList();
  }

  Future<List<FeeGradeLevel>> getSchoolGradeLevels(
    String customSchoolId,
  ) async {
    final response = await _send(
      'GET',
      '/api/grade-levels/school/$customSchoolId',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(FeeGradeLevel.fromJson)
        .where((grade) => grade.id > 0 && grade.name.trim().isNotEmpty)
        .toList();
  }

  Future<CurrentAcademicTerm> getCurrentTerm(String customSchoolId) async {
    final response = await _send('GET', '/api/v1/current-term/$customSchoolId');
    return CurrentAcademicTerm.fromJson(_decodeMap(response));
  }

  Future<List<FeeStudent>> getStudents(String customSchoolId) async {
    final response = await _send(
      'GET',
      '/api/schools/$customSchoolId/students?statuses=ACTIVE&page=0&size=500',
    );
    return _extractList(_decode(response))
        .whereType<Map<String, dynamic>>()
        .map(FeeStudent.fromJson)
        .where((student) => student.customStudentId.trim().isNotEmpty)
        .toList();
  }

  Future<List<FeeAdjustment>> getFeeAdjustments({
    required String customSchoolId,
    required int termId,
  }) async {
    final response = await _send(
      'GET',
      '/api/schools/$customSchoolId/fee-adjustments?termId=$termId',
    );
    return _extractList(
      _decode(response),
    ).whereType<Map<String, dynamic>>().map(FeeAdjustment.fromJson).toList();
  }

  Future<FeeManagementOverview> getFeeManagementOverview({
    required String customSchoolId,
    int? termId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/fee-management/overview', {
        if (termId != null && termId > 0) 'termId': '$termId',
      }),
    );
    return FeeManagementOverview.fromJson(_decodeMap(response));
  }

  Future<FeeStudentFeesPage> getFeeManagementStudents({
    required String customSchoolId,
    int? termId,
    int? gradeLevelId,
    String? paymentStatus,
    String? search,
    int page = 0,
    int size = 50,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/fee-management/students', {
        if (termId != null && termId > 0) 'termId': '$termId',
        if (gradeLevelId != null && gradeLevelId > 0)
          'gradeLevelId': '$gradeLevelId',
        if (paymentStatus != null && paymentStatus.trim().isNotEmpty)
          'paymentStatus': paymentStatus.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': '$page',
        'size': '$size',
      }),
    );
    return FeeStudentFeesPage.fromJson(_decodeMap(response));
  }

  Future<List<FeeClassCollectionSummary>> getFeeManagementClasses({
    required String customSchoolId,
    int? termId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/fee-management/classes', {
        if (termId != null && termId > 0) 'termId': '$termId',
      }),
    );
    return _decodeList(response)
        .whereType<Map<String, dynamic>>()
        .map(FeeClassCollectionSummary.fromJson)
        .toList();
  }

  Future<List<FeeClassStructure>> getFeeStructuresForTerm({
    required String customSchoolId,
    int? termId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/fee-management/fee-structures', {
        if (termId != null && termId > 0) 'termId': '$termId',
      }),
    );
    return _decodeList(response)
        .whereType<Map<String, dynamic>>()
        .map(FeeClassStructure.fromJson)
        .toList();
  }

  Future<FeeClassStructure> saveFeeStructure({
    required String customSchoolId,
    required int gradeLevelId,
    required int termId,
    required List<FeeStructureItem> feeItems,
  }) async {
    final response = await _send(
      'PUT',
      '/api/schools/$customSchoolId/fee-management/fee-structures/$gradeLevelId',
      body: {
        'termId': termId,
        'feeItems': feeItems.map((item) => item.toJson()).toList(),
      },
    );
    return FeeClassStructure.fromJson(_decodeMap(response));
  }

  Future<List<FeeStudentFeeRow>> getFeeManagementArrears({
    required String customSchoolId,
    int? termId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/fee-management/arrears', {
        if (termId != null && termId > 0) 'termId': '$termId',
      }),
    );
    return _decodeList(
      response,
    ).whereType<Map<String, dynamic>>().map(FeeStudentFeeRow.fromJson).toList();
  }

  Future<List<FeeWaiverSummary>> getFeeManagementWaivers({
    required String customSchoolId,
    int? termId,
  }) async {
    final response = await _send(
      'GET',
      _withQuery('/api/schools/$customSchoolId/fee-management/waivers', {
        if (termId != null && termId > 0) 'termId': '$termId',
      }),
    );
    return _decodeList(
      response,
    ).whereType<Map<String, dynamic>>().map(FeeWaiverSummary.fromJson).toList();
  }

  Future<List<FeePaymentMethod>> getPaymentMethods() async {
    final response = await _send('GET', '/api/lookup/payment-methods');
    return _decodeList(response)
        .whereType<Map<String, dynamic>>()
        .map(FeePaymentMethod.fromJson)
        .where((method) => method.id > 0 && method.method.trim().isNotEmpty)
        .toList();
  }

  Future<FeePaymentReceipt> recordPayment(FeePaymentRequest request) async {
    final response = await _sendMultipart('/api/payments', {
      'customStudentId': request.customStudentId,
      'customSchoolId': request.customSchoolId,
      'payerName': request.payerName,
      'amount': request.amount.toStringAsFixed(2),
      'paymentDate': _dateTimeValue(request.paymentDate),
      'paymentMethodId': '${request.paymentMethodId}',
      'referenceNumber': request.referenceNumber,
      'receivedBy': request.receivedBy,
      'description': request.description,
      'termId': '${request.termId}',
      'receipts[0].receiptNumber': request.physicalReceiptNumber,
    });
    return FeePaymentReceipt.fromJson(_decodeMap(response));
  }

  Future<List<FeeStudentPayment>> getStudentPayments({
    required String customStudentId,
    int? termId,
  }) async {
    final path = termId != null && termId > 0
        ? '/api/payments/student/$customStudentId/term/$termId'
        : '/api/payments/student/$customStudentId';
    final response = await _send('GET', path);
    return _decodeList(response)
        .whereType<Map<String, dynamic>>()
        .map(FeeStudentPayment.fromJson)
        .toList();
  }

  Future<SchoolFee> createFee(FeeSaveRequest request) async {
    final response = await _send('POST', '/fees', body: request.toJson());
    return SchoolFee.fromJson(_decodeMap(response));
  }

  Future<SchoolFee> updateFee(int feeId, FeeSaveRequest request) async {
    final response = await _send('PUT', '/fees/$feeId', body: request.toJson());
    return SchoolFee.fromJson(_decodeMap(response));
  }

  Future<void> deleteFee({
    required int feeId,
    required String customSchoolId,
    required int gradeLevelId,
  }) async {
    await _send(
      'DELETE',
      '/fees/$feeId/school/$customSchoolId/grade/$gradeLevelId',
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const FeeApiException('Please sign in again to continue.');
    }

    Future<http.Response> send() {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final encodedBody = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encodedBody),
        'PUT' => _client.put(uri, headers: headers, body: encodedBody),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 15));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final nextToken = await onRefreshAccessToken!.call();
        if (nextToken != null && nextToken.isNotEmpty) {
          accessToken = nextToken;
          response = await send();
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw FeeApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const FeeApiException(
        'The fee information took too long to load. Please try again.',
      );
    } on FeeApiException {
      rethrow;
    } catch (_) {
      throw const FeeApiException('Unable to reach the fee service right now.');
    }
  }

  Future<http.Response> _sendMultipart(
    String path,
    Map<String, String> fields,
  ) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const FeeApiException('Please sign in again to continue.');
    }

    Future<http.StreamedResponse> send() {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields.addAll(
        fields.map((key, value) => MapEntry(key, value.trim())),
      );
      return _client.send(request).timeout(const Duration(seconds: 20));
    }

    try {
      var streamed = await send();
      if ((streamed.statusCode == 401 || streamed.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final nextToken = await onRefreshAccessToken!.call();
        if (nextToken != null && nextToken.isNotEmpty) {
          accessToken = nextToken;
          streamed = await send();
        }
      }
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw FeeApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const FeeApiException(
        'The payment request took too long. Please try again.',
      );
    } on FeeApiException {
      rethrow;
    } catch (_) {
      throw const FeeApiException(
        'Unable to reach the payment service right now.',
      );
    }
  }

  String _withQuery(String path, Map<String, String> query) {
    if (query.isEmpty) return path;
    final uri = Uri(path: path, queryParameters: query);
    return uri.toString();
  }

  String _dateTimeValue(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}T${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }

  dynamic _decode(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return {};
    return jsonDecode(body);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = _decode(response);
    return _extractList(decoded);
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final value =
          decoded['content'] ??
          decoded['data'] ??
          decoded['items'] ??
          decoded['results'];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        final nested =
            value['content'] ??
            value['data'] ??
            value['items'] ??
            value['results'];
        if (nested is List) return nested;
      }
    }
    return const [];
  }

  String _messageFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'detail']) {
          final value = decoded[key];
          if (value is String && value.trim().isNotEmpty) return value;
        }
      }
    } catch (_) {
      // Use default below.
    }

    return switch (response.statusCode) {
      401 || 403 => 'Your session has expired. Please sign in again.',
      404 => 'The requested fee information could not be found.',
      >= 500 => 'The fee service is having trouble. Please try again later.',
      _ => 'Could not complete the fee request. Please try again.',
    };
  }
}

class FeeApiException implements Exception {
  const FeeApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
