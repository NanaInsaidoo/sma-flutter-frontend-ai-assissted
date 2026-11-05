import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/platform/data/live_platform_repository.dart';
import 'package:school_management_app/src/platform/data/platform_api_client.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';
import 'package:school_management_app/src/platform/presentation/school_creation_screen.dart';

import 'support/fake_platform_repository.dart';

void main() {
  testWidgets(
    'hydrates, edits and sends both Other descriptions with permanent IDs',
    (tester) async {
      final repository = await _pumpRegistration(tester);
      expect(
        _controller(tester, 'Specify GES registration type').text,
        'Existing GES type',
      );
      expect(
        _controller(tester, 'Specify business registration type').text,
        'Existing business type',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Specify GES registration type')),
        '  Test education permit  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('Specify business registration type')),
        '  Test school trust  ',
      );
      await _save(tester);
      final draft = repository.savedDraft!;
      expect(draft.gesRegistrationTypeOther, 'Test education permit');
      expect(draft.businessRegistrationTypeOther, 'Test school trust');
      final body = await _requestBody(draft);
      expect(body['gesRegistrationType'], {'id': 5});
      expect(body['businessRegistrationType'], {'id': 9});
      expect(body['registrationTypeOther'], 'Test education permit');
      expect(body['businessRegistrationTypeOther'], 'Test school trust');
    },
  );

  testWidgets('both Other descriptions are required before saving', (
    tester,
  ) async {
    final repository = await _pumpRegistration(
      tester,
      gesOther: ' ',
      businessOther: '',
    );
    await _save(tester);
    expect(repository.savedDraft, isNull);
    expect(
      find.text('Specify the type when selecting Other.'),
      findsNWidgets(2),
    );
  });

  testWidgets(
    'switching to standard types hides and clears descriptions in the request',
    (tester) async {
      final repository = await _pumpRegistration(tester);
      await _select(tester, 'GES registration type', 'Private School');
      await _select(
        tester,
        'Business registration type',
        'Sole Proprietorship',
      );
      expect(
        find.byKey(const ValueKey('Specify GES registration type')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('Specify business registration type')),
        findsNothing,
      );
      await _save(tester);
      final draft = repository.savedDraft!;
      expect(draft.gesRegistrationTypeOther, isEmpty);
      expect(draft.businessRegistrationTypeOther, isEmpty);
      final body = await _requestBody(draft);
      expect(body['gesRegistrationType'], {'id': 1});
      expect(body['businessRegistrationType'], {'id': 1});
      expect(body['registrationTypeOther'], isNull);
      expect(body['businessRegistrationTypeOther'], isNull);
    },
  );

  testWidgets('rejects descriptions over 200 characters without saving', (
    tester,
  ) async {
    final repository = await _pumpRegistration(tester, gesOther: 'x' * 201);
    await _save(tester);
    expect(repository.savedDraft, isNull);
    expect(find.text('Use 200 characters or fewer.'), findsOneWidget);
  });

  testWidgets(
    'accepts the 200 character boundary and preserves hidden drafts on reselect',
    (tester) async {
      final repository = await _pumpRegistration(tester, gesOther: 'x' * 200);
      await _select(tester, 'GES registration type', 'Private School');
      await _select(tester, 'GES registration type', 'Other');
      expect(
        _controller(tester, 'Specify GES registration type').text,
        'x' * 200,
      );
      await _save(tester);
      expect(repository.savedDraft!.gesRegistrationTypeOther, 'x' * 200);
    },
  );
}

TextEditingController _controller(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(find.byKey(ValueKey(label))).controller!;

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, String label, String value) async {
  final dropdown = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<Map<String, dynamic>> _requestBody(SchoolOnboardingDraft draft) async {
  Map<String, dynamic>? sent;
  final repository = LivePlatformRepository(
    accessToken: 'test-token',
    client: MockClient((request) async {
      expect(request.method, 'PUT');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-OTHER',
          'currentStep': 'REGISTRATION_DETAILS',
          'completedSteps': ['BASIC_INFO', 'REGISTRATION_DETAILS'],
        }),
        200,
      );
    }),
  );
  await repository.saveSchoolOnboardingStep(stepIndex: 1, draft: draft);
  return sent!['registrationDetails'] as Map<String, dynamic>;
}

Future<_RegistrationRepository> _pumpRegistration(
  WidgetTester tester, {
  String gesOther = 'Existing GES type',
  String businessOther = 'Existing business type',
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _RegistrationRepository();
  const lookups = SchoolCreationLookups(
    gesRegistrationTypes: ['Private School', 'Other'],
    gesRegistrationTypeIds: {'Private School': 1, 'Other': 5},
    businessRegistrationTypes: ['Sole Proprietorship', 'Other'],
    businessRegistrationTypeIds: {'Sole Proprietorship': 1, 'Other': 9},
    schoolCategories: [],
    schoolCategoryIds: {},
    educationLevels: [],
    educationLevelIds: {},
    socialWelfareStatuses: [],
    socialWelfareStatusIds: {},
    countries: [],
    countryIds: {},
    regions: [],
    regionIds: {},
    academicYears: [],
    academicYearIds: {},
    termTypes: [],
    termTypeIds: {},
    socialMediaPlatforms: [],
    socialMediaPlatformIds: {},
    eventTypes: [],
    eventTypeIds: {},
    gradeLevels: [],
    gradeLevelIds: {},
    cities: [],
    cityIds: {},
    districts: [],
    districtIds: {},
  );
  final record = SchoolOnboardingRecord(
    data: {
      'customSchoolId': 'SCH-OTHER',
      'schoolName': 'Registration Test School',
      'registrationStatus': 'IN_PROGRESS',
      'currentStep': 'REGISTRATION_DETAILS',
      'completedSteps': ['BASIC_INFO'],
      'registrationDetails': {
        'registrationNumberGes': 'TEST-GES',
        'registrationType': {'id': 5, 'name': 'Other'},
        'registrationTypeOther': gesOther,
        'gesRegistrationDate': '2026-01-01',
        'businessRegistrationNumber': 'TEST-BRN',
        'businessRegistrationType': {'id': 9, 'name': 'Other'},
        'businessRegistrationTypeOther': businessOther,
        'businessRegistrationDate': '2026-01-01',
        'gemisCode': 'TEST-GEMIS',
        'taxIdNumber': 'TEST-TIN',
      },
    },
    progress: const SchoolOnboardingProgress(
      customSchoolId: 'SCH-OTHER',
      registrationStatus: 'IN_PROGRESS',
      currentStep: 'REGISTRATION_DETAILS',
      completedSteps: ['BASIC_INFO'],
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SchoolCreationScreen(
          accessToken: 'preview',
          onRefreshAccessToken: () async => null,
          repository: repository,
          existingSchool: _school,
          initialStep: 1,
          singleStepEdit: true,
          initialRecord: record,
          initialLookups: lookups,
          lookupLoader: () async => lookups,
          onBack: () {},
          onCreated: () {},
          onStepUpdated: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

class _RegistrationRepository extends FakePlatformRepository {
  SchoolOnboardingDraft? savedDraft;
  @override
  Future<SchoolOnboardingProgress> saveSchoolOnboardingStep({
    required int stepIndex,
    required SchoolOnboardingDraft draft,
  }) async {
    savedDraft = draft;
    return const SchoolOnboardingProgress(
      customSchoolId: 'SCH-OTHER',
      registrationStatus: 'IN_PROGRESS',
      currentStep: 'REGISTRATION_DETAILS',
      completedSteps: ['BASIC_INFO', 'REGISTRATION_DETAILS'],
    );
  }
}

const _school = ManagedSchool(
  name: 'Registration Test School',
  code: 'SCH-OTHER',
  region: '',
  district: '',
  town: '',
  students: 0,
  staff: 0,
  status: SchoolStatus.inProgress,
  progress: .1,
  accountManager: '',
  subscriptionPlan: 'Trial',
  subscriptionStatus: 'IN_PROGRESS',
  renewalDate: '',
  lastActive: '',
  approvedDate: '',
  administratorName: '',
  administratorPhone: '',
  administratorEmail: '',
);
