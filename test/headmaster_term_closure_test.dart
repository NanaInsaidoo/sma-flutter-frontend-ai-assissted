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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'TEST',
            actorUserId: 1,
            repository: repo,
            workstreamActions: {'REPORTS': () => reportsOpened = true},
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
    expect(find.text('Student report cards'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    await tester.tap(find.text('View'));
    expect(reportsOpened, isTrue);
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

  testWidgets('reloads the new operational term after a rollover', (
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
            onTermTransitioned: () => transitioned = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Term transition summary'), findsOneWidget);
    expect(find.text('Current term closes'), findsOneWidget);
    expect(find.text('Office opens / vacation begins'), findsOneWidget);
    expect(find.text('Teaching starts'), findsOneWidget);
    expect(find.text('Teaching ends'), findsOneWidget);
    expect(find.text('Next term closes'), findsOneWidget);
    expect(find.text('12 Dec 2026'), findsOneWidget);
    expect(find.text('14 Jan 2027'), findsOneWidget);
    expect(find.text('31 Mar 2027'), findsOneWidget);
    expect(find.text('30 Apr 2027'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
    expect(find.text('Balances forward'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Close term and begin next term'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Close term and begin next term'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'CLOSE TERM');
    await tester.tap(
      find.widgetWithText(FilledButton, 'Close term and begin next term').last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Term transition completed'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(transitioned, isTrue);
    expect(repo.getCalls, 2);
    expect(find.text('New-term setup'), findsOneWidget);
    expect(find.text('Old-term ready item'), findsNothing);
  });

  testWidgets('opens the same date editor from summary and checklist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var editorOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'TEST',
            repository: _DateRepo(),
            onOpenTermDates: () async {
              editorOpens++;
              return false;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View dates'));
    await tester.pump();
    expect(editorOpens, 1);

    await tester.scrollUntilVisible(
      find.text('Modify dates'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Modify dates'));
    await tester.pump();
    expect(editorOpens, 2);
  });
}

class _DateRepo implements HeadmasterTermClosureRepository {
  static const value = HeadmasterTermClosure(
    termId: 1,
    status: 'DRAFT',
    termClosed: false,
    readyToClose: false,
    items: [
      TermClosureItem(
        key: 'CLOSING_DATE',
        label: 'Term closing date',
        status: 'SCHEDULED',
        severity: 'BLOCKER',
        detail: 'This term cannot close before 2026-12-11.',
      ),
    ],
    acknowledgements: {},
    facilities: {},
    summary: {},
    transitionPreview: {
      'available': true,
      'nextTermName': 'Second Term',
      'currentTermClosingDate': '2026-12-11',
      'operationalStartDate': '2026-12-12',
      'teachingStartDate': '2027-01-14',
      'teachingEndDate': '2027-03-31',
      'closingDate': '2027-04-30',
    },
  );

  @override
  Future<HeadmasterTermClosure> get(String schoolId) async => value;

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
    return getCalls == 1 ? oldTerm : nextTerm;
  }

  @override
  Future<HeadmasterTermClosure> close(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async => HeadmasterTermClosure(
    termId: oldTerm.termId,
    status: 'CLOSED',
    termClosed: true,
    readyToClose: false,
    items: oldTerm.items,
    acknowledgements: const {},
    facilities: const {},
    summary: oldTerm.summary,
    transitionPreview: oldTerm.transitionPreview,
    transition: const {
      'nextTermName': 'Second Term',
      'studentsTransitioned': 5,
      'balanceAmount': 6090,
      'nextTermFeeLinesAssigned': 15,
    },
  );

  @override
  Future<HeadmasterTermClosure> saveDraft(
    String schoolId,
    HeadmasterTermClosureInput input,
  ) async => oldTerm;

  @override
  Future<List<int>> downloadReport(String schoolId) async => [37, 80, 68, 70];
}
