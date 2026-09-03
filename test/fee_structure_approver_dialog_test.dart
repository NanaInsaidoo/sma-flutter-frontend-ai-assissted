import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/fees/data/fee_api_client.dart';
import 'package:school_management_app/src/fees/presentation/fee_structure_workflow_content.dart';

void main() {
  testWidgets('approver is selected in a modal only after submit is pressed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = FeeApiClient(
      accessToken: 'token',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/all-streams')) {
          return http.Response(
            jsonEncode([
              {
                'streamId': 33,
                'streamName': 'Stream A',
                'gradeLevelId': 12,
                'gradeLevelName': 'Basic 6',
                'isActive': true,
                'studentCount': 5,
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/fee-master')) {
          return http.Response(
            jsonEncode([
              {
                'id': 100,
                'code': 'TUITION',
                'itemName': 'Tuition Fee',
                'category': 'Tuition',
                'description': 'Academic tuition for the term',
                'active': true,
                'status': 'APPROVED',
                'hasApprovedVersion': true,
                'hasPendingChange': false,
                'systemDefined': true,
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/fee-structures/approvers')) {
          return http.Response(
            jsonEncode([
              {'id': 8, 'name': 'Akosua Owusu', 'role': 'Administrator'},
              {'id': 9, 'name': 'Nana Boateng', 'role': 'Headmaster'},
            ]),
            200,
          );
        }
        if (path.endsWith('/fee-structures/workflow-summary')) {
          return http.Response(
            jsonEncode({
              'pendingMyApproval': 0,
              'pendingAll': 0,
              'masterPendingMyApproval': 0,
              'masterPendingAll': 0,
              'requiredItemsPendingMyApproval': 0,
              'requiredItemsPendingAll': 0,
              'myDrafts': 0,
              'approvedNotPublished': 0,
              'streamsWithoutActiveFees': 1,
              'activeStreams': 1,
              'activeStreamsWithFees': 0,
            }),
            200,
          );
        }
        if (path.endsWith('/fee-structures') && request.method == 'GET') {
          return http.Response('[]', 200);
        }
        return http.Response('Not found: $path', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FeeStructureWorkflowContent(
              api: api,
              customSchoolId: 'SCH-001',
              termId: 44,
              termName: 'First Term 2026-2027',
              currentUserId: 7,
              money: (amount) => 'GH₵${amount.toStringAsFixed(0)}',
              onChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approvals'), findsNothing);
    await tester.tap(find.text('Stream A'));
    await tester.pumpAndSettle();

    expect(find.text('Approver for submission'), findsNothing);
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();

    expect(find.text('Submit for approval'), findsWidgets);
    expect(
      find.byKey(const Key('fee-editor-approver-dialog-dropdown')),
      findsOneWidget,
    );
    expect(find.textContaining('Choose who should review'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('fee-editor-confirm-approver')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'fee revision separates published fees and opens a publication review',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = FeeApiClient(
        accessToken: 'token',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/all-streams')) {
            return http.Response(
              jsonEncode([
                {
                  'streamId': 33,
                  'streamName': 'Stream A',
                  'gradeLevelId': 12,
                  'gradeLevelName': 'Basic 6',
                  'isActive': true,
                  'studentCount': 5,
                },
              ]),
              200,
            );
          }
          if (path.endsWith('/fee-master')) {
            return http.Response('[]', 200);
          }
          if (path.endsWith('/fee-structures/approvers')) {
            return http.Response('[]', 200);
          }
          if (path.endsWith('/fee-structures/workflow-summary')) {
            return http.Response(
              jsonEncode({
                'pendingMyApproval': 0,
                'pendingAll': 0,
                'masterPendingMyApproval': 0,
                'masterPendingAll': 0,
                'requiredItemsPendingMyApproval': 0,
                'requiredItemsPendingAll': 0,
                'myDrafts': 0,
                'approvedNotPublished': 1,
                'streamsWithoutActiveFees': 0,
                'activeStreams': 1,
                'activeStreamsWithFees': 1,
              }),
              200,
            );
          }
          if (path.endsWith('/fee-structures') && request.method == 'GET') {
            return http.Response(
              jsonEncode([
                {
                  'structureId': 91,
                  'gradeLevelId': 12,
                  'streamId': 33,
                  'streamName': 'Stream A',
                  'levelCode': 'B6',
                  'fullName': 'Basic 6',
                  'studentCount': 5,
                  'version': 2,
                  'status': 'APPROVED',
                  'totalPerTerm': 650,
                  'hasPublishedVersion': true,
                  'creatorOwned': true,
                  'feeItems': [
                    {
                      'itemId': 501,
                      'itemKey': 'tuition-key',
                      'feeName': 'Tuition Fee',
                      'category': 'Tuition',
                      'amount': 550,
                      'active': true,
                    },
                    {
                      'itemId': 502,
                      'itemKey': 'bus-key',
                      'feeName': 'Bus Fee',
                      'category': 'Transport',
                      'amount': 100,
                      'active': true,
                    },
                  ],
                  'publishedFeeItems': [
                    {
                      'itemId': 401,
                      'itemKey': 'tuition-key',
                      'feeName': 'Tuition Fee',
                      'category': 'Tuition',
                      'amount': 500,
                      'active': true,
                      'lifecycleAction': 'ADDED',
                      'lifecycleAt': '2026-08-20T09:00:00',
                      'lifecycleBy': 'Kofi Nketia',
                    },
                    {
                      'itemId': 402,
                      'itemKey': 'exam-key',
                      'feeName': 'Examination Fee',
                      'category': 'Assessment',
                      'amount': 50,
                      'active': true,
                    },
                  ],
                },
              ]),
              200,
            );
          }
          return http.Response('Not found: $path', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FeeStructureWorkflowContent(
                api: api,
                customSchoolId: 'SCH-001',
                termId: 44,
                termName: 'First Term 2026-2027',
                currentUserId: 7,
                money: (amount) => 'GH₵${amount.toStringAsFixed(0)}',
                onChanged: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stream A'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('published-fees-section')), findsOneWidget);
      expect(find.byKey(const Key('working-fees-section')), findsOneWidget);
      expect(find.text('CURRENTLY PUBLISHED FEES'), findsOneWidget);
      expect(find.text('CHANGES IN PROGRESS'), findsOneWidget);
      expect(find.text('NEW FEE'), findsOneWidget);
      expect(find.text('REMOVING'), findsOneWidget);
      expect(find.text('Added 20 Aug 2026 by Kofi Nketia'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('working-fees-section')),
          matching: find.text('Publish'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(find.text('Review and publish fees'), findsOneWidget);
      expect(find.text('GH₵500  →  GH₵550'), findsOneWidget);
      expect(find.text('ADDED'), findsOneWidget);
      expect(find.text('REMOVED'), findsOneWidget);
      expect(find.byKey(const Key('confirm-publish-fees')), findsOneWidget);
    },
  );
}
