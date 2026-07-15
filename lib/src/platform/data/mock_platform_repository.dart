import '../domain/platform_models.dart';
import 'platform_repository.dart';

const _mockOnboardingSteps = [
  'BASIC_INFO',
  'REGISTRATION_DETAILS',
  'SOCIAL_WELFARE_COMPLIANCE',
  'ADDRESS',
  'CONTACT_INFO',
  'DOCUMENTS',
  'GRADE_LEVELS',
  'TERM_CALENDAR',
  'REVIEW',
];

class MockPlatformRepository implements PlatformRepository {
  final List<AccountManagerProfile> _accountManagers = [
    const AccountManagerProfile(
      id: '4',
      name: 'Sam Doe',
      email: 'sam@gmail.com',
      phone: '+233 24 612 3456',
      region: 'Greater Accra',
      schoolCount: 8,
      activeSchoolCount: 7,
      status: AccountManagerStatus.active,
      lastActive: '09-06-2026',
      joined: 'Oct 3, 2024',
      inviteMethod: 'Email and SMS',
      verified: false,
      bio: 'Supports onboarding and school operations across Greater Accra.',
    ),
    const AccountManagerProfile(
      id: '5',
      name: 'Mono Doe',
      email: 'mono@gmail.com',
      phone: '+233 34 672 3456',
      region: 'Ashanti',
      schoolCount: 0,
      activeSchoolCount: 0,
      status: AccountManagerStatus.active,
      lastActive: '23-05-2026',
      joined: 'Nov 14, 2024',
      inviteMethod: 'SMS',
      verified: false,
      bio: 'Newly assigned account manager awaiting first school portfolio.',
    ),
    const AccountManagerProfile(
      id: '6',
      name: 'Kofi Boateng',
      email: 'kofi.boateng@gmail.com',
      phone: '+233 59 459 5484',
      region: 'Central',
      schoolCount: 1,
      activeSchoolCount: 1,
      status: AccountManagerStatus.pendingApproval,
      lastActive: '23-05-2026',
      joined: 'Pending approval',
      inviteMethod: 'Email',
      verified: true,
      bio: 'Former school administrator completing final approval checks.',
    ),
    const AccountManagerProfile(
      id: '7',
      name: 'Esi Nyarko',
      email: 'esi.nyarko@gmail.com',
      phone: '+233 20 184 7520',
      region: 'Eastern',
      schoolCount: 0,
      activeSchoolCount: 0,
      status: AccountManagerStatus.invited,
      lastActive: 'Not yet active',
      joined: 'Invite sent',
      inviteMethod: 'Email and SMS',
      verified: true,
      bio: 'Invite sent. Profile will activate after first login.',
    ),
  ];

  @override
  Future<AccountManagerSnapshot> getAccountManagerDashboard() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return const AccountManagerSnapshot(
      managerName: 'Abena Mensah',
      accountManagers: 8,
      pendingApprovals: 4,
      schools: [
        ManagedSchool(
          name: 'Akwaaba Hills School',
          code: 'GA-041-12',
          region: 'Greater Accra',
          town: 'Adenta',
          students: 648,
          staff: 42,
          status: SchoolStatus.approved,
          progress: 1,
          accountManager: 'Sam Doe',
          subscriptionPlan: 'Premium Basic',
          subscriptionStatus: 'Paid',
          renewalDate: '30-09-2026',
          lastActive: 'Today, 9:30 AM',
          approvedDate: '12-01-2025',
          administratorName: 'Kwame Asare',
          administratorPhone: '+233 24 100 4455',
          administratorEmail: 'admin@akwaabahills.edu.gh',
        ),
        ManagedSchool(
          name: 'Bright Future Academy',
          code: 'GA-063-04',
          region: 'Greater Accra',
          town: 'Tema',
          students: 392,
          staff: 28,
          status: SchoolStatus.approved,
          progress: 1,
          accountManager: 'Sam Doe',
          subscriptionPlan: 'Standard',
          subscriptionStatus: 'Paid',
          renewalDate: '15-08-2026',
          lastActive: 'Yesterday, 4:12 PM',
          approvedDate: '04-03-2025',
          administratorName: 'Esi Hammond',
          administratorPhone: '+233 27 223 1188',
          administratorEmail: 'office@brightfuture.edu.gh',
        ),
        ManagedSchool(
          name: 'Aseda Preparatory School',
          code: 'ER-018-09',
          region: 'Eastern',
          town: 'Koforidua',
          students: 0,
          staff: 0,
          status: SchoolStatus.inProgress,
          progress: .68,
          accountManager: 'Kofi Boateng',
          subscriptionPlan: 'Trial',
          subscriptionStatus: 'Trial',
          renewalDate: 'Pending activation',
          lastActive: '2 days ago',
          approvedDate: 'In progress',
          administratorName: 'Not invited',
          administratorPhone: 'Pending',
          administratorEmail: 'Pending',
        ),
        ManagedSchool(
          name: 'Little Scholars Academy',
          code: 'VR-014-03',
          region: 'Volta',
          town: 'Ho',
          students: 0,
          staff: 0,
          status: SchoolStatus.inProgress,
          progress: .42,
          accountManager: 'Sam Doe',
          subscriptionPlan: 'Trial',
          subscriptionStatus: 'Trial',
          renewalDate: 'Pending activation',
          lastActive: '4 days ago',
          approvedDate: 'In progress',
          administratorName: 'Rev. Mawuli Mensah',
          administratorPhone: '+233 20 777 8800',
          administratorEmail: 'head@littlescholars.edu.gh',
        ),
        ManagedSchool(
          name: 'Covenant Gate School',
          code: 'WR-022-07',
          region: 'Western',
          town: 'Takoradi',
          students: 0,
          staff: 0,
          status: SchoolStatus.pendingApproval,
          progress: .84,
          accountManager: 'Sam Doe',
          subscriptionPlan: 'Trial',
          subscriptionStatus: 'Trial',
          renewalDate: 'Pending activation',
          lastActive: 'Today, 8:05 AM',
          approvedDate: 'In progress',
          administratorName: 'Patience Arthur',
          administratorPhone: '+233 24 900 6611',
          administratorEmail: 'admin@covenantgate.edu.gh',
        ),
        ManagedSchool(
          name: 'Royal Seed Academy',
          code: 'CR-025-02',
          region: 'Central',
          town: 'Kasoa',
          students: 274,
          staff: 19,
          status: SchoolStatus.needsRevision,
          progress: .82,
          accountManager: 'Sam Doe',
          subscriptionPlan: 'Standard',
          subscriptionStatus: 'Payment overdue',
          renewalDate: '01-06-2026',
          lastActive: '3 days ago',
          approvedDate: '20-09-2025',
          administratorName: 'Josephine Quaye',
          administratorPhone: '+233 26 444 9900',
          administratorEmail: 'accounts@royalseed.edu.gh',
        ),
        ManagedSchool(
          name: 'Gracefield Montessori',
          code: 'AS-031-06',
          region: 'Ashanti',
          town: 'Kumasi',
          students: 189,
          staff: 16,
          status: SchoolStatus.approved,
          progress: 1,
          accountManager: 'Mono Doe',
          subscriptionPlan: 'Standard',
          subscriptionStatus: 'Paid',
          renewalDate: '11-10-2026',
          lastActive: 'Today, 10:15 AM',
          approvedDate: '06-02-2026',
          administratorName: 'Nana Osei',
          administratorPhone: '+233 20 555 1212',
          administratorEmail: 'office@gracefield.edu.gh',
        ),
      ],
    );
  }

  @override
  Future<NeedsAttentionSummary> getNeedsAttentionSummary() async {
    return const NeedsAttentionSummary(total: 0, categories: []);
  }

  @override
  Future<NeedsAttentionPage> getNeedsAttentionItems({
    required String category,
    String? searchTerm,
    int page = 0,
    int size = 20,
  }) async {
    return NeedsAttentionPage(
      items: const [],
      totalElements: 0,
      totalPages: 1,
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<ManagedSchool> createSchool(SchoolDraft draft) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return ManagedSchool(
      name: draft.schoolName,
      code: 'NEW-DRAFT',
      region: draft.region,
      town: draft.town,
      students: 0,
      staff: 0,
      status: SchoolStatus.inProgress,
      progress: .2,
      accountManager: 'Abena Mensah',
      subscriptionPlan: 'Trial',
      subscriptionStatus: 'Trial',
      renewalDate: 'Pending activation',
      lastActive: 'Just created',
      approvedDate: 'In progress',
      administratorName: draft.administratorName,
      administratorPhone: draft.administratorPhone,
      administratorEmail: draft.administratorEmail,
    );
  }

  @override
  Future<ManagedSchoolPage> getSchools({
    String? searchTerm,
    String? region,
    String? district,
    String? status,
    String? accountManagerId,
    int page = 0,
    int size = 10,
  }) async {
    final snapshot = await getAccountManagerDashboard();
    final query = searchTerm?.trim().toLowerCase() ?? '';
    final filtered = snapshot.schools.where((school) {
      final matchesSearch =
          query.isEmpty ||
          school.name.toLowerCase().contains(query) ||
          school.code.toLowerCase().contains(query) ||
          school.region.toLowerCase().contains(query);
      final matchesRegion =
          region == null || region == 'All Regions' || school.region == region;
      final matchesDistrict =
          district == null ||
          district == 'All Districts' ||
          school.district == district;
      final matchesStatus =
          status == null ||
          status == 'All Statuses' ||
          school.status.label == status;
      final matchesManager =
          accountManagerId == null ||
          accountManagerId == 'All AMs' ||
          school.accountManager == accountManagerId;
      return matchesSearch &&
          matchesRegion &&
          matchesDistrict &&
          matchesStatus &&
          matchesManager;
    }).toList();
    final start = page * size;
    final end = start + size > filtered.length ? filtered.length : start + size;
    final schools = start >= filtered.length
        ? <ManagedSchool>[]
        : filtered.sublist(start, end);
    return ManagedSchoolPage(
      schools: schools,
      totalElements: filtered.length,
      totalPages: filtered.isEmpty ? 1 : (filtered.length / size).ceil(),
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final snapshot = await getAccountManagerDashboard();
    final school = snapshot.schools.firstWhere(
      (school) => school.code == customSchoolId,
      orElse: () => snapshot.schools.first,
    );
    final completedIndex = (school.progress * _mockOnboardingSteps.length)
        .floor()
        .clamp(0, _mockOnboardingSteps.length - 1);
    return SchoolOnboardingRecord(
      data: {
        'customSchoolId': school.code,
        'schoolName': school.name,
        'address': {
          'city': {'name': school.town},
          'region': {'name': school.region},
          'district': {'name': school.district},
          'country': {'name': 'Ghana'},
        },
        'contactInfo': {
          'personalPhoneNumbers': [
            {'phoneNumber': school.administratorPhone, 'isPrimary': true},
          ],
          'emails': [school.administratorEmail],
        },
      },
      progress: SchoolOnboardingProgress(
        customSchoolId: school.code,
        registrationStatus: 'IN_PROGRESS',
        currentStep: _mockStepName(completedIndex),
        completedSteps: _mockCompletedSteps(completedIndex - 1),
      ),
    );
  }

  @override
  Future<SchoolOnboardingRecord> getSchoolReviewRecord(String customSchoolId) =>
      getSchoolOnboardingRecord(customSchoolId);

  @override
  Future<SchoolOnboardingProgress> saveSchoolOnboardingStep({
    required int stepIndex,
    required SchoolOnboardingDraft draft,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final completed = _mockCompletedSteps(stepIndex);
    return SchoolOnboardingProgress(
      customSchoolId: draft.customSchoolId ?? 'NEW-DRAFT',
      registrationStatus: stepIndex >= 8 ? 'COMPLETED' : 'IN_PROGRESS',
      currentStep: stepIndex >= 8 ? 'REVIEW' : _mockStepName(stepIndex + 1),
      completedSteps: completed,
    );
  }

  List<String> _mockCompletedSteps(int stepIndex) => [
    for (var i = 0; i <= stepIndex && i < _mockOnboardingSteps.length; i++)
      _mockOnboardingSteps[i],
  ];

  String _mockStepName(int index) =>
      _mockOnboardingSteps[index.clamp(0, _mockOnboardingSteps.length - 1)];

  @override
  Future<SchoolOnboardingRecord> finishSchoolSetup(
    String customSchoolId,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return SchoolOnboardingRecord(
      data: {
        'customSchoolId': customSchoolId,
        'schoolName': 'Submitted School',
        'registrationStatus': 'PENDING_APPROVAL',
      },
      progress: SchoolOnboardingProgress(
        customSchoolId: customSchoolId,
        registrationStatus: 'PENDING_APPROVAL',
        currentStep: 'REVIEW',
        completedSteps: _mockCompletedSteps(8),
      ),
    );
  }

  @override
  Future<void> changeSchoolStatus({
    required String customSchoolId,
    required SchoolStatus status,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Future<String> getSchoolDocumentDownloadUrl({
    required String customSchoolId,
    required String documentId,
  }) async => 'https://example.com/document/$documentId';

  @override
  Future<List<SchoolDocumentInfo>> getSchoolDocuments(
    String customSchoolId,
  ) async => const [];

  @override
  Future<List<SchoolGradeLevelInfo>> getSchoolGradeLevels(
    String customSchoolId,
  ) async => const [];

  @override
  Future<SchoolAdministratorInviteResult> inviteSchoolAdministrator({
    required String customSchoolId,
    required SchoolAdministratorInvite invite,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return SchoolAdministratorInviteResult(
      message: 'School administrator invitation sent successfully.',
      username: '${invite.firstName}.${invite.lastName}'
          .toLowerCase()
          .replaceAll(' ', ''),
    );
  }

  @override
  Future<List<SchoolUserInfo>> getSchoolUsers(String customSchoolId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final pending = customSchoolId == 'GA-041-12';
    return [
      SchoolUserInfo(
        id: '1-$customSchoolId',
        name: 'Ama Mensah',
        email: 'ama@school.edu.gh',
        phoneNumber: '+233 24 123 4567',
        role: 'ADMINISTRATOR',
        status: pending ? 'PENDING_APPROVAL' : 'ACTIVE',
        lastLogin: pending ? 'Never' : 'Today',
        username: 'ama.mensah',
        userType: 'STAFF',
        customSchoolId: customSchoolId,
        schoolName: customSchoolId,
        createdAt: '2026-06-18',
      ),
    ];
  }

  @override
  Future<SchoolUserInfo?> approveSchoolUser({
    required String customSchoolId,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return null;
  }

  @override
  Future<SchoolUserInfo?> rejectSchoolUser({
    required String customSchoolId,
    required String userId,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return null;
  }

  @override
  Future<void> suspendSchoolUser({
    required String customSchoolId,
    required String userId,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<void> reactivateSchoolUser({
    required String customSchoolId,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<SchoolUserInfo?> updateSchoolUserRole({
    required String customSchoolId,
    required String userId,
    required String role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return null;
  }

  @override
  Future<SchoolAdministratorInviteResult> resendSchoolUserCredentials({
    required String customSchoolId,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const SchoolAdministratorInviteResult(
      message: 'Credentials resent successfully.',
    );
  }

  @override
  Future<SchoolAdministratorInviteResult> resetSchoolUserPassword({
    required String customSchoolId,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const SchoolAdministratorInviteResult(
      message: 'Password reset successfully.',
      temporaryPassword: 'Temp@12345',
    );
  }

  @override
  Future<UserAuditLogPage> getUserAuditLogs({
    required String userId,
    int page = 0,
    int size = 50,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final logs = [
      UserAuditLog(
        id: 'audit-1',
        userId: userId,
        performedBy: 'system.admin@sma',
        actionType: 'CREATE',
        description: 'User account created',
        timestamp: '2026-06-21T14:30:00',
        ipAddress: '192.168.1.100',
        userAgent: 'Mozilla/5.0',
        metadata: '{"role":"ADMINISTRATOR"}',
      ),
      UserAuditLog(
        id: 'audit-2',
        userId: userId,
        performedBy: 'ama.mensah',
        actionType: 'LOGIN',
        description: 'User logged in successfully',
        timestamp: '2026-06-21T15:00:00',
        ipAddress: '192.168.1.105',
        userAgent: 'Mozilla/5.0',
        metadata: null,
      ),
      UserAuditLog(
        id: 'audit-3',
        userId: userId,
        performedBy: 'ama.mensah',
        actionType: 'PASSWORD_RESET',
        description: 'User changed password',
        timestamp: '2026-06-21T15:05:00',
        ipAddress: '192.168.1.105',
        userAgent: 'Mozilla/5.0',
        metadata: null,
      ),
    ];
    return UserAuditLogPage(
      userId: userId,
      userName: 'ama.mensah',
      logs: logs,
      totalElements: logs.length,
      totalPages: 1,
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<List<AccountManagerProfile>> getAccountManagers() async {
    final page = await getAccountManagerPage(size: 100);
    return page.managers;
  }

  @override
  Future<AccountManagerPage> getAccountManagerPage({
    String? searchTerm,
    List<String> userStatuses = const [],
    int page = 0,
    int size = 20,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final query = searchTerm?.trim().toLowerCase() ?? '';
    final filtered = _accountManagers.where((manager) {
      final matchesQuery =
          query.isEmpty ||
          manager.name.toLowerCase().contains(query) ||
          manager.email.toLowerCase().contains(query) ||
          manager.phone.toLowerCase().contains(query) ||
          manager.region.toLowerCase().contains(query);
      final matchesStatus =
          userStatuses.isEmpty ||
          userStatuses.any(
            (status) => status.toUpperCase() == _mockUserStatus(manager.status),
          );
      return matchesQuery && matchesStatus;
    }).toList();
    final start = page * size;
    final managers = start >= filtered.length
        ? <AccountManagerProfile>[]
        : filtered.sublist(start, (start + size).clamp(0, filtered.length));
    return AccountManagerPage(
      managers: managers,
      totalElements: filtered.length,
      totalPages: filtered.isEmpty ? 1 : (filtered.length / size).ceil(),
      currentPage: page,
      pageSize: size,
    );
  }

  @override
  Future<List<AccountManagerProfile>> searchAccountManagers({
    required String searchTerm,
    List<String> userStatuses = const ['ACTIVE'],
    int page = 0,
    int size = 10,
  }) async {
    final result = await getAccountManagerPage(
      searchTerm: searchTerm,
      userStatuses: userStatuses,
      page: page,
      size: size,
    );
    return result.managers;
  }

  @override
  Future<AccountManagerProfile> createAccountManager(
    AccountManagerDraft draft,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    final accountManager = AccountManagerProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${draft.firstName} ${draft.lastName}',
      email: draft.email,
      phone: draft.phone,
      region: 'Not assigned',
      schoolCount: 0,
      activeSchoolCount: 0,
      status: AccountManagerStatus.invited,
      lastActive: 'Not yet active',
      joined: 'Invite sent today',
      inviteMethod: draft.inviteMethod,
      verified: false,
      bio: 'Awaiting first login and profile verification.',
    );
    _accountManagers.add(accountManager);
    return accountManager;
  }

  @override
  Future<AccountManagerProfile> updateAccountManagerStatus({
    required String accountManagerId,
    required AccountManagerStatus status,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final index = _accountManagers.indexWhere(
      (manager) => manager.id == accountManagerId,
    );
    if (index < 0) return _accountManagers.first;
    final current = _accountManagers[index];
    final updated = AccountManagerProfile(
      id: current.id,
      userId: current.userId,
      name: current.name,
      email: current.email,
      phone: current.phone,
      region: current.region,
      schoolCount: current.schoolCount,
      activeSchoolCount: current.activeSchoolCount,
      status: status,
      lastActive: current.lastActive,
      joined: current.joined,
      inviteMethod: current.inviteMethod,
      verified: current.verified,
      bio: current.bio,
    );
    _accountManagers[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteAccountManager({
    required String accountManagerId,
    String? reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _accountManagers.removeWhere((manager) => manager.id == accountManagerId);
  }

  @override
  Future<SchoolAdministratorInviteResult> forceResetAccountManagerPassword({
    required AccountManagerProfile manager,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return SchoolAdministratorInviteResult(
      message: 'Password reset successfully for ${manager.email}.',
      temporaryPassword: 'Temp123!',
    );
  }

  @override
  Future<SchoolAdministratorInviteResult> resendAccountManagerCredentials({
    required AccountManagerProfile manager,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return SchoolAdministratorInviteResult(
      message: 'Temporary credentials have been sent to ${manager.email}.',
      temporaryPassword: 'Temp123!',
    );
  }

  @override
  Future<List<SchoolAssignmentReasonOption>>
  getSchoolAssignmentReasons() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const [
      SchoolAssignmentReasonOption(
        value: 'WORKLOAD_TOO_HIGH',
        label: 'Workload too high',
      ),
      SchoolAssignmentReasonOption(
        value: 'REGIONAL_RESTRUCTURING',
        label: 'Regional restructuring',
      ),
      SchoolAssignmentReasonOption(
        value: 'AM_SUSPENDED_OR_INACTIVE',
        label: 'AM suspended or inactive',
      ),
      SchoolAssignmentReasonOption(
        value: 'AM_REQUESTED_TRANSFER',
        label: 'AM requested transfer',
      ),
      SchoolAssignmentReasonOption(
        value: 'SCHOOL_REQUESTED_CHANGE',
        label: 'School requested change',
      ),
      SchoolAssignmentReasonOption(
        value: 'PERFORMANCE_CONCERNS',
        label: 'Performance concerns',
      ),
      SchoolAssignmentReasonOption(value: 'OTHER', label: 'Other'),
    ];
  }

  @override
  Future<AccountManagerProfile> assignSchoolsToAccountManager({
    required String accountManagerId,
    required List<String> customSchoolIds,
    required String reason,
    String? notes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _accountManagers.firstWhere(
      (manager) => manager.id == accountManagerId,
      orElse: () => _accountManagers.first,
    );
  }
}

String _mockUserStatus(AccountManagerStatus status) => switch (status) {
  AccountManagerStatus.active => 'ACTIVE',
  AccountManagerStatus.pendingApproval => 'PENDING',
  AccountManagerStatus.invited => 'INVITED',
  AccountManagerStatus.suspended => 'SUSPENDED',
};
