import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../domain/guardian_portal_models.dart';

class GuardianPortalApiClient {
  GuardianPortalApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  Future<GuardianPortalSnapshot> dashboard() async =>
      GuardianPortalSnapshot.fromJson(
        _map(_decode(await _send('/api/v1/guardian-portal/me'))),
      );

  Future<GuardianFeeDetail> fees(
    String studentId,
  ) async => GuardianFeeDetail.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/fees',
        ),
      ),
    ),
  );

  Future<GuardianPaymentSubmission> submitPayment({
    required String studentId,
    required double amount,
    required String paymentMethod,
    required String idempotencyKey,
    String? mobileNetwork,
    String? mobileNumber,
    String? chequeNumber,
    String? bankName,
    String? note,
  }) async => GuardianPaymentSubmission.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/payments',
          method: 'POST',
          body: {
            'amount': amount,
            'paymentMethod': paymentMethod,
            'idempotencyKey': idempotencyKey,
            if (mobileNetwork != null) 'mobileNetwork': mobileNetwork,
            if (mobileNumber != null) 'mobileNumber': mobileNumber,
            if (chequeNumber != null) 'chequeNumber': chequeNumber,
            if (bankName != null) 'bankName': bankName,
            if (note != null) 'note': note,
          },
        ),
      ),
    ),
  );

  Future<GuardianChildDetails> childDetails(
    String studentId,
  ) async => GuardianChildDetails.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/details',
        ),
      ),
    ),
  );

  Future<GuardianAcademicData> academics(
    String studentId,
  ) async => GuardianAcademicData.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/academics',
        ),
      ),
    ),
  );

  Future<GuardianStudentRequirements> requirements(
    String studentId,
  ) async => GuardianStudentRequirements.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/requirements',
        ),
      ),
    ),
  );

  Future<GuardianProfile> profile() async => GuardianProfile.fromJson(
    _map(_decode(await _send('/api/v1/guardian-portal/profile'))),
  );

  Future<GuardianProfile> updateProfile({
    required String email,
    required String phoneNumber,
    required String residentialAddress,
    required List<String> occupations,
    required bool emailNotifications,
    required bool smsNotifications,
  }) async => GuardianProfile.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/profile',
          method: 'PUT',
          body: {
            'email': email,
            'phoneNumber': phoneNumber,
            'residentialAddress': residentialAddress,
            'occupations': occupations,
            'emailNotifications': emailNotifications,
            'smsNotifications': smsNotifications,
          },
        ),
      ),
    ),
  );

  Future<List<HouseholdGuardian>> householdGuardians() async =>
      _list(_decode(await _send('/api/v1/guardian-portal/household/guardians')))
          .map((item) => HouseholdGuardian.fromJson(_map(item)))
          .toList(growable: false);

  Future<HouseholdGuardian> blockGuardian(
    String guardianId,
    String reason,
  ) async => HouseholdGuardian.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/household/guardians/${Uri.encodeComponent(guardianId)}/block',
          method: 'POST',
          body: {'reason': reason},
        ),
      ),
    ),
  );

  Future<HouseholdGuardian> restoreGuardian(
    String guardianId,
  ) async => HouseholdGuardian.fromJson(
    _map(
      _decode(
        await _send(
          '/api/v1/guardian-portal/household/guardians/${Uri.encodeComponent(guardianId)}/restore',
          method: 'POST',
        ),
      ),
    ),
  );

  Future<List<GuardianAttendanceItem>> attendance(
    String studentId,
  ) async => _list(
    _decode(
      await _send(
        '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/attendance',
      ),
    ),
  ).map((item) => GuardianAttendanceItem.fromJson(_map(item))).toList(growable: false);

  Future<List<GuardianReportItem>> reports(String studentId) async => _list(
    _decode(
      await _send(
        '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/reports',
      ),
    ),
  ).map((item) => GuardianReportItem.fromJson(_map(item))).toList(growable: false);

  Future<List<int>> report({
    required String studentId,
    required int termId,
    required int academicYearId,
    bool download = false,
  }) async {
    final query = Uri(
      queryParameters: {
        'termId': '$termId',
        'academicYearId': '$academicYearId',
        'download': '$download',
      },
    ).query;
    final response = await _send(
      '/api/v1/guardian-portal/students/${Uri.encodeComponent(studentId)}/report?$query',
      accept: 'application/pdf',
    );
    if (response.bodyBytes.isEmpty) {
      throw const GuardianPortalException('The report could not be opened.');
    }
    return response.bodyBytes;
  }

  Future<http.Response> _send(
    String path, {
    String accept = 'application/json',
    String method = 'GET',
    Map<String, dynamic>? body,
    bool retry = true,
  }) async {
    try {
      final request =
          http.Request(method, Uri.parse('${ApiConfig.baseUrl}$path'))
            ..headers.addAll({
              'Accept': accept,
              if (body != null) 'Content-Type': 'application/json',
              if (accessToken != null && accessToken!.isNotEmpty)
                'Authorization': 'Bearer $accessToken',
            });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      if (response.statusCode == 401 && retry && onRefreshAccessToken != null) {
        accessToken = await onRefreshAccessToken!();
        if (accessToken != null && accessToken!.isNotEmpty) {
          return _send(
            path,
            accept: accept,
            method: method,
            body: body,
            retry: false,
          );
        }
      }
      throw GuardianPortalException(_message(response), response.statusCode);
    } on TimeoutException {
      throw const GuardianPortalException(
        'This is taking longer than expected. Please try again.',
      );
    } on GuardianPortalException {
      rethrow;
    } catch (_) {
      throw const GuardianPortalException(
        'We could not connect to the school right now. Please try again.',
      );
    }
  }

  Object? _decode(http.Response response) {
    if (response.body.trim().isEmpty) return const {};
    final value = jsonDecode(response.body);
    if (value is Map<String, dynamic> &&
        value.containsKey('data') &&
        value['data'] != null) {
      return value['data'];
    }
    return value;
  }

  String _message(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) {
        for (final key in ['message', 'error', 'detail']) {
          if (value[key] is String &&
              (value[key] as String).trim().isNotEmpty) {
            return value[key] as String;
          }
        }
      }
    } catch (_) {}
    return switch (response.statusCode) {
      401 => 'Please sign in again.',
      403 => 'This information is not available to your account.',
      404 => 'We could not find that information.',
      409 => 'This is not ready yet. Please check again later.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}

class GuardianPortalException implements Exception {
  const GuardianPortalException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<dynamic> _list(Object? value) => value is List ? value : const [];
