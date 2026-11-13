import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/presentation/facility_inspection_prototype.dart';
import 'package:school_management_app/src/term_review/domain/headmaster_term_closure_models.dart';
import 'package:school_management_app/src/theme/app_theme.dart';

void main() {
  for (final termClosed in [false, true]) {
    testWidgets(
      'opens submitted inspection read-only (term closed: $termClosed)',
      (tester) async {
        tester.view.physicalSize = termClosed
            ? const Size(360, 1800)
            : const Size(1440, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository(submitted: true, termClosed: termClosed);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: FacilityInspectionPrototype(
                onBack: () {},
                schoolId: 'SMA-DEMO-001',
                termName: 'First Term',
                actorDisplayName: 'Ama Teacher',
                repository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Submitted'), findsOneWidget);
        expect(
          find.textContaining('Signed off by Esi Assessment'),
          findsOneWidget,
        );
        expect(find.textContaining('12 Nov 2026'), findsOneWidget);
        expect(find.text('Inspection report'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Submit final inspection'), findsNothing);
        expect(find.text('Save draft'), findsNothing);
        expect(
          find.text('Edit inspection'),
          termClosed ? findsNothing : findsOneWidget,
        );
        tester.view.physicalSize = const Size(1440, 1800);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Checklist'));
        await tester.pumpAndSettle();
        expect(find.text('Mark all as…'), findsNothing);
        expect(find.byType(ChoiceChip), findsNothing);
        final roof = find.byKey(const ValueKey('classrooms.roof'));
        expect(
          find.descendant(of: roof, matching: find.text('POOR')),
          findsOneWidget,
        );

        await tester.tap(find.text('Management flags').last);
        await tester.pumpAndSettle();
        expect(find.text('Update follow-up'), findsNothing);
        expect(
          find.text('Two roofing sheets are loose above the Class 5 block.'),
          findsOneWidget,
        );

        if (!termClosed) {
          await tester.tap(find.text('Edit inspection'));
          await tester.pumpAndSettle();
          expect(find.text('Editing submitted inspection'), findsOneWidget);
          expect(find.text('Mark all as…'), findsOneWidget);
          expect(find.text('Resubmit inspection'), findsOneWidget);
          await tester.tap(
            find.descendant(of: roof, matching: find.text('Good')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel editing'));
          await tester.pumpAndSettle();
          expect(find.text('Submitted'), findsOneWidget);
          expect(find.text('Inspection report'), findsOneWidget);
          await tester.tap(find.text('Checklist'));
          await tester.pumpAndSettle();
          expect(
            find.descendant(of: roof, matching: find.text('POOR')),
            findsOneWidget,
          );
          expect(repository.savedInput, isNull);
        }
      },
    );
  }

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
            actorDisplayName: 'Esi Assessment',
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
      findsNothing,
    );
    expect(find.text('SMC / PTA chair'), findsNothing);
    expect(find.text('Signing as'), findsOneWidget);
    expect(find.text('Esi Assessment'), findsOneWidget);
    expect(find.text('Headteacher'), findsNothing);
    expect(find.text('Assistant head'), findsNothing);
  });

  testWidgets(
    'keeps comments and photos in the checklist and edits follow-up in flags',
    (tester) async {
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

      final roofItem = find.byKey(const ValueKey('classrooms.roof'));
      final poor = find.descendant(of: roofItem, matching: find.text('Poor'));
      await tester.ensureVisible(poor);
      await tester.pumpAndSettle();
      await tester.tap(poor);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: roofItem, matching: find.text('Comment')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: roofItem, matching: find.text('Add photos')),
        findsOneWidget,
      );
      expect(find.text('Assigned to'), findsNothing);
      expect(find.text('Fix by'), findsNothing);
      expect(find.text('Finding status'), findsNothing);
      const comment = 'Two roof sheets need repairs.';
      await tester.enterText(
        find.descendant(of: roofItem, matching: find.byType(TextFormField)),
        comment,
      );
      final ceilingItem = find.byKey(const ValueKey('classrooms.ceiling'));
      final ceilingDetails = find.descendant(
        of: ceilingItem,
        matching: find.byTooltip('Comment and photos'),
      );
      await tester.ensureVisible(ceilingDetails);
      await tester.pumpAndSettle();
      await tester.tap(ceilingDetails);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: ceilingItem, matching: find.byType(TextFormField)),
        'Minor staining.',
      );

      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Management flags').last);
      await tester.pumpAndSettle();
      expect(find.text(comment), findsOneWidget);
      await tester.ensureVisible(find.text('Update follow-up').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update follow-up').first);
      await tester.pumpAndSettle();

      expect(find.text('Finding status'), findsOneWidget);
      expect(find.text('Assigned to'), findsOneWidget);
      expect(find.text('Fix by'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Facilities lead',
      );
      await tester.enterText(find.byType(TextFormField).at(1), '10 Jan 2027');
      final status = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(status);
      await tester.pumpAndSettle();
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolved').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply changes'));
      await tester.pumpAndSettle();
      expect(find.text('Facilities lead'), findsOneWidget);
      expect(find.text('Fix by 10 Jan 2027'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save draft').first);
      await tester.pumpAndSettle();

      final facilities = repository.savedInput!.facilities;
      final findings = Map<String, dynamic>.from(facilities['findings'] as Map);
      final roof = Map<String, dynamic>.from(
        findings['classrooms.roof'] as Map,
      );
      expect(roof['status'], 'RESOLVED');
      expect(roof['finding'], comment);
      expect(roof['assignedTo'], 'Facilities lead');
      expect(roof['due'], '10 Jan 2027');
      expect(facilities['comments'], {'classrooms.ceiling': 'Minor staining.'});
      expect(repository.savedInput!.submitInspection, isFalse);
      expect(facilities['signoff'], isNull);

      final safetyCard = find.ancestor(
        of: find.text('Fire extinguishers are present, charged and in date'),
        matching: find.byType(Card),
      );
      final openSafetyItem = find.descendant(
        of: safetyCard,
        matching: find.text('Open checklist item'),
      );
      await tester.ensureVisible(openSafetyItem);
      await tester.pumpAndSettle();
      await tester.tap(openSafetyItem);
      await tester.pumpAndSettle();
      expect(
        find
            .descendant(
              of: find.byKey(const ValueKey('safety.extinguishers')),
              matching: find.text('Add photos'),
            )
            .hitTestable(),
        findsOneWidget,
      );
    },
  );

  testWidgets('counts N/A without expanding rows and keeps optional reasons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final screen = MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FacilityInspectionPrototype(
          onBack: () {},
          schoolId: 'SMA-DEMO-001',
          termName: 'First Term',
          repository: repository,
        ),
      ),
    );
    await tester.pumpWidget(screen);
    await tester.pumpAndSettle();

    final boards = find.byKey(const ValueKey('classrooms.boards'));
    final doors = find.byKey(const ValueKey('classrooms.doors'));
    final originalHeight = tester.getSize(boards).height;
    await tester.tap(find.descendant(of: boards, matching: find.text('N/A')));
    await tester.tap(find.descendant(of: doors, matching: find.text('N/A')));
    await tester.pumpAndSettle();
    expect(tester.getSize(boards).height, originalHeight);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('14 / 53'), findsOneWidget);
    expect(find.text('63%'), findsOneWidget);

    final report = find.text('Report & sign-off');
    await tester.tap(report);
    await tester.pumpAndSettle();
    expect(find.text('2 N/A'), findsOneWidget);
    expect(find.text('Not applicable reasons'), findsNothing);
    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(of: boards, matching: find.text('Add reason')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reason (optional)'), findsOneWidget);
    const reason = 'These classrooms use projection screens.';
    await tester.enterText(find.byType(TextFormField), reason);
    await tester.tap(find.text('Save reason'));
    await tester.pumpAndSettle();
    expect(tester.getSize(boards).height, originalHeight);
    expect(find.text('Edit reason'), findsOneWidget);

    await tester.tap(find.text('Save draft').first);
    await tester.pumpAndSettle();
    final saved = repository.savedInput!.facilities;
    expect(
      saved['ratings'],
      containsPair('classrooms.doors', 'NOT_APPLICABLE'),
    );
    expect(saved['notApplicableReasons'], {'classrooms.boards': reason});
    expect(saved['itemsInspected'], 14);
    expect(saved['score'], 63);
    expect(saved['findings'], isNot(contains('classrooms.boards')));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(screen);
    await tester.pumpAndSettle();
    expect(find.text('Edit reason'), findsOneWidget);
    await tester.tap(report);
    await tester.pumpAndSettle();
    expect(find.text(reason), findsOneWidget);
    expect(find.text('Chalkboards and whiteboards are usable'), findsOneWidget);
    expect(
      find.text('Doors, windows, hinges and locks work correctly'),
      findsNothing,
    );

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: boards, matching: find.text('Good')));
    await tester.pumpAndSettle();
    expect(find.text('Edit reason'), findsNothing);
    await tester.tap(find.text('Save draft').first);
    await tester.pumpAndSettle();
    expect(repository.savedInput!.facilities['notApplicableReasons'], isEmpty);
  });

  testWidgets(
    'confirms dropdown ratings and protects existing section answers',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
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

      final markAll = find.text('Mark all as…');
      await tester.tap(markAll);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      for (final option in ['Good', 'Fair', 'Poor', 'Not applicable']) {
        expect(find.widgetWithText(MenuItemButton, option), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(MenuItemButton, 'Not applicable'));
      await tester.pumpAndSettle();
      expect(find.text('Update Classrooms'), findsOneWidget);
      expect(
        find.text('Mark 4 unanswered items as Not applicable.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('12 / 53'), findsOneWidget);

      await tester.tap(markAll);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Not applicable'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply rating'));
      await tester.pumpAndSettle();
      expect(find.text('8 of 8 answered'), findsOneWidget);
      expect(find.text('16 / 53'), findsOneWidget);
      expect(find.text('63%'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      final roof = find.byKey(const ValueKey('classrooms.roof'));
      final roofRating = find.descendant(
        of: roof,
        matching: find.widgetWithText(ChoiceChip, 'Poor'),
      );
      expect(tester.widget<ChoiceChip>(roofRating).selected, isTrue);

      await tester.tap(markAll);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Poor'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Apply rating'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Include already answered items'));
      await tester.pumpAndSettle();
      expect(find.text('Mark 7 items as Poor.'), findsOneWidget);
      await tester.tap(find.text('Apply rating'));
      await tester.pumpAndSettle();
      expect(find.text('8 flagged'), findsOneWidget);
      expect(find.text('16 / 53'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Save draft').first);
      await tester.pumpAndSettle();
      final saved = repository.savedInput!.facilities;
      final ratings = saved['ratings'] as Map;
      expect(
        ratings.entries
            .where((entry) => entry.key.toString().startsWith('classrooms.'))
            .map((entry) => entry.value),
        everyElement('POOR'),
      );
      expect(ratings['library.books'], 'GOOD');
      final findings = saved['findings'] as Map;
      expect(findings['classrooms.roof']['assignedTo'], 'Works coordinator');
      expect(findings['classrooms.electrical']['severity'], 'Urgent');
    },
  );
}

class _Repository implements HeadmasterTermClosureRepository {
  _Repository({this.submitted = false, this.termClosed = false});

  final bool submitted;
  final bool termClosed;
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
    termClosed: termClosed,
    readyToClose: false,
    items: const [],
    acknowledgements: const {},
    facilities:
        savedInput?.facilities ??
        {
          'ratings': ratings,
          'findings': findings,
          if (submitted) ...{
            'inspectionCompleted': true,
            'submittedAt': '2026-11-12T12:00:00Z',
            'signoff': {'signedByName': 'Esi Assessment'},
          },
        },
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
