String normalizeReportStatus(String? value) {
  return switch ((value ?? '').trim().toUpperCase().replaceAll(' ', '_')) {
    'PUBLISHED' => 'Published',
    'GENERATED' => 'Generated',
    _ => 'Not Generated',
  };
}

String summarizeReportReadiness(List<String> blockers) {
  if (blockers.isEmpty) return 'Ready';
  final additional = blockers.length - 1;
  return additional == 0
      ? blockers.first
      : '${blockers.first} · +$additional more';
}
