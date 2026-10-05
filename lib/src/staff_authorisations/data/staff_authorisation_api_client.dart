import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class StaffAuthorisationApiClient {
  StaffAuthorisationApiClient({
    required this.accessToken,
    this.onRefreshAccessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final http.Client _client;

  String _root(String schoolId) =>
      '/api/schools/${Uri.encodeComponent(schoolId)}/staff-authorisations';

  Future<AuthorisationCatalog> getCatalog(String schoolId) async =>
      AuthorisationCatalog.fromJson(
        _map(await _send('GET', '${_root(schoolId)}/catalog')),
      );

  Future<List<AuthorityTemplateRecord>> getAuthorities(String schoolId) async =>
      _list(
        await _send('GET', '${_root(schoolId)}/authorities'),
      ).map(AuthorityTemplateRecord.fromJson).toList();

  Future<AuthorityTemplateRecord> createAuthority({
    required String schoolId,
    required String name,
    required String description,
    required String baseTemplateId,
    List<PermissionRuleInput> rules = const [],
  }) async => AuthorityTemplateRecord.fromJson(
    _map(
      await _send(
        'POST',
        '${_root(schoolId)}/authorities',
        body: {
          'name': name,
          'description': description,
          'baseTemplateId': int.parse(baseTemplateId),
          'permissionRules': rules.map((rule) => rule.toJson()).toList(),
        },
      ),
    ),
  );

  Future<List<JobTitleRecord>> getJobTitles(
    String schoolId, {
    bool includeInactive = true,
  }) async => _list(
    await _send(
      'GET',
      '${_root(schoolId)}/job-titles?includeInactive=$includeInactive',
    ),
  ).map(JobTitleRecord.fromJson).toList();

  Future<JobTitleRecord> createJobTitle({
    required String schoolId,
    required String name,
    required String description,
    required String authorityTemplateId,
  }) async => JobTitleRecord.fromJson(
    _map(
      await _send(
        'POST',
        '${_root(schoolId)}/job-titles',
        body: {
          'name': name,
          'description': description,
          'authorityTemplateId': int.parse(authorityTemplateId),
        },
      ),
    ),
  );

  Future<JobTitleRecord> updateJobTitle({
    required String schoolId,
    required JobTitleRecord title,
    required bool active,
  }) async => JobTitleRecord.fromJson(
    _map(
      await _send(
        'PUT',
        '${_root(schoolId)}/job-titles/${title.id}',
        body: {'active': active, 'version': title.version},
      ),
    ),
  );

  Future<List<StaffAccessUser>> getStaffUsers(String schoolId) async {
    final query = Uri(queryParameters: {'page': '0', 'size': '250'}).query;
    return _list(
          await _send(
            'GET',
            '/api/user-management/schools/${Uri.encodeComponent(schoolId)}/users?$query',
          ),
        )
        .map(StaffAccessUser.fromJson)
        .where((user) => user.userType == 'STAFF')
        .toList();
  }

  Future<AuthorityAssignmentRecord> assignAuthority({
    required String schoolId,
    required String userId,
    required String authorityTemplateId,
    required String scopeType,
    String? scopeId,
    String? startsOn,
    String? endsOn,
    bool primary = false,
  }) async => AuthorityAssignmentRecord.fromJson(
    _map(
      await _send(
        'POST',
        '${_root(schoolId)}/assignments',
        body: {
          'userId': int.parse(userId),
          'authorityTemplateId': int.parse(authorityTemplateId),
          'scopeType': scopeType,
          if (scopeId?.trim().isNotEmpty == true) 'scopeId': scopeId!.trim(),
          if (startsOn?.isNotEmpty == true) 'startsOn': startsOn,
          if (endsOn?.isNotEmpty == true) 'endsOn': endsOn,
          'primary': primary,
        },
      ),
    ),
  );

  Future<PermissionExceptionRecord> createException({
    required String schoolId,
    required String userId,
    required String module,
    required String resource,
    required String action,
    required String effect,
    required String scopeType,
    String? scopeId,
    required String reason,
    String? startsOn,
    String? expiresOn,
  }) async => PermissionExceptionRecord.fromJson(
    _map(
      await _send(
        'POST',
        '${_root(schoolId)}/exceptions',
        body: {
          'userId': int.parse(userId),
          'module': module,
          'resource': resource,
          'action': action,
          'effect': effect,
          'scopeType': scopeType,
          if (scopeId?.trim().isNotEmpty == true) 'scopeId': scopeId!.trim(),
          'reason': reason,
          if (startsOn?.isNotEmpty == true) 'startsOn': startsOn,
          if (expiresOn?.isNotEmpty == true) 'expiresOn': expiresOn,
        },
      ),
    ),
  );

  Future<EffectiveAccessRecord> getEffectiveAccess({
    required String schoolId,
    required String userId,
  }) async => EffectiveAccessRecord.fromJson(
    _map(
      await _send(
        'GET',
        '${_root(schoolId)}/users/${Uri.encodeComponent(userId)}/effective-access',
      ),
    ),
  );

  Future<List<PermissionExceptionRecord>> getPendingExceptions(
    String schoolId,
  ) async => _list(
    await _send('GET', '${_root(schoolId)}/exceptions/pending'),
  ).map(PermissionExceptionRecord.fromJson).toList();

  Future<List<AuthorityAssignmentRecord>> getPendingAssignments(
    String schoolId,
  ) async => _list(
    await _send('GET', '${_root(schoolId)}/assignments/pending'),
  ).map(AuthorityAssignmentRecord.fromJson).toList();

  Future<void> decideException({
    required String schoolId,
    required String exceptionId,
    required bool approve,
    String reason = '',
  }) async {
    await _send(
      'POST',
      '${_root(schoolId)}/exceptions/$exceptionId/${approve ? 'approve' : 'reject'}',
      body: approve ? null : {'reason': reason},
    );
  }

  Future<void> approveAssignment({
    required String schoolId,
    required String assignmentId,
  }) async {
    await _send('POST', '${_root(schoolId)}/assignments/$assignmentId/approve');
  }

  Future<void> revokeException({
    required String schoolId,
    required String exceptionId,
    required String reason,
  }) async {
    await _send(
      'POST',
      '${_root(schoolId)}/exceptions/$exceptionId/revoke',
      body: {'reason': reason},
    );
  }

  Future<void> revokeAssignment({
    required String schoolId,
    required String assignmentId,
    required String reason,
  }) async {
    await _send(
      'POST',
      '${_root(schoolId)}/assignments/$assignmentId/revoke',
      body: {'reason': reason},
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (accessToken == null || accessToken!.isEmpty) {
      throw const StaffAuthorisationApiException(
        'Please sign in again to manage authorisations.',
      );
    }

    Future<http.Response> send() {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };
      final encoded = body == null ? null : jsonEncode(body);
      return switch (method) {
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers, body: encoded),
        _ => _client.get(uri, headers: headers),
      }.timeout(const Duration(seconds: 20));
    }

    try {
      var response = await send();
      if ((response.statusCode == 401 || response.statusCode == 403) &&
          onRefreshAccessToken != null) {
        final refreshed = await onRefreshAccessToken!.call();
        if (refreshed?.isNotEmpty == true) {
          accessToken = refreshed;
          response = await send();
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw StaffAuthorisationApiException(_errorMessage(response));
    } on TimeoutException {
      throw const StaffAuthorisationApiException(
        'The authorisation request took too long. Please try again.',
      );
    } on StaffAuthorisationApiException {
      rethrow;
    } catch (_) {
      throw const StaffAuthorisationApiException(
        'Unable to reach the authorisation service right now.',
      );
    }
  }

  dynamic _decoded(http.Response response) {
    if (response.body.trim().isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body);
  }

  Map<String, dynamic> _map(http.Response response) {
    final value = _decoded(response);
    if (value is Map<String, dynamic>) {
      final data = value['data'];
      if (data is Map<String, dynamic>) return data;
      return value;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _list(http.Response response) {
    final value = _decoded(response);
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      final nested =
          value['content'] ?? value['data'] ?? value['items'] ?? value['users'];
      if (nested is List) return nested;
      if (nested is Map<String, dynamic> && nested['content'] is List) {
        return nested['content'] as List;
      }
    }
    return const [];
  }

  String _errorMessage(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) {
        for (final key in ['message', 'detail', 'error']) {
          final text = value[key]?.toString().trim() ?? '';
          if (text.isNotEmpty) return text;
        }
      }
    } catch (_) {}
    return switch (response.statusCode) {
      403 => 'You do not have permission to manage staff authorisations.',
      409 => 'This access record changed. Refresh and try again.',
      >= 500 => 'The authorisation service is having trouble.',
      _ => 'The authorisation change could not be completed.',
    };
  }
}

class StaffAuthorisationApiException implements Exception {
  const StaffAuthorisationApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthorisationCatalog {
  const AuthorisationCatalog({
    required this.modules,
    required this.actions,
    required this.scopeTypes,
    required this.resources,
  });
  final List<String> modules;
  final List<String> actions;
  final List<String> scopeTypes;
  final List<String> resources;

  factory AuthorisationCatalog.fromJson(dynamic value) {
    final json = _json(value);
    return AuthorisationCatalog(
      modules: _strings(json['modules']),
      actions: _strings(json['actions']),
      scopeTypes: _strings(json['scopeTypes']),
      resources: _strings(json['resources']),
    );
  }
}

class PermissionRuleInput {
  const PermissionRuleInput({
    required this.module,
    required this.resource,
    required this.action,
    required this.effect,
    required this.scopeType,
  });
  final String module;
  final String resource;
  final String action;
  final String effect;
  final String scopeType;
  Map<String, dynamic> toJson() => {
    'module': module,
    'resource': resource,
    'action': action,
    'effect': effect,
    'scopeType': scopeType,
  };
}

class AuthorityTemplateRecord {
  const AuthorityTemplateRecord({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.baseRole,
    required this.builtIn,
    required this.active,
    required this.assignedUsers,
    required this.permissionRules,
  });
  final String id;
  final String key;
  final String name;
  final String description;
  final String baseRole;
  final bool builtIn;
  final bool active;
  final int assignedUsers;
  final List<PermissionRuleInput> permissionRules;

  factory AuthorityTemplateRecord.fromJson(dynamic value) {
    final json = _json(value);
    final rules = json['permissionRules'];
    return AuthorityTemplateRecord(
      id: '${json['id'] ?? ''}',
      key: '${json['key'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      baseRole: '${json['baseRole'] ?? ''}',
      builtIn: json['builtIn'] == true,
      active: json['active'] != false,
      assignedUsers: int.tryParse('${json['assignedUsers'] ?? 0}') ?? 0,
      permissionRules: rules is List
          ? rules.map((item) {
              final rule = _json(item);
              return PermissionRuleInput(
                module: '${rule['module'] ?? ''}',
                resource: '${rule['resource'] ?? '*'}',
                action: '${rule['action'] ?? ''}',
                effect: '${rule['effect'] ?? ''}',
                scopeType: '${rule['scopeType'] ?? 'SCHOOL'}',
              );
            }).toList()
          : const [],
    );
  }
}

class JobTitleRecord {
  const JobTitleRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.systemDefault,
    required this.active,
    required this.version,
    required this.authority,
  });
  final String id;
  final String name;
  final String description;
  final bool systemDefault;
  final bool active;
  final int version;
  final AuthorityTemplateRecord authority;

  factory JobTitleRecord.fromJson(dynamic value) {
    final json = _json(value);
    return JobTitleRecord(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      description: '${json['description'] ?? ''}',
      systemDefault: json['systemDefault'] == true,
      active: json['active'] != false,
      version: int.tryParse('${json['version'] ?? 0}') ?? 0,
      authority: AuthorityTemplateRecord.fromJson(json['authority']),
    );
  }
}

class StaffAccessUser {
  const StaffAccessUser({
    required this.id,
    required this.name,
    required this.userType,
    required this.role,
    required this.accountStatus,
  });
  final String id;
  final String name;
  final String userType;
  final String role;
  final String accountStatus;

  factory StaffAccessUser.fromJson(dynamic value) {
    final json = _json(value);
    final name = [json['firstName'], json['middleName'], json['lastName']]
        .map((part) => '${part ?? ''}'.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    return StaffAccessUser(
      id: '${json['id'] ?? json['userId'] ?? ''}',
      name: name.isEmpty ? '${json['userName'] ?? 'Staff member'}' : name,
      userType: '${json['userType'] ?? ''}'.toUpperCase(),
      role: '${json['role'] ?? ''}',
      accountStatus: '${json['accountStatus'] ?? json['status'] ?? ''}',
    );
  }
}

class AuthorityAssignmentRecord {
  const AuthorityAssignmentRecord({
    required this.id,
    required this.userId,
    required this.authorityName,
    required this.baseRole,
    required this.scopeType,
    required this.scopeId,
    required this.status,
    required this.active,
    required this.assignedBy,
  });
  final String id;
  final String userId;
  final String authorityName;
  final String baseRole;
  final String scopeType;
  final String scopeId;
  final String status;
  final bool active;
  final String assignedBy;

  factory AuthorityAssignmentRecord.fromJson(dynamic value) {
    final json = _json(value);
    return AuthorityAssignmentRecord(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      authorityName: '${json['authorityName'] ?? ''}',
      baseRole: '${json['baseRole'] ?? ''}',
      scopeType: '${json['scopeType'] ?? 'SCHOOL'}',
      scopeId: '${json['scopeId'] ?? ''}',
      status: '${json['status'] ?? ''}',
      active: json['active'] == true,
      assignedBy: '${json['assignedBy'] ?? ''}',
    );
  }
}

class PermissionExceptionRecord {
  const PermissionExceptionRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.module,
    required this.resource,
    required this.action,
    required this.effect,
    required this.scopeType,
    required this.scopeId,
    required this.reason,
    required this.status,
    required this.sensitiveChange,
    required this.requestedBy,
  });
  final String id;
  final String userId;
  final String userName;
  final String module;
  final String resource;
  final String action;
  final String effect;
  final String scopeType;
  final String scopeId;
  final String reason;
  final String status;
  final bool sensitiveChange;
  final String requestedBy;

  factory PermissionExceptionRecord.fromJson(dynamic value) {
    final json = _json(value);
    return PermissionExceptionRecord(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      userName: '${json['userName'] ?? ''}',
      module: '${json['module'] ?? ''}',
      resource: '${json['resource'] ?? '*'}',
      action: '${json['action'] ?? ''}',
      effect: '${json['effect'] ?? ''}',
      scopeType: '${json['scopeType'] ?? 'SCHOOL'}',
      scopeId: '${json['scopeId'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      status: '${json['status'] ?? ''}',
      sensitiveChange: json['sensitiveChange'] == true,
      requestedBy: '${json['requestedBy'] ?? ''}',
    );
  }
}

class AccessDecisionRecord {
  const AccessDecisionRecord({
    required this.module,
    required this.resource,
    required this.action,
    required this.allowed,
    required this.source,
  });
  final String module;
  final String resource;
  final String action;
  final bool allowed;
  final String source;

  factory AccessDecisionRecord.fromJson(dynamic value) {
    final json = _json(value);
    return AccessDecisionRecord(
      module: '${json['module'] ?? ''}',
      resource: '${json['resource'] ?? '*'}',
      action: '${json['action'] ?? ''}',
      allowed: json['allowed'] == true,
      source: '${json['source'] ?? ''}',
    );
  }
}

class EffectiveAccessRecord {
  const EffectiveAccessRecord({
    required this.userId,
    required this.displayName,
    required this.roles,
    required this.authorities,
    required this.exceptions,
    required this.decisions,
  });
  final String userId;
  final String displayName;
  final List<String> roles;
  final List<AuthorityAssignmentRecord> authorities;
  final List<PermissionExceptionRecord> exceptions;
  final List<AccessDecisionRecord> decisions;

  factory EffectiveAccessRecord.fromJson(dynamic value) {
    final json = _json(value);
    return EffectiveAccessRecord(
      userId: '${json['userId'] ?? ''}',
      displayName: '${json['displayName'] ?? ''}',
      roles: _strings(json['roles']),
      authorities:
          (json['authorities'] is List ? json['authorities'] as List : const [])
              .map(AuthorityAssignmentRecord.fromJson)
              .toList(),
      exceptions:
          (json['exceptions'] is List ? json['exceptions'] as List : const [])
              .map(PermissionExceptionRecord.fromJson)
              .toList(),
      decisions:
          (json['decisions'] is List ? json['decisions'] as List : const [])
              .map(AccessDecisionRecord.fromJson)
              .toList(),
    );
  }
}

Map<String, dynamic> _json(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<String> _strings(dynamic value) => value is List
    ? value.map((item) => '$item').where((item) => item.isNotEmpty).toList()
    : const [];
