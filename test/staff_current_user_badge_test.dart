import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/staff/data/staff_api_client.dart';
import 'package:school_management_app/src/staff/presentation/staff_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  Future<void> pumpStaffDirectory(
    WidgetTester tester, {
    List<http.Request>? requests,
    String nanaAccountStatus = 'ACTIVE',
    bool includeResume = false,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      requests?.add(request);
      if (request.url.path.endsWith('/api/lookup/departments')) {
        return http.Response(
          jsonEncode([
            {'id': 1, 'name': 'Academic'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/staff-authorisations/job-titles')) {
        return http.Response(
          jsonEncode([
            {
              'id': 10,
              'name': 'Teacher',
              'authority': {'name': 'Teacher', 'baseRole': 'CLASS_TEACHER'},
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/documents/DOC-7/download-url')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'downloadUrl':
                  'https://documents.example.test/signed/nana-resume.pdf',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/user-management/schools/')) {
        if (request.method == 'POST') {
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
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
              'accountStatus': nanaAccountStatus,
              'createdAt': '2026-08-02',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.contains('/staff-management/schools/')) {
        return http.Response(
          jsonEncode(
            includeResume
                ? [
                    {
                      'staffId': 'STAFF-7',
                      'userId': '7',
                      'position': 'Teacher',
                      'departmentName': 'Academic',
                      'employmentType': 'Permanent',
                      'startDate': '2026-08-02',
                      'resumeDocuments': [
                        {
                          'documentId': 'DOC-7',
                          'fileName': 'nana-resume.pdf',
                          'fileType': 'application/pdf',
                          'fileSize': 2048,
                          'status': 'ACTIVE',
                        },
                      ],
                    },
                  ]
                : const [],
          ),
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('staff-list-count')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('staff-onboarding-count')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires a password change for one selected staff account', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await pumpStaffDirectory(tester, requests: requests);

    await tester.tap(find.text('Nana Boateng'));
    await tester.pumpAndSettle();
    expect(find.text('Account controls'), findsNothing);
    expect(find.text('Account actions'), findsOneWidget);
    await tester.tap(find.text('Account actions'));
    await tester.pumpAndSettle();
    expect(find.text('Require password change'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('staff-require-password-change-7')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Require password change?'), findsOneWidget);
    expect(
      find.textContaining('signed out of all current sessions'),
      findsOneWidget,
    );
    await tester.tap(find.text('Require change'));
    await tester.pumpAndSettle();

    expect(
      requests.where(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/users/7/reset-password'),
      ),
      hasLength(1),
    );
    expect(
      find.text('Password change required. Current sessions signed out.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reviewing staff receives approve and reject controls', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await pumpStaffDirectory(
      tester,
      requests: requests,
      nanaAccountStatus: 'PENDING_REVIEW',
    );

    await tester.tap(find.text('Onboarding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nana Boateng'));
    await tester.pumpAndSettle();

    expect(find.text('Account controls'), findsNothing);
    expect(find.text('Account actions'), findsOneWidget);
    await tester.tap(find.text('Account actions'));
    await tester.pumpAndSettle();
    expect(find.text('Approve account'), findsOneWidget);
    expect(find.text('Reject account'), findsOneWidget);
    await tester.tap(find.text('Approve account'));
    await tester.pumpAndSettle();
    expect(find.text('Approve staff account?'), findsOneWidget);
    await tester.tap(find.text('Approve account').last);
    await tester.pumpAndSettle();

    expect(
      requests.where(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/users/7/approve'),
      ),
      hasLength(1),
    );
    expect(find.text('Staff account approved.'), findsOneWidget);
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
    expect(find.byKey(const Key('staff-job-title')), findsOneWidget);

    Finder textField(String label) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    );
    await tester.enterText(textField('First name *'), 'Ama');
    await tester.enterText(textField('Last name *'), 'Boateng');
    await tester.enterText(textField('Phone *'), '0240000004');
    await tester.tap(find.byKey(const Key('staff-job-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teacher').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Additional or individual access can be assigned safely',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Employment status'), findsNothing);
    expect(find.text('Employment type (optional)'), findsOneWidget);
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

  testWidgets('staff table sorts by a selected column in both directions', (
    tester,
  ) async {
    await pumpStaffDirectory(tester);

    expect(
      tester.getTopLeft(find.text('Adjoa Mensah')).dy,
      lessThan(tester.getTopLeft(find.text('Nana Boateng')).dy),
    );

    await tester.tap(find.byKey(const ValueKey('staff-sort-name')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Nana Boateng')).dy,
      lessThan(tester.getTopLeft(find.text('Adjoa Mensah')).dy),
    );
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('staff-sort-name')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Adjoa Mensah')).dy,
      lessThan(tester.getTopLeft(find.text('Nana Boateng')).dy),
    );
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff table remains readable with horizontal scrolling', (
    tester,
  ) async {
    await pumpStaffDirectory(tester);
    tester.view.physicalSize = const Size(760, 900);
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
    expect(find.text('Adjoa Mensah'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('staff profile and account controls reflow on a compact page', (
    tester,
  ) async {
    await pumpStaffDirectory(tester);
    tester.view.physicalSize = const Size(760, 900);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nana Boateng'));
    await tester.pumpAndSettle();

    expect(find.text('Account controls'), findsNothing);
    expect(find.text('Account actions'), findsOneWidget);
    await tester.tap(find.text('Account actions'));
    await tester.pumpAndSettle();
    expect(find.text('Require password change'), findsOneWidget);
    expect(find.text('Suspend account'), findsOneWidget);
    expect(find.text('Deactivate and archive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'documents contain files only and account events stay in history',
    (tester) async {
      await pumpStaffDirectory(tester);

      await tester.tap(find.text('Nana Boateng'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Documents'), findsWidgets);
      expect(find.text('No documents uploaded'), findsOneWidget);
      expect(find.text('Login setup complete'), findsNothing);
      expect(find.text('Employment onboarding saved'), findsNothing);
      expect(find.text('Resume uploaded'), findsNothing);
      expect(find.text('Verified'), findsNothing);

      await tester.tap(find.text('Account history'));
      await tester.pumpAndSettle();

      expect(find.text('No account history yet'), findsOneWidget);
      expect(
        find.textContaining('Role, access, suspension, reactivation'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('staff documents provide secure view and download actions', (
    tester,
  ) async {
    final requests = <http.Request>[];
    await pumpStaffDirectory(tester, requests: requests, includeResume: true);

    await tester.tap(find.text('Nana Boateng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();

    expect(find.text('nana-resume.pdf'), findsOneWidget);
    expect(find.text('2.0 KB · active'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('staff-document-view-DOC-7')));
    await tester.pumpAndSettle();
    expect(
      requests.where(
        (request) =>
            request.url.path.endsWith('/documents/DOC-7/download-url') &&
            request.url.queryParameters['download'] == 'false',
      ),
      hasLength(1),
    );

    await tester.tap(
      find.byKey(const ValueKey('staff-document-download-DOC-7')),
    );
    await tester.pumpAndSettle();
    expect(
      requests.where(
        (request) =>
            request.url.path.endsWith('/documents/DOC-7/download-url') &&
            request.url.queryParameters['download'] == 'true',
      ),
      hasLength(1),
    );
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
