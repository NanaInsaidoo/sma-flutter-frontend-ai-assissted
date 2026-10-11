class ManagementReportSection {
  const ManagementReportSection({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<Object?>> rows;

  factory ManagementReportSection.fromJson(Map<String, dynamic> json) =>
      ManagementReportSection(
        title: '${json['title'] ?? ''}',
        headers: (json['headers'] as List? ?? []).map((e) => '$e').toList(),
        rows: (json['rows'] as List? ?? [])
            .whereType<List>()
            .map((row) => row.cast<Object?>())
            .toList(),
      );
}

class ManagementReport {
  const ManagementReport({
    required this.id,
    required this.termId,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.academicYear,
    required this.term,
    required this.metrics,
    required this.sections,
    required this.notes,
    this.closedAt,
    this.generatedAt,
  });

  final String id;
  final int termId;
  final String type;
  final String title;
  final String description;
  final String category;
  final String status;
  final String academicYear;
  final String term;
  final Map<String, Object?> metrics;
  final List<ManagementReportSection> sections;
  final List<String> notes;
  final DateTime? closedAt;
  final DateTime? generatedAt;

  factory ManagementReport.fromJson(Map<String, dynamic> json) =>
      ManagementReport(
        id: '${json['id'] ?? ''}',
        termId: int.tryParse('${json['termId']}') ?? 0,
        type: '${json['type'] ?? 'STANDARD'}',
        title: '${json['title'] ?? 'Report'}',
        description: '${json['description'] ?? ''}',
        category: '${json['category'] ?? 'TERM'}',
        status: '${json['status'] ?? 'LIVE'}',
        academicYear: '${json['academicYear'] ?? ''}',
        term: '${json['term'] ?? ''}',
        metrics: json['metrics'] is Map
            ? Map<String, Object?>.from(json['metrics'] as Map)
            : const {},
        sections: (json['sections'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => ManagementReportSection.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList(),
        notes: (json['notes'] as List? ?? []).map((e) => '$e').toList(),
        closedAt: DateTime.tryParse('${json['closedAt'] ?? ''}'),
        generatedAt: DateTime.tryParse('${json['generatedAt'] ?? ''}'),
      );
}

abstract interface class ManagementReportRepository {
  Future<List<ManagementReport>> list(String schoolId);
  Future<List<int>> downloadPdf(String schoolId, int termId, String type);
}
