class ApprovalInbox {
  const ApprovalInbox({
    required this.pendingMyApproval,
    required this.pendingMyRequests,
    required this.myApprovals,
    required this.myRequests,
  });

  final int pendingMyApproval;
  final int pendingMyRequests;
  final List<ApprovalItem> myApprovals;
  final List<ApprovalItem> myRequests;

  int get pendingTotal => pendingMyRequests + pendingMyApproval;

  String get navigationLabel =>
      'Requests ($pendingMyRequests) & Approvals ($pendingMyApproval)';

  factory ApprovalInbox.fromJson(Map<String, dynamic> json) {
    List<ApprovalItem> items(String key) => (json[key] as List? ?? const [])
        .whereType<Map>()
        .map((value) => ApprovalItem.fromJson(Map<String, dynamic>.from(value)))
        .toList();
    return ApprovalInbox(
      pendingMyApproval: (json['pendingMyApproval'] as num?)?.toInt() ?? 0,
      pendingMyRequests: (json['pendingMyRequests'] as num?)?.toInt() ?? 0,
      myApprovals: items('myApprovals'),
      myRequests: items('myRequests'),
    );
  }
}

class ApprovalItem {
  const ApprovalItem({
    required this.key,
    required this.type,
    required this.entityId,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.status,
    this.amount,
    required this.requesterName,
    required this.approverName,
    required this.reason,
    this.requesterNote = '',
    this.submittedAt,
    this.updatedAt,
    this.createdAt,
    this.decidedAt,
    this.academicPeriod = '',
    this.version,
    this.stateToken = '',
    this.detailSections = const [],
    required this.canApprove,
    required this.canReject,
    required this.canWithdraw,
    required this.sourcePage,
  });

  final String key;
  final String type;
  final int entityId;
  final String category;
  final String title;
  final String subtitle;
  final String status;
  final double? amount;
  final String requesterName;
  final String approverName;
  final String reason;
  final String requesterNote;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final DateTime? decidedAt;
  final String academicPeriod;
  final int? version;
  final String stateToken;
  final List<ApprovalDetailSection> detailSections;
  final bool canApprove;
  final bool canReject;
  final bool canWithdraw;
  final String sourcePage;

  bool get pending => status == 'PENDING_APPROVAL';

  factory ApprovalItem.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    DateTime? date(String key) {
      final value = json[key];
      if (value is String) return DateTime.tryParse(value.trim());
      if (value is List && value.length >= 3) {
        int part(int index, [int fallback = 0]) => index < value.length
            ? (value[index] as num?)?.toInt() ?? fallback
            : fallback;
        final nanoseconds = part(6);
        return DateTime(
          part(0),
          part(1),
          part(2),
          part(3),
          part(4),
          part(5),
          nanoseconds ~/ 1000000,
          (nanoseconds % 1000000) ~/ 1000,
        );
      }
      return null;
    }

    return ApprovalItem(
      key: text('key'),
      type: text('type'),
      entityId: (json['entityId'] as num?)?.toInt() ?? 0,
      category: text('category'),
      title: text('title'),
      subtitle: text('subtitle'),
      status: text('status').toUpperCase(),
      amount: (json['amount'] as num?)?.toDouble(),
      requesterName: text('requesterName'),
      approverName: text('approverName'),
      reason: text('reason'),
      requesterNote: text('requesterNote'),
      submittedAt: date('submittedAt'),
      updatedAt: date('updatedAt'),
      createdAt: date('createdAt'),
      decidedAt: date('decidedAt'),
      academicPeriod: text('academicPeriod'),
      version: (json['version'] as num?)?.toInt(),
      stateToken: text('stateToken'),
      detailSections: (json['detailSections'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) => ApprovalDetailSection.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList(),
      canApprove: json['canApprove'] == true,
      canReject: json['canReject'] == true,
      canWithdraw: json['canWithdraw'] == true,
      sourcePage: text('sourcePage'),
    );
  }
}

class ApprovalDetailSection {
  const ApprovalDetailSection({
    required this.title,
    required this.description,
    required this.entries,
  });

  final String title;
  final String description;
  final List<ApprovalDetailEntry> entries;

  factory ApprovalDetailSection.fromJson(
    Map<String, dynamic> json,
  ) => ApprovalDetailSection(
    title: json['title']?.toString().trim() ?? '',
    description: json['description']?.toString().trim() ?? '',
    entries: (json['entries'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              ApprovalDetailEntry.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
  );
}

class ApprovalDetailEntry {
  const ApprovalDetailEntry({
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final String title;
  final String subtitle;
  final List<ApprovalDetailField> fields;

  factory ApprovalDetailEntry.fromJson(
    Map<String, dynamic> json,
  ) => ApprovalDetailEntry(
    title: json['title']?.toString().trim() ?? '',
    subtitle: json['subtitle']?.toString().trim() ?? '',
    fields: (json['fields'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              ApprovalDetailField.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(),
  );
}

class ApprovalDetailField {
  const ApprovalDetailField({
    required this.label,
    required this.value,
    required this.emphasized,
  });

  final String label;
  final String value;
  final bool emphasized;

  factory ApprovalDetailField.fromJson(Map<String, dynamic> json) =>
      ApprovalDetailField(
        label: json['label']?.toString().trim() ?? '',
        value: json['value']?.toString().trim() ?? '',
        emphasized: json['emphasized'] == true,
      );
}
