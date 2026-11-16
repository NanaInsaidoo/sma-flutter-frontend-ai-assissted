import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';
import 'package:school_management_app/src/admissions/domain/guardian_directory.dart';
import 'package:school_management_app/src/admissions/presentation/guardian_directory_search.dart';
import 'package:school_management_app/src/admissions/presentation/admissions_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

Map<String, dynamic> directoryJson(int count) => {
  'guardians': List.generate(
    count,
    (i) => {
      'customGuardianId': 'G-$i',
      'firstName': 'Guardian',
      'lastName': '$i',
      'householdId': i ~/ 2 + 1,
      'householdName': 'Household ${(i ~/ 2 + 1).toString().padLeft(5, '0')}',
      'isPrimary': i.isEven,
      'status': 'ACTIVE',
      'phoneNumbers': ['020${i.toString().padLeft(7, '0')}'],
    },
  ),
  'studentCounts': {'1': 401},
};

void main() {
  test(
    'complete directory retains 1000 guardians and accurate student counts',
    () {
      final directory = SchoolGuardianDirectory.fromJson(directoryJson(1000));
      expect(directory.guardians.length, 1000);
      expect(directory.households.length, 500);
      expect(directory.households.first.studentCount, 401);
      final household = directory.households.singleWhere(
        (h) => h.matches('G-999'),
      );
      expect(household.id, 500);
      expect(household.contactFor('G-999').isPrimary, false);
      expect(household.matches('020 000 0999'), true);
      expect(household.matches('500'), true);
    },
  );

  test('guardians without a household or phone remain available', () {
    final directory = SchoolGuardianDirectory.fromJson({
      'guardians': [
        {'customGuardianId': 'ORPHAN', 'firstName': 'Unlinked'},
      ],
      'studentCounts': {},
    });
    expect(directory.households.single.id, isNull);
    expect(directory.households.single.matches('Unlinked'), true);
    expect(directory.guardians.single.phone, '');
    expect(
      directory.households.single.guardianSetup,
      GuardianSetupStatus.noHouseholdLinked,
    );
  });

  test('guardian setup is complete once all linked guardians are approved', () {
    GuardianSetupStatus setup(List<String> statuses) =>
        GuardianSetupStatus.fromGuardians(
          householdId: 1,
          guardianStatuses: statuses,
        );

    expect(setup([]), GuardianSetupStatus.detailsIncomplete);
    expect(
      setup(['DRAFT', 'PENDING_REVIEW']),
      GuardianSetupStatus.detailsIncomplete,
    );
    expect(
      setup(['APPROVED', 'pending_approval']),
      GuardianSetupStatus.awaitingApproval,
    );
    expect(setup(['APPROVED', 'REJECTED']), GuardianSetupStatus.needsAttention);
    expect(setup(['APPROVED', 'APPROVED']), GuardianSetupStatus.complete);
  });

  testWidgets('guardian setup filters households independently of student count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = AdmissionsApiClient(
      accessToken: 'test',
      client: MockClient((_) async => http.Response(
        jsonEncode({
          'guardians': [
            for (final (id, name, status) in [
              (1, 'Adu', 'APPROVED'),
              (2, 'Boateng', 'APPROVED'),
              (3, 'Mensah', 'PENDING_REVIEW'),
              (4, 'Ofori', 'DRAFT'),
              (5, 'Tetteh', 'REJECTED'),
            ])
              {
                'customGuardianId': 'G-$id',
                'firstName': name,
                'householdId': id,
                'isPrimary': true,
                'status': status,
              },
            {'customGuardianId': 'UNLINKED', 'firstName': 'Unlinked'},
          ],
          'studentCounts': {'2': 3, '4': 2},
        }),
        200,
      )),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: HouseholdsGuardiansScreen(customSchoolId: 'SCHOOL', api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GUARDIAN SETUP'), findsOneWidget);

    Finder household(int id) => find.byKey(ValueKey('directory-row-household-$id'));
    Finder badge(int id, String label) =>
        find.descendant(of: household(id), matching: find.text(label));
    expect(badge(1, 'Complete'), findsOneWidget);
    expect(badge(2, 'Complete'), findsOneWidget);
    expect(badge(3, 'Awaiting approval'), findsOneWidget);
    expect(badge(4, 'Details incomplete'), findsOneWidget);
    expect(badge(5, 'Needs attention'), findsOneWidget);
    expect(find.text('No household linked'), findsOneWidget);

    final filter = find.byKey(const Key('guardian-setup-filter'));
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete').last);
    await tester.pumpAndSettle();
    expect(household(1), findsOneWidget);
    expect(household(2), findsOneWidget);
    expect(household(3), findsNothing);

    await tester.enterText(find.byType(TextField), 'Boateng');
    await tester.pumpAndSettle();
    expect(household(1), findsNothing);
    expect(household(2), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All statuses').last);
    await tester.pumpAndSettle();
    expect(household(3), findsOneWidget);
  });

  test(
    'API loads summaries in one request without page or size caps',
    () async {
      final requests = <http.Request>[];
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.url.path, endsWith('/schools/SCHOOL/directory'));
          expect(request.url.queryParameters, isEmpty);
          return http.Response(jsonEncode(directoryJson(1000)), 200);
        }),
      );
      final directory = await api.getGuardianDirectory('SCHOOL');
      expect(directory.guardians.length, 1000);
      expect(requests.length, 1);
    },
  );

  test(
    'failed or malformed loads are not replaced with truncated legacy lists',
    () async {
      for (final response in [
        http.Response('{}', 200),
        http.Response('Unavailable', 503),
      ]) {
        var requests = 0;
        final api = AdmissionsApiClient(
          accessToken: 'test',
          client: MockClient((request) async {
            requests++;
            return response;
          }),
        );
        await expectLater(
          api.getGuardianDirectory('SCHOOL'),
          throwsA(isA<AdmissionsApiException>()),
        );
        expect(requests, 1);
      }
    },
  );

  testWidgets(
    '5000-guardian picker builds visible rows and finds a late secondary guardian',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      GuardianDirectoryHousehold? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: GuardianDirectorySearch(
              directory: SchoolGuardianDirectory.fromJson(directoryJson(5000)),
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(30));
      expect(
        find.byKey(const ValueKey('directory-household-2500')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const Key('guardian-directory-search')),
        'G-4999',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Guardian 4999'), findsOneWidget);
      expect(
        find.textContaining('Primary guardian: Guardian 4998'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('directory-household-2500')));
      expect(selected?.id, 2500);
      await tester.enterText(
        find.byKey(const Key('guardian-directory-search')),
        'does not exist',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No matching guardian'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('guardian-directory-search')),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(30));
    },
  );

  testWidgets(
    'household screen uses the directory only and searches secondary guardians beyond old cap',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.url.path, endsWith('/schools/SCHOOL/directory'));
          return http.Response(jsonEncode(directoryJson(1000)), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HouseholdsGuardiansScreen(customSchoolId: 'SCHOOL', api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      expect(
        find.byKey(const ValueKey('directory-row-household-500')),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), 'G-999');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('directory-row-household-500')),
        findsOneWidget,
      );
      expect(find.textContaining('Matched: Guardian 999'), findsOneWidget);
      expect(requests.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
