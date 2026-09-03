import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/presentation/fee_management_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('waiver overview summarizes active and pending records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/academic-context/current')) {
        return http.Response(
          jsonEncode({
            'academicTerm': {
              'id': 44,
              'termType': {'name': 'First Term'},
            },
            'academicYear': {'year': '2026-2027'},
          }),
          200,
        );
      }
      if (path.endsWith('/api/academic-terms')) {
        return http.Response(
          jsonEncode([
            {
              'id': 44,
              'termName': 'First Term',
              'academicYear': '2026-2027',
              'isCurrentTerm': true,
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/fee-management/overview')) {
        return http.Response(
          jsonEncode({
            'termId': 44,
            'termName': 'First Term',
            'academicYear': '2026-2027',
            'collectionByClass': <dynamic>[],
            'outstandingArrears': <dynamic>[],
          }),
          200,
        );
      }
      if (path.endsWith('/waiver-types')) {
        return http.Response(
          jsonEncode([
            {
              'id': 9,
              'name': 'Partial bursary',
              'description': 'Tuition support',
              'valueType': 'FIXED_AMOUNT',
              'defaultValue': 250,
              'scope': 'ALL_FEES',
              'active': true,
            },
          ]),
          200,
        );
      }
      if (path.endsWith('/student-waivers')) {
        return http.Response(
          jsonEncode([
            _waiver(
              id: 71,
              studentId: 'STU-044',
              studentName: 'Ama Mensah',
              amount: 250,
              status: 'ACTIVE',
            ),
            _waiver(
              id: 72,
              studentId: 'STU-052',
              studentName: 'Kojo Boateng',
              amount: 100,
              status: 'PENDING_APPROVAL',
            ),
            _waiver(
              id: 73,
              studentId: 'STU-044',
              studentName: 'Ama Mensah',
              amount: 50,
              status: 'ACTIVE',
            ),
          ]),
          200,
        );
      }
      return http.Response('Not found: $path', 404);
    });

    String? openedStudentId;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FeeManagementScreen(
            customSchoolId: 'SCH-001',
            schoolName: 'Test School',
            accessToken: 'token',
            api: FeeApiClient(accessToken: 'token', client: client),
            onOpenStudent: (studentId) => openedStudentId = studentId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Waivers & Discounts').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('waiver-summary-total')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('waiver-summary-total')),
        matching: find.text('GH₵ 300'),
      ),
      findsOneWidget,
    );
    expect(find.text('Partial bursary'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('waiver-summary-students')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('waiver-summary-pending')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('waiver-view-students')));
    await tester.pumpAndSettle();

    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('STU-044'), findsOneWidget);
    expect(find.text('GH₵ 300'), findsWidgets);
    expect(find.text('Kojo Boateng'), findsOneWidget);

    await tester.tap(find.text('Ama Mensah'));
    expect(openedStudentId, 'STU-044');
  });
}

Map<String, dynamic> _waiver({
  required int id,
  required String studentId,
  required String studentName,
  required double amount,
  required String status,
}) {
  return {
    'id': id,
    'academicTermId': 44,
    'customStudentId': studentId,
    'studentName': studentName,
    'className': 'Basic 6',
    'waiverTypeId': 9,
    'waiverType': 'Partial bursary',
    'valueType': 'FIXED_AMOUNT',
    'value': amount,
    'scope': 'ALL_FEES',
    'eligibleAmount': 500,
    'waivedAmount': amount,
    'reason': 'Approved support',
    'status': status,
    'createdById': 12,
    'createdByName': 'Kofi Nketia',
    'assignedApproverId': 18,
    'assignedApproverName': 'Adjoa Mensah',
    'changeType': 'NEW',
    'creatorOwned': status != 'ACTIVE',
    'canApprove': false,
    'createdAt': '2026-08-30T10:00:00Z',
    'assessments': <dynamic>[],
  };
}
