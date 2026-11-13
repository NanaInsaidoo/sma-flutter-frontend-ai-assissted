import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/term_review/domain/teacher_term_review_models.dart';
import 'package:school_management_app/src/term_review/presentation/teacher_review_management_panel.dart';
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
    expect(find.text('4 required answers pending'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
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

  testWidgets(
    'highlights missing assessment answers and scrolls to the first',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _FakeTeacherReviewRepository(reflectionComplete: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TeacherTermClosingScreen(
              schoolId: 'S1',
              teacherUserId: 4,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('6 required answers pending'), findsOneWidget);
      final firstAssessment = find.widgetWithText(
        DropdownButtonFormField<String>,
        'How would you assess the headmaster’s performance?',
      );
      expect(
        find.descendant(
          of: firstAssessment,
          matching: find.text('Required · Pending'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Headmaster assessment').hitTestable());
      await tester.pumpAndSettle();
      expect(firstAssessment.hitTestable(), findsOneWidget);

      final submit = find.text('Submit term review');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repo.submissions, 0);
      expect(firstAssessment.hitTestable(), findsOneWidget);
      expect(find.text('Answer required'), findsNWidgets(6));
      final optional = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText?.endsWith('(Optional)') == true,
        ),
      );
      expect(optional.decoration?.errorText, isNull);

      await tester.tap(firstAssessment);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Good').last);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: firstAssessment,
          matching: find.text('Answer required'),
        ),
        findsNothing,
      );
      expect(find.text('5 required answers pending'), findsOneWidget);
    },
  );

  testWidgets('staff review rows reflow and preserve the reopen action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FakeTeacherReviewRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TeacherReviewManagementPanel(
                schoolId: 'S1',
                actorUserId: 4,
                repository: repo,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Staff member'), findsOneWidget);
    expect(find.text('Review status'), findsOneWidget);
    expect(find.text('Class teacher'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Reopen review'), findsOneWidget);

    tester.view.physicalSize = const Size(320, 820);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Review status'), findsNothing);
    expect(find.text(_FakeTeacherReviewRepository.teacherName), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen review').hitTestable());
    await tester.pumpAndSettle();

    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Reopen review'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      'Update the term reflection.',
    );
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repo.reopenedTeacherId, 10);
    expect(repo.reopenReason, 'Update the term reflection.');
    expect(find.text('Reopen review'), findsNothing);
  });
}

class _FakeTeacherReviewRepository implements TeacherTermReviewRepository {
  _FakeTeacherReviewRepository({bool reflectionComplete = false})
    : current = TeacherTermReview(
        termId: 1,
        status: 'OPEN',
        opensOn: DateTime.now().subtract(const Duration(days: 1)),
        deadline: DateTime.now().add(const Duration(days: 7)),
        reviewStatus: 'NOT_STARTED',
        reflection: reflectionComplete
            ? const {
                'workedWell': 'Peer feedback.',
                'challenges': 'Limited materials.',
                'changeNextTerm': 'More practice sessions.',
                'supportNeeded': 'Training on assessments.',
              }
            : const {},
        leadership: const {},
        recommendations: const [],
        damageConfirmed: reflectionComplete,
        recommendationsSubmitted: reflectionComplete,
        seriousConcern: false,
        assessmentIncompleteCount: reflectionComplete ? 0 : 2,
        evaluationIncompleteCount: reflectionComplete ? 0 : 1,
      );

  int drafts = 0;
  int submissions = 0;
  int? reopenedTeacherId;
  String? reopenReason;
  static const teacherName = 'Ama Assessment Teacher with a Long Display Name';
  final TeacherTermReview current;
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
  Future<TeacherTermReview> submit(
    String s,
    int u,
    TeacherTermReviewInput i,
  ) async {
    submissions++;
    return current;
  }

  @override
  Future<TeacherReviewDashboard> getDashboard(String s) async {
    final reopened = reopenedTeacherId != null;
    return TeacherReviewDashboard(
      termId: 1,
      status: 'OPEN',
      total: 2,
      notStarted: 1,
      draft: reopened ? 1 : 0,
      submitted: reopened ? 0 : 1,
      closed: 0,
      teachers: [
        TeacherReviewRow(
          teacherUserId: 10,
          name: teacherName,
          role: 'CLASS TEACHER',
          status: reopened ? 'DRAFT' : 'SUBMITTED',
        ),
        const TeacherReviewRow(
          teacherUserId: 11,
          name: 'Esi Assessment',
          role: 'ADMINISTRATOR',
          status: 'NOT_STARTED',
        ),
      ],
    );
  }

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
  }) async {
    reopenedTeacherId = u;
    reopenReason = reason;
    return current;
  }
}
