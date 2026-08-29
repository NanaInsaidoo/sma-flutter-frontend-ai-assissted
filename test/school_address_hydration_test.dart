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
    expect(find.text('Custom early-years classes'), findsOneWidget);
    expect(find.text('GES kindergarten'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Custom early-years classes')).dy,
      lessThan(tester.getTopLeft(find.text('GES kindergarten')).dy),
    );
    expect(find.text('CUSTOM CLASS · KG SUBJECTS SUGGESTED'), findsOneWidget);
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
        {'number': '+233 30 111 1111', 'type': 'office'},
      ],
      'workPhoneNumbers': [
        {'number': '+233 30 111 1111', 'type': 'office'},
        {'number': '+233 30 222 2222', 'type': 'office'},
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
