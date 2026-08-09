String normalizeReportStatus(String? value) {
  final canonical = (value ?? '')
      .trim()
      .toUpperCase()
      .replaceAll('·', '')
      .replaceAll(' ', '_')
      .replaceAll(RegExp('_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return switch (canonical) {
    'PUBLISHED' => 'Published',
    'PUBLISHED_UPDATE_REQUIRED' => 'Published · update required',
    'UPDATE_REQUIRED' => 'Update required',
    'GENERATED' => 'Generated',
    _ => 'Not Generated',
  };
}

bool canDistributeReport(String? status) =>
    normalizeReportStatus(status) == 'Published';

bool reportHasPublishedVersion(String? status) =>
    switch (normalizeReportStatus(status)) {
      'Published' || 'Published · update required' => true,
      _ => false,
    };

bool reportHasGeneratedVersion(String? status) =>
    switch (normalizeReportStatus(status)) {
      'Generated' ||
      'Update required' ||
      'Published' ||
      'Published · update required' => true,
      _ => false,
    };

bool reportNeedsUpdate(String? status) {
  final normalized = normalizeReportStatus(status);
  return normalized == 'Update required' ||
      normalized == 'Published · update required';
}

String summarizeReportReadiness(List<String> blockers) {
  if (blockers.isEmpty) return 'Ready';
  final additional = blockers.length - 1;
  return additional == 0
      ? blockers.first
      : '${blockers.first} · +$additional more';
}
