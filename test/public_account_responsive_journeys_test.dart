import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/account_access/data/account_access_api_client.dart';
import 'package:school_management_app/src/account_access/presentation/account_recovery_screen.dart';

void main() {
  const viewports = <String, Size>{
    'compact mobile': Size(360, 800),
    'tablet portrait': Size(834, 1194),
  };

  for (final viewport in viewports.entries) {
    testWidgets('username recovery completes on ${viewport.key}', (
      tester,
    ) async {
      await _setViewport(tester, viewport.value);
      final api = _recoveryApi();
      await tester.pumpWidget(
        MaterialApp(
          home: AccountRecoveryScreen(
            kind: AccountRecoveryKind.username,
            onBackToLogin: () {},
            api: api,
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registered phone number'),
        '+233245550167',
      );
      await _tapButton(tester, 'Send verification code');
      await _completeVerification(tester);

      expect(find.text('akosua.mensah'), findsOneWidget);
      await _tapButton(tester, 'Done');
      expect(find.text('Sign in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('password reset completes on ${viewport.key}', (tester) async {
      await _setViewport(tester, viewport.value);
      final api = _recoveryApi();
      await tester.pumpWidget(
        MaterialApp(
          home: AccountRecoveryScreen(
            kind: AccountRecoveryKind.password,
            onBackToLogin: () {},
            api: api,
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Global username'),
        'akosua.mensah',
      );
      await _tapButton(tester, 'Send verification code');
      await _completeVerification(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'SecurePass10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'SecurePass10',
      );
      await _tapButton(tester, 'Update password');

      expect(find.text('Password updated successfully.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _completeVerification(WidgetTester tester) async {
  expect(find.text('Local testing code: 456789'), findsOneWidget);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'First name'),
    'Akosua',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Last name'),
    'Mensah',
  );
  await _tapButton(tester, 'Verify account information');
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

AccountAccessApiClient _recoveryApi() {
  return AccountAccessApiClient(
    client: MockClient((request) async {
      if (request.url.path.endsWith('/start')) {
        return http.Response(
          jsonEncode({
            'challengeId': 'responsive-challenge',
            'deliveryChannel': 'SMS',
            'maskedDestination': '+233 24 *** 0167',
            'message': 'A verification code was sent.',
            'testingCode': '456789',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/verify')) {
        return http.Response(
          jsonEncode({
            'proofToken': 'responsive-proof',
            'accounts': [
              {
                'accountType': 'GUARDIAN',
                'username': 'akosua.mensah',
                'schoolLabel': 'SMA Quality Academy',
              },
            ],
            'message': 'Identity verified.',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/reset-password')) {
        return http.Response(jsonEncode({'message': 'Password updated.'}), 200);
      }
      return http.Response(jsonEncode({'message': 'Unexpected request.'}), 500);
    }),
  );
}
