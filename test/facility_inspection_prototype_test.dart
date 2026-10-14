import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/presentation/facility_inspection_prototype.dart';
import 'package:school_management_app/src/term_review/domain/headmaster_term_closure_models.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  testWidgets('shows the full inspection, flags and report design', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FacilityInspectionPrototype(
            onBack: () {},
            schoolId: 'SMA-DEMO-001',
            termName: 'First Term',
            repository: _Repository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('End-of-term facility inspection'), findsOneWidget);
    expect(find.text('Download checklist template'), findsOneWidget);
    expect(find.text('12 / 53'), findsOneWidget);
    expect(find.text('Classrooms'), findsOneWidget);

    await tester.tap(find.text('Management flags').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Two roofing sheets are loose above the Class 5 block.'),
      findsOneWidget,
    );
    expect(find.text('Acknowledged'), findsNothing);
    expect(find.text('Evidence required'), findsWidgets);

    await tester.tap(find.text('Report & sign-off'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 urgent safety issues require acknowledgement'),
      findsOneWidget,
    );
    expect(find.text('SMC / PTA chair'), findsNothing);
  });

  testWidgets('updates finding status with structured values', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FacilityInspectionPrototype(
            onBack: () {},
            schoolId: 'SMA-DEMO-001',
            termName: 'First Term',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Management flags').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update follow-up').first);
    await tester.pumpAndSettle();

    expect(find.text('Finding status'), findsOneWidget);
    final status = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(status);
    await tester.pumpAndSettle();
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolved').last);
    await tester.pumpAndSettle();
    final saveDraft = find.text('Save draft').first;
    await tester.ensureVisible(saveDraft);
    await tester.pumpAndSettle();
    await tester.tap(saveDraft);
    await tester.pumpAndSettle();

    final facilities = repository.savedInput!.facilities;
    final findings = Map<String, dynamic>.from(facilities['findings'] as Map);
    final roof = Map<String, dynamic>.from(findings['classrooms.roof'] as Map);
    final signoff = Map<String, dynamic>.from(facilities['signoff'] as Map);
    expect(roof['status'], 'RESOLVED');
    expect(signoff, isNot(contains('communityChair')));
  });
}

class _Repository implements HeadmasterTermClosureRepository {
  HeadmasterTermClosureInput? savedInput;
  final ratings = {
    'classrooms.roof': 'POOR',
    'classrooms.ceiling': 'FAIR',
    'classrooms.desks': 'FAIR',
    'classrooms.electrical': 'GOOD',
    'sanitation.toilets': 'POOR',
    'sanitation.handwashing': 'GOOD',
    'safety.extinguishers': 'POOR',
    'safety.exits': 'GOOD',
    'ict.computers': 'FAIR',
    'library.books': 'GOOD',
    'compound.gate': 'GOOD',
    'compound.keys': 'GOOD',
  };

  final findings = {
    'classrooms.roof': {
      'severity': 'Urgent',
      'finding': 'Two roofing sheets are loose above the Class 5 block.',
      'assignedTo': 'Works coordinator',
      'due': '23 Dec 2026',
      'status': 'Acknowledged',
    },
    'classrooms.desks': {
      'severity': 'Medium',
      'finding': 'Five desks require repair.',
      'assignedTo': 'Assistant head',
      'due': '04 Jan 2027',
      'status': 'Open',
    },
    'sanitation.toilets': {
      'severity': 'High',
      'finding': 'The girls’ KVIP pit needs desludging.',
      'assignedTo': 'Headteacher',
      'due': '23 Dec 2026',
      'status': 'In progress',
    },
    'safety.extinguishers': {
      'severity': 'Urgent',
      'finding': 'Both extinguishers are expired.',
      'assignedTo': 'Headteacher',
      'due': '23 Dec 2026',
      'status': 'Open',
    },
    'ict.computers': {
      'severity': 'High',
      'finding': 'One computer is missing.',
      'assignedTo': 'ICT coordinator',
      'due': '19 Dec 2026',
      'status': 'In progress',
    },
  };

  HeadmasterTermClosure _closure() => HeadmasterTermClosure(
    termId: 1,
    status: 'DRAFT',
    termClosed: false,
    readyToClose: false,
    items: const [],
    acknowledgements: const {},
    facilities: {'ratings': ratings, 'findings': findings},
    summary: const {},
  );

  @override
  Future<HeadmasterTermClosure> get(String schoolId) async => _closure();

  @override
  Future<HeadmasterTermClosure> saveDraft(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async {
    savedInput = input;
    return _closure();
  }

  @override
  Future<HeadmasterTermClosure> close(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async => _closure();

  @override
  Future<List<int>> downloadReport(String schoolId) async => [];
}
