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
