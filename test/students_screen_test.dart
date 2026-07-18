import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/students/presentation/students_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  Future<void> pumpStudents(
    WidgetTester tester, {
    VoidCallback? onOpenHousehold,
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

  testWidgets('shows fee statement and creates an overall pending adjustment', (
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
    await tester.tap(find.text('Overall fee account').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('adjustment-amount')), '35');
    await tester.enterText(
      find.byKey(const Key('adjustment-reason')),
      'Short-term hardship support',
    );
    await tester.tap(find.byKey(const Key('save-fee-adjustment')));
    await tester.pumpAndSettle();

    expect(find.text('Short-term hardship support'), findsWidgets);
    expect(find.textContaining('Overall fee account'), findsWidgets);
    expect(find.text('Fee adjustment submitted for approval.'), findsOneWidget);
  });

  testWidgets('pending adjustment can be edited, deleted, or moved to draft', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('adjustment-menu-ADJ-1042-03'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Move to draft'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit fee adjustment'), findsOneWidget);
    final reasonField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('adjustment-reason')),
        matching: find.byType(EditableText),
      ),
    );
    expect(reasonField.controller.text, 'Temporary financial support request');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('adjustment-menu-ADJ-1042-03')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to draft'));
    await tester.pumpAndSettle();

    expect(find.text('Adjustment withdrawn to draft.'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);

    await tester.tap(find.byKey(const Key('adjustment-menu-ADJ-1042-03')));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Submit for approval'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('reverses an approved adjustment with a counter entry', (
    tester,
  ) async {
    await pumpStudents(tester);

    await tester.tap(find.byKey(const Key('student-row-STU-FA1BC0-9043')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-tab-fees')));
    await tester.pumpAndSettle();

    final menu = find.byKey(const Key('adjustment-menu-ADJ-1042-01'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reverse adjustment'));
    await tester.pumpAndSettle();

    expect(find.text('Reverse fee adjustment'), findsOneWidget);
    expect(
      find.byKey(const Key('reversing-adjustment-context')),
      findsOneWidget,
    );
    expect(find.textContaining('ADJ-1042-01'), findsWidgets);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('adjustment-amount')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('save-fee-adjustment')));
    await tester.pumpAndSettle();

    expect(
      find.text('Adjustment reversed with an audit entry.'),
      findsOneWidget,
    );
    expect(find.textContaining('Reversal of ADJ-1042-01'), findsWidgets);
    expect(find.text('Reversed'), findsWidgets);
  });
}
