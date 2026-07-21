import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class StaffApiClient {
  StaffApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<List<StaffLookupOption>> getDepartments(String customSchoolId) async {
    final response = await _send('GET', '/api/lookup/departments');
    return _decodeList(response).map(StaffLookupOption.fromJson).toList();
  }

  Future<List<StaffLookupOption>> getEmploymentStatuses() async {
    final response = await _send('GET', '/api/lookup/employment-statuses');
    return _decodeList(response).map(StaffLookupOption.fromJson).toList();
  }

  Future<List<StaffUserRecord>> getSchoolStaffUsers({
    required String customSchoolId,
    int page = 0,
    int size = 100,
  }) async {
    final query = Uri(
      queryParameters: {'page': page.toString(), 'size': size.toString()},
    ).query;
    final response = await _send(
      'GET',
      '/api/user-management/schools/$customSchoolId/users?$query',
    );
    return _decodeList(response)
        .map(StaffUserRecord.fromJson)
        .where((user) => user.userType.toUpperCase() == 'STAFF')
        .toList();
  }

  Future<CreatedSchoolUser> createSchoolUser({
    required String customSchoolId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'POST',
      '/api/user-management/schools/$customSchoolId/users',
      body: body,
    );
    return CreatedSchoolUser.fromJson(_decodeMap(response));
  }

  Future<StaffOnboardingResult> initiateOnboarding({
    required Map<String, dynamic> body,
  }) async {
    final response = await _send(
      'POST',
      '/api/v1/staff-management/initiate-onboarding',
      body: body,
    );
    return StaffOnboardingResult.fromJson(_decodeMap(response));
  }

  Future<void> createFinance({
    required String staffId,
    required Map<String, dynamic> body,
  }) async {
    await _send(
      'POST',
      '/api/v1/staff-management/$staffId/finance',
      body: body,
    );
  }

  Future<void> uploadResume({
    required String staffId,
    required List<int> bytes,
    required String fileName,
  }) async {
    await _sendMultipart(
      '/api/v1/staff-management/$staffId/documents/resume',
      fields: const {'documentType': 'RESUME'},
      fileBytes: bytes,
      fileName: fileName,
    );
  }

  Future<void> createEmploymentReference({
    required String staffId,
    required Map<String, dynamic> body,
  }) async {
    await _send(
      'POST',
      '/api/v1/staff-management/$staffId/employment-reference',
      body: body,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const StaffApiException('Please sign in again to continue.');
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
      }.timeout(const Duration(seconds: 20));
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
      throw StaffApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const StaffApiException(
        'The staff request took too long. Please try again.',
      );
    } on StaffApiException {
      rethrow;
    } catch (_) {
      throw const StaffApiException(
        'Unable to reach the staff service right now.',
      );
    }
  }

  Future<http.Response> _sendMultipart(
    String path, {
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const StaffApiException('Please sign in again to continue.');
    }

    Future<http.StreamedResponse> send() {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      request.headers['Authorization'] = 'Bearer $accessToken';
      request.fields.addAll(fields);
      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );
      return _client.send(request).timeout(const Duration(seconds: 30));
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
      throw StaffApiException(_messageFromResponse(response));
    } on TimeoutException {
      throw const StaffApiException(
        'The resume upload took too long. Please try again.',
      );
    } on StaffApiException {
      rethrow;
    } catch (_) {
      throw const StaffApiException('Unable to upload the resume right now.');
    }
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

  List<dynamic> _decodeList(http.Response response) =>
      _extractList(_decode(response));

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final value =
          decoded['content'] ??
          decoded['users'] ??
          decoded['data'] ??
          decoded['items'] ??
          decoded['results'];
      if (value is List) return value;
      if (value is Map<String, dynamic>) {
        final nested =
            value['content'] ??
            value['users'] ??
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
      404 => 'The staff endpoint could not be found.',
      >= 500 => 'The staff service is having trouble. Please try again later.',
      _ => 'Could not complete the staff request. Please try again.',
    };
  }
}

class StaffUserRecord {
  const StaffUserRecord({
    required this.id,
    required this.userName,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.userType,
    required this.role,
    required this.accountStatus,
    required this.mustChangePassword,
    required this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String dateOfBirth;
  final String userType;
  final String role;
  final String accountStatus;
  final bool mustChangePassword;
  final String lastLoginAt;
  final String createdAt;
  final String updatedAt;

  factory StaffUserRecord.fromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return StaffUserRecord(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      userName: (json['userName'] ?? json['username'] ?? '').toString(),
      firstName: (json['firstName'] ?? '').toString(),
      middleName: (json['middleName'] ?? '').toString(),
      lastName: (json['lastName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? json['phone'] ?? '').toString(),
      dateOfBirth: (json['dateOfBirth'] ?? '').toString(),
      userType: (json['userType'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      accountStatus: (json['accountStatus'] ?? json['status'] ?? '').toString(),
      mustChangePassword: json['mustChangePassword'] == true,
      lastLoginAt: (json['lastLoginAt'] ?? json['lastActive'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}

class StaffLookupOption {
  const StaffLookupOption({required this.id, required this.name});

  final String id;
  final String name;

  factory StaffLookupOption.fromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final rawId =
        json['id'] ??
        json['departmentId'] ??
        json['employmentStatusId'] ??
        json['value'];
    final rawName =
        json['name'] ??
        json['departmentName'] ??
        json['status'] ??
        json['statusName'] ??
        json['label'] ??
        json['description'];
    return StaffLookupOption(
      id: rawId?.toString() ?? '',
      name: rawName?.toString() ?? '',
    );
  }
}

class CreatedSchoolUser {
  const CreatedSchoolUser({
    required this.userId,
    required this.username,
    this.temporaryPassword,
  });

  final String userId;
  final String username;
  final String? temporaryPassword;

  factory CreatedSchoolUser.fromJson(Map<String, dynamic> json) {
    return CreatedSchoolUser(
      userId: (json['userId'] ?? json['id'] ?? '').toString(),
      username: (json['username'] ?? json['userName'] ?? '').toString(),
      temporaryPassword: json['temporaryPassword']?.toString(),
    );
  }
}

class StaffOnboardingResult {
  const StaffOnboardingResult({required this.staffId});

  final String staffId;

  factory StaffOnboardingResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final source = data is Map<String, dynamic> ? data : json;
    return StaffOnboardingResult(
      staffId:
          (source['staffId'] ?? source['id'] ?? source['customStaffId'] ?? '')
              .toString(),
    );
  }
}

class StaffApiException implements Exception {
  const StaffApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
