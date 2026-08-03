class SchoolReadiness {
  const SchoolReadiness({
    required this.ready,
    required this.currentBlockingStep,
    required this.items,
  });

  final bool ready;
  final String? currentBlockingStep;
  final List<SchoolReadinessItem> items;

  factory SchoolReadiness.fromJson(Map<String, dynamic> json) {
    return SchoolReadiness(
      ready: json['ready'] == true,
      currentBlockingStep: json['currentBlockingStep']?.toString(),
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                SchoolReadinessItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  static const readySchool = SchoolReadiness(
    ready: true,
    currentBlockingStep: null,
    items: [],
  );
}

class SchoolReadinessItem {
  const SchoolReadinessItem({
    required this.key,
    required this.label,
    required this.status,
    required this.required,
    required this.detail,
    required this.missingGradeLevels,
  });

  final String key;
  final String label;
  final String status;
  final bool required;
  final String detail;
  final List<String> missingGradeLevels;

  bool get complete => status == 'COMPLETED';
  bool get blocked => status == 'BLOCKED';

  factory SchoolReadinessItem.fromJson(Map<String, dynamic> json) {
    return SchoolReadinessItem(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'INCOMPLETE',
      required: json['required'] != false,
      detail: json['detail']?.toString() ?? '',
      missingGradeLevels: (json['missingGradeLevels'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
