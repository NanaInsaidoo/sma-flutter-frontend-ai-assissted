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

  Future<List<StaffProfileRecord>> getSchoolStaffProfiles(
    String customSchoolId,
  ) async {
    final response = await _send(
      'GET',
      '/api/v1/staff-management/schools/$customSchoolId/profiles',
    );
    return _decodeList(response).map(StaffProfileRecord.fromJson).toList();
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

  Future<StaffUserRecord> updateSchoolUserRoles({
    required String customSchoolId,
    required String userId,
    required String primaryRole,
    required List<String> roles,
  }) async {
    final response = await _send(
      'PUT',
      '/api/user-management/schools/$customSchoolId/users/$userId',
      body: {'role': primaryRole, 'roles': roles},
    );
    return StaffUserRecord.fromJson(_decodeMap(response));
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
    required String customSchoolId,
    required String staffId,
    required List<int> bytes,
    required String fileName,
  }) async {
    final contentType = _resumeContentType(fileName);
    final requestResponse = await _send(
      'POST',
      '/api/schools/$customSchoolId/documents/upload-requests',
      body: {
        'fileName': fileName,
        'contentType': contentType,
        'fileSize': bytes.length,
        'documentType': 'RESUME',
        'description': 'Staff resume',
      },
    );
    final requestJson = _unwrapMap(_decodeMap(requestResponse));
    final documentId = _firstString(requestJson, const [
      'documentId',
      'documentID',
      'id',
    ]);
    final uploadUrl = _firstString(requestJson, const [
      'uploadUrl',
      'uploadURL',
      'presignedUrl',
      'presignedURL',
    ]);
    if (documentId.isEmpty || uploadUrl.isEmpty) {
      throw const StaffApiException(
        'The resume upload instructions were incomplete.',
      );
    }
    final uploadUri = Uri.tryParse(uploadUrl);
    if (uploadUri == null ||
        !uploadUri.hasQuery ||
        !uploadUri.queryParameters.keys.any(
          (key) => key.toLowerCase().startsWith('x-amz-'),
        )) {
      throw const StaffApiException(
        'The resume upload URL is not a valid presigned S3 URL.',
      );
    }
    late http.Response uploadResponse;
    try {
      uploadResponse = await _client
          .put(uploadUri, headers: {'Content-Type': contentType}, body: bytes)
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const StaffApiException(
        'S3 blocked the resume upload. Check bucket CORS and storage configuration.',
      );
    }
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw StaffApiException(
        'Resume upload failed with ${uploadResponse.statusCode}.',
      );
    }
    final eTag = (uploadResponse.headers['etag'] ?? '').replaceAll('"', '');
    if (eTag.isEmpty) {
      throw const StaffApiException(
        'S3 did not expose the resume upload ETag.',
      );
    }
    await _send(
      'POST',
      '/api/schools/$customSchoolId/documents/$documentId/confirm',
      body: {'eTag': eTag, 'fileSize': bytes.length},
    );
    await _send(
      'POST',
      '/api/v1/staff-management/$staffId/documents/resume/$documentId/attach',
      body: const {},
    );
  }

  String _resumeContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.rtf')) return 'application/rtf';
    return 'application/octet-stream';
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic> json) {
    final data = json['data'];
    return data is Map<String, dynamic> ? data : json;
  }

  String _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value'.trim();
    }
    return '';
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
    this.roles = const [],
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
  final List<String> roles;
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
      roles: _roleList(json['roles'], fallback: json['role']),
      accountStatus: (json['accountStatus'] ?? json['status'] ?? '').toString(),
      mustChangePassword: json['mustChangePassword'] == true,
      lastLoginAt: (json['lastLoginAt'] ?? json['lastActive'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
    );
  }
}

List<String> _roleList(dynamic value, {dynamic fallback}) {
  final roles = <String>{};
  if (fallback != null && fallback.toString().trim().isNotEmpty) {
    roles.add(fallback.toString().trim().toUpperCase());
  }
  if (value is List) {
    roles.addAll(
      value
          .map((item) => item.toString().trim().toUpperCase())
          .where((item) => item.isNotEmpty),
    );
  }
  return roles.toList(growable: false);
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

class StaffProfileRecord {
  const StaffProfileRecord({
    required this.staffId,
    required this.userId,
    required this.position,
    required this.departmentName,
    required this.employmentType,
    required this.startDate,
    required this.resumes,
  });

  final String staffId;
  final String userId;
  final String position;
  final String departmentName;
  final String employmentType;
  final String startDate;
  final List<StaffResumeRecord> resumes;

  factory StaffProfileRecord.fromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final resumeValues = json['resumeDocuments'];
    return StaffProfileRecord(
      staffId: (json['staffId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      departmentName: (json['departmentName'] ?? '').toString(),
      employmentType: (json['employmentType'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      resumes: resumeValues is List
          ? resumeValues.map(StaffResumeRecord.fromJson).toList()
          : const [],
    );
  }
}

class StaffResumeRecord {
  const StaffResumeRecord({
    required this.documentId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.status,
  });

  final String documentId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String status;

  factory StaffResumeRecord.fromJson(dynamic value) {
    final json = value is Map<String, dynamic> ? value : <String, dynamic>{};
    return StaffResumeRecord(
      documentId: (json['documentId'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      fileType: (json['fileType'] ?? '').toString(),
      fileSize: int.tryParse('${json['fileSize'] ?? 0}') ?? 0,
      status: (json['status'] ?? '').toString(),
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
  const StaffOnboardingResult({
    required this.staffId,
    required this.invitationToken,
    required this.invitationStatus,
    required this.invitationMaskedPhone,
  });

  final String staffId;
  final String invitationToken;
  final String invitationStatus;
  final String invitationMaskedPhone;

  factory StaffOnboardingResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final source = data is Map<String, dynamic> ? data : json;
    return StaffOnboardingResult(
      staffId:
          (source['staffId'] ?? source['id'] ?? source['customStaffId'] ?? '')
              .toString(),
      invitationToken: (source['invitationToken'] ?? '').toString(),
      invitationStatus: (source['invitationStatus'] ?? '').toString(),
      invitationMaskedPhone: (source['invitationMaskedPhone'] ?? '').toString(),
    );
  }
}

class StaffApiException implements Exception {
  const StaffApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
