import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/fees/data/mock_class_requirements_repository.dart';
import 'package:school_management_app/src/fees/domain/class_requirement_models.dart';
import 'package:school_management_app/src/fees/presentation/class_requirements_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  test('records received quantities and student-specific adjustments', () {
    final repository = MockClassRequirementsRepository();

    repository.recordReceived(
      studentId: 'stu-kojo',
      requirementId: 'b1-rolls',
      quantity: 10,
    );
    repository.adjustRequirement(
      studentId: 'stu-kojo',
      requirementId: 'b1-rolls',
      adjustment: const StudentRequirementAdjustment(
        type: RequirementAdjustmentType.reducedQuantity,
        reason: 'Administrator decision',
        notes: 'Approved reduced quantity.',
        adjustedQuantity: 10,
      ),
    );

    final student = repository
        .studentsForClass('basic-1')
        .firstWhere((item) => item.id == 'stu-kojo');
    expect(student.receivedQuantities['b1-rolls'], 10);
    expect(student.adjustments['b1-rolls']?.adjustedQuantity, 10);
  });

  test('supports full waiver with cash-equivalent audit notes', () {
    final repository = MockClassRequirementsRepository();

    repository.adjustRequirement(
      studentId: 'stu-efua',
      requirementId: 'b1-tissue',
      adjustment: const StudentRequirementAdjustment(
        type: RequirementAdjustmentType.fullWaiver,
        reason: 'Cash equivalent paid',
        notes: 'Guardian paid the approved cash equivalent.',
        paymentReference: 'REC-1042',
      ),
    );

    final adjustment = repository
        .studentsForClass('basic-1')
        .firstWhere((item) => item.id == 'stu-efua')
        .adjustments['b1-tissue'];
    expect(adjustment?.type, RequirementAdjustmentType.fullWaiver);
    expect(adjustment?.paymentReference, 'REC-1042');
  });

  test('supports increasing a requirement for an individual student', () {
    final repository = MockClassRequirementsRepository();

    repository.adjustRequirement(
      studentId: 'stu-kojo',
      requirementId: 'b1-rolls',
      adjustment: const StudentRequirementAdjustment(
        type: RequirementAdjustmentType.increasedQuantity,
        reason: 'Administrator decision',
        notes: 'Additional rolls requested for this student.',
        adjustedQuantity: 20,
      ),
    );

    final adjustment = repository
        .studentsForClass('basic-1')
        .firstWhere((item) => item.id == 'stu-kojo')
        .adjustments['b1-rolls'];
    expect(adjustment?.type, RequirementAdjustmentType.increasedQuantity);
    expect(adjustment?.adjustedQuantity, 20);
  });

  test('edits and deletes class requirements as draft changes', () {
    final repository = MockClassRequirementsRepository();
    final original = repository.groups
        .firstWhere((group) => group.id == 'basic-1')
        .items
        .firstWhere((item) => item.id == 'b1-rolls');

    repository.updateRequirement(
      'basic-1',
      ClassRequirementItem(
        id: original.id,
        name: original.name,
        category: original.category,
        quantity: 20,
        unit: original.unit,
        estimatedUnitPrice: original.estimatedUnitPrice,
        dueDate: original.dueDate,
        instructions: original.instructions,
      ),
    );

    final updated = repository.groups
        .firstWhere((group) => group.id == 'basic-1')
        .items
        .firstWhere((item) => item.id == 'b1-rolls');
    expect(updated.quantity, 20);
    expect(updated.updatedSincePublished, isTrue);
    expect(repository.draftChangeCountForClass('basic-1'), 1);

    repository.deleteRequirement('basic-1', 'b1-rolls');

    final group = repository.groups.firstWhere(
      (group) => group.id == 'basic-1',
    );
    expect(group.items.where((item) => item.id == 'b1-rolls'), isEmpty);
    expect(
      repository
          .studentsForClass('basic-1')
          .first
          .receivedQuantities
          .containsKey('b1-rolls'),
      isFalse,
    );
    expect(repository.draftChangeCountForClass('basic-1'), 2);
  });

  test('adds individual student requirements', () {
    final repository = MockClassRequirementsRepository();
    repository.addStudentRequirement(
      studentId: 'stu-ama',
      requirement: StudentCustomRequirement(
        id: 'custom-art',
        name: 'Art sketch pad',
        quantity: 1,
        unit: 'pad',
        dueDate: DateTime(2026, 8, 1),
        notes: 'Required for the student art project.',
      ),
    );

    final student = repository
        .studentsForClass('basic-1')
        .firstWhere((item) => item.id == 'stu-ama');
    expect(student.customRequirements.single.name, 'Art sketch pad');
  });

  test('publishes only the selected class with its notification plan', () {
    final repository = MockClassRequirementsRepository();
    expect(repository.draftChangeCount, 1);

    repository.addRequirement(
      'basic-1',
      ClassRequirementItem(
        id: 'b1-marker',
        name: 'Whiteboard marker',
        category: 'Learning materials',
        quantity: 2,
        unit: 'pieces',
        estimatedUnitPrice: 6.5,
        dueDate: DateTime(2026, 8, 1),
      ),
    );
    expect(repository.draftChangeCountForClass('basic-1'), 1);
    expect(repository.draftChangeCountForClass('basic-2'), 1);
    expect(
      repository.groups
          .firstWhere((group) => group.id == 'basic-1')
          .items
          .last
          .updatedSincePublished,
      isTrue,
    );

    repository.publishClass(
      'basic-1',
      const RequirementNotificationPlan(
        useDefaultPreference: false,
        methods: {'WhatsApp', 'SMS'},
        message: 'Requirements changed.',
      ),
    );

    expect(repository.draftChangeCount, 1);
    expect(repository.draftChangeCountForClass('basic-1'), 0);
    expect(repository.draftChangeCountForClass('basic-2'), 1);
    expect(
      repository.groups.firstWhere((group) => group.id == 'basic-1').status,
      RequirementStatus.published,
    );
    expect(
      repository.groups.firstWhere((group) => group.id == 'basic-2').status,
      RequirementStatus.draft,
    );
    expect(repository.lastNotificationPlan?.methods, contains('WhatsApp'));
    expect(
      repository.groups
          .firstWhere((group) => group.id == 'basic-1')
          .items
          .last
          .updatedSincePublished,
      isFalse,
    );
  });

  test(
    'adds a class before requirements and preserves estimated unit price',
    () {
      final repository = MockClassRequirementsRepository();
      repository.addClass(
        const ClassRequirementGroup(
          id: 'basic-3',
          className: 'Basic 3',
          studentCount: 0,
          items: [],
          status: RequirementStatus.draft,
        ),
      );
      repository.addRequirement(
        'basic-3',
        ClassRequirementItem(
          id: 'b3-rolls',
          name: 'Toilet rolls',
          category: 'Hygiene',
          quantity: 10,
          unit: 'rolls',
          estimatedUnitPrice: 4.5,
          dueDate: DateTime(2026, 8, 1),
        ),
      );

      final group = repository.groups.firstWhere(
        (item) => item.id == 'basic-3',
      );
      expect(group.items.single.estimatedUnitPrice, 4.5);
      expect(
        group.items.single.quantity * group.items.single.estimatedUnitPrice,
        45,
      );
      expect(group.draftChangeCount, 1);
      expect(group.items.single.updatedSincePublished, isFalse);
    },
  );

  testWidgets('class requirements overview opens class student tracker', (
    tester,
  ) async {
    final repository = MockClassRequirementsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClassRequirementsScreen(
                repository: repository,
                termName: 'Term 2 · 2025/26',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Class Requirements'), findsOneWidget);
    expect(find.text('Add class'), findsOneWidget);
    expect(find.text('Basic 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Basic 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic 1'));
    await tester.pumpAndSettle();

    expect(find.text('Basic 1 requirements'), findsOneWidget);
    expect(find.text('Add class item'), findsOneWidget);
    expect(find.text('UNIT ESTIMATE'), findsOneWidget);
    expect(find.text('TOTAL / STUDENT'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.byTooltip('Edit requirement'), findsNWidgets(3));
    expect(find.byTooltip('Delete requirement'), findsNWidgets(3));
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Student progress'), findsOneWidget);
  });
}
