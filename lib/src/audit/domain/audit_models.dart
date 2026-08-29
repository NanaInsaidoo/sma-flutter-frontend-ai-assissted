class AuditScopeOption {
  const AuditScopeOption({
    required this.value,
    required this.label,
    required this.type,
  });

  final String value;
  final String label;
  final String type;

  factory AuditScopeOption.fromJson(Map<String, dynamic> json) =>
      AuditScopeOption(
        value: _string(json['value']),
        label: _string(json['label'], fallback: 'Audit scope'),
        type: _string(json['type']),
      );
}

class AuditLogPage {
  const AuditLogPage({
    required this.logs,
    required this.totalElements,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
  });

  final List<AuditLogRecord> logs;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final int pageSize;

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    final values = json['logs'];
    final logs = values is List
        ? values
              .whereType<Map>()
              .map((value) => AuditLogRecord.fromJson(value.cast()))
              .toList()
        : <AuditLogRecord>[];
    return AuditLogPage(
      logs: logs,
      totalElements: _int(json['totalElements'], fallback: logs.length),
      totalPages: _int(json['totalPages'], fallback: logs.isEmpty ? 0 : 1),
      currentPage: _int(json['currentPage']),
      pageSize: _int(json['pageSize'], fallback: 20),
    );
  }
}

class AuditLogRecord {
  const AuditLogRecord({
    required this.id,
    required this.actionType,
    required this.description,
    required this.timestamp,
    required this.customSchoolId,
    required this.subjectUserId,
    required this.subjectUsername,
    required this.subjectDisplayName,
    required this.subjectRole,
    required this.performedByUserId,
    required this.performedByUsername,
    required this.performedByDisplayName,
    required this.ipAddress,
    required this.userAgent,
    required this.metadata,
  });

  final String id;
  final String actionType;
  final String description;
  final DateTime? timestamp;
  final String customSchoolId;
  final String subjectUserId;
  final String subjectUsername;
  final String subjectDisplayName;
  final String subjectRole;
  final String performedByUserId;
  final String performedByUsername;
  final String performedByDisplayName;
  final String ipAddress;
  final String userAgent;
  final String? metadata;

  String get subjectName {
    if (subjectDisplayName.trim().isNotEmpty) return subjectDisplayName.trim();
    if (subjectUsername.trim().isNotEmpty) return subjectUsername.trim();
    return 'Deleted account';
  }

  String get actorName {
    if (performedByDisplayName.trim().isNotEmpty) {
      return performedByDisplayName.trim();
    }
    if (performedByUsername.trim().isNotEmpty) {
      return performedByUsername.trim();
    }
    return 'System';
  }

  factory AuditLogRecord.fromJson(Map<String, dynamic> json) => AuditLogRecord(
    id: _string(json['id']),
    actionType: _string(json['actionType'], fallback: 'UNKNOWN'),
    description: _string(json['description']),
    timestamp: DateTime.tryParse(_string(json['timestamp'])),
    customSchoolId: _string(json['customSchoolId']),
    subjectUserId: _string(json['subjectUserId']),
    subjectUsername: _string(json['subjectUsername']),
    subjectDisplayName: _string(json['subjectDisplayName']),
    subjectRole: _string(json['subjectRole']),
    performedByUserId: _string(json['performedByUserId']),
    performedByUsername: _string(json['performedByUsername']),
    performedByDisplayName: _string(json['performedByDisplayName']),
    ipAddress: _string(json['ipAddress']),
    userAgent: _string(json['userAgent']),
    metadata: json['metadata']?.toString(),
  );
}

class AuditStatistics {
  const AuditStatistics({
    required this.totalLogs,
    required this.createCount,
    required this.editCount,
    required this.accessChangeCount,
    required this.failedLoginCount,
  });

  final int totalLogs;
  final int createCount;
  final int editCount;
  final int accessChangeCount;
  final int failedLoginCount;

  factory AuditStatistics.fromJson(Map<String, dynamic> json) =>
      AuditStatistics(
        totalLogs: _int(json['totalLogs']),
        createCount: _int(json['createCount']),
        editCount: _int(json['editCount']),
        accessChangeCount: _int(json['accessChangeCount']),
        failedLoginCount: _int(json['failedLoginCount']),
      );
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _string(Object? value, {String fallback = ''}) {
  final result = value?.toString() ?? '';
  return result.trim().isEmpty ? fallback : result;
}
