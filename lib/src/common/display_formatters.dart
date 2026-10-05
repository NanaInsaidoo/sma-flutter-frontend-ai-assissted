String displayRoleName(String? value, {String fallback = 'Staff'}) {
  final clean = value?.trim() ?? '';
  if (clean.isEmpty) return fallback;

  final normalized = clean
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (const {
    'teacher',
    'class teacher',
    'subject teacher',
  }.contains(normalized)) {
    return 'Teacher';
  }
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}
