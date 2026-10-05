import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff_authorisations/data/staff_authorisation_api_client.dart';

void main() {
  test('decodes configurable job titles and their authority', () async {
    final client = StaffAuthorisationApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/api/schools/SCH-1/staff-authorisations/job-titles'),
        );
        return http.Response(
          jsonEncode([
            {
              'id': 4,
              'name': 'Pastor',
              'active': true,
              'version': 0,
              'authority': {
                'id': 9,
                'key': 'STAFF_ONLY',
                'name': 'Staff Only',
                'baseRole': 'STAFF',
                'builtIn': true,
                'active': true,
                'assignedUsers': 0,
                'permissionRules': [],
              },
            },
          ]),
          200,
        );
      }),
    );

    final titles = await client.getJobTitles('SCH-1');

    expect(titles, hasLength(1));
    expect(titles.single.name, 'Pastor');
    expect(titles.single.authority.name, 'Staff Only');
    expect(titles.single.authority.baseRole, 'STAFF');
  });

  test('decodes staff from the live paginated users envelope', () async {
    final client = StaffAuthorisationApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/api/user-management/schools/SCH-1/users'),
        );
        return http.Response(
          jsonEncode({
            'page': 0,
            'size': 250,
            'total': 2,
            'users': [
              {
                'id': 3,
                'firstName': 'Kofi',
                'lastName': 'Nketia',
                'userType': 'STAFF',
                'role': 'ADMINISTRATOR',
                'accountStatus': 'ACTIVE',
              },
              {
                'id': 5,
                'firstName': 'Esi',
                'lastName': 'Boateng',
                'userType': 'GUARDIAN',
                'role': 'GUARDIAN_ROLE',
                'accountStatus': 'ACTIVE',
              },
            ],
          }),
          200,
        );
      }),
    );

    final staff = await client.getStaffUsers('SCH-1');

    expect(staff, hasLength(1));
    expect(staff.single.id, '3');
    expect(staff.single.name, 'Kofi Nketia');
    expect(staff.single.role, 'ADMINISTRATOR');
  });

  test('sends a precise one-person resource block', () async {
    late Map<String, dynamic> sent;
    final client = StaffAuthorisationApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 30,
            'userId': 14,
            'userName': 'Ama Mensah',
            'module': 'FINANCE',
            'resource': 'PETTY_CASH_TOP_UP',
            'action': 'EDIT',
            'effect': 'DENY',
            'scopeType': 'SCHOOL',
            'reason': 'Separation of duties',
            'status': 'ACTIVE',
            'sensitiveChange': false,
            'requestedBy': 'Administrator',
          }),
          200,
        );
      }),
    );

    final result = await client.createException(
      schoolId: 'SCH-1',
      userId: '14',
      module: 'FINANCE',
      resource: 'PETTY_CASH_TOP_UP',
      action: 'EDIT',
      effect: 'DENY',
      scopeType: 'SCHOOL',
      reason: 'Separation of duties',
    );

    expect(sent['userId'], 14);
    expect(sent['resource'], 'PETTY_CASH_TOP_UP');
    expect(sent['effect'], 'DENY');
    expect(result.status, 'ACTIVE');
  });

  test('surfaces server safety messages', () async {
    final client = StaffAuthorisationApiClient(
      accessToken: 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'You cannot change or approve your own access',
          }),
          403,
        ),
      ),
    );

    expect(
      () => client.getAuthorities('SCH-1'),
      throwsA(
        isA<StaffAuthorisationApiException>().having(
          (error) => error.message,
          'message',
          contains('your own access'),
        ),
      ),
    );
  });
}
