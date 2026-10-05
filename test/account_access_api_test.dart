import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/account_access/data/account_access_api_client.dart';
import 'package:school_management_app/src/account_access/presentation/account_activation_screen.dart';
import 'package:school_management_app/src/account_access/presentation/account_recovery_screen.dart';
import 'package:school_management_app/src/auth/data/auth_api_client.dart';

void main() {
  testWidgets('invitation confirmation does not ask for the email again', (
    tester,
  ) async {
    final api = AccountAccessApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'token': 'invite-token',
            'schoolName': 'Akwaaba Learning Academy',
            'accountType': 'STAFF',
            'dateOfBirthRequired': true,
            'emailRequired': true,
            'deliveryChannel': 'EMAIL',
            'maskedDestination': 'n***@gma.com',
            'status': 'CODE_SENT',
            'message': 'Enter the code.',
          }),
          200,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountActivationScreen(
          token: 'invite-token',
          onGoToLogin: () {},
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm your invitation'), findsOneWidget);
    expect(find.text('Email given to the school'), findsNothing);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.byTooltip('Choose date of birth'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose date of birth'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Choose date of birth'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('invitation date of birth accepts and validates YYYY-MM-DD', (
    tester,
  ) async {
    http.Request? verificationRequest;
    final api = AccountAccessApiClient(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'token': 'invite-token',
              'schoolName': 'Akwaaba Learning Academy',
              'accountType': 'STAFF',
              'dateOfBirthRequired': true,
              'deliveryChannel': 'SMS',
              'maskedDestination': '***0001',
              'status': 'CODE_SENT',
              'message': 'Enter the code.',
            }),
            200,
          );
        }
        verificationRequest = request;
        return http.Response(
          jsonEncode({
            'activationSession': 'proof-session',
            'accountType': 'STAFF',
            'schoolName': 'Akwaaba Learning Academy',
            'possibleAccounts': [],
            'usernameSuggestions': [],
            'assignedUsername': 'ama.mensah@akwaaba',
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountActivationScreen(
          token: 'invite-token',
          onGoToLogin: () {},
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'Ama');
    await tester.enterText(fields.at(2), 'Mensah');
    await tester.enterText(fields.at(3), '2000-02-30');
    await tester.tap(find.text('Verify invitation'));
    await tester.pump();

    expect(find.text('Enter a valid date as YYYY-MM-DD'), findsOneWidget);
    expect(verificationRequest, isNull);

    await tester.enterText(fields.at(3), '1990-05-12');
    await tester.tap(find.text('Verify invitation'));
    await tester.pumpAndSettle();

    expect(verificationRequest, isNotNull);
    final body = jsonDecode(verificationRequest!.body) as Map<String, dynamic>;
    expect(body['dateOfBirth'], '1990-05-12');
    expect(find.text('Set up your access'), findsOneWidget);
  });

  testWidgets('staff activation never presents inferred account matches', (
    tester,
  ) async {
    http.Request? activationRequest;
    final api = AccountAccessApiClient(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'token': 'invite-token',
              'schoolName': 'Akwaaba Learning Academy',
              'accountType': 'STAFF',
              'dateOfBirthRequired': false,
              'deliveryChannel': 'SMS',
              'maskedDestination': '***0001',
              'status': 'CODE_SENT',
              'message': 'Enter the code.',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/activate')) {
          activationRequest = request;
          return http.Response(
            jsonEncode({
              'username': 'kofi.kego@akwaaba',
              'message': 'Your staff account is ready.',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'activationSession': 'proof-session',
            'accountType': 'STAFF',
            'schoolName': 'Akwaaba Learning Academy',
            'possibleAccounts': [
              {
                'proofId': 'untrusted-match',
                'accountType': 'STAFF',
                'maskedUsername': 'to***i',
                'schoolLabel': 'Akwaaba Learning Academy',
                'explanation': 'A possible account was found.',
              },
            ],
            'usernameSuggestions': [],
            'assignedUsername': 'kofi.kego@akwaaba',
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AccountActivationScreen(
          token: 'invite-token',
          onGoToLogin: () {},
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '123456');
    await tester.enterText(fields.at(1), 'Kofi');
    await tester.enterText(fields.at(2), 'Kego');
    await tester.tap(find.text('Verify invitation'));
    await tester.pumpAndSettle();

    expect(find.text('Possible existing access'), findsNothing);
    expect(find.textContaining('to***i'), findsNothing);
    expect(find.text('Decide later'), findsNothing);
    expect(find.text('None of these accounts is mine'), findsNothing);
    expect(find.text('Create new access'), findsNothing);
    expect(find.text('I already have SMA access'), findsNothing);
    expect(find.textContaining('already created and reserved'), findsOneWidget);
    expect(find.text('Assigned username'), findsOneWidget);
    expect(find.text('kofi.kego@akwaaba'), findsOneWidget);
    expect(find.text('Create password'), findsOneWidget);
    expect(find.text('Activate staff account'), findsOneWidget);

    final assignedField = find.ancestor(
      of: find.text('Assigned username'),
      matching: find.byType(TextFormField),
    );
    final assignedInput = tester.widget<EditableText>(
      find.descendant(of: assignedField, matching: find.byType(EditableText)),
    );
    expect(assignedInput.readOnly, isTrue);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Create password'),
      'SecurePass10',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'SecurePass10',
    );
    await tester.ensureVisible(find.text('Activate staff account'));
    await tester.tap(find.text('Activate staff account'));
    await tester.pumpAndSettle();

    expect(activationRequest, isNotNull);
    final activationBody =
        jsonDecode(activationRequest!.body) as Map<String, dynamic>;
    expect(activationBody['decision'], 'ACTIVATE_RESERVED');
    expect(activationBody['username'], 'kofi.kego@akwaaba');
    expect(find.text('Your account is ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.textContaining('Enter the global username'), findsOneWidget);
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
              'assignedUsername': null,
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
      expect(result.assignedUsername, isEmpty);
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
