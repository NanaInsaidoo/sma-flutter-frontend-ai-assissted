enum SchoolStatus {
  inProgress,
  completed,
  pendingApproval,
  needsRevision,
  approved,
  rejected,
  suspended,
  inactive,
  deleted,
}

SchoolStatus schoolStatusFromApi(String? value) {
  return switch (value?.trim().toUpperCase()) {
    'COMPLETED' => SchoolStatus.completed,
    'PENDING_APPROVAL' => SchoolStatus.pendingApproval,
    'NEEDS_REVISION' => SchoolStatus.needsRevision,
    'APPROVED' => SchoolStatus.approved,
    'REJECTED' => SchoolStatus.rejected,
    'SUSPENDED' => SchoolStatus.suspended,
    'INACTIVE' => SchoolStatus.inactive,
    'DELETED' => SchoolStatus.deleted,
    _ => SchoolStatus.inProgress,
  };
}

extension SchoolStatusDetails on SchoolStatus {
  String get apiValue => switch (this) {
    SchoolStatus.inProgress => 'IN_PROGRESS',
    SchoolStatus.completed => 'COMPLETED',
    SchoolStatus.pendingApproval => 'PENDING_APPROVAL',
    SchoolStatus.needsRevision => 'NEEDS_REVISION',
    SchoolStatus.approved => 'APPROVED',
    SchoolStatus.rejected => 'REJECTED',
    SchoolStatus.suspended => 'SUSPENDED',
    SchoolStatus.inactive => 'INACTIVE',
    SchoolStatus.deleted => 'DELETED',
  };

  String get label => switch (this) {
    SchoolStatus.inProgress => 'In Progress',
    SchoolStatus.completed => 'Completed',
    SchoolStatus.pendingApproval => 'Pending Approval',
    SchoolStatus.needsRevision => 'Needs Revision',
    SchoolStatus.approved => 'Approved',
    SchoolStatus.rejected => 'Rejected',
    SchoolStatus.suspended => 'Suspended',
    SchoolStatus.inactive => 'Inactive',
    SchoolStatus.deleted => 'Deleted',
  };

  bool get isApproved => this == SchoolStatus.approved;
  bool get isOnboarding => this == SchoolStatus.inProgress;
  bool get canResumeOnboarding =>
      this == SchoolStatus.inProgress || this == SchoolStatus.needsRevision;
  bool get needsAttention =>
      this == SchoolStatus.needsRevision ||
      this == SchoolStatus.rejected ||
      this == SchoolStatus.suspended ||
      this == SchoolStatus.inactive;
}

enum PlatformRole { accountManager, superAccountManager, superAdmin }

PlatformRole platformRoleFromApiRole(
  String? value, {
  bool isAccountManager = false,
}) {
  final role = value?.trim().toUpperCase() ?? '';
  return switch (role) {
    'SUPER_ADMIN' => PlatformRole.superAdmin,
    'SUPER_ACCOUNT_MANAGER' => PlatformRole.superAccountManager,
    'ACCOUNT_MANAGER' ||
    'ACCOUNT_MANAGER_UNVERIFIED' ||
    'ACCOUNT_MANAGER_VERIFIED_STAFF' => PlatformRole.accountManager,
    _ when isAccountManager => PlatformRole.accountManager,
    _ => PlatformRole.accountManager,
  };
}

extension PlatformRoleDetails on PlatformRole {
  bool get canManageAccountManagers =>
      this == PlatformRole.superAccountManager ||
      this == PlatformRole.superAdmin;

  bool get canViewAllSchools =>
      this == PlatformRole.superAccountManager ||
      this == PlatformRole.superAdmin;

  String get label => switch (this) {
    PlatformRole.accountManager => 'Account Manager',
    PlatformRole.superAccountManager => 'Super Account Manager',
    PlatformRole.superAdmin => 'Super Admin',
  };

  String get apiRole => switch (this) {
    PlatformRole.accountManager => 'ACCOUNT_MANAGER',
    PlatformRole.superAccountManager => 'SUPER_ACCOUNT_MANAGER',
    PlatformRole.superAdmin => 'SUPER_ADMIN',
  };
}

enum AccountManagerStatus { active, pendingApproval, invited, suspended }

class AccountManagerProfile {
  const AccountManagerProfile({
    this.id = '',
    this.userId = '',
    required this.name,
    required this.email,
    required this.phone,
    required this.region,
    required this.schoolCount,
    required this.activeSchoolCount,
    required this.status,
    required this.lastActive,
    required this.joined,
    required this.inviteMethod,
    required this.verified,
    required this.bio,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String region;
  final int schoolCount;
  final int activeSchoolCount;
  final AccountManagerStatus status;
  final String lastActive;
  final String joined;
  final String inviteMethod;
  final bool verified;
  final String bio;
}

class AccountManagerPage {
  const AccountManagerPage({
    required this.managers,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final List<AccountManagerProfile> managers;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  bool get hasPrevious => currentPage > 0;
  bool get hasNext => currentPage + 1 < totalPages;
}

class SchoolAssignmentReasonOption {
  const SchoolAssignmentReasonOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class AccountManagerDraft {
  const AccountManagerDraft({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.inviteMethod,
    required this.role,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime dateOfBirth;
  final String inviteMethod;
  final PlatformRole role;
}

class SchoolAdministratorInvite {
  const SchoolAdministratorInvite({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    this.middleName = '',
    this.emailDelivery = true,
    this.smsDelivery = true,
  });

  final String firstName;
  final String middleName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final bool emailDelivery;
  final bool smsDelivery;
}

class SchoolAdministratorInviteResult {
  const SchoolAdministratorInviteResult({
    required this.message,
    this.username,
    this.temporaryPassword,
    this.user,
  });

  final String message;
  final String? username;
  final String? temporaryPassword;
  final SchoolUserInfo? user;
}

class SchoolUserInfo {
  const SchoolUserInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.lastLogin,
    this.username = '',
    this.userType = '',
    this.customSchoolId = '',
    this.schoolName = '',
    this.createdAt = '',
    this.invitedAt = '',
    this.dateOfBirth = '',
  });

  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final String status;
  final String lastLogin;
  final String username;
  final String userType;
  final String customSchoolId;
  final String schoolName;
  final String createdAt;
  final String invitedAt;
  final String dateOfBirth;

  bool get isAdministrator => role.trim().toUpperCase() == 'ADMINISTRATOR';

  bool get isPendingApproval {
    final value = status.trim().toUpperCase();
    return value == 'PENDING' ||
        value == 'PENDING_APPROVAL' ||
        value == 'AWAITING_APPROVAL';
  }

  SchoolUserInfo copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? role,
    String? status,
    String? lastLogin,
    String? username,
    String? userType,
    String? customSchoolId,
    String? schoolName,
    String? createdAt,
    String? invitedAt,
    String? dateOfBirth,
  }) {
    return SchoolUserInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      status: status ?? this.status,
      lastLogin: lastLogin ?? this.lastLogin,
      username: username ?? this.username,
      userType: userType ?? this.userType,
      customSchoolId: customSchoolId ?? this.customSchoolId,
      schoolName: schoolName ?? this.schoolName,
      createdAt: createdAt ?? this.createdAt,
      invitedAt: invitedAt ?? this.invitedAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}

class UserAuditLogPage {
  const UserAuditLogPage({
    required this.userId,
    required this.userName,
    required this.logs,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final String userId;
  final String userName;
  final List<UserAuditLog> logs;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;
}

class UserAuditLog {
  const UserAuditLog({
    required this.id,
    required this.userId,
    required this.performedBy,
    required this.actionType,
    required this.description,
    required this.timestamp,
    required this.ipAddress,
    required this.userAgent,
    required this.metadata,
  });

  final String id;
  final String userId;
  final String performedBy;
  final String actionType;
  final String description;
  final String timestamp;
  final String ipAddress;
  final String userAgent;
  final String? metadata;
}

class ManagedSchool {
  const ManagedSchool({
    required this.name,
    required this.code,
    required this.region,
    required this.town,
    required this.students,
    required this.staff,
    required this.status,
    required this.progress,
    required this.accountManager,
    required this.subscriptionPlan,
    required this.subscriptionStatus,
    required this.renewalDate,
    required this.lastActive,
    required this.approvedDate,
    required this.administratorName,
    required this.administratorPhone,
    required this.administratorEmail,
    this.accountManagerId = '',
    this.district = '',
  });

  final String name;
  final String code;
  final String region;
  final String district;
  final String town;
  final int students;
  final int staff;
  final SchoolStatus status;
  final double progress;
  final String accountManager;
  final String accountManagerId;
  final String subscriptionPlan;
  final String subscriptionStatus;
  final String renewalDate;
  final String lastActive;
  final String approvedDate;
  final String administratorName;
  final String administratorPhone;
  final String administratorEmail;

  ManagedSchool copyWith({
    String? name,
    String? code,
    String? region,
    String? district,
    String? town,
    int? students,
    int? staff,
    SchoolStatus? status,
    double? progress,
    String? accountManager,
    String? accountManagerId,
    String? subscriptionPlan,
    String? subscriptionStatus,
    String? renewalDate,
    String? lastActive,
    String? approvedDate,
    String? administratorName,
    String? administratorPhone,
    String? administratorEmail,
  }) {
    return ManagedSchool(
      name: name ?? this.name,
      code: code ?? this.code,
      region: region ?? this.region,
      district: district ?? this.district,
      town: town ?? this.town,
      students: students ?? this.students,
      staff: staff ?? this.staff,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      accountManager: accountManager ?? this.accountManager,
      accountManagerId: accountManagerId ?? this.accountManagerId,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      renewalDate: renewalDate ?? this.renewalDate,
      lastActive: lastActive ?? this.lastActive,
      approvedDate: approvedDate ?? this.approvedDate,
      administratorName: administratorName ?? this.administratorName,
      administratorPhone: administratorPhone ?? this.administratorPhone,
      administratorEmail: administratorEmail ?? this.administratorEmail,
    );
  }
}

class ManagedSchoolPage {
  const ManagedSchoolPage({
    required this.schools,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final List<ManagedSchool> schools;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  bool get hasPrevious => currentPage > 0;
  bool get hasNext => currentPage + 1 < totalPages;
}

class SchoolOnboardingProgress {
  const SchoolOnboardingProgress({
    required this.customSchoolId,
    required this.registrationStatus,
    required this.currentStep,
    required this.completedSteps,
    this.totalSteps = 9,
  });

  final String? customSchoolId;
  final String registrationStatus;
  final String currentStep;
  final List<String> completedSteps;
  final int totalSteps;

  int get completedStepCount => completedSteps.length.clamp(0, totalSteps);

  double get completionPercentage =>
      totalSteps == 0 ? 0 : completedStepCount / totalSteps;
}

class SchoolOnboardingRecord {
  const SchoolOnboardingRecord({required this.data, required this.progress});

  final Map<String, dynamic> data;
  final SchoolOnboardingProgress progress;
}

class SchoolDocumentInfo {
  const SchoolDocumentInfo({
    required this.documentId,
    required this.fileName,
    required this.fileSize,
    required this.contentType,
    required this.documentType,
    required this.status,
  });

  final String documentId;
  final String fileName;
  final int fileSize;
  final String contentType;
  final String documentType;
  final String status;
}

class SchoolGradeLevelInfo {
  const SchoolGradeLevelInfo({
    required this.gradeLevelId,
    required this.gradeLevelName,
    required this.numberOfStreams,
    this.status = 'ACTIVE',
  });

  final int gradeLevelId;
  final String gradeLevelName;
  final int numberOfStreams;
  final String status;
}

class NeedsAttentionSummary {
  const NeedsAttentionSummary({required this.total, required this.categories});

  final int total;
  final List<NeedsAttentionCategory> categories;
}

class NeedsAttentionCategory {
  const NeedsAttentionCategory({
    required this.category,
    required this.label,
    required this.count,
    required this.priority,
  });

  final String category;
  final String label;
  final int count;
  final String priority;
}

class NeedsAttentionPage {
  const NeedsAttentionPage({
    required this.items,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final List<NeedsAttentionItem> items;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  bool get hasPrevious => currentPage > 0;
  bool get hasNext => currentPage + 1 < totalPages;
}

class NeedsAttentionItem {
  const NeedsAttentionItem({
    required this.id,
    required this.category,
    required this.priority,
    required this.title,
    required this.description,
    required this.entityType,
    required this.entityId,
    required this.status,
    required this.actionTarget,
    this.ageInDays,
    this.type = '',
    this.createdAt = '',
  });

  final String id;
  final String category;
  final String priority;
  final String title;
  final String description;
  final String entityType;
  final String entityId;
  final String status;
  final int? ageInDays;
  final String actionTarget;
  final String type;
  final String createdAt;
}

class AccountManagerSnapshot {
  const AccountManagerSnapshot({
    required this.managerName,
    required this.schools,
    required this.accountManagers,
    required this.pendingApprovals,
    this.totalSchoolsValue,
    this.activeSchoolsValue,
    this.totalSchoolsCaption = '',
    this.activeSchoolsCaption = '',
    this.accountManagersCaption = '',
    this.pendingApprovalsCaption = '',
    this.needsAttentionSummary,
  });

  final String managerName;
  final List<ManagedSchool> schools;
  final int accountManagers;
  final int pendingApprovals;
  final int? totalSchoolsValue;
  final int? activeSchoolsValue;
  final String totalSchoolsCaption;
  final String activeSchoolsCaption;
  final String accountManagersCaption;
  final String pendingApprovalsCaption;
  final NeedsAttentionSummary? needsAttentionSummary;

  int get totalSchools => totalSchoolsValue ?? schools.length;

  int get activeSchools =>
      activeSchoolsValue ??
      schools.where((school) => school.status.isApproved).length;

  int get onboardingSchools =>
      schools.where((school) => school.status.isOnboarding).length;

  int get attentionSchools =>
      schools.where((school) => school.status.needsAttention).length;

  int get needsAttentionCount {
    final liveTotal = needsAttentionSummary?.total;
    if (liveTotal != null) return liveTotal;
    final accountManagerApprovals = pendingApprovals;
    final schoolIssues = schools.fold<int>(
      0,
      (total, school) => total + school.needsAttentionReasons.length,
    );
    return accountManagerApprovals + schoolIssues;
  }

  int get totalStudents =>
      schools.fold(0, (total, school) => total + school.students);
}

extension ManagedSchoolAttentionRules on ManagedSchool {
  List<String> get needsAttentionReasons {
    final reasons = <String>[];
    final statusText = '$subscriptionStatus $approvedDate $lastActive'
        .toLowerCase();

    if (status.isOnboarding && progress > 0 && progress < 1) {
      reasons.add(
        'School has not moved to the next onboarding step after 5 days',
      );
    }

    if (status == SchoolStatus.pendingApproval ||
        approvedDate.toLowerCase().contains('pending')) {
      reasons.add('School pending approval');
    }

    if (status.needsAttention || statusText.contains('more than 3 days')) {
      reasons.add('School waiting for approval for more than 3 days');
    }

    if (statusText.contains('ges') && statusText.contains('missing')) {
      reasons.add('GES registration missing');
    }

    if (statusText.contains('business') &&
        statusText.contains('registration') &&
        (statusText.contains('missing') || statusText.contains('6 months'))) {
      reasons.add('Business registration missing for more than 6 months');
    }

    return reasons.toSet().toList();
  }
}

class SchoolDraft {
  const SchoolDraft({
    required this.schoolName,
    required this.schoolType,
    required this.schoolTypeId,
    required this.educationLevel,
    required this.educationLevelId,
    required this.yearFounded,
    required this.motto,
    required this.region,
    required this.town,
    required this.phone,
    required this.email,
    required this.levels,
    required this.administratorName,
    required this.administratorPhone,
    required this.administratorEmail,
  });

  final String schoolName;
  final String schoolType;
  final int? schoolTypeId;
  final String educationLevel;
  final int? educationLevelId;
  final int yearFounded;
  final String motto;
  final String region;
  final String town;
  final String phone;
  final String email;
  final List<String> levels;
  final String administratorName;
  final String administratorPhone;
  final String administratorEmail;
}

class SchoolOnboardingDraft {
  const SchoolOnboardingDraft({
    required this.customSchoolId,
    required this.schoolName,
    required this.schoolType,
    required this.schoolTypeId,
    required this.educationLevel,
    required this.educationLevelId,
    required this.yearFounded,
    required this.motto,
    required this.gesRegistrationNumber,
    required this.gesRegistrationType,
    required this.gesRegistrationTypeId,
    required this.gesRegistrationDate,
    required this.businessRegistrationNumber,
    required this.businessRegistrationType,
    required this.businessRegistrationTypeId,
    required this.businessRegistrationDate,
    required this.gemisCode,
    required this.taxIdNumber,
    required this.socialWelfareNumber,
    required this.socialWelfareOfficer,
    required this.socialWelfareDate,
    required this.socialWelfareStatus,
    required this.socialWelfareStatusId,
    required this.houseNumber,
    required this.streetName,
    required this.additionalDirection,
    required this.ghanaPostAddress,
    required this.town,
    required this.cityId,
    required this.district,
    required this.districtId,
    required this.region,
    required this.regionId,
    required this.country,
    required this.countryId,
    required this.gpsLatitude,
    required this.gpsLongitude,
    required this.phone,
    required this.phoneNetwork,
    required this.secondaryPhone,
    required this.secondaryPhoneNetwork,
    required this.officePhone,
    required this.email,
    required this.website,
    required this.socialMedia,
    required this.socialMediaPlatformId,
    required this.socialMediaLinks,
    required this.administratorName,
    required this.administratorPhone,
    required this.administratorEmail,
    required this.levels,
    required this.gradeStreams,
    required this.gradeLevelIds,
    required this.academicYear,
    required this.academicYearId,
    required this.academicTerm,
    required this.academicTermId,
    required this.termDescription,
    required this.termStartDate,
    required this.termEndDate,
    required this.events,
    required this.eventTypeIds,
    required this.documents,
  });

  final String? customSchoolId;
  final String schoolName;
  final String schoolType;
  final int? schoolTypeId;
  final String educationLevel;
  final int? educationLevelId;
  final int yearFounded;
  final String motto;
  final String gesRegistrationNumber;
  final String gesRegistrationType;
  final int? gesRegistrationTypeId;
  final String gesRegistrationDate;
  final String businessRegistrationNumber;
  final String businessRegistrationType;
  final int? businessRegistrationTypeId;
  final String businessRegistrationDate;
  final String gemisCode;
  final String taxIdNumber;
  final String socialWelfareNumber;
  final String socialWelfareOfficer;
  final String socialWelfareDate;
  final String socialWelfareStatus;
  final int? socialWelfareStatusId;
  final String houseNumber;
  final String streetName;
  final String additionalDirection;
  final String ghanaPostAddress;
  final String town;
  final int? cityId;
  final String district;
  final int? districtId;
  final String region;
  final int? regionId;
  final String country;
  final int? countryId;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String phone;
  final String phoneNetwork;
  final String secondaryPhone;
  final String secondaryPhoneNetwork;
  final String officePhone;
  final String email;
  final String website;
  final String socialMedia;
  final int? socialMediaPlatformId;
  final List<SocialMediaContact> socialMediaLinks;
  final String administratorName;
  final String administratorPhone;
  final String administratorEmail;
  final List<String> levels;
  final Map<String, int> gradeStreams;
  final Map<String, int> gradeLevelIds;
  final String academicYear;
  final int? academicYearId;
  final String academicTerm;
  final int? academicTermId;
  final String termDescription;
  final DateTime? termStartDate;
  final DateTime? termEndDate;
  final List<SchoolCalendarEventDraft> events;
  final Map<String, int> eventTypeIds;
  final Map<String, SchoolDocumentDraft> documents;

  SchoolDraft toSchoolDraft() => SchoolDraft(
    schoolName: schoolName.isEmpty ? 'New School' : schoolName,
    schoolType: schoolType,
    schoolTypeId: schoolTypeId,
    educationLevel: educationLevel,
    educationLevelId: educationLevelId,
    yearFounded: yearFounded,
    motto: motto,
    region: region,
    town: town,
    phone: phone,
    email: email,
    levels: levels,
    administratorName: administratorName,
    administratorPhone: administratorPhone,
    administratorEmail: administratorEmail,
  );
}

class SocialMediaContact {
  const SocialMediaContact({
    required this.platform,
    required this.platformId,
    required this.handle,
  });

  final String platform;
  final int? platformId;
  final String handle;
}

class SchoolCalendarEventDraft {
  const SchoolCalendarEventDraft({
    required this.type,
    required this.otherName,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.isSchoolDay,
  });

  final String type;
  final String otherName;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String startTime;
  final String endTime;
  final bool isSchoolDay;
}

class SchoolDocumentDraft {
  const SchoolDocumentDraft({
    required this.name,
    required this.size,
    required this.bytes,
    this.url,
    this.mimeType,
  });

  final String name;
  final int size;
  final List<int>? bytes;
  final String? url;
  final String? mimeType;
}
