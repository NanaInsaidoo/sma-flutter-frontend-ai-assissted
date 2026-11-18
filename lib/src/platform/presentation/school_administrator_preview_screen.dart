import 'package:flutter/material.dart';

import '../data/platform_repository.dart';
import '../domain/platform_models.dart';

class SchoolAdministratorPreviewScreen extends StatefulWidget {
  const SchoolAdministratorPreviewScreen({
    super.key,
    required this.repository,
    required this.onExit,
    required this.schoolBuilder,
  });

  final PlatformRepository repository;
  final VoidCallback onExit;
  final Widget Function(ManagedSchool school) schoolBuilder;

  @override
  State<SchoolAdministratorPreviewScreen> createState() =>
      _SchoolAdministratorPreviewScreenState();
}

class _SchoolAdministratorPreviewScreenState
    extends State<SchoolAdministratorPreviewScreen> {
  final _search = TextEditingController();
  late Future<ManagedSchoolPage> _schools = _loadSchools();
  ManagedSchool? _selectedSchool;
  int _page = 0;

  Future<ManagedSchoolPage> _loadSchools() => widget.repository.getSchools(
    searchTerm: _search.text.trim(),
    status: SchoolStatus.approved.apiValue,
    page: _page,
    size: 20,
  );

  void _refresh({int page = 0}) {
    setState(() {
      _page = page;
      _schools = _loadSchools();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final school = _selectedSchool;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    school == null
                        ? 'School admin preview'
                        : 'School admin preview · ${school.name} · ${school.code}',
                  ),
                  if (school != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedSchool = null),
                      child: const Text('Change school'),
                    ),
                  TextButton.icon(
                    onPressed: widget.onExit,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to platform'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: school != null
              ? widget.schoolBuilder(school)
              : Scaffold(
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select a school',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _search,
                              onSubmitted: (_) => _refresh(),
                              decoration: InputDecoration(
                                labelText: 'Search approved schools',
                                suffixIcon: IconButton(
                                  onPressed: _refresh,
                                  tooltip: 'Search schools',
                                  icon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: FutureBuilder<ManagedSchoolPage>(
                                future: _schools,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return Center(
                                      child: TextButton.icon(
                                        onPressed: _refresh,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text(
                                          'Could not load schools. Try again',
                                        ),
                                      ),
                                    );
                                  }
                                  final result = snapshot.requireData;
                                  return Column(
                                    children: [
                                      Expanded(
                                        child: result.schools.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  'No approved schools found.',
                                                ),
                                              )
                                            : ListView.separated(
                                                itemCount:
                                                    result.schools.length,
                                                separatorBuilder: (_, _) =>
                                                    const Divider(),
                                                itemBuilder: (context, index) {
                                                  final item =
                                                      result.schools[index];
                                                  return ListTile(
                                                    title: Text(item.name),
                                                    subtitle: Text(item.code),
                                                    trailing: const Icon(
                                                      Icons.chevron_right,
                                                    ),
                                                    onTap: () => setState(
                                                      () => _selectedSchool =
                                                          item,
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                      if (result.totalPages > 1)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: result.hasPrevious
                                                  ? () => _refresh(
                                                      page: _page - 1,
                                                    )
                                                  : null,
                                              child: const Text('Previous'),
                                            ),
                                            TextButton(
                                              onPressed: result.hasNext
                                                  ? () => _refresh(
                                                      page: _page + 1,
                                                    )
                                                  : null,
                                              child: const Text('Next'),
                                            ),
                                          ],
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
