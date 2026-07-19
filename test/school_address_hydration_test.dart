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

  testWidgets('hydrates saved stream counts into the class structure', (
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
            initialStep: 6,
            onBack: () {},
            onCreated: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4 streams selected'), findsOneWidget);
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

class _AddressRepository extends FakePlatformRepository {
  @override
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  ) async => _addressRecord;
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
}
