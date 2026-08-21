import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/guardian/data/guardian_portal_api_client.dart';
import 'package:school_management_app/src/guardian/domain/guardian_portal_models.dart';
import 'package:school_management_app/src/guardian/presentation/guardian_portal_screen.dart';

void main() {
  test(
    'guardian dashboard parses household children and publication state',
    () {
      final snapshot = GuardianPortalSnapshot.fromJson({
        'guardianName': 'Ama Mensah',
        'schoolName': 'Horizon School',
        'termId': 8,
        'academicYearId': 3,
        'totalBalance': 350,
        'calendarEvents': [
          {
            'id': 11,
            'title': 'Parent meeting',
            'category': 'School event',
            'startDate': '2026-08-22',
            'endDate': '2026-08-22',
            'schoolDay': true,
          },
        ],
        'children': [
          {
            'customStudentId': 'STU-1',
            'studentName': 'Kofi Mensah',
            'gradeLevel': 'KG 1',
            'stream': 'Stream A',
            'balance': 350,
            'attendanceDays': 10,
            'presentDays': 8,
            'attendancePercentage': 80,
            'reportPublished': false,
          },
        ],
      });

      expect(snapshot.children.single.name, 'Kofi Mensah');
      expect(snapshot.children.single.balance, 350);
      expect(snapshot.children.single.reportPublished, isFalse);
      expect(snapshot.calendarEvents.single.title, 'Parent meeting');
    },
  );

  testWidgets('parent sees a household summary and opens one child workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeGuardianApi();

    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: api, onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello, Ama'), findsOneWidget);
    expect(find.text('Your children'), findsOneWidget);
    expect(find.text('Kofi Mensah'), findsWidgets);
    expect(find.text('Adwoa Ofori'), findsNothing);
    expect(find.text('Kwame Ofori'), findsNothing);
    expect(find.text('Family fees'), findsOneWidget);
    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('Parent meeting'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('guardian-open-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guardian-open-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('School calendar'), findsOneWidget);
    expect(find.text('Term events'), findsOneWidget);
    expect(find.text('Parent meeting'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guardian-calendar-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();
    expect(find.text('Back to family home'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Academics'), findsOneWidget);
    expect(find.text('Attendance'), findsWidgets);
    expect(find.text('Report cards'), findsOneWidget);
    expect(find.text('Child details'), findsOneWidget);
    expect(find.text('Fees'), findsOneWidget);
  });

  testWidgets('unpublished report cannot be opened', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('child-tab-5')));
    await tester.pumpAndSettle();

    expect(find.text('Not ready'), findsWidgets);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('preview-open-report-STU-1')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('child workspace shows detailed academic and wellbeing records', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('child-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Current subject performance'), findsOneWidget);
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('78%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('child-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('Homework history'), findsOneWidget);
    expect(find.text('Submitted'), findsWidgets);
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('child-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('No timetable published'), findsOneWidget);

    await tester.tap(find.byKey(const Key('child-tab-4')));
    await tester.pumpAndSettle();
    expect(find.text('Daily attendance history'), findsOneWidget);
    expect(find.text('Arrived at 8:24 AM'), findsOneWidget);

    tester.widget<ChoiceChip>(find.byKey(const Key('child-tab-6'))).onSelected!(
      true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Items for this term'), findsOneWidget);
    expect(find.text('Exercise books'), findsOneWidget);
    expect(find.text('Partly delivered'), findsOneWidget);
    expect(find.text('Crayons'), findsOneWidget);
    expect(find.text('Delivered'), findsWidgets);

    tester.widget<ChoiceChip>(find.byKey(const Key('child-tab-7'))).onSelected!(
      true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Medical information'), findsOneWidget);
    expect(find.text('Vaccination records'), findsOneWidget);
    expect(find.text('Groundnuts'), findsOneWidget);
    expect(find.text('Shellfish'), findsOneWidget);
    expect(find.text('Dust'), findsOneWidget);
    expect(find.text('Pollen'), findsOneWidget);
    expect(find.text('Asthma'), findsOneWidget);
    expect(find.text('Mild'), findsOneWidget);
    expect(find.text('BCG'), findsOneWidget);
    expect(find.text('Tuberculosis'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('Immunization card verified'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a negative amount remains a signed balance', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(
          api: _FakeGuardianApi(balance: -125),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Balance'), findsWidgets);
    expect(find.text('GH₵ -125'), findsOneWidget);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
  });

  testWidgets('parent portal remains usable on a small phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello, Ama'), findsOneWidget);
    expect(find.text('Fees'), findsOneWidget);
    await tester.tap(find.text('Fees'));
    await tester.pumpAndSettle();
    expect(find.text('Fees & payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all children in one household are easy to switch between', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(
          api: _FakeGuardianApi(secondChild: true),
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kofi Mensah'), findsWidgets);
    expect(find.text('Akosua Mensah'), findsWidgets);
    await tester.tap(find.byKey(const Key('home-open-child-STU-2')));
    await tester.pumpAndSettle();
    expect(find.text('Back to family home'), findsOneWidget);
    expect(find.text('Akosua Mensah'), findsOneWidget);
    await tester.tap(find.byKey(const Key('child-workspace-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-open-child-STU-1')), findsOneWidget);
  });

  testWidgets('opening a child starts the student page at the top', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const PageStorageKey<String>('guardian-page-Hello, Ama')),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();

    final childScroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(
          const PageStorageKey<String>('guardian-page-Kofi Mensah'),
        ),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    expect(childScroll.position.pixels, 0);
  });

  testWidgets('expanded parent portal exposes each major desktop section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guardian-message-count')), findsNothing);
    expect(find.byKey(const Key('guardian-pay-fees')), findsOneWidget);

    await tester.tap(find.byKey(const Key('guardian-nav-fees')));
    await tester.pumpAndSettle();
    expect(find.text('Fees & payments'), findsOneWidget);
    expect(find.text('Balance'), findsWidgets);

    await tester.tap(find.byKey(const Key('guardian-nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();
    expect(find.text('Academics'), findsOneWidget);
    expect(find.text('Homework'), findsOneWidget);
    expect(find.text('Report cards'), findsOneWidget);
    expect(find.text('Items to bring'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guardian-nav-messages')));
    await tester.pumpAndSettle();
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Conversations'), findsOneWidget);
    expect(find.text('New message'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guardian-nav-account')));
    await tester.pumpAndSettle();
    expect(find.text('My account'), findsWidgets);
    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Other guardians'), findsOneWidget);
    expect(find.text('Kwesi Ofori'), findsOneWidget);
    expect(find.text('+233244000001'), findsOneWidget);
    expect(find.text('@ama_parent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('global payment action opens the payment details dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-open-child-STU-1')));
    await tester.pumpAndSettle();
    expect(find.text('Back to family home'), findsOneWidget);

    await tester.tap(find.byKey(const Key('guardian-pay-fees')));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Money payments'), findsOneWidget);
    expect(
      find.text('Online Mobile Money payments are coming soon.'),
      findsOneWidget,
    );
    expect(find.textContaining('No payment has been started'), findsOneWidget);
    expect(find.text('Cash'), findsNothing);
    expect(find.text('Cheque'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary guardian can block and restore another guardian', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('guardian-nav-account')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('block-guardian-Kwesi Ofori')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block-guardian-Kwesi Ofori')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('guardian-block-reason')),
      'Temporary household access change',
    );
    await tester.tap(find.byKey(const Key('confirm-block-guardian')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('restore-guardian-Kwesi Ofori')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('restore-guardian-Kwesi Ofori')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-restore-guardian')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('block-guardian-Kwesi Ofori')), findsOneWidget);
  });

  testWidgets('fee payment experience opens without starting a payment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: GuardianPortalScreen(api: _FakeGuardianApi(), onLogout: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fees'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay school fees'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Money payments'), findsOneWidget);
    expect(find.byKey(const Key('guardian-payment-amount')), findsNothing);
    expect(find.textContaining('pay cash or cheque directly'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('payment dates returned as JSON arrays are formatted normally', () {
    final detail = GuardianFeeDetail.fromJson({
      'payments': [
        {
          'paymentReference': 'PAY-2',
          'amount': 10,
          'paymentDate': [2026, 8, 9],
          'paymentMethod': 'Cash',
        },
      ],
      'summary': {},
    });

    expect(detail.payments.single.date, '2026-08-09');
  });
}

class _FakeGuardianApi extends GuardianPortalApiClient {
  _FakeGuardianApi({this.balance = 350, this.secondChild = false})
    : super(accessToken: 'test');

  final double balance;
  final bool secondChild;
  bool guardianBlocked = false;

  @override
  Future<GuardianPortalSnapshot> dashboard() async =>
      GuardianPortalSnapshot.fromJson({
        'guardianName': 'Ama Mensah',
        'email': 'ama@example.com',
        'phoneNumber': '+233200000000',
        'schoolName': 'Horizon School',
        'academicYear': '2026-2027',
        'termName': 'First Term',
        'termId': 8,
        'academicYearId': 3,
        'totalBalance': balance,
        'calendarEvents': [
          {
            'id': 11,
            'title': 'Parent meeting',
            'description': 'Meet the class teachers in the school hall.',
            'category': 'School event',
            'startDate': '2026-08-22',
            'endDate': '2026-08-22',
            'startTime': '15:00',
            'endTime': '16:30',
            'schoolDay': true,
          },
        ],
        'children': [
          {
            'customStudentId': 'STU-1',
            'studentName': 'Kofi Mensah',
            'gradeLevel': 'KG 1',
            'stream': 'Stream A',
            'totalFees': 1000,
            'totalPaid': 650,
            'balance': balance,
            'attendanceDays': 10,
            'presentDays': 8,
            'absentDays': 1,
            'lateDays': 1,
            'attendancePercentage': 90,
            'reportPublished': false,
            'reportCurrent': false,
          },
          if (secondChild)
            {
              'customStudentId': 'STU-2',
              'studentName': 'Akosua Mensah',
              'gradeLevel': 'Basic 2',
              'stream': 'Stream B',
              'totalFees': 900,
              'totalPaid': 900,
              'balance': 0,
              'attendanceDays': 10,
              'presentDays': 10,
              'absentDays': 0,
              'lateDays': 0,
              'attendancePercentage': 100,
              'reportPublished': true,
              'reportCurrent': true,
            },
        ],
      });

  @override
  Future<GuardianAcademicData> academics(String studentId) async =>
      GuardianAcademicData.fromJson({
        'subjects': [
          {
            'subjectName': 'Mathematics',
            'currentAverage': 78,
            'releasedScoreCount': 2,
            'scores': [],
          },
        ],
        'activities': [
          {
            'subjectName': 'Mathematics',
            'title': 'Fractions worksheet',
            'type': 'Homework',
            'dueDate': '2026-08-15',
            'status': 'SUBMITTED',
            'percentage': 84,
          },
          {
            'subjectName': 'English',
            'title': 'Reading',
            'type': 'Homework',
            'dueDate': '2026-08-14',
            'status': 'MARKED',
            'percentage': 80,
          },
          {
            'subjectName': 'Science',
            'title': 'Plants',
            'type': 'Class exercise',
            'dueDate': '2026-08-13',
            'status': 'MARKED',
            'percentage': 82,
          },
          {
            'subjectName': 'Computing',
            'title': 'Keyboard',
            'type': 'Homework',
            'dueDate': '2026-08-12',
            'status': 'NOT_SUBMITTED',
          },
          {
            'subjectName': 'Creative Arts',
            'title': 'Colours',
            'type': 'Class exercise',
            'dueDate': '2026-08-11',
            'status': 'MARKED',
            'percentage': 90,
          },
        ],
      });

  @override
  Future<GuardianStudentRequirements> requirements(String studentId) async =>
      GuardianStudentRequirements.fromJson({
        'studentId': studentId,
        'studentName': 'Kofi Mensah',
        'academicTermId': 8,
        'items': [
          {
            'id': 1,
            'name': 'Exercise books',
            'category': 'Learning materials',
            'requiredQuantity': 4,
            'receivedQuantity': 2,
            'unit': 'books',
            'estimatedUnitPrice': 8.5,
            'dueDate': '2026-08-20',
            'instructions': 'Write the child name on each book.',
            'optional': false,
            'status': 'PARTIAL',
          },
          {
            'id': 2,
            'name': 'Crayons',
            'category': 'Creative Arts',
            'requiredQuantity': 1,
            'receivedQuantity': 1,
            'unit': 'pack',
            'status': 'FULFILLED',
          },
        ],
      });

  @override
  Future<GuardianProfile> profile() async => GuardianProfile.fromJson({
    'guardianName': 'Ama Mensah',
    'email': 'ama@example.com',
    'phoneNumber': '+233200000000',
    'phoneNumbers': ['+233200000000', '+233244000001'],
    'workPhoneNumber': '+233302000002',
    'emailAddresses': ['ama@example.com', 'ama.work@example.com'],
    'residentialAddress': 'Accra',
    'nationalities': ['Ghanaian'],
    'languages': ['English', 'Twi'],
    'religion': 'Christianity',
    'occupations': ['Teacher'],
    'skills': ['First aid'],
    'socialAccounts': [
      {'platform': 'Instagram', 'account': '@ama_parent'},
    ],
    'proofOfIdType': 'Ghana Card',
    'proofOfIdNumber': 'GHA-123456789-0',
    'emailNotifications': true,
    'smsNotifications': false,
  });

  @override
  Future<GuardianProfile> updateProfile({
    required String email,
    required String phoneNumber,
    required String residentialAddress,
    required List<String> occupations,
    required bool emailNotifications,
    required bool smsNotifications,
  }) async => GuardianProfile.fromJson({
    'guardianName': 'Ama Mensah',
    'email': email,
    'phoneNumber': phoneNumber,
    'phoneNumbers': [phoneNumber],
    'emailAddresses': [email],
    'residentialAddress': residentialAddress,
    'occupations': occupations,
    'emailNotifications': emailNotifications,
    'smsNotifications': smsNotifications,
  });

  @override
  Future<List<HouseholdGuardian>> householdGuardians() async => [
    HouseholdGuardian.fromJson({
      'guardianId': 'GUA-2',
      'name': 'Kwesi Ofori',
      'email': 'kwesi.ofori@example.com',
      'phoneNumber': '+233245550182',
      'blocked': guardianBlocked,
      'canManage': true,
    }),
    HouseholdGuardian.fromJson({
      'guardianId': 'GUA-3',
      'name': 'Akua Mensah',
      'email': 'akua.mensah@example.com',
      'phoneNumber': '+233552047719',
      'blocked': false,
      'canManage': true,
    }),
  ];

  @override
  Future<HouseholdGuardian> blockGuardian(
    String guardianId,
    String reason,
  ) async {
    guardianBlocked = true;
    return (await householdGuardians()).first;
  }

  @override
  Future<HouseholdGuardian> restoreGuardian(String guardianId) async {
    guardianBlocked = false;
    return (await householdGuardians()).first;
  }

  @override
  Future<GuardianFeeDetail> fees(String studentId) async =>
      GuardianFeeDetail.fromJson({
        'studentName': 'Kofi Mensah',
        'currentTerm': 'First Term',
        'feeItems': [
          {'feeName': 'Tuition', 'amount': 1000},
        ],
        'payments': [
          {
            'paymentReference': 'PAY-1',
            'amount': 650,
            'paymentDate': '2026-08-10',
            'paymentMethod': 'Cash',
          },
        ],
        'summary': {
          'totalFees': 1000,
          'totalPayments': 650,
          'outstandingBalance': 350,
        },
      });

  @override
  Future<GuardianChildDetails> childDetails(String studentId) async =>
      GuardianChildDetails.fromJson({
        'customStudentId': studentId,
        'firstName': studentId == 'STU-2' ? 'Akosua' : 'Kofi',
        'lastName': 'Mensah',
        'gender': studentId == 'STU-2' ? 'Female' : 'Male',
        'dateOfBirth': '2016-03-14',
        'status': 'ACTIVE',
        'gradeLevel': 'KG 1',
        'stream': 'Stream A',
        'countryOfBirth': 'Ghana',
        'cityOfBirth': 'Accra',
        'religion': 'Christianity',
        'languages': ['English', 'Twi'],
        'address': {
          'streetName': 'Independence Avenue',
          'city': 'Accra',
          'region': 'Greater Accra',
          'country': 'Ghana',
          'ghanaPostAddress': 'GA-123-4567',
        },
        'medical': {
          'bloodGroup': 'O+',
          'heightCm': 142.5,
          'weightKg': 38.2,
          'conditions': [
            {'name': 'Asthma', 'status': 'Yes', 'notes': 'Mild'},
          ],
          'foodAllergies': ['Groundnuts', 'Shellfish'],
          'medicalAllergies': [],
          'environmentalAllergies': ['Dust', 'Pollen'],
        },
        'vaccinations': [
          {
            'name': 'BCG',
            'diseaseProtected': 'Tuberculosis',
            'recommendedAge': 'At birth',
            'required': true,
            'status': 'YES',
            'dateReceived': '2016-03-18',
            'notes': 'Immunization card verified',
          },
        ],
        'emergencyContacts': [
          {
            'name': 'Ama Mensah',
            'phoneNumber': '+233200000000',
            'email': 'ama@example.com',
            'primaryGuardian': true,
          },
        ],
      });

  @override
  Future<List<GuardianAttendanceItem>> attendance(String studentId) async => [
    GuardianAttendanceItem.fromJson({
      'date': '2026-08-12',
      'status': 'LATE',
      'note': 'Arrived at 8:24 AM',
      'minutesLate': 24,
    }),
    GuardianAttendanceItem.fromJson({
      'date': '2026-08-11',
      'status': 'PRESENT',
      'note': '',
      'minutesLate': 0,
    }),
  ];

  @override
  Future<List<GuardianReportItem>> reports(String studentId) async => [
    GuardianReportItem.fromJson({
      'termId': 8,
      'academicYearId': 3,
      'academicYear': '2026-2027',
      'termName': 'First Term',
      'currentTerm': true,
      'status': 'NOT_GENERATED',
      'available': false,
    }),
    GuardianReportItem.fromJson({
      'termId': 7,
      'academicYearId': 2,
      'academicYear': '2025-2026',
      'termName': 'Third Term',
      'currentTerm': false,
      'status': 'PUBLISHED',
      'publishedAt': '2026-07-20T10:00:00',
      'available': true,
    }),
  ];
}
