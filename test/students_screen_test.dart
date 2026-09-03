import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:school_management_app/src/admissions/data/admissions_api_client.dart';
import 'package:school_management_app/src/students/presentation/students_screen.dart';
import 'package:school_management_app/src/students/domain/student_models.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

import 'support/fake_students_repository.dart';

void main() {
  Future<void> pumpStudents(
    WidgetTester tester, {
    VoidCallback? onOpenHousehold,
    StudentsRepository repository = const FakeStudentsRepository(),
    bool focusSearchOnLoad = false,
    ValueChanged<EnrolledStudent>? onCollectPayment,
    AdmissionsApiClient? admissionsApi,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentsScreen(
            term: 'Term 2',
            academicYear: '2025/26',
            repository: repository,
            onOpenHousehold: onOpenHousehold,
            onCollectPayment: onCollectPayment,
            focusSearchOnLoad: focusSearchOnLoad,
            admissionsApi: admissionsApi,
            customSchoolId: admissionsApi == null ? null : 'SCHOOL',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows enrolled register and filters students', (tester) async {
    await pumpStudents(tester);

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Enrolled students (6)'), findsOneWidget);
    expect(find.text('Kwame Yaw Asante'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('students-search')), 'Akosua');
    await tester.pump();

    expect(find.text('Enrolled students (1)'), findsOneWidget);
    expect(find.text('Akosua Owusu'), findsOneWidget);
    expect(find.text('Kwame Yaw Asante'), findsNothing);
  });

  testWidgets('focuses student search when opened from a quick action', (
    tester,
  ) async {
    await pumpStudents(tester, focusSearchOnLoad: true);

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('students-search')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('opens student profile tabs and returns to register', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();

    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Current-term snapshot'), findsOneWidget);

    await tester.tap(find.byKey(const Key('student-tab-requirements')));
    await tester.pumpAndSettle();
    expect(find.text('Items & supplies progress'), findsOneWidget);
    expect(find.text('Exercise books'), findsOneWidget);
    expect(find.text('Previous term'), findsOneWidget);
    expect(find.textContaining('From Term 1 · 2025/26'), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-students')));
    await tester.pumpAndSettle();
    expect(find.text('Enrolled students (6)'), findsOneWidget);
  });

  testWidgets('collect payment quick action returns the selected student', (
    tester,
  ) async {
    EnrolledStudent? selectedStudent;
    await pumpStudents(
      tester,
      onCollectPayment: (student) => selectedStudent = student,
    );

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();

    expect(find.text('Collect payment'), findsOneWidget);
    await tester.tap(find.byKey(const Key('collect-student-payment')));
    await tester.pump();

    expect(selectedStudent?.id, 'STU-FA1BC0-9043');
  });

  testWidgets(
    'one Edit profile action opens the editor with all stages available',
    (tester) async {
      final requests = <http.Request>[];
      final api = AdmissionsApiClient(
        accessToken: 'test',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/record-changes/context')) {
            return http.Response(
              jsonEncode({
                'student': {
                  'customStudentId': 'STU-FA1BC0-9043',
                  'householdId': 1042,
                  'firstName': 'Kwame',
                  'lastName': 'Asante',
                  'status': 'ACTIVE',
                },
                'baseVersion': 'version-1',
                'approvers': [],
              }),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      );
      await pumpStudents(tester, admissionsApi: api);
      await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
      await tester.pumpAndSettle();

      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Edit student'), findsNothing);
      for (final label in [
        'Edit personal details',
        'Edit address',
        'Edit medical details',
        'Edit vaccinations',
        'Edit school history',
        'Edit documents',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('Change history'), findsOneWidget);

      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Student'), findsOneWidget);
      expect(
        find.byKey(const Key('student-edit-approval-notice')),
        findsOneWidget,
      );
      expect(
        find.textContaining('require another administrator’s approval'),
        findsOneWidget,
      );
      for (var step = 0; step < 6; step++) {
        expect(find.byKey(Key('admission-drawer-step-$step')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('admission-drawer-step-2')));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 6 — Medical'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admission-drawer-step-0')));
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 6 — Basic Info'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit profile'), findsOneWidget);
      expect(requests.where((request) => request.method != 'GET'), isEmpty);
    },
  );

  testWidgets('reviews and confirms a same-grade stream transfer', (
    tester,
  ) async {
    final repository = _CountingStudentsRepository();
    await pumpStudents(tester, repository: repository);
    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-class-grade')));
    await tester.pumpAndSettle();
    expect(find.text('Change class/grade'), findsWidgets);
    expect(find.byKey(const Key('transfer-student-summary')), findsOneWidget);
    expect(find.byKey(const Key('transfer-from-to')), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('Transfer type'), findsNothing);
    expect(find.text('Same grade, different stream'), findsNothing);
    expect(find.text('Different grade level'), findsNothing);
    expect(find.text('Select date'), findsOneWidget);
    await tester.tap(find.byKey(const Key('transfer-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JHS 1 — B').last);
    final transferDate = find.byKey(const Key('transfer-date'));
    await tester.dragFrom(const Offset(800, 500), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.ensureVisible(transferDate);
    await tester.tap(transferDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Select date'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('transfer-reason')),
      'Move to the other stream.',
    );
    await tester.tap(find.text('Review transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Review transfer'), findsOneWidget);
    expect(find.text('No grade-level fee change is expected.'), findsOneWidget);
    expect(
      repository.lastPreviewInput?.type,
      StudentTransferType.sameGradeDifferentStream,
    );
    await tester.tap(find.text('Confirm transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Student class changed successfully.'), findsOneWidget);
    expect(repository.registerLoads, 2);
  });

  testWidgets('infers a different-grade transfer from the destination', (
    tester,
  ) async {
    final repository = _CountingStudentsRepository();
    await pumpStudents(tester, repository: repository);
    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-class-grade')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transfer-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JHS 2 — A').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transfer-approver')), findsOneWidget);
    await tester.tap(find.byKey(const Key('transfer-approver')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adjoa Mensah · Administrator').last);
    await tester.dragFrom(const Offset(800, 500), const Offset(0, -260));
    await tester.pumpAndSettle();
    final transferDate = find.byKey(const Key('transfer-date'));
    await tester.ensureVisible(transferDate);
    await tester.tap(transferDate);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('transfer-reason')),
      'Promote to the next grade.',
    );
    await tester.tap(find.text('Review transfer'));
    await tester.pumpAndSettle();

    expect(
      repository.lastPreviewInput?.type,
      StudentTransferType.differentGrade,
    );
    expect(
      find.text(
        'Fees will be recalculated only after approval. Existing discounts and waivers will then be cancelled and must be reapplied manually. Payments and receipts remain recorded.',
      ),
      findsOneWidget,
    );
    expect(find.text('Submit for approval'), findsOneWidget);
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();
    expect(
      find.text('Grade-change request submitted for approval.'),
      findsOneWidget,
    );
    expect(repository.registerLoads, 1);
  });

  testWidgets('unfunded destination is labelled and cannot be selected', (
    tester,
  ) async {
    await pumpStudents(tester);
    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-class-grade')));
    await tester.pumpAndSettle();

    expect(find.text('Blocked classes need active fees.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('transfer-destination')));
    await tester.pumpAndSettle();

    final blocked = find.byKey(const Key('blocked-transfer-destination-13'));
    expect(blocked, findsOneWidget);
    expect(find.text('JHS 1 — C'), findsOneWidget);
    expect(find.text('Fees are not active'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(blocked);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButtonFormField<StudentTransferDestination>>(
            find.byKey(const Key('transfer-destination')),
          )
          .initialValue,
      isNull,
    );
  });

  testWidgets('requires the user to choose an effective transfer date', (
    tester,
  ) async {
    await pumpStudents(tester);
    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-class-grade')));
    await tester.pumpAndSettle();

    expect(find.text('Select date'), findsOneWidget);
    await tester.tap(find.byKey(const Key('transfer-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JHS 1 — B').last);
    await tester.enterText(
      find.byKey(const Key('transfer-reason')),
      'Move to the other stream.',
    );
    await tester.tap(find.text('Review transfer'));
    await tester.pumpAndSettle();

    expect(find.text('Select an effective date.'), findsOneWidget);
    expect(find.text('Review transfer'), findsOneWidget);
  });

  testWidgets('shows medical conditions, allergies, and vaccinations', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-medical')));
    await tester.pumpAndSettle();

    expect(find.text('Medical conditions'), findsOneWidget);
    expect(find.text('Allergies'), findsOneWidget);
    expect(find.text('Peanuts'), findsOneWidget);
    expect(find.text('Vaccination records'), findsOneWidget);
    expect(find.text('Yellow Fever'), findsOneWidget);
  });

  testWidgets('household header opens household and sibling opens profile', (
    tester,
  ) async {
    var householdOpened = false;
    await pumpStudents(tester, onOpenHousehold: () => householdOpened = true);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();

    final household = find.byKey(const Key('open-student-household'));
    await tester.ensureVisible(household);
    await tester.tap(household);
    expect(householdOpened, isTrue);

    final sibling = find.byKey(const Key('household-member-STU-FA1BC0-3391'));
    await tester.ensureVisible(sibling);
    await tester.tap(sibling);
    await tester.pumpAndSettle();

    expect(find.text('Abena Asante'), findsWidgets);
    expect(find.text('Basic 4B'), findsWidgets);
  });

  testWidgets('shows unified financial activity and creates an adjustment', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    expect(find.text('ORIGINAL FEES'), findsOneWidget);
    expect(find.text('Financial activity'), findsOneWidget);
    expect(find.text('Fee statement'), findsNothing);
    expect(find.text('Payments & reversals'), findsNothing);
    expect(find.textContaining('Adjustment history'), findsNothing);
    expect(find.text('All types'), findsOneWidget);
    expect(find.text('All statuses'), findsOneWidget);
    expect(find.text('REC-0070'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('REC-0071'), findsOneWidget);
    expect(find.text('REV-0071'), findsOneWidget);
    expect(find.text('Reversed'), findsWidgets);
    final reversalRow = find.byKey(const Key('financial-row-REV-0071'));
    await tester.ensureVisible(reversalRow);
    await tester.tap(reversalRow);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Payment was recorded against the wrong student.'),
      findsOneWidget,
    );
    expect(
      find.text('Sibling discount for two enrolled children'),
      findsWidgets,
    );

    await tester.tap(find.byKey(const Key('create-fee-adjustment')));
    await tester.pumpAndSettle();
    expect(find.text('Create fee adjustment'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-fee-adjustment')));
    await tester.pumpAndSettle();
    expect(find.text('Select the fee item to adjust'), findsOneWidget);
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    expect(find.text('Enter a reason for the adjustment'), findsOneWidget);

    await tester.tap(find.byKey(const Key('adjustment-fee-item')));
    await tester.pumpAndSettle();
    final tuitionOption = find.byKey(const Key('adjustment-fee-option-501'));
    await tester.ensureVisible(tuitionOption);
    await tester.tap(tuitionOption);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('adjustment-amount')), '35');
    await tester.enterText(
      find.byKey(const Key('adjustment-reason')),
      'Short-term hardship support',
    );
    final save = find.byKey(const Key('save-fee-adjustment'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Select the person who must approve this request'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Select an approver to submit this request, or save it as a draft.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final approver = find.byKey(const Key('adjustment-approver'));
    await tester.ensureVisible(approver);
    await tester.tap(approver);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Efua Nyarko').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Short-term hardship support'), findsWidgets);
    expect(find.textContaining('Tuition fee'), findsWidgets);
    expect(find.text('Fee adjustment submitted for approval.'), findsOneWidget);
  });

  testWidgets('pending adjustment is visible and editable', (tester) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    expect(find.text('Pending: 1 adjustment'), findsOneWidget);
    expect(find.text('1 pending adjustment'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pending-adjustments-summary')));
    await tester.pumpAndSettle();
    expect(find.text('Financial activity'), findsOneWidget);
    expect(find.text('1 pending adjustment'), findsOneWidget);

    final menu = find.byKey(const Key('adjustment-menu-ADJ-1042-03'));
    expect(menu, findsOneWidget);
    await tester.tap(find.byKey(const Key('adjustment-row-ADJ-1042-03')));
    await tester.pumpAndSettle();
    expect(find.text('Edit fee adjustment'), findsOneWidget);
    expect(find.byKey(const Key('cancel-adjustment-request')), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('adjustment-approver')),
          )
          .onChanged,
      isNotNull,
    );
    expect(find.byKey(const Key('adjustment-change-reason')), findsOneWidget);
    expect(find.byKey(const Key('adjustment-fee-preview')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('adjustment-amount')), '200');
    await tester.pump();
    expect(
      find.text('Warning: this adjustment will make the fee negative.'),
      findsOneWidget,
    );
    expect(find.text('-GH₵ 150'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('adjustment-change-reason')),
      'Correcting the requested amount',
    );
    await tester.enterText(find.byKey(const Key('adjustment-amount')), '20');
    final saveChanges = find.byKey(const Key('save-fee-adjustment'));
    await tester.ensureVisible(saveChanges);
    await tester.tap(saveChanges);
    await tester.pumpAndSettle();
    expect(find.textContaining('GH₵ 20'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('financial activity columns sort in both directions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    final amountHeader = find.byKey(const Key('financial-sort-amount'));
    await tester.ensureVisible(amountHeader);
    await tester.tap(amountHeader);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('ADJ-1042-02')).dy,
      lessThan(tester.getTopLeft(find.text('ADJ-1042-01')).dy),
    );

    await tester.tap(amountHeader);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('ADJ-1042-01')).dy,
      lessThan(tester.getTopLeft(find.text('ADJ-1042-02')).dy),
    );
  });

  testWidgets('saved draft can later be submitted with an approver', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-fee-adjustment')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('adjustment-fee-item')));
    await tester.pumpAndSettle();
    final tuitionOption = find.byKey(const Key('adjustment-fee-option-501'));
    await tester.ensureVisible(tuitionOption);
    await tester.tap(tuitionOption);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('adjustment-amount')), '35');
    await tester.enterText(
      find.byKey(const Key('adjustment-reason')),
      'Draft hardship support request',
    );
    final processing = find.byKey(const Key('adjustment-processing'));
    await tester.ensureVisible(processing);
    await tester.tap(processing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as draft').last);
    await tester.pumpAndSettle();
    final create = find.byKey(const Key('save-fee-adjustment'));
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.text('Draft hardship support request'), findsWidgets);
    final draftMenu = find.byKey(const Key('adjustment-menu-ADJ-SERVER-1'));
    await tester.ensureVisible(draftMenu);
    await tester.tap(draftMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adjustment-processing')), findsOneWidget);

    final draftProcessing = find.byKey(const Key('adjustment-processing'));
    await tester.ensureVisible(draftProcessing);
    await tester.tap(draftProcessing);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit for approval').last);
    await tester.pumpAndSettle();
    final approver = find.byKey(const Key('adjustment-approver'));
    await tester.ensureVisible(approver);
    await tester.tap(approver);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Efua Nyarko').last);
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('save-fee-adjustment'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('approved adjustments cannot be mutated from student profile', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('adjustment-menu-ADJ-1042-01')), findsNothing);
    expect(find.text('Approved'), findsWidgets);
  });

  testWidgets('collects several student items and creates one receipt', (
    tester,
  ) async {
    final repository = _ItemTrackingStudentsRepository();
    await pumpStudents(tester, repository: repository);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-7591')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-requirements')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('collect-student-items')));
    await tester.pumpAndSettle();

    expect(find.text('Enter what the school received today'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('collect-quantity-REQ-UNIFORM')),
      '1',
    );
    await tester.enterText(
      find.byKey(const Key('collect-quantity-REQ-ART')),
      '2',
    );
    await tester.tap(find.byKey(const Key('confirm-item-collection')));
    await tester.pumpAndSettle();

    expect(repository.collectedItems, hasLength(2));
    expect(find.text('Items collected'), findsOneWidget);
    expect(find.text('ITEM-20260829-DEMO0001'), findsOneWidget);
  });

  testWidgets('exempts one item from the student row action', (tester) async {
    final repository = _ItemTrackingStudentsRepository();
    await pumpStudents(tester, repository: repository);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-requirements')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('requirement-actions-REQ-ART')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exempt student from this item'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('student-item-exemption-reason')),
      'Approved by the school office',
    );
    await tester.tap(find.byKey(const Key('student-item-exemption-approver')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efua Nyarko · Administrator').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-student-item-exemption')));
    await tester.pumpAndSettle();

    expect(repository.exemptedRequirementId, 'REQ-ART');
    expect(repository.exemptionReason, 'Approved by the school office');
  });

  testWidgets('shows student item receipt history and downloads selected', (
    tester,
  ) async {
    final repository = _ItemTrackingStudentsRepository();
    await pumpStudents(tester, repository: repository);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-requirements')));
    await tester.pumpAndSettle();

    expect(find.text('Collection history'), findsOneWidget);
    expect(find.text('ITEM-20260829-DEMO0002'), findsOneWidget);
    final receipt = find.byKey(const Key('select-item-receipt-2'));
    await tester.ensureVisible(receipt);
    await tester.tap(receipt);
    await tester.pumpAndSettle();
    final download = find.byKey(const Key('download-selected-item-receipts'));
    await tester.ensureVisible(download);
    await tester.tap(download);
    await tester.pumpAndSettle();

    expect(repository.downloadedReceiptIds, [2]);
  });
}

class _CountingStudentsRepository extends FakeStudentsRepository {
  int registerLoads = 0;
  StudentTransferInput? lastPreviewInput;

  @override
  Future<List<EnrolledStudent>> getEnrolledStudents() {
    registerLoads += 1;
    return super.getEnrolledStudents();
  }

  @override
  Future<StudentTransferPreview> previewTransfer(
    String studentId,
    StudentTransferInput input,
  ) {
    lastPreviewInput = input;
    return super.previewTransfer(studentId, input);
  }
}

class _ItemTrackingStudentsRepository extends FakeStudentsRepository {
  List<StudentItemCollectionEntry> collectedItems = const [];
  String? exemptedRequirementId;
  String? exemptionReason;
  List<int> downloadedReceiptIds = const [];

  @override
  Future<StudentItemCollectionReceipt> collectStudentItems({
    required String studentId,
    required String idempotencyKey,
    required List<StudentItemCollectionEntry> items,
    String notes = '',
  }) {
    collectedItems = List.unmodifiable(items);
    return super.collectStudentItems(
      studentId: studentId,
      idempotencyKey: idempotencyKey,
      items: items,
      notes: notes,
    );
  }

  @override
  Future<void> exemptStudentFromItem({
    required String studentId,
    required String requirementId,
    required String reason,
    int? approverId,
    required bool submit,
  }) async {
    exemptedRequirementId = requirementId;
    exemptionReason = reason;
  }

  @override
  Future<List<int>> downloadStudentItemReceipts({
    required String studentId,
    required List<int> receiptIds,
  }) async {
    downloadedReceiptIds = List.unmodifiable(receiptIds);
    return const <int>[37, 80, 68, 70];
  }
}
