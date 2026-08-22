import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/account_access/data/account_access_api_client.dart';
import 'package:school_management_app/src/account_access/presentation/account_recovery_screen.dart';
import 'package:school_management_app/src/auth/data/auth_api_client.dart';

void main() {
  testWidgets('recovery copy matches the selected recovery journey', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountRecoveryScreen(
          kind: AccountRecoveryKind.password,
          onBackToLogin: () {},
        ),
      ),
    );
    expect(
      find.textContaining('Enter the global username'),
      findsOneWidget,
    );
    expect(
      find.textContaining('registered phone to find eligible accounts'),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountRecoveryScreen(
          kind: AccountRecoveryKind.username,
          onBackToLogin: () {},
        ),
      ),
    );
    expect(
      find.textContaining('registered phone number to find eligible usernames'),
      findsOneWidget,
    );
  });

  test(
    'invitation verification sends only supplied optional evidence',
    () async {
      late http.Request captured;
      final api = AccountAccessApiClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'activationSession': 'proof-session',
              'accountType': 'GUARDIAN',
              'schoolName': 'Horizon Academy',
              'possibleAccounts': [],
              'usernameSuggestions': ['ama.mensah'],
            }),
            200,
          );
        }),
      );

      final result = await api.verifyInvitation(
        token: 'invite-token',
        code: '123456',
        firstName: 'Ama',
        lastName: 'Mensah',
        dateOfBirth: '',
        email: '',
      );

      expect(
        captured.url.path,
        contains('/account-access/invitations/invite-token/verify'),
      );
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body, containsPair('code', '123456'));
      expect(body, isNot(contains('dateOfBirth')));
      expect(body, isNot(contains('email')));
      expect(result.usernameSuggestions, ['ama.mensah']);
    },
  );

  test('activation records the explicit account decision', () async {
    late http.Request captured;
    final api = AccountAccessApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'username': 'ama.separate', 'message': 'Account ready.'}),
          200,
        );
      }),
    );

    await api.activate(
      token: 'invite-token',
      activationSession: 'session',
      decision: 'NOT_MINE',
      username: 'ama.separate',
      password: 'SecurePass10',
    );

    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['decision'], 'NOT_MINE');
    expect(body['activationSession'], 'session');
    expect(body['existingUsername'], isNull);
  });

  test('forgot username and password use different identifiers', () async {
    final requests = <http.Request>[];
    final api = AccountAccessApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'challengeId': 'challenge-${requests.length}',
            'maskedDestination': '***0001',
            'message': 'If eligible, a code was sent.',
            'testingCode': '456789',
          }),
          200,
        );
      }),
    );

    await api.startUsernameRecovery('+233245550001');
    await api.startPasswordReset('ama.staff');

    expect(jsonDecode(requests[0].body), {'phoneNumber': '+233245550001'});
    expect(jsonDecode(requests[1].body), {'username': 'ama.staff'});
  });

  test(
    'normal login sends username only and never a school selector',
    () async {
      late http.Request captured;
      final api = AuthApiClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'accessToken': 'access',
              'refreshToken': 'refresh',
              'userId': 1,
              'userName': 'ama.staff',
              'role': 'SUBJECT_TEACHER',
              'roles': ['SUBJECT_TEACHER'],
              'firstName': 'Ama',
              'lastName': 'Mensah',
              'schoolMemberships': [],
            }),
            200,
          );
        }),
      );

      await api.login(identifier: ' Ama.Staff ', password: 'SecurePass10');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['userName'], 'Ama.Staff');
      expect(body['password'], 'SecurePass10');
      expect(body, isNot(contains('email')));
      expect(body, isNot(contains('phoneNumber')));
      expect(body, isNot(contains('schoolId')));
    },
  );
}
