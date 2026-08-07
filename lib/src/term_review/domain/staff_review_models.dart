class StaffReviewDashboardData {
  const StaffReviewDashboardData({
    required this.termId,
    required this.termName,
    required this.total,
    required this.notStarted,
    required this.draft,
    required this.completed,
    required this.reviews,
  });
  final int termId;
  final String termName;
  final int total;
  final int notStarted;
  final int draft;
  final int completed;
  final List<StaffReview> reviews;
}

class StaffReview {
  const StaffReview({
    this.id,
    required this.staffId,
    required this.staffName,
    required this.role,
    required this.status,
    this.ratings = const {},
    this.overallRating,
    this.strengths = '',
    this.improvementAreas = '',
    this.trainingSupport = '',
    this.nextTermActions = '',
    this.formalFollowUp = false,
    this.finalComments = '',
    this.updatedAt,
  });
  final int? id;
  final String staffId;
  final String staffName;
  final String role;
  final String status;
  final Map<String, int> ratings;
  final int? overallRating;
  final String strengths;
  final String improvementAreas;
  final String trainingSupport;
  final String nextTermActions;
  final bool formalFollowUp;
  final String finalComments;
  final DateTime? updatedAt;
}

class StaffReviewInput {
  const StaffReviewInput({
    required this.reviewerUserId,
    required this.ratings,
    required this.overallRating,
    required this.strengths,
    required this.improvementAreas,
    required this.trainingSupport,
    required this.nextTermActions,
    required this.formalFollowUp,
    required this.finalComments,
  });
  final int? reviewerUserId;
  final Map<String, int> ratings;
  final int? overallRating;
  final String strengths;
  final String improvementAreas;
  final String trainingSupport;
  final String nextTermActions;
  final bool formalFollowUp;
  final String finalComments;
}

abstract class StaffReviewRepository {
  Future<StaffReviewDashboardData> getDashboard(String schoolId);
  Future<StaffReview> getReview(String schoolId, String staffId);
  Future<StaffReview> saveDraft(
    String schoolId,
    String staffId,
    StaffReviewInput input,
  );
  Future<StaffReview> complete(
    String schoolId,
    String staffId,
    StaffReviewInput input,
  );
  Future<StaffReview> reopen(
    String schoolId,
    String staffId, {
    required int? reviewerUserId,
    required String reason,
  });
}
