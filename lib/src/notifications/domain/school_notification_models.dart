class SchoolNotificationInbox {
  const SchoolNotificationInbox({
    required this.unreadCount,
    required this.items,
  });

  final int unreadCount;
  final List<SchoolNotificationItem> items;

  factory SchoolNotificationInbox.fromJson(Map<String, dynamic> json) {
    final rawItems = json['notifications'] ?? json['items'];
    return SchoolNotificationInbox(
      unreadCount: _int(json['unreadCount']),
      items: (rawItems as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SchoolNotificationItem.fromJson)
          .toList(),
    );
  }
}

class SchoolNotificationItem {
  const SchoolNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.sourceType,
    required this.sourceId,
    required this.createdAt,
    required this.read,
  });

  final int id;
  final String type;
  final String title;
  final String message;
  final String sourceType;
  final int sourceId;
  final DateTime? createdAt;
  final bool read;

  factory SchoolNotificationItem.fromJson(Map<String, dynamic> json) {
    return SchoolNotificationItem(
      id: _int(json['id']),
      type: '${json['type'] ?? ''}',
      title: '${json['title'] ?? ''}',
      message: '${json['message'] ?? ''}',
      sourceType: '${json['sourceType'] ?? ''}',
      sourceId: _int(json['sourceId']),
      createdAt: _dateTime(json['createdAt']),
      read: json['read'] == true,
    );
  }
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

DateTime? _dateTime(dynamic value) {
  if (value is List && value.length >= 3) {
    final parts = value.map(_int).toList();
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
