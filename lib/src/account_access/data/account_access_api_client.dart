import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class AccountAccessApiClient {
  AccountAccessApiClient({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const baseUrl = ApiConfig.baseUrl;

  Future<InvitationSummary> invitation(String token) async =>
      InvitationSummary.fromJson(
        await _get('/api/account-access/invitations/$token'),
      );

  Future<InvitationSummary> resendCode(String token) async =>
      InvitationSummary.fromJson(
        await _post('/api/account-access/invitations/$token/resend-code', {}),
      );

  Future<void> dispute(String token) async {
    await _post('/api/account-access/invitations/$token/not-me', {});
  }

  Future<VerifiedInvitation> verifyInvitation({
    required String token,
    required String code,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? email,
  }) async => VerifiedInvitation.fromJson(
    await _post('/api/account-access/invitations/$token/verify', {
      'code': code,
      'firstName': firstName,
      'lastName': lastName,
      if (dateOfBirth?.isNotEmpty ?? false) 'dateOfBirth': dateOfBirth,
      if (email?.isNotEmpty ?? false) 'email': email,
    }),
  );

  Future<ActivationResult> activate({
    required String token,
    required String activationSession,
    required String decision,
    String? username,
    String? password,
    String? existingUsername,
    String? existingPassword,
  }) async => ActivationResult.fromJson(
    await _post('/api/account-access/invitations/$token/activate', {
      'activationSession': activationSession,
      'decision': decision,
      if (username?.isNotEmpty ?? false) 'username': username,
      if (password?.isNotEmpty ?? false) 'password': password,
      if (existingUsername?.isNotEmpty ?? false)
        'existingUsername': existingUsername,
      if (existingPassword?.isNotEmpty ?? false)
        'existingPassword': existingPassword,
    }),
  );

  Future<bool> usernameAvailable(String username) async {
    final value = Uri.encodeComponent(username.trim());
    final json = await _get('/api/account-access/usernames/$value/available');
    return json['available'] == true;
  }

  Future<ChallengeStarted> startUsernameRecovery(String phone) async =>
      ChallengeStarted.fromJson(
        await _post('/api/account-access/recovery/usernames/start', {
          'phoneNumber': phone,
        }),
      );

  Future<ChallengeStarted> startPasswordReset(String username) async =>
      ChallengeStarted.fromJson(
        await _post('/api/account-access/recovery/password/start', {
          'username': username,
        }),
      );

  Future<RecoveryVerified> verifyRecovery({
    required String challengeId,
    required String code,
    required String firstName,
    required String lastName,
    String? dateOfBirth,
    String? email,
  }) async => RecoveryVerified.fromJson(
    await _post('/api/account-access/recovery/$challengeId/verify', {
      'code': code,
      'firstName': firstName,
      'lastName': lastName,
      if (dateOfBirth?.isNotEmpty ?? false) 'dateOfBirth': dateOfBirth,
      if (email?.isNotEmpty ?? false) 'email': email,
    }),
  );

  Future<void> resetPassword({
    required String challengeId,
    required String proofToken,
    required String newPassword,
  }) async {
    await _post('/api/account-access/recovery/$challengeId/reset-password', {
      'proofToken': proofToken,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } on TimeoutException {
      throw const AccountAccessException('The request timed out. Try again.');
    } on AccountAccessException {
      rethrow;
    } catch (_) {
      throw const AccountAccessException('Unable to reach SMA right now.');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } on TimeoutException {
      throw const AccountAccessException('The request timed out. Try again.');
    } on AccountAccessException {
      rethrow;
    } catch (_) {
      throw const AccountAccessException('Unable to reach SMA right now.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json = {};
    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final message = ['message', 'detail', 'error']
        .map((key) => json[key])
        .whereType<String>()
        .firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => 'Something went wrong. Please try again.',
        );
    throw AccountAccessException(message, response.statusCode);
  }
}

class InvitationSummary {
  const InvitationSummary({
    required this.token,
    required this.schoolName,
    required this.accountType,
    required this.dateOfBirthRequired,
    required this.emailRequired,
    required this.deliveryChannel,
    required this.maskedDestination,
    required this.status,
    required this.message,
    this.testingCode,
  });
  factory InvitationSummary.fromJson(Map<String, dynamic> json) =>
      InvitationSummary(
        token: json['token']?.toString() ?? '',
        schoolName: json['schoolName']?.toString() ?? 'Your school',
        accountType: json['accountType']?.toString() ?? '',
        dateOfBirthRequired: json['dateOfBirthRequired'] == true,
        emailRequired: json['emailRequired'] == true,
        deliveryChannel: json['deliveryChannel']?.toString() ?? 'EMAIL',
        maskedDestination: json['maskedDestination']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        testingCode: json['testingCode']?.toString(),
      );
  final String token;
  final String schoolName;
  final String accountType;
  final bool dateOfBirthRequired;
  final bool emailRequired;
  final String deliveryChannel;
  final String maskedDestination;
  final String status;
  final String message;
  final String? testingCode;
}

class CandidateAccount {
  const CandidateAccount({
    required this.accountType,
    required this.maskedUsername,
    required this.schoolLabel,
    required this.explanation,
  });
  factory CandidateAccount.fromJson(Map<String, dynamic> json) =>
      CandidateAccount(
        accountType: json['accountType']?.toString() ?? '',
        maskedUsername: json['maskedUsername']?.toString() ?? '',
        schoolLabel: json['schoolLabel']?.toString() ?? '',
        explanation: json['explanation']?.toString() ?? '',
      );
  final String accountType;
  final String maskedUsername;
  final String schoolLabel;
  final String explanation;
}

class VerifiedInvitation {
  const VerifiedInvitation({
    required this.activationSession,
    required this.accountType,
    required this.schoolName,
    required this.possibleAccounts,
    required this.usernameSuggestions,
  });
  factory VerifiedInvitation.fromJson(Map<String, dynamic> json) =>
      VerifiedInvitation(
        activationSession: json['activationSession']?.toString() ?? '',
        accountType: json['accountType']?.toString() ?? '',
        schoolName: json['schoolName']?.toString() ?? '',
        possibleAccounts: (json['possibleAccounts'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (value) =>
                  CandidateAccount.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList(),
        usernameSuggestions: (json['usernameSuggestions'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
      );
  final String activationSession;
  final String accountType;
  final String schoolName;
  final List<CandidateAccount> possibleAccounts;
  final List<String> usernameSuggestions;
}

class ActivationResult {
  const ActivationResult({required this.username, required this.message});
  factory ActivationResult.fromJson(Map<String, dynamic> json) =>
      ActivationResult(
        username: json['username']?.toString() ?? '',
        message: json['message']?.toString() ?? 'Account ready.',
      );
  final String username;
  final String message;
}

class ChallengeStarted {
  const ChallengeStarted({
    required this.challengeId,
    required this.deliveryChannel,
    required this.maskedDestination,
    required this.message,
    this.testingCode,
  });
  factory ChallengeStarted.fromJson(Map<String, dynamic> json) =>
      ChallengeStarted(
        challengeId: json['challengeId']?.toString() ?? '',
        deliveryChannel: json['deliveryChannel']?.toString() ?? 'EMAIL',
        maskedDestination: json['maskedDestination']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        testingCode: json['testingCode']?.toString(),
      );
  final String challengeId;
  final String deliveryChannel;
  final String maskedDestination;
  final String message;
  final String? testingCode;
}

class RecoveredAccount {
  const RecoveredAccount({
    required this.accountType,
    required this.username,
    required this.schoolLabel,
  });
  factory RecoveredAccount.fromJson(Map<String, dynamic> json) =>
      RecoveredAccount(
        accountType: json['accountType']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        schoolLabel: json['schoolLabel']?.toString() ?? '',
      );
  final String accountType;
  final String username;
  final String schoolLabel;
}

class RecoveryVerified {
  const RecoveryVerified({
    required this.proofToken,
    required this.accounts,
    required this.message,
  });
  factory RecoveryVerified.fromJson(Map<String, dynamic> json) =>
      RecoveryVerified(
        proofToken: json['proofToken']?.toString() ?? '',
        accounts: (json['accounts'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (value) =>
                  RecoveredAccount.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList(),
        message: json['message']?.toString() ?? '',
      );
  final String proofToken;
  final List<RecoveredAccount> accounts;
  final String message;
}

class AccountAccessException implements Exception {
  const AccountAccessException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
}
