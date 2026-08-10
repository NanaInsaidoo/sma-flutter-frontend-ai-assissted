import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/students/presentation/students_screen.dart';
import 'package:school_management_app/src/students/domain/student_models.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

import 'support/fake_students_repository.dart';

void main() {
  Future<void> pumpStudents(
    WidgetTester tester, {
    VoidCallback? onOpenHousehold,
    StudentsRepository repository = const FakeStudentsRepository(),
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
    await tester.tap(find.byKey(const Key('transfer-destination')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JHS 1 — B').last);
    await tester.enterText(
      find.byKey(const Key('transfer-reason')),
      'Move to the other stream.',
    );
    await tester.tap(find.text('Review transfer'));
    await tester.pumpAndSettle();
    expect(find.text('Review transfer'), findsOneWidget);
    expect(find.text('No grade-level fee change is expected.'), findsOneWidget);
    await tester.tap(find.text('Confirm transfer'));
    await tester.pumpAndSettle();
    expect(
      find.text('Student class/grade changed successfully.'),
      findsOneWidget,
    );
    expect(repository.registerLoads, 2);
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

  testWidgets('household members link to student and household pages', (
    tester,
  ) async {
    var householdOpened = false;
    await pumpStudents(tester, onOpenHousehold: () => householdOpened = true);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();

    final guardian = find.byKey(const Key('household-member-GUA-1042-01'));
    await tester.ensureVisible(guardian);
    await tester.tap(guardian);
    expect(householdOpened, isTrue);

    final sibling = find.byKey(const Key('household-member-STU-FA1BC0-3391'));
    await tester.ensureVisible(sibling);
    await tester.tap(sibling);
    await tester.pumpAndSettle();

    expect(find.text('Abena Asante'), findsWidgets);
    expect(find.text('Basic 4B'), findsWidgets);
  });

  testWidgets('shows fee statement and creates a pending fee-item adjustment', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    expect(find.text('ORIGINAL FEES'), findsOneWidget);
    expect(find.text('Fee statement'), findsOneWidget);
    expect(find.text('ORIGINAL FEE ITEMS'), findsOneWidget);
    expect(find.text('APPROVED ADJUSTMENTS'), findsOneWidget);
    expect(find.text('TOTAL FEES'), findsOneWidget);
    expect(find.textContaining('Adjustment history'), findsOneWidget);
    expect(find.text('Financial activity'), findsOneWidget);
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
    expect(find.text('Adjustment history · 1 pending'), findsOneWidget);

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
    expect(find.text('GH₵ 20'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
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
}

class _CountingStudentsRepository extends FakeStudentsRepository {
  int registerLoads = 0;

  @override
  Future<List<EnrolledStudent>> getEnrolledStudents() {
    registerLoads += 1;
    return super.getEnrolledStudents();
  }
}
