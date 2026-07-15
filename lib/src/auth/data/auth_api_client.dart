import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class AuthApiClient {
  AuthApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = ApiConfig.baseUrl;

  final http.Client _client;

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _post('/api/auth/login', {
      ..._identifierPayload(identifier),
      'password': password,
    });

    return AuthSession.fromJson(_decode(response));
  }

  Future<AuthSession> refreshSession({required String refreshToken}) async {
    final response = await _post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
    return AuthSession.fromJson(_decode(response));
  }

  Future<PasswordResetStart> requestPasswordReset({
    required String identifier,
  }) async {
    final response = await _post(
      '/api/auth/forgot-password',
      _identifierPayload(identifier),
    );
    return PasswordResetStart.fromJson(_decode(response));
  }

  Future<void> verifyDobForReset({
    required String userName,
    required String dateOfBirth,
  }) async {
    await _post('/api/auth/verify-dob-for-reset', {
      'userName': userName,
      'dateOfBirth': dateOfBirth,
    });
  }

  Future<void> verifyOtp({
    required String userName,
    required String otp,
  }) async {
    await _post('/api/auth/verify-otp', {'userName': userName, 'otp': otp});
  }

  Future<void> resetPasswordWithOtp({
    required String userName,
    required String otp,
    required String newPassword,
    String? dateOfBirth,
  }) async {
    await _post('/api/auth/reset-password', {
      'userName': userName,
      'otp': otp,
      'newPassword': newPassword,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty)
        'dateOfBirth': dateOfBirth,
    });
  }

  Future<void> verifyDateOfBirth({
    required String accessToken,
    required String userName,
    required String dateOfBirth,
  }) async {
    await _post('/api/auth/verify-dob', {
      'userName': userName,
      'dateOfBirth': dateOfBirth,
    }, accessToken: accessToken);
  }

  Future<void> changePasswordAfterVerification({
    required String accessToken,
    required String userName,
    String? currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword != null && currentPassword.isNotEmpty) {
      await _post('/api/auth/change-password', {
        'userName': userName,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }, accessToken: accessToken);
      return;
    }

    await _post('/api/auth/change-password-after-verification', {
      'userName': userName,
      'newPassword': newPassword,
    }, accessToken: accessToken);
  }

  Future<http.Response> _post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (accessToken != null && accessToken.isNotEmpty)
                'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw AuthException(_messageFromResponse(response), response.statusCode);
    } on TimeoutException {
      throw const AuthException(
        'The request timed out. Please check your internet connection.',
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Unable to reach the server right now.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.trim().isEmpty) return {};
    final decoded = jsonDecode(response.body);
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
      // Fall through to friendly defaults below.
    }

    return switch (response.statusCode) {
      400 => 'Please check the details and try again.',
      401 || 403 => 'Invalid login details or account access denied.',
      404 => 'We could not find that account.',
      >= 500 => 'The server is having trouble. Please try again later.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  Map<String, dynamic> _identifierPayload(String rawIdentifier) {
    final identifier = rawIdentifier.trim();
    final digits = identifier.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) return {'phoneNumber': identifier};

    final normalized = identifier.toLowerCase();
    final looksLikeEmail =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier) &&
        !normalized.endsWith('@platform');
    if (looksLikeEmail) return {'email': identifier};

    return {'userName': identifier};
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.mustChangePassword,
    required this.requiresDateOfBirth,
    required this.isAccountManager,
    required this.role,
    required this.accountStatus,
    required this.userStatus,
    required this.customSchoolId,
    required this.schoolName,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String firstName;
  final String lastName;
  final String userName;
  final bool mustChangePassword;
  final bool requiresDateOfBirth;
  final bool isAccountManager;
  final String role;
  final String accountStatus;
  final String userStatus;
  final String customSchoolId;
  final String schoolName;
  final int userId;

  bool get isAccountManagerRole {
    final value = role.trim().toUpperCase();
    return isAccountManager ||
        value == 'ACCOUNT_MANAGER' ||
        value == 'SUPER_ACCOUNT_MANAGER' ||
        value == 'ACCOUNT_MANAGER_UNVERIFIED' ||
        value == 'ACCOUNT_MANAGER_VERIFIED_STAFF';
  }

  bool get isPendingAccountManagerApproval {
    if (!isAccountManagerRole) return false;
    final value = accountStatus.trim().toUpperCase();
    return value == 'PENDING_REVIEW' ||
        value == 'PENDING_APPROVAL' ||
        value == 'PENDING';
  }

  bool get isBlockedFromLogin {
    const blockedStatuses = {
      'SUSPENDED',
      'INACTIVE',
      'DELETED',
      'DISABLED',
      'REJECTED',
    };
    return blockedStatuses.contains(accountStatus.trim().toUpperCase()) ||
        blockedStatuses.contains(userStatus.trim().toUpperCase());
  }

  String get loginBlockMessage {
    final values = [
      accountStatus.trim().toUpperCase(),
      userStatus.trim().toUpperCase(),
    ];
    if (values.contains('SUSPENDED')) {
      return 'This account has been suspended. Please contact your administrator.';
    }
    if (values.contains('INACTIVE') || values.contains('DELETED')) {
      return 'This account is no longer active. Please contact your administrator.';
    }
    return 'This account cannot access the system. Please contact your administrator.';
  }

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? userName : name;
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final tokenClaims = _decodeJwtClaims(json['accessToken'] as String? ?? '');
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      userName:
          json['userName'] as String? ?? tokenClaims['sub'] as String? ?? '',
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      requiresDateOfBirth: json['requiresDateOfBirth'] as bool? ?? false,
      isAccountManager: json['isAccountManager'] as bool? ?? false,
      role:
          json['role'] as String? ??
          tokenClaims['role'] as String? ??
          tokenClaims['authorities'] as String? ??
          '',
      accountStatus:
          json['accountStatus'] as String? ?? '',
      userStatus: json['status'] as String? ?? json['userStatus'] as String? ?? '',
      customSchoolId:
          json['customSchoolId'] as String? ??
          json['tenantId'] as String? ??
          tokenClaims['tenantId'] as String? ??
          '',
      schoolName:
          json['schoolName'] as String? ??
          tokenClaims['schoolName'] as String? ??
          '',
      userId:
          _intValue(json['userId']) ?? _intValue(tokenClaims['userId']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'firstName': firstName,
    'lastName': lastName,
    'userName': userName,
    'mustChangePassword': mustChangePassword,
    'requiresDateOfBirth': requiresDateOfBirth,
    'isAccountManager': isAccountManager,
    'role': role,
    'accountStatus': accountStatus,
    'userStatus': userStatus,
    'customSchoolId': customSchoolId,
    'schoolName': schoolName,
    'userId': userId,
  };

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? firstName,
    String? lastName,
    String? userName,
    bool? mustChangePassword,
    bool? requiresDateOfBirth,
    bool? isAccountManager,
    String? role,
    String? accountStatus,
    String? userStatus,
    String? customSchoolId,
    String? schoolName,
    int? userId,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      userName: userName ?? this.userName,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      requiresDateOfBirth: requiresDateOfBirth ?? this.requiresDateOfBirth,
      isAccountManager: isAccountManager ?? this.isAccountManager,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      userStatus: userStatus ?? this.userStatus,
      customSchoolId: customSchoolId ?? this.customSchoolId,
      schoolName: schoolName ?? this.schoolName,
      userId: userId ?? this.userId,
    );
  }

  AuthSession mergeRefresh(AuthSession refreshed) {
    return AuthSession(
      accessToken: refreshed.accessToken.isEmpty
          ? accessToken
          : refreshed.accessToken,
      refreshToken: refreshed.refreshToken.isEmpty
          ? refreshToken
          : refreshed.refreshToken,
      firstName: refreshed.firstName.isEmpty ? firstName : refreshed.firstName,
      lastName: refreshed.lastName.isEmpty ? lastName : refreshed.lastName,
      userName: refreshed.userName.isEmpty ? userName : refreshed.userName,
      mustChangePassword: refreshed.mustChangePassword,
      requiresDateOfBirth: refreshed.requiresDateOfBirth,
      isAccountManager: refreshed.isAccountManager || isAccountManager,
      role: refreshed.role.isEmpty ? role : refreshed.role,
      accountStatus: refreshed.accountStatus.isEmpty
          ? accountStatus
          : refreshed.accountStatus,
      userStatus: refreshed.userStatus.isEmpty ? userStatus : refreshed.userStatus,
      customSchoolId: refreshed.customSchoolId.isEmpty
          ? customSchoolId
          : refreshed.customSchoolId,
      schoolName: refreshed.schoolName.isEmpty
          ? schoolName
          : refreshed.schoolName,
      userId: refreshed.userId == 0 ? userId : refreshed.userId,
    );
  }
}

Map<String, dynamic> _decodeJwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length < 2) return {};
  try {
    final payload = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(payload));
    final claims = jsonDecode(decoded);
    return claims is Map<String, dynamic> ? claims : {};
  } catch (_) {
    return {};
  }
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class PasswordResetStart {
  const PasswordResetStart({
    required this.userName,
    required this.requiresDateOfBirth,
    this.maskedEmail,
    this.maskedPhone,
  });

  final String userName;
  final bool requiresDateOfBirth;
  final String? maskedEmail;
  final String? maskedPhone;

  String get destination {
    if (maskedEmail != null && maskedEmail!.isNotEmpty) return maskedEmail!;
    if (maskedPhone != null && maskedPhone!.isNotEmpty) return maskedPhone!;
    return 'the contact on file';
  }

  factory PasswordResetStart.fromJson(Map<String, dynamic> json) {
    return PasswordResetStart(
      userName: json['userName'] as String? ?? '',
      requiresDateOfBirth: json['requiresDateOfBirth'] as bool? ?? false,
      maskedEmail: json['maskedEmail'] as String?,
      maskedPhone: json['maskedPhone'] as String?,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
