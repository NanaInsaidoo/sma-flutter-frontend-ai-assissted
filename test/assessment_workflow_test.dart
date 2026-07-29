import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/assessments/presentation/assessment_workflow_screen.dart';

void main() {
  Future<void> pumpWorkflow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompleteAssessmentWorkflow(
            schoolName: 'SMA School',
            term: 'Term 1',
            academicYear: '2024 Academic Year',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAssessmentRegister(WidgetTester tester) async {
    await tester.tap(find.text('Manage Assessments').first);
    await tester.pumpAndSettle();
    expect(find.text('Select a class and stream to continue.'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Check Readiness'), findsOneWidget);
  }

  testWidgets('opens an assessment detail and its score sheet', (tester) async {
    await pumpWorkflow(tester);
    await openAssessmentRegister(tester);

    await tester.tap(find.text('CAT 1 – Number & Algebra').first);
    await tester.pumpAndSettle();

    expect(find.text('View Score Sheet'), findsWidgets);
    expect(find.text('Edit Assessment'), findsWidgets);
    expect(find.text('SCORE STATISTICS'), findsOneWidget);

    await tester.tap(find.text('View Score Sheet').first);
    await tester.pumpAndSettle();

    expect(find.text('Save Scores'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Search students...'), findsOneWidget);
  });

  testWidgets('assessment register search filters the rows', (tester) async {
    await pumpWorkflow(tester);
    await openAssessmentRegister(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search...'),
      'Environmental',
    );
    await tester.pump();

    expect(find.text('Environmental Science Project'), findsOneWidget);
    expect(find.text('CAT 1 – Number & Algebra'), findsNothing);
  });

  testWidgets(
    'evaluation class selection opens its student register directly',
    (tester) async {
      await pumpWorkflow(tester);

      await tester.tap(find.text('Student Evaluations').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Pending Evaluations'), findsOneWidget);
      expect(find.text('Grade 5 - Stream A'), findsWidgets);
      expect(find.text('CURRENT SCORE'), findsOneWidget);
      expect(find.text('LAST EVALUATED'), findsOneWidget);
      expect(find.text('View/Edit'), findsWidgets);
      expect(find.text('Evaluate'), findsOneWidget);

      await tester.tap(find.text('Evaluate'));
      await tester.pumpAndSettle();
      expect(find.text('Student Evaluation'), findsOneWidget);
      expect(find.text('Nana Owusu'), findsOneWidget);
      expect(find.text('Save Evaluation'), findsWidgets);
      expect(find.text('Homework Completion'), findsOneWidget);
      expect(find.text('Neatness'), findsOneWidget);
      expect(find.text('Score Summary'), findsOneWidget);
    },
  );

  testWidgets(
    'opens final reports and uses report cards as a monitoring register',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1700, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpWorkflow(tester);

      await tester.tap(find.text('Final Reports').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Final Report Management'), findsOneWidget);
      expect(find.text('TOTAL STREAMS'), findsOneWidget);
      expect(find.text('PENDING GENERATION'), findsWidgets);
      expect(find.textContaining('Publish All'), findsOneWidget);
      expect(find.text('Publish (25)'), findsOneWidget);
      expect(find.text('Export Report'), findsOneWidget);

      final view = find.text('View').first;
      await tester.ensureVisible(view);
      await tester.tap(view);
      await tester.pumpAndSettle();

      expect(find.text('Report Cards'), findsOneWidget);
      expect(find.text('TOTAL STUDENTS'), findsOneWidget);
      expect(find.text('READY TO PUBLISH'), findsOneWidget);
      expect(find.text('HEAD COMMENTS'), findsOneWidget);
      expect(find.text('MISSING PROMOTION'), findsOneWidget);
      expect(find.text('All Students'), findsOneWidget);
      expect(find.text('Open Report'), findsWidgets);
      expect(find.textContaining('Publish ('), findsNothing);

      await tester.tap(find.text('Open Report').first);
      await tester.pumpAndSettle();
      expect(find.text('Student Report'), findsOneWidget);
      expect(find.text('Academic Performance'), findsOneWidget);
      expect(find.text('Publication Readiness'), findsOneWidget);
      expect(find.text('Student Evaluation'), findsOneWidget);
      expect(find.text('Record Information'), findsOneWidget);
      expect(find.text('CREATED BY'), findsOneWidget);
      expect(find.text('LAST UPDATED BY'), findsOneWidget);
      expect(find.text('Class Teacher Remarks'), findsOneWidget);
      expect(find.text('Head Teacher Remarks'), findsOneWidget);
    expect(find.text('Ignore Head Teacher comment'), findsOneWidget);
    expect(find.text('Promoted To'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);

      await tester.tap(find.text('Edit Evaluation'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Student Evaluation'), findsOneWidget);
      expect(find.text('Overall Evaluation Remark'), findsOneWidget);
      expect(find.text('Optional one-line comment'), findsNWidgets(6));
      expect(find.text('Add one concise overall comment'), findsOneWidget);
      expect(find.text('Save Evaluation'), findsOneWidget);
    },
  );
}
