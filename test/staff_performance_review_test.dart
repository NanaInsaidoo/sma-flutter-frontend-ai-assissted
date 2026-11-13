import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/domain/headmaster_term_closure_models.dart';
import 'package:school_management_app/src/term_review/domain/staff_review_models.dart';
import 'package:school_management_app/src/term_review/presentation/term_review_screen.dart';

void main() {
  testWidgets('opens a role-aware staff review and saves a draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeStaffReviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TermReviewScreen(
            schoolId: 'SCHOOL-1',
            reviewerUserId: 12,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff performance reviews'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ama Teacher'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ama Teacher'), findsOneWidget);
    expect(find.text('not started'), findsOneWidget);

    await tester.tap(find.text('Start review'));
    await tester.pumpAndSettle();

    expect(find.text('Teaching quality'), findsOneWidget);
    expect(find.text('Classroom management'), findsOneWidget);
    expect(find.text('Assessment completion'), findsOneWidget);

    final professionalism = find.byKey(const ValueKey('professionalism'));
    final quality = find.byKey(const ValueKey('quality'));
    Finder score(Finder row, int value) =>
        find.descendant(of: row, matching: find.text('$value'));

    final scoreTwoPosition = tester.getCenter(score(professionalism, 2));
    await tester.tap(score(professionalism, 2));
    await tester.pumpAndSettle();
    expect(tester.getCenter(score(professionalism, 2)), scoreTwoPosition);
    expect(
      tester.getCenter(score(professionalism, 2)).dx,
      tester.getCenter(score(quality, 2)).dx,
    );
    await tester.tap(score(quality, 4));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(score(professionalism, 1)).dy,
      greaterThan(
        tester.getBottomLeft(find.text('Professionalism and conduct')).dy,
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Save draft'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repository.savedDrafts, 1);
    expect(repository.lastDraft?.ratings, {'professionalism': 2, 'quality': 4});
    expect(find.text('Draft saved.'), findsOneWidget);
  });

  testWidgets('completed staff reviews show saved values until reopened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1160, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeStaffReviewRepository(
      review: const StaffReview(
        staffId: 'STAFF-1',
        staffName: 'Ama Teacher',
        role: 'CLASS TEACHER',
        status: 'COMPLETED',
        ratings: {'professionalism': 4},
        overallRating: 3,
        strengths: 'Uses clear examples in class.',
        formalFollowUp: true,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TermReviewScreen(
            schoolId: 'SCHOOL-1',
            reviewerUserId: 12,
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View review'));
    await tester.pumpAndSettle();

    final professionalism = find.byKey(const ValueKey('professionalism'));
    expect(find.text('Read-only review'), findsOneWidget);
    expect(
      find.descendant(of: professionalism, matching: find.text('4 / 5')),
      findsOneWidget,
    );
    expect(find.text('3 / 5'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Written assessment'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('Uses clear examples in class.'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Save draft'), findsNothing);

    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    tester.view.physicalSize = const Size(320, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Reopen review'));
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Reopen');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Correct the review notes.');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repository.reopenReason, 'Correct the review notes.');
    expect(find.text('Read-only review'), findsNothing);
    expect(
      tester
          .widget<SegmentedButton<int>>(
            find.descendant(
              of: professionalism,
              matching: find.byType(SegmentedButton<int>),
            ),
          )
          .selected,
      {4},
    );
    await tester.scrollUntilVisible(
      find.text('Written assessment'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(TextField), findsWidgets);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('keeps staff reviews out of the closure dashboard until opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TermReviewScreen(
            schoolId: 'SCHOOL-1',
            reviewerUserId: 12,
            repository: _FakeStaffReviewRepository(),
            headmasterClosureRepository: _FakeHeadmasterClosureRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Term Closure Dashboard'), findsOneWidget);
    expect(find.text('Staff performance reviews'), findsOneWidget);
    expect(
      find.text('Review every staff member before the term is closed.'),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.text('Staff performance reviews'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Staff performance reviews'));
    await tester.pumpAndSettle();
    expect(find.text('Back to Term Closure'), findsOneWidget);
    expect(find.text('Staff performance reviews'), findsOneWidget);
    expect(
      find.text('Review every staff member before the term is closed.'),
      findsOneWidget,
    );
    expect(find.text('Term Closure Dashboard'), findsNothing);

    await tester.tap(find.text('Back to Term Closure'));
    await tester.pumpAndSettle();
    expect(find.text('Term Closure Dashboard'), findsOneWidget);
    expect(
      find.text('Review every staff member before the term is closed.'),
      findsNothing,
    );
  });

  testWidgets(
    'opens facilities inspection from its title and reviews its warning separately',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TermReviewScreen(
              schoolId: 'SCHOOL-1',
              reviewerUserId: 12,
              repository: _FakeStaffReviewRepository(),
              headmasterClosureRepository: _FakeHeadmasterClosureRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open inspection'), findsOneWidget);
      expect(find.text('Review warning'), findsOneWidget);

      await tester.ensureVisible(find.text('Facilities inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facilities inspection'));
      await tester.pumpAndSettle();
      expect(find.text('End-of-term facility inspection'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Back to Term Closure'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review warning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review warning'));
      await tester.pumpAndSettle();
      expect(find.text('Reason for accepting this warning'), findsOneWidget);
      expect(find.text('Save acknowledgement'), findsOneWidget);
      expect(find.text('Open work area'), findsNothing);
      expect(find.text('End-of-term facility inspection'), findsNothing);
    },
  );
}

class _FakeHeadmasterClosureRepository
    implements HeadmasterTermClosureRepository {
  static const value = HeadmasterTermClosure(
    termId: 1,
    status: 'DRAFT',
    termClosed: false,
    readyToClose: false,
    items: [
      TermClosureItem(
        key: 'STAFF_REVIEWS',
        label: 'Staff performance reviews',
        status: 'ACTION_REQUIRED',
        severity: 'BLOCKER',
        detail: 'One staff review is incomplete.',
      ),
      TermClosureItem(
        key: 'FACILITIES',
        label: 'Facilities inspection',
        status: 'WARNING',
        severity: 'WARNING',
        detail: 'Facilities inspection has not been recorded.',
      ),
    ],
    acknowledgements: {},
    facilities: {},
    summary: {},
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

class _FakeStaffReviewRepository implements StaffReviewRepository {
  _FakeStaffReviewRepository({
    this.review = const StaffReview(
      staffId: 'STAFF-1',
      staffName: 'Ama Teacher',
      role: 'TEACHER',
      status: 'NOT_STARTED',
    ),
  });

  int savedDrafts = 0;
  StaffReviewInput? lastDraft;
  String? reopenReason;
  final StaffReview review;

  @override
  Future<StaffReviewDashboardData> getDashboard(String schoolId) async =>
      StaffReviewDashboardData(
        termId: 1,
        termName: 'First Term',
        total: 1,
        notStarted: review.status == 'NOT_STARTED' ? 1 : 0,
        draft: 0,
        completed: review.status == 'COMPLETED' ? 1 : 0,
        reviews: [review],
      );

  @override
  Future<StaffReview> getReview(String schoolId, String staffId) async =>
      review;

  @override
  Future<StaffReview> saveDraft(
    String schoolId,
    String staffId,
    StaffReviewInput input,
  ) async {
    savedDrafts++;
    lastDraft = input;
    return const StaffReview(
      id: 1,
      staffId: 'STAFF-1',
      staffName: 'Ama Teacher',
      role: 'TEACHER',
      status: 'DRAFT',
    );
  }

  @override
  Future<StaffReview> complete(
    String schoolId,
    String staffId,
    StaffReviewInput input,
  ) async => throw UnimplementedError();

  @override
  Future<StaffReview> reopen(
    String schoolId,
    String staffId, {
    required int? reviewerUserId,
    required String reason,
  }) async {
    reopenReason = reason;
    return StaffReview(
      staffId: review.staffId,
      staffName: review.staffName,
      role: review.role,
      status: 'DRAFT',
      ratings: review.ratings,
      overallRating: review.overallRating,
      strengths: review.strengths,
      formalFollowUp: review.formalFollowUp,
    );
  }
}
