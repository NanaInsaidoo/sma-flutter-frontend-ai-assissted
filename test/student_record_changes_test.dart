import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';
import 'package:school_management_app/src/admissions/presentation/student_record_changes.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets(
    'student history approves without a comment and refreshes the audit history',
    (tester) async {
      final decisions = <Map<String, dynamic>>[];
      var refreshes = 0;
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, endsWith('/record-changes/1/decision'));
            decisions.add(
              Map<String, dynamic>.from(jsonDecode(request.body) as Map),
            );
            return http.Response('[]', 200);
          }
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'status': decisions.isEmpty ? 'PENDING_APPROVAL' : 'APPROVED',
                'requesterName': 'Admin One',
                'approverName': 'Admin Two',
                'reason': 'Correct blood group',
                'decisionReason': '',
                'createdAt': '2026-08-30',
                'canApprove': decisions.isEmpty,
                'canWithdraw': false,
                'before': {},
                'proposed': {},
                'events': decisions.isEmpty
                    ? []
                    : [
                        {
                          'action': 'APPROVED',
                          'actorName': 'Admin Two',
                          'occurredAt': '2026-08-30',
                          'reason': '',
                          'notifications': [],
                        },
                      ],
              },
            ]),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentRecordHistoryPanel(
                api: api,
                school: 'SCHOOL',
                student: 'STU-1',
                onChanged: () => refreshes++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PENDING_APPROVAL · Admin One'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve'));
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(decisions, [
        {'action': 'APPROVE', 'reason': ''},
      ]);
      expect(refreshes, 1);
      expect(
        find.text('0 pending changes · 1 recorded changes'),
        findsOneWidget,
      );
      await tester.tap(find.text('Change history'));
      await tester.pumpAndSettle();
      expect(find.text('APPROVED · Admin One'), findsOneWidget);
      await tester.tap(find.text('APPROVED · Admin One'));
      await tester.pumpAndSettle();
      expect(find.text('APPROVED · Admin Two'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scenario in [
    (sensitive: true, hasApprover: true),
    (sensitive: true, hasApprover: false),
    (sensitive: false, hasApprover: false),
  ]) {
    testWidgets(
      'review enforces approval=${scenario.sensitive} with available approver=${scenario.hasApprover}',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <http.Request>[];
        Map<String, dynamic>? result;
        final sections = scenario.sensitive
            ? {
                'medical': {'bloodGroupId': 7},
              }
            : {
                'address': {'houseNumber': '12'},
              };
        final api = AdmissionsApiClient(
          accessToken: 'test',
          client: MockClient((request) async {
            requests.add(request);
            expect(request.method, 'POST');
            if (request.url.path.endsWith('/record-changes/preview')) {
              return http.Response(
                jsonEncode({
                  'requiresApproval': scenario.sensitive,
                  'before': scenario.sensitive
                      ? {
                          'medical': {'bloodGroupId': 1},
                        }
                      : {
                          'address': {'houseNumber': '10'},
                        },
                }),
                200,
              );
            }
            expect(
              request.url.path,
              endsWith('/students/STU-1/record-changes'),
            );
            return http.Response(
              jsonEncode({
                'status': scenario.sensitive ? 'PENDING_APPROVAL' : 'APPLIED',
              }),
              200,
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Review edit'),
                  onPressed: () async {
                    result = await reviewStudentRecordChange(
                      context: context,
                      api: api,
                      school: 'SCHOOL',
                      student: 'STU-1',
                      recordContext: {
                        'baseVersion': 'version-1',
                        'approvers': [
                          if (scenario.hasApprover)
                            {'id': 2, 'name': 'Admin Two'},
                        ],
                      },
                      sections: sections,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Review edit'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Correct verified school record',
        );
        await tester.pump();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(requests.single.url.path, endsWith('/record-changes/preview'));
        final submit = find.widgetWithText(
          FilledButton,
          scenario.sensitive ? 'Submit for approval' : 'Save changes',
        );
        if (scenario.sensitive) {
          expect(
            find.textContaining('existing record stays unchanged'),
            findsOneWidget,
          );
          expect(tester.widget<FilledButton>(submit).onPressed, isNull);
          if (!scenario.hasApprover) {
            expect(
              find.textContaining('No other authorized administrator'),
              findsOneWidget,
            );
            await tester.tap(find.text('Back'));
            await tester.pumpAndSettle();
            expect(result, isNull);
            expect(requests, hasLength(1));
            return;
          }
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Admin Two').last);
          await tester.pumpAndSettle();
        } else {
          expect(
            find.textContaining(
              'Other authorized administrators will be notified',
            ),
            findsOneWidget,
          );
          expect(find.byType(DropdownButtonFormField<int>), findsNothing);
        }
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        expect(jsonDecode(requests.last.body), {
          'baseVersion': 'version-1',
          'reason': 'Correct verified school record',
          'sections': sections,
          if (scenario.sensitive) 'approverId': 2,
        });
        expect(
          result?['status'],
          scenario.sensitive ? 'PENDING_APPROVAL' : 'APPLIED',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'skip ID sends only explicit skip, never fabricated identity fields',
    () async {
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          expect(request.method, 'PUT');
          expect(
            request.url.path,
            endsWith('/schools/SCHOOL/guardians/G-1/proof-of-id'),
          );
          expect(jsonDecode(request.body), {'skipped': true});
          return http.Response(
            '{"customGuardianId":"G-1","proofOfIdSkipped":true}',
            200,
          );
        }),
      );
      await api.updateGuardianStep(
        customSchoolId: 'SCHOOL',
        customGuardianId: 'G-1',
        step: 'proof-of-id',
        body: {'skipped': true},
      );
    },
  );

  test(
    'record request includes unchanged version, reason and selected approver',
    () async {
      final body = {
        'baseVersion': 'version-1',
        'reason': 'Correct recorded blood group',
        'approverId': 2,
        'sections': {
          'medical': {'bloodGroupId': 7},
        },
      };
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, endsWith('/students/STU-1/record-changes'));
          expect(jsonDecode(request.body), body);
          return http.Response('{"status":"PENDING_APPROVAL"}', 200);
        }),
      );
      final response = await api.submitStudentRecordChange(
        'SCHOOL',
        'STU-1',
        body,
      );
      expect(response['status'], 'PENDING_APPROVAL');
    },
  );

  testWidgets(
    'history shows withdrawal, not self approval, and notification acknowledgments',
    (tester) async {
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'id': 1,
                'status': 'PENDING_APPROVAL',
                'requesterName': 'Admin One',
                'reason': 'Correction needed',
                'createdAt': '2026-08-30',
                'approverName': 'Admin Two',
                'canApprove': false,
                'canWithdraw': true,
                'before': {},
                'proposed': {},
                'events': [
                  {
                    'action': 'SUBMITTED',
                    'actorName': 'Admin One',
                    'occurredAt': '2026-08-30',
                    'reason': 'Correction needed',
                    'notifications': [
                      {'recipient': 'Admin Two', 'readAt': null},
                    ],
                  },
                ],
              },
            ]),
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentRecordHistoryPanel(
                api: api,
                school: 'SCHOOL',
                student: 'STU-1',
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('PENDING_APPROVAL · Admin One'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw request'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(
        find.textContaining('Delivered, not acknowledged'),
        findsOneWidget,
      );
    },
  );

  testWidgets('change reason is required before continuing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  requestStudentChangeReason(context, 'Record change'),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Correct address');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );
  });
}
