import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/platform/data/live_platform_repository.dart';
import 'package:school_management_app/src/platform/data/platform_api_client.dart';
import 'package:school_management_app/src/platform/domain/platform_models.dart';

void main() {
  test('school registration statuses preserve every backend value', () {
    const expected = <String, SchoolStatus>{
      'IN_PROGRESS': SchoolStatus.inProgress,
      'COMPLETED': SchoolStatus.completed,
      'PENDING_APPROVAL': SchoolStatus.pendingApproval,
      'NEEDS_REVISION': SchoolStatus.needsRevision,
      'APPROVED': SchoolStatus.approved,
      'REJECTED': SchoolStatus.rejected,
      'SUSPENDED': SchoolStatus.suspended,
      'INACTIVE': SchoolStatus.inactive,
      'DELETED': SchoolStatus.deleted,
    };

    for (final entry in expected.entries) {
      expect(schoolStatusFromApi(entry.key), entry.value);
      expect(entry.value.apiValue, entry.key);
    }
  });

  test('account manager schools use the managed paginated API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/Narellallc/sma-v1/1.0.0/api/account-managers/schools/paginated',
      );
      expect(request.url.queryParameters['page'], '0');
      expect(request.url.queryParameters['size'], '20');
      expect(request.url.queryParameters['sort'], 'createdAt,desc');
      return http.Response(
        jsonEncode({
          'content': [
            {
              'customSchoolId': 'MYS-XXX-9F3710',
              'schoolName': 'My School',
              'registrationStatus': 'APPROVED',
              'totalStudents': 0,
            },
          ],
          'totalElements': 1,
          'totalPages': 1,
          'number': 0,
          'size': 20,
        }),
        200,
      );
    });

    final page = await LivePlatformRepository(
      accessToken: 'test-token',
      role: PlatformRole.accountManager,
      client: client,
    ).getSchools(size: 20);

    expect(page.schools, hasLength(1));
    expect(page.schools.single.code, 'MYS-XXX-9F3710');
    expect(page.totalElements, 1);
  });

  test('academic years are loaded from the global lookup', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      if (request.url.path.endsWith('/api/lookup/academic-years')) {
        expect(request.url.queryParameters, isEmpty);
        return http.Response(
          jsonEncode([
            {'id': 1, 'year': '2025/2026'},
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    final result = await PlatformApiClient(
      accessToken: 'test-token',
      client: client,
    ).getSchoolCreationLookups();

    expect(result.academicYears, ['2025/2026']);
    expect(result.academicYearIds['2025/2026'], 1);
  });

  test('review is loaded from the registration review endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.path,
        '/Narellallc/sma-v1/1.0.0/api/schools/SCH-001/registration-step',
      );
      expect(request.url.queryParameters['currentStep'], 'REVIEW');
      expect(jsonDecode(request.body), <String, dynamic>{});
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'schoolName': 'Review School',
          'registrationStatus': 'IN_PROGRESS',
          'currentStep': 'REVIEW',
          'completedSteps': ['TERM_CALENDAR'],
        }),
        200,
      );
    });

    final record = await LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    ).getSchoolReviewRecord('SCH-001');

    expect(record.data['schoolName'], 'Review School');
    expect(record.progress.currentStep, 'REVIEW');
  });

  test('finish setup returns the backend school status', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/Narellallc/sma-v1/1.0.0/api/schools/SCH-001/finish-setup',
      );
      expect(jsonDecode(request.body), <String, dynamic>{});
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'schoolName': 'Submitted School',
          'registrationStatus': 'PENDING_APPROVAL',
          'currentStep': 'REVIEW',
          'completedSteps': ['REVIEW'],
        }),
        200,
      );
    });

    final result = await LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    ).finishSchoolSetup('SCH-001');

    expect(result.data['schoolName'], 'Submitted School');
    expect(result.progress.registrationStatus, 'PENDING_APPROVAL');
  });

  test('school approval uses the school status change API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.path,
        '/Narellallc/sma-v1/1.0.0/api/schools/SCH-001/changeschoolstatus',
      );
      expect(jsonDecode(request.body), {
        'status': 'APPROVED',
        'reason': 'School registration reviewed and approved',
      });
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'schoolName': 'Approved School',
          'registrationStatus': 'APPROVED',
        }),
        200,
      );
    });

    await LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    ).changeSchoolStatus(
      customSchoolId: 'SCH-001',
      status: SchoolStatus.approved,
      reason: 'School registration reviewed and approved',
    );
  });

  test(
    'school administrator invitation uses the user management API',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/Narellallc/sma-v1/1.0.0/api/user-management/schools/SCH-001/users',
        );
        expect(jsonDecode(request.body), {
          'firstName': 'Ama',
          'middleName': '',
          'lastName': 'Mensah',
          'email': 'ama@school.edu.gh',
          'phoneNumber': '+233241234567',
          'dateOfBirth': '1990-06-20',
          'userType': 'STAFF',
          'role': 'ADMINISTRATOR',
          'emailDelivery': true,
          'smsDelivery': true,
          'printSlipDelivery': false,
        });
        return http.Response(
          jsonEncode({
            'message': 'Invitation sent',
            'username': 'ama.mensah',
            'temporaryPassword': 'Temp123!',
          }),
          201,
        );
      });

      final result =
          await LivePlatformRepository(
            accessToken: 'test-token',
            client: client,
          ).inviteSchoolAdministrator(
            customSchoolId: 'SCH-001',
            invite: SchoolAdministratorInvite(
              firstName: 'Ama',
              lastName: 'Mensah',
              email: 'ama@school.edu.gh',
              phoneNumber: '024 123 4567',
              dateOfBirth: DateTime(1990, 6, 20),
            ),
          );

      expect(result.username, 'ama.mensah');
      expect(result.temporaryPassword, 'Temp123!');
    },
  );

  test('account manager invitation sends the selected account type', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.path,
        '/Narellallc/sma-v1/1.0.0/api/auth/register/account-manager',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['firstName'], 'Akosua');
      expect(body['lastName'], 'Mensah');
      expect(body['email'], 'akosua@example.com');
      expect(body['phoneNumber'], '+233241234567');
      expect(body['dateOfBirth'], '1990-06-20');
      expect(body['role'], 'SUPER_ACCOUNT_MANAGER');
      expect(body['inviteMethod'], 'Email and SMS');
      return http.Response(
        jsonEncode({
          'id': 42,
          'firstName': 'Akosua',
          'lastName': 'Mensah',
          'email': 'akosua@example.com',
          'phoneNumber': '+233241234567',
          'status': 'PENDING',
        }),
        201,
      );
    });

    final result =
        await LivePlatformRepository(
          accessToken: 'test-token',
          client: client,
        ).createAccountManager(
          AccountManagerDraft(
            firstName: 'Akosua',
            lastName: 'Mensah',
            email: 'akosua@example.com',
            phone: '+233241234567',
            dateOfBirth: DateTime(1990, 6, 20),
            inviteMethod: 'Email and SMS',
            role: PlatformRole.superAccountManager,
          ),
        );

    expect(result.email, 'akosua@example.com');
  });

  test('school users are loaded from the user management API', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/Narellallc/sma-v1/1.0.0/api/user-management/schools/SCH-001/users',
      );
      expect(request.url.queryParameters['page'], '0');
      expect(request.url.queryParameters['size'], '100');
      return http.Response(
        jsonEncode({
          'content': [
            {
              'userId': 7,
              'firstName': 'Ama',
              'lastName': 'Mensah',
              'email': 'ama@school.edu.gh',
              'phoneNumber': '+233241234567',
              'role': 'ADMINISTRATOR',
              'accountStatus': 'ACTIVE',
              'lastLoginAt': '2026-06-21T09:30:00',
            },
          ],
          'totalElements': 1,
        }),
        200,
      );
    });

    final users = await LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    ).getSchoolUsers('SCH-001');

    expect(users, hasLength(1));
    expect(users.single.name, 'Ama Mensah');
    expect(users.single.isAdministrator, isTrue);
    expect(users.single.status, 'ACTIVE');
  });

  test(
    'invalid school administrator phone is rejected before the API',
    () async {
      final client = MockClient((request) async {
        fail('The API must not be called for an invalid phone number.');
      });
      final repository = LivePlatformRepository(
        accessToken: 'test-token',
        client: client,
      );

      await expectLater(
        repository.inviteSchoolAdministrator(
          customSchoolId: 'SCH-001',
          invite: SchoolAdministratorInvite(
            firstName: 'Ama',
            lastName: 'Mensah',
            email: 'ama@school.edu.gh',
            phoneNumber: '68588',
            dateOfBirth: DateTime(1990, 6, 20),
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test('documents follow the presigned S3 upload contract', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);

      if (request.url.path.endsWith('/documents/upload-requests')) {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'fileName': 'business-registration.pdf',
          'contentType': 'application/pdf',
          'fileSize': 4,
          'documentType': 'BUSINESS_REGISTRATION',
          'description': 'Business registration certificate',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'documentId': '123',
              'uploadUrl':
                  'https://school-files.s3.amazonaws.com/document.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=test',
            },
          }),
          200,
        );
      }

      if (request.url.host == 'school-files.s3.amazonaws.com') {
        expect(request.method, 'PUT');
        expect(request.headers['authorization'], isNull);
        expect(request.headers['content-type'], 'application/pdf');
        expect(request.bodyBytes, [1, 2, 3, 4]);
        return http.Response('', 200, headers: {'etag': '"upload-etag"'});
      }

      if (request.url.path.endsWith('/documents/123/confirm')) {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'eTag': 'upload-etag',
          'fileSize': 4,
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'documentId': '123', 'status': 'ACTIVE'},
          }),
          200,
        );
      }

      if (request.url.path.endsWith('/registration-step')) {
        expect(request.method, 'PUT');
        expect(request.url.queryParameters['currentStep'], 'DOCUMENTS');
        expect(jsonDecode(request.body), <String, dynamic>{});
        return http.Response(
          jsonEncode({
            'customSchoolId': 'SCH-001',
            'registrationStatus': 'IN_PROGRESS',
            'currentStep': 'GRADE_LEVELS',
            'completedSteps': ['DOCUMENTS'],
          }),
          200,
        );
      }

      fail('Unexpected request: ${request.method} ${request.url}');
    });

    final repository = LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    );
    final progress = await repository.saveSchoolOnboardingStep(
      stepIndex: 5,
      draft: _documentDraft(),
    );

    expect(requests, hasLength(4));
    expect(progress.currentStep, 'GRADE_LEVELS');
    expect(progress.completedSteps, contains('DOCUMENTS'));
  });

  test('registration identifiers are included in the save request', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(
        request.url.queryParameters['currentStep'],
        'REGISTRATION_DETAILS',
      );
      final details =
          (jsonDecode(request.body)
                  as Map<String, dynamic>)['registrationDetails']
              as Map<String, dynamic>;
      expect(details['gesRegistrationNumber'], 'GES-123');
      expect(details['registrationNumberGes'], 'GES-123');
      expect(details['gemisCode'], 'GEMIS-456');
      expect(details['taxIdNumber'], 'TIN-789');
      expect(details['gesRegistrationTypeId'], 2);
      expect(details['businessRegistrationTypeId'], 3);
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'currentStep': 'SOCIAL_WELFARE_COMPLIANCE',
          'completedSteps': ['BASIC_INFO', 'REGISTRATION_DETAILS'],
        }),
        200,
      );
    });

    final repository = LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    );
    await repository.saveSchoolOnboardingStep(
      stepIndex: 1,
      draft: _documentDraft(
        gesRegistrationNumber: 'GES-123',
        gesRegistrationTypeId: 2,
        businessRegistrationTypeId: 3,
        gemisCode: 'GEMIS-456',
        taxIdNumber: 'TIN-789',
      ),
    );
  });

  test(
    'education level is included in the basic information request',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.queryParameters['currentStep'], 'BASIC_INFO');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['educationLevel'], {
          'id': 4,
          'name': 'Basic School',
          'level': 'Basic School',
        });
        return http.Response(
          jsonEncode({
            'customSchoolId': 'SCH-001',
            'currentStep': 'REGISTRATION_DETAILS',
            'completedSteps': ['BASIC_INFO'],
          }),
          200,
        );
      });

      final repository = LivePlatformRepository(
        accessToken: 'test-token',
        client: client,
      );
      await repository.saveSchoolOnboardingStep(
        stepIndex: 0,
        draft: _documentDraft(educationLevelId: 4),
      );
    },
  );

  test(
    'new schools start through the account manager creation endpoint',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/Narellallc/sma-v1/1.0.0/api/account-managers/schools/create',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['schoolName'], 'Test School');
        expect(body['category'], {'id': 1, 'name': 'Private'});
        expect(body['educationLevel'], {
          'id': 4,
          'name': 'Basic School',
          'level': 'Basic School',
        });
        return http.Response(
          jsonEncode({
            'message': 'School created',
            'school': {
              'customSchoolId': 'NEW-001',
              'schoolName': 'Test School',
              'registrationStatus': 'IN_PROGRESS',
              'currentStep': 'REGISTRATION_DETAILS',
              'completedSteps': ['BASIC_INFO'],
            },
          }),
          201,
        );
      });

      final repository = LivePlatformRepository(
        accessToken: 'test-token',
        client: client,
      );
      final progress = await repository.saveSchoolOnboardingStep(
        stepIndex: 0,
        draft: _documentDraft(customSchoolId: null, educationLevelId: 4),
      );

      expect(progress.customSchoolId, 'NEW-001');
      expect(progress.currentStep, 'REGISTRATION_DETAILS');
    },
  );

  test('address step sends every address and location field', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.queryParameters['currentStep'], 'ADDRESS');
      expect(jsonDecode(request.body), {
        'address': {
          'houseNumber': 'H123',
          'streetName': 'Main Street',
          'additionalDirection': 'Near East Legon Police Station',
          'ghanaPostAddress': 'GA-123-4567',
          'gpsLocation': {'latitude': 5.6037, 'longitude': -0.1870},
          'city': 'Accra',
          'country': 'Ghana',
          'district': {'id': 5},
          'region': {'id': 3},
        },
      });
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'currentStep': 'CONTACT_INFO',
          'completedSteps': ['ADDRESS'],
        }),
        200,
      );
    });

    final repository = LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    );
    await repository.saveSchoolOnboardingStep(
      stepIndex: 3,
      draft: _documentDraft(
        houseNumber: 'H123',
        streetName: 'Main Street',
        additionalDirection: 'Near East Legon Police Station',
        ghanaPostAddress: 'GA-123-4567',
        town: 'Accra',
        districtId: 5,
        regionId: 3,
        gpsLatitude: 5.6037,
        gpsLongitude: -0.1870,
      ),
    );
  });

  test('grade levels use the backend registration contract', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.queryParameters['currentStep'], 'GRADE_LEVELS');
      expect(jsonDecode(request.body), {
        'gradeLevels': [
          {
            'gradeLevelId': 5,
            'gradeName': 'Basic 1',
            'streamsCount': 3,
            'status': 'ACTIVE',
          },
          {
            'gradeLevelId': 6,
            'gradeName': 'Basic 2',
            'streamsCount': 0,
            'status': 'INACTIVE',
          },
        ],
      });
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'currentStep': 'TERM_CALENDAR',
          'completedSteps': ['GRADE_LEVELS'],
        }),
        200,
      );
    });

    final repository = LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    );
    await repository.saveSchoolOnboardingStep(
      stepIndex: 6,
      draft: _documentDraft(
        gradeStreams: const {'Basic 1': 3},
        gradeLevelIds: const {'Basic 1': 5, 'Basic 2': 6},
      ),
    );
  });

  test(
    'school grade levels hydrate active rows from the live contract',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/Narellallc/sma-v1/1.0.0/api/grade-levels/school/SCH-001',
        );
        return http.Response(
          jsonEncode([
            {
              'gradeLevelId': 5,
              'gradeName': 'Basic 1',
              'streamsCount': 3,
              'status': 'ACTIVE',
            },
            {
              'gradeLevelId': 6,
              'gradeName': 'Basic 2',
              'streamsCount': 1,
              'status': 'INACTIVE',
            },
          ]),
          200,
        );
      });

      final repository = LivePlatformRepository(
        accessToken: 'test-token',
        client: client,
      );
      final grades = await repository.getSchoolGradeLevels('SCH-001');

      expect(grades, hasLength(2));
      expect(grades.first.gradeLevelId, 5);
      expect(grades.first.gradeLevelName, 'Basic 1');
      expect(grades.first.numberOfStreams, 3);
      expect(grades.first.status, 'ACTIVE');
      expect(grades.last.gradeLevelId, 6);
      expect(grades.last.status, 'INACTIVE');
    },
  );

  test('academic term and events use nested backend objects', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.queryParameters['currentStep'], 'TERM_CALENDAR');
      expect(jsonDecode(request.body), {
        'currentAcademicTerm': {
          'academicYear': {'id': 1},
          'termType': {'id': 1},
          'description': 'First term of 2025',
          'startDate': '2025-01-15',
          'endDate': '2025-04-15',
          'events': [
            {
              'name': 'Sports Day',
              'description': 'Annual inter-house sports competition',
              'startDate': '2025-03-10',
              'endDate': '2025-03-10',
              'startTime': '08:00:00',
              'endTime': '16:00:00',
              'eventType': {'id': 2},
              'isSchoolDay': true,
            },
          ],
        },
      });
      return http.Response(
        jsonEncode({
          'customSchoolId': 'SCH-001',
          'currentStep': 'REVIEW',
          'completedSteps': ['TERM_CALENDAR'],
        }),
        200,
      );
    });

    final repository = LivePlatformRepository(
      accessToken: 'test-token',
      client: client,
    );
    await repository.saveSchoolOnboardingStep(
      stepIndex: 7,
      draft: _documentDraft(
        academicYear: '2025',
        academicYearId: 1,
        academicTerm: 'First Term',
        academicTermId: 1,
        termDescription: 'First term of 2025',
        termStartDate: DateTime(2025, 1, 15),
        termEndDate: DateTime(2025, 4, 15),
        events: const [
          SchoolCalendarEventDraft(
            type: 'Sports Day',
            otherName: '',
            description: 'Annual inter-house sports competition',
            startDate: null,
            endDate: null,
            startTime: '[8, 0]',
            endTime: '[16, 0]',
            isSchoolDay: true,
          ),
        ],
        eventTypeIds: const {'Sports Day': 2},
        eventStartDate: DateTime(2025, 3, 10),
        eventEndDate: DateTime(2025, 3, 10),
      ),
    );
  });
}

SchoolOnboardingDraft _documentDraft({
  String? customSchoolId = 'SCH-001',
  int? educationLevelId = 1,
  String gesRegistrationNumber = '',
  int? gesRegistrationTypeId,
  int? businessRegistrationTypeId,
  String gemisCode = '',
  String taxIdNumber = '',
  String houseNumber = '',
  String streetName = '',
  String additionalDirection = '',
  String ghanaPostAddress = '',
  String town = '',
  int? districtId,
  int? regionId,
  double? gpsLatitude,
  double? gpsLongitude,
  Map<String, int> gradeStreams = const {},
  Map<String, int> gradeLevelIds = const {},
  String academicYear = '',
  int? academicYearId,
  String academicTerm = '',
  int? academicTermId,
  String termDescription = '',
  DateTime? termStartDate,
  DateTime? termEndDate,
  List<SchoolCalendarEventDraft> events = const [],
  Map<String, int> eventTypeIds = const {},
  DateTime? eventStartDate,
  DateTime? eventEndDate,
}) => SchoolOnboardingDraft(
  customSchoolId: customSchoolId,
  schoolName: 'Test School',
  schoolType: 'Private',
  schoolTypeId: 1,
  educationLevel: 'Basic School',
  educationLevelId: educationLevelId,
  yearFounded: 2020,
  motto: '',
  gesRegistrationNumber: gesRegistrationNumber,
  gesRegistrationType: '',
  gesRegistrationTypeId: gesRegistrationTypeId,
  gesRegistrationDate: '',
  businessRegistrationNumber: '',
  businessRegistrationType: '',
  businessRegistrationTypeId: businessRegistrationTypeId,
  businessRegistrationDate: '',
  gemisCode: gemisCode,
  taxIdNumber: taxIdNumber,
  socialWelfareNumber: '',
  socialWelfareOfficer: '',
  socialWelfareDate: '',
  socialWelfareStatus: '',
  socialWelfareStatusId: null,
  houseNumber: houseNumber,
  streetName: streetName,
  additionalDirection: additionalDirection,
  ghanaPostAddress: ghanaPostAddress,
  town: town,
  cityId: null,
  district: '',
  districtId: districtId,
  region: '',
  regionId: regionId,
  country: 'Ghana',
  countryId: 1,
  gpsLatitude: gpsLatitude,
  gpsLongitude: gpsLongitude,
  phone: '',
  phoneNetwork: '',
  secondaryPhone: '',
  secondaryPhoneNetwork: '',
  officePhone: '',
  email: '',
  website: '',
  socialMedia: '',
  socialMediaPlatformId: null,
  socialMediaLinks: const [],
  administratorName: '',
  administratorPhone: '',
  administratorEmail: '',
  levels: const [],
  gradeStreams: gradeStreams,
  gradeLevelIds: gradeLevelIds,
  academicYear: academicYear,
  academicYearId: academicYearId,
  academicTerm: academicTerm,
  academicTermId: academicTermId,
  termDescription: termDescription,
  termStartDate: termStartDate,
  termEndDate: termEndDate,
  events: events
      .map(
        (event) => eventStartDate == null && eventEndDate == null
            ? event
            : SchoolCalendarEventDraft(
                type: event.type,
                otherName: event.otherName,
                description: event.description,
                startDate: eventStartDate ?? event.startDate,
                endDate: eventEndDate ?? event.endDate,
                startTime: event.startTime,
                endTime: event.endTime,
                isSchoolDay: event.isSchoolDay,
              ),
      )
      .toList(),
  eventTypeIds: eventTypeIds,
  documents: const {
    'Business registration certificate': SchoolDocumentDraft(
      name: 'business-registration.pdf',
      size: 4,
      bytes: [1, 2, 3, 4],
      mimeType: 'application/pdf',
    ),
  },
);
