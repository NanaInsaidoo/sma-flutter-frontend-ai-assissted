import '../domain/platform_models.dart';

abstract interface class PlatformRepository {
  /// Future backend route: GET /api/v1/account-managers/me/dashboard
  Future<AccountManagerSnapshot> getAccountManagerDashboard();

  /// Backend route: GET /api/super-admin/needs-attention/summary
  Future<NeedsAttentionSummary> getNeedsAttentionSummary();

  /// Backend route: GET /api/super-admin/needs-attention
  Future<NeedsAttentionPage> getNeedsAttentionItems({
    required String category,
    String? searchTerm,
    int page = 0,
    int size = 20,
  });

  /// Future backend route: POST /api/v1/schools
  Future<ManagedSchool> createSchool(SchoolDraft draft);

  /// Future backend route: GET /api/super-admin/dashboard/schools
  Future<ManagedSchoolPage> getSchools({
    String? searchTerm,
    String? region,
    String? district,
    String? status,
    String? accountManagerId,
    int page = 0,
    int size = 10,
  });

  /// Load a full in-progress school registration record.
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  );

  /// Load the backend-composed final registration review.
  Future<SchoolOnboardingRecord> getSchoolReviewRecord(String customSchoolId);

  /// Save one school onboarding step and returns backend onboarding progress.
  Future<SchoolOnboardingProgress> saveSchoolOnboardingStep({
    required int stepIndex,
    required SchoolOnboardingDraft draft,
  });

  /// Finalize a completed onboarding record.
  Future<SchoolOnboardingRecord> finishSchoolSetup(String customSchoolId);

  /// Backend route: PUT /api/schools/{customSchoolId}/changeschoolstatus
  Future<void> changeSchoolStatus({
    required String customSchoolId,
    required SchoolStatus status,
    String? reason,
  });

  /// Generate a short-lived URL for viewing a saved school document.
  Future<String> getSchoolDocumentDownloadUrl({
    required String customSchoolId,
    required String documentId,
  });

  /// Load confirmed documents belonging to a school.
  Future<List<SchoolDocumentInfo>> getSchoolDocuments(String customSchoolId);

  /// Load the selected grade levels and streams for an existing school.
  Future<List<SchoolGradeLevelInfo>> getSchoolGradeLevels(
    String customSchoolId,
  );

  /// Invite the first or an additional administrator for a school.
  Future<SchoolAdministratorInviteResult> inviteSchoolAdministrator({
    required String customSchoolId,
    required SchoolAdministratorInvite invite,
  });

  /// Load users belonging to a school.
  Future<List<SchoolUserInfo>> getSchoolUsers(String customSchoolId);

  /// Approve a pending user account.
  Future<SchoolUserInfo?> approveSchoolUser({
    required String customSchoolId,
    required String userId,
  });

  /// Reject a pending user account.
  Future<SchoolUserInfo?> rejectSchoolUser({
    required String customSchoolId,
    required String userId,
    String? reason,
  });

  /// Suspend an active user account.
  Future<void> suspendSchoolUser({
    required String customSchoolId,
    required String userId,
    String? reason,
  });

  /// Reactivate a suspended user account.
  Future<void> reactivateSchoolUser({
    required String customSchoolId,
    required String userId,
  });

  /// Change a user's role.
  Future<SchoolUserInfo?> updateSchoolUserRole({
    required String customSchoolId,
    required String userId,
    required String role,
  });

  /// Resend generated credentials to the user.
  Future<SchoolAdministratorInviteResult> resendSchoolUserCredentials({
    required String customSchoolId,
    required String userId,
  });

  /// Reset a user's password to a new temporary password.
  Future<SchoolAdministratorInviteResult> resetSchoolUserPassword({
    required String customSchoolId,
    required String userId,
  });

  /// Load audit log entries for a user.
  Future<UserAuditLogPage> getUserAuditLogs({
    required String userId,
    int page = 0,
    int size = 50,
  });

  /// Backend route: GET /api/account-managers/?page=...&size=...
  Future<List<AccountManagerProfile>> getAccountManagers();

  /// Backend route: GET /api/account-managers/?page=...&size=...
  Future<AccountManagerPage> getAccountManagerPage({
    String? searchTerm,
    List<String> userStatuses = const [],
    int page = 0,
    int size = 20,
  });

  /// Backend route: GET /api/account-managers/?searchTerm=...&userStatuses=...
  Future<List<AccountManagerProfile>> searchAccountManagers({
    required String searchTerm,
    List<String> userStatuses = const ['ACTIVE'],
    int page = 0,
    int size = 10,
  });

  /// Future backend route: POST /api/v1/account-managers/invitations
  Future<AccountManagerProfile> createAccountManager(AccountManagerDraft draft);

  /// Backend route: PATCH /api/account-managers/{id}/status
  Future<AccountManagerProfile> updateAccountManagerStatus({
    required String accountManagerId,
    required AccountManagerStatus status,
    String? reason,
  });

  /// Backend route: DELETE /api/account-managers/{id}
  Future<void> deleteAccountManager({
    required String accountManagerId,
    String? reason,
  });

  /// Backend route: POST /api/account-managers/{id}/reset-password
  Future<SchoolAdministratorInviteResult> forceResetAccountManagerPassword({
    required AccountManagerProfile manager,
  });

  /// Backend route: POST /api/account-managers/{id}/resend-credentials
  Future<SchoolAdministratorInviteResult> resendAccountManagerCredentials({
    required AccountManagerProfile manager,
  });

  /// Backend route: GET /api/account-managers/school-assignment-reasons
  Future<List<SchoolAssignmentReasonOption>> getSchoolAssignmentReasons();

  /// Backend route: POST /api/account-managers/{id}/assign-schools
  Future<AccountManagerProfile> assignSchoolsToAccountManager({
    required String accountManagerId,
    required List<String> customSchoolIds,
    required String reason,
    String? notes,
  });
}
