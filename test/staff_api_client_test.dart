import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';

void main() {
  test('loads class and subject assignments by staff profile id', () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/all-streams')) {
        return http.Response(
          jsonEncode([
            {
              'streamId': 11,
              'gradeLevelName': 'Basic 1',
              'streamName': 'Section 1',
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/streams/11/class-teachers')) {
        return http.Response(
          jsonEncode([
            {
              'id': 1,
              'staffId': 'staff-1',
              'isPrimary': true,
              'isActive': true,
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/streams/11/subject-teachers')) {
        return http.Response(
          jsonEncode([
            {
              'id': 2,
              'staffId': 'staff-1',
              'subjectName': 'Mathematics',
              'active': true,
            },
          ]),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final assignments = await StaffApiClient(
      accessToken: 'token',
      client: client,
    ).getStaffAssignments('SCH-001');

    expect(assignments['staff-1'], [
      'Mathematics teacher · Basic 1 · Section 1',
      'Primary class teacher · Basic 1 · Section 1',
    ]);
  });

  test('reads invitation role and masked contact details', () {
    final profile = StaffProfileRecord.fromJson({
      'staffId': 'staff-2',
      'firstName': 'E2E',
      'lastName': 'Tester',
      'invitationMaskedPhone': '***4567',
      'invitationPrimaryRole': 'CLASS_TEACHER',
      'invitationRoles': ['CLASS_TEACHER', 'BURSAR'],
      'email': 'e2e@example.test',
      'dateOfBirth': '1990-01-15',
    });

    expect(profile.invitationMaskedPhone, '***4567');
    expect(profile.invitationPrimaryRole, 'CLASS_TEACHER');
    expect(profile.invitationRoles, ['CLASS_TEACHER', 'BURSAR']);
    expect(profile.email, 'e2e@example.test');
    expect(profile.dateOfBirth, '1990-01-15');
  });

  test('reads saved payroll and real audit activity', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/staff-1/finance')) {
        return http.Response(
          jsonEncode({
            'basicPay': 2500,
            'houseAllowance': 100,
            'transportAllowance': 150,
            'otherAllowances': 50,
            'grossSalary': 2800,
            'ssnitNumber': 'SSNIT-E2E',
            'tinNumber': 'TIN-E2E',
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/user/7/recent')) {
        return http.Response(
          jsonEncode({
            'recentActivity': [
              {
                'actionType': 'EDIT',
                'description': 'Profile updated',
                'timestamp': '2026-09-30T12:00:00',
                'performedByDisplayName': 'Kofi Nketia',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    });
    final api = StaffApiClient(accessToken: 'token', client: client);

    final finance = await api.getStaffFinance('staff-1');
    final activity = await api.getStaffActivity('7');

    expect(finance?.basicPay, 2500);
    expect(finance?.totalAllowances, 300);
    expect(finance?.grossSalary, 2800);
    expect(activity.single.description, 'Profile updated');
    expect(activity.single.actorName, 'Kofi Nketia');
  });

  test('uses lifecycle endpoints with an audit reason', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response('{}', 200);
    });
    final api = StaffApiClient(accessToken: 'token', client: client);

    await api.suspendSchoolUser(
      customSchoolId: 'SCH-001',
      userId: '7',
      reason: 'E2E verification',
    );
    await api.reactivateSchoolUser(customSchoolId: 'SCH-001', userId: '7');
    await api.deactivateSchoolUser(
      customSchoolId: 'SCH-001',
      userId: '7',
      reason: 'Employment ended',
    );
    await api.requirePasswordChange(customSchoolId: 'SCH-001', userId: '7');
    await api.approveSchoolUser(customSchoolId: 'SCH-001', userId: '7');
    await api.rejectSchoolUser(
      customSchoolId: 'SCH-001',
      userId: '7',
      reason: 'Review failed',
    );

    expect(requests.map((request) => request.method), [
      'POST',
      'POST',
      'POST',
      'POST',
      'POST',
      'POST',
    ]);
    expect(requests[0].url.queryParameters['reason'], 'E2E verification');
    expect(requests[1].url.path, endsWith('/users/7/reactivate'));
    expect(requests[2].url.queryParameters['reason'], 'Employment ended');
    expect(requests[3].url.path, endsWith('/users/7/reset-password'));
    expect(requests[4].url.path, endsWith('/users/7/approve'));
    expect(requests[5].url.path, endsWith('/users/7/reject'));
    expect(jsonDecode(requests[5].body), {'reason': 'Review failed'});
  });
}
