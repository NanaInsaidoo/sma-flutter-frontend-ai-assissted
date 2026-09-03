import 'package:flutter/material.dart';
import '../domain/guardian_directory.dart';

/// The full directory is searchable in memory; only visible rows build widgets.
class GuardianDirectorySearch extends StatefulWidget {
  const GuardianDirectorySearch({
    super.key,
    required this.directory,
    required this.onSelected,
  });
  final SchoolGuardianDirectory directory;
  final ValueChanged<GuardianDirectoryHousehold> onSelected;
  @override
  State<GuardianDirectorySearch> createState() =>
      _GuardianDirectorySearchState();
}

class _GuardianDirectorySearchState extends State<GuardianDirectorySearch> {
  String _query = '';
  late List<GuardianDirectoryHousehold> _visible;
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _visible = widget.directory.households;
  }

  @override
  void didUpdateWidget(covariant GuardianDirectorySearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.directory != widget.directory) _filter(_query);
  }

  void _filter(String value) {
    _query = value;
    _visible = widget.directory.households
        .where((h) => h.matches(value))
        .toList();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const Key('guardian-directory-search'),
        decoration: const InputDecoration(
          labelText: 'Search all guardians',
          hintText: 'Name, phone number, guardian or household ID',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) => setState(() => _filter(value)),
      ),
      const SizedBox(height: 12),
      Text(
        '${widget.directory.guardians.length} guardians available · ${_visible.length} matching households',
      ),
      const SizedBox(height: 12),
      Expanded(
        child: _visible.isEmpty
            ? const Center(
                child: Text(
                  'No matching guardian or household. Try another name, phone number or ID.',
                ),
              )
            : ListView.builder(
                key: const Key('guardian-directory-list'),
                controller: _scroll,
                itemCount: _visible.length,
                itemBuilder: (context, index) {
                  final household = _visible[index];
                  final contact = household.contactFor(_query);
                  return Card(
                    key: ValueKey('directory-${household.key}'),
                    child: ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: Text(household.name),
                      subtitle: Text(
                        [
                          '${contact.name}${contact.phone.isEmpty ? '' : ' · ${contact.phone}'}',
                          household.id == null
                              ? 'No household linked · view guardian'
                              : 'Household #${household.id} · ${household.studentCount} student(s)',
                          if (contact.id != household.primary.id)
                            'Primary guardian: ${household.primary.name}',
                        ].join('\n'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onSelected(household),
                    ),
                  );
                },
              ),
      ),
    ],
  );
}
