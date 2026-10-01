import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';
import 'package:school_management_app/src/staff/presentation/staff_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  Future<void> pumpStaffDirectory(WidgetTester tester) async {
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
              'roles': ['CLASS_TEACHER', 'SUBJECT_TEACHER'],
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
  }

  testWidgets('marks only the signed-in staff member as Me', (tester) async {
    await pumpStaffDirectory(tester);

    expect(find.text('Adjoa Mensah'), findsOneWidget);
    expect(find.text('Nana Boateng'), findsOneWidget);
    expect(find.byKey(const ValueKey('current-staff-user-badge')), findsOne);
    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Class Teacher'), findsNothing);
    expect(find.text('Subject Teacher'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff onboarding offers one Teacher access role', (
    tester,
  ) async {
    await pumpStaffDirectory(tester);

    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add manually'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher'), findsWidgets);
    expect(find.text('Class teacher'), findsNothing);
    expect(find.text('Subject teacher'), findsNothing);
    expect(
      find.textContaining(
        'Class and subject responsibilities are assigned later',
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    Finder textField(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.enterText(textField('First name *'), 'Ama');
    await tester.enterText(textField('Last name *'), 'Boateng');
    await tester.enterText(textField('Phone *'), '0240000004');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Employment status'), findsNothing);
    expect(find.text('Employment type *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff status badges hug their labels in table columns', (
    tester,
  ) async {
    await pumpStaffDirectory(tester);

    final badges = find.byKey(const ValueKey('staff-soft-badge-Active'));
    expect(badges, findsNWidgets(2));
    for (final element in badges.evaluate()) {
      final badge = find.byWidget(element.widget);
      final label = find.descendant(of: badge, matching: find.text('Active'));
      expect(
        tester.getSize(badge).width,
        closeTo(tester.getSize(label).width + 20, .1),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('managing a subject-only teacher preserves technical access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? savedRoles;
    final client = MockClient((request) async {
      if (request.method == 'PUT' && request.url.path.endsWith('/users/7')) {
        savedRoles = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 7,
            'userName': 'kwame.teacher',
            'firstName': 'Kwame',
            'lastName': 'Mensah',
            'role': savedRoles!['role'],
            'roles': savedRoles!['roles'],
            'accountStatus': 'ACTIVE',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/user-management/schools/')) {
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'userName': 'kwame.teacher',
              'firstName': 'Kwame',
              'lastName': 'Mensah',
              'email': 'kwame@example.com',
              'phoneNumber': '0240000003',
              'userType': 'STAFF',
              'role': 'SUBJECT_TEACHER',
              'roles': ['SUBJECT_TEACHER'],
              'accountStatus': 'ACTIVE',
              'createdAt': '2026-08-03',
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

    expect(find.text('Teacher'), findsOneWidget);
    await tester.tap(find.text('Kwame Mensah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage roles'));
    await tester.pumpAndSettle();

    expect(find.text('Teacher'), findsWidgets);
    expect(
      find.textContaining('subject assignments managed automatically'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save roles'));
    await tester.pumpAndSettle();

    expect(savedRoles?['role'], 'SUBJECT_TEACHER');
    expect(savedRoles?['roles'], ['SUBJECT_TEACHER']);
    expect(tester.takeException(), isNull);
  });
}
