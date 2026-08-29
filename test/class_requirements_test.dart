import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_class_requirements_repository.dart';
import 'package:school_management_app/src/fees/domain/class_requirement_models.dart';
import 'package:school_management_app/src/fees/presentation/class_requirements_screen.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  test('records received quantities and student-specific adjustments', () {
    final repository = FakeClassRequirementsRepository();

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
    final repository = FakeClassRequirementsRepository();

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
    final repository = FakeClassRequirementsRepository();

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
    final repository = FakeClassRequirementsRepository();
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
    final repository = FakeClassRequirementsRepository();
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

  test(
    'student-specific requirements follow their own approval lifecycle',
    () async {
      final repository = FakeClassRequirementsRepository();
      await repository.addStudentRequirement(
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

      expect(repository.unpublishedStudentRequirementCount, 1);
      await repository.submitStudentRequirement('custom-art', 99);
      expect(
        repository.studentSpecificRequirements.single.status,
        StudentSpecificRequirementStatus.pendingApproval,
      );
      await repository.approveStudentRequirement('custom-art');
      expect(
        repository.studentSpecificRequirements.single.status,
        StudentSpecificRequirementStatus.active,
      );
      expect(repository.unpublishedStudentRequirementCount, 0);
    },
  );

  test('summarizes prior-term physical requirement arrears', () {
    final repository = FakeClassRequirementsRepository();
    final pending = repository.priorTermRequirements
        .where((item) => item.status == PriorTermRequirementStatus.pending)
        .toList();

    expect(pending, hasLength(5));
    expect(pending.map((item) => item.studentId).toSet(), hasLength(3));
    expect(
      pending.fold<int>(0, (sum, item) => sum + item.remainingQuantity),
      18,
    );
    expect(
      pending.fold<double>(
        0,
        (sum, item) => sum + item.estimatedOutstandingValue,
      ),
      127.5,
    );
  });

  test('records prior-term receipts and keeps partial balances pending', () {
    final repository = FakeClassRequirementsRepository();

    repository.recordPriorTermReceived(
      requirementId: 'prior-ama-rolls',
      quantity: 2,
      notes: 'Two additional rolls received at the office.',
    );
    var requirement = repository.priorTermRequirements.firstWhere(
      (item) => item.id == 'prior-ama-rolls',
    );
    expect(requirement.receivedQuantity, 12);
    expect(requirement.remainingQuantity, 3);
    expect(requirement.status, PriorTermRequirementStatus.pending);

    repository.recordPriorTermReceived(
      requirementId: 'prior-ama-rolls',
      quantity: 3,
      notes: 'Balance received.',
    );
    requirement = repository.priorTermRequirements.firstWhere(
      (item) => item.id == 'prior-ama-rolls',
    );
    expect(requirement.receivedQuantity, 15);
    expect(requirement.status, PriorTermRequirementStatus.fulfilled);
    expect(requirement.resolvedAt, isNotNull);
  });

  test('converts prior-term physical items to an audited cash charge', () {
    final repository = FakeClassRequirementsRepository();

    repository.resolvePriorTermRequirement(
      requirementId: 'prior-ama-tissue',
      status: PriorTermRequirementStatus.convertedToCash,
      convertedCashAmount: 36,
      notes: 'Guardian chose the approved cash equivalent.',
      notifyGuardian: true,
    );

    final requirement = repository.priorTermRequirements.firstWhere(
      (item) => item.id == 'prior-ama-tissue',
    );
    expect(requirement.status, PriorTermRequirementStatus.convertedToCash);
    expect(requirement.convertedCashAmount, 36);
    expect(requirement.guardianNotificationQueued, isTrue);
    expect(requirement.resolvedAt, isNotNull);
  });

  test('publishes only the selected class with its notification plan', () {
    final repository = FakeClassRequirementsRepository();
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
      final repository = FakeClassRequirementsRepository();
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
    final repository = FakeClassRequirementsRepository();
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

    expect(find.text('Items & Supplies'), findsOneWidget);
    expect(find.text('Add class'), findsOneWidget);
    expect(find.text('Basic 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Basic 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic 1'));
    await tester.pumpAndSettle();

    expect(find.text('Basic 1 requirements'), findsOneWidget);
    expect(find.text('Add class item'), findsOneWidget);
    expect(find.text('REQUIRED QUANTITY'), findsOneWidget);
    expect(find.text('ESTIMATED PRICE'), findsOneWidget);
    expect(find.text('TOTAL / STUDENT'), findsNothing);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.byTooltip('Edit requirement'), findsNWidgets(3));
    expect(find.byTooltip('Delete requirement'), findsNWidgets(3));
    expect(find.text('Active'), findsNWidgets(3));
    expect(find.text('Draft'), findsNothing);
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Student progress'), findsOneWidget);
  });

  testWidgets('opens the prior-term resolution queue by student', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeClassRequirementsRepository();
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

    expect(find.text('Prior-term outstanding requirements'), findsOneWidget);
    expect(find.textContaining('3 students · 5 item types'), findsOneWidget);

    await tester.ensureVisible(find.text('Review outstanding items'));
    await tester.tap(find.text('Review outstanding items'));
    await tester.pumpAndSettle();

    expect(find.text('Affected students'.toUpperCase()), findsOneWidget);
    expect(find.text('By student'), findsOneWidget);
    expect(find.text('By item'), findsOneWidget);
    expect(find.text('Ama Mensah'), findsOneWidget);
    expect(find.text('Kojo Asare'), findsOneWidget);
  });

  testWidgets('approval review makes quantities prominent before price', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeClassRequirementsRepository();
    await repository.submitClass('basic-2', 99);

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
                currentUserId: 99,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Basic 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review approval'));
    await tester.pumpAndSettle();

    expect(find.text('Review required items'), findsOneWidget);
    expect(find.byKey(const Key('approval-quantity-b2-soap')), findsOneWidget);
    expect(
      find.byKey(const Key('approval-quantity-b2-disinfectant')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('approval-quantity-b2-books')), findsOneWidget);
    expect(
      find.textContaining('Estimated price: GH₵ 22 per bottle'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('approve-requirement-list')));
    await tester.pumpAndSettle();
    expect(find.text('Approved — publication required'), findsOneWidget);
    expect(find.textContaining('The creator must publish'), findsOneWidget);
  });

  testWidgets('approved creator sees the publish-items next step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeClassRequirementsRepository();
    await repository.addClass(
      ClassRequirementGroup(
        id: 'nursery-1',
        className: 'Nursery 1',
        studentCount: 20,
        status: RequirementStatus.approved,
        creatorOwned: true,
        items: [
          ClassRequirementItem(
            id: 'n1-crayons',
            name: 'Colouring crayons',
            category: 'Learning materials',
            quantity: 2,
            unit: 'packs',
            estimatedUnitPrice: 15,
            dueDate: DateTime(2026, 9, 15),
          ),
        ],
      ),
    );

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

    await tester.ensureVisible(find.text('Nursery 1'));
    await tester.tap(find.text('Nursery 1'));
    await tester.pumpAndSettle();
    expect(find.text('Approved — publication required'), findsOneWidget);
    expect(
      find.byKey(const Key('publish-approved-requirements')),
      findsOneWidget,
    );
    expect(find.textContaining('Next step: publish'), findsOneWidget);
    expect(find.text('Publish approved items'), findsNothing);
    expect(find.text('Add class item'), findsNothing);
    expect(find.byTooltip('Edit requirement'), findsNothing);
    expect(find.byTooltip('Delete requirement'), findsNothing);
  });

  testWidgets('class cards preview only three items and show the remainder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeClassRequirementsRepository();
    repository.addRequirement(
      'basic-1',
      ClassRequirementItem(
        id: 'b1-crayons',
        name: 'Colouring crayons',
        category: 'Learning materials',
        quantity: 1,
        unit: 'pack',
        estimatedUnitPrice: 15,
        dueDate: DateTime(2026, 8, 1),
      ),
    );

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

    expect(find.text('+ 1 more item'), findsOneWidget);
    expect(find.text('Colouring crayons'), findsNothing);
  });

  testWidgets(
    'overview separates class and student requirements with one action badge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeClassRequirementsRepository();
      await repository.addStudentRequirement(
        studentId: 'stu-ama',
        requirement: StudentCustomRequirement(
          id: 'custom-art',
          name: 'Art sketch pad',
          quantity: 2,
          unit: 'pads',
          dueDate: DateTime(2026, 9, 1),
          notes: 'For the student art project.',
        ),
      );

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

      expect(find.text('Class requirements'), findsOneWidget);
      expect(find.text('Student-specific requirements'), findsOneWidget);
      expect(
        find.byKey(
          const Key('requirements-unpublished-Student-specific requirements'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Student-specific requirements'));
      await tester.pumpAndSettle();

      expect(find.text('Ama Mensah'), findsOneWidget);
      expect(find.text('Art sketch pad'), findsOneWidget);
      expect(find.text('2 pads'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Add student requirement'), findsOneWidget);
      expect(find.textContaining('total'), findsNothing);
    },
  );
}
