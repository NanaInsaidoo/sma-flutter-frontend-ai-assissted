import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';
import 'package:school_management_app/src/admissions/presentation/admissions_screen.dart';
import 'package:school_management_app/src/students/presentation/students_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';
import 'support/fake_students_repository.dart';

http.Response json(Object body) => http.Response(jsonEncode(body), 200);
void wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> editor(
  WidgetTester tester,
  AdmissionsApiClient api, {
  int initialStep = 1,
}) async {
  wide(tester);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStudentRecordEditor(
              context: context,
              api: api,
              school: 'SCHOOL',
              studentId: 'STU-1',
              initialStep: initialStep,
            ),
            child: const Text('Edit'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

Map<String, Object?> address(int id) => {
  'id': id,
  'ownerId': 'G-$id',
  'ownerName': 'Guardian $id',
  'houseNumber': '$id',
  'streetName': 'Street $id',
  'cityName': 'Town $id',
};

void main() {
  testWidgets('new household shows only the primary guardian setup', (
    tester,
  ) async {
    wide(tester);
    var writes = 0;
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        if (request.method != 'GET') writes++;
        if (request.url.path.contains('current-term')) {
          return json({
            'id': 1,
            'startDate': '2026-09-01',
            'endDate': '2026-12-18',
          });
        }
        return json([]);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdmissionsScreen(customSchoolId: 'SCHOOL', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Admission'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new household'));
    await tester.pumpAndSettle();

    final addGuardian = find.text('Add guardian');
    expect(find.text('Add the primary guardian'), findsOneWidget);
    expect(addGuardian, findsOneWidget);
    expect(find.text('Add child'), findsNothing);
    expect(find.text('Recent activity'), findsNothing);
    expect(find.text('Last payment'), findsNothing);

    await tester.tap(addGuardian);
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(addGuardian, findsOneWidget);
    expect(writes, 0);
  });

  testWidgets('opens a pending guardian for review and refreshes after approval', (
    tester,
  ) async {
    wide(tester);
    var approved = false;
    var approvals = 0;
    var invitations = 0;
    Map<String, dynamic> guardian() => {
      'customGuardianId': 'GUA-1',
      'firstName': 'Ama',
      'lastName': 'Mensah',
      'householdId': 10,
      'isPrimary': true,
      'status': approved ? 'APPROVED' : 'PENDING_REVIEW',
      'canApproveAdmission': !approved,
    };
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.contains('/guardian-portal-access/')) {
          expect(approved, isTrue);
          invitations++;
          return json({
            'newlyCreated': true,
            'invitationDeliveryStatus': 'FAILED',
            'message': 'The invitation was created, but delivery failed.',
          });
        }
        if (path.endsWith('/directory')) {
          return json({'guardians': [guardian()], 'studentCounts': {}});
        }
        if (path.endsWith('/guardians/GUA-1/approve-admission')) {
          expect(request.method, 'POST');
          approvals++;
          approved = true;
          return json(guardian());
        }
        if (path.endsWith('/guardians/GUA-1')) return json(guardian());
        return json([]);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: HouseholdsGuardiansScreen(customSchoolId: 'SCHOOL', api: api),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting approval'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('directory-row-household-10')));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting approval'), findsOneWidget);

    await tester.tap(find.text('Review guardian'));
    await tester.pumpAndSettle();
    expect(find.text('Guardian profile'), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    final enableLogin = find.byKey(const Key('enable-guardian-login'));
    expect(tester.widget<OutlinedButton>(enableLogin).onPressed, isNull);
    await tester.tap(enableLogin);
    await tester.pumpAndSettle();
    expect(invitations, 0);
    expect(
      find.text('Approve the guardian before enabling login.'),
      findsOneWidget,
    );
    expect(approvals, 0);

    await tester.tap(find.text('Approve guardian'));
    await tester.pumpAndSettle();
    expect(approvals, 0);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Approve guardian'),
    ));
    await tester.pumpAndSettle();
    expect(approvals, 1);
    expect(find.text('Approve guardian'), findsNothing);
    expect(find.text('Approved'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(enableLogin).onPressed, isNotNull);
    await tester.tap(enableLogin);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();
    expect(invitations, 1);
    expect(find.text('Parent invitation could not be delivered'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Review guardian'), findsNothing);
    expect(find.text('View profile'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('guardian ID saves and reopens a city outside the lookup', (
    tester,
  ) async {
    wide(tester);
    final guardian = <String, dynamic>{
      'customGuardianId': 'GUA-1',
      'firstName': 'Ama',
      'lastName': 'Mensah',
      'householdId': 10,
      'isPrimary': true,
    };
    final proof = <String, dynamic>{
      'proofOfIDTypeId': 1,
      'idNumber': 'DEMO-ID',
      'issueDate': '2024-01-01',
      'expirationDate': '2030-01-01',
      'countryId': 2,
      'cityId': 1,
      'city': {'id': 1, 'name': 'Accra'},
    };
    Map<String, dynamic>? submitted;
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/directory')) {
          return json({'guardians': [guardian], 'studentCounts': {}});
        }
        if (path.endsWith('/guardians/GUA-1')) {
          return json({...guardian, 'proofOfID': proof});
        }
        if (path.endsWith('/proof-of-id')) {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          proof
            ..remove('city')
            ..remove('cityId')
            ..addAll(submitted!);
          return json(guardian);
        }
        if (path.endsWith('/proof-of-id-types')) {
          return json([{'id': 1, 'name': 'Passport'}]);
        }
        if (path.endsWith('/nationalities')) {
          return json([{'id': 2, 'countryName': 'United Kingdom'}]);
        }
        return json([]);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: HouseholdsGuardiansScreen(customSchoolId: 'SCHOOL', api: api),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('directory-row-household-10')));
    await tester.pumpAndSettle();

    Future<void> openIdEditor() async {
      final actions = find.byTooltip('More guardian actions');
      await tester.ensureVisible(actions);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit guardian'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardian ID').last);
      await tester.pumpAndSettle();
    }

    await openIdEditor();
    final city = find.widgetWithText(TextField, 'City of issue');
    await tester.ensureVisible(city);
    await tester.enterText(city, 'London');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(submitted?['cityName'], 'London');
    expect(submitted?.containsKey('cityId'), isFalse);
    await openIdEditor();
    expect(tester.widget<TextField>(city).controller!.text, 'London');
  });

  testWidgets('vaccination comments open on demand and retain their text', (
    tester,
  ) async {
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/context')) {
          return json({
            'baseVersion': 'v1',
            'student': {
              'customStudentId': 'STU-1',
              'householdId': 10,
              'status': 'DRAFT',
              'vaccinationRecords': [
                {'vaccinationId': 2, 'status': 'NO', 'notes': 'Prior note'},
              ],
            },
          });
        }
        if (path.endsWith('/vaccinations/default')) {
          return json([
            {'id': 1, 'name': 'BCG'},
            {'id': 2, 'name': 'Polio'},
          ]);
        }
        return json([]);
      }),
    );
    await editor(tester, api, initialStep: 3);
    final bcgComment = find.widgetWithText(TextField, 'Comment for BCG');
    final polioComment = find.widgetWithText(TextField, 'Comment for Polio');
    expect(bcgComment, findsNothing);
    expect(polioComment, findsNothing);
    expect(find.text('Add comment'), findsNothing);
    expect(find.text('Edit comment'), findsOneWidget);
    expect(find.text('Date received (optional)'), findsNothing);

    final yes = find.text('Yes').first;
    await tester.tap(yes);
    await tester.pumpAndSettle();
    expect(bcgComment, findsNothing);
    final addComment = find.text('Add comment');
    expect(addComment, findsOneWidget);
    expect(tester.getCenter(addComment).dy, closeTo(tester.getCenter(yes).dy, 1));
    expect(find.text('Date received (optional)'), findsOneWidget);

    await tester.tap(addComment);
    await tester.pumpAndSettle();
    expect(bcgComment, findsOneWidget);
    expect(polioComment, findsNothing);
    await tester.enterText(bcgComment, 'BCG card checked');
    await tester.tap(find.text('Hide comment'));
    await tester.pumpAndSettle();
    expect(bcgComment, findsNothing);

    await tester.tap(find.text('Edit comment').first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(bcgComment).controller!.text,
      'BCG card checked',
    );
    expect(polioComment, findsNothing);
  });

  testWidgets('medical condition notes stay collapsed until requested', (
    tester,
  ) async {
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/context')) {
          return json({
            'baseVersion': 'v1',
            'student': {
              'customStudentId': 'STU-1',
              'householdId': 10,
              'status': 'DRAFT',
              'medicalCondition': {
                'medicalConditions': [
                  {'conditionTypeId': 1, 'value': '1', 'notes': 'Prior note'},
                ],
              },
            },
          });
        }
        if (path.endsWith('/medical-conditions/default')) {
          return json([
            {'id': 1, 'name': 'Asthma'},
            {'id': 2, 'name': 'Diabetes'},
          ]);
        }
        return json([]);
      }),
    );
    await editor(tester, api, initialStep: 2);
    final saved = find.widgetWithText(TextField, 'Comment for Asthma');
    final added = find.widgetWithText(TextField, 'Comment for Diabetes');
    expect(saved, findsNothing);
    final yes = find.text('Yes').last;
    await tester.tap(yes);
    await tester.pumpAndSettle();
    expect(added, findsNothing);
    final addComment = find.text('Add comment');
    expect(addComment, findsOneWidget);
    expect(tester.getCenter(addComment).dy, closeTo(tester.getCenter(yes).dy, 1));
    await tester.tap(find.text('No').last);
    await tester.pumpAndSettle();
    expect(addComment, findsNothing);

    await tester.tap(find.text('Edit comment'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(saved).controller!.text, 'Prior note');
    expect(added, findsNothing);
  });

  testWidgets('household payment only appears for an eligible child', (
    tester,
  ) async {
    wide(tester);
    final students = [
      {'customStudentId': 'STU-1', 'firstName': 'Ama', 'status': 'PENDING_APPROVAL'},
      {'customStudentId': 'STU-2', 'firstName': 'Kojo', 'status': 'ACTIVE'},
      {'customStudentId': 'STU-3', 'firstName': 'Akosua', 'status': 'ACTIVE'},
    ];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/directory')) {
        return json({
          'guardians': [
            {
              'customGuardianId': 'GUA-1',
              'firstName': 'Demo',
              'lastName': 'Guardian',
              'householdId': 10,
              'isPrimary': true,
            },
          ],
          'studentCounts': {'10': 3},
        });
      }
      if (path.endsWith('/students/filter')) return json(students);
      if (path.contains('/current-term/')) {
        return json({'id': 1, 'startDate': '2026-09-01', 'endDate': '2026-12-31'});
      }
      if (path.endsWith('/fee-account')) {
        final assessed = !path.contains('/STU-2/');
        return json({
          'balance': assessed ? 100 : 0,
          'assessments': [
            if (assessed) {'assessmentId': 1, 'status': 'ACTIVE', 'amount': 100},
          ],
        });
      }
      return json(students.firstWhere((student) => path.endsWith('/${student['customStudentId']}')));
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HouseholdsGuardiansScreen(
            customSchoolId: 'SCHOOL',
            api: AdmissionsApiClient(accessToken: 'test', client: client),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('directory-row-household-10')));
      await tester.pumpAndSettle();
      expect(find.text('Fees not assessed'), findsOneWidget);
      expect(find.byKey(const Key('split-household-payment')), findsOneWidget);

      final menus = find.byTooltip('More child actions');
      expect(menus, findsNWidgets(3));
      for (var index = 0; index < 3; index++) {
        await tester.ensureVisible(menus.at(index));
        await tester.tap(menus.at(index));
        await tester.pumpAndSettle();
        expect(find.text('Receive payment'), findsNWidgets(index == 2 ? 2 : 1));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
    }, () => client);
  });

  for (final count in [1, 3]) {
    testWidgets('shows and explicitly selects all $count household addresses', (
      tester,
    ) async {
      Map<String, dynamic>? submitted;
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/context')) {
            return json({
              'baseVersion': 'v1',
              'student': {
                'customStudentId': 'STU-1',
                'householdId': 10,
                'status': 'DRAFT',
              },
            });
          }
          if (request.url.path.endsWith('/addresses')) {
            return json(List.generate(count, (i) => address(i + 1)));
          }
          if (request.url.path.endsWith('/preview')) {
            return json({'requiresApproval': false, 'before': {}});
          }
          if (request.method == 'POST') {
            submitted = jsonDecode(request.body);
            return json({'status': 'APPLIED'});
          }
          return json([]);
        }),
      );
      await editor(tester, api);
      for (var id = 1; id <= count; id++) {
        expect(find.text('Guardian $id'), findsOneWidget);
        expect(find.text('$id · Street $id · Town $id'), findsOneWidget);
      }
      expect(find.text('Enter another address'), findsOneWidget);
      final tile = tester.widget<RadioListTile<int>>(
        find.byKey(ValueKey('household-address-G-$count-$count')),
      );
      expect(tile.groupValue, isNull);
      await tester.tap(
        find.byKey(ValueKey('household-address-G-$count-$count')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review changes'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for this change'),
        'Use selected household address',
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(submitted?['sections']['address'], {
        'useHouseholdAddress': true,
        'householdAddressId': count,
      });
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('typed city saves without a suggestion and hydrates on reopen', (
    tester,
  ) async {
    final savedAddress = <String, dynamic>{
      'regionId': 1,
      'districtId': 2,
      'cityId': 3,
      'cityName': 'Accra',
      'houseNumber': '10',
      'streetName': 'Main Street',
      'ghanaPostAddress': 'GA-100',
      'additionalDirection': 'Near school',
      'howLongStayedInCurrentAddress': '1-3 years',
    };
    Map<String, dynamic>? submitted;
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/context')) {
          return json({
            'baseVersion': 'v1',
            'student': {
              'customStudentId': 'STU-1',
              'householdId': 10,
              'status': 'DRAFT',
              'address': savedAddress,
            },
          });
        }
        if (path.endsWith('/addresses')) return json([address(1)]);
        if (path.endsWith('/regions')) {
          return json([
            {'id': 1, 'name': 'Region'},
          ]);
        }
        if (path.endsWith('/districts')) {
          return json([
            {'id': 2, 'name': 'District'},
          ]);
        }
        if (path.endsWith('/preview')) {
          return json({'requiresApproval': false, 'before': {}});
        }
        if (request.method == 'POST') {
          submitted = jsonDecode(request.body);
          return json({'status': 'APPLIED'});
        }
        return json([]);
      }),
    );
    await editor(tester, api);
    final city = find.widgetWithText(TextField, 'City / town');
    await tester.ensureVisible(city);
    await tester.enterText(city, 'My New Town');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review changes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for this change'),
      'Correct town spelling',
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final payload = Map<String, dynamic>.from(
      submitted?['sections']['address'],
    );
    expect(payload['cityName'], 'My New Town');
    expect(payload.containsKey('cityId'), false);
    savedAddress.remove('cityId');
    savedAddress.addAll(payload);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'City / town'))
          .controller!
          .text,
      'My New Town',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('admission source hydrates and Other details are submitted', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/record-changes/context')) {
          return json({
            'baseVersion': 'v1',
            'student': {
              'customStudentId': 'STU-1',
              'householdId': 10,
              'status': 'DRAFT',
              'firstName': 'Ama',
              'lastName': 'Mensah',
              'dateOfBirth': '2016-02-03',
              'gradeLevelId': 1,
              'schoolGradeLevelId': 11,
              'genderId': 2,
              'religion': {'id': 3, 'religionName': 'Christian'},
              'languageSpoken': ['English'],
              'admissionSource': 'PARENT_GUARDIAN_REFERRAL',
            },
          });
        }
        if (path == '/api/grade-levels/school/SCHOOL') {
          return json([
            {'gradeLevelId': 1, 'gradeName': 'Basic 1', 'id': 11},
          ]);
        }
        if (path.endsWith('/streams')) return json([]);
        if (path.endsWith('/genders')) {
          return json([
            {'id': 2, 'name': 'Female'},
          ]);
        }
        if (path.endsWith('/religions')) {
          return json([
            {'id': 3, 'name': 'Christian'},
          ]);
        }
        if (path.endsWith('/languages')) {
          return json([
            {'id': 4, 'name': 'English'},
          ]);
        }
        if (path.endsWith('/record-changes/preview')) {
          return json({'requiresApproval': false, 'before': {}});
        }
        if (path.endsWith('/record-changes') && request.method == 'POST') {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return json({'status': 'APPLIED'});
        }
        return json([]);
      }),
    );

    await editor(tester, api, initialStep: 0);
    final source = find.byKey(const Key('admission-source'));
    expect(source, findsOneWidget);
    expect(
      find.text('How did the family hear about the school? *'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Choose the first source the family remembers. This is used for admissions reporting.',
      ),
      findsNothing,
    );
    expect(
      tester.widget<DropdownButtonFormField<String>>(source).initialValue,
      'PARENT_GUARDIAN_REFERRAL',
    );

    await tester.ensureVisible(source);
    await tester.pumpAndSettle();
    await tester.tap(source);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Please specify *'),
      'Neighbourhood banner',
    );
    await tester.tap(find.text('Review changes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason for this change'),
      'Record the admission source',
    );
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final basic = Map<String, dynamic>.from(
      submitted?['sections']['basic'] as Map,
    );
    expect(basic['admissionSource'], 'OTHER');
    expect(basic['admissionSourceOther'], 'Neighbourhood banner');
    expect(tester.takeException(), isNull);
  });

  testWidgets('applied dates sort backend timestamps by day and time', (
    tester,
  ) async {
    wide(tester);
    final timestamps = <String, Object?>{
      'Z': [2026, 9, 30, 18, 20],
      'M': null,
      'A': [2026, 10, 1, 8, 12, 0, 200000000],
      'B': '2026-10-01T08:12:00.100',
    };
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((request) async {
        if (request.url.path.contains('current-term')) {
          return json({
            'id': 1,
            'startDate': '2026-09-01',
            'endDate': '2026-12-11',
          });
        }
        return json({
          'content': [
            for (final entry in timestamps.entries)
              {
                'customStudentId': entry.key,
                'firstName': 'Student ${entry.key}',
                'createdAt': entry.value,
                'status': 'DRAFT',
              },
          ],
        });
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AdmissionsScreen(customSchoolId: 'SCHOOL', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    List<String> rowOrder() {
      final ids = timestamps.keys.toList();
      double rowY(String id) => tester
          .getTopLeft(find.byKey(ValueKey('admission-row-$id')))
          .dy;
      ids.sort((first, second) => rowY(first).compareTo(rowY(second)));
      return ids;
    }

    expect(find.text('30 Sep 2026'), findsOneWidget);
    expect(find.text('1 Oct 2026'), findsNWidgets(2));
    expect(rowOrder(), ['A', 'B', 'Z', 'M']);
    await tester.tap(find.byKey(const ValueKey('sort-Applied')));
    await tester.pumpAndSettle();
    expect(rowOrder(), ['Z', 'B', 'A', 'M']);
    await tester.tap(find.byKey(const ValueKey('sort-Applied')));
    await tester.pumpAndSettle();
    expect(rowOrder(), ['A', 'B', 'Z', 'M']);
  });

  testWidgets(
    'admissions update across clients and every column sorts both ways',
    (tester) async {
      wide(tester);
      var added = false;
      var loads = 0;
      final rows = [
        {
          'customStudentId': 'A',
          'firstName': 'Amy',
          'guardianName': 'Alice',
          'gradeLevelName': 'Basic 1',
          'personType': 'APPLICANT',
          'createdAt': '2026-08-26',
          'status': 'ACTIVE',
        },
        {
          'customStudentId': 'Z',
          'firstName': 'Zoe',
          'guardianName': 'Zack',
          'gradeLevelName': 'KG1',
          'personType': 'STUDENT',
          'createdAt': '2026-08-28',
          'status': 'DRAFT',
        },
      ];
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          if (request.url.path.contains('current-term')) {
            return json({
              'id': 1,
              'startDate': '2026-08-25',
              'endDate': '2026-12-11',
            });
          }
          loads++;
          return json({
            'content': [
              ...rows,
              if (added)
                {
                  'customStudentId': 'N',
                  'firstName': 'New Student',
                  'createdAt': '2026-08-30',
                  'status': 'DRAFT',
                },
            ],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AdmissionsScreen(customSchoolId: 'SCHOOL', api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Applicant',
        'Guardian',
        'Applying for',
        'Type',
        'Applied',
        'Status',
      ]) {
        for (final ascending in [true, false]) {
          await tester.tap(find.byKey(ValueKey('sort-$label')));
          await tester.pumpAndSettle();
          final ay = tester
              .getTopLeft(find.byKey(const ValueKey('admission-row-A')))
              .dy;
          final zy = tester
              .getTopLeft(find.byKey(const ValueKey('admission-row-Z')))
              .dy;
          expect(ay < zy, ascending, reason: '$label ascending=$ascending');
        }
      }
      final otherClient = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          added = true;
          return json({'customStudentId': 'N'});
        }),
      );
      await otherClient.createStudent(
        customSchoolId: 'SCHOOL',
        householdId: 10,
        body: {},
      );
      await tester.pumpAndSettle();
      expect(find.text('New Student'), findsOneWidget);
      expect(loads, 2);
      await otherClient.createStudent(
        customSchoolId: 'OTHER',
        householdId: 10,
        body: {},
      );
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student documents upload, replace, view and confirmed deletion refresh immediately',
    (tester) async {
      wide(tester);
      var hasDocument = false;
      var uploads = 0, deletes = 0, views = 0, changes = 0;
      const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => [
              {
                'name': 'certificate.pdf',
                'size': 4,
                'bytes': Uint8List.fromList([1, 2, 3, 4]),
                'path': '/test/certificate.pdf',
              },
            ],
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            uploads++;
            hasDocument = true;
            return json('uploaded');
          }
          if (request.method == 'DELETE') {
            deletes++;
            hasDocument = false;
            return json({});
          }
          if (request.url.path.contains('download-url')) {
            views++;
            return json({'downloadUrl': 'https://example.test/document.pdf'});
          }
          return json({
            'documents': [
              if (hasDocument)
                {
                  'documentId': 'D1',
                  'documentType': 'BIRTH_CERTIFICATE',
                  'fileName': 'certificate.pdf',
                  'fileUrl': 'stored-file',
                  'status': 'ACTIVE',
                },
            ],
          });
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StudentDocumentsPanel(
                api: api,
                customSchoolId: 'SCHOOL',
                customStudentId: 'STU-1',
                onChanged: () => changes++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Upload'), findsNWidgets(4));
      await tester.tap(find.text('Upload').at(1));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for this change'),
        'Add birth certificate',
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(find.text('certificate.pdf'), findsOneWidget);
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for this change'),
        'Replace clearer copy',
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(uploads, 2);
      await tester.tap(find.byTooltip('View document'));
      await tester.pumpAndSettle();
      expect(views, 1);
      await tester.tap(find.byTooltip('Remove document'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      await tester.tap(find.byTooltip('Remove document'));
      await tester.pumpAndSettle();
      expect(find.text('Delete certificate.pdf?'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason for this change'),
        'Remove outdated document',
      );
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(deletes, 1);
      expect(changes, 3);
      expect(find.text('certificate.pdf'), findsNothing);
      expect(find.text('Upload'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student profile has household header action and member profile actions',
    (tester) async {
      wide(tester);
      final student = (await tester.runAsync(
        () => const FakeStudentsRepository().getStudent('STU-FA1BC0-9043'),
      ))!;
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((_) async => json([])),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StudentProfileView(
              term: 'First Term',
              academicYear: '2026-2027',
              student: student,
              onBack: () {},
              onOpenStudent: (_) {},
              admissionsApi: api,
              customSchoolId: 'SCHOOL',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open-student-household')), findsOneWidget);
      expect(find.text('Open household'), findsOneWidget);
      expect(
        find.text('View profile'),
        findsNWidgets(student.householdMembers.length),
      );
      await tester.tap(find.byKey(const Key('student-tab-documents')));
      await tester.pumpAndSettle();
      expect(find.byType(StudentDocumentsPanel), findsOneWidget);
    },
  );
}
