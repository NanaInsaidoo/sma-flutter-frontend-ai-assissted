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

String? reportProgressionDecision(String? value) {
  final decision = value?.trim() ?? '';
  return decision.isEmpty || decision.toLowerCase() == 'pending review'
      ? null
      : decision;
}

String? classPublicationBlocker({
  required int missingProgression,
  required int missingResults,
}) {
  if (missingProgression > 0) {
    return 'Set progression for $missingProgression '
        'student${missingProgression == 1 ? '' : 's'} before publishing.';
  }
  if (missingResults > 0) {
    return 'Generate results for $missingResults '
        'student${missingResults == 1 ? '' : 's'} before publishing.';
  }
  return null;
}

bool reportStatusCanBePublished(
  String? status, {
  bool republishRequired = false,
  bool regenerationRequired = false,
}) {
  final normalized = normalizeReportStatus(status);
  return normalized == 'Generated' ||
      (normalized == 'Published · update required' &&
          republishRequired &&
          !regenerationRequired);
}

bool reportCorrectionCanRegenerate(String? status) => const {
  'APPROVED_REGENERATION_REQUIRED',
  'REGENERATION_FAILED',
}.contains(status);

bool reportCorrectionCanRepublish(String? status) => const {
  'REGENERATED_AWAITING_PUBLICATION',
  'PUBLICATION_FAILED',
}.contains(status);

String bulkPublishLabel({
  required int selectedCount,
  required int eligibleCount,
}) {
  if (selectedCount == 0) {
    return 'Publish Results ($eligibleCount)';
  }
  if (selectedCount == eligibleCount) {
    return 'Publish selected ($eligibleCount)';
  }
  return 'Publish eligible ($eligibleCount)';
}

String summarizeReportReadiness(List<String> blockers) {
  if (blockers.isEmpty) return 'Ready';
  final additional = blockers.length - 1;
  return additional == 0
      ? blockers.first
      : '${blockers.first} · +$additional more';
}
