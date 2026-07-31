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

  testWidgets('does not render fabricated assessment records', (tester) async {
    await pumpWorkflow(tester);

    expect(find.text('ACTIVE ASSESSMENTS'), findsOneWidget);
    expect(find.text('CAT 1 – Number & Algebra'), findsNothing);
    expect(find.text('Environmental Science Project'), findsNothing);
    expect(find.text('Ama Boateng'), findsNothing);
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
}
