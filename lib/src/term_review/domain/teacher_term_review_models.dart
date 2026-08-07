class TeacherReviewWindow {
  const TeacherReviewWindow({
    required this.termId,
    required this.status,
    this.opensOn,
    this.deadline,
  });
  final int termId;
  final String status;
  final DateTime? opensOn;
  final DateTime? deadline;
}

class TeacherReviewDashboard extends TeacherReviewWindow {
  const TeacherReviewDashboard({
    required super.termId,
    required super.status,
    super.opensOn,
    super.deadline,
    required this.total,
    required this.notStarted,
    required this.draft,
    required this.submitted,
    required this.closed,
    required this.teachers,
  });
  final int total, notStarted, draft, submitted, closed;
  final List<TeacherReviewRow> teachers;
}

class TeacherReviewRow {
  const TeacherReviewRow({
    required this.teacherUserId,
    required this.name,
    required this.role,
    required this.status,
  });
  final int teacherUserId;
  final String name, role, status;
}

class NextTermRecommendation {
  const NextTermRecommendation({
    required this.name,
    required this.category,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.reason,
  });
  final String name, category, description, reason;
  final int quantity;
  final double unitPrice;
  Map<String, Object> toJson() => {
    'name': name,
    'category': category,
    'description': description,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'reason': reason,
  };
  factory NextTermRecommendation.fromJson(Map<String, dynamic> j) =>
      NextTermRecommendation(
        name: '${j['name'] ?? ''}',
        category: '${j['category'] ?? ''}',
        description: '${j['description'] ?? ''}',
        quantity: int.tryParse('${j['quantity']}') ?? 1,
        unitPrice: double.tryParse('${j['unitPrice']}') ?? 0,
        reason: '${j['reason'] ?? ''}',
      );
}

class TeacherTermReview extends TeacherReviewWindow {
  const TeacherTermReview({
    required super.termId,
    required super.status,
    super.opensOn,
    super.deadline,
    required this.reviewStatus,
    required this.reflection,
    required this.leadership,
    required this.recommendations,
    required this.damageConfirmed,
    required this.recommendationsSubmitted,
    required this.seriousConcern,
    this.seriousConcernDetails = '',
    required this.assessmentIncompleteCount,
    required this.evaluationIncompleteCount,
  });
  final String reviewStatus;
  final Map<String, String> reflection, leadership;
  final List<NextTermRecommendation> recommendations;
  final bool damageConfirmed, recommendationsSubmitted, seriousConcern;
  final String seriousConcernDetails;
  final int assessmentIncompleteCount, evaluationIncompleteCount;
}

class TeacherTermReviewInput {
  const TeacherTermReviewInput({
    required this.reflection,
    required this.leadership,
    required this.recommendations,
    required this.damageConfirmed,
    required this.recommendationsSubmitted,
    required this.seriousConcern,
    required this.seriousConcernDetails,
  });
  final Map<String, String> reflection, leadership;
  final List<NextTermRecommendation> recommendations;
  final bool damageConfirmed, recommendationsSubmitted, seriousConcern;
  final String seriousConcernDetails;
}

abstract class TeacherTermReviewRepository {
  Future<TeacherReviewDashboard> getDashboard(String schoolId);
  Future<TeacherReviewWindow> release(
    String schoolId, {
    required int? actorUserId,
    required DateTime opensOn,
    required DateTime deadline,
  });
  Future<TeacherReviewWindow> close(
    String schoolId, {
    required int? actorUserId,
  });
  Future<TeacherTermReview> getTeacherReview(
    String schoolId,
    int teacherUserId,
  );
  Future<TeacherTermReview> saveDraft(
    String schoolId,
    int teacherUserId,
    TeacherTermReviewInput input,
  );
  Future<TeacherTermReview> submit(
    String schoolId,
    int teacherUserId,
    TeacherTermReviewInput input,
  );
  Future<TeacherTermReview> reopen(
    String schoolId,
    int teacherUserId, {
    required int? actorUserId,
    required String reason,
  });
}
