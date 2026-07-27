import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../config/api_config.dart';
import '../domain/expense_models.dart';

class ExpenseApiException implements Exception {
  const ExpenseApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ExpenseApiClient {
  ExpenseApiClient({
    this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<ExpenseReferenceData> getReferenceData() async {
    final results = await Future.wait([
      _getLookup('/api/v1/expenses/categories'),
      _getLookup('/api/v1/expenses/currencies'),
      _getLookup('/api/v1/expenses/payment-methods'),
      _getLookup('/api/v1/expenses/departments'),
      _getStatuses(),
    ]);
    return ExpenseReferenceData(
      categories: results[0],
      currencies: results[1],
      paymentMethods: results[2],
      departments: results[3],
      statuses: results[4],
    );
  }

  Future<ExpensePage> getExpenses({
    required String customSchoolId,
    int page = 0,
    int size = 100,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final trimmedStatus = status?.trim().toUpperCase();
    final path = trimmedStatus != null && trimmedStatus.isNotEmpty
        ? _withQuery('/api/v1/expenses/by-status', {
            'customSchoolId': customSchoolId,
            'status': trimmedStatus,
            'page': '$page',
            'size': '$size',
            'sort': 'date,desc',
          })
        : startDate != null && endDate != null
        ? _withQuery('/api/v1/expenses/by-date-range', {
            'customSchoolId': customSchoolId,
            'startDate': _dateOnlyValue(startDate),
            'endDate': _dateOnlyValue(endDate),
            'page': '$page',
            'size': '$size',
            'sort': 'date,desc',
          })
        : _withQuery('/api/v1/expenses', {
            'customSchoolId': customSchoolId,
            'page': '$page',
            'size': '$size',
            'sort': 'date,desc',
          });

    final response = await _send('GET', path);
    return ExpensePage.fromJson(_decode(response));
  }

  Future<ExpenseRecord> createExpense({
    required String customSchoolId,
    required Map<String, dynamic> expenseBody,
    Uint8List? documentBytes,
    String? documentName,
  }) async {
    final response = await _sendMultipart(
      '/api/v1/expenses',
      customSchoolId: customSchoolId,
      expenseBody: expenseBody,
      documentBytes: documentBytes,
      documentName: documentName,
    );
    return ExpenseRecord.fromJson(_decodeMap(response));
  }

  Future<ExpenseRecord> updateStatus({
    required String customSchoolId,
    required String expenseId,
    required String status,
    String? reason,
  }) async {
    final response = await _send(
      'PUT',
      _withQuery('/api/v1/expenses/$expenseId/status', {
        'customSchoolId': customSchoolId,
      }),
      body: {
        'status': status,
        if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
      },
    );
    return ExpenseRecord.fromJson(_decodeMap(response));
  }

  Future<void> deleteExpense({
    required String customSchoolId,
    required String expenseId,
  }) async {
    await _send(
      'DELETE',
      _withQuery('/api/v1/expenses/$expenseId', {
        'customSchoolId': customSchoolId,
      }),
    );
  }

  Future<List<ExpenseLookup>> _getLookup(String path) async {
    final response = await _send('GET', path);
    final decoded = _decode(response);
    final list = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? decoded['data']
        : null;
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => ExpenseLookup.fromJson(item.cast()))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  Future<List<ExpenseLookup>> _getStatuses() async {
    final response = await _send('GET', '/api/v1/expenses/statuses');
    final decoded = _decode(response);
    if (decoded is! List) return const [];
    return decoded
        .map((item) => ExpenseLookup.fromStatus('$item'))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const ExpenseApiException('Please sign in again to continue.');
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
      }.timeout(const Duration(seconds: 18));
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
      throw ExpenseApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const ExpenseApiException(
        'The expense request took too long. Please try again.',
      );
    } on ExpenseApiException {
      rethrow;
    } catch (_) {
      throw const ExpenseApiException(
        'Unable to reach the expense service right now.',
      );
    }
  }

  Future<http.Response> _sendMultipart(
    String path, {
    required String customSchoolId,
    required Map<String, dynamic> expenseBody,
    Uint8List? documentBytes,
    String? documentName,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const ExpenseApiException('Please sign in again to continue.');
    }

    Future<http.StreamedResponse> send() {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields['customSchoolId'] = customSchoolId;
      request.files.add(
        http.MultipartFile.fromString(
          'expenseDTO',
          jsonEncode(expenseBody),
          contentType: MediaType('application', 'json'),
        ),
      );
      if (documentBytes != null &&
          documentBytes.isNotEmpty &&
          documentName != null &&
          documentName.trim().isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'documents',
            documentBytes,
            filename: documentName.trim(),
          ),
        );
      }
      return _client.send(request).timeout(const Duration(seconds: 25));
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
      throw ExpenseApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const ExpenseApiException(
        'The expense upload took too long. Please try again.',
      );
    } on ExpenseApiException {
      rethrow;
    } catch (_) {
      throw const ExpenseApiException(
        'Unable to upload the expense right now.',
      );
    }
  }

  String _withQuery(String path, Map<String, String> query) {
    final clean = Map<String, String>.fromEntries(
      query.entries.where((entry) => entry.value.trim().isNotEmpty),
    );
    if (clean.isEmpty) return path;
    return Uri(path: path, queryParameters: clean).toString();
  }

  String _dateOnlyValue(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
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
      404 => 'The requested expense record could not be found.',
      >= 500 =>
        'The expense service is having trouble. Please try again later.',
      _ => 'Could not complete the expense request. Please try again.',
    };
  }
}
