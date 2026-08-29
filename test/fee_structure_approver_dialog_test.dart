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
}
