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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeadmasterTermClosureScreen(
            schoolId: 'TEST',
            actorUserId: 1,
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Term readiness and closure'), findsOneWidget);
    expect(find.text('ACTION REQUIRED'), findsWidgets);
    expect(find.text('Finance and petty cash'), findsOneWidget);
    expect(
      find.text('Reason for accepting this warning before closure'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextField).first,
      'Accepted for final report',
    );
    expect(find.text('Close term and begin next term'), findsOneWidget);
    await tester.tap(find.text('Save closure draft'));
    await tester.pumpAndSettle();
    expect(repo.saved, isTrue);
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
    return value;
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
      'operationalStartDate': '2026-08-21',
      'teachingStartDate': '2027-01-11',
      'students': 5,
      'balancesToCarryForward': 6090,
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
