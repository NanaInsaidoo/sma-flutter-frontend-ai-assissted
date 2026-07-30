DateTime? _incidentDateTime(dynamic value) {
  if (value is List && value.length >= 3) {
    final parts = value.map((item) => (item as num?)?.toInt() ?? 0).toList();
    return DateTime(
      parts[0],
      parts[1],
      parts[2],
      parts.length > 3 ? parts[3] : 0,
      parts.length > 4 ? parts[4] : 0,
      parts.length > 5 ? parts[5] : 0,
      parts.length > 6 ? parts[6] ~/ 1000000 : 0,
    );
  }
  return DateTime.tryParse('${value ?? ''}');
}

class IncidentLookup {
  const IncidentLookup({required this.id, required this.name});
  final int id;
  final String name;

  factory IncidentLookup.fromJson(Map<String, dynamic> json) => IncidentLookup(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: '${json['name'] ?? ''}',
  );
}

class IncidentMention {
  const IncidentMention({
    required this.id,
    required this.name,
    required this.personType,
    this.subtitle = '',
  });

  final String id;
  final String name;
  final String personType;
  final String subtitle;

  bool get isStudent => personType == 'STUDENT';
}

class IncidentPerson {
  const IncidentPerson({
    this.involvementId,
    required this.personId,
    required this.personType,
    required this.name,
    this.subtitle = '',
    this.roleId,
    this.roleName = '',
    this.avatarColor,
  });
  final int? involvementId;
  final String personId;
  final String personType;
  final String name;
  final String subtitle;
  final int? roleId;
  final String roleName;
  final String? avatarColor;

  factory IncidentPerson.fromJson(Map<String, dynamic> json) => IncidentPerson(
    involvementId: (json['involvementId'] as num?)?.toInt(),
    personId: '${json['personId'] ?? ''}',
    personType: '${json['personType'] ?? 'EXTERNAL'}',
    name: '${json['name'] ?? ''}',
    subtitle: '${json['subtitle'] ?? ''}',
    roleId: (json['roleId'] as num?)?.toInt(),
    roleName: '${json['roleName'] ?? ''}',
    avatarColor: json['avatarColor'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'personId': personId,
    'personType': personType,
    'name': name,
    'subtitle': subtitle,
    if (roleId != null) 'roleId': roleId,
    'roleName': roleName,
    if (avatarColor != null) 'avatarColor': avatarColor,
  };
}

class IncidentAction {
  const IncidentAction({
    this.actionId,
    this.actionTypeId,
    required this.actionTypeName,
    this.description = '',
    this.takenBy = '',
    this.takenAt,
    this.updatedBy = '',
    this.updatedAt,
  });
  final int? actionId;
  final int? actionTypeId;
  final String actionTypeName;
  final String description;
  final String takenBy;
  final DateTime? takenAt;
  final String updatedBy;
  final DateTime? updatedAt;

  factory IncidentAction.fromJson(Map<String, dynamic> json) => IncidentAction(
    actionId: (json['actionId'] as num?)?.toInt(),
    actionTypeId: (json['actionTypeId'] as num?)?.toInt(),
    actionTypeName: '${json['actionTypeName'] ?? ''}',
    description: '${json['description'] ?? ''}',
    takenBy: '${json['takenBy'] ?? ''}',
    takenAt: _incidentDateTime(json['takenAt']),
    updatedBy: '${json['updatedBy'] ?? ''}',
    updatedAt: _incidentDateTime(json['updatedAt']),
  );
}

class IncidentUpdate {
  const IncidentUpdate({
    this.updateId = '',
    required this.note,
    this.updatedBy = '',
    this.type = 'INTERNAL_NOTE',
    this.updateDateTime,
    this.attachmentUrl,
    this.parentUpdateId = '',
  });
  final String updateId;
  final String note;
  final String updatedBy;
  final String type;
  final DateTime? updateDateTime;
  final String? attachmentUrl;
  final String parentUpdateId;

  factory IncidentUpdate.fromJson(Map<String, dynamic> json) => IncidentUpdate(
    updateId: '${json['updateId'] ?? ''}',
    note: '${json['note'] ?? ''}',
    updatedBy: '${json['updatedBy'] ?? ''}',
    type: '${json['type'] ?? 'INTERNAL_NOTE'}',
    updateDateTime: _incidentDateTime(json['updateDateTime']),
    attachmentUrl: json['attachmentUrl'] as String?,
    parentUpdateId: '${json['parentUpdateId'] ?? ''}',
  );
}

class IncidentRecord {
  const IncidentRecord({
    required this.incidentId,
    required this.customSchoolId,
    required this.incidentType,
    required this.incidentTypeName,
    required this.severity,
    required this.title,
    required this.description,
    required this.incidentDate,
    required this.location,
    required this.status,
    this.reportedByName = '',
    this.reportedByStaffId = '',
    this.people = const [],
    this.actions = const [],
    this.updates = const [],
    this.parentNotified = false,
    this.classTeacherNotified = false,
    this.counselorNotified = false,
    this.headmasterNotified = false,
    this.followUpRequired = false,
    this.followUpDate,
    this.followUpNotes = '',
    this.escalatedTo = '',
  });
  final String incidentId;
  final String customSchoolId;
  final String incidentType;
  final String incidentTypeName;
  final String severity;
  final String title;
  final String description;
  final DateTime incidentDate;
  final String location;
  final String status;
  final String reportedByName;
  final String reportedByStaffId;
  final List<IncidentPerson> people;
  final List<IncidentAction> actions;
  final List<IncidentUpdate> updates;
  final bool parentNotified;
  final bool classTeacherNotified;
  final bool counselorNotified;
  final bool headmasterNotified;
  final bool followUpRequired;
  final DateTime? followUpDate;
  final String followUpNotes;
  final String escalatedTo;

  IncidentPerson? get primaryStudent {
    for (final person in people) {
      if (person.personType == 'STUDENT') return person;
    }
    return null;
  }

  Map<String, dynamic> editableJson({
    String? title,
    String? description,
    String? location,
    String? severity,
    bool? parentNotified,
    bool? classTeacherNotified,
    bool? counselorNotified,
    bool? headmasterNotified,
    bool? followUpRequired,
    DateTime? followUpDate,
    String? followUpNotes,
  }) => {
    'title': title ?? this.title,
    'description': description ?? this.description,
    'location': location ?? this.location,
    'severity': severity ?? this.severity,
    'parentNotified': parentNotified ?? this.parentNotified,
    'classTeacherNotified': classTeacherNotified ?? this.classTeacherNotified,
    'counselorNotified': counselorNotified ?? this.counselorNotified,
    'headmasterNotified': headmasterNotified ?? this.headmasterNotified,
    'followUpRequired': followUpRequired ?? this.followUpRequired,
    if (followUpRequired ?? this.followUpRequired)
      'followUpDate': _dateOnly(
        followUpDate ??
            this.followUpDate ??
            DateTime.now().add(const Duration(days: 7)),
      ),
    if (followUpRequired ?? this.followUpRequired)
      'followUpNotes': followUpNotes ?? this.followUpNotes,
  };

  factory IncidentRecord.fromJson(Map<String, dynamic> json) {
    final reporter = json['reportedBy'] is Map
        ? (json['reportedBy'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final date = '${json['incidentDate'] ?? ''}';
    final time = '${json['incidentTime'] ?? '00:00'}';
    return IncidentRecord(
      incidentId: '${json['incidentId'] ?? ''}',
      customSchoolId: '${json['customSchoolId'] ?? ''}',
      incidentType: '${json['incidentType'] ?? ''}',
      incidentTypeName: '${json['incidentTypeName'] ?? ''}',
      severity: '${json['severity'] ?? 'LOW'}',
      title: '${json['title'] ?? ''}',
      description: '${json['description'] ?? ''}',
      incidentDate:
          DateTime.tryParse('${date}T$time') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      location: '${json['location'] ?? ''}',
      status: '${json['incidentStatus'] ?? json['status'] ?? 'REPORTED'}',
      reportedByName: '${reporter['name'] ?? ''}',
      reportedByStaffId: '${reporter['staffId'] ?? ''}',
      people: _maps(
        json['peopleInvolved'],
      ).map(IncidentPerson.fromJson).toList(),
      actions: _maps(
        json['actionRecords'],
      ).map(IncidentAction.fromJson).toList(),
      updates: _maps(json['updates']).map(IncidentUpdate.fromJson).toList(),
      parentNotified: json['parentNotified'] == true,
      classTeacherNotified: json['classTeacherNotified'] == true,
      counselorNotified: json['counselorNotified'] == true,
      headmasterNotified: json['headmasterNotified'] == true,
      followUpRequired: json['followUpRequired'] == true,
      followUpDate: _incidentDateTime(json['followUpDate']),
      followUpNotes: '${json['followUpNotes'] ?? ''}',
      escalatedTo: '${json['escalatedTo'] ?? ''}',
    );
  }
}

class IncidentPage {
  const IncidentPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
  });
  final List<IncidentRecord> items;
  final int page;
  final int totalPages;
  final int totalElements;

  factory IncidentPage.fromJson(Map<String, dynamic> json) => IncidentPage(
    items: _maps(json['content']).map(IncidentRecord.fromJson).toList(),
    page: (json['number'] as num?)?.toInt() ?? 0,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
  );
}

class IncidentDashboardStats {
  const IncidentDashboardStats({
    this.total = 0,
    this.criticalOrHigh = 0,
    this.openOrPending = 0,
    this.resolved = 0,
    this.studentsInvolved = 0,
    this.totalChange = '—',
    this.typeBreakdown = const [],
    this.severityBreakdown = const [],
    this.weeklyTrend = const [],
    this.recentActivity = const [],
  });
  final int total;
  final int criticalOrHigh;
  final int openOrPending;
  final int resolved;
  final int studentsInvolved;
  final String totalChange;
  final List<IncidentBreakdown> typeBreakdown;
  final List<IncidentBreakdown> severityBreakdown;
  final List<IncidentTrend> weeklyTrend;
  final List<IncidentActivity> recentActivity;

  factory IncidentDashboardStats.fromJson(Map<String, dynamic> json) {
    final summary = _map(json['summary']);
    final metrics = _map(json['metrics']);
    final trends = _map(json['trends']);
    return IncidentDashboardStats(
      total: (summary['total'] as num?)?.toInt() ?? 0,
      criticalOrHigh: (metrics['criticalOrHigh'] as num?)?.toInt() ?? 0,
      openOrPending: (metrics['openOrPending'] as num?)?.toInt() ?? 0,
      resolved: (metrics['resolved'] as num?)?.toInt() ?? 0,
      studentsInvolved: (metrics['studentsInvolved'] as num?)?.toInt() ?? 0,
      totalChange: '${trends['totalChange'] ?? '—'}',
      typeBreakdown: _maps(
        json['typeBreakdown'],
      ).map(IncidentBreakdown.fromJson).toList(),
      severityBreakdown: _maps(
        json['severityBreakdown'],
      ).map(IncidentBreakdown.fromJson).toList(),
      weeklyTrend: _maps(
        json['weeklyTrend'],
      ).map(IncidentTrend.fromJson).toList(),
      recentActivity: _maps(
        json['recentActivity'],
      ).map(IncidentActivity.fromJson).toList(),
    );
  }
}

class IncidentBreakdown {
  const IncidentBreakdown(this.key, this.count, this.percentage);
  final String key;
  final int count;
  final double percentage;
  factory IncidentBreakdown.fromJson(Map<String, dynamic> json) =>
      IncidentBreakdown(
        '${json['key'] ?? ''}',
        (json['count'] as num?)?.toInt() ?? 0,
        (json['percentage'] as num?)?.toDouble() ?? 0,
      );
}

class IncidentTrend {
  const IncidentTrend(this.label, this.count);
  final String label;
  final int count;
  factory IncidentTrend.fromJson(Map<String, dynamic> json) => IncidentTrend(
    '${json['label'] ?? ''}',
    (json['count'] as num?)?.toInt() ?? 0,
  );
}

class IncidentActivity {
  const IncidentActivity(
    this.incidentId,
    this.description,
    this.performedBy,
    this.occurredAt,
  );
  final String incidentId;
  final String description;
  final String performedBy;
  final DateTime? occurredAt;
  factory IncidentActivity.fromJson(Map<String, dynamic> json) =>
      IncidentActivity(
        '${json['incidentId'] ?? ''}',
        '${json['description'] ?? ''}',
        '${json['performedBy'] ?? ''}',
        _incidentDateTime(json['occurredAt']),
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
    : const [];

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
