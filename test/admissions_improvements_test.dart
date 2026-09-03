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

Future<void> editor(WidgetTester tester, AdmissionsApiClient api) async {
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
              initialStep: 1,
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
