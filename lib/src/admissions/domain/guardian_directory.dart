/// List-only data. Full guardian profiles are deliberately kept out of this model.
class GuardianDirectoryEntry {
  GuardianDirectoryEntry.fromJson(Map<String, dynamic> json)
    : id = '${json['customGuardianId'] ?? ''}',
      name = [
        json['firstName'],
        json['lastName'],
      ].where((part) => part != null && '$part'.trim().isNotEmpty).join(' '),
      householdId = (json['householdId'] as num?)?.toInt(),
      householdName = '${json['householdName'] ?? ''}',
      isPrimary = json['isPrimary'] == true,
      status = '${json['status'] ?? 'DRAFT'}',
      createdAt = '${json['createdAt'] ?? ''}',
      email = '${json['email'] ?? ''}',
      phones = List.unmodifiable(
        (json['phoneNumbers'] as List? ?? []).map((p) => '$p'),
      );

  final String id, name, householdName, status, createdAt, email;
  final int? householdId;
  final bool isPrimary;
  final List<String> phones;
  String get phone => phones.isEmpty ? '' : phones.first;

  bool matches(String query) {
    final text = query.trim().toLowerCase();
    if (name.toLowerCase().contains(text) || id.toLowerCase().contains(text)) {
      return true;
    }
    final phoneQuery = RegExp(r'^[+\d\s().-]+$').hasMatch(text)
        ? text.replaceAll(RegExp(r'\D'), '')
        : '';
    return phones.any(
      (phone) =>
          phone.toLowerCase().contains(text) ||
          (phoneQuery.isNotEmpty &&
              phone.replaceAll(RegExp(r'\D'), '').contains(phoneQuery)),
    );
  }
}

class GuardianDirectoryHousehold {
  GuardianDirectoryHousehold(this.guardians, this.studentCount)
    : primary = guardians.firstWhere(
        (g) => g.isPrimary,
        orElse: () => guardians.first,
      );

  final List<GuardianDirectoryEntry> guardians;
  final int studentCount;
  final GuardianDirectoryEntry primary;
  int? get id => primary.householdId;
  String get key => id == null ? 'guardian-${primary.id}' : 'household-$id';
  String get name => primary.householdName.trim().isNotEmpty
      ? primary.householdName
      : id == null
      ? primary.name
      : '${primary.name} Household';
  int get pendingCount => guardians
      .where((g) => g.status.contains('PENDING') || g.status.contains('REVIEW'))
      .length;
  bool get incomplete => guardians.any(
    (g) => g.status.contains('DRAFT') || g.status.contains('INCOMPLETE'),
  );

  bool matches(String query) =>
      query.trim().isEmpty ||
      name.toLowerCase().contains(query.trim().toLowerCase()) ||
      (id?.toString().contains(query.trim()) ?? false) ||
      guardians.any((guardian) => guardian.matches(query));

  GuardianDirectoryEntry contactFor(String query) => query.trim().isEmpty
      ? primary
      : guardians.firstWhere((g) => g.matches(query), orElse: () => primary);
}

class SchoolGuardianDirectory {
  SchoolGuardianDirectory.fromJson(Map<String, dynamic> json) {
    guardians = List.unmodifiable(
      (json['guardians'] as List).map(
        (row) => GuardianDirectoryEntry.fromJson(
          Map<String, dynamic>.from(row as Map),
        ),
      ),
    );
    final counts = Map<String, dynamic>.from(json['studentCounts'] as Map);
    final grouped = <String, List<GuardianDirectoryEntry>>{};
    for (final guardian in guardians) {
      final key = guardian.householdId == null
          ? 'guardian-${guardian.id}'
          : 'household-${guardian.householdId}';
      grouped.putIfAbsent(key, () => []).add(guardian);
    }
    households = List.unmodifiable(
      grouped.values
          .map(
            (members) => GuardianDirectoryHousehold(
              List.unmodifiable(members),
              (counts['${members.first.householdId}'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList()
        ..sort((a, b) {
          final nameOrder = a.name.toLowerCase().compareTo(
            b.name.toLowerCase(),
          );
          return nameOrder == 0 ? a.key.compareTo(b.key) : nameOrder;
        }),
    );
  }

  late final List<GuardianDirectoryEntry> guardians;
  late final List<GuardianDirectoryHousehold> households;
}
