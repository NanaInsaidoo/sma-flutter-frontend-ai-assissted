import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/platform_models.dart';
import 'platform_api_client.dart';
import 'platform_repository.dart';

class LivePlatformRepository implements PlatformRepository {
  LivePlatformRepository({
    required this.accessToken,
    this.userDisplayName,
    this.role = PlatformRole.superAdmin,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final String? userDisplayName;
  final PlatformRole role;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  static const _onboardingSteps = [
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

  bool get _canUseApi =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      accessToken != 'preview';

  void _requireApi() {
    if (!_canUseApi) {
      throw http.ClientException('Sign in required to load live data');
    }
  }

  bool get _usesManagedSchoolEndpoint => role == PlatformRole.accountManager;

  @override
  Future<AccountManagerSnapshot> getAccountManagerDashboard() async {
    _requireApi();

    if (_usesManagedSchoolEndpoint) {
      final schoolsPage = await _getManagedSchoolsPage(page: 0, size: 100);
      return AccountManagerSnapshot(
        managerName: _dashboardManagerName(const {}),
        schools: schoolsPage.schools,
        accountManagers: 0,
        pendingApprovals: 0,
        totalSchoolsValue: schoolsPage.totalElements,
        activeSchoolsValue: schoolsPage.schools
            .where((school) => school.status.isApproved)
            .length,
        totalSchoolsCaption: 'Schools assigned to you',
        activeSchoolsCaption: 'Approved assigned schools',
      );
    }

    final dashboardResponse = await _get('/api/super-admin/dashboard');
    final dashboard = _asMap(_unwrap(dashboardResponse));
    final statsCandidate = dashboard['stats'];
    final stats = _asMap(
      statsCandidate is Map<String, dynamic> ? statsCandidate : dashboard,
    );
    final schools = await _getDashboardSchoolsForOverview();
    final roleScopedManagerTotals = role == PlatformRole.superAccountManager
        ? await _getRoleScopedAccountManagerTotals()
        : null;
    final accountManagers = roleScopedManagerTotals == null
        ? await _getAccountManagersForDashboard()
        : const <AccountManagerProfile>[];
    final needsAttention = await _getNeedsAttentionForDashboard();

    return AccountManagerSnapshot(
      managerName: _dashboardManagerName(dashboard),
      schools: schools,
      totalSchoolsValue: _statValue(stats, 'totalSchools').$1,
      activeSchoolsValue: _statValue(stats, 'activeSchools').$1,
      accountManagers:
          roleScopedManagerTotals?.total ??
          _statValue(stats, 'accountManagers').$1 ?? accountManagers.length,
      pendingApprovals:
          roleScopedManagerTotals?.pending ??
          _statValue(stats, 'pendingApprovals').$1 ??
          accountManagers
              .where(
                (manager) =>
                    manager.status == AccountManagerStatus.pendingApproval,
              )
              .length,
      totalSchoolsCaption: _statValue(stats, 'totalSchools').$2,
      activeSchoolsCaption: _statValue(stats, 'activeSchools').$2,
      accountManagersCaption:
          roleScopedManagerTotals?.caption ??
          _statValue(stats, 'accountManagers').$2,
      pendingApprovalsCaption:
          roleScopedManagerTotals?.pendingCaption ??
          _statValue(stats, 'pendingApprovals').$2,
      needsAttentionSummary: needsAttention,
    );
  }

  @override
  Future<NeedsAttentionSummary> getNeedsAttentionSummary() async {
    _requireApi();
    final response = await _get('/api/super-admin/needs-attention/summary');
    final map = _asMap(_unwrap(response));
    final categories = _asList(
      map['categories'],
    ).map(_needsAttentionCategoryFromJson).toList();
    return NeedsAttentionSummary(
      total: _int(
        map,
        ['total'],
        fallback: categories.fold<int>(
          0,
          (total, category) => total + category.count,
        ),
      ),
      categories: categories,
    );
  }

  @override
  Future<NeedsAttentionPage> getNeedsAttentionItems({
    required String category,
    String? searchTerm,
    int page = 0,
    int size = 20,
  }) async {
    _requireApi();
    final query = <String, String>{
      if (category.trim().isNotEmpty) 'category': category.trim(),
      'page': page.toString(),
      'size': size.toString(),
    };
    final cleanSearch = searchTerm?.trim();
    if (cleanSearch != null && cleanSearch.isNotEmpty) {
      query['searchTerm'] = cleanSearch;
    }
    final response = await _get(
      '/api/super-admin/needs-attention?${Uri(queryParameters: query).query}',
    );
    final map = _asMap(response);
    final items = _asList(
      _unwrap(response),
    ).map(_needsAttentionItemFromJson).toList();
    return NeedsAttentionPage(
      items: items,
      totalElements: _int(map, [
        'totalElements',
        'total',
      ], fallback: items.length),
      totalPages: _int(map, ['totalPages'], fallback: 1),
      currentPage: _int(map, ['currentPage', 'number'], fallback: page),
      pageSize: _int(map, ['pageSize', 'size'], fallback: size),
    );
  }

  @override
  Future<ManagedSchool> createSchool(SchoolDraft draft) async {
    _requireApi();

    try {
      final response = await _post(
        '/api/account-managers/schools/create',
        _createSchoolBody(draft),
      );
      return _schoolFromJson(_unwrapSchoolRecord(response), draft: draft);
    } catch (_) {
      rethrow;
    }
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
    _requireApi();

    if (_usesManagedSchoolEndpoint) {
      final managedPage = await _getManagedSchoolsPage(page: page, size: size);
      final filteredSchools = managedPage.schools
          .where(
            (school) => _matchesApiFallbackFilters(
              school,
              searchTerm: searchTerm,
              region: region,
              district: district,
              status: status,
              accountManager: accountManagerId,
            ),
          )
          .toList();
      final hasClientFilters =
          (searchTerm?.trim().isNotEmpty ?? false) ||
          _apiRegion(region) != null ||
          (district?.trim().isNotEmpty ?? false) &&
              district?.trim() != 'All Districts' ||
          _apiSchoolStatus(status) != null ||
          (accountManagerId?.trim().isNotEmpty ?? false) &&
              accountManagerId?.trim() != 'All AMs';
      return ManagedSchoolPage(
        schools: filteredSchools,
        totalElements: hasClientFilters
            ? filteredSchools.length
            : managedPage.totalElements,
        totalPages: hasClientFilters ? 1 : managedPage.totalPages,
        currentPage: hasClientFilters ? 0 : managedPage.currentPage,
        pageSize: managedPage.pageSize,
      );
    }

    final query = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
    };
    final apiStatus = _apiSchoolStatus(status);
    if (apiStatus != null) query['status'] = apiStatus;
    final cleanSearch = searchTerm?.trim();
    if (cleanSearch != null && cleanSearch.isNotEmpty) {
      query['searchTerm'] = cleanSearch;
    }
    final cleanRegion = _apiRegion(region);
    if (cleanRegion != null) query['region'] = cleanRegion;
    final cleanDistrict = district?.trim();
    if (cleanDistrict != null &&
        cleanDistrict.isNotEmpty &&
        cleanDistrict != 'All Districts') {
      query['district'] = cleanDistrict;
    }
    final cleanManager = accountManagerId?.trim();
    if (cleanManager != null &&
        cleanManager.isNotEmpty &&
        cleanManager != 'All AMs' &&
        int.tryParse(cleanManager) != null) {
      query['accountManagerId'] = cleanManager;
    }

    final queryString = Uri(queryParameters: query).query;
    final response = await _get(
      '/api/super-admin/dashboard/schools?$queryString',
    );
    final responseMap = _asMap(response);
    final schools = _asList(_unwrap(response))
        .map(_schoolFromJson)
        .where(
          (school) => _matchesApiFallbackFilters(
            school,
            searchTerm: cleanSearch,
            region: region,
            district: district,
            status: status,
            accountManager: accountManagerId,
          ),
        )
        .toList();

    return ManagedSchoolPage(
      schools: schools,
      totalElements: _int(responseMap, [
        'totalElements',
        'total',
        'totalSchools',
      ], fallback: schools.length),
      totalPages: _int(responseMap, ['totalPages'], fallback: 1),
      currentPage: _int(responseMap, ['currentPage', 'number'], fallback: page),
      pageSize: _int(responseMap, ['pageSize', 'size'], fallback: size),
    );
  }

  Future<ManagedSchoolPage> _getManagedSchoolsPage({
    required int page,
    required int size,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': page.toString(),
        'size': size.toString(),
        'sort': 'createdAt,desc',
      },
    ).query;
    final response = await _get(
      '/api/account-managers/schools/paginated?$query',
    );
    final responseMap = _asMap(response);
    final schools = _asList(_unwrap(response)).map(_schoolFromJson).toList();
    return ManagedSchoolPage(
      schools: schools,
      totalElements: _int(responseMap, [
        'totalElements',
        'total',
        'totalSchools',
      ], fallback: schools.length),
      totalPages: _int(responseMap, ['totalPages'], fallback: 1),
      currentPage: _int(responseMap, ['currentPage', 'number'], fallback: page),
      pageSize: _int(responseMap, ['pageSize', 'size'], fallback: size),
    );
  }

  @override
  Future<SchoolOnboardingRecord> getSchoolOnboardingRecord(
    String customSchoolId,
  ) async {
    _requireApi();
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _get('/api/schools/$encoded');
    final data = _asMap(_unwrapSchoolRecord(response));
    return SchoolOnboardingRecord(
      data: data,
      progress: _onboardingProgressFromJson(
        data,
        fallbackCustomSchoolId: customSchoolId,
        fallbackCompletedStepIndex: _completedStepsFromJson(data).length - 1,
        fallbackCurrentStep: _jsonString(data, ['currentStep']) ?? 'BASIC_INFO',
      ),
    );
  }

  @override
  Future<SchoolOnboardingRecord> getSchoolReviewRecord(
    String customSchoolId,
  ) async {
    _requireApi();
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _put(
      '/api/schools/$encoded/registration-step?currentStep=REVIEW',
      const {},
    );
    final data = _asMap(_unwrapSchoolRecord(response));
    return SchoolOnboardingRecord(
      data: data,
      progress: _onboardingProgressFromJson(
        data,
        fallbackCustomSchoolId: customSchoolId,
        fallbackCompletedStepIndex: 7,
        fallbackCurrentStep: 'REVIEW',
      ),
    );
  }

  @override
  Future<SchoolOnboardingProgress> saveSchoolOnboardingStep({
    required int stepIndex,
    required SchoolOnboardingDraft draft,
  }) async {
    _requireApi();

    try {
      if (stepIndex == 0 && _isNewSchoolId(draft.customSchoolId)) {
        final response = await _post(
          '/api/account-managers/schools/create',
          _createSchoolBody(draft.toSchoolDraft()),
        );
        return _onboardingProgressFromJson(
          response,
          fallbackCustomSchoolId: draft.customSchoolId,
          fallbackCompletedStepIndex: stepIndex,
          fallbackCurrentStep: 'REGISTRATION_DETAILS',
        );
      }

      final customSchoolId = draft.customSchoolId;
      if (customSchoolId == null || customSchoolId.isEmpty) {
        throw http.ClientException('School setup has not been initialized');
      }

      switch (stepIndex) {
        case 0:
          final response = await _putRegistrationStep(
            customSchoolId,
            'BASIC_INFO',
            _basicInfoBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'REGISTRATION_DETAILS',
          );
        case 1:
          final response = await _putRegistrationStep(
            customSchoolId,
            'REGISTRATION_DETAILS',
            _registrationBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'SOCIAL_WELFARE_COMPLIANCE',
          );
        case 2:
          final response = await _putRegistrationStep(
            customSchoolId,
            'SOCIAL_WELFARE_COMPLIANCE',
            _socialWelfareBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'ADDRESS',
          );
        case 3:
          final response = await _putRegistrationStep(
            customSchoolId,
            'ADDRESS',
            _addressBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'CONTACT_INFO',
          );
        case 4:
          final response = await _putRegistrationStep(
            customSchoolId,
            'CONTACT_INFO',
            _contactBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'DOCUMENTS',
          );
        case 5:
          final response = await _completeDocumentsStep(customSchoolId, draft);
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'GRADE_LEVELS',
          );
        case 6:
          final response = await _putRegistrationStep(
            customSchoolId,
            'GRADE_LEVELS',
            _gradeLevelsBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'TERM_CALENDAR',
          );
        case 7:
          final response = await _putRegistrationStep(
            customSchoolId,
            'TERM_CALENDAR',
            _termCalendarBody(draft),
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'REVIEW',
          );
        case 8:
          final response = await _putRegistrationStep(
            customSchoolId,
            'REVIEW',
            {'reviewConfirmed': true},
          );
          return _onboardingProgressFromJson(
            response,
            fallbackCustomSchoolId: customSchoolId,
            fallbackCompletedStepIndex: stepIndex,
            fallbackCurrentStep: 'REVIEW',
          );
      }
      return SchoolOnboardingProgress(
        customSchoolId: customSchoolId,
        registrationStatus: stepIndex >= 8 ? 'COMPLETED' : 'IN_PROGRESS',
        currentStep: _stepNameForIndex((stepIndex + 1).clamp(0, 8)),
        completedSteps: _fallbackCompletedSteps(stepIndex),
      );
    } catch (_) {
      rethrow;
    }
  }

  bool _isNewSchoolId(String? customSchoolId) {
    final value = customSchoolId?.trim() ?? '';
    return value.isEmpty || value.startsWith('NEW_SCHOOL_');
  }

  @override
  Future<SchoolOnboardingRecord> finishSchoolSetup(
    String customSchoolId,
  ) async {
    _requireApi();
    if (customSchoolId.isEmpty) {
      throw http.ClientException('School ID is required to finish setup');
    }

    final response = await _post(
      '/api/schools/$customSchoolId/finish-setup',
      {},
    );
    final data = _asMap(_unwrapSchoolRecord(response));
    return SchoolOnboardingRecord(
      data: data,
      progress: _onboardingProgressFromJson(
        data,
        fallbackCustomSchoolId: customSchoolId,
        fallbackCompletedStepIndex: 8,
        fallbackCurrentStep: 'REVIEW',
      ),
    );
  }

  @override
  Future<void> changeSchoolStatus({
    required String customSchoolId,
    required SchoolStatus status,
    String? reason,
  }) async {
    _requireApi();
    final encoded = Uri.encodeComponent(customSchoolId);
    await _put('/api/schools/$encoded/changeschoolstatus', {
      'status': status.apiValue,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  @override
  Future<String> getSchoolDocumentDownloadUrl({
    required String customSchoolId,
    required String documentId,
  }) async {
    _requireApi();
    final schoolId = Uri.encodeComponent(customSchoolId);
    final fileId = Uri.encodeComponent(documentId);
    final response = _unwrap(
      await _get(
        '/api/schools/$schoolId/documents/$fileId/download-url?expirationMinutes=15',
      ),
    );
    final url = _jsonString(response, [
      'downloadUrl',
      'presignedUrl',
      'signedUrl',
      'url',
    ]);
    if (url == null || url.isEmpty) {
      throw http.ClientException('Document download URL was not returned');
    }
    return url;
  }

  @override
  Future<List<SchoolDocumentInfo>> getSchoolDocuments(
    String customSchoolId,
  ) async {
    _requireApi();
    final schoolId = Uri.encodeComponent(customSchoolId);
    final response = _unwrap(await _get('/api/schools/$schoolId/documents'));
    final items = response is List
        ? response
        : response is Map<String, dynamic>
        ? (response['documents'] ?? response['content'] ?? response['items'])
        : null;
    if (items is! List) return const [];
    return items
        .map((item) {
          final map = _asMap(item);
          return SchoolDocumentInfo(
            documentId: _string(map, ['documentId', 'id']),
            fileName: _string(map, ['fileName', 'name']),
            fileSize: _int(map, ['fileSize', 'size']),
            contentType: _string(map, ['contentType', 'fileType']),
            documentType: _string(map, ['documentType', 'type']),
            status: _string(map, ['status']),
          );
        })
        .where((document) {
          final status = document.status.trim().toUpperCase();
          return document.documentId.isNotEmpty &&
              (status.isEmpty || status == 'ACTIVE' || status == 'CONFIRMED');
        })
        .toList();
  }

  @override
  Future<List<SchoolGradeLevelInfo>> getSchoolGradeLevels(
    String customSchoolId,
  ) async {
    _requireApi();
    final schoolId = Uri.encodeComponent(customSchoolId);
    final response = _unwrap(await _get('/api/grade-levels/school/$schoolId'));
    final items = response is List
        ? response
        : response is Map<String, dynamic>
        ? (response['gradeLevels'] ?? response['content'] ?? response['items'])
        : null;
    if (items is! List) return const [];
    return items
        .map((item) {
          final map = _asMap(item);
          final grade = _asMap(map['gradeLevel']);
          final id = _int(map, [
            'gradeLevelId',
          ], fallback: _int(grade, ['id', 'gradeLevelId']));
          final directName = _string(map, [
            'gradeName',
            'gradeLevelName',
            'name',
          ]);
          final name = directName.trim().isEmpty
              ? _string(grade, ['gradeName', 'gradeLevelName', 'name'])
              : directName;
          final streams = _int(map, [
            'numberOfStreams',
            'streamCount',
            'streamsCount',
            'streams',
          ], fallback: 0);
          final streamItems = map['streams'];
          final resolvedStreams = streams > 0
              ? streams
              : streamItems is List && streamItems.isNotEmpty
              ? streamItems.length
              : 1;
          return SchoolGradeLevelInfo(
            gradeLevelId: id,
            gradeLevelName: name,
            numberOfStreams: resolvedStreams.clamp(1, 10),
            status: _string(map, ['status'], fallback: 'INACTIVE'),
          );
        })
        .where(
          (grade) =>
              grade.gradeLevelId > 0 && grade.gradeLevelName.trim().isNotEmpty,
        )
        .toList();
  }

  @override
  Future<SchoolAdministratorInviteResult> inviteSchoolAdministrator({
    required String customSchoolId,
    required SchoolAdministratorInvite invite,
  }) async {
    _requireApi();
    final encoded = Uri.encodeComponent(customSchoolId);
    final response =
        await _post('/api/user-management/schools/$encoded/users', {
          'firstName': invite.firstName.trim(),
          'middleName': invite.middleName.trim(),
          'lastName': invite.lastName.trim(),
          'email': invite.email.trim(),
          'phoneNumber': _ghanaPhoneNumber(invite.phoneNumber),
          'dateOfBirth': _isoDate(invite.dateOfBirth),
          'userType': 'STAFF',
          'role': 'ADMINISTRATOR',
          'emailDelivery': invite.emailDelivery,
          'smsDelivery': invite.smsDelivery,
          'printSlipDelivery': false,
        });
    final data = _asMap(_unwrap(response));
    final username = _string(data, ['username', 'generatedUsername']);
    final temporaryPassword = _string(data, [
      'temporaryPassword',
      'tempPassword',
    ]);
    final createdUser = SchoolUserInfo(
      id: _string(data, ['userId', 'id']),
      name: [
        invite.firstName.trim(),
        invite.middleName.trim(),
        invite.lastName.trim(),
      ].where((part) => part.isNotEmpty).join(' '),
      email: invite.email.trim(),
      phoneNumber: _ghanaPhoneNumber(invite.phoneNumber),
      role: 'ADMINISTRATOR',
      status: 'INVITED',
      lastLogin: 'Never',
      username: username,
      userType: 'STAFF',
      customSchoolId: customSchoolId,
      invitedAt: DateTime.now().toIso8601String(),
      dateOfBirth: _isoDate(invite.dateOfBirth),
    );
    return SchoolAdministratorInviteResult(
      message: _string(data, [
        'message',
      ], fallback: 'School administrator invitation sent successfully.'),
      username: username.isEmpty ? null : username,
      temporaryPassword: temporaryPassword.isEmpty ? null : temporaryPassword,
      user: createdUser,
    );
  }

  @override
  Future<List<SchoolUserInfo>> getSchoolUsers(String customSchoolId) async {
    _requireApi();
    final encoded = Uri.encodeComponent(customSchoolId);
    final response = await _get(
      '/api/user-management/schools/$encoded/users?page=0&size=100',
    );
    final usersJson = response is Map<String, dynamic> && response['users'] != null
        ? response['users']
        : _unwrap(response);
    return _asList(usersJson).map((item) {
      final map = _asMap(item);
      final firstName = _string(map, ['firstName']);
      final middleName = _string(map, ['middleName']);
      final lastName = _string(map, ['lastName']);
      final composedName = [
        firstName,
        middleName,
        lastName,
      ].where((part) => part.trim().isNotEmpty).join(' ');
      final role = map['role'];
      final status = map['accountStatus'] ?? map['status'];
      return SchoolUserInfo(
        id: _string(map, ['userId', 'id']),
        name: _string(map, [
          'fullName',
          'name',
          'displayName',
          'username',
        ], fallback: composedName.isEmpty ? 'Unnamed user' : composedName),
        email: _string(map, ['email'], fallback: 'Not provided'),
        phoneNumber: _string(map, [
          'phoneNumber',
          'phone',
        ], fallback: 'Not provided'),
        role: role is Map<String, dynamic>
            ? _string(role, ['name', 'roleName', 'code'])
            : role?.toString() ?? 'Not assigned',
        status: status is Map<String, dynamic>
            ? _string(status, ['name', 'status', 'code'])
            : status?.toString() ?? 'UNKNOWN',
        lastLogin: _string(map, [
          'lastLogin',
          'lastLoginAt',
          'lastActive',
        ], fallback: 'Never'),
        username: _string(map, ['username', 'userName']),
        userType: _string(map, ['userType', 'type']),
        customSchoolId: customSchoolId,
        schoolName: _string(map, ['schoolName']),
        createdAt: _string(map, ['createdAt', 'createdDate']),
        invitedAt: _string(map, ['invitedAt', 'inviteSentAt']),
        dateOfBirth: _string(map, ['dateOfBirth', 'dob']),
      );
    }).toList();
  }

  @override
  Future<SchoolUserInfo?> approveSchoolUser({
    required String customSchoolId,
    required String userId,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    final response = await _post(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser/approve',
      const {},
    );
    final data = _asMap(_unwrap(response));
    return data.isEmpty
        ? null
        : _schoolUserFromJson(data, customSchoolId: customSchoolId);
  }

  @override
  Future<SchoolUserInfo?> rejectSchoolUser({
    required String customSchoolId,
    required String userId,
    String? reason,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    final response = await _post(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser/reject',
      {'reason': reason?.trim() ?? ''},
    );
    final data = _asMap(_unwrap(response));
    return data.isEmpty
        ? null
        : _schoolUserFromJson(data, customSchoolId: customSchoolId);
  }

  @override
  Future<void> suspendSchoolUser({
    required String customSchoolId,
    required String userId,
    String? reason,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    final query = reason == null || reason.trim().isEmpty
        ? ''
        : '?reason=${Uri.encodeQueryComponent(reason.trim())}';
    await _post(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser/suspend$query',
      const {},
    );
  }

  @override
  Future<void> reactivateSchoolUser({
    required String customSchoolId,
    required String userId,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    await _post(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser/reactivate',
      const {},
    );
  }

  @override
  Future<SchoolUserInfo?> updateSchoolUserRole({
    required String customSchoolId,
    required String userId,
    required String role,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    final response = await _put(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser',
      {'role': role},
    );
    final data = _asMap(_unwrap(response));
    return data.isEmpty
        ? null
        : _schoolUserFromJson(data, customSchoolId: customSchoolId);
  }

  @override
  Future<SchoolAdministratorInviteResult> resendSchoolUserCredentials({
    required String customSchoolId,
    required String userId,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    final response = await _post(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser/resend-credentials',
      const {},
    );
    return _credentialActionResult(
      _asMap(_unwrap(response)),
      fallback: 'Credentials resent successfully.',
    );
  }

  @override
  Future<SchoolAdministratorInviteResult> resetSchoolUserPassword({
    required String customSchoolId,
    required String userId,
  }) async {
    _requireApi();
    final encodedSchool = Uri.encodeComponent(customSchoolId);
    final encodedUser = Uri.encodeComponent(userId);
    final response = await _post(
      '/api/user-management/schools/$encodedSchool/users/$encodedUser/reset-password',
      const {},
    );
    return _credentialActionResult(
      _asMap(_unwrap(response)),
      fallback: 'Password reset successfully.',
    );
  }

  @override
  Future<UserAuditLogPage> getUserAuditLogs({
    required String userId,
    int page = 0,
    int size = 50,
  }) async {
    _requireApi();
    final encodedUser = Uri.encodeComponent(userId);
    final response = await _get(
      '/api/audit-logs/user/$encodedUser?page=$page&size=$size',
    );
    final data = _asMap(_unwrap(response));
    final logs = _asList(
      data['logs'],
    ).map((item) => _userAuditLogFromJson(_asMap(item))).toList();
    return UserAuditLogPage(
      userId: _string(data, ['userId'], fallback: userId),
      userName: _string(data, ['userName', 'username']),
      logs: logs,
      totalElements: _int(data, ['totalElements'], fallback: logs.length),
      totalPages: _int(data, ['totalPages'], fallback: 1),
      currentPage: _int(data, ['currentPage', 'page'], fallback: page),
      pageSize: _int(data, ['pageSize', 'size'], fallback: size),
    );
  }

  UserAuditLog _userAuditLogFromJson(Map<String, dynamic> map) {
    return UserAuditLog(
      id: _string(map, ['id']),
      userId: _string(map, ['userId']),
      performedBy: _string(map, ['performedBy']),
      actionType: _string(map, ['actionType', 'action']),
      description: _string(map, ['description']),
      timestamp: _string(map, ['timestamp', 'createdAt']),
      ipAddress: _string(map, ['ipAddress']),
      userAgent: _string(map, ['userAgent']),
      metadata: map['metadata']?.toString(),
    );
  }

  SchoolAdministratorInviteResult _credentialActionResult(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final username = _string(data, [
      'username',
      'userName',
      'generatedUsername',
    ]);
    final temporaryPassword = _string(data, [
      'temporaryPassword',
      'tempPassword',
      'password',
      'newPassword',
    ]);
    return SchoolAdministratorInviteResult(
      message: _string(data, ['message'], fallback: fallback),
      username: username.isEmpty ? null : username,
      temporaryPassword: temporaryPassword.isEmpty ? null : temporaryPassword,
    );
  }

  SchoolUserInfo _schoolUserFromJson(
    Map<String, dynamic> map, {
    required String customSchoolId,
  }) {
    final firstName = _string(map, ['firstName']);
    final middleName = _string(map, ['middleName']);
    final lastName = _string(map, ['lastName']);
    final composedName = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ');
    final role = map['role'];
    final status = map['accountStatus'] ?? map['status'];
    return SchoolUserInfo(
      id: _string(map, ['userId', 'id']),
      name: _string(map, [
        'fullName',
        'name',
        'displayName',
        'username',
      ], fallback: composedName.isEmpty ? 'Unnamed user' : composedName),
      email: _string(map, ['email'], fallback: 'Not provided'),
      phoneNumber: _string(map, [
        'phoneNumber',
        'phone',
      ], fallback: 'Not provided'),
      role: role is Map<String, dynamic>
          ? _string(role, ['name', 'roleName', 'code'])
          : role?.toString() ?? 'Not assigned',
      status: status is Map<String, dynamic>
          ? _string(status, ['name', 'status', 'code'])
          : status?.toString() ?? 'UNKNOWN',
      lastLogin: _string(map, [
        'lastLogin',
        'lastLoginAt',
        'lastActive',
      ], fallback: 'Never'),
      username: _string(map, ['username', 'userName']),
      userType: _string(map, ['userType', 'type']),
      customSchoolId: customSchoolId,
      schoolName: _string(map, ['schoolName']),
      createdAt: _string(map, ['createdAt', 'createdDate']),
      invitedAt: _string(map, ['invitedAt', 'inviteSentAt']),
      dateOfBirth: _string(map, ['dateOfBirth', 'dob']),
    );
  }

  String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _ghanaPhoneNumber(String value) {
    final clean = value.trim();
    var digits = clean.replaceAll(RegExp(r'[^0-9]'), '');
    if (!digits.startsWith('233')) {
      if (digits.startsWith('0')) digits = digits.substring(1);
      digits = '233$digits';
    }
    final normalized = '+$digits';
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized)) {
      throw ArgumentError(
        'Phone number must contain 10 to 15 digits, including the country code.',
      );
    }
    return normalized;
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
    _requireApi();
    final response = await _accountManagersResponse(
      searchTerm: searchTerm,
      userStatuses: userStatuses,
      page: page,
      size: size,
    );
    final managers = _asList(
      _unwrap(response),
    ).map(_accountManagerFromJson).toList();
    final data = _asMap(response);
    return AccountManagerPage(
      managers: managers,
      totalElements: _int(data, ['totalElements'], fallback: managers.length),
      totalPages: _int(data, ['totalPages'], fallback: 1),
      currentPage: _int(data, [
        'number',
        'currentPage',
        'page',
      ], fallback: page),
      pageSize: _int(data, ['size', 'pageSize'], fallback: size),
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

  Future<dynamic> _accountManagersResponse({
    String? searchTerm,
    List<String> userStatuses = const [],
    required int page,
    required int size,
  }) async {
    _requireApi();
    final query = <String>[
      if (searchTerm != null && searchTerm.trim().isNotEmpty)
        'searchTerm=${Uri.encodeQueryComponent(searchTerm.trim())}',
      'page=$page',
      'size=$size',
      'sort=${Uri.encodeQueryComponent('createdAt,desc')}',
      ...userStatuses
          .where((status) => status.trim().isNotEmpty)
          .map(
            (status) =>
                'userStatuses=${Uri.encodeQueryComponent(status.trim())}',
          ),
    ].join('&');
    return _get('/api/account-managers/?$query');
  }

  @override
  Future<AccountManagerProfile> createAccountManager(
    AccountManagerDraft draft,
  ) async {
    _requireApi();

    final body = {
      'firstName': draft.firstName,
      'lastName': draft.lastName,
      'email': draft.email,
      'phoneNumber': draft.phone,
      'dateOfBirth': _apiDate(draft.dateOfBirth),
      'role': draft.role.apiRole,
      'userType': 'ADMIN',
      'privacyAgreementAccepted': true,
      'password': 'password',
      'inviteMethod': draft.inviteMethod,
    };

    try {
      final response = await _post('/api/auth/register/account-manager', body);
      return _accountManagerFromJson(_unwrap(response), draft: draft);
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<AccountManagerProfile> updateAccountManagerStatus({
    required String accountManagerId,
    required AccountManagerStatus status,
    String? reason,
  }) async {
    _requireApi();
    final encoded = Uri.encodeComponent(accountManagerId);
    final response = await _patch('/api/account-managers/$encoded/status', {
      'status': _accountManagerStatusApiValue(status),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return _accountManagerFromJson(_unwrap(response));
  }

  @override
  Future<void> deleteAccountManager({
    required String accountManagerId,
    String? reason,
  }) async {
    _requireApi();
    final encoded = Uri.encodeComponent(accountManagerId);
    await _delete('/api/account-managers/$encoded', {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  @override
  Future<SchoolAdministratorInviteResult> forceResetAccountManagerPassword({
    required AccountManagerProfile manager,
  }) async {
    _requireApi();
    final encoded = Uri.encodeComponent(manager.id);
    final response = await _post(
      '/api/account-managers/$encoded/reset-password',
      const {},
    );
    return _credentialActionResult(
      _asMap(_unwrap(response)),
      fallback: 'Password reset successfully.',
    );
  }

  @override
  Future<SchoolAdministratorInviteResult> resendAccountManagerCredentials({
    required AccountManagerProfile manager,
  }) async {
    _requireApi();
    final encoded = Uri.encodeComponent(manager.id);
    final response = await _post(
      '/api/account-managers/$encoded/resend-credentials',
      const {},
    );
    return _credentialActionResult(
      _asMap(_unwrap(response)),
      fallback: 'Temporary credentials sent successfully.',
    );
  }

  @override
  Future<List<SchoolAssignmentReasonOption>>
  getSchoolAssignmentReasons() async {
    _requireApi();
    final response = await _get(
      '/api/account-managers/school-assignment-reasons',
    );
    return _asList(_unwrap(response))
        .map((item) {
          final map = _asMap(item);
          return SchoolAssignmentReasonOption(
            value: _string(map, ['value']),
            label: _string(map, ['label', 'name', 'description']),
          );
        })
        .where((reason) => reason.value.isNotEmpty && reason.label.isNotEmpty)
        .toList();
  }

  @override
  Future<AccountManagerProfile> assignSchoolsToAccountManager({
    required String accountManagerId,
    required List<String> customSchoolIds,
    required String reason,
    String? notes,
  }) async {
    _requireApi();
    final managerId = Uri.encodeComponent(accountManagerId);
    final response =
        await _post('/api/account-managers/$managerId/assign-schools', {
          'customSchoolIds': customSchoolIds,
          'reason': reason,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        });
    return _accountManagerFromJson(_unwrap(response));
  }

  Future<dynamic> _putRegistrationStep(
    String customSchoolId,
    String currentStep,
    Map<String, dynamic> body,
  ) async {
    return _put(
      '/api/schools/$customSchoolId/registration-step?currentStep=$currentStep',
      body,
    );
  }

  Map<String, dynamic> _createSchoolBody(SchoolDraft draft) => {
    'schoolName': draft.schoolName,
    'schoolSlug': _schoolSlug(draft.schoolName),
    'yearFounded': draft.yearFounded,
    'motto': draft.motto,
    'category': {'id': draft.schoolTypeId, 'name': draft.schoolType},
    'educationLevel': {
      'id': draft.educationLevelId,
      'name': draft.educationLevel,
      'level': draft.educationLevel,
    },
  };

  Map<String, dynamic> _basicInfoBody(SchoolOnboardingDraft draft) => {
    'schoolName': draft.schoolName,
    'schoolSlug': _schoolSlug(draft.schoolName),
    'yearFounded': draft.yearFounded,
    'motto': draft.motto,
    'category': {'id': draft.schoolTypeId, 'name': draft.schoolType},
    'educationLevel': {
      'id': draft.educationLevelId,
      'name': draft.educationLevel,
      'level': draft.educationLevel,
    },
  };

  Map<String, dynamic> _registrationBody(SchoolOnboardingDraft draft) => {
    'registrationDetails': {
      'gesRegistrationNumber': draft.gesRegistrationNumber,
      'registrationNumberGes': draft.gesRegistrationNumber,
      'gesRegistrationTypeId': draft.gesRegistrationTypeId,
      if (draft.gesRegistrationTypeId != null)
        'gesRegistrationType': {'id': draft.gesRegistrationTypeId},
      if (draft.gesRegistrationTypeId != null)
        'registrationType': {'id': draft.gesRegistrationTypeId},
      'gesRegistrationDate': draft.gesRegistrationDate,
      'businessRegistrationNumber': draft.businessRegistrationNumber,
      'businessRegistrationTypeId': draft.businessRegistrationTypeId,
      if (draft.businessRegistrationTypeId != null)
        'businessRegistrationType': {'id': draft.businessRegistrationTypeId},
      'businessRegistrationDate': draft.businessRegistrationDate,
      'gemisCode': draft.gemisCode,
      'taxIdNumber': draft.taxIdNumber,
    },
  };

  Map<String, dynamic> _socialWelfareBody(SchoolOnboardingDraft draft) => {
    'socialWelfareCompliance': {
      'approvalNumber': draft.socialWelfareNumber,
      'approvalDate': draft.socialWelfareDate,
      'approvalOfficerName': draft.socialWelfareOfficer,
      'expiryDate': '',
      'complianceStatusId': draft.socialWelfareStatusId,
      if (draft.socialWelfareStatusId != null)
        'complianceStatus': {'id': draft.socialWelfareStatusId},
      'notes': '',
    },
  };

  Map<String, dynamic> _addressBody(SchoolOnboardingDraft draft) => {
    'address': {
      'houseNumber': draft.houseNumber,
      'streetName': draft.streetName,
      'additionalDirection': draft.additionalDirection,
      'ghanaPostAddress': draft.ghanaPostAddress,
      if (draft.gpsLatitude != null && draft.gpsLongitude != null)
        'gpsLocation': {
          'latitude': draft.gpsLatitude,
          'longitude': draft.gpsLongitude,
        },
      'city': draft.town,
      'country': draft.country,
      'district': {'id': draft.districtId},
      'region': {'id': draft.regionId},
    },
  };

  Map<String, dynamic> _contactBody(SchoolOnboardingDraft draft) => {
    'contactInfo': {
      'personalPhoneNumbers': [
        {
          'number': draft.phone,
          'type': draft.phoneNetwork.trim().isEmpty
              ? 'mobile'
              : draft.phoneNetwork.trim(),
        },
        if (draft.secondaryPhone.trim().isNotEmpty)
          {
            'number': draft.secondaryPhone,
            'type': draft.secondaryPhoneNetwork.trim().isEmpty
                ? 'mobile'
                : draft.secondaryPhoneNetwork.trim(),
          },
      ],
      'workPhoneNumbers': [
        if (draft.officePhone.trim().isNotEmpty)
          {'number': draft.officePhone, 'type': 'office'},
      ],
      'emails': draft.email
          .split(',')
          .map((email) => email.trim())
          .where((email) => email.isNotEmpty)
          .toList(),
      'socialMedia': draft.socialMediaLinks.isNotEmpty
          ? draft.socialMediaLinks
                .map(
                  (link) => {
                    if (link.platformId != null)
                      'platform': {'id': link.platformId},
                    'handle': link.handle,
                  },
                )
                .toList()
          : [
              if (draft.socialMedia.trim().isNotEmpty)
                {
                  if (draft.socialMediaPlatformId != null)
                    'platform': {'id': draft.socialMediaPlatformId},
                  'handle': draft.socialMedia,
                },
            ],
    },
  };

  Map<String, dynamic> _gradeLevelsBody(SchoolOnboardingDraft draft) => {
    'gradeLevels': draft.gradeLevelIds.entries
        .map(
          (entry) => {
            'gradeLevelId': entry.value,
            'gradeName': entry.key,
            'streamsCount': draft.gradeStreams[entry.key] ?? 0,
            'status': draft.gradeStreams.containsKey(entry.key)
                ? 'ACTIVE'
                : 'INACTIVE',
          },
        )
        .toList(),
  };

  Map<String, dynamic> _termCalendarBody(SchoolOnboardingDraft draft) => {
    'currentAcademicTerm': {
      'academicYear': {'id': draft.academicYearId},
      'termType': {'id': draft.academicTermId},
      'description': draft.termDescription,
      'startDate': _apiDateOrEmpty(draft.termStartDate),
      'endDate': _apiDateOrEmpty(draft.termEndDate),
      'events': draft.events
          .map(
            (event) => {
              'name': event.type == 'Other' && event.otherName.trim().isNotEmpty
                  ? event.otherName.trim()
                  : event.type,
              'description': event.description,
              'startDate': _apiDateOrEmpty(event.startDate),
              'endDate': _apiDateOrEmpty(event.endDate),
              'startTime': _apiTime(event.startTime, fallback: '00:00:00'),
              'endTime': _apiTime(event.endTime, fallback: '23:59:59'),
              'eventType': {'id': draft.eventTypeIds[event.type]},
              'isSchoolDay': event.isSchoolDay,
            },
          )
          .toList(),
    },
  };

  Future<void> _uploadPendingDocuments(
    String customSchoolId,
    SchoolOnboardingDraft draft,
  ) async {
    for (final entry in draft.documents.entries) {
      final documentType = _documentType(entry.key);
      final contentType = entry.value.mimeType ?? _mimeType(entry.value.name);
      final fileUrl = entry.value.url ?? '';

      if (fileUrl.isEmpty &&
          entry.value.bytes != null &&
          entry.value.bytes!.isNotEmpty) {
        await _uploadSchoolDocument(
          customSchoolId: customSchoolId,
          documentType: documentType,
          description: entry.key,
          fileName: entry.value.name,
          contentType: contentType,
          fileSize: entry.value.size,
          bytes: entry.value.bytes!,
        );
      }
    }
  }

  Future<dynamic> _completeDocumentsStep(
    String customSchoolId,
    SchoolOnboardingDraft draft,
  ) async {
    await _uploadPendingDocuments(customSchoolId, draft);
    return _putRegistrationStep(customSchoolId, 'DOCUMENTS', {});
  }

  Future<({String documentId, String fileUrl})> _uploadSchoolDocument({
    required String customSchoolId,
    required String documentType,
    required String description,
    required String fileName,
    required String contentType,
    required int fileSize,
    required List<int> bytes,
  }) async {
    final requestResponse =
        await _post('/api/schools/$customSchoolId/documents/upload-requests', {
          'fileName': fileName,
          'contentType': contentType,
          'fileSize': fileSize,
          'documentType': documentType,
          'description': description,
        });
    final requestJson = _unwrap(requestResponse);
    final uploadUrlValue = _jsonString(requestJson, [
      'uploadUrl',
      'uploadURL',
      'presignedUrl',
      'presignedURL',
      'signedUrl',
    ]);
    if (uploadUrlValue == null || uploadUrlValue.isEmpty) {
      throw http.ClientException('Document upload URL was not returned');
    }
    final uploadUrl = uploadUrlValue;
    final uploadUri = Uri.tryParse(uploadUrl);
    if (uploadUri == null ||
        !uploadUri.hasQuery ||
        !uploadUri.queryParameters.keys.any(
          (key) => key.toLowerCase().startsWith('x-amz-'),
        )) {
      throw http.ClientException(
        'The document upload URL is not a valid presigned S3 URL',
      );
    }

    final uploadHeaders = <String, String>{'Content-Type': contentType};
    // Browsers calculate Content-Length themselves and reject attempts to set
    // this forbidden header. Native clients still send it explicitly.
    if (!kIsWeb) uploadHeaders['Content-Length'] = fileSize.toString();
    late http.Response uploadResponse;
    try {
      uploadResponse = await _client
          .put(uploadUri, headers: uploadHeaders, body: bytes)
          .timeout(const Duration(seconds: 45));
    } on http.ClientException {
      throw http.ClientException(
        'S3 blocked the browser upload. Allow PUT from this web origin in the bucket CORS policy and expose the ETag response header.',
      );
    }
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw http.ClientException(
        'Document upload failed with ${uploadResponse.statusCode}',
      );
    }

    final documentId = _jsonString(requestJson, [
      'documentId',
      'documentID',
      'id',
    ]);
    if (documentId == null || documentId.isEmpty) {
      throw http.ClientException('Document id was not returned');
    }
    final eTag = (uploadResponse.headers['etag'] ?? '').replaceAll('"', '');
    if (eTag.isEmpty) {
      throw http.ClientException(
        'S3 did not return an accessible ETag. The bucket must expose the ETag response header.',
      );
    }
    dynamic confirmJson = const <String, dynamic>{};
    confirmJson = _unwrap(
      await _post(
        '/api/schools/$customSchoolId/documents/$documentId/confirm',
        {'eTag': eTag, 'fileSize': fileSize},
      ),
    );

    final fileUrl =
        _jsonString(confirmJson, [
          'fileUrl',
          'fileURL',
          'documentUrl',
          'documentURL',
          'publicUrl',
          'publicURL',
          'downloadUrl',
          'downloadURL',
          'objectUrl',
          'objectURL',
        ]) ??
        _jsonString(requestJson, [
          'fileUrl',
          'fileURL',
          'documentUrl',
          'documentURL',
          'publicUrl',
          'publicURL',
          'downloadUrl',
          'downloadURL',
          'objectUrl',
          'objectURL',
          'objectKey',
          'key',
        ]) ??
        uploadUrl.split('?').first;
    return (documentId: documentId, fileUrl: fileUrl);
  }

  String _documentType(String label) => switch (label) {
    'Business registration certificate' => 'BUSINESS_REGISTRATION',
    'GES registration document' => 'SCHOOL_REGISTRATION',
    'Social welfare approval' => 'SOCIAL_WELFARE',
    'School crest or logo' => 'SCHOOL_CREST',
    'School front photo' => 'SCHOOL_PHOTO',
    _ => label.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_'),
  };

  String? _jsonString(dynamic json, List<String> keys) {
    if (json is Map<String, dynamic>) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      for (final value in json.values) {
        final nested = _jsonString(value, keys);
        if (nested != null && nested.trim().isNotEmpty) return nested;
      }
    }
    if (json is List) {
      for (final value in json) {
        final nested = _jsonString(value, keys);
        if (nested != null && nested.trim().isNotEmpty) return nested;
      }
    }
    return null;
  }

  SchoolOnboardingProgress _onboardingProgressFromJson(
    dynamic json, {
    required String? fallbackCustomSchoolId,
    required int fallbackCompletedStepIndex,
    required String fallbackCurrentStep,
  }) {
    final unwrapped = _unwrap(json);
    final map = _asMap(unwrapped);
    final completedSteps = _completedStepsFromJson(map);
    return SchoolOnboardingProgress(
      customSchoolId:
          _jsonString(unwrapped, ['customSchoolId', 'schoolCode', 'code']) ??
          fallbackCustomSchoolId,
      registrationStatus:
          _jsonString(unwrapped, ['registrationStatus', 'status']) ??
          (fallbackCompletedStepIndex >= 8 ? 'COMPLETED' : 'IN_PROGRESS'),
      currentStep:
          _jsonString(unwrapped, ['currentStep', 'nextStep']) ??
          fallbackCurrentStep,
      completedSteps: completedSteps.isEmpty
          ? _fallbackCompletedSteps(fallbackCompletedStepIndex)
          : completedSteps,
      totalSteps: _onboardingSteps.length,
    );
  }

  List<String> _completedStepsFromJson(Map<String, dynamic> map) {
    final value = map['completedSteps'];
    if (value is List) {
      return value
          .map((step) => step.toString().trim())
          .where((step) => step.isNotEmpty)
          .toList();
    }
    final navigation = map['navigation'];
    if (navigation is Map<String, dynamic>) {
      final nested = navigation['completedSteps'];
      if (nested is List) {
        return nested
            .map((step) => step.toString().trim())
            .where((step) => step.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  List<String> _fallbackCompletedSteps(int stepIndex) => [
    for (var i = 0; i <= stepIndex && i < _onboardingSteps.length; i++)
      _onboardingSteps[i],
  ];

  String _stepNameForIndex(int index) =>
      _onboardingSteps[index.clamp(0, _onboardingSteps.length - 1)];

  String _schoolSlug(String schoolName) {
    final slug = schoolName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'new-school' : slug;
  }

  String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  Future<dynamic> _get(String path) async {
    final response = await _sendWithRefresh(
      () => _client.get(
        Uri.parse('${PlatformApiClient.baseUrl}$path'),
        headers: _headers,
      ),
    );
    return _decodeOrThrow(response);
  }

  Future<List<AccountManagerProfile>> _getAccountManagersForDashboard() async {
    try {
      return await getAccountManagers();
    } catch (_) {
      return const [];
    }
  }

  Future<
    ({
      int total,
      int active,
      int invited,
      int pending,
      String caption,
      String pendingCaption,
    })?
  >
  _getRoleScopedAccountManagerTotals() async {
    try {
      final total = await getAccountManagerPage(page: 0, size: 1);
      final active = await getAccountManagerPage(
        userStatuses: const ['ACTIVE'],
        page: 0,
        size: 1,
      );
      final invited = await getAccountManagerPage(
        userStatuses: const ['INVITED'],
        page: 0,
        size: 1,
      );
      final pending = await getAccountManagerPage(
        userStatuses: const ['PENDING'],
        page: 0,
        size: 1,
      );
      return (
        total: total.totalElements,
        active: active.totalElements,
        invited: invited.totalElements,
        pending: pending.totalElements,
        caption: '${active.totalElements} active · ${invited.totalElements} invited',
        pendingCaption: '${pending.totalElements} pending approval',
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<ManagedSchool>> _getDashboardSchoolsForOverview() async {
    try {
      final schoolsResponse = await _get(
        '/api/super-admin/dashboard/schools?page=0&size=100',
      );
      return _asList(_unwrap(schoolsResponse)).map(_schoolFromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<NeedsAttentionSummary?> _getNeedsAttentionForDashboard() async {
    try {
      return await getNeedsAttentionSummary();
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRefresh(
      () => _client.post(
        Uri.parse('${PlatformApiClient.baseUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decodeOrThrow(response);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRefresh(
      () => _client.put(
        Uri.parse('${PlatformApiClient.baseUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decodeOrThrow(response);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRefresh(
      () => _client.patch(
        Uri.parse('${PlatformApiClient.baseUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decodeOrThrow(response);
  }

  Future<dynamic> _delete(String path, Map<String, dynamic> body) async {
    final response = await _sendWithRefresh(
      () => _client.delete(
        Uri.parse('${PlatformApiClient.baseUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );
    return _decodeOrThrow(response);
  }

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() send,
  ) async {
    var response = await send().timeout(const Duration(seconds: 15));
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshedToken = await onRefreshAccessToken!.call();
      if (refreshedToken != null &&
          refreshedToken.isNotEmpty &&
          refreshedToken != accessToken) {
        accessToken = refreshedToken;
        response = await send().timeout(const Duration(seconds: 15));
      }
    }
    return response;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $accessToken',
  };

  dynamic _decodeOrThrow(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw http.ClientException(
        detail.isEmpty
            ? 'API request failed with ${response.statusCode}'
            : 'API request failed with ${response.statusCode}: $detail',
      );
    }
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }

  dynamic _unwrap(dynamic json) {
    if (json is Map<String, dynamic>) {
      for (final key in ['data', 'content', 'items', 'result', 'payload']) {
        final value = json[key];
        if (value != null) return value;
      }
    }
    return json;
  }

  dynamic _unwrapSchoolRecord(dynamic json) {
    var current = _unwrap(json);
    for (var depth = 0; depth < 4; depth++) {
      if (current is! Map<String, dynamic>) break;
      if (current.containsKey('customSchoolId') ||
          current.containsKey('schoolName')) {
        break;
      }
      dynamic nested;
      for (final key in [
        'school',
        'schoolDetails',
        'schoolDetail',
        'schoolRegistration',
        'onboarding',
      ]) {
        if (current[key] is Map) {
          nested = current[key];
          break;
        }
      }
      if (nested == null) break;
      current = _unwrap(nested);
    }
    return current;
  }

  List<dynamic> _asList(dynamic json) {
    if (json is List) return json;
    if (json is Map<String, dynamic>) {
      for (final key in ['schools', 'accountManagers', 'users', 'content']) {
        final value = json[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  Map<String, dynamic> _asMap(dynamic json) =>
      json is Map<String, dynamic> ? json : <String, dynamic>{};

  String _dashboardManagerName(Map<String, dynamic> dashboard) {
    final fromDashboard = _string(dashboard, [
      'managerName',
      'displayName',
      'userName',
      'name',
    ]);
    if (fromDashboard.isNotEmpty) return fromDashboard;
    final user = dashboard['user'];
    if (user is Map<String, dynamic>) {
      final name = _string(user, ['displayName', 'name', 'userName']);
      if (name.isNotEmpty) return name;
    }
    final sessionName = userDisplayName?.trim() ?? '';
    return sessionName.isEmpty ? 'Super Admin' : sessionName;
  }

  (int?, String) _statValue(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is num) return (value.toInt(), '');
    if (value is String) return (int.tryParse(value), '');
    if (value is Map<String, dynamic>) {
      final count = _int(value, ['value', 'count', 'total']);
      final change = value['change'];
      if (change is Map<String, dynamic>) {
        final label = _string(change, ['label', 'description']);
        if (label.isNotEmpty) return (count, label);
        final direction = _string(change, ['direction']);
        final changeValue = change['value'];
        if (changeValue != null && changeValue.toString().isNotEmpty) {
          return (
            count,
            '${direction.isEmpty ? '' : '$direction '}${changeValue.toString()}',
          );
        }
      }
      return (count, _string(value, ['label', 'description']));
    }
    return (null, '');
  }

  ManagedSchool _schoolFromJson(dynamic json, {SchoolDraft? draft}) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final name = _string(map, [
      'schoolName',
      'name',
    ], fallback: draft?.schoolName ?? 'Unnamed School');
    final statusText = _string(map, [
      'registrationStatus',
      'status',
    ], fallback: 'IN_PROGRESS');
    final progress = _schoolProgress(map);

    return ManagedSchool(
      name: name,
      code: _string(map, [
        'customSchoolId',
        'schoolCode',
        'code',
        'id',
      ], fallback: 'PENDING'),
      region: _nestedString(map, [
        'region',
      ], fallback: draft?.region ?? 'Not provided'),
      district: _nestedString(map, ['district'], fallback: ''),
      town: _nestedString(map, [
        'town',
        'city',
      ], fallback: draft?.town ?? 'Not provided'),
      students: _int(map, [
        'students',
        'studentCount',
        'numberOfStudents',
        'totalStudents',
      ]),
      staff: _int(map, ['staff', 'staffCount', 'numberOfStaff']),
      status: schoolStatusFromApi(statusText),
      progress: progress,
      accountManager: _nestedString(map, [
        'accountManagerName',
        'accountManager',
        'assignedAccountManager',
      ], fallback: 'Not assigned'),
      accountManagerId: _string(map, ['accountManagerId']),
      subscriptionPlan: _string(map, [
        'subscriptionPlan',
        'plan',
      ], fallback: 'Trial'),
      subscriptionStatus: _string(map, [
        'subscriptionStatus',
      ], fallback: statusText.isEmpty ? 'Trial' : statusText),
      renewalDate: _string(map, [
        'renewalDate',
      ], fallback: 'Pending activation'),
      lastActive: _string(map, [
        'lastActive',
        'lastUpdated',
        'updatedAt',
        'createdAt',
      ], fallback: 'Recently'),
      approvedDate: _string(
        map,
        ['approvedDate', 'approvalDate'],
        fallback: schoolStatusFromApi(statusText).isApproved
            ? 'Approved'
            : 'In progress',
      ),
      administratorName: _string(map, [
        'administratorName',
        'adminName',
      ], fallback: draft?.administratorName ?? 'Not provided'),
      administratorPhone: _string(map, [
        'administratorPhone',
        'adminPhone',
      ], fallback: draft?.administratorPhone ?? 'Not provided'),
      administratorEmail: _string(map, [
        'administratorEmail',
        'adminEmail',
      ], fallback: draft?.administratorEmail ?? 'Not provided'),
    );
  }

  AccountManagerProfile _accountManagerFromJson(
    dynamic json, {
    AccountManagerDraft? draft,
  }) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    final firstName = _string(map, [
      'firstName',
    ], fallback: draft?.firstName ?? '');
    final lastName = _string(map, [
      'lastName',
    ], fallback: draft?.lastName ?? '');
    final fullName = _string(map, [
      'name',
      'fullName',
      'displayName',
    ], fallback: '$firstName $lastName'.trim());
    final statusText = _string(map, [
      'status',
      'userStatus',
      'accountStatus',
      'registrationStatus',
      'verificationStatus',
    ]);
    final schoolCount = _int(map, [
      'schoolCount',
      'schoolsCount',
      'numberOfSchools',
      'assignedSchools',
      'schoolsOnboardedCount',
    ]);

    return AccountManagerProfile(
      id: _string(map, ['id', 'accountManagerId']),
      userId: _string(map, ['userId'], fallback: _string(map, ['id'])),
      name: fullName.isEmpty ? 'Account Manager' : fullName,
      email: _string(map, ['email'], fallback: draft?.email ?? ''),
      phone: _string(map, [
        'phone',
        'phoneNumber',
      ], fallback: draft?.phone ?? ''),
      region: _nestedString(map, ['region'], fallback: 'Not assigned'),
      schoolCount: schoolCount,
      activeSchoolCount: _int(map, [
        'activeSchoolCount',
        'activeSchools',
      ], fallback: schoolCount),
      status: _accountManagerStatus(statusText, draft: draft),
      lastActive: _string(map, [
        'lastActive',
        'lastLogin',
      ], fallback: 'Not yet active'),
      joined: _string(map, [
        'joined',
        'createdAt',
      ], fallback: draft == null ? 'Unknown' : 'Invite sent today'),
      inviteMethod: _string(map, [
        'inviteMethod',
      ], fallback: draft?.inviteMethod ?? 'Email and SMS'),
      verified: _bool(map, ['verified', 'isVerified'], fallback: false),
      bio: _string(
        map,
        ['bio'],
        fallback: draft == null
            ? 'Platform account manager.'
            : 'Awaiting first login and profile verification.',
      ),
    );
  }

  NeedsAttentionCategory _needsAttentionCategoryFromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return NeedsAttentionCategory(
      category: _string(map, ['category']),
      label: _string(map, ['label', 'title', 'name']),
      count: _int(map, ['count', 'total']),
      priority: _string(map, ['priority']),
    );
  }

  NeedsAttentionItem _needsAttentionItemFromJson(dynamic json) {
    final map = json is Map<String, dynamic> ? json : <String, dynamic>{};
    return NeedsAttentionItem(
      id: _string(map, ['id']),
      category: _string(map, ['category']),
      priority: _string(map, ['priority']),
      title: _string(map, ['title', 'entityName']),
      description: _string(map, ['description', 'detail']),
      entityType: _string(map, ['entityType']),
      entityId: _string(map, ['entityId']),
      status: _string(map, ['status']),
      ageInDays: _nullableInt(map, ['ageInDays']),
      actionTarget: _string(map, ['actionTarget']),
      type: _string(map, ['type']),
      createdAt: _string(map, ['createdAt']),
    );
  }

  double _schoolProgress(Map<String, dynamic> map) {
    final completedSteps = _completedStepsFromJson(map);
    if (completedSteps.isNotEmpty) {
      return (completedSteps.length / _onboardingSteps.length).clamp(0.0, 1.0);
    }
    final raw = _double(map, [
      'progress',
      'setupProgress',
      'onboardingProgress',
      'completionPercentage',
    ]);
    return raw > 1 ? (raw / 100).clamp(0.0, 1.0) : raw.clamp(0.0, 1.0);
  }

  String? _apiSchoolStatus(String? status) {
    final value = status?.trim().toLowerCase();
    return switch (value) {
      null || '' || 'all statuses' => null,
      'approved' || 'active' => 'APPROVED',
      'in progress' || 'onboarding' => 'IN_PROGRESS',
      'pending approval' => 'PENDING_APPROVAL',
      'needs revision' || 'needs attention' => 'NEEDS_REVISION',
      'rejected' => 'REJECTED',
      'suspended' => 'SUSPENDED',
      'inactive' => 'INACTIVE',
      'completed' => 'COMPLETED',
      'deleted' => 'DELETED',
      _ => status!.trim().toUpperCase().replaceAll(' ', '_'),
    };
  }

  String? _apiRegion(String? region) {
    final value = region?.trim();
    if (value == null || value.isEmpty || value == 'All Regions') return null;
    return value;
  }

  bool _matchesApiFallbackFilters(
    ManagedSchool school, {
    String? searchTerm,
    String? region,
    String? district,
    String? status,
    String? accountManager,
  }) {
    final query = searchTerm?.trim().toLowerCase() ?? '';
    final matchesSearch =
        query.isEmpty ||
        school.name.toLowerCase().contains(query) ||
        school.code.toLowerCase().contains(query) ||
        school.region.toLowerCase().contains(query);
    final matchesRegion =
        region == null ||
        region == 'All Regions' ||
        school.region.toLowerCase() == region.toLowerCase();
    final matchesDistrict =
        district == null ||
        district == 'All Districts' ||
        school.district.toLowerCase() == district.toLowerCase();
    final matchesStatus =
        status == null ||
        status == 'All Statuses' ||
        school.status.apiValue == _apiSchoolStatus(status);
    final matchesManager =
        accountManager == null ||
        accountManager == 'All AMs' ||
        school.accountManager == accountManager ||
        school.accountManagerId == accountManager;
    return matchesSearch &&
        matchesRegion &&
        matchesDistrict &&
        matchesStatus &&
        matchesManager;
  }

  AccountManagerStatus _accountManagerStatus(
    String status, {
    AccountManagerDraft? draft,
  }) {
    final value = status.toUpperCase();
    if (draft != null) return AccountManagerStatus.invited;
    if (value.contains('SUSPEND')) return AccountManagerStatus.suspended;
    if (value.contains('INVIT')) return AccountManagerStatus.invited;
    if (value.contains('PENDING')) return AccountManagerStatus.pendingApproval;
    return AccountManagerStatus.active;
  }

  String _accountManagerStatusApiValue(AccountManagerStatus status) {
    return switch (status) {
      AccountManagerStatus.active => 'ACTIVE',
      AccountManagerStatus.pendingApproval => 'PENDING',
      AccountManagerStatus.invited => 'INVITED',
      AccountManagerStatus.suspended => 'SUSPENDED',
    };
  }

  String _string(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String _nestedString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is Map<String, dynamic>) {
        for (final childKey in ['name', 'label', 'description']) {
          final child = value[childKey];
          if (child != null && child.toString().trim().isNotEmpty) {
            return child.toString();
          }
        }
      }
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  int _int(Map<String, dynamic> map, List<String> keys, {int fallback = 0}) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  int? _nullableInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  double _double(
    Map<String, dynamic> map,
    List<String> keys, {
    double fallback = 0,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  bool _bool(
    Map<String, dynamic> map,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
    }
    return fallback;
  }

  String _apiDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _apiDateOrEmpty(DateTime? date) => date == null ? '' : _apiDate(date);

  String _apiTime(String value, {required String fallback}) {
    final numbers = RegExp(r'\d{1,2}')
        .allMatches(value)
        .map((match) => int.tryParse(match.group(0)!))
        .whereType<int>()
        .toList();
    if (numbers.length < 2) return fallback;
    final hour = numbers[0].clamp(0, 23).toString().padLeft(2, '0');
    final minute = numbers[1].clamp(0, 59).toString().padLeft(2, '0');
    final second = (numbers.length > 2 ? numbers[2] : 0)
        .clamp(0, 59)
        .toString()
        .padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
