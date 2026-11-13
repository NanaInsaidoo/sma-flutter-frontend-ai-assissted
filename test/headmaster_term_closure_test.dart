import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/domain/headmaster_term_closure_models.dart';
import 'package:school_management_app/src/term_review/presentation/headmaster_term_closure_screen.dart';

void main() {
  testWidgets('shows blockers and saves warning acknowledgements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    var reportsOpened = false;
    var incidentsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'TEST',
            actorUserId: 1,
            repository: repo,
            workstreamActions: {
              'REPORTS': () => reportsOpened = true,
              'INCIDENTS': () => incidentsOpened = true,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Term Closure Dashboard'), findsOneWidget);
    expect(find.text('All closure actions'), findsOneWidget);
    expect(find.text('3 all actions'), findsOneWidget);
    expect(find.text('1 cleared'), findsOneWidget);
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Final closure'), findsOneWidget);
    expect(find.text('ACTION REQUIRED'), findsWidgets);
    expect(find.text('Finance and petty cash'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, 'Finance and petty cash'),
      findsNothing,
    );
    expect(find.text('Student report cards'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    await tester.tap(find.text('Student report cards'));
    expect(reportsOpened, isTrue);
    await tester.tap(find.text('Incidents and loss/damage'));
    expect(incidentsOpened, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Warning acknowledgements'), findsNothing);
    await tester.tap(find.text('Review warning'));
    await tester.pumpAndSettle();
    expect(find.text('Reason for accepting this warning'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Accepted for final report');
    await tester.pump();
    await tester.tap(find.text('Save acknowledgement'));
    await tester.pumpAndSettle();
    expect(repo.saved, isTrue);
    expect(find.text('Reviewed'), findsOneWidget);
    expect(find.text('2 cleared'), findsOneWidget);
    expect(find.text('1 reviewed'), findsOneWidget);
    expect(find.textContaining('need review'), findsNothing);
    expect(find.text('Final closure'), findsOneWidget);
  });

  testWidgets('confirms no finance activity from the finance row menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repo();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'TEST',
            repository: repo,
            onConfirmNoFinanceActivity: (termId) async {
              expect(termId, repo.value.termId);
              attempts++;
              if (attempts == 1) {
                throw Exception('This term has recorded payments.');
              }
              return HeadmasterTermClosure(
                termId: termId,
                status: repo.value.status,
                termClosed: false,
                readyToClose: false,
                items: [
                  const TermClosureItem(
                    key: 'FINANCE',
                    label: 'Finance and petty cash',
                    status: 'READY',
                    severity: 'BLOCKER',
                    detail: 'No finance activity confirmed for this term.',
                    resolution: 'NO_FINANCE_ACTIVITY',
                  ),
                  ...repo.value.items.where((item) => item.key != 'FINANCE'),
                ],
                acknowledgements: {},
                facilities: {},
                summary: {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> openConfirmation() async {
      await tester.tap(find.byTooltip('Finance options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm no finance activity'));
      await tester.pumpAndSettle();
    }

    await openConfirmation();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(attempts, 0);

    await openConfirmation();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('This term has recorded payments.'), findsOneWidget);
    expect(find.text('Not applicable'), findsNothing);

    await openConfirmation();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Not applicable'), findsOneWidget);
    expect(find.byTooltip('Finance options'), findsNothing);
    expect(find.text('Needs review'), findsOneWidget);
  });

  testWidgets('closes, resumes setup and begins the new term separately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _RolloverRepo();
    var transitioned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'TEST',
            actorUserId: 1,
            repository: repo,
            onSetUpNextTerm: (termId) async {
              expect(termId, 1);
              repo.prepared = true;
              return true;
            },
            onBeginNextTerm: (closedId, nextId) async {
              expect(closedId, 1);
              expect(nextId, 2);
              repo.begun = true;
              return {'nextTermName': 'Second Term', 'studentsTransitioned': 5};
            },
            onTermTransitioned: () => transitioned = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Term transition'), findsOneWidget);
    expect(find.text('Earliest closing date'), findsOneWidget);
    expect(find.text('Office opens / vacation begins'), findsNothing);
    expect(find.text('Teaching starts'), findsOneWidget);
    expect(find.text('Teaching ends'), findsOneWidget);
    expect(find.text('Next term closes'), findsOneWidget);
    expect(find.text('14 Jan 2027'), findsOneWidget);
    expect(find.text('31 Mar 2027'), findsOneWidget);
    expect(find.text('30 Apr 2027'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
    expect(find.text('Balances forward'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Close term'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Close term'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Close term').last;
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, 'CLOSE TERM');
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('First Term is complete'), findsOneWidget);
    expect(repo.begun, isFalse);
    expect(transitioned, isFalse);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recheck readiness'));
    await tester.pumpAndSettle();
    expect(find.text('Next term setup pending'), findsOneWidget);
    expect(find.text('Resume setup'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Begin Second Term'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Resume setup'));
    await tester.pumpAndSettle();
    expect(find.text('Teaching starts'), findsOneWidget);
    expect(find.text('Office opens / vacation begins'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Begin Second Term'));
    await tester.pumpAndSettle();
    expect(find.text('Term transition completed'), findsOneWidget);
    await tester.tap(find.text('Continue to dashboard'));
    await tester.pumpAndSettle();

    expect(transitioned, isTrue);
    expect(repo.getCalls, 4);
    expect(find.text('New-term setup'), findsOneWidget);
    expect(find.text('Old-term ready item'), findsNothing);
  });

  testWidgets('pending rollover sends the prepared term to fee setup', (
    tester,
  ) async {
    final repo = _RolloverRepo()
      ..closed = true
      ..prepared = true
      ..needsFees = true;
    int? selectedTerm;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'SCH-1',
            repository: repo,
            onBeginNextTerm: (_, _) async => {},
            onOpenFees: (termId) => selectedTerm = termId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Begin Second Term'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Open fee setup'));
    expect(selectedTerm, 2);
  });

  testWidgets(
    'groups both transition checks and refreshes after editing dates',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _DateRepo();
      var editorOpens = 0;
      var editedCurrentTermId = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeadmasterTermClosureScreen(
              schoolId: 'TEST',
              repository: repo,
              onOpenTermDates: () async {
                editorOpens++;
                repo.nextTermReady = true;
                return true;
              },
              onEditCurrentTermDates: (termId) async {
                editedCurrentTermId = termId;
                repo.closingDateReached = true;
                return true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final manageDates = find.text('Manage next term dates');
      final closeTerm = find.ancestor(
        of: find.text('Close term'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(find.text('Term transition'), findsOneWidget);
      expect(find.text('Earliest closing date'), findsOneWidget);
      expect(find.text('Next term readiness'), findsOneWidget);
      expect(
        find.text('Configure the next academic term before closing.'),
        findsOneWidget,
      );
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Term closing date'), findsNothing);
      expect(find.text('Next operational term'), findsNothing);
      expect(find.text('Term transition summary'), findsNothing);
      expect(find.text('View dates'), findsNothing);
      expect(find.text('Set up term'), findsNothing);
      expect(find.text('Modify dates'), findsNothing);
      expect(manageDates, findsOneWidget);
      expect(tester.widget<FilledButton>(closeTerm).onPressed, isNull);

      await tester.tap(manageDates);
      await tester.pumpAndSettle();
      expect(editorOpens, 1);
      expect(repo.getCalls, 2);
      expect(find.text('Second Term dates'), findsOneWidget);
      expect(find.text('11 December 2026'), findsOneWidget);
      expect(
        find.text('Student progression and next-term fee setup are complete.'),
        findsOneWidget,
      );
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Needs attention'), findsNothing);
      expect(find.text('CLOSURE SCHEDULED'), findsOneWidget);
      expect(
        find.text('You can close this term on or after 11 December 2026.'),
        findsOneWidget,
      );
      expect(manageDates, findsOneWidget);
      expect(tester.widget<FilledButton>(closeTerm).onPressed, isNotNull);

      await tester.tap(closeTerm);
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(find.text('Term closure is scheduled'), findsOneWidget);
      expect(
        find.descendant(
          of: dialog,
          matching: find.text(
            'You can close this term on or after 11 December 2026.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit current term dates'));
      await tester.pumpAndSettle();
      expect(editedCurrentTermId, repo.value.termId);
      expect(repo.getCalls, 3);
      expect(find.text('Scheduled'), findsNothing);
      expect(find.text('READY TO CLOSE'), findsOneWidget);
      expect(tester.widget<FilledButton>(closeTerm).onPressed, isNotNull);

      repo.nextTermReady = false;
      await tester.tap(find.byTooltip('Recheck readiness'));
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsOneWidget);
      expect(tester.widget<FilledButton>(closeTerm).onPressed, isNull);
    },
  );
}

class _DateRepo implements HeadmasterTermClosureRepository {
  bool closingDateReached = false;
  bool nextTermReady = false;
  int getCalls = 0;

  HeadmasterTermClosure get value => HeadmasterTermClosure(
    termId: 1,
    status: 'DRAFT',
    termClosed: false,
    readyToClose: closingDateReached && nextTermReady,
    items: [
      TermClosureItem(
        key: 'CLOSING_DATE',
        label: 'Term closing date',
        status: closingDateReached ? 'READY' : 'ACTION_REQUIRED',
        severity: 'BLOCKER',
        detail: closingDateReached
            ? 'The term closing window is open.'
            : 'This term cannot close before 2026-12-11.',
      ),
      TermClosureItem(
        key: 'NEXT_TERM',
        label: 'Next operational term',
        status: nextTermReady ? 'READY' : 'ACTION_REQUIRED',
        severity: 'BLOCKER',
        detail: nextTermReady
            ? 'Student progression and next-term fee setup are complete.'
            : 'Configure the next academic term before closing.',
      ),
    ],
    acknowledgements: const {},
    facilities: const {},
    summary: const {},
    transitionPreview: nextTermReady
        ? const {
            'available': true,
            'nextTermName': 'Second Term',
            'currentTermClosingDate': '2026-12-11',
            'operationalStartDate': '2026-12-12',
            'teachingStartDate': '2027-01-14',
            'teachingEndDate': '2027-03-31',
            'closingDate': '2027-04-30',
          }
        : const {
            'available': false,
            'currentTermClosingDate': '2026-12-11',
            'detail': 'Configure the next academic term before closing.',
          },
  );

  @override
  Future<HeadmasterTermClosure> get(String schoolId) async {
    getCalls++;
    return value;
  }

  @override
  Future<HeadmasterTermClosure> saveDraft(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async => value;

  @override
  Future<HeadmasterTermClosure> close(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async => value;

  @override
  Future<List<int>> downloadReport(String schoolId) async => [];
}

class _Repo implements HeadmasterTermClosureRepository {
  bool saved = false;
  final value = const HeadmasterTermClosure(
    termId: 1,
    status: 'DRAFT',
    termClosed: false,
    readyToClose: false,
    items: [
      TermClosureItem(
        key: 'FINANCE',
        label: 'Finance and petty cash',
        status: 'ACTION_REQUIRED',
        severity: 'BLOCKER',
        detail: 'Finance is incomplete.',
      ),
      TermClosureItem(
        key: 'INCIDENTS',
        label: 'Incidents and loss/damage',
        status: 'WARNING',
        severity: 'WARNING',
        detail: 'One incident remains open.',
      ),
      TermClosureItem(
        key: 'REPORTS',
        label: 'Student report cards',
        status: 'READY',
        severity: 'BLOCKER',
        detail: 'All report cards are published.',
      ),
    ],
    acknowledgements: {},
    facilities: {},
    summary: {'students': 10},
  );
  @override
  Future<HeadmasterTermClosure> get(String s) async => value;
  @override
  Future<HeadmasterTermClosure> saveDraft(
    String s,
    HeadmasterTermClosureInput i,
  ) async {
    saved = true;
    return HeadmasterTermClosure(
      termId: value.termId,
      status: value.status,
      termClosed: value.termClosed,
      readyToClose: value.readyToClose,
      items: value.items,
      acknowledgements: i.acknowledgements,
      facilities: i.facilities,
      summary: value.summary,
    );
  }

  @override
  Future<HeadmasterTermClosure> close(
    String s,
    HeadmasterTermClosureInput i,
  ) async => value;
  @override
  Future<List<int>> downloadReport(String s) async => [37, 80, 68, 70];
}

class _RolloverRepo implements HeadmasterTermClosureRepository {
  int getCalls = 0;
  bool closed = false;
  bool prepared = false;
  bool needsFees = false;
  bool begun = false;

  final oldTerm = const HeadmasterTermClosure(
    termId: 1,
    status: 'READY',
    termClosed: false,
    readyToClose: true,
    items: [
      TermClosureItem(
        key: 'READY',
        label: 'Old-term ready item',
        status: 'READY',
        severity: 'INFO',
        detail: 'Ready.',
      ),
    ],
    acknowledgements: {},
    facilities: {},
    summary: {'students': 5},
    transitionPreview: {
      'available': true,
      'nextTermName': 'Second Term',
      'currentTermName': 'First Term',
      'currentTermClosingDate': '2026-12-11',
      'operationalStartDate': '2026-12-12',
      'teachingStartDate': '2027-01-14',
      'teachingEndDate': '2027-03-31',
      'closingDate': '2027-04-30',
    },
  );

  final nextTerm = const HeadmasterTermClosure(
    termId: 2,
    status: 'DRAFT',
    termClosed: false,
    readyToClose: false,
    items: [
      TermClosureItem(
        key: 'NEXT_SETUP',
        label: 'New-term setup',
        status: 'ACTION_REQUIRED',
        severity: 'BLOCKER',
        detail: 'Configure the following term.',
      ),
    ],
    acknowledgements: {},
    facilities: {},
    summary: {'students': 5},
  );

  @override
  Future<HeadmasterTermClosure> get(String schoolId) async {
    getCalls++;
    return begun
        ? nextTerm
        : closed
        ? pending
        : oldTerm;
  }

  HeadmasterTermClosure get pending => HeadmasterTermClosure(
    termId: oldTerm.termId,
    status: 'CLOSED',
    termClosed: true,
    readyToClose: false,
    items: oldTerm.items,
    acknowledgements: const {},
    facilities: const {},
    summary: oldTerm.summary,
    transitionPreview: {
      ...oldTerm.transitionPreview,
      'available': prepared,
      'ready': prepared && !needsFees,
      'missingPublishedFeeStructures': needsFees ? 1 : 0,
      if (prepared) 'nextTermId': 2,
    },
    transition: const {'status': 'PENDING_SETUP'},
  );

  @override
  Future<HeadmasterTermClosure> close(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async {
    closed = true;
    return pending;
  }

  @override
  Future<HeadmasterTermClosure> saveDraft(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async => oldTerm;

  @override
  Future<List<int>> downloadReport(String schoolId) async => [37, 80, 68, 70];
}
