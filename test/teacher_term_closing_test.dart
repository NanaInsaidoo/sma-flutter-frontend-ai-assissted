import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/domain/teacher_term_review_models.dart';
import 'package:school_management_app/src/term_review/presentation/teacher_term_closing_screen.dart';

void main() {
  testWidgets('shows focused closing actions and saves a teacher draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repo = _FakeTeacherReviewRepository();
    var incidentOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeacherTermClosingScreen(
            schoolId: 'S1',
            teacherUserId: 4,
            repository: repo,
            onOpenIncidents: () => incidentOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Close your teaching term'), findsOneWidget);
    expect(find.text('Items requiring action'), findsOneWidget);
    expect(find.text('Loss and damage declaration'), findsOneWidget);
    await tester.tap(find.text('Loss and damage declaration'));
    expect(incidentOpened, isTrue);
    await tester.scrollUntilVisible(
      find.text('Save draft'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repo.drafts, 1);
    expect(find.text('Draft saved.'), findsOneWidget);
  });
}

class _FakeTeacherReviewRepository implements TeacherTermReviewRepository {
  int drafts = 0;
  final current = TeacherTermReview(
    termId: 1,
    status: 'OPEN',
    opensOn: DateTime.now().subtract(const Duration(days: 1)),
    deadline: DateTime.now().add(const Duration(days: 7)),
    reviewStatus: 'NOT_STARTED',
    reflection: const {},
    leadership: const {},
    recommendations: const [],
    damageConfirmed: false,
    recommendationsSubmitted: false,
    seriousConcern: false,
    assessmentIncompleteCount: 2,
    evaluationIncompleteCount: 1,
  );
  @override
  Future<TeacherTermReview> getTeacherReview(String s, int u) async => current;
  @override
  Future<TeacherTermReview> saveDraft(
    String s,
    int u,
    TeacherTermReviewInput i,
  ) async {
    drafts++;
    return TeacherTermReview(
      termId: 1,
      status: 'OPEN',
      opensOn: current.opensOn,
      deadline: current.deadline,
      reviewStatus: 'DRAFT',
      reflection: i.reflection,
      leadership: i.leadership,
      recommendations: i.recommendations,
      damageConfirmed: i.damageConfirmed,
      recommendationsSubmitted: i.recommendationsSubmitted,
      seriousConcern: i.seriousConcern,
      assessmentIncompleteCount: 2,
      evaluationIncompleteCount: 1,
    );
  }

  @override
  Future<TeacherTermReview> submit(String s, int u, TeacherTermReviewInput i) =>
      throw UnimplementedError();
  @override
  Future<TeacherReviewDashboard> getDashboard(String s) =>
      throw UnimplementedError();
  @override
  Future<TeacherReviewWindow> release(
    String s, {
    required int? actorUserId,
    required DateTime opensOn,
    required DateTime deadline,
  }) => throw UnimplementedError();
  @override
  Future<TeacherReviewWindow> close(String s, {required int? actorUserId}) =>
      throw UnimplementedError();
  @override
  Future<TeacherTermReview> reopen(
    String s,
    int u, {
    required int? actorUserId,
    required String reason,
  }) => throw UnimplementedError();
}
