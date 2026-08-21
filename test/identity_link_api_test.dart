import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';

void main() {
  test('staff identity linking starts and verifies an owner challenge', () async {
    final requests = <http.Request>[];
    final api = StaffApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/start')) {
          return http.Response(
            jsonEncode({
              'accountFound': true,
              'challengeId': 'challenge-1',
              'verificationDestination': 'a***@example.com',
              'message': 'Code sent',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'challengeId': 'challenge-1',
            'firstName': 'Ama',
            'middleName': '',
            'lastName': 'Mensah',
            'dateOfBirth': '1985-03-04',
            'email': 'ama@example.com',
            'phoneNumber': '+233200000000',
          }),
          200,
        );
      }),
    );

    final started = await api.startIdentityLink(
      customSchoolId: 'SCH-1',
      identifier: 'ama@example.com',
      purpose: 'STAFF',
    );
    final profile = await api.verifyIdentityLink(
      customSchoolId: 'SCH-1',
      challengeId: started.challengeId,
      code: '123456',
    );

    expect(started.verificationDestination, 'a***@example.com');
    expect(profile.firstName, 'Ama');
    expect(
      requests.map(
        (request) => request.url.path.replaceFirst(
          '/Narellallc/sma-v1/1.0.0',
          '',
        ),
      ),
      [
        '/api/v1/identity-links/schools/SCH-1/start',
        '/api/v1/identity-links/schools/SCH-1/verify',
      ],
    );
    expect(jsonDecode(requests.first.body)['purpose'], 'STAFF');
    expect(jsonDecode(requests.last.body)['code'], '123456');
  });
}
