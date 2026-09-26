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
            customSchoolId: '',
            accessToken: null,
            viewerName: 'Test Administrator',
            viewerRole: 'Administrator',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpTeacherWorkflow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompleteAssessmentWorkflow(
            schoolName: 'SMA School',
            term: 'First Term',
            academicYear: '2026-2027',
            customSchoolId: '',
            accessToken: null,
            viewerName: 'Sena Owusu',
            viewerRole: 'CLASS_TEACHER',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('does not render fabricated assessment records', (tester) async {
    await pumpWorkflow(tester);

    expect(find.text('ACTIVE ASSESSMENTS'), findsOneWidget);
    expect(find.text('CAT 1 – Number & Algebra'), findsNothing);
    expect(find.text('Environmental Science Project'), findsNothing);
    expect(find.text('Ama Boateng'), findsNothing);
    expect(find.text('Student Evaluations'), findsNothing);
  });

  testWidgets('requires a real school before opening assessment data', (
    tester,
  ) async {
    await pumpWorkflow(tester);

    await tester.tap(find.text('Manage Assessments').first);
    await tester.pumpAndSettle();

    expect(
      find.text('A school must be selected before loading assessments.'),
      findsOneWidget,
    );
  });

  testWidgets('teacher dashboard contains the full assessment register', (
    tester,
  ) async {
    await pumpTeacherWorkflow(tester);

    expect(find.text('My Assessments'), findsOneWidget);
    expect(find.text('Assessment register'), findsOneWidget);
    expect(find.text('New Assessment'), findsOneWidget);
    expect(find.text('Check report readiness'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
    expect(find.text('My Recent Assessments'), findsNothing);
    expect(find.text('Assessment Completion'), findsNothing);

    await tester.tap(find.text('Check report readiness'));
    await tester.pumpAndSettle();

    expect(find.text('Reports are not ready'), findsOneWidget);
  });

  testWidgets('assessment filters allow multiple selections', (tester) async {
    await pumpTeacherWorkflow(tester);

    await tester.tap(find.text('All Types'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Class Exercise'));
    await tester.tap(find.text('Homework'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('2 types selected'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(find.text('All Types'), findsOneWidget);
    expect(find.text('Clear all'), findsNothing);
  });
}
