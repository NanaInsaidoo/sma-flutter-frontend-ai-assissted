import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/domain/headmaster_term_closure_models.dart';
import 'package:school_management_app/src/term_review/domain/staff_review_models.dart';
import 'package:school_management_app/src/term_review/presentation/term_review_screen.dart';

void main() {
  testWidgets('opens a role-aware staff review and saves a draft', (
    tester,
  ) async {
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

    await tester.scrollUntilVisible(
      find.text('Save draft'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repository.savedDrafts, 1);
    expect(find.text('Draft saved.'), findsOneWidget);
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
      find.text('Review staff'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Review staff'));
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
  int savedDrafts = 0;
  final review = const StaffReview(
    staffId: 'STAFF-1',
    staffName: 'Ama Teacher',
    role: 'TEACHER',
    status: 'NOT_STARTED',
  );

  @override
  Future<StaffReviewDashboardData> getDashboard(String schoolId) async =>
      StaffReviewDashboardData(
        termId: 1,
        termName: 'First Term',
        total: 1,
        notStarted: 1,
        draft: 0,
        completed: 0,
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
  }) async => throw UnimplementedError();
}
