import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';
import 'package:school_management_app/src/staff/presentation/staff_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('marks only the signed-in staff member as Me', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path.contains('/user-management/schools/')) {
        return http.Response(
          jsonEncode([
            {
              'id': 4,
              'userName': 'adjoa.admin',
              'firstName': 'Adjoa',
              'lastName': 'Mensah',
              'email': 'adjoa@example.com',
              'phoneNumber': '0240000001',
              'userType': 'STAFF',
              'role': 'ADMINISTRATOR',
              'roles': ['ADMINISTRATOR'],
              'accountStatus': 'ACTIVE',
              'createdAt': '2026-08-01',
            },
            {
              'id': 7,
              'userName': 'nana.teacher',
              'firstName': 'Nana',
              'lastName': 'Boateng',
              'email': 'nana@example.com',
              'phoneNumber': '0240000002',
              'userType': 'STAFF',
              'role': 'CLASS_TEACHER',
              'roles': ['CLASS_TEACHER'],
              'accountStatus': 'ACTIVE',
              'createdAt': '2026-08-02',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/staff-management/schools/')) {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not found', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StaffScreen(
            customSchoolId: 'SCH-001',
            currentUserId: 4,
            accessToken: 'test-token',
            apiClient: StaffApiClient(
              accessToken: 'test-token',
              client: client,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adjoa Mensah'), findsOneWidget);
    expect(find.text('Nana Boateng'), findsOneWidget);
    expect(find.byKey(const ValueKey('current-staff-user-badge')), findsOne);
    expect(find.text('Me'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
