import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/classes/presentation/teacher_classes_screen.dart';
import 'package:school_management_app/src/dashboard/data/teacher_workspace_api_client.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('asks a teacher to choose when more than one class is assigned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TeacherClassesScreen(
            schoolId: 'SCH-001',
            displayName: 'Sena Owusu',
            workspaceLoader: (_) async => _workspace,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('My classes'),
      ),
      findsOneWidget,
    );
    expect(find.text('Choose a class to open its dashboard.'), findsOneWidget);
    expect(find.text('2 assigned classes'), findsOneWidget);
    expect(find.text('Basic 1 · Section 1'), findsOneWidget);
    expect(find.text('Basic 2 · Section 1'), findsOneWidget);
    expect(find.text('24 students'), findsNothing);
    expect(find.text('30 capacity'), findsNothing);
    expect(find.text('Primary class'), findsNothing);
    expect(find.text('Subject teacher'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing the initial chooser returns to the dashboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var returnedToDashboard = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TeacherClassesScreen(
            schoolId: 'SCH-001',
            displayName: 'Sena Owusu',
            workspaceLoader: (_) async => _workspace,
            onBack: () => returnedToDashboard = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(returnedToDashboard, isTrue);
    expect(
      find.text('Choose the class dashboard you want to open.'),
      findsNothing,
    );
    expect(find.text('Choose a class'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('combines class and subject assignments without duplicate classes', () {
    expect(_workspace.assignedClasses, hasLength(2));
    expect(
      _workspace.assignedClasses.map((assignment) => assignment.streamId),
      containsAll(<int>[101, 202]),
    );
  });
}

const _workspace = TeacherWorkspaceSnapshot(
  role: 'CLASS_TEACHER',
  assignedStudents: 45,
  classes: [
    TeacherClassAssignment(
      gradeLevelId: 11,
      gradeName: 'Basic 1',
      streamName: 'Section 1',
      streamId: 101,
      primary: true,
      studentCount: 24,
      capacity: 30,
    ),
  ],
  subjects: [
    TeacherSubjectAssignment(
      gradeLevelId: 11,
      gradeName: 'Basic 1',
      streamId: 101,
      streamName: 'Section 1',
      subjectId: 4,
      subjectName: 'Mathematics',
      studentCount: 24,
      capacity: 30,
    ),
    TeacherSubjectAssignment(
      gradeLevelId: 12,
      gradeName: 'Basic 2',
      streamId: 202,
      streamName: 'Section 1',
      subjectId: 8,
      subjectName: 'Science',
      studentCount: 21,
      capacity: 30,
    ),
  ],
);
