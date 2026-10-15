class DataExportDataset {
  const DataExportDataset({
    required this.code,
    required this.label,
    required this.description,
  });
  final String code;
  final String label;
  final String description;

  factory DataExportDataset.fromJson(Map<String, dynamic> json) =>
      DataExportDataset(
        code: '${json['code'] ?? ''}',
        label: '${json['label'] ?? ''}',
        description: '${json['description'] ?? ''}',
      );
}

class DataExportTerm {
  const DataExportTerm({
    required this.id,
    required this.academicYear,
    required this.term,
    required this.status,
    required this.current,
    this.startDate,
    this.endDate,
  });

  final int id;
  final String academicYear;
  final String term;
  final String status;
  final bool current;
  final DateTime? startDate;
  final DateTime? endDate;

  String get label => '$term · $academicYear';

  factory DataExportTerm.fromJson(Map<String, dynamic> json) => DataExportTerm(
    id: int.tryParse('${json['id']}') ?? 0,
    academicYear: '${json['academicYear'] ?? ''}',
    term: '${json['term'] ?? 'Term'}',
    status: '${json['status'] ?? ''}',
    current: json['current'] == true,
    startDate: DateTime.tryParse('${json['startDate'] ?? ''}'),
    endDate: DateTime.tryParse('${json['endDate'] ?? ''}'),
  );
}

class DataExportOptionItem {
  const DataExportOptionItem({required this.id, required this.name});
  final int id;
  final String name;

  factory DataExportOptionItem.fromJson(Map<String, dynamic> json) =>
      DataExportOptionItem(
        id: int.tryParse('${json['id']}') ?? 0,
        name: '${json['name'] ?? json['method'] ?? json['alias'] ?? ''}',
      );
}

class DataExportOptions {
  const DataExportOptions({
    required this.datasets,
    required this.terms,
    required this.classes,
    required this.paymentMethods,
    required this.statusOptions,
    required this.canIncludeIdentities,
    required this.maximumRows,
  });

  final List<DataExportDataset> datasets;
  final List<DataExportTerm> terms;
  final List<DataExportOptionItem> classes;
  final List<DataExportOptionItem> paymentMethods;
  final List<String> statusOptions;
  final bool canIncludeIdentities;
  final int maximumRows;

  factory DataExportOptions.fromJson(
    Map<String, dynamic> json,
  ) => DataExportOptions(
    datasets: (json['datasets'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) => DataExportDataset.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    terms: (json['terms'] as List? ?? [])
        .whereType<Map>()
        .map((item) => DataExportTerm.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    classes: (json['classes'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              DataExportOptionItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    paymentMethods: (json['paymentMethods'] as List? ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              DataExportOptionItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
    statusOptions: (json['statusOptions'] as List? ?? [])
        .map((item) => '$item')
        .toList(),
    canIncludeIdentities: json['canIncludeIdentities'] == true,
    maximumRows: int.tryParse('${json['maximumRows']}') ?? 250000,
  );
}

class DataExportRequest {
  const DataExportRequest({
    required this.datasets,
    required this.termIds,
    required this.classIds,
    required this.statuses,
    required this.paymentMethodIds,
    required this.allAvailable,
    required this.anonymized,
    required this.includeAnalysisColumns,
    required this.includeDataDictionary,
    this.startDate,
    this.endDate,
    this.minimumAmount,
    this.maximumAmount,
  });

  final List<String> datasets;
  final List<int> termIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int> classIds;
  final List<String> statuses;
  final List<int> paymentMethodIds;
  final double? minimumAmount;
  final double? maximumAmount;
  final bool allAvailable;
  final bool anonymized;
  final bool includeAnalysisColumns;
  final bool includeDataDictionary;

  Map<String, dynamic> toJson() => {
    'datasets': datasets,
    'termIds': termIds,
    'startDate': _date(startDate),
    'endDate': _date(endDate),
    'classIds': classIds,
    'statuses': statuses,
    'paymentMethodIds': paymentMethodIds,
    'minimumAmount': minimumAmount,
    'maximumAmount': maximumAmount,
    'allAvailable': allAvailable,
    'anonymized': anonymized,
    'includeAnalysisColumns': includeAnalysisColumns,
    'includeDataDictionary': includeDataDictionary,
  };

  static String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class DataExportPreview {
  const DataExportPreview({
    required this.totalRecords,
    required this.files,
    required this.overLimit,
    required this.period,
  });
  final int totalRecords;
  final Map<String, int> files;
  final bool overLimit;
  final String period;

  factory DataExportPreview.fromJson(Map<String, dynamic> json) =>
      DataExportPreview(
        totalRecords: int.tryParse('${json['totalRecords']}') ?? 0,
        files: json['files'] is Map
            ? Map<String, dynamic>.from(
                json['files'] as Map,
              ).map((key, value) => MapEntry(key, int.tryParse('$value') ?? 0))
            : const {},
        overLimit: json['overLimit'] == true,
        period: '${json['period'] ?? ''}',
      );
}

class DataExportHistoryItem {
  const DataExportHistoryItem({
    required this.id,
    required this.fileName,
    required this.datasets,
    required this.rowCount,
    required this.anonymized,
    required this.generatedBy,
    this.generatedAt,
  });
  final int id;
  final String fileName;
  final List<String> datasets;
  final int rowCount;
  final bool anonymized;
  final String generatedBy;
  final DateTime? generatedAt;

  factory DataExportHistoryItem.fromJson(Map<String, dynamic> json) =>
      DataExportHistoryItem(
        id: int.tryParse('${json['id']}') ?? 0,
        fileName: '${json['fileName'] ?? 'analysis-data.zip'}',
        datasets: (json['datasets'] as List? ?? [])
            .map((item) => '$item')
            .toList(),
        rowCount: int.tryParse('${json['rowCount']}') ?? 0,
        anonymized: json['anonymized'] != false,
        generatedBy: '${json['generatedBy'] ?? 'School user'}',
        generatedAt: DateTime.tryParse('${json['generatedAt'] ?? ''}'),
      );
}

class DataExportDownload {
  const DataExportDownload({required this.fileName, required this.bytes});
  final String fileName;
  final List<int> bytes;
}

abstract interface class DataExportRepository {
  Future<DataExportOptions> dataExportOptions(String schoolId);
  Future<List<DataExportHistoryItem>> dataExportHistory(String schoolId);
  Future<DataExportPreview> previewDataExport(
    String schoolId,
    DataExportRequest request,
  );
  Future<DataExportDownload> createDataExport(
    String schoolId,
    DataExportRequest request,
  );
  Future<DataExportDownload> downloadDataExport(
    String schoolId,
    int exportId,
    String fileName,
  );
}
