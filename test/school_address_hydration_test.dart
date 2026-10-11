import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/platform/data/platform_api_client.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';
import 'package:school_management_app/src/platform/presentation/school_creation_screen.dart';

import 'support/fake_platform_repository.dart';

void main() {
  testWidgets('hydrates the live district and address response', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: _AddressRepository(),
            existingSchool: _school,
            initialStep: 3,
            initialLookups: _addressLookups,
            lookupLoader: () async => _addressLookups,
            initialRecord: _addressRecord,
            onBack: () {},
            onCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    void expectFieldValue(String label, String expected) {
      final textFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );
      if (textFieldFinder.evaluate().isNotEmpty) {
        expect(textFieldFinder, findsOneWidget);
        expect(
          tester.widget<TextField>(textFieldFinder).controller?.text ?? '',
          expected,
        );
        return;
      }
      final formFieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.controller?.text == expected,
      );
      if (formFieldFinder.evaluate().isNotEmpty) {
        expect(formFieldFinder, findsOneWidget, reason: 'Expected $label');
        return;
      }
      final visibleTextFinder = find.text(expected);
      if (visibleTextFinder.evaluate().isNotEmpty) {
        expect(visibleTextFinder, findsWidgets, reason: 'Expected $label');
        return;
      }
      expect(formFieldFinder, findsOneWidget, reason: 'Expected $label');
    }

    expectFieldValue('House number', '113');
    expectFieldValue('Street name', '02');
    expectFieldValue('City', 'Multan');
    expectFieldValue('District', 'Bongo');
    expect(find.text('Upper East'), findsOneWidget);
    expectFieldValue('Additional directions', 'Direction');
    expectFieldValue('Ghana Post address', 'GA-123-4567');
  });

  testWidgets('detailed onboarding step overrides stale school-list progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: _GradeRepository(),
            existingSchool: _school,
            onBack: () {},
            onCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 streams selected'), findsOneWidget);
  });

  testWidgets('phone numbers and emails use repeatable contact rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: _ContactRepository(),
            existingSchool: _school,
            initialStep: 4,
            initialLookups: _addressLookups,
            lookupLoader: () async => _addressLookups,
            initialRecord: _contactRecord,
            onBack: () {},
            onCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Primary phone number'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);
    expect(find.text('Email address 1 (optional)'), findsOneWidget);
    expect(find.text('Email address 2 (optional)'), findsOneWidget);
    expect(find.text('Add another phone'), findsOneWidget);
    expect(find.text('Add another email'), findsOneWidget);
    expect(find.text('Uses WhatsApp'), findsNWidgets(2));
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('Phone WhatsApp 0')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const ValueKey('Phone type 0')),
          )
          .initialValue,
      'mobile',
    );

    await tester.ensureVisible(find.text('Add another phone'));
    await tester.tap(find.text('Add another phone'));
    await tester.pump();
    expect(find.byKey(const ValueKey('Phone number 2')), findsOneWidget);
  });

  testWidgets('class structure excludes senior secondary grades', (
    tester,
  ) async {
    final lookups = SchoolCreationLookups.empty().copyWith(
      gradeLevels: const ['JHS 3', 'SHS 1', 'Senior Secondary 2'],
      gradeLevelIds: const {'JHS 3': 10, 'SHS 1': 11, 'Senior Secondary 2': 12},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: _GradeRepository(),
            existingSchool: _school,
            initialStep: 6,
            initialLookups: lookups,
            lookupLoader: () async => lookups,
            initialRecord: _gradeRecord,
            initialGradeLevels: const [
              SchoolGradeLevelInfo(
                gradeLevelId: 10,
                gradeLevelName: 'JHS 3',
                numberOfStreams: 1,
              ),
              SchoolGradeLevelInfo(
                gradeLevelId: 11,
                gradeLevelName: 'SHS 1',
                numberOfStreams: 2,
              ),
            ],
            onBack: () {},
            onCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 grades selected'), findsOneWidget);
    expect(find.text('JHS 3'), findsOneWidget);
    expect(find.text('SHS 1'), findsNothing);
    expect(find.text('Senior Secondary 2'), findsNothing);
    expect(find.text('Senior High School'), findsNothing);
  });

  testWidgets('class structure creates and selects a custom class', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lookups = SchoolCreationLookups.empty().copyWith(
      gradeLevels: const ['KG1', 'KG2', 'Basic 1'],
      gradeLevelIds: const {'KG1': 1, 'KG2': 2, 'Basic 1': 3},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: _GradeRepository(),
            existingSchool: _school,
            initialStep: 6,
            initialLookups: lookups,
            lookupLoader: () async => lookups,
            initialRecord: _gradeRecord,
            initialGradeLevels: const [
              SchoolGradeLevelInfo(
                gradeLevelId: 1,
                gradeLevelName: 'KG1',
                numberOfStreams: 1,
              ),
            ],
            onBack: () {},
            onCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add custom class'), findsOneWidget);
    expect(find.text('Add New'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-custom-grade-level')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-grade-name')),
      'Nursery 1',
    );
    await tester.tap(find.byKey(const ValueKey('create-custom-grade-level')));
    await tester.pumpAndSettle();

    expect(find.text('Nursery 1'), findsOneWidget);
    expect(find.text('Custom classes'), findsOneWidget);
    expect(find.text('GES kindergarten'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Custom classes')).dy,
      lessThan(tester.getTopLeft(find.text('GES kindergarten')).dy),
    );
    expect(find.text('CUSTOM CLASS · KG SUBJECTS SUGGESTED'), findsNothing);
    expect(find.text('2 grades selected'), findsOneWidget);
  });

  testWidgets(
    'term setup omits term description and requires attendance answer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SchoolCreationScreen(
              accessToken: 'preview',
              onRefreshAccessToken: () async => null,
              repository: _GradeRepository(),
              existingSchool: _school,
              initialStep: 7,
              initialLookups: SchoolCreationLookups.empty(),
              lookupLoader: () async => SchoolCreationLookups.empty(),
              initialRecord: _termRecord,
              onBack: () {},
              onCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Description'), findsNothing);
      expect(
        find.text('Are students expected to attend school? *'),
        findsOneWidget,
      );
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      await tester.tap(find.textContaining('Continue'));
      await tester.pump();
      expect(find.text('Select Yes or No'), findsOneWidget);

      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pump();
      expect(find.text('Select Yes or No'), findsNothing);
    },
  );

  testWidgets('education level replaces the redundant school category', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _BasicInfoRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: repository,
            existingSchool: _school,
            initialStep: 0,
            singleStepEdit: true,
            initialLookups: _basicInfoLookups,
            lookupLoader: () async => _basicInfoLookups,
            initialRecord: _basicInfoRecord,
            onBack: () {},
            onCreated: () {},
            onStepUpdated: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('School category'), findsNothing);
    expect(find.text('Education level'), findsOneWidget);
    expect(find.text('Junior High'), findsOneWidget);
    final mottoField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('school-motto')),
        matching: find.byType(TextField),
      ),
    );
    expect(mottoField.minLines, 2);
    expect(mottoField.maxLines, 4);
    expect(mottoField.maxLength, 160);

    await tester.tap(find.text('Junior High'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primary').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(repository.savedDraft, isNotNull);
    expect(repository.savedDraft!.educationLevel, 'Primary');
    expect(repository.savedDraft!.educationLevelId, 2);
    expect(repository.savedDraft!.schoolType, 'Primary');
    expect(repository.savedDraft!.schoolTypeId, 2);
  });

  testWidgets('social welfare step can be saved without any details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _BasicInfoRepository();
    const lookups = _basicInfoLookups;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: repository,
            existingSchool: _school,
            initialStep: 2,
            singleStepEdit: true,
            initialLookups: lookups,
            lookupLoader: () async => lookups,
            initialRecord: _socialWelfareRecord,
            onBack: () {},
            onCreated: () {},
            onStepUpdated: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Optional approval and compliance details. These can be added later.',
      ),
      findsOneWidget,
    );
    expect(find.text('Approval officer name (optional)'), findsOneWidget);
    expect(find.text('Approval date (optional)'), findsOneWidget);
    expect(find.text('Compliance status (optional)'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('highlighted required fields'), findsNothing);
    expect(repository.savedDraft, isNotNull);
    expect(repository.savedDraft!.socialWelfareNumber, isEmpty);
    expect(repository.savedDraft!.socialWelfareOfficer, isEmpty);
    expect(repository.savedDraft!.socialWelfareDate, isEmpty);
    expect(repository.savedDraft!.socialWelfareStatusId, isNull);
  });

  testWidgets('all supporting documents are optional', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _BasicInfoRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchoolCreationScreen(
            accessToken: 'preview',
            onRefreshAccessToken: () async => null,
            repository: repository,
            existingSchool: _school,
            initialStep: 5,
            singleStepEdit: true,
            initialLookups: _basicInfoLookups,
            lookupLoader: () async => _basicInfoLookups,
            initialRecord: _socialWelfareRecord,
            onBack: () {},
            onCreated: () {},
            onStepUpdated: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Supporting Documents'), findsWidgets);
    expect(
      find.text('Add registration and compliance documents now or later.'),
      findsOneWidget,
    );
    expect(find.text('Required'), findsNothing);
    expect(find.text('Social welfare approval'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Upload the required documents before continuing'),
      findsNothing,
    );
    expect(repository.savedDraft, isNotNull);
    expect(repository.savedDraft!.documents, isEmpty);
  });
}

const _school = ManagedSchool(
  name: 'Address Test School',
  code: 'SCH-ADDRESS',
  region: 'Upper East',
  district: 'Bongo',
  town: 'Multan',
  students: 0,
  staff: 0,
  status: SchoolStatus.inProgress,
  progress: .44,
  accountManager: 'Test Manager',
  subscriptionPlan: 'Trial',
  subscriptionStatus: 'IN_PROGRESS',
  renewalDate: '',
  lastActive: '',
  approvedDate: '',
  administratorName: '',
  administratorPhone: '',
  administratorEmail: '',
);

const _basicInfoLookups = SchoolCreationLookups(
  schoolCategories: [
    'Kindergarten',
    'Primary',
    'Junior High School',
    'Basic School (KG-Primary-JHS)',
    'Special School',
  ],
  schoolCategoryIds: {
    'Kindergarten': 1,
    'Primary': 2,
    'Junior High School': 3,
    'Basic School (KG-Primary-JHS)': 4,
    'Special School': 5,
  },
  educationLevels: [
    'Kindergarten',
    'Primary',
    'Junior High',
    'Special Education',
  ],
  educationLevelIds: {
    'Kindergarten': 1,
    'Primary': 2,
    'Junior High': 3,
    'Special Education': 4,
  },
  gesRegistrationTypes: [],
  gesRegistrationTypeIds: {},
  businessRegistrationTypes: [],
  businessRegistrationTypeIds: {},
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

const _basicInfoRecord = SchoolOnboardingRecord(
  data: {
    'customSchoolId': 'SCH-ADDRESS',
    'schoolName': 'Address Test School',
    'category': {'id': 3, 'name': 'Junior High School'},
    'educationLevel': {'id': 3, 'level': 'Junior High'},
    'yearFounded': 2020,
    'motto': 'Learn and serve',
    'registrationStatus': 'IN_PROGRESS',
    'currentStep': 'BASIC_INFO',
    'completedSteps': [],
  },
  progress: SchoolOnboardingProgress(
    customSchoolId: 'SCH-ADDRESS',
    registrationStatus: 'IN_PROGRESS',
    currentStep: 'BASIC_INFO',
    completedSteps: [],
  ),
);

const _socialWelfareRecord = SchoolOnboardingRecord(
  data: {
    'customSchoolId': 'SCH-ADDRESS',
    'schoolName': 'Address Test School',
    'registrationStatus': 'IN_PROGRESS',
    'currentStep': 'SOCIAL_WELFARE_COMPLIANCE',
    'completedSteps': ['BASIC_INFO', 'REGISTRATION_DETAILS'],
  },
  progress: SchoolOnboardingProgress(
    customSchoolId: 'SCH-ADDRESS',
    registrationStatus: 'IN_PROGRESS',
    currentStep: 'SOCIAL_WELFARE_COMPLIANCE',
    completedSteps: ['BASIC_INFO', 'REGISTRATION_DETAILS'],
  ),
);

final _addressLookups = SchoolCreationLookups.empty().copyWith(
  districts: const ['Bongo'],
  districtIds: const {'Bongo': 146},
);

const _addressRecord = SchoolOnboardingRecord(
  data: {
    'customSchoolId': 'SCH-ADDRESS',
    'schoolName': 'Address Test School',
    'address': {
      'id': 7,
      'houseNumber': '113',
      'streetName': '02',
      'city': 'Multan',
      'district': {'id': 146, 'name': 'Bongo'},
      'region': {'id': 11, 'name': 'Upper East'},
      'country': 'Pakistans',
      'additionalDirection': 'Direction',
      'ghanaPostAddress': 'GA-123-4567',
      'gpsLocation': {'id': 1, 'latitude': 4.0, 'longitude': 4.0},
    },
    'registrationStatus': 'IN_PROGRESS',
    'currentStep': 'ADDRESS',
    'completedSteps': [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
    ],
  },
  progress: SchoolOnboardingProgress(
    customSchoolId: 'SCH-ADDRESS',
    registrationStatus: 'IN_PROGRESS',
    currentStep: 'ADDRESS',
    completedSteps: [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
    ],
  ),
);

const _contactRecord = SchoolOnboardingRecord(
  data: {
    'customSchoolId': 'SCH-ADDRESS',
    'schoolName': 'Address Test School',
    'contactInfo': {
      'personalPhoneNumbers': [
        {'number': '+233 30 111 1111', 'type': 'whatsapp'},
      ],
      'workPhoneNumbers': [
        {'number': '+233 30 111 1111', 'type': 'office', 'isWhatsApp': false},
        {'number': '+233 30 222 2222', 'type': 'office', 'isWhatsApp': false},
      ],
      'emails': ['office@school.test', 'accounts@school.test'],
    },
    'registrationStatus': 'IN_PROGRESS',
    'currentStep': 'CONTACT_INFO',
    'completedSteps': [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
      'ADDRESS',
    ],
  },
  progress: SchoolOnboardingProgress(
    customSchoolId: 'SCH-ADDRESS',
    registrationStatus: 'IN_PROGRESS',
    currentStep: 'CONTACT_INFO',
    completedSteps: [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
      'ADDRESS',
    ],
  ),
);

const _gradeRecord = SchoolOnboardingRecord(
  data: {
    'customSchoolId': 'SCH-ADDRESS',
    'schoolName': 'Address Test School',
    'registrationStatus': 'IN_PROGRESS',
    'currentStep': 'GRADE_LEVELS',
    'completedSteps': [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
      'ADDRESS',
      'CONTACT_INFO',
      'DOCUMENTS',
    ],
  },
  progress: SchoolOnboardingProgress(
    customSchoolId: 'SCH-ADDRESS',
    registrationStatus: 'IN_PROGRESS',
    currentStep: 'GRADE_LEVELS',
    completedSteps: [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
      'ADDRESS',
      'CONTACT_INFO',
      'DOCUMENTS',
    ],
  ),
);

const _termRecord = SchoolOnboardingRecord(
  data: {
    'customSchoolId': 'SCH-ADDRESS',
    'schoolName': 'Address Test School',
    'registrationStatus': 'IN_PROGRESS',
    'currentStep': 'TERM_CALENDAR',
    'currentAcademicTerm': {
      'academicYear': {'name': '2026-2027'},
      'termType': {'name': 'First Term'},
      'description': 'A description that should no longer be editable',
      'startDate': '2026-09-01',
      'endDate': '2026-12-18',
      'events': [
        {
          'name': 'Opening Day',
          'eventType': {'name': 'Other'},
          'startDate': '2026-09-01',
          'endDate': '2026-09-01',
        },
      ],
    },
    'completedSteps': [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
      'ADDRESS',
      'CONTACT_INFO',
      'DOCUMENTS',
      'GRADE_LEVELS',
    ],
  },
  progress: SchoolOnboardingProgress(
    customSchoolId: 'SCH-ADDRESS',
    registrationStatus: 'IN_PROGRESS',
    currentStep: 'TERM_CALENDAR',
    completedSteps: [
      'BASIC_INFO',
      'REGISTRATION_DETAILS',
      'SOCIAL_WELFARE_COMPLIANCE',
      'ADDRESS',
      'CONTACT_INFO',
      'DOCUMENTS',
      'GRADE_LEVELS',
    ],
  ),
);

class _AddressRepository extends FakePlatformRepository {
  @override
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  ) async => _addressRecord;
}

class _BasicInfoRepository extends _AddressRepository {
  SchoolOnboardingDraft? savedDraft;

  @override
  Future<SchoolOnboardingProgress> saveSchoolOnboardingStep({
    required int stepIndex,
    required SchoolOnboardingDraft draft,
  }) async {
    savedDraft = draft;
    return const SchoolOnboardingProgress(
      customSchoolId: 'SCH-ADDRESS',
      registrationStatus: 'IN_PROGRESS',
      currentStep: 'REGISTRATION_DETAILS',
      completedSteps: ['BASIC_INFO'],
    );
  }
}

class _ContactRepository extends _AddressRepository {
  @override
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  ) async => _contactRecord;
}

class _GradeRepository extends _AddressRepository {
  @override
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  ) async => const SchoolOnboardingRecord(
    data: {
      'customSchoolId': 'SCH-ADDRESS',
      'schoolName': 'Address Test School',
      'registrationStatus': 'IN_PROGRESS',
      'currentStep': 'GRADE_LEVELS',
      'completedSteps': [
        'BASIC_INFO',
        'REGISTRATION_DETAILS',
        'SOCIAL_WELFARE_COMPLIANCE',
        'ADDRESS',
        'CONTACT_INFO',
        'DOCUMENTS',
      ],
    },
    progress: SchoolOnboardingProgress(
      customSchoolId: 'SCH-ADDRESS',
      registrationStatus: 'IN_PROGRESS',
      currentStep: 'GRADE_LEVELS',
      completedSteps: [
        'BASIC_INFO',
        'REGISTRATION_DETAILS',
        'SOCIAL_WELFARE_COMPLIANCE',
        'ADDRESS',
        'CONTACT_INFO',
        'DOCUMENTS',
      ],
    ),
  );

  @override
  Future<List<SchoolGradeLevelInfo>> getSchoolGradeLevels(
    String customSchoolId,
  ) async => const [
    SchoolGradeLevelInfo(
      gradeLevelId: 11,
      gradeLevelName: 'JHS 1',
      numberOfStreams: 4,
    ),
  ];

  @override
  Future<SchoolGradeLevelInfo> createCustomGradeLevel({
    required String customSchoolId,
    required String gradeLevelName,
    required int numberOfStreams,
  }) async => SchoolGradeLevelInfo(
    gradeLevelId: 100001,
    gradeLevelName: gradeLevelName,
    numberOfStreams: numberOfStreams,
    isCustom: true,
  );
}
