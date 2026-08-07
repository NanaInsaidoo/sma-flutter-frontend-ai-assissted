import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
