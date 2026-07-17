import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../data/admissions_api_client.dart';
import '../../platform/presentation/document_opener.dart';
import '../../theme/app_theme.dart';

const _allClassesFilter = 'All classes';

enum AdmissionStatusFilter {
  all('All'),
  draft('Draft'),
  pendingApproval('Pending Approval'),
  approved('Approved'),
  rejected('Rejected'),
  active('Active');

  const AdmissionStatusFilter(this.label);
  final String label;
}

enum StudentApplicationStatus {
  draft('Draft', AppColors.muted),
  pendingApproval('Pending Approval', AppColors.amber),
  approved('Approved', AppColors.green),
  rejected('Rejected', AppColors.red),
  active('Active', AppColors.blue);

  const StudentApplicationStatus(this.label, this.color);
  final String label;
  final Color color;
}

class AdmissionsScreen extends StatefulWidget {
  const AdmissionsScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  @override
  State<AdmissionsScreen> createState() => _AdmissionsScreenState();
}

class _AdmissionsScreenState extends State<AdmissionsScreen> {
  AdmissionStatusFilter _filter = AdmissionStatusFilter.all;
  String _search = '';
  String _selectedClass = _allClassesFilter;
  late final AdmissionsApiClient _api;
  late final Future<AdmissionTermContext> _termFuture;
  late Future<List<_StudentApplication>> _applicationsFuture;

  @override
  void initState() {
    super.initState();
    _api = AdmissionsApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    _termFuture = _api.getCurrentTerm(widget.customSchoolId);
    _applicationsFuture = _loadApplications();
  }

  Future<List<_StudentApplication>> _loadApplications() async {
    final term = await _termFuture;
    final items = await _api.getAdmissions(
      customSchoolId: widget.customSchoolId,
      startDate: term.startDate,
      endDate: term.endDate,
    );
    return items
        .map(
          (item) => _StudentApplication(
            id: item.id,
            householdId: item.householdId,
            admissionId: item.admissionId,
            studentName: item.displayName.isEmpty
                ? 'Unnamed applicant'
                : item.displayName,
            studentId: item.customStudentId.isNotEmpty
                ? item.customStudentId
                : item.id == null
                ? 'Admission pending'
                : 'ADM-${item.id}',
            guardianName: item.guardianName.isNotEmpty
                ? item.guardianName
                : 'Guardian details pending',
            guardianPhone: item.guardianPhone,
            applyingFor: item.gradeLevelName.isEmpty
                ? 'Class pending'
                : item.gradeLevelName,
            type: _titleCase(item.personType),
            appliedDate: _formatDateText(item.createdAt),
            createdAt: item.createdAt,
            rawStatus: item.status,
            status: _studentStatusFromApi(item.status),
          ),
        )
        .toList();
  }

  List<_StudentApplication> _visibleApplications(
    List<_StudentApplication> applications,
  ) {
    final query = _search.trim().toLowerCase();
    return applications.where((application) {
      final matchesFilter = switch (_filter) {
        AdmissionStatusFilter.all => true,
        AdmissionStatusFilter.draft =>
          application.status == StudentApplicationStatus.draft,
        AdmissionStatusFilter.pendingApproval =>
          application.status == StudentApplicationStatus.pendingApproval,
        AdmissionStatusFilter.approved =>
          application.status == StudentApplicationStatus.approved,
        AdmissionStatusFilter.rejected =>
          application.status == StudentApplicationStatus.rejected,
        AdmissionStatusFilter.active =>
          application.status == StudentApplicationStatus.active,
      };
      if (!matchesFilter) return false;
      if (_selectedClass != _allClassesFilter &&
          application.applyingFor != _selectedClass) {
        return false;
      }
      if (query.isEmpty) return true;
      return application.studentName.toLowerCase().contains(query) ||
          application.guardianName.toLowerCase().contains(query) ||
          application.studentId.toLowerCase().contains(query) ||
          application.applyingFor.toLowerCase().contains(query);
    }).toList();
  }

  void _reloadApplications() {
    final nextApplications = _loadApplications();
    setState(() {
      _applicationsFuture = nextApplications;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StudentApplication>>(
      future: _applicationsFuture,
      builder: (context, snapshot) {
        final applications = snapshot.data ?? const <_StudentApplication>[];
        return LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 650 ? 16.0 : 28.0;
            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdmissionsHeader(
                    title: 'Admissions',
                    subtitle:
                        'Student applications for the current academic year.',
                    primaryAction: 'Start Admission',
                    onPrimaryAction: _showStartAdmissionSheet,
                  ),
                  const SizedBox(height: 12),
                  _CurrentTermBanner(future: _termFuture),
                  const SizedBox(height: 18),
                  _StatusTabs(
                    selected: _filter,
                    applications: applications,
                    onSelected: (filter) => setState(() => _filter = filter),
                  ),
                  const SizedBox(height: 18),
                  _SummaryCards(applications: applications),
                  const SizedBox(height: 18),
                  _AdmissionsFilters(
                    selectedClass: _selectedClass,
                    classes: {
                      _allClassesFilter,
                      _selectedClass,
                      ...applications
                          .map((item) => item.applyingFor)
                          .where((item) => item != 'Class pending'),
                    }.toList(),
                    onSearchChanged: (value) => setState(() => _search = value),
                    onClassChanged: (value) =>
                        setState(() => _selectedClass = value),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const _AdmissionsLoadingCard()
                  else if (snapshot.hasError)
                    _AdmissionsErrorCard(
                      message: snapshot.error.toString(),
                      onRetry: _reloadApplications,
                    )
                  else
                    _ApplicationsTable(
                      applications: _visibleApplications(applications),
                      customSchoolId: widget.customSchoolId,
                      api: _api,
                      onChanged: _reloadApplications,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showStartAdmissionSheet() async {
    final mode = await showDialog<_AdmissionStartMode>(
      context: context,
      builder: (context) => const _StartAdmissionDialog(),
    );
    if (!mounted || mode == null) return;
    final route = mode == _AdmissionStartMode.newHousehold
        ? _HouseholdDashboardScreen(
            household: _newHouseholdRecord(),
            customSchoolId: widget.customSchoolId,
            api: _api,
          )
        : _HouseholdPickerScreen(
            customSchoolId: widget.customSchoolId,
            api: _api,
          );
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => route));
    if (mounted) _reloadApplications();
  }
}

class HouseholdsGuardiansScreen extends StatefulWidget {
  const HouseholdsGuardiansScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  @override
  State<HouseholdsGuardiansScreen> createState() =>
      _HouseholdsGuardiansScreenState();
}

class _HouseholdsGuardiansScreenState extends State<HouseholdsGuardiansScreen> {
  String _search = '';
  late final AdmissionsApiClient _api;
  late final Future<AdmissionTermContext> _termFuture;
  late Future<List<_HouseholdRecord>> _householdsFuture;

  @override
  void initState() {
    super.initState();
    _api = AdmissionsApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    _termFuture = _api.getCurrentTerm(widget.customSchoolId);
    _householdsFuture = _loadHouseholds();
  }

  Future<List<_HouseholdRecord>> _loadHouseholds() async {
    final results = await Future.wait([
      _api.getGuardians(customSchoolId: widget.customSchoolId),
      _api.getStudents(customSchoolId: widget.customSchoolId),
    ]);
    return _householdsFromGuardians(
      results[0] as List<AdmissionGuardian>,
      students: results[1] as List<AdmissionStudent>,
    );
  }

  List<_HouseholdRecord> _visibleHouseholds(List<_HouseholdRecord> households) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return households;
    return households.where((household) {
      return household.householdName.toLowerCase().contains(query) ||
          household.primaryGuardian.toLowerCase().contains(query) ||
          household.phone.toLowerCase().contains(query);
    }).toList();
  }

  void _reloadHouseholds() {
    final nextHouseholds = _loadHouseholds();
    setState(() {
      _householdsFuture = nextHouseholds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < 650 ? 16.0 : 28.0;
        return FutureBuilder<List<_HouseholdRecord>>(
          future: _householdsFuture,
          builder: (context, snapshot) {
            final households = snapshot.data ?? const <_HouseholdRecord>[];
            return SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdmissionsHeader(
                    title: 'Households & Guardians',
                    subtitle:
                        'Find existing households, manage guardians, and continue unfinished guardian onboarding.',
                  ),
                  const SizedBox(height: 12),
                  _CurrentTermBanner(future: _termFuture),
                  const SizedBox(height: 18),
                  _HouseholdSummaryCards(households: households),
                  const SizedBox(height: 18),
                  _HouseholdFilters(
                    onSearchChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const _AdmissionsLoadingCard()
                  else if (snapshot.hasError)
                    _AdmissionsErrorCard(
                      message: snapshot.error.toString(),
                      onRetry: _reloadHouseholds,
                    )
                  else
                    _HouseholdsTable(
                      households: _visibleHouseholds(households),
                      customSchoolId: widget.customSchoolId,
                      api: _api,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AdmissionsHeader extends StatelessWidget {
  const _AdmissionsHeader({
    required this.title,
    required this.subtitle,
    this.primaryAction,
    this.onPrimaryAction,
  });

  final String title;
  final String subtitle;
  final String? primaryAction;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        if (primaryAction != null)
          FilledButton.icon(
            onPressed: onPrimaryAction ?? () {},
            icon: const Icon(Icons.add_rounded),
            label: Text(primaryAction!),
          ),
      ],
    );
  }
}

class _TermContextBanner extends StatelessWidget {
  const _TermContextBanner({
    required this.academicYear,
    required this.term,
    required this.dateRange,
  });

  final String academicYear;
  final String term;
  final String dateRange;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TermChip(icon: Icons.calendar_month_rounded, label: academicYear),
            _TermChip(icon: Icons.flag_rounded, label: term),
            _TermChip(icon: Icons.date_range_rounded, label: dateRange),
          ],
        ),
      ),
    );
  }
}

class _CurrentTermBanner extends StatelessWidget {
  const _CurrentTermBanner({required this.future});

  final Future<AdmissionTermContext> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdmissionTermContext>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _TermContextBanner(
            academicYear: 'Loading academic year...',
            term: 'Loading term...',
            dateRange: 'Loading dates...',
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      snapshot.error?.toString() ??
                          'The current academic term could not be loaded.',
                      style: const TextStyle(color: AppColors.red),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final term = snapshot.data!;
        return _TermContextBanner(
          academicYear: term.academicYear.isEmpty
              ? 'Academic year'
              : term.academicYear,
          term: term.term.isEmpty ? 'Current term' : term.term,
          dateRange:
              '${_formatDateText(term.startDate)} to ${_formatDateText(term.endDate)}',
        );
      },
    );
  }
}

class _TermChip extends StatelessWidget {
  const _TermChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.green),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.selected,
    required this.applications,
    required this.onSelected,
  });

  final AdmissionStatusFilter selected;
  final List<_StudentApplication> applications;
  final ValueChanged<AdmissionStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AdmissionStatusFilter.values.map((filter) {
          final active = selected == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: active,
              label: Text('${filter.label} ${_countFor(filter)}'),
              onSelected: (_) => onSelected(filter),
              selectedColor: AppColors.greenSoft,
              side: BorderSide(
                color: active ? AppColors.green : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: active ? AppColors.green : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _countFor(AdmissionStatusFilter filter) {
    return switch (filter) {
      AdmissionStatusFilter.all => applications.length,
      AdmissionStatusFilter.draft =>
        applications
            .where((item) => item.status == StudentApplicationStatus.draft)
            .length,
      AdmissionStatusFilter.pendingApproval =>
        applications
            .where(
              (item) => item.status == StudentApplicationStatus.pendingApproval,
            )
            .length,
      AdmissionStatusFilter.approved =>
        applications
            .where((item) => item.status == StudentApplicationStatus.approved)
            .length,
      AdmissionStatusFilter.rejected =>
        applications
            .where((item) => item.status == StudentApplicationStatus.rejected)
            .length,
      AdmissionStatusFilter.active =>
        applications
            .where((item) => item.status == StudentApplicationStatus.active)
            .length,
    };
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.applications});
  final List<_StudentApplication> applications;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _SummaryValue(
        'Total',
        applications.length,
        'All student applications',
        AppColors.green,
      ),
      _SummaryValue(
        'Draft',
        _count(StudentApplicationStatus.draft),
        'Saved, not submitted',
        AppColors.muted,
      ),
      _SummaryValue(
        'Pending Approval',
        _count(StudentApplicationStatus.pendingApproval),
        'Awaiting decision',
        AppColors.amber,
      ),
      _SummaryValue(
        'Approved',
        _count(StudentApplicationStatus.approved),
        'Ready to enroll',
        AppColors.green,
      ),
      _SummaryValue(
        'Rejected',
        _count(StudentApplicationStatus.rejected),
        'Not admitted',
        AppColors.red,
      ),
      _SummaryValue(
        'Active',
        _count(StudentApplicationStatus.active),
        'Enrolled students',
        AppColors.blue,
      ),
    ];
    return _ResponsiveCardGrid(
      children: rows
          .map(
            (item) => _SummaryCard(
              title: item.title,
              value: item.value.toString(),
              subtitle: item.subtitle,
              color: item.color,
            ),
          )
          .toList(),
    );
  }

  int _count(StudentApplicationStatus status) {
    return applications.where((item) => item.status == status).length;
  }
}

class _HouseholdSummaryCards extends StatelessWidget {
  const _HouseholdSummaryCards({required this.households});
  final List<_HouseholdRecord> households;

  @override
  Widget build(BuildContext context) {
    final incomplete = households
        .where(
          (item) =>
              item.status == 'Guardian incomplete' ||
              item.status == 'No student added',
        )
        .length;
    final pendingGuardians = households.fold<int>(
      0,
      (sum, item) => sum + item.pendingGuardians,
    );
    return _ResponsiveCardGrid(
      children: [
        _SummaryCard(
          title: 'Households',
          value: households.length.toString(),
          subtitle: 'Guardian accounts',
          color: AppColors.green,
        ),
        _SummaryCard(
          title: 'Incomplete',
          value: incomplete.toString(),
          subtitle: 'Need setup work',
          color: AppColors.amber,
        ),
        _SummaryCard(
          title: 'Pending Guardians',
          value: pendingGuardians.toString(),
          subtitle: 'Additional guardians',
          color: AppColors.blue,
        ),
      ],
    );
  }
}

class _ResponsiveCardGrid extends StatelessWidget {
  const _ResponsiveCardGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / 220).floor().clamp(1, 6);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 140,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 3)),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _AdmissionsFilters extends StatelessWidget {
  const _AdmissionsFilters({
    required this.selectedClass,
    required this.classes,
    required this.onSearchChanged,
    required this.onClassChanged,
  });

  final String selectedClass;
  final List<String> classes;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onClassChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final search = TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search applications',
                hintText: 'Student, guardian, class, or application ID',
                prefixIcon: Icon(Icons.search_rounded),
                contentPadding: EdgeInsets.symmetric(vertical: 13),
              ),
            );
            final classFilter = DropdownButtonFormField<String>(
              value: selectedClass,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Class',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              items: classes
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onClassChanged(value);
              },
            );
            if (compact) {
              return Column(
                children: [search, const SizedBox(height: 10), classFilter],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                SizedBox(width: 230, child: classFilter),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HouseholdFilters extends StatelessWidget {
  const _HouseholdFilters({required this.onSearchChanged});
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return _FilterBar(
      searchHint: 'Search by guardian name, phone, or household',
      onSearchChanged: onSearchChanged,
      filters: const ['All statuses', 'All guardians'],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchHint,
    required this.onSearchChanged,
    required this.filters,
  });

  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final List<String> filters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 420,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
            ...filters.map(
              (filter) => SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  value: filter,
                  items: [DropdownMenuItem(value: filter, child: Text(filter))],
                  onChanged: (_) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationsTable extends StatelessWidget {
  const _ApplicationsTable({
    required this.applications,
    required this.customSchoolId,
    required this.api,
    required this.onChanged,
  });
  final List<_StudentApplication> applications;
  final String customSchoolId;
  final AdmissionsApiClient api;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const _TableHeader(
            labels: [
              'Applicant',
              'Guardian',
              'Applying for',
              'Type',
              'Applied',
              'Status',
            ],
          ),
          if (applications.isEmpty)
            const _EmptyState(
              title: 'No student applications found',
              subtitle: 'Try another status or search term.',
            )
          else
            ...applications.map((application) {
              return _ApplicationRow(
                application: application,
                customSchoolId: customSchoolId,
                api: api,
                onChanged: onChanged,
              );
            }),
        ],
      ),
    );
  }
}

class _HouseholdsTable extends StatelessWidget {
  const _HouseholdsTable({
    required this.households,
    required this.customSchoolId,
    required this.api,
  });

  final List<_HouseholdRecord> households;
  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const _TableHeader(
            labels: [
              'Household',
              'Primary guardian',
              'Students',
              'Pending guardians',
              'Started',
              'Status',
            ],
          ),
          if (households.isEmpty)
            const _EmptyState(
              title: 'No households found',
              subtitle: 'Try another search term.',
            )
          else
            ...households.map((household) {
              return _HouseholdRow(
                household: household,
                customSchoolId: customSchoolId,
                api: api,
              );
            }),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: labels
            .map(
              (label) => Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({
    required this.application,
    required this.customSchoolId,
    required this.api,
    required this.onChanged,
  });
  final _StudentApplication application;
  final String customSchoolId;
  final AdmissionsApiClient api;
  final VoidCallback onChanged;

  Future<void> _openApplication(BuildContext context) async {
    if (application.status == StudentApplicationStatus.pendingApproval) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ApplicantDetailScreen(
            application: application,
            customSchoolId: customSchoolId,
            api: api,
          ),
        ),
      );
      onChanged();
      return;
    }

    if (application.status == StudentApplicationStatus.approved ||
        application.status == StudentApplicationStatus.active) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _StudentProfileScreen(
            application: application,
            customSchoolId: customSchoolId,
            api: api,
          ),
        ),
      );
      onChanged();
      return;
    }

    final householdId = application.householdId;
    if (householdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This application has no household information yet.'),
        ),
      );
      return;
    }
    final guardianName = application.guardianName == 'Guardian details pending'
        ? 'Applicant'
        : application.guardianName;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HouseholdDashboardScreen(
          household: _HouseholdRecord(
            householdId: householdId,
            householdName: '$guardianName Household',
            primaryGuardian: application.guardianName,
            phone: application.guardianPhone.isEmpty
                ? 'No phone yet'
                : application.guardianPhone,
            status: application.status.label,
            statusColor: application.status.color,
            students: 1,
            pendingGuardians: 0,
            started: application.appliedDate,
          ),
          customSchoolId: customSchoolId,
          api: api,
        ),
      ),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: application.studentId.startsWith('STU-')
          ? () => _openApplication(context)
          : null,
      child: _ResponsiveRow(
        leadingTitle: application.studentName,
        leadingSubtitle: application.studentId,
        cells: [
          _TwoLine(application.guardianName, application.guardianPhone),
          Text(application.applyingFor),
          Text(application.type),
          Text(application.appliedDate),
          Row(
            children: [
              _StatusPill(
                label: application.status.label,
                color: application.status.color,
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StudentProfileScreen extends StatefulWidget {
  const _StudentProfileScreen({
    required this.application,
    required this.customSchoolId,
    required this.api,
  });

  final _StudentApplication application;
  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  State<_StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<_StudentProfileScreen> {
  late Future<AdmissionStudent> _studentFuture;

  @override
  void initState() {
    super.initState();
    _studentFuture = _loadStudent();
  }

  Future<AdmissionStudent> _loadStudent() => widget.api.getStudentDetails(
    customSchoolId: widget.customSchoolId,
    customStudentId: widget.application.studentId,
  );

  void _reloadStudent() {
    final nextStudent = _loadStudent();
    setState(() => _studentFuture = nextStudent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _AdmissionFlowTopBar(
              title: 'Student profile',
              subtitle: 'Student identity and enrollment information',
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: FutureBuilder<AdmissionStudent>(
                future: _studentFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: _AdmissionsLoadingCard(),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: _AdmissionsErrorCard(
                        message: snapshot.error.toString(),
                        onRetry: _reloadStudent,
                      ),
                    );
                  }
                  return _StudentProfileOverview(
                    student: snapshot.data!,
                    application: widget.application,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentProfileOverview extends StatelessWidget {
  const _StudentProfileOverview({
    required this.student,
    required this.application,
  });

  final AdmissionStudent student;
  final _StudentApplication application;

  @override
  Widget build(BuildContext context) {
    final displayName = student.displayName.trim().isEmpty
        ? application.studentName
        : student.displayName;
    final status = student.status.trim().isEmpty
        ? application.status
        : _studentStatusFromApi(student.status);
    final values = [
      ('Applying for', _value(student.gradeLevel)),
      ('Gender', _value(student.gender)),
      ('Date of birth', _dateValue(student.dateOfBirth)),
      ('Guardian', _value(application.guardianName)),
      ('Household ID', '${student.householdId ?? 'Not provided'}'),
      ('Application status', status.label),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: AppColors.greenSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initialsForText(displayName),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 230),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              student.customStudentId,
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      _StatusPill(label: status.label, color: status.color),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 820 ? 3 : 1;
                  const gap = 12.0;
                  final cardWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: values
                        .map(
                          (item) => SizedBox(
                            width: cardWidth,
                            child: _StudentProfileValueCard(
                              label: item.$1,
                              value: item.$2,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _value(String value) =>
      value.trim().isEmpty ? 'Not provided' : value;

  static String _dateValue(String value) =>
      value.trim().isEmpty ? 'Not provided' : _formatDateText(value);
}

class _StudentProfileValueCard extends StatelessWidget {
  const _StudentProfileValueCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdRow extends StatelessWidget {
  const _HouseholdRow({
    required this.household,
    required this.customSchoolId,
    required this.api,
  });

  final _HouseholdRecord household;
  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _HouseholdDashboardScreen(
            household: household,
            customSchoolId: customSchoolId,
            api: api,
          ),
        ),
      ),
      child: _ResponsiveRow(
        leadingTitle: household.householdName,
        leadingSubtitle: household.phone,
        cells: [
          Text(household.primaryGuardian),
          Text('${household.students}'),
          Text('${household.pendingGuardians}'),
          Text(household.started),
          Align(
            alignment: Alignment.centerLeft,
            child: _StatusPill(
              label: household.status,
              color: household.statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({
    required this.leadingTitle,
    required this.leadingSubtitle,
    required this.cells,
  });

  final String leadingTitle;
  final String leadingSubtitle;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TwoLine(leadingTitle, leadingSubtitle),
                const SizedBox(height: 12),
                Wrap(spacing: 18, runSpacing: 10, children: cells),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(child: _TwoLine(leadingTitle, leadingSubtitle)),
              ...cells.map((cell) => Expanded(child: cell)),
            ],
          ),
        );
      },
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

enum _AdmissionStartMode { newHousehold, existingHousehold }

enum _AdmissionFlowKind { primaryGuardian, additionalGuardian, student }

class _StartAdmissionDialog extends StatelessWidget {
  const _StartAdmissionDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_ind_rounded,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start admission',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'A student application must belong to a household.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _StartAdmissionOption(
                icon: Icons.home_work_rounded,
                title: 'Create new household',
                subtitle:
                    'Use this when the guardian is new. Create the household, complete guardian details, then add the student.',
                onTap: () =>
                    Navigator.pop(context, _AdmissionStartMode.newHousehold),
              ),
              const SizedBox(height: 12),
              _StartAdmissionOption(
                icon: Icons.manage_search_rounded,
                title: 'Use existing household',
                subtitle:
                    'Search for the existing guardian or household, then start a student application from that household.',
                onTap: () => Navigator.pop(
                  context,
                  _AdmissionStartMode.existingHousehold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseholdPickerScreen extends StatefulWidget {
  const _HouseholdPickerScreen({
    required this.customSchoolId,
    required this.api,
  });

  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  State<_HouseholdPickerScreen> createState() => _HouseholdPickerScreenState();
}

class _HouseholdPickerScreenState extends State<_HouseholdPickerScreen> {
  late Future<List<_HouseholdRecord>> _householdsFuture;

  @override
  void initState() {
    super.initState();
    _householdsFuture = _loadHouseholds();
  }

  Future<List<_HouseholdRecord>> _loadHouseholds() async {
    final results = await Future.wait([
      widget.api.getGuardians(customSchoolId: widget.customSchoolId),
      widget.api.getStudents(customSchoolId: widget.customSchoolId),
    ]);
    return _householdsFromGuardians(
      results[0] as List<AdmissionGuardian>,
      students: results[1] as List<AdmissionStudent>,
    );
  }

  void _reloadHouseholds() {
    final nextHouseholds = _loadHouseholds();
    setState(() {
      _householdsFuture = nextHouseholds;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _AdmissionFlowTopBar(
              title: 'Select household',
              subtitle:
                  'Find the existing household before adding a student application.',
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: _StepFormCard(
                      title: 'Use existing household',
                      subtitle:
                          'Search by guardian name, phone number, or household ID.',
                      child: FutureBuilder<List<_HouseholdRecord>>(
                        future: _householdsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _AdmissionsLoadingCard();
                          }
                          if (snapshot.hasError) {
                            return _AdmissionsErrorCard(
                              message: snapshot.error.toString(),
                              onRetry: _reloadHouseholds,
                            );
                          }
                          return _ExistingHouseholdSearchForm(
                            households:
                                snapshot.data ?? const <_HouseholdRecord>[],
                            onSelected: (household) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) => _HouseholdDashboardScreen(
                                    household: household,
                                    customSchoolId: widget.customSchoolId,
                                    api: widget.api,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdDashboardScreen extends StatefulWidget {
  const _HouseholdDashboardScreen({
    required this.household,
    required this.customSchoolId,
    required this.api,
  });

  final _HouseholdRecord household;
  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  State<_HouseholdDashboardScreen> createState() =>
      _HouseholdDashboardScreenState();
}

class _HouseholdDashboardScreenState extends State<_HouseholdDashboardScreen> {
  late Future<_HouseholdDashboardData> _dashboardFuture;
  late _HouseholdRecord _household;
  String? _primaryGuardianKey;
  String? _settingPrimaryGuardianKey;

  @override
  void initState() {
    super.initState();
    _household = widget.household;
    _dashboardFuture = _loadDashboard();
  }

  Future<_HouseholdDashboardData> _loadDashboard() async {
    final householdId = _household.householdId;
    if (householdId == null) {
      return const _HouseholdDashboardData(guardians: [], students: []);
    }
    final results = await Future.wait([
      widget.api.getGuardians(
        customSchoolId: widget.customSchoolId,
        householdId: householdId,
      ),
      widget.api.getStudents(
        customSchoolId: widget.customSchoolId,
        householdId: householdId,
      ),
    ]);
    final guardians = results[0] as List<AdmissionGuardian>;
    final studentSummaries = results[1] as List<AdmissionStudent>;
    final students = await Future.wait(
      studentSummaries.map(
        (student) => widget.api.getStudentDetails(
          customSchoolId: widget.customSchoolId,
          customStudentId: student.customStudentId,
        ),
      ),
    );
    if (guardians.isNotEmpty) {
      final primary = guardians.firstWhere(
        (guardian) => guardian.isPrimary,
        orElse: () => guardians.first,
      );
      final incompleteGuardians = guardians.where((guardian) {
        return _isIncompleteGuardian(guardian.status);
      }).length;
      final pendingGuardians = guardians.where((guardian) {
        return _isPendingReviewGuardian(guardian.status);
      }).length;
      _household = _household.copyWith(
        householdName: '${primary.displayName} Household',
        primaryGuardian: primary.displayName,
        phone: primary.phone.isEmpty ? 'No phone yet' : primary.phone,
        students: students.length,
        pendingGuardians: pendingGuardians,
        status: incompleteGuardians > 0
            ? 'Guardian incomplete'
            : pendingGuardians > 0
            ? 'Pending review'
            : 'Ready for student',
        statusColor: incompleteGuardians > 0
            ? AppColors.amber
            : pendingGuardians > 0
            ? AppColors.blue
            : AppColors.green,
      );
    }
    return _HouseholdDashboardData(guardians: guardians, students: students);
  }

  void _reloadDashboard() {
    final nextDashboard = _loadDashboard();
    setState(() {
      _dashboardFuture = nextDashboard;
    });
  }

  Future<void> _openDrawer(
    _AdmissionFlowKind flow, {
    AdmissionGuardian? existingGuardian,
    AdmissionStudent? existingStudent,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close admission form',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _AdmissionSideDrawer(
            flow: flow,
            householdName: _household.householdName,
            householdId: _household.householdId,
            customSchoolId: widget.customSchoolId,
            api: widget.api,
            existingGuardian: existingGuardian,
            existingStudent: existingStudent,
            onSaved: (savedHouseholdId) {
              final nextDashboard = _loadDashboard();
              setState(() {
                if (_household.householdId == null &&
                    savedHouseholdId != null) {
                  _household = _household.copyWith(
                    householdId: savedHouseholdId,
                    status: 'Ready for student',
                    statusColor: AppColors.green,
                  );
                }
                _dashboardFuture = nextDashboard;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    flow == _AdmissionFlowKind.student
                        ? 'Student application saved to this household.'
                        : 'Guardian saved to this household.',
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  Future<void> _editGuardian(AdmissionGuardian guardian) async {
    try {
      final details = await widget.api.getGuardianDetails(
        customSchoolId: widget.customSchoolId,
        customGuardianId: guardian.customGuardianId,
      );
      if (!mounted) return;
      await _openDrawer(
        _AdmissionFlowKind.additionalGuardian,
        existingGuardian: details,
      );
    } on AdmissionsApiException catch (error) {
      if (!mounted) return;
      _showHouseholdMessage(error.message);
    }
  }

  Future<void> _editStudent(AdmissionStudent student) async {
    try {
      final details = await widget.api.getStudentDetails(
        customSchoolId: widget.customSchoolId,
        customStudentId: student.customStudentId,
      );
      if (!mounted) return;
      await _openDrawer(_AdmissionFlowKind.student, existingStudent: details);
    } on AdmissionsApiException catch (error) {
      if (!mounted) return;
      _showHouseholdMessage(error.message);
    }
  }

  Future<void> _deleteGuardian(AdmissionGuardian guardian) async {
    final householdId = guardian.householdId ?? _household.householdId;
    if (householdId == null) {
      _showHouseholdMessage('This guardian has no household identifier.');
      return;
    }
    final confirmed = await _confirmMemberDeletion(
      title: 'Delete guardian?',
      message:
          'This will permanently remove ${guardian.displayName} from this household.',
      confirmLabel: 'Delete guardian',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.api.deleteGuardian(
        customSchoolId: widget.customSchoolId,
        customGuardianId: guardian.customGuardianId,
        householdId: householdId,
      );
      if (!mounted) return;
      _reloadDashboard();
      _showHouseholdMessage('Guardian deleted.');
    } on AdmissionsApiException catch (error) {
      if (!mounted) return;
      _showHouseholdMessage(error.message);
    }
  }

  Future<void> _deleteStudent(AdmissionStudent student) async {
    final householdId = student.householdId ?? _household.householdId;
    if (householdId == null) {
      _showHouseholdMessage('This student has no household identifier.');
      return;
    }
    final confirmed = await _confirmMemberDeletion(
      title: 'Delete student application?',
      message:
          'This will permanently remove ${student.displayName} and the related admission application.',
      confirmLabel: 'Delete student',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.api.deleteStudent(
        customSchoolId: widget.customSchoolId,
        householdId: householdId,
        customStudentId: student.customStudentId,
      );
      if (!mounted) return;
      _reloadDashboard();
      _showHouseholdMessage('Student application deleted.');
    } on AdmissionsApiException catch (error) {
      if (!mounted) return;
      _showHouseholdMessage(error.message);
    }
  }

  Future<void> _setPrimaryGuardian(AdmissionGuardian guardian) async {
    final guardianKey = _guardianKey(guardian);
    if (_settingPrimaryGuardianKey != null || guardianKey.isEmpty) return;

    setState(() => _settingPrimaryGuardianKey = guardianKey);
    try {
      final updated = await widget.api.setPrimaryGuardian(
        customSchoolId: widget.customSchoolId,
        customGuardianId: guardian.customGuardianId,
      );
      if (!mounted) return;
      setState(() {
        _primaryGuardianKey = guardianKey;
        _settingPrimaryGuardianKey = null;
      });
      _reloadDashboard();
      final guardianName = updated.displayName.trim().isEmpty
          ? guardian.displayName
          : updated.displayName;
      _showHouseholdMessage('$guardianName is now the primary guardian.');
    } on AdmissionsApiException catch (error) {
      if (!mounted) return;
      setState(() => _settingPrimaryGuardianKey = null);
      _showHouseholdMessage(error.message);
    }
  }

  Future<bool> _confirmMemberDeletion({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showHouseholdMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _AdmissionFlowTopBar(
              title: widget.household.householdName,
              subtitle:
                  'Household dashboard · Guardians and student applications',
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: FutureBuilder<_HouseholdDashboardData>(
                future: _dashboardFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: _AdmissionsLoadingCard(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: _AdmissionsErrorCard(
                        message: snapshot.error.toString(),
                        onRetry: _reloadDashboard,
                      ),
                    );
                  }
                  return _HouseholdWorkspace(
                    household: _household,
                    guardians:
                        snapshot.data?.guardians ?? const <AdmissionGuardian>[],
                    students:
                        snapshot.data?.students ?? const <AdmissionStudent>[],
                    primaryGuardianKey: _primaryGuardianKey,
                    settingPrimaryGuardianKey: _settingPrimaryGuardianKey,
                    onSetPrimaryGuardian: (guardian) {
                      _setPrimaryGuardian(guardian);
                    },
                    onAddGuardian: () => _openDrawer(
                      (snapshot.data?.guardians ?? const <AdmissionGuardian>[])
                              .isEmpty
                          ? _AdmissionFlowKind.primaryGuardian
                          : _AdmissionFlowKind.additionalGuardian,
                    ),
                    onAddStudent: () => _openDrawer(_AdmissionFlowKind.student),
                    onEditGuardian: _editGuardian,
                    onDeleteGuardian: _deleteGuardian,
                    onEditStudent: _editStudent,
                    onDeleteStudent: _deleteStudent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdWorkspace extends StatelessWidget {
  const _HouseholdWorkspace({
    required this.household,
    required this.guardians,
    required this.students,
    required this.primaryGuardianKey,
    required this.settingPrimaryGuardianKey,
    required this.onSetPrimaryGuardian,
    required this.onAddGuardian,
    required this.onAddStudent,
    required this.onEditGuardian,
    required this.onDeleteGuardian,
    required this.onEditStudent,
    required this.onDeleteStudent,
  });

  final _HouseholdRecord household;
  final List<AdmissionGuardian> guardians;
  final List<AdmissionStudent> students;
  final String? primaryGuardianKey;
  final String? settingPrimaryGuardianKey;
  final ValueChanged<AdmissionGuardian> onSetPrimaryGuardian;
  final VoidCallback onAddGuardian;
  final VoidCallback onAddStudent;
  final ValueChanged<AdmissionGuardian> onEditGuardian;
  final ValueChanged<AdmissionGuardian> onDeleteGuardian;
  final ValueChanged<AdmissionStudent> onEditStudent;
  final ValueChanged<AdmissionStudent> onDeleteStudent;

  bool get _hasGuardian => guardians.isNotEmpty;
  bool get _hasStudent => students.isNotEmpty;
  bool get _ready => _hasGuardian && _hasStudent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1060;
              final main = Column(
                children: [
                  _HouseholdIdentityCard(household: household),
                  const SizedBox(height: 14),
                  _HouseholdSectionCard(
                    title: 'Parents & Guardians',
                    count: guardians.length,
                    accent: AppColors.green,
                    actionLabel: 'Add Guardian',
                    actionIcon: Icons.person_add_alt_1_rounded,
                    onAction: onAddGuardian,
                    emptyIcon: Icons.supervisor_account_rounded,
                    emptyTitle: 'No guardian added yet',
                    emptySubtitle:
                        'Add the first parent or guardian before registering students.',
                    children: guardians
                        .map(
                          (guardian) => _GuardianWorkspaceRow(
                            guardian: guardian,
                            isPrimary: primaryGuardianKey == null
                                ? guardian.isPrimary
                                : _guardianKey(guardian) == primaryGuardianKey,
                            isSettingPrimary:
                                _guardianKey(guardian) ==
                                settingPrimaryGuardianKey,
                            onSetPrimary: () => onSetPrimaryGuardian(guardian),
                            onEdit: () => onEditGuardian(guardian),
                            onDelete: () => onDeleteGuardian(guardian),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  _HouseholdSectionCard(
                    title: 'Students & Children',
                    count: students.length,
                    accent: AppColors.blue,
                    actionLabel: 'Add Student',
                    actionIcon: Icons.school_rounded,
                    onAction: _hasGuardian ? onAddStudent : null,
                    emptyIcon: Icons.child_care_rounded,
                    emptyTitle: _hasGuardian
                        ? 'No student applications yet'
                        : 'Add a guardian first',
                    emptySubtitle: _hasGuardian
                        ? 'Start a separate admission application for each child.'
                        : 'Every student application must belong to a household with at least one guardian.',
                    children: students
                        .map(
                          (student) => _StudentWorkspaceRow(
                            student: student,
                            onEdit: () => onEditStudent(student),
                            onDelete: () => onDeleteStudent(student),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
              final side = _HouseholdSidebar(
                household: household,
                guardians: guardians.length,
                students: students.length,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: main),
                          const SizedBox(width: 16),
                          SizedBox(width: 290, child: side),
                        ],
                      )
                    : Column(
                        children: [main, const SizedBox(height: 16), side],
                      ),
              );
            },
          ),
        ),
        _HouseholdFooterBar(
          guardians: guardians.length,
          students: students.length,
          ready: _ready,
        ),
      ],
    );
  }
}

class _HouseholdIdentityCard extends StatelessWidget {
  const _HouseholdIdentityCard({required this.household});

  final _HouseholdRecord household;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 76,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF004D40), AppColors.green, AppColors.blue],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      border: Border.all(color: Colors.white, width: 4),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initialsForText(household.householdName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          household.householdName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusPill(
                              label: household.status,
                              color: household.statusColor,
                            ),
                            Text(
                              '${household.primaryGuardian} · ${household.phone} · Started ${household.started}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                        if (household.isPreview) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Preview household: use the drawers to inspect guardian and student form fields.',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdSectionCard extends StatelessWidget {
  const _HouseholdSectionCard({
    required this.title,
    required this.count,
    required this.accent,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  final String title;
  final int count;
  final Color accent;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _CountPill(count: count),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (children.isEmpty)
            _HouseholdEmptySection(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }
}

class _HouseholdEmptySection extends StatelessWidget {
  const _HouseholdEmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.border,
                width: 2,
                style: BorderStyle.solid,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianWorkspaceRow extends StatelessWidget {
  const _GuardianWorkspaceRow({
    required this.guardian,
    required this.isPrimary,
    required this.isSettingPrimary,
    required this.onSetPrimary,
    required this.onEdit,
    required this.onDelete,
  });

  final AdmissionGuardian guardian;
  final bool isPrimary;
  final bool isSettingPrimary;
  final VoidCallback onSetPrimary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final relationship = guardian.relationship.isEmpty
        ? (isPrimary ? 'Primary guardian' : 'Guardian')
        : guardian.relationship;
    return _ContactRecordRow(
      initials: _initialsForText(guardian.displayName),
      name: guardian.displayName,
      relationship: relationship,
      phone: guardian.phone.isEmpty ? 'No phone yet' : guardian.phone,
      email: guardian.email.isEmpty ? 'No email yet' : guardian.email,
      isPrimary: isPrimary,
      isSettingPrimary: isSettingPrimary,
      onSetPrimary: onSetPrimary,
      status: _guardianStatusLabel(guardian.status),
      statusColor: _guardianStatusColor(guardian.status),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _StudentWorkspaceRow extends StatelessWidget {
  const _StudentWorkspaceRow({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });

  final AdmissionStudent student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _StudentApplicationRow(
      initials: _initialsForText(student.displayName),
      name: student.displayName,
      gender: student.gender.isEmpty ? 'Gender pending' : student.gender,
      dateOfBirth: student.dateOfBirth.isEmpty
          ? 'DOB pending'
          : _formatDateText(student.dateOfBirth),
      gradeLevel: student.gradeLevel.isEmpty
          ? 'Class pending'
          : 'Applying for ${student.gradeLevel}',
      studentId: student.customStudentId.isEmpty
          ? 'Student ID pending'
          : student.customStudentId,
      status: _studentStatusLabel(student.status),
      statusColor: _studentStatusColor(student.status),
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _ContactRecordRow extends StatelessWidget {
  const _ContactRecordRow({
    required this.initials,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.isPrimary,
    required this.isSettingPrimary,
    required this.onSetPrimary,
    required this.status,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
  });

  final String initials;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final bool isPrimary;
  final bool isSettingPrimary;
  final VoidCallback onSetPrimary;
  final String status;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.greenSoft : const Color(0xFFF8FAFB),
        border: Border.all(
          color: isPrimary
              ? AppColors.green.withValues(alpha: 0.24)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    _MiniBadge(
                      label: relationship,
                      color: AppColors.green,
                      filled: false,
                    ),
                    if (isPrimary)
                      const _MiniBadge(
                        label: 'Primary',
                        color: AppColors.green,
                        filled: true,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$phone · $email',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusPill(label: status, color: statusColor),
          const SizedBox(width: 6),
          if (!isPrimary)
            OutlinedButton(
              onPressed: isSettingPrimary ? null : onSetPrimary,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
              child: isSettingPrimary
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 7),
                        Text('Saving...'),
                      ],
                    )
                  : const Text('Set Primary'),
            ),
          if (!isPrimary) const SizedBox(width: 6),
          _RecordActionButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          const SizedBox(width: 6),
          _RecordActionButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onPressed: onDelete,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _StudentApplicationRow extends StatelessWidget {
  const _StudentApplicationRow({
    required this.initials,
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.gradeLevel,
    required this.studentId,
    required this.status,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
  });

  final String initials;
  final String name;
  final String gender;
  final String dateOfBirth;
  final String gradeLevel;
  final String studentId;
  final String status;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _InlineMeta(icon: Icons.badge_outlined, label: studentId),
                    _InlineMeta(icon: Icons.person_outline, label: gender),
                    _InlineMeta(icon: Icons.cake_outlined, label: dateOfBirth),
                    _InlineMeta(icon: Icons.school_outlined, label: gradeLevel),
                  ],
                ),
              ],
            ),
          ),
          _StatusPill(label: status, color: statusColor),
          const SizedBox(width: 6),
          _RecordActionButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
          const SizedBox(width: 6),
          _RecordActionButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onPressed: onDelete,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
    required this.filled,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RecordActionButton extends StatelessWidget {
  const _RecordActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.red : AppColors.green;
    return Tooltip(
      message: label,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(72, 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: color.withValues(alpha: 0.42)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _HouseholdSidebar extends StatelessWidget {
  const _HouseholdSidebar({
    required this.household,
    required this.guardians,
    required this.students,
  });

  final _HouseholdRecord household;
  final int guardians;
  final int students;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SideCard(
          title: 'Submission Checklist',
          child: Column(
            children: [
              _ChecklistItem(
                label: 'Enter household name',
                done: household.householdName.trim().isNotEmpty,
              ),
              _ChecklistItem(
                label: 'Add at least 1 guardian',
                done: guardians > 0,
              ),
              _ChecklistItem(
                label: 'Add at least 1 student',
                done: students > 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SideCard(
          title: 'Household Summary',
          child: Column(
            children: [
              _SummaryRow(label: 'Guardians', value: '$guardians'),
              _SummaryRow(label: 'Students', value: '$students'),
              _SummaryRow(
                label: 'Applications',
                value: students == 0 ? '0' : '$students pending',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: done ? AppColors.green : AppColors.border,
            child: Icon(
              done ? Icons.check_rounded : Icons.circle_outlined,
              color: done ? Colors.white : AppColors.muted,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done ? AppColors.text : AppColors.muted,
                fontWeight: done ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.green,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HouseholdFooterBar extends StatelessWidget {
  const _HouseholdFooterBar({
    required this.guardians,
    required this.students,
    required this.ready,
  });

  final int guardians;
  final int students;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 5,
            backgroundColor: ready ? AppColors.green : AppColors.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$guardians guardians · $students students — ${ready ? 'Ready to submit' : 'Complete the checklist before submission'}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to admissions'),
          ),
        ],
      ),
    );
  }
}

class _AdmissionSideDrawer extends StatefulWidget {
  const _AdmissionSideDrawer({
    required this.flow,
    required this.householdName,
    required this.customSchoolId,
    required this.api,
    required this.onSaved,
    this.householdId,
    this.existingGuardian,
    this.existingStudent,
    this.initialStep = 0,
  });

  final _AdmissionFlowKind flow;
  final String householdName;
  final String customSchoolId;
  final AdmissionsApiClient api;
  final ValueChanged<int?> onSaved;
  final int? householdId;
  final AdmissionGuardian? existingGuardian;
  final AdmissionStudent? existingStudent;
  final int initialStep;

  @override
  State<_AdmissionSideDrawer> createState() => _AdmissionSideDrawerState();
}

class _GuardianAdmissionDraft {
  final title = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final dob = TextEditingController();
  final religion = TextEditingController();
  final phoneNumbers = <_GuardianPhoneDraft>[
    _GuardianPhoneDraft(isPrimary: true),
  ];
  final workPhone = TextEditingController();
  String workPhoneNetwork = '';
  final emailAddresses = <TextEditingController>[TextEditingController()];
  final socialAccounts = <_GuardianSocialAccountDraft>[
    _GuardianSocialAccountDraft(),
  ];
  final idNumber = TextEditingController();
  final issueDate = TextEditingController();
  final expiryDate = TextEditingController();
  final occupationOther = TextEditingController();
  final addressDraft = _AddressDraft();
  final proofLocationDraft = _AddressDraft();

  String? customGuardianId;
  int? householdId;
  String? admissionId;
  int? genderId;
  int? nationalityId;
  int? religionId;
  String? nationalityCode;
  String nationalityName = '';
  String religionName = '';
  int? proofOfIdTypeId;
  int? proofCountryId;
  String proofOfIdTypeName = '';
  String proofCountryCode = '';
  String proofCountryName = '';
  String relationship = 'Parent';
  final selectedLanguages = <AdmissionLookupOption>[];
  final selectedOccupations = <AdmissionLookupOption>[];
  final selectedSkills = <AdmissionLookupOption>[];

  void hydrate(AdmissionGuardian guardian) {
    final json = guardian.rawJson;
    customGuardianId = guardian.customGuardianId;
    householdId = guardian.householdId;
    admissionId = _admissionText(json['admissionId']);
    title.text = _admissionText(json['title']);
    firstName.text = _admissionText(json['firstName']);
    lastName.text = _admissionText(json['lastName']);
    dob.text = _admissionDate(json['dob'] ?? json['dateOfBirth']);
    relationship = guardian.relationship.isEmpty
        ? 'Parent'
        : guardian.relationship;

    final gender = _admissionMap(json['gender']);
    genderId = _admissionInt(gender?['id'] ?? json['genderId']);
    final religionJson = _admissionMap(json['religion']);
    religionId = _admissionInt(
      religionJson?['religionId'] ?? religionJson?['id'] ?? json['religionId'],
    );
    religionName = _admissionText(
      religionJson?['religionName'] ??
          religionJson?['name'] ??
          json['religionName'],
    );
    religion.text = religionName;

    final nationalities = _admissionList(json['nationality']);
    if (nationalities.isNotEmpty) {
      final nationality = _admissionMap(nationalities.first);
      nationalityId = _admissionInt(
        nationality?['id'] ?? nationality?['nationalityId'],
      );
      nationalityCode = _admissionText(
        nationality?['countryId'] ?? nationality?['code'],
      );
      nationalityName = _admissionText(
        nationality?['countryName'] ?? nationality?['name'],
      );
    }
    selectedLanguages
      ..clear()
      ..addAll(
        _admissionList(
          json['languageSpoken'],
        ).map(_lookupOptionFromValue).where((option) => option.name.isNotEmpty),
      );

    final contact =
        _admissionMap(json['contactInfo']) ?? _admissionMap(json['contact']);
    final phones = _admissionList(contact?['personalPhoneNumber']);
    final networks = _admissionList(contact?['phoneNetworks']);
    for (final phone in phoneNumbers) {
      phone.dispose();
    }
    phoneNumbers
      ..clear()
      ..addAll(
        List.generate(phones.isEmpty ? 1 : phones.length, (index) {
          final phone = _GuardianPhoneDraft(isPrimary: index == 0);
          if (index < phones.length) {
            phone.number.text = _admissionText(phones[index]);
          }
          if (index < networks.length) {
            phone.network = _admissionText(networks[index]);
          }
          return phone;
        }),
      );
    workPhone.text = _admissionText(contact?['workPhoneNumber']);
    workPhoneNetwork = _admissionText(contact?['workPhoneNetwork']);

    final emails = _admissionList(contact?['emails']);
    if (emails.isEmpty && _admissionText(contact?['email']).isNotEmpty) {
      emails.add(contact?['email']);
    }
    for (final email in emailAddresses) {
      email.dispose();
    }
    emailAddresses
      ..clear()
      ..addAll(
        (emails.isEmpty ? const <Object?>[''] : emails).map(
          (value) => TextEditingController(text: _admissionText(value)),
        ),
      );

    final socials = _admissionList(
      contact?['socialMediaAccount'] ??
          contact?['socialMediaAccounts'] ??
          json['socialMediaAccount'] ??
          json['socialMediaAccounts'],
    );
    for (final account in socialAccounts) {
      account.dispose();
    }
    socialAccounts
      ..clear()
      ..addAll(
        (socials.isEmpty ? const <Object?>[null] : socials).map((value) {
          final json = _admissionMap(value);
          final account = _GuardianSocialAccountDraft();
          account.platformId = _admissionInt(
            json?['socialMediaPlatformId'] ??
                _admissionMap(json?['platform'])?['id'],
          );
          account.handle.text = _admissionText(json?['url'] ?? json?['handle']);
          return account;
        }),
      );

    addressDraft.hydrate(_admissionMap(json['address']));
    final proof =
        _admissionMap(json['proofOfID']) ?? _admissionMap(json['proofOfId']);
    final proofType =
        _admissionMap(proof?['proofOfIDType']) ??
        _admissionMap(proof?['proofOfIdType']) ??
        _admissionMap(proof?['type']);
    proofOfIdTypeId = _admissionInt(
      proof?['proofOfIDTypeId'] ??
          proof?['proofOfIdTypeId'] ??
          proofType?['id'],
    );
    proofOfIdTypeName = _admissionText(
      proof?['proofOfIDTypeName'] ??
          proof?['proofOfIdTypeName'] ??
          proofType?['name'] ??
          proofType?['typeName'],
    );
    idNumber.text = _admissionText(proof?['idNumber']);
    issueDate.text = _admissionDate(proof?['issueDate']);
    expiryDate.text = _admissionDate(proof?['expirationDate']);
    final proofCountry = _admissionMap(proof?['country']);
    proofCountryId = _admissionInt(
      proof?['countryId'] ??
          proofCountry?['id'] ??
          proofCountry?['nationalityId'],
    );
    proofCountryCode = _admissionText(
      proofCountry?['countryId'] ?? proofCountry?['code'],
    );
    proofCountryName = _admissionText(
      proofCountry?['countryName'] ?? proofCountry?['name'],
    );
    final proofCity = _admissionMap(proof?['city']);
    proofLocationDraft.cityId = _admissionInt(
      proof?['cityId'] ?? proofCity?['id'],
    );
    proofLocationDraft.cityName = _admissionText(
      proofCity?['name'] ?? proof?['cityName'],
    );

    selectedOccupations
      ..clear()
      ..addAll(
        _admissionList(
          json['occupation'],
        ).map(_lookupOptionFromValue).where((option) => option.name.isNotEmpty),
      );
    selectedSkills
      ..clear()
      ..addAll(
        _admissionList(
          json['skills'],
        ).map(_lookupOptionFromValue).where((option) => option.name.isNotEmpty),
      );
  }

  void applySaved(AdmissionSavedPerson saved) {
    if (saved.customGuardianId.isNotEmpty) {
      customGuardianId = saved.customGuardianId;
    }
    householdId = saved.householdId ?? householdId;
    if (saved.admissionId.isNotEmpty) admissionId = saved.admissionId;
  }

  String requireGuardianId() {
    final id = customGuardianId;
    if (id == null || id.isEmpty) {
      throw const AdmissionsApiException('Save guardian information first.');
    }
    return id;
  }

  Map<String, dynamic> basicInfoPayload({
    required String customSchoolId,
    required int? householdId,
    required bool isPrimary,
    String? customGuardianId,
  }) {
    _requireAtLeastOne(selectedLanguages, 'Select at least one language.');
    final languages = selectedLanguages
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final payload = <String, dynamic>{
      'title': _requiredText(title.text, 'Select a title.'),
      'firstName': _requiredText(firstName.text, 'Enter guardian first name.'),
      'lastName': _requiredText(lastName.text, 'Enter guardian last name.'),
      'isPrimary': isPrimary,
      'dob': _requiredText(dob.text, 'Select guardian date of birth.'),
      'languageSpoken': languages,
      'religion': {
        'religionId': '${_requiredId(religionId, 'Select religion.')}',
        'religionName': religion.text.trim(),
      },
      'gender': {'id': _requiredId(genderId, 'Select gender.')},
      'genderId': genderId,
      'customSchoolId': customSchoolId,
      if (householdId != null) 'householdId': householdId,
      if (admissionId != null && admissionId!.isNotEmpty)
        'admissionId': admissionId,
      if (customGuardianId != null) 'customGuardianId': customGuardianId,
    };
    if (nationalityId != null) {
      payload['nationality'] = [
        {'countryId': nationalityCode ?? '$nationalityId'},
      ];
    }
    return payload;
  }

  Map<String, dynamic> contactPayload() {
    final completedPhones = phoneNumbers
        .where((phone) => phone.number.text.trim().isNotEmpty)
        .toList();
    final phones = completedPhones
        .map((phone) => phone.number.text.trim())
        .toList();
    if (phones.isEmpty && workPhone.text.trim().isEmpty) {
      throw const AdmissionsApiException(
        'Enter at least one guardian phone number.',
      );
    }
    final emails = emailAddresses
        .map((controller) => controller.text.trim())
        .where((email) => email.isNotEmpty)
        .toList();
    if (emails.isEmpty) {
      throw const AdmissionsApiException('Enter a guardian email address.');
    }
    for (final email in emails) {
      if (!_isValidEmailAddress(email)) {
        throw AdmissionsApiException('Enter a valid email address: $email');
      }
    }
    return {
      'personalPhoneNumber': phones,
      'phoneNetworks': completedPhones.map((phone) => phone.network).toList(),
      'workPhoneNumber': workPhone.text.trim(),
      'workPhoneNetwork': workPhoneNetwork,
      'email': emails.first,
      'emails': emails,
      'socialMediaAccount': socialAccounts
          .where(
            (account) =>
                account.platformId != null &&
                account.handle.text.trim().isNotEmpty,
          )
          .map(
            (account) => {
              'socialMediaPlatformId': account.platformId,
              'url': account.handle.text.trim(),
            },
          )
          .toList(),
    };
  }

  Map<String, dynamic> addressPayload() => addressDraft.payload();

  Map<String, dynamic> proofOfIdPayload() {
    final idCountry = proofCountryId ?? nationalityId;
    final payload = <String, dynamic>{
      'proofOfIDTypeId': _requiredId(
        proofOfIdTypeId,
        'Select proof of ID type.',
      ),
      'idNumber': _requiredText(idNumber.text, 'Enter ID number.'),
      'issueDate': _requiredText(issueDate.text, 'Select ID issue date.'),
      'expirationDate': _requiredText(
        expiryDate.text,
        'Select ID expiry date.',
      ),
      'countryId': _requiredId(idCountry, 'Select ID country of issue.'),
    };
    final idCity = proofLocationDraft.cityId ?? addressDraft.cityId;
    if (idCity != null) payload['cityId'] = '$idCity';
    return payload;
  }

  Map<String, dynamic> occupationPayload() {
    _requireAtLeastOne(selectedOccupations, 'Select at least one occupation.');
    return {
      'occupations': selectedOccupations
          .map((occupation) => occupation.name.trim())
          .where((occupation) => occupation.isNotEmpty)
          .toList(),
    };
  }

  Map<String, dynamic> skillsPayload() {
    return {
      'skills': selectedSkills
          .map((skill) => skill.name.trim())
          .where((skill) => skill.isNotEmpty)
          .toList(),
    };
  }

  void dispose() {
    title.dispose();
    firstName.dispose();
    lastName.dispose();
    dob.dispose();
    religion.dispose();
    for (final phone in phoneNumbers) {
      phone.dispose();
    }
    workPhone.dispose();
    for (final email in emailAddresses) {
      email.dispose();
    }
    for (final account in socialAccounts) {
      account.dispose();
    }
    idNumber.dispose();
    issueDate.dispose();
    expiryDate.dispose();
    occupationOther.dispose();
    addressDraft.dispose();
    proofLocationDraft.dispose();
  }
}

class _GuardianPhoneDraft {
  _GuardianPhoneDraft({this.isPrimary = false});

  final bool isPrimary;
  final number = TextEditingController();
  String network = '';

  void dispose() => number.dispose();
}

class _GuardianSocialAccountDraft {
  final handle = TextEditingController();
  int? platformId;

  void dispose() => handle.dispose();
}

const _otherLeavingReason = 'Other';
const _studentLeavingReasons = [
  'Relocation',
  'Transfer to another school',
  'Financial reasons',
  'Academic reasons',
  'Health reasons',
  'Family circumstances',
  'Completed previous level',
];

class _StudentAdmissionDraft {
  final firstName = TextEditingController();
  final middleName = TextEditingController();
  final lastName = TextEditingController();
  final dateOfBirth = TextEditingController();
  final religion = TextEditingController();
  final previousSchoolName = TextEditingController();
  final previousSchoolLocation = TextEditingController();
  final lastGradeAttended = TextEditingController();
  final previousSchoolFees = TextEditingController();
  final reasonForLeaving = TextEditingController();
  final skillsAndInterests = TextEditingController();
  final birthCityDraft = _AddressDraft();
  final addressDraft = _AddressDraft();

  String? customStudentId;
  int? admissionId;
  int? gradeLevelId;
  int? schoolGradeLevelId;
  int? streamId;
  int? genderId;
  int? religionId;
  int? countryOfBirthId;
  int? cityOfBirthId;
  String reasonForLeavingChoice = '';
  final selectedLanguages = <AdmissionLookupOption>[];
  final selectedSkillsAndInterests = <AdmissionLookupOption>[];
  final conditionAnswers = <int, bool>{};
  final conditionNames = <int, String>{};
  final conditionNotes = <int, TextEditingController>{};
  final foodAllergies = <String>{};
  final medicalAllergies = <String>{};
  final environmentalAllergies = <String>{};
  final vaccinationStatuses = <int, String>{};
  final vaccinationDates = <int, TextEditingController>{};
  final vaccinationNotes = <int, TextEditingController>{};
  bool firstTimeStudent = false;

  void hydrate(AdmissionStudent student) {
    final json = student.rawJson;
    customStudentId = student.customStudentId;
    admissionId = _admissionInt(json['admissionId']);
    firstName.text = _admissionText(json['firstName']);
    middleName.text = _admissionText(json['middleName']);
    lastName.text = _admissionText(json['lastName']);
    dateOfBirth.text = _admissionDate(json['dateOfBirth'] ?? json['dob']);
    genderId = _admissionInt(
      _admissionMap(json['gender'])?['id'] ?? json['genderId'],
    );
    final religionJson = _admissionMap(json['religion']);
    religionId = _admissionInt(
      religionJson?['religionId'] ?? religionJson?['id'],
    );
    religion.text = _admissionText(
      religionJson?['religionName'] ?? religionJson?['name'],
    );
    final country = _admissionMap(json['countryOfBirth']);
    countryOfBirthId = _admissionInt(
      country?['countryId'] ?? country?['id'] ?? json['countryOfBirthId'],
    );
    final birthCity = _admissionMap(json['cityOfBirth']);
    cityOfBirthId = _admissionInt(birthCity?['id'] ?? json['cityOfBirthId']);
    birthCityDraft
      ..cityId = cityOfBirthId
      ..cityName = _admissionText(
        birthCity?['name'] ?? json['cityOfBirthName'],
      );
    gradeLevelId = _admissionInt(
      json['gradeLevelId'] ?? _admissionMap(json['gradeLevel'])?['id'],
    );
    schoolGradeLevelId = _admissionInt(json['schoolGradeLevelId']);
    streamId = _admissionInt(
      json['streamId'] ?? _admissionMap(json['stream'])?['id'],
    );
    selectedLanguages
      ..clear()
      ..addAll(
        _admissionList(
          json['languageSpoken'],
        ).map(_lookupOptionFromValue).where((option) => option.name.isNotEmpty),
      );

    final address = _admissionMap(json['address']);
    addressDraft
      ..useHouseholdAddress = address == null || address.isEmpty
      ..hydrate(address);

    conditionAnswers.clear();
    conditionNames.clear();
    for (final controller in conditionNotes.values) {
      controller.dispose();
    }
    conditionNotes.clear();
    final medical = _admissionMap(json['medicalCondition']);
    for (final condition in _admissionList(medical?['medicalConditions'])) {
      final item = _admissionMap(condition);
      final id = _admissionInt(item?['conditionTypeId'] ?? item?['id']);
      if (id == null) continue;
      final value = _admissionText(item?['value']).toUpperCase();
      final yes = value == '1' || value == 'YES' || item?['value'] == true;
      conditionAnswers[id] = yes;
      conditionNames[id] = _admissionText(
        item?['conditionName'] ?? item?['name'],
      );
      if (yes && _admissionText(item?['notes']).isNotEmpty) {
        notesForCondition(id).text = _admissionText(item?['notes']);
      }
    }
    foodAllergies
      ..clear()
      ..addAll(
        _admissionList(medical?['foodAllergies'])
            .map(_admissionText)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    medicalAllergies
      ..clear()
      ..addAll(
        _admissionList(medical?['medicalAllergies'])
            .map(_admissionText)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );
    environmentalAllergies
      ..clear()
      ..addAll(
        _admissionList(medical?['environmentalAllergies'])
            .map(_admissionText)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty),
      );

    vaccinationStatuses.clear();
    for (final controller in vaccinationDates.values) {
      controller.dispose();
    }
    vaccinationDates.clear();
    for (final controller in vaccinationNotes.values) {
      controller.dispose();
    }
    vaccinationNotes.clear();
    for (final vaccination in _admissionList(json['vaccinationRecords'])) {
      final item = _admissionMap(vaccination);
      final id = _admissionInt(
        item?['vaccinationId'] ??
            item?['id'] ??
            _admissionMap(item?['vaccination'])?['id'],
      );
      if (id != null) {
        final status = _admissionText(item?['status']).toUpperCase();
        vaccinationStatuses[id] = status;
        vaccinationDateFor(id).text = status == 'YES'
            ? _admissionDate(item?['dateReceived'])
            : '';
        vaccinationNotesFor(id).text = _admissionText(item?['notes']);
      }
    }
    previousSchoolName.text = _admissionText(json['formerSchoolName']);
    previousSchoolLocation.text = _admissionText(json['formerSchoolLocation']);
    final savedReasonForLeaving = _admissionText(json['reasonForLeaving']);
    reasonForLeavingChoice =
        _studentLeavingReasons.contains(savedReasonForLeaving)
        ? savedReasonForLeaving
        : savedReasonForLeaving.isEmpty
        ? ''
        : _otherLeavingReason;
    reasonForLeaving.text = savedReasonForLeaving;
    lastGradeAttended.text = _admissionText(json['lastGradeAttended']);
    previousSchoolFees.text = _admissionText(json['previousSchoolFees']);
    skillsAndInterests.text = _admissionText(json['skillsAndInterests']);
    selectedSkillsAndInterests
      ..clear()
      ..addAll(
        skillsAndInterests.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .map((value) => AdmissionLookupOption(id: null, name: value)),
      );
    firstTimeStudent = [
      previousSchoolName.text,
      previousSchoolLocation.text,
      reasonForLeaving.text,
      lastGradeAttended.text,
      previousSchoolFees.text,
    ].every((value) => value.trim().isEmpty);
  }

  void applySaved(AdmissionSavedPerson saved) {
    if (saved.customStudentId.isNotEmpty) {
      customStudentId = saved.customStudentId;
    }
  }

  String requireStudentId() {
    final id = customStudentId;
    if (id == null || id.isEmpty) {
      throw const AdmissionsApiException('Save student information first.');
    }
    return id;
  }

  Map<String, dynamic> basicInfoPayload() {
    _requireAtLeastOne(selectedLanguages, 'Select at least one language.');
    final payload = <String, dynamic>{
      'firstName': _requiredText(firstName.text, 'Enter student first name.'),
      'middleName': middleName.text.trim(),
      'lastName': _requiredText(lastName.text, 'Enter student last name.'),
      'dateOfBirth': _requiredText(
        dateOfBirth.text,
        'Select student date of birth.',
      ),
      'gradeLevelId': _requiredId(gradeLevelId, 'Select applying grade.'),
      if (streamId != null) 'streamId': streamId,
      'genderId': _requiredId(genderId, 'Select student gender.'),
      'religionId': _requiredId(religionId, 'Select student religion.'),
      'languageSpoken': selectedLanguages
          .map((item) => item.name.trim())
          .where((name) => name.isNotEmpty)
          .toList(),
    };
    if (countryOfBirthId != null) {
      payload['countryOfBirthId'] = countryOfBirthId;
    }
    if (cityOfBirthId != null) {
      payload['cityOfBirthId'] = cityOfBirthId;
    }
    return payload;
  }

  Map<String, dynamic> medicalPayload() {
    return {
      'medicalConditions': conditionAnswers.entries
          .map(
            (entry) => {
              'conditionTypeId': entry.key,
              'conditionName': _requiredText(
                conditionNames[entry.key] ?? '',
                'A medical condition name is missing. Reload the form.',
              ),
              'value': entry.value ? '1' : '2',
              'valueDescription': entry.value ? 'Yes' : 'No',
              'notes': entry.value
                  ? (conditionNotes[entry.key]?.text.trim() ?? '')
                  : '',
            },
          )
          .toList(),
      'medicalAllergies': medicalAllergies.toList(),
      'foodAllergies': foodAllergies.toList(),
      'environmentalAllergies': environmentalAllergies.toList(),
    };
  }

  TextEditingController notesForCondition(int conditionId) {
    return conditionNotes.putIfAbsent(conditionId, TextEditingController.new);
  }

  TextEditingController vaccinationDateFor(int vaccinationId) {
    return vaccinationDates.putIfAbsent(
      vaccinationId,
      TextEditingController.new,
    );
  }

  TextEditingController vaccinationNotesFor(int vaccinationId) {
    return vaccinationNotes.putIfAbsent(
      vaccinationId,
      TextEditingController.new,
    );
  }

  Map<String, dynamic> addressPayload() {
    if (addressDraft.useHouseholdAddress) {
      return {'useHouseholdAddress': true};
    }
    final payload = addressDraft.payload();
    payload['useHouseholdAddress'] = false;
    final gps = payload.remove('gpsLocation');
    if (gps is Map<String, dynamic>) {
      payload['gpsLatitude'] = gps['latitude'];
      payload['gpsLongitude'] = gps['longitude'];
    }
    return payload;
  }

  List<Map<String, dynamic>> vaccinationPayload() {
    if (vaccinationStatuses.isEmpty) {
      throw const AdmissionsApiException(
        'Select a vaccination status before continuing.',
      );
    }
    return vaccinationStatuses.entries.map((entry) {
      final date = vaccinationDateFor(entry.key).text.trim();
      return {
        'vaccinationId': entry.key,
        'status': entry.value,
        if (entry.value == 'YES' && date.isNotEmpty) 'dateReceived': date,
        'notes': vaccinationNotesFor(entry.key).text.trim(),
      };
    }).toList();
  }

  Map<String, dynamic> previousSchoolPayload() {
    final selectedSkills = selectedSkillsAndInterests
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    skillsAndInterests.text = selectedSkills;
    if (firstTimeStudent) {
      return {
        'formerSchoolName': '',
        'formerSchoolLocation': '',
        'reasonForLeaving': '',
        'lastGradeAttended': '',
        'skillsAndInterests': selectedSkills,
      };
    }
    return {
      'formerSchoolName': previousSchoolName.text.trim(),
      'formerSchoolLocation': previousSchoolLocation.text.trim(),
      'reasonForLeaving': resolvedReasonForLeaving,
      'lastGradeAttended': lastGradeAttended.text.trim(),
      if (previousSchoolFees.text.trim().isNotEmpty)
        'previousSchoolFees':
            double.tryParse(previousSchoolFees.text.trim()) ?? 0,
      'skillsAndInterests': selectedSkills,
    };
  }

  String get resolvedReasonForLeaving {
    if (reasonForLeavingChoice == _otherLeavingReason) {
      return reasonForLeaving.text.trim();
    }
    return reasonForLeavingChoice.trim();
  }

  void dispose() {
    firstName.dispose();
    middleName.dispose();
    lastName.dispose();
    dateOfBirth.dispose();
    religion.dispose();
    previousSchoolName.dispose();
    previousSchoolLocation.dispose();
    lastGradeAttended.dispose();
    previousSchoolFees.dispose();
    reasonForLeaving.dispose();
    skillsAndInterests.dispose();
    for (final controller in conditionNotes.values) {
      controller.dispose();
    }
    for (final controller in vaccinationDates.values) {
      controller.dispose();
    }
    for (final controller in vaccinationNotes.values) {
      controller.dispose();
    }
    birthCityDraft.dispose();
    addressDraft.dispose();
  }
}

class _AddressDraft {
  final houseNumber = TextEditingController();
  final streetName = TextEditingController();
  final ghanaPostAddress = TextEditingController();
  final additionalDirections = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  String duration = '';
  bool useHouseholdAddress = true;
  int? regionId;
  int? districtId;
  int? cityId;
  String cityName = '';

  void hydrate(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return;
    final region = _admissionMap(json['region']);
    final district = _admissionMap(json['district']);
    final city = _admissionMap(json['city']);
    regionId = _admissionInt(json['regionId'] ?? region?['id']);
    districtId = _admissionInt(json['districtId'] ?? district?['id']);
    cityId = _admissionInt(json['cityId'] ?? city?['id']);
    cityName = _admissionText(city?['name'] ?? json['cityName']);
    houseNumber.text = _admissionText(json['houseNumber']);
    streetName.text = _admissionText(json['streetName']);
    ghanaPostAddress.text = _admissionText(json['ghanaPostAddress']);
    additionalDirections.text = _admissionText(
      json['additionalDirection'] ?? json['additionalDirections'],
    );
    final gps = _admissionMap(json['gpsLocation']);
    latitude.text = _admissionText(gps?['latitude'] ?? json['gpsLatitude']);
    longitude.text = _admissionText(gps?['longitude'] ?? json['gpsLongitude']);
    duration = _admissionText(json['howLongStayedInCurrentAddress']);
  }

  Map<String, dynamic> payload() {
    return {
      'districtId': _requiredId(districtId, 'Select district.'),
      'cityId': _requiredId(cityId, 'Select a city from the suggestions.'),
      'regionId': _requiredId(regionId, 'Select region.'),
      'houseNumber': _requiredText(houseNumber.text, 'Enter house number.'),
      'streetName': _requiredText(streetName.text, 'Enter street name.'),
      'additionalDirection': _requiredText(
        additionalDirections.text,
        'Enter additional directions.',
      ),
      'ghanaPostAddress': _requiredText(
        ghanaPostAddress.text,
        'Enter Ghana Post address.',
      ),
      'gpsLocation': {
        'latitude': double.tryParse(latitude.text.trim()) ?? 0,
        'longitude': double.tryParse(longitude.text.trim()) ?? 0,
      },
      'howLongStayedInCurrentAddress': _requiredText(
        duration,
        'Select how long the guardian has stayed at this address.',
      ),
    };
  }

  void dispose() {
    houseNumber.dispose();
    streetName.dispose();
    ghanaPostAddress.dispose();
    additionalDirections.dispose();
    latitude.dispose();
    longitude.dispose();
  }
}

String _requiredText(String value, String message) {
  final clean = value.trim();
  if (clean.isEmpty) {
    throw AdmissionsApiException(message);
  }
  return clean;
}

bool _isValidEmailAddress(String value) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
}

int _requiredId(int? value, String message) {
  if (value == null) {
    throw AdmissionsApiException(message);
  }
  return value;
}

void _requireAtLeastOne(List<Object> value, String message) {
  if (value.isEmpty) {
    throw AdmissionsApiException(message);
  }
}

Map<String, dynamic>? _admissionMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return null;
}

List<Object?> _admissionList(Object? value) {
  if (value is List) return List<Object?>.from(value);
  if (value == null) return <Object?>[];
  return <Object?>[value];
}

String _admissionText(Object? value) {
  if (value == null) return '';
  final text = '$value'.trim();
  return text.toLowerCase() == 'null' ? '' : text;
}

int? _admissionInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_admissionText(value));
}

String _admissionDate(Object? value) {
  if (value is List && value.length >= 3) {
    final year = _admissionInt(value[0]);
    final month = _admissionInt(value[1]);
    final day = _admissionInt(value[2]);
    if (year != null && month != null && day != null) {
      return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
  }
  final text = _admissionText(value);
  return text.contains('T') ? text.split('T').first : text;
}

AdmissionLookupOption _lookupOptionFromValue(Object? value) {
  final json = _admissionMap(value);
  if (json != null) return AdmissionLookupOption.fromJson(json);
  return AdmissionLookupOption(id: null, name: _admissionText(value));
}

class _AdmissionSideDrawerState extends State<_AdmissionSideDrawer> {
  int _step = 0;
  bool _saving = false;
  String? _formError;
  final _fieldErrors = <String, String>{};
  final _contentScrollController = ScrollController();
  late final _GuardianAdmissionDraft _guardianDraft;
  late final _StudentAdmissionDraft _studentDraft;

  late final List<_AdmissionFormStep> _steps = switch (widget.flow) {
    _AdmissionFlowKind.primaryGuardian ||
    _AdmissionFlowKind.additionalGuardian => const [
      _AdmissionFormStep('Guardian info', 'Basic details'),
      _AdmissionFormStep('Guardian contact', 'Phone and email'),
      _AdmissionFormStep('Guardian address', 'Household location'),
      _AdmissionFormStep('Guardian ID', 'Proof of ID'),
      _AdmissionFormStep('Occupation & skills', 'Work and skills'),
    ],
    _AdmissionFlowKind.student => const [
      _AdmissionFormStep('Basic Info', 'Student and class details'),
      _AdmissionFormStep('Student Address', 'Where the student lives'),
      _AdmissionFormStep('Medical', 'Health conditions and allergies'),
      _AdmissionFormStep('Vaccinations', 'Vaccination records'),
      _AdmissionFormStep('School History', 'Previous school details'),
      _AdmissionFormStep('Documents', 'Required documents'),
    ],
  };

  bool get _isFirst => _step == 0;
  bool get _isLast => _step == _steps.length - 1;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(0, _steps.length - 1).toInt();
    _guardianDraft = _GuardianAdmissionDraft();
    _studentDraft = _StudentAdmissionDraft();
    final guardian = widget.existingGuardian;
    if (guardian != null) _guardianDraft.hydrate(guardian);
    final student = widget.existingStudent;
    if (student != null) _studentDraft.hydrate(student);
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    _guardianDraft.dispose();
    _studentDraft.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_saving) return;
    final valid = widget.flow == _AdmissionFlowKind.student
        ? _validateStudentStep()
        : _validateGuardianStep();
    if (!valid) {
      _contentScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
      _fieldErrors.clear();
    });
    try {
      await _saveCurrentStep();
      if (!mounted) return;
      if (_isLast) {
        widget.onSaved(_guardianDraft.householdId ?? widget.householdId);
        Navigator.of(context).pop();
        return;
      }
      setState(() => _step++);
    } on AdmissionsApiException catch (error) {
      if (!mounted) return;
      setState(() => _formError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _formError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validateStudentStep() {
    final errors = <String, String>{};
    switch (_step) {
      case 0:
        if (_studentDraft.gradeLevelId == null) {
          errors['grade'] = 'Select the grade the student is applying for.';
        }
        if (_studentDraft.firstName.text.trim().isEmpty) {
          errors['firstName'] = 'Enter the student\'s first name.';
        }
        if (_studentDraft.lastName.text.trim().isEmpty) {
          errors['lastName'] = 'Enter the student\'s last name.';
        }
        if (_studentDraft.dateOfBirth.text.trim().isEmpty) {
          errors['dateOfBirth'] = 'Select the student\'s date of birth.';
        }
        if (_studentDraft.genderId == null) {
          errors['gender'] = 'Select the student\'s gender.';
        }
        if (_studentDraft.religionId == null) {
          errors['religion'] = 'Select the student\'s religion.';
        }
        if (_studentDraft.selectedLanguages.isEmpty) {
          errors['languages'] = 'Select at least one language.';
        }
      case 3:
        if (_studentDraft.vaccinationStatuses.isEmpty) {
          errors['vaccinations'] =
              'Select a status for at least one vaccination.';
        }
      case 4:
        if (!_studentDraft.firstTimeStudent) {
          if (_studentDraft.previousSchoolName.text.trim().isEmpty) {
            errors['previousSchoolName'] = 'Enter the previous school name.';
          }
          if (_studentDraft.lastGradeAttended.text.trim().isEmpty) {
            errors['lastGrade'] = 'Select the last grade attended.';
          }
          if (_studentDraft.previousSchoolFees.text.trim().isEmpty) {
            errors['previousSchoolFees'] = 'Enter the previous school fees.';
          }
          if (_studentDraft.previousSchoolLocation.text.trim().isEmpty) {
            errors['previousSchoolLocation'] =
                'Enter the previous school address.';
          }
          if (_studentDraft.reasonForLeavingChoice.isEmpty) {
            errors['reasonForLeaving'] =
                'Select the reason the student left the previous school.';
          }
          if (_studentDraft.reasonForLeavingChoice == _otherLeavingReason &&
              _studentDraft.reasonForLeaving.text.trim().isEmpty) {
            errors['reasonForLeavingNote'] =
                'Enter the student\'s reason for leaving.';
          }
        }
    }
    if (errors.isEmpty) return true;
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _formError = errors.values.first;
    });
    return false;
  }

  bool _validateGuardianStep() {
    final errors = <String, String>{};
    switch (_step) {
      case 0:
        if (_guardianDraft.title.text.trim().isEmpty) {
          errors['title'] = 'Select the guardian\'s title.';
        }
        if (_guardianDraft.genderId == null) {
          errors['gender'] = 'Select the guardian\'s gender.';
        }
        if (_guardianDraft.firstName.text.trim().isEmpty) {
          errors['firstName'] = 'Enter the guardian\'s first name.';
        }
        if (_guardianDraft.lastName.text.trim().isEmpty) {
          errors['lastName'] = 'Enter the guardian\'s last name.';
        }
        if (_guardianDraft.dob.text.trim().isEmpty) {
          errors['dateOfBirth'] = 'Select the guardian\'s date of birth.';
        }
        if (_guardianDraft.relationship.trim().isEmpty ||
            _guardianDraft.relationship == 'Select relationship') {
          errors['relationship'] = 'Select the guardian\'s relationship.';
        }
        if (_guardianDraft.nationalityId == null) {
          errors['nationality'] = 'Select the guardian\'s nationality.';
        }
        if (_guardianDraft.religionId == null) {
          errors['religion'] = 'Select the guardian\'s religion.';
        }
        if (_guardianDraft.selectedLanguages.isEmpty) {
          errors['languages'] = 'Select at least one language.';
        }
      case 1:
        final personalPhones = _guardianDraft.phoneNumbers
            .where((phone) => phone.number.text.trim().isNotEmpty)
            .toList();
        if (personalPhones.isEmpty &&
            _guardianDraft.workPhone.text.trim().isEmpty) {
          errors['phones'] = 'Enter at least one guardian phone number.';
        }
        if (personalPhones.any((phone) => phone.network.trim().isEmpty)) {
          errors['phones'] = 'Select a network for every phone number.';
        }
        final emails = _guardianDraft.emailAddresses
            .map((controller) => controller.text.trim())
            .where((email) => email.isNotEmpty)
            .toList();
        if (emails.isEmpty) {
          errors['emails'] = 'Enter a guardian email address.';
        } else if (emails.any((email) => !_isValidEmailAddress(email))) {
          errors['emails'] = 'Enter a valid email address.';
        }
        final incompleteSocial = _guardianDraft.socialAccounts.any((account) {
          final hasPlatform = account.platformId != null;
          final hasHandle = account.handle.text.trim().isNotEmpty;
          return hasPlatform != hasHandle;
        });
        if (incompleteSocial) {
          errors['socialMedia'] =
              'Select a platform and enter its handle or URL.';
        }
      case 2:
        final address = _guardianDraft.addressDraft;
        if (address.regionId == null) errors['region'] = 'Select a region.';
        if (address.districtId == null) {
          errors['district'] = 'Select a district.';
        }
        if (address.cityId == null) {
          errors['city'] = 'Select a city from the suggestions.';
        }
        if (address.houseNumber.text.trim().isEmpty) {
          errors['houseNumber'] = 'Enter the house number.';
        }
        if (address.streetName.text.trim().isEmpty) {
          errors['streetName'] = 'Enter the street name.';
        }
        if (address.ghanaPostAddress.text.trim().isEmpty) {
          errors['ghanaPostAddress'] = 'Enter the Ghana Post address.';
        }
        if (address.additionalDirections.text.trim().isEmpty) {
          errors['additionalDirections'] = 'Enter additional directions.';
        }
        if (address.duration.trim().isEmpty) {
          errors['duration'] = 'Select how long the guardian has lived here.';
        }
      case 3:
        if (_guardianDraft.proofOfIdTypeId == null) {
          errors['proofOfIdType'] = 'Select the ID type.';
        }
        if (_guardianDraft.idNumber.text.trim().isEmpty) {
          errors['idNumber'] = 'Enter the ID number.';
        }
        if (_guardianDraft.issueDate.text.trim().isEmpty) {
          errors['issueDate'] = 'Select the ID issue date.';
        }
        if (_guardianDraft.expiryDate.text.trim().isEmpty) {
          errors['expiryDate'] = 'Select the ID expiry date.';
        }
        if (_guardianDraft.proofCountryId == null) {
          errors['proofCountry'] = 'Select the country of issue.';
        }
        if (_guardianDraft.proofLocationDraft.cityId == null &&
            _guardianDraft.addressDraft.cityId == null) {
          errors['proofCity'] = 'Select the city of issue.';
        }
      case 4:
        if (_guardianDraft.selectedOccupations.isEmpty) {
          errors['occupations'] = 'Select at least one occupation.';
        }
    }
    if (errors.isEmpty) return true;
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors);
      _formError = errors.values.first;
    });
    return false;
  }

  Future<void> _saveCurrentStep() async {
    if (widget.flow == _AdmissionFlowKind.student) {
      await _saveStudentStep();
    } else {
      await _saveGuardianStep();
    }
  }

  Future<void> _saveGuardianStep() async {
    final customGuardianId = _guardianDraft.customGuardianId;
    switch (_step) {
      case 0:
        final saved = customGuardianId == null
            ? await widget.api.createGuardian(
                additionalGuardian:
                    widget.flow == _AdmissionFlowKind.additionalGuardian,
                customSchoolId: widget.customSchoolId,
                householdId: widget.householdId,
                body: _guardianDraft.basicInfoPayload(
                  customSchoolId: widget.customSchoolId,
                  householdId: widget.householdId,
                  isPrimary: widget.flow == _AdmissionFlowKind.primaryGuardian,
                ),
              )
            : await widget.api.updateGuardianStep(
                customSchoolId: widget.customSchoolId,
                customGuardianId: customGuardianId,
                step: 'basic-info',
                body: _guardianDraft.basicInfoPayload(
                  customSchoolId: widget.customSchoolId,
                  householdId: widget.householdId ?? _guardianDraft.householdId,
                  isPrimary: widget.flow == _AdmissionFlowKind.primaryGuardian,
                  customGuardianId: customGuardianId,
                ),
              );
        _guardianDraft.applySaved(saved);
      case 1:
        await widget.api.updateGuardianStep(
          customSchoolId: widget.customSchoolId,
          customGuardianId: _guardianDraft.requireGuardianId(),
          step: 'contact-info',
          body: _guardianDraft.contactPayload(),
        );
      case 2:
        await widget.api.updateGuardianStep(
          customSchoolId: widget.customSchoolId,
          customGuardianId: _guardianDraft.requireGuardianId(),
          step: 'address',
          body: _guardianDraft.addressPayload(),
        );
      case 3:
        await widget.api.updateGuardianStep(
          customSchoolId: widget.customSchoolId,
          customGuardianId: _guardianDraft.requireGuardianId(),
          step: 'proof-of-id',
          body: _guardianDraft.proofOfIdPayload(),
        );
      case 4:
        final guardianId = _guardianDraft.requireGuardianId();
        await widget.api.updateGuardianStep(
          customSchoolId: widget.customSchoolId,
          customGuardianId: guardianId,
          step: 'occupation',
          body: _guardianDraft.occupationPayload(),
        );
        await widget.api.updateGuardianStep(
          customSchoolId: widget.customSchoolId,
          customGuardianId: guardianId,
          step: 'skills',
          body: _guardianDraft.skillsPayload(),
        );
        await widget.api.completeGuardianReview(
          customSchoolId: widget.customSchoolId,
          customGuardianId: guardianId,
        );
    }
  }

  Future<void> _saveStudentStep() async {
    final householdId = widget.householdId ?? _guardianDraft.householdId;
    if (householdId == null) {
      throw const AdmissionsApiException(
        'Create or open a household before adding a student.',
      );
    }
    final customStudentId = _studentDraft.customStudentId;
    switch (_step) {
      case 0:
        final body = _studentDraft.basicInfoPayload();
        final saved = customStudentId == null
            ? await widget.api.createStudent(
                customSchoolId: widget.customSchoolId,
                householdId: householdId,
                body: body,
              )
            : await widget.api.updateStudentBasicInfo(
                customSchoolId: widget.customSchoolId,
                householdId: householdId,
                customStudentId: customStudentId,
                body: body,
              );
        _studentDraft.applySaved(saved);
        // The creation endpoint does not currently persist religion and
        // languages. Apply the complete basic-info contract immediately so a
        // newly created draft hydrates exactly like a later edit.
        if (customStudentId == null) {
          await widget.api.updateStudentBasicInfo(
            customSchoolId: widget.customSchoolId,
            householdId: householdId,
            customStudentId: _studentDraft.requireStudentId(),
            body: body,
          );
        }
      case 1:
        await widget.api.updateStudentAddress(
          customSchoolId: widget.customSchoolId,
          householdId: householdId,
          customStudentId: _studentDraft.requireStudentId(),
          body: _studentDraft.addressPayload(),
        );
      case 2:
        await widget.api.updateStudentMedicalCondition(
          customSchoolId: widget.customSchoolId,
          householdId: householdId,
          customStudentId: _studentDraft.requireStudentId(),
          body: _studentDraft.medicalPayload(),
        );
      case 3:
        await widget.api.updateStudentVaccinations(
          customSchoolId: widget.customSchoolId,
          householdId: householdId,
          customStudentId: _studentDraft.requireStudentId(),
          body: _studentDraft.vaccinationPayload(),
        );
      case 4:
        await widget.api.updateStudentPreviousSchool(
          customSchoolId: widget.customSchoolId,
          customStudentId: _studentDraft.requireStudentId(),
          body: _studentDraft.previousSchoolPayload(),
        );
      case 5:
        final studentId = _studentDraft.requireStudentId();
        await widget.api.completeStudentDocuments(
          customSchoolId: widget.customSchoolId,
          customStudentId: studentId,
        );
        await widget.api.completeStudentReview(
          customSchoolId: widget.customSchoolId,
          customStudentId: studentId,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.flow == _AdmissionFlowKind.student
        ? widget.existingStudent == null
              ? 'Add Student'
              : 'Edit Student'
        : widget.existingGuardian == null
        ? 'Add Guardian'
        : 'Edit Guardian';
    return Material(
      color: const Color(0xFFF8FAFB),
      child: SizedBox(
        width: 520,
        height: double.infinity,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Step ${_step + 1} of ${_steps.length} — ${_steps[_step].title}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F6F8),
                      foregroundColor: AppColors.muted,
                      fixedSize: const Size(34, 34),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _DrawerStepStrip(steps: _steps, current: _step),
            Expanded(
              child: SingleChildScrollView(
                controller: _contentScrollController,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
                child: Column(
                  children: [
                    if (_formError != null) ...[
                      _LookupErrorBox(message: _formError!),
                      const SizedBox(height: 12),
                    ],
                    _buildStepContent(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text(
                    '${_step + 1} / ${_steps.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (!_isFirst)
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _step--;
                        _formError = null;
                        _fieldErrors.clear();
                      }),
                      child: const Text('Back'),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _next,
                    icon: Icon(
                      _saving
                          ? Icons.hourglass_top_rounded
                          : _isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : (_isLast
                                ? widget.flow == _AdmissionFlowKind.student
                                      ? 'Submit application'
                                      : 'Save guardian'
                                : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final title = _steps[_step].title;
    return switch (title) {
      'Guardian info' => _GuardianBasicInfoForm(
        api: widget.api,
        draft: _guardianDraft,
        errors: _fieldErrors,
      ),
      'Guardian contact' => _GuardianContactForm(
        api: widget.api,
        draft: _guardianDraft,
        errors: _fieldErrors,
      ),
      'Guardian address' => _AddressForm(
        owner: 'guardian household',
        includeDuration: true,
        api: widget.api,
        draft: _guardianDraft.addressDraft,
        errors: _fieldErrors,
      ),
      'Guardian ID' => _GuardianProofOfIdForm(
        api: widget.api,
        draft: _guardianDraft,
        errors: _fieldErrors,
      ),
      'Occupation & skills' => _GuardianWorkSkillsForm(
        api: widget.api,
        draft: _guardianDraft,
        errors: _fieldErrors,
      ),
      'Basic Info' => _StudentBasicInfoForm(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        draft: _studentDraft,
        errors: _fieldErrors,
      ),
      'Student Address' => _AddressForm(
        owner: 'student',
        includeDuration: true,
        api: widget.api,
        draft: _studentDraft.addressDraft,
      ),
      'Medical' => _StudentMedicalForm(api: widget.api, draft: _studentDraft),
      'Vaccinations' => _StudentVaccinationForm(
        api: widget.api,
        draft: _studentDraft,
        errorText: _fieldErrors['vaccinations'],
      ),
      'School History' => _PreviousSchoolForm(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        draft: _studentDraft,
        errors: _fieldErrors,
      ),
      'Documents' => _StudentDocumentsForm(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        customStudentId: _studentDraft.requireStudentId(),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _DrawerStepStrip extends StatelessWidget {
  const _DrawerStepStrip({required this.steps, required this.current});

  final List<_AdmissionFormStep> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            for (var index = 0; index < steps.length; index++) ...[
              _DrawerStepPill(
                index: index,
                label: steps[index].title,
                active: index == current,
                done: index < current,
              ),
              if (index < steps.length - 1)
                Container(
                  width: 18,
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: index < current
                      ? AppColors.green
                      : const Color(0xFFD7E0E7),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerStepPill extends StatelessWidget {
  const _DrawerStepPill({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final activeOrDone = active || done;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: activeOrDone ? AppColors.green : Colors.white,
            border: Border.all(
              color: activeOrDone ? AppColors.green : const Color(0xFFD7E0E7),
              width: 1.4,
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: active ? AppColors.green : AppColors.muted,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Kept briefly while the admissions household screen settles into the new
// workspace design.
// ignore: unused_element
class _HouseholdHeroCard extends StatelessWidget {
  const _HouseholdHeroCard({required this.household});

  final _HouseholdRecord household;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 18,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.home_work_rounded,
                color: AppColors.green,
                size: 34,
              ),
            ),
            SizedBox(
              width: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    household.householdName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${household.primaryGuardian} · ${household.phone} · Started ${household.started}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (household.isPreview) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Preview household: use Add student to inspect the student admission form fields.',
                      style: TextStyle(
                        color: AppColors.amber,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _StatusPill(label: household.status, color: household.statusColor),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _HouseholdActionCards extends StatelessWidget {
  const _HouseholdActionCards({
    required this.household,
    required this.customSchoolId,
    required this.api,
  });

  final _HouseholdRecord household;
  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveCardGrid(
      children: [
        _HouseholdActionCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Add guardian',
          subtitle: 'Add another parent or guardian to this household.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _AdmissionFlowScreen(
                flow: _AdmissionFlowKind.additionalGuardian,
                householdName: household.householdName,
                householdId: household.householdId,
                customSchoolId: customSchoolId,
                api: api,
              ),
            ),
          ),
        ),
        _HouseholdActionCard(
          icon: Icons.school_rounded,
          title: 'Add student',
          subtitle:
              'Start a separate student application under this household.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _AdmissionFlowScreen(
                flow: _AdmissionFlowKind.student,
                householdName: household.householdName,
                householdId: household.householdId,
                customSchoolId: customSchoolId,
                api: api,
              ),
            ),
          ),
        ),
        _HouseholdActionCard(
          icon: Icons.fact_check_rounded,
          title: 'Review household',
          subtitle: 'Check guardian and student setup before approval.',
          onTap: () {},
        ),
      ],
    );
  }
}

class _HouseholdActionCard extends StatelessWidget {
  const _HouseholdActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.green),
              ),
              const SizedBox(width: 14),
              Expanded(child: _TwoLine(title, subtitle)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _HouseholdDashboardGrid extends StatelessWidget {
  const _HouseholdDashboardGrid({
    required this.household,
    required this.guardians,
    required this.students,
  });

  final _HouseholdRecord household;
  final List<AdmissionGuardian> guardians;
  final List<AdmissionStudent> students;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 980;
        final guardianPanel = _HouseholdGuardiansPanel(guardians: guardians);
        final studentPanel = _HouseholdStudentsPanel(students: students);
        if (!twoColumns) {
          return Column(
            children: [guardianPanel, const SizedBox(height: 18), studentPanel],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: guardianPanel),
            const SizedBox(width: 18),
            Expanded(child: studentPanel),
          ],
        );
      },
    );
  }
}

class _HouseholdGuardiansPanel extends StatelessWidget {
  const _HouseholdGuardiansPanel({required this.guardians});

  final List<AdmissionGuardian> guardians;

  @override
  Widget build(BuildContext context) {
    final members = guardians.map((guardian) {
      return _HouseholdMember(
        name: guardian.displayName,
        subtitle:
            '${guardian.phone.isEmpty ? 'No phone yet' : guardian.phone} · ${guardian.isPrimary ? 'Primary guardian' : 'Additional guardian'}',
        status: _guardianStatusLabel(guardian.status),
        color: _guardianStatusColor(guardian.status),
      );
    }).toList();
    return _HouseholdPanel(
      title: 'Guardians',
      subtitle: '${members.length} guardian record(s)',
      emptyTitle: 'No guardians yet',
      emptySubtitle: 'Guardians will appear here after they are created.',
      children: members
          .map((guardian) => _HouseholdMemberRow(member: guardian))
          .toList(),
    );
  }
}

class _HouseholdStudentsPanel extends StatelessWidget {
  const _HouseholdStudentsPanel({required this.students});

  final List<AdmissionStudent> students;

  @override
  Widget build(BuildContext context) {
    final members = students.map((student) {
      return _HouseholdMember(
        name: student.displayName,
        subtitle:
            '${student.customStudentId.isEmpty ? 'Student ID pending' : student.customStudentId} · ${student.gradeLevel.isEmpty ? 'Class pending' : student.gradeLevel}',
        status: _studentStatusLabel(student.status),
        color: _studentStatusColor(student.status),
      );
    }).toList();
    return _HouseholdPanel(
      title: 'Students / applications',
      subtitle: '${members.length} student application(s)',
      emptyTitle: 'No students added yet',
      emptySubtitle: 'Use Add student to start a separate student application.',
      children: members
          .map((student) => _HouseholdMemberRow(member: student))
          .toList(),
    );
  }
}

class _HouseholdPanel extends StatelessWidget {
  const _HouseholdPanel({
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [Expanded(child: _TwoLine(title, subtitle))]),
          ),
          const Divider(height: 1),
          if (children.isEmpty)
            _EmptyState(title: emptyTitle, subtitle: emptySubtitle)
          else
            ...children,
        ],
      ),
    );
  }
}

class _HouseholdMemberRow extends StatelessWidget {
  const _HouseholdMemberRow({required this.member});

  final _HouseholdMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.greenSoft,
            child: Text(
              _initials(member.name),
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _TwoLine(member.name, member.subtitle)),
          _StatusPill(label: member.status, color: member.color),
        ],
      ),
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '-';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}

class _AdmissionFlowScreen extends StatefulWidget {
  const _AdmissionFlowScreen({
    required this.flow,
    required this.householdName,
    required this.customSchoolId,
    required this.api,
    this.householdId,
  });

  final _AdmissionFlowKind flow;
  final String householdName;
  final String customSchoolId;
  final AdmissionsApiClient api;
  final int? householdId;

  @override
  State<_AdmissionFlowScreen> createState() => _AdmissionFlowScreenState();
}

class _AdmissionFlowScreenState extends State<_AdmissionFlowScreen> {
  int _step = 0;
  late final _GuardianAdmissionDraft _guardianDraft = _GuardianAdmissionDraft();
  late final _StudentAdmissionDraft _studentDraft = _StudentAdmissionDraft();

  @override
  void dispose() {
    _guardianDraft.dispose();
    _studentDraft.dispose();
    super.dispose();
  }

  late final List<_AdmissionFormStep> _steps = switch (widget.flow) {
    _AdmissionFlowKind.primaryGuardian ||
    _AdmissionFlowKind.additionalGuardian => const [
      _AdmissionFormStep('Guardian info', 'Primary guardian details'),
      _AdmissionFormStep('Guardian contact', 'Phone, email, and socials'),
      _AdmissionFormStep('Guardian address', 'Household location'),
      _AdmissionFormStep('Guardian ID', 'Proof of identification'),
      _AdmissionFormStep('Occupation & skills', 'Work and useful skills'),
      _AdmissionFormStep('Review', 'Confirm guardian details'),
    ],
    _AdmissionFlowKind.student => const [
      _AdmissionFormStep('Student info', 'Student and class details'),
      _AdmissionFormStep('Student address', 'Where the student lives'),
      _AdmissionFormStep('Medical', 'Allergies and medical notes'),
      _AdmissionFormStep('Vaccination', 'Vaccination records'),
      _AdmissionFormStep('Previous school', 'Transfer history'),
      _AdmissionFormStep('Documents', 'Required student documents'),
      _AdmissionFormStep('Review', 'Confirm student application'),
    ],
  };

  bool get _isFirst => _step == 0;
  bool get _isLast => _step == _steps.length - 1;

  void _next() {
    if (_isLast) {
      if (widget.flow == _AdmissionFlowKind.primaryGuardian) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => _HouseholdDashboardScreen(
              household: _HouseholdRecord(
                householdId: widget.householdId,
                householdName: 'New Household',
                primaryGuardian: 'New guardian',
                phone: 'Phone pending',
                status: 'Ready for student',
                statusColor: AppColors.green,
                students: 0,
                pendingGuardians: 0,
                started: 'Today',
              ),
              customSchoolId: widget.customSchoolId,
              api: widget.api,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_isFirst) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _AdmissionFlowTopBar(
              title: _flowTitle,
              subtitle:
                  '${widget.householdName} · 2026/2027 Academic Year · Term 1 · 15th July 2026 to 18th December 2026',
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 880;
                  final content = _StepFormCard(
                    title: _steps[_step].title,
                    subtitle: _steps[_step].subtitle,
                    child: _buildStepContent(),
                  );
                  if (compact) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _CompactStepIndicator(
                            current: _step,
                            total: _steps.length,
                            label: _steps[_step].title,
                          ),
                          const SizedBox(height: 14),
                          content,
                        ],
                      ),
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 300,
                        child: _AdmissionStepRail(
                          steps: _steps,
                          currentStep: _step,
                          onStepSelected: (index) =>
                              setState(() => _step = index),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 32, 120),
                          child: content,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _AdmissionActionBar(
              isFirst: _isFirst,
              isLast: _isLast,
              lastLabel: _lastActionLabel,
              onBack: _back,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    final title = _steps[_step].title;
    return switch (title) {
      'Guardian info' => _GuardianBasicInfoForm(
        api: widget.api,
        draft: _guardianDraft,
      ),
      'Guardian contact' => _GuardianContactForm(
        api: widget.api,
        draft: _guardianDraft,
      ),
      'Guardian address' => _AddressForm(
        owner: 'guardian household',
        includeDuration: true,
        api: widget.api,
        draft: _guardianDraft.addressDraft,
      ),
      'Guardian ID' => _GuardianProofOfIdForm(
        api: widget.api,
        draft: _guardianDraft,
      ),
      'Occupation & skills' => _GuardianWorkSkillsForm(
        api: widget.api,
        draft: _guardianDraft,
      ),
      'Student info' => _StudentBasicInfoForm(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        draft: _studentDraft,
        errors: const {},
      ),
      'Student address' => _AddressForm(
        owner: 'student',
        includeDuration: true,
        api: widget.api,
        draft: _studentDraft.addressDraft,
      ),
      'Medical' => _StudentMedicalForm(api: widget.api, draft: _studentDraft),
      'Vaccination' => _StudentVaccinationForm(
        api: widget.api,
        draft: _studentDraft,
      ),
      'Previous school' => _PreviousSchoolForm(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        draft: _studentDraft,
        errors: const {},
      ),
      'Documents' => _StudentDocumentsForm(
        api: widget.api,
        customSchoolId: widget.customSchoolId,
        customStudentId: _studentDraft.customStudentId ?? '',
      ),
      'Review' => _AdmissionReviewForm(
        flow: widget.flow,
        householdName: widget.householdName,
        totalSteps: _steps.length,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  String get _flowTitle {
    return switch (widget.flow) {
      _AdmissionFlowKind.primaryGuardian => 'Create household guardian',
      _AdmissionFlowKind.additionalGuardian => 'Add guardian',
      _AdmissionFlowKind.student => 'Add student application',
    };
  }

  String get _lastActionLabel {
    return switch (widget.flow) {
      _AdmissionFlowKind.primaryGuardian => 'Create household',
      _AdmissionFlowKind.additionalGuardian => 'Save guardian',
      _AdmissionFlowKind.student => 'Submit application',
    };
  }
}

class _AdmissionFormStep {
  const _AdmissionFormStep(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

class _AdmissionFlowTopBar extends StatelessWidget {
  const _AdmissionFlowTopBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdmissionStepRail extends StatelessWidget {
  const _AdmissionStepRail({
    required this.steps,
    required this.currentStep,
    required this.onStepSelected,
  });

  final List<_AdmissionFormStep> steps;
  final int currentStep;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: steps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final step = steps[index];
          final active = index == currentStep;
          final done = index < currentStep;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onStepSelected(index),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active ? AppColors.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? AppColors.green : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: done || active
                        ? AppColors.green
                        : const Color(0xFFE8EEF0),
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: active ? Colors.white : AppColors.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: TextStyle(
                            color: active ? AppColors.green : AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompactStepIndicator extends StatelessWidget {
  const _CompactStepIndicator({
    required this.current,
    required this.total,
    required this.label,
  });

  final int current;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              'Step ${current + 1} of $total',
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _StepFormCard extends StatelessWidget {
  const _StepFormCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _AdmissionActionBar extends StatelessWidget {
  const _AdmissionActionBar({
    required this.isFirst,
    required this.isLast,
    required this.lastLabel,
    required this.onBack,
    required this.onNext,
  });

  final bool isFirst;
  final bool isLast;
  final String lastLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: onBack,
            child: Text(isFirst ? 'Cancel' : 'Back'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onNext,
            icon: Icon(
              isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
            ),
            label: Text(isLast ? lastLabel : 'Save and continue'),
          ),
        ],
      ),
    );
  }
}

class _ExistingHouseholdSearchForm extends StatefulWidget {
  const _ExistingHouseholdSearchForm({
    required this.households,
    required this.onSelected,
  });

  final List<_HouseholdRecord> households;
  final ValueChanged<_HouseholdRecord> onSelected;

  @override
  State<_ExistingHouseholdSearchForm> createState() =>
      _ExistingHouseholdSearchFormState();
}

class _ExistingHouseholdSearchFormState
    extends State<_ExistingHouseholdSearchForm> {
  String _query = '';

  List<_HouseholdRecord> get _visibleHouseholds {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.households;
    return widget.households.where((household) {
      return household.householdName.toLowerCase().contains(query) ||
          household.primaryGuardian.toLowerCase().contains(query) ||
          household.phone.toLowerCase().contains(query) ||
          (household.householdId?.toString().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final households = _visibleHouseholds;
    return Column(
      children: [
        _Field(
          label: 'Search household',
          hint: 'Guardian name, phone number, or household ID',
          icon: Icons.search_rounded,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 16),
        if (households.isEmpty)
          const _EmptyState(
            title: 'No household found',
            subtitle:
                'Create a new household if this guardian is not already registered.',
          )
        else
          ...households.map(
            (household) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HouseholdSearchResult(
                household: household.householdName,
                guardian: household.primaryGuardian,
                phone: household.phone,
                students: '${household.students} student(s)',
                onTap: () => widget.onSelected(household),
              ),
            ),
          ),
      ],
    );
  }
}

class _HouseholdSearchResult extends StatelessWidget {
  const _HouseholdSearchResult({
    required this.household,
    required this.guardian,
    required this.phone,
    required this.students,
    required this.onTap,
  });

  final String household;
  final String guardian;
  final String phone;
  final String students;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFB),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.greenSoft,
              child: Icon(Icons.home_rounded, color: AppColors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _TwoLine(household, '$guardian · $phone · $students'),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _GuardianBasicInfoForm extends StatefulWidget {
  const _GuardianBasicInfoForm({
    required this.api,
    required this.draft,
    this.errors = const {},
  });

  final AdmissionsApiClient api;
  final _GuardianAdmissionDraft draft;
  final Map<String, String> errors;

  @override
  State<_GuardianBasicInfoForm> createState() => _GuardianBasicInfoFormState();
}

class _GuardianBasicInfoFormState extends State<_GuardianBasicInfoForm> {
  late final Future<List<AdmissionLookupOption>> _gendersFuture;
  late final Future<List<AdmissionLookupOption>> _nationalitiesFuture;
  late final Future<List<AdmissionLookupOption>> _religionsFuture;
  late final Future<List<AdmissionLookupOption>> _languagesFuture;

  static const _titles = ['Select title', 'Mr.', 'Mrs.', 'Ms.', 'Dr.'];
  static const _relationships = [
    'Select relationship',
    'Parent',
    'Father',
    'Mother',
    'Guardian',
    'Aunt',
    'Uncle',
  ];

  @override
  void initState() {
    super.initState();
    _gendersFuture = widget.api.getGenders();
    _nationalitiesFuture = widget.api.getNationalities();
    _religionsFuture = widget.api.getReligions();
    _languagesFuture = widget.api.getLanguages();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Column(
      children: [
        _DrawerFormSection(
          title: 'Personal Information',
          child: _ResponsiveFormGrid(
            children: [
              _SelectField(
                label: 'Title',
                value: 'Select title',
                options: _titles,
                selectedValue: draft.title.text.isEmpty
                    ? 'Select title'
                    : draft.title.text,
                onChanged: (value) => draft.title.text = value == 'Select title'
                    ? ''
                    : (value ?? ''),
                errorText: widget.errors['title'],
              ),
              _LookupSingleChoiceField(
                label: 'Gender',
                future: _gendersFuture,
                value: draft.genderId,
                errorText: widget.errors['gender'],
                onChanged: (value) => setState(() {
                  draft.genderId = value?.id;
                }),
              ),
              _Field(
                label: 'First name',
                hint: 'e.g. Ama',
                controller: draft.firstName,
                errorText: widget.errors['firstName'],
              ),
              _Field(
                label: 'Last name',
                hint: 'e.g. Mensah',
                controller: draft.lastName,
                errorText: widget.errors['lastName'],
              ),
              _DateField(
                label: 'Date of birth',
                controller: draft.dob,
                errorText: widget.errors['dateOfBirth'],
              ),
              _SelectField(
                label: 'Relationship',
                value: 'Select relationship',
                options: _relationships,
                selectedValue: draft.relationship,
                onChanged: (value) => draft.relationship = value ?? 'Parent',
                errorText: widget.errors['relationship'],
              ),
              _LookupSelectField(
                label: 'Nationality',
                placeholder: 'Select nationality',
                future: _nationalitiesFuture,
                value: draft.nationalityId,
                fallbackName: draft.nationalityName,
                fallbackCode: draft.nationalityCode,
                errorText: widget.errors['nationality'],
                onResolved: (value) {
                  draft.nationalityId = value.id;
                  draft.nationalityCode = value.code;
                  draft.nationalityName = value.name;
                },
                onChanged: (value) {
                  draft.nationalityId = value?.id;
                  draft.nationalityCode = value?.code;
                  draft.nationalityName = value?.name ?? '';
                },
              ),
              _LookupSelectField(
                label: 'Religion',
                placeholder: 'Select religion',
                future: _religionsFuture,
                value: draft.religionId,
                fallbackName: draft.religionName,
                errorText: widget.errors['religion'],
                onResolved: (value) {
                  draft.religionId = value.id;
                  draft.religionName = value.name;
                  draft.religion.text = value.name;
                },
                onChanged: (value) {
                  draft.religionId = value?.id;
                  draft.religionName = value?.name ?? '';
                  draft.religion.text = value?.name ?? '';
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DrawerFormSection(
          title: 'Languages Spoken',
          errorText: widget.errors['languages'],
          child: _LookupTagSelectionGrid(
            future: _languagesFuture,
            selected: draft.selectedLanguages,
            onChanged: (values) => setState(() {
              draft.selectedLanguages
                ..clear()
                ..addAll(values);
            }),
            emptyMessage: 'No languages are configured in the backend.',
            customHint: 'Add other language',
          ),
        ),
      ],
    );
  }
}

class _GuardianContactForm extends StatefulWidget {
  const _GuardianContactForm({
    required this.api,
    required this.draft,
    this.errors = const {},
  });

  final AdmissionsApiClient api;
  final _GuardianAdmissionDraft draft;
  final Map<String, String> errors;

  @override
  State<_GuardianContactForm> createState() => _GuardianContactFormState();
}

class _GuardianContactFormState extends State<_GuardianContactForm> {
  late final Future<List<AdmissionLookupOption>> _socialPlatformsFuture;

  static const _networks = [
    'Select network',
    'MTN',
    'Telecel',
    'AirtelTigo',
    'Glo',
    'Landline',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _socialPlatformsFuture = widget.api.getSocialMediaPlatforms();
  }

  void _addPhone() {
    if (widget.draft.phoneNumbers.length >= 5) return;
    setState(() => widget.draft.phoneNumbers.add(_GuardianPhoneDraft()));
  }

  void _removePhone(int index) {
    if (widget.draft.phoneNumbers.length == 1) return;
    setState(() {
      widget.draft.phoneNumbers.removeAt(index).dispose();
    });
  }

  void _addEmail() {
    if (widget.draft.emailAddresses.length >= 5) return;
    setState(() => widget.draft.emailAddresses.add(TextEditingController()));
  }

  void _removeEmail(int index) {
    if (widget.draft.emailAddresses.length == 1) return;
    setState(() {
      widget.draft.emailAddresses.removeAt(index).dispose();
    });
  }

  void _addSocialAccount() {
    if (widget.draft.socialAccounts.length >= 5) return;
    setState(
      () => widget.draft.socialAccounts.add(_GuardianSocialAccountDraft()),
    );
  }

  void _removeSocialAccount(int index) {
    if (widget.draft.socialAccounts.length == 1) return;
    setState(() {
      widget.draft.socialAccounts.removeAt(index).dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Column(
      children: [
        _DrawerFormSection(
          title: 'Email & Phone',
          errorText: widget.errors['phones'] ?? widget.errors['emails'],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FormGroupLabel('Phone numbers'),
              const SizedBox(height: 8),
              for (
                var index = 0;
                index < draft.phoneNumbers.length;
                index++
              ) ...[
                _PhoneNetworkRow(
                  controller: draft.phoneNumbers[index].number,
                  network: draft.phoneNumbers[index].network,
                  index: index,
                  networks: _networks,
                  onNetworkChanged: (value) => setState(() {
                    draft.phoneNumbers[index].network =
                        value == 'Select network' ? '' : (value ?? '');
                  }),
                  onRemove: index == 0 ? null : () => _removePhone(index),
                  errorText: widget.errors['phones'],
                ),
                if (index < draft.phoneNumbers.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              _AddInlineButton(
                label: 'Add another phone',
                onPressed: draft.phoneNumbers.length >= 5 ? null : _addPhone,
              ),
              const SizedBox(height: 14),
              _PhoneNetworkRow(
                controller: draft.workPhone,
                network: draft.workPhoneNetwork,
                label: 'Work phone',
                networks: _networks,
                onNetworkChanged: (value) => setState(() {
                  draft.workPhoneNetwork = value == 'Select network'
                      ? ''
                      : (value ?? '');
                }),
              ),
              const SizedBox(height: 18),
              const _FormGroupLabel('Email addresses'),
              const SizedBox(height: 8),
              for (
                var index = 0;
                index < draft.emailAddresses.length;
                index++
              ) ...[
                _RemovableFieldRow(
                  onRemove: index == 0 ? null : () => _removeEmail(index),
                  child: _Field(
                    label: index == 0
                        ? 'Primary email address'
                        : 'Additional email address',
                    hint: 'guardian@email.com',
                    controller: draft.emailAddresses[index],
                    keyboardType: TextInputType.emailAddress,
                    errorText: widget.errors['emails'],
                  ),
                ),
                if (index < draft.emailAddresses.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              _AddInlineButton(
                label: 'Add another email address',
                onPressed: draft.emailAddresses.length >= 5 ? null : _addEmail,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DrawerFormSection(
          title: 'Social Media',
          errorText: widget.errors['socialMedia'],
          child: Column(
            children: [
              for (
                var index = 0;
                index < draft.socialAccounts.length;
                index++
              ) ...[
                _SocialAccountRow(
                  platformsFuture: _socialPlatformsFuture,
                  account: draft.socialAccounts[index],
                  onPlatformChanged: (value) => setState(() {
                    draft.socialAccounts[index].platformId = value?.id;
                  }),
                  onRemove: index == 0
                      ? null
                      : () => _removeSocialAccount(index),
                ),
                if (index < draft.socialAccounts.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: _AddInlineButton(
                  label: 'Add account',
                  onPressed: draft.socialAccounts.length >= 5
                      ? null
                      : _addSocialAccount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressForm extends StatelessWidget {
  const _AddressForm({
    required this.owner,
    this.includeDuration = false,
    required this.api,
    required this.draft,
    this.errors = const {},
  });
  final String owner;
  final bool includeDuration;
  final AdmissionsApiClient api;
  final _AddressDraft draft;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setAddressState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (owner == 'student') ...[
            _SelectField(
              label: 'Address source',
              value: 'Use household address',
              options: const [
                'Use household address',
                'Enter a different address',
              ],
              selectedValue: draft.useHouseholdAddress
                  ? 'Use household address'
                  : 'Enter a different address',
              onChanged: (value) => setAddressState(() {
                draft.useHouseholdAddress =
                    value != 'Enter a different address';
              }),
            ),
            const SizedBox(height: 16),
            if (draft.useHouseholdAddress)
              const _LookupEmptyBox(
                message:
                    'The primary guardian\'s current household address will be copied to this student when you continue. This replaces any previously saved student address.',
              ),
          ],
          if (owner != 'student' || !draft.useHouseholdAddress) ...[
            _DrawerFormSection(
              title: 'Physical Address',
              child: _ResponsiveFormGrid(
                children: [
                  _Field(
                    label: 'House number',
                    hint: 'e.g. H123',
                    controller: draft.houseNumber,
                    errorText: errors['houseNumber'],
                  ),
                  _Field(
                    label: 'Street name',
                    hint: 'e.g. Main Street',
                    controller: draft.streetName,
                    errorText: errors['streetName'],
                  ),
                  _LookupSelectField(
                    label: 'Region',
                    placeholder: 'Select region',
                    future: api.getRegions(),
                    value: draft.regionId,
                    errorText: errors['region'],
                    onChanged: (value) {
                      setAddressState(() {
                        draft.regionId = value?.id;
                        draft.districtId = null;
                        draft.cityId = null;
                        draft.cityName = '';
                      });
                    },
                  ),
                  _DistrictSelectField(
                    api: api,
                    draft: draft,
                    errorText: errors['district'],
                    onChanged: (value) {
                      setAddressState(() {
                        draft.districtId = value?.id;
                        draft.cityId = null;
                        draft.cityName = '';
                      });
                    },
                  ),
                  _CitySearchField(
                    key: ValueKey(
                      'address-city-${draft.regionId}-${draft.districtId}',
                    ),
                    api: api,
                    draft: draft,
                    requiresLocationScope: true,
                    errorText: errors['city'],
                  ),
                  _Field(
                    label: 'Ghana Post address',
                    hint: 'GA-123-4567',
                    controller: draft.ghanaPostAddress,
                    errorText: errors['ghanaPostAddress'],
                  ),
                  if (includeDuration)
                    _SelectField(
                      label: 'How long stayed here',
                      value: 'Select duration',
                      options: const [
                        'Select duration',
                        'Less than 1 year',
                        '1-3 years',
                        '4-10 years',
                        'More than 10 years',
                      ],
                      selectedValue: draft.duration.isEmpty
                          ? 'Select duration'
                          : draft.duration,
                      onChanged: (value) => draft.duration =
                          value == 'Select duration' ? '' : (value ?? ''),
                      errorText: errors['duration'],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DrawerFormSection(
              title: 'Location Details',
              child: Column(
                children: [
                  _Field(
                    label: 'Additional directions',
                    hint: 'Describe how to locate the house',
                    maxLines: 4,
                    controller: draft.additionalDirections,
                    errorText: errors['additionalDirections'],
                  ),
                  SizedBox(height: 12),
                  _ResponsiveFormGrid(
                    minTwoColumnWidth: 420,
                    children: [
                      _Field(
                        label: 'GPS latitude',
                        hint: '5.6037',
                        controller: draft.latitude,
                        keyboardType: TextInputType.number,
                      ),
                      _Field(
                        label: 'GPS longitude',
                        hint: '-0.1870',
                        controller: draft.longitude,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuardianProofOfIdForm extends StatelessWidget {
  const _GuardianProofOfIdForm({
    required this.api,
    required this.draft,
    this.errors = const {},
  });

  final AdmissionsApiClient api;
  final _GuardianAdmissionDraft draft;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    return _DrawerFormSection(
      title: 'Proof of Identity',
      child: _ResponsiveFormGrid(
        children: [
          _LookupSelectField(
            label: 'ID type',
            placeholder: 'Select ID type',
            future: api.getProofOfIdTypes(),
            value: draft.proofOfIdTypeId,
            fallbackName: draft.proofOfIdTypeName,
            errorText: errors['proofOfIdType'],
            onResolved: (value) {
              draft.proofOfIdTypeId = value.id;
              draft.proofOfIdTypeName = value.name;
            },
            onChanged: (value) {
              draft.proofOfIdTypeId = value?.id;
              draft.proofOfIdTypeName = value?.name ?? '';
            },
          ),
          _Field(
            label: 'ID number',
            hint: 'Enter ID number',
            controller: draft.idNumber,
            errorText: errors['idNumber'],
          ),
          _DateField(
            label: 'Issue date',
            controller: draft.issueDate,
            errorText: errors['issueDate'],
          ),
          _DateField(
            label: 'Expiry date',
            controller: draft.expiryDate,
            errorText: errors['expiryDate'],
          ),
          _LookupSelectField(
            label: 'Country of issue',
            placeholder: 'Select country',
            future: api.getNationalities(),
            value: draft.proofCountryId,
            fallbackName: draft.proofCountryName,
            fallbackCode: draft.proofCountryCode,
            errorText: errors['proofCountry'],
            onResolved: (value) {
              draft.proofCountryId = value.id;
              draft.proofCountryCode = value.code ?? '';
              draft.proofCountryName = value.name;
            },
            onChanged: (value) {
              draft.proofCountryId = value?.id;
              draft.proofCountryCode = value?.code ?? '';
              draft.proofCountryName = value?.name ?? '';
            },
          ),
          _CitySearchField(
            api: api,
            draft: draft.proofLocationDraft,
            label: 'City of issue',
            errorText: errors['proofCity'],
          ),
        ],
      ),
    );
  }
}

class _GuardianWorkSkillsForm extends StatefulWidget {
  const _GuardianWorkSkillsForm({
    required this.api,
    required this.draft,
    this.errors = const {},
  });

  final AdmissionsApiClient api;
  final _GuardianAdmissionDraft draft;
  final Map<String, String> errors;

  @override
  State<_GuardianWorkSkillsForm> createState() =>
      _GuardianWorkSkillsFormState();
}

class _GuardianWorkSkillsFormState extends State<_GuardianWorkSkillsForm> {
  late final Future<List<AdmissionLookupOption>> _occupationsFuture;
  late final Future<List<AdmissionLookupOption>> _skillsFuture;

  @override
  void initState() {
    super.initState();
    _occupationsFuture = widget.api.getOccupations();
    _skillsFuture = widget.api.getSkills();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DrawerFormSection(
          title: 'Occupations',
          errorText: widget.errors['occupations'],
          child: _LookupTagSelectionGrid(
            future: _occupationsFuture,
            selected: widget.draft.selectedOccupations,
            maxSelections: 5,
            customHint: 'Add other occupation',
            onChanged: (value) => setState(() {
              widget.draft.selectedOccupations
                ..clear()
                ..addAll(value);
            }),
            emptyMessage: 'No occupations are configured in the backend.',
          ),
        ),
        SizedBox(height: 12),
        _DrawerFormSection(
          title: 'Useful skills',
          child: _LookupTagSelectionGrid(
            future: _skillsFuture,
            selected: widget.draft.selectedSkills,
            maxSelections: 5,
            customHint: 'Add other skill',
            onChanged: (value) => setState(() {
              widget.draft.selectedSkills
                ..clear()
                ..addAll(value);
            }),
            emptyMessage: 'No skills are configured in the backend.',
          ),
        ),
      ],
    );
  }
}

class _StudentBasicInfoForm extends StatefulWidget {
  const _StudentBasicInfoForm({
    required this.api,
    required this.customSchoolId,
    required this.draft,
    required this.errors,
  });

  final AdmissionsApiClient api;
  final String customSchoolId;
  final _StudentAdmissionDraft draft;
  final Map<String, String> errors;

  @override
  State<_StudentBasicInfoForm> createState() => _StudentBasicInfoFormState();
}

class _StudentBasicInfoFormState extends State<_StudentBasicInfoForm> {
  late final Future<List<AdmissionLookupOption>> _gradeLevelsFuture;
  late final Future<List<AdmissionLookupOption>> _gendersFuture;
  late final Future<List<AdmissionLookupOption>> _nationalitiesFuture;
  late final Future<List<AdmissionLookupOption>> _religionsFuture;
  late final Future<List<AdmissionLookupOption>> _languagesFuture;
  Future<List<AdmissionLookupOption>>? _streamsFuture;

  @override
  void initState() {
    super.initState();
    _gradeLevelsFuture = widget.api.getSchoolGradeLevels(widget.customSchoolId);
    _gendersFuture = widget.api.getGenders();
    _nationalitiesFuture = widget.api.getNationalities();
    _religionsFuture = widget.api.getReligions();
    _languagesFuture = widget.api.getLanguages();
    _prepareStreamsLookup();
  }

  void _prepareStreamsLookup() {
    final gradeLevelId =
        widget.draft.schoolGradeLevelId ?? widget.draft.gradeLevelId;
    _streamsFuture = gradeLevelId == null
        ? null
        : widget.api.getGradeLevelStreams(
            customSchoolId: widget.customSchoolId,
            gradeLevelId: gradeLevelId,
          );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Column(
      children: [
        _ResponsiveFormGrid(
          children: [
            _LookupSelectField(
              label: 'Applying for grade',
              placeholder: 'Select grade',
              future: _gradeLevelsFuture,
              value: draft.gradeLevelId,
              errorText: widget.errors['grade'],
              onChanged: (value) => setState(() {
                draft.gradeLevelId = value?.id;
                draft.schoolGradeLevelId = int.tryParse(value?.code ?? '');
                draft.streamId = null;
                _prepareStreamsLookup();
              }),
            ),
            if (draft.gradeLevelId == null || _streamsFuture == null)
              _SelectField(
                label: 'Stream / class',
                value: 'Select grade first',
                options: const ['Select grade first'],
                onChanged: (_) {},
              )
            else
              _LookupSelectField(
                label: 'Stream / class',
                placeholder: 'Select stream',
                future: _streamsFuture!,
                value: draft.streamId,
                onChanged: (value) => draft.streamId = value?.id,
              ),
            _Field(
              label: 'First name',
              hint: 'e.g. Kofi',
              controller: draft.firstName,
              errorText: widget.errors['firstName'],
            ),
            _Field(
              label: 'Middle name',
              hint: 'Optional',
              controller: draft.middleName,
            ),
            _Field(
              label: 'Last name',
              hint: 'e.g. Mensah',
              controller: draft.lastName,
              errorText: widget.errors['lastName'],
            ),
            _DateField(
              label: 'Date of birth',
              controller: draft.dateOfBirth,
              errorText: widget.errors['dateOfBirth'],
            ),
            _LookupSingleChoiceField(
              label: 'Gender',
              future: _gendersFuture,
              value: draft.genderId,
              errorText: widget.errors['gender'],
              onChanged: (value) => setState(() {
                draft.genderId = value?.id;
              }),
            ),
            _LookupSelectField(
              label: 'Country of birth',
              placeholder: 'Select country',
              future: _nationalitiesFuture,
              value: draft.countryOfBirthId,
              onChanged: (value) => draft.countryOfBirthId = value?.id,
            ),
            _CitySearchField(
              api: widget.api,
              draft: draft.birthCityDraft,
              label: 'City of birth',
              onSelected: (value) => draft.cityOfBirthId = value?.id,
            ),
            _LookupSelectField(
              label: 'Religion',
              placeholder: 'Select religion',
              future: _religionsFuture,
              value: draft.religionId,
              errorText: widget.errors['religion'],
              onChanged: (value) {
                draft.religionId = value?.id;
                draft.religion.text = value?.name ?? '';
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DrawerFormSection(
          title: 'Languages Spoken',
          errorText: widget.errors['languages'],
          child: _LookupTagSelectionGrid(
            future: _languagesFuture,
            selected: draft.selectedLanguages,
            onChanged: (values) => setState(() {
              draft.selectedLanguages
                ..clear()
                ..addAll(values);
            }),
            emptyMessage: 'No languages are configured in the backend.',
            customHint: 'Add other language',
          ),
        ),
      ],
    );
  }
}

class _StudentMedicalForm extends StatefulWidget {
  const _StudentMedicalForm({required this.api, required this.draft});

  final AdmissionsApiClient api;
  final _StudentAdmissionDraft draft;

  @override
  State<_StudentMedicalForm> createState() => _StudentMedicalFormState();
}

class _StudentMedicalFormState extends State<_StudentMedicalForm> {
  late final Future<List<AdmissionMedicalConditionOption>> _conditionsFuture;

  @override
  void initState() {
    super.initState();
    _conditionsFuture = widget.api.getDefaultMedicalConditions();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DrawerFormSection(
          title: 'Medical Conditions',
          child: FutureBuilder<List<AdmissionMedicalConditionOption>>(
            future: _conditionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LookupLoadingRows(message: 'Loading conditions');
              }
              if (snapshot.hasError) {
                return _LookupErrorBox(
                  message:
                      'Could not load medical conditions from the backend.',
                );
              }
              final conditions = snapshot.data ?? const [];
              if (conditions.isEmpty) {
                return const _LookupEmptyBox(
                  message:
                      'No medical conditions are configured in the backend.',
                );
              }
              for (final condition in conditions) {
                final conditionId = condition.id;
                if (conditionId != null) {
                  widget.draft.conditionNames.putIfAbsent(
                    conditionId,
                    () => condition.name,
                  );
                }
              }
              return Column(
                children: conditions
                    .map(
                      (condition) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MedicalConditionChoiceRow(
                          condition: condition,
                          value: condition.id == null
                              ? null
                              : widget.draft.conditionAnswers[condition.id],
                          notesController: condition.id == null
                              ? null
                              : widget.draft.notesForCondition(condition.id!),
                          onChanged: (value) {
                            if (condition.id != null) {
                              setState(() {
                                widget.draft.conditionAnswers[condition.id!] =
                                    value;
                              });
                            }
                          },
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _AllergyChecklistSection(
          title: 'Food Allergies',
          selected: widget.draft.foodAllergies,
          options: const [
            'Peanuts',
            'Tree Nuts',
            'Shellfish',
            'Fish',
            'Eggs',
            'Milk',
            'Soy',
            'Wheat',
          ],
        ),
        const SizedBox(height: 12),
        _AllergyChecklistSection(
          title: 'Medical Allergies',
          selected: widget.draft.medicalAllergies,
          options: const [
            'Penicillin',
            'Aspirin',
            'Ibuprofen',
            'Codeine',
            'Sulfa Drugs',
            'Latex',
          ],
        ),
        const SizedBox(height: 12),
        _AllergyChecklistSection(
          title: 'Environmental Allergies',
          selected: widget.draft.environmentalAllergies,
          options: const [
            'Pollen',
            'Dust Mites',
            'Pet Dander',
            'Mold',
            'Grass',
            'Smoke',
            'Perfumes',
            'Cold Air',
          ],
        ),
      ],
    );
  }
}

class _StudentVaccinationForm extends StatefulWidget {
  const _StudentVaccinationForm({
    required this.api,
    required this.draft,
    this.errorText,
  });

  final AdmissionsApiClient api;
  final _StudentAdmissionDraft draft;
  final String? errorText;

  @override
  State<_StudentVaccinationForm> createState() =>
      _StudentVaccinationFormState();
}

class _StudentVaccinationFormState extends State<_StudentVaccinationForm> {
  late final Future<List<AdmissionVaccinationOption>> _vaccinationsFuture;

  @override
  void initState() {
    super.initState();
    _vaccinationsFuture = widget.api.getDefaultVaccinations();
  }

  @override
  Widget build(BuildContext context) {
    return _DrawerFormSection(
      title: 'Vaccination Records',
      errorText: widget.errorText,
      child: FutureBuilder<List<AdmissionVaccinationOption>>(
        future: _vaccinationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _LookupLoadingRows(message: 'Loading vaccinations');
          }
          if (snapshot.hasError) {
            return const _LookupErrorBox(
              message: 'Could not load vaccinations from the backend.',
            );
          }
          final vaccinations = snapshot.data ?? const [];
          if (vaccinations.isEmpty) {
            return const _LookupEmptyBox(
              message: 'No vaccinations are configured in the backend.',
            );
          }
          return Column(
            children: vaccinations
                .map(
                  (vaccination) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VaccinationRecordCard(
                      vaccination: vaccination,
                      status: vaccination.id == null
                          ? null
                          : widget.draft.vaccinationStatuses[vaccination.id],
                      dateController: vaccination.id == null
                          ? null
                          : widget.draft.vaccinationDateFor(vaccination.id!),
                      notesController: vaccination.id == null
                          ? null
                          : widget.draft.vaccinationNotesFor(vaccination.id!),
                      onChanged: (value) {
                        if (vaccination.id != null) {
                          setState(() {
                            widget.draft.vaccinationStatuses[vaccination.id!] =
                                value;
                            if (value != 'YES') {
                              widget.draft
                                  .vaccinationDateFor(vaccination.id!)
                                  .clear();
                            }
                          });
                        }
                      },
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _DrawerFormSection extends StatelessWidget {
  const _DrawerFormSection({
    required this.title,
    required this.child,
    this.errorText,
  });

  final String title;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: errorText == null ? AppColors.border : AppColors.red,
          width: errorText == null ? 1 : 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: .9,
            ),
          ),
          const SizedBox(height: 10),
          child,
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: const TextStyle(
                color: AppColors.red,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LookupSelectField extends StatelessWidget {
  const _LookupSelectField({
    required this.label,
    required this.placeholder,
    required this.future,
    required this.onChanged,
    this.value,
    this.errorText,
    this.fallbackName,
    this.fallbackCode,
    this.onResolved,
  });

  final String label;
  final String placeholder;
  final Future<List<AdmissionLookupOption>> future;
  final int? value;
  final ValueChanged<AdmissionLookupOption?> onChanged;
  final String? errorText;
  final String? fallbackName;
  final String? fallbackCode;
  final ValueChanged<AdmissionLookupOption>? onResolved;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdmissionLookupOption>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Loading...',
              errorText: errorText,
            ),
          );
        }
        final options = snapshot.data ?? const [];
        if (snapshot.hasError || options.isEmpty) {
          return TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: snapshot.hasError
                  ? 'Could not load from backend'
                  : 'No backend options found',
              errorText: errorText,
            ),
          );
        }
        final selected = options.where((item) => item.id == value).firstOrNull;
        final fallback = selected != null
            ? null
            : options.where((item) {
                final wantedName = fallbackName?.trim().toLowerCase() ?? '';
                final wantedCode = fallbackCode?.trim().toLowerCase() ?? '';
                return (wantedName.isNotEmpty &&
                        item.name.trim().toLowerCase() == wantedName) ||
                    (wantedCode.isNotEmpty &&
                        item.code?.trim().toLowerCase() == wantedCode);
              }).firstOrNull;
        if (value == null && fallback?.id != null && onResolved != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onResolved!(fallback!);
          });
        }
        final effectiveValue = selected?.id ?? fallback?.id;
        return DropdownButtonFormField<int>(
          value: effectiveValue,
          decoration: InputDecoration(labelText: label, errorText: errorText),
          hint: Text(placeholder),
          items: options
              .map(
                (option) => DropdownMenuItem<int>(
                  value: option.id,
                  child: Text(option.name),
                ),
              )
              .toList(),
          onChanged: (id) => onChanged(
            id == null
                ? null
                : options.where((option) => option.id == id).firstOrNull,
          ),
        );
      },
    );
  }
}

class _LookupSingleChoiceField extends StatelessWidget {
  const _LookupSingleChoiceField({
    required this.label,
    required this.future,
    required this.onChanged,
    this.value,
    this.errorText,
  });

  final String label;
  final Future<List<AdmissionLookupOption>> future;
  final int? value;
  final ValueChanged<AdmissionLookupOption?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdmissionLookupOption>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Loading...',
              errorText: errorText,
            ),
          );
        }

        final options = snapshot.data ?? const [];
        if (snapshot.hasError || options.isEmpty) {
          return TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: label,
              hintText: snapshot.hasError
                  ? 'Could not load from backend'
                  : 'No backend options found',
              errorText: errorText,
            ),
          );
        }

        return InputDecorator(
          decoration: InputDecoration(labelText: label, errorText: errorText),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (option) => ChoiceChip(
                    label: Text(option.name),
                    selected: option.id == value,
                    onSelected: (_) => onChanged(option),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _LookupTagSelectionGrid extends StatefulWidget {
  const _LookupTagSelectionGrid({
    required this.future,
    required this.selected,
    required this.onChanged,
    required this.emptyMessage,
    this.maxSelections,
    this.customHint,
  });

  final Future<List<AdmissionLookupOption>> future;
  final List<AdmissionLookupOption> selected;
  final ValueChanged<List<AdmissionLookupOption>> onChanged;
  final String emptyMessage;
  final int? maxSelections;
  final String? customHint;

  @override
  State<_LookupTagSelectionGrid> createState() =>
      _LookupTagSelectionGridState();
}

class _LookupTagSelectionGridState extends State<_LookupTagSelectionGrid> {
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String _key(AdmissionLookupOption option) =>
      'name:${option.name.trim().toLowerCase()}';

  void _toggle(AdmissionLookupOption option) {
    final active = widget.selected.any((item) => _key(item) == _key(option));
    final next = [...widget.selected];
    if (active) {
      next.removeWhere((item) => _key(item) == _key(option));
    } else {
      if (widget.maxSelections != null &&
          next.length >= widget.maxSelections!) {
        _showLimitMessage();
        return;
      }
      next.add(option);
    }
    widget.onChanged(next);
  }

  void _addCustom() {
    final name = _customController.text.trim();
    if (name.isEmpty) return;
    if (widget.selected.any(
      (item) => item.name.trim().toLowerCase() == name.toLowerCase(),
    )) {
      _customController.clear();
      return;
    }
    if (widget.maxSelections != null &&
        widget.selected.length >= widget.maxSelections!) {
      _showLimitMessage();
      return;
    }
    widget.onChanged([
      ...widget.selected,
      AdmissionLookupOption(id: null, name: name),
    ]);
    _customController.clear();
  }

  void _showLimitMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You can select up to ${widget.maxSelections} items.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdmissionLookupOption>>(
      future: widget.future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LookupLoadingRows(message: 'Loading options');
        }
        final options = snapshot.data ?? const [];
        final visible = <AdmissionLookupOption>[
          ...options,
          ...widget.selected.where(
            (selected) => !options.any((item) => _key(item) == _key(selected)),
          ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.hasError)
              const _LookupErrorBox(
                message: 'Could not load options from the backend.',
              )
            else if (visible.isEmpty)
              _LookupEmptyBox(message: widget.emptyMessage)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: visible.map((option) {
                  final active = widget.selected.any(
                    (item) => _key(item) == _key(option),
                  );
                  return _SelectionPill(
                    label: option.name,
                    selected: active,
                    onTap: () => _toggle(option),
                  );
                }).toList(),
              ),
            if (widget.customHint != null) ...[
              const SizedBox(height: 16),
              _CustomSelectionInput(
                controller: _customController,
                hintText: '${widget.customHint}...',
                onAdd: _addCustom,
              ),
              const SizedBox(height: 12),
              _SelectedItemsSummary(
                labels: widget.selected.map((item) => item.name).toList(),
                onRemove: (label) {
                  final matches = widget.selected.where(
                    (item) => item.name == label,
                  );
                  if (matches.isNotEmpty) _toggle(matches.first);
                },
                footer: widget.maxSelections == null
                    ? null
                    : '${widget.selected.length} of ${widget.maxSelections} selected',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SelectionPill extends StatelessWidget {
  const _SelectionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.white,
          border: Border.all(
            color: selected ? AppColors.green : const Color(0xFFD7DEE3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CustomSelectionInput extends StatelessWidget {
  const _CustomSelectionInput({
    required this.controller,
    required this.hintText,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(hintText: hintText),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _SelectedItemsSummary extends StatelessWidget {
  const _SelectedItemsSummary({
    required this.labels,
    required this.onRemove,
    this.footer,
  });

  final List<String> labels;
  final ValueChanged<String> onRemove;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: labels.isEmpty
          ? const Text(
              'No items selected',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: labels
                      .map(
                        (label) => InputChip(
                          label: Text(label),
                          onDeleted: () => onRemove(label),
                          deleteIconColor: AppColors.green,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD8E2EA)),
                          labelStyle: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    footer!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DistrictSelectField extends StatefulWidget {
  const _DistrictSelectField({
    required this.api,
    required this.draft,
    required this.onChanged,
    this.errorText,
  });

  final AdmissionsApiClient api;
  final _AddressDraft draft;
  final ValueChanged<AdmissionLookupOption?> onChanged;
  final String? errorText;

  @override
  State<_DistrictSelectField> createState() => _DistrictSelectFieldState();
}

class _DistrictSelectFieldState extends State<_DistrictSelectField> {
  int? _loadedRegionId;
  Future<List<AdmissionLookupOption>>? _districtsFuture;

  @override
  Widget build(BuildContext context) {
    final regionId = widget.draft.regionId;
    if (regionId == null) {
      _loadedRegionId = null;
      _districtsFuture = null;
      return TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'District',
          hintText: 'Select region first',
          errorText: widget.errorText,
        ),
      );
    }
    if (_loadedRegionId != regionId || _districtsFuture == null) {
      _loadedRegionId = regionId;
      _districtsFuture = widget.api.getDistricts(regionId);
    }
    return _LookupSelectField(
      label: 'District',
      placeholder: 'Select district',
      future: _districtsFuture!,
      value: widget.draft.districtId,
      errorText: widget.errorText,
      onChanged: widget.onChanged,
    );
  }
}

class _CitySearchField extends StatefulWidget {
  const _CitySearchField({
    super.key,
    required this.api,
    required this.draft,
    this.label = 'City / town',
    this.onSelected,
    this.requiresLocationScope = false,
    this.errorText,
  });

  final AdmissionsApiClient api;
  final _AddressDraft draft;
  final String label;
  final ValueChanged<AdmissionLookupOption?>? onSelected;
  final bool requiresLocationScope;
  final String? errorText;

  @override
  State<_CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<_CitySearchField> {
  final _controller = TextEditingController();
  List<AdmissionLookupOption> _options = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.draft.cityName;
  }

  @override
  void didUpdateWidget(covariant _CitySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.cityName != _controller.text) {
      _controller.text = widget.draft.cityName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    final cleanValue = value.trim();
    if (cleanValue != widget.draft.cityName) {
      widget.draft.cityId = null;
      widget.draft.cityName = '';
      widget.onSelected?.call(null);
    }
    if (cleanValue.length < 3) {
      setState(() => _options = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await widget.api.searchCities(cleanValue);
      if (mounted) setState(() => _options = results.take(5).toList());
    } catch (_) {
      if (mounted) setState(() => _options = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationScopeReady =
        !widget.requiresLocationScope ||
        (widget.draft.regionId != null && widget.draft.districtId != null);
    return Column(
      children: [
        TextField(
          enabled: locationScopeReady,
          controller: _controller,
          onChanged: _search,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: locationScopeReady
                ? 'Type at least 3 letters'
                : 'Select region and district first',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.draft.cityId != null
                ? const Icon(Icons.check_circle_rounded, color: AppColors.green)
                : null,
            errorText: widget.errorText,
          ),
        ),
        if (_options.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _options
                .map(
                  (option) => ActionChip(
                    label: Text(option.name),
                    onPressed: () {
                      setState(() {
                        widget.draft.cityId = option.id;
                        widget.draft.cityName = option.name;
                        _controller.text = option.name;
                        _controller.selection = TextSelection.collapsed(
                          offset: option.name.length,
                        );
                        _options = const [];
                      });
                      widget.onSelected?.call(option);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AddInlineButton extends StatelessWidget {
  const _AddInlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: Text(label),
    );
  }
}

class _FormGroupLabel extends StatelessWidget {
  const _FormGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .8,
      ),
    );
  }
}

class _PhoneNetworkRow extends StatelessWidget {
  const _PhoneNetworkRow({
    required this.controller,
    required this.network,
    required this.networks,
    required this.onNetworkChanged,
    this.index,
    this.label,
    this.onRemove,
    this.errorText,
  });

  final TextEditingController controller;
  final String network;
  final List<String> networks;
  final ValueChanged<String?> onNetworkChanged;
  final int? index;
  final String? label;
  final VoidCallback? onRemove;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final phoneLabel =
        label ?? (index == 0 ? 'Primary phone number' : 'Phone number');
    final phone = _Field(
      label: phoneLabel,
      hint: '+233 24 000 0000',
      controller: controller,
      keyboardType: TextInputType.phone,
      errorText: errorText,
    );
    final networkField = _SelectField(
      label: 'Network',
      value: 'Select network',
      options: networks,
      selectedValue: network.isEmpty ? 'Select network' : network,
      onChanged: onNetworkChanged,
      errorText: errorText,
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = constraints.maxWidth >= 280
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: phone),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: networkField),
                  ],
                )
              : Column(
                  children: [phone, const SizedBox(height: 10), networkField],
                );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Remove phone number',
                  onPressed: onRemove,
                  color: AppColors.red,
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RemovableFieldRow extends StatelessWidget {
  const _RemovableFieldRow({required this.child, this.onRemove});

  final Widget child;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: child),
        if (onRemove != null) ...[
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            color: AppColors.red,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ],
    );
  }
}

class _SocialAccountRow extends StatelessWidget {
  const _SocialAccountRow({
    required this.platformsFuture,
    required this.account,
    required this.onPlatformChanged,
    this.onRemove,
  });

  final Future<List<AdmissionLookupOption>> platformsFuture;
  final _GuardianSocialAccountDraft account;
  final ValueChanged<AdmissionLookupOption?> onPlatformChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final platform = _LookupSelectField(
      label: 'Platform',
      placeholder: 'Select platform',
      future: platformsFuture,
      value: account.platformId,
      onChanged: onPlatformChanged,
    );
    final handle = _Field(
      label: 'Handle or URL',
      hint: '@name or https://...',
      controller: account.handle,
      keyboardType: TextInputType.url,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = constraints.maxWidth >= 280
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: platform),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: handle),
                  ],
                )
              : Column(
                  children: [platform, const SizedBox(height: 10), handle],
                );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Remove social media account',
                  onPressed: onRemove,
                  color: AppColors.red,
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MedicalConditionChoiceRow extends StatelessWidget {
  const _MedicalConditionChoiceRow({
    required this.condition,
    required this.value,
    required this.notesController,
    required this.onChanged,
  });

  final AdmissionMedicalConditionOption condition;
  final bool? value;
  final TextEditingController? notesController;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2EA)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TwoLine(
                  condition.name,
                  condition.description.isEmpty
                      ? 'Select Yes or No'
                      : condition.description,
                ),
              ),
              const SizedBox(width: 10),
              _TinyChoiceChip(
                label: 'Yes',
                active: value == true,
                onTap: () => onChanged(true),
              ),
              const SizedBox(width: 5),
              _TinyChoiceChip(
                label: 'No',
                active: value == false,
                onTap: () => onChanged(false),
              ),
            ],
          ),
          if (value == true && notesController != null) ...[
            const SizedBox(height: 10),
            _Field(
              label: 'Notes for ${condition.name}',
              hint: 'Add relevant details, treatment or support needs',
              controller: notesController,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}

class _AllergyChecklistSection extends StatefulWidget {
  const _AllergyChecklistSection({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;

  @override
  State<_AllergyChecklistSection> createState() =>
      _AllergyChecklistSectionState();
}

class _AllergyChecklistSectionState extends State<_AllergyChecklistSection> {
  final _customController = TextEditingController();
  final _customOptions = <String>[];

  String _key(String value) => value.trim().toLowerCase();

  String? _selectedValue(String option) {
    final optionKey = _key(option);
    for (final selected in widget.selected) {
      if (_key(selected) == optionKey) return selected;
    }
    return null;
  }

  List<String> get _visibleOptions {
    final values = <String>[...widget.options, ..._customOptions];
    final knownKeys = values.map(_key).toSet();
    for (final selected in widget.selected) {
      final cleanValue = selected.trim();
      if (cleanValue.isEmpty || !knownKeys.add(_key(cleanValue))) continue;
      values.add(cleanValue);
    }
    return values;
  }

  @override
  void initState() {
    super.initState();
    _syncCustomOptions();
  }

  @override
  void didUpdateWidget(covariant _AllergyChecklistSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCustomOptions();
  }

  void _syncCustomOptions() {
    final standardKeys = widget.options.map(_key).toSet();
    for (final value in widget.selected) {
      final cleanValue = value.trim();
      if (cleanValue.isEmpty || standardKeys.contains(_key(cleanValue))) {
        continue;
      }
      if (!_customOptions.any((option) => _key(option) == _key(cleanValue))) {
        _customOptions.add(cleanValue);
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggle(String option) {
    setState(() {
      final selectedValue = _selectedValue(option);
      if (selectedValue != null) {
        widget.selected.remove(selectedValue);
      } else {
        widget.selected.add(option.trim());
      }
    });
  }

  void _addCustom() {
    final value = _customController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      if (_selectedValue(value) == null) widget.selected.add(value);
      if (!widget.options.any((option) => _key(option) == _key(value)) &&
          !_customOptions.any((option) => _key(option) == _key(value))) {
        _customOptions.add(value);
      }
      _customController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return _DrawerFormSection(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _visibleOptions
                .map(
                  (option) => _SelectionPill(
                    label: option,
                    selected: _selectedValue(option) != null,
                    onTap: () => _toggle(option),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _CustomSelectionInput(
            controller: _customController,
            hintText: 'Add other...',
            onAdd: _addCustom,
          ),
          const SizedBox(height: 12),
          _SelectedItemsSummary(
            labels: widget.selected.toList(),
            onRemove: _toggle,
          ),
        ],
      ),
    );
  }
}

class _VaccinationRecordCard extends StatelessWidget {
  const _VaccinationRecordCard({
    required this.vaccination,
    required this.status,
    required this.onChanged,
    required this.dateController,
    required this.notesController,
  });

  final AdmissionVaccinationOption vaccination;
  final String? status;
  final ValueChanged<String> onChanged;
  final TextEditingController? dateController;
  final TextEditingController? notesController;

  @override
  Widget build(BuildContext context) {
    final hasBeenReceived = status == 'YES';
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2EA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vaccination.name,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          if (vaccination.protectedDisease.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              vaccination.protectedDisease,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (vaccination.recommendedAge.isNotEmpty)
                _SoftMetaChip(label: 'Age: ${vaccination.recommendedAge}'),
              if (vaccination.isRequired)
                const _SoftMetaChip(label: 'Required', danger: true),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _TinyChoiceChip(
                label: 'Vaccinated',
                icon: Icons.check_rounded,
                active: status == 'YES',
                onTap: () => onChanged('YES'),
              ),
              _TinyChoiceChip(
                label: 'Not vaccinated',
                icon: Icons.close_rounded,
                active: status == 'NO',
                onTap: () => onChanged('NO'),
              ),
              _TinyChoiceChip(
                label: 'Pending',
                icon: Icons.hourglass_empty_rounded,
                active: status == 'NOT_ANSWERED',
                onTap: () => onChanged('NOT_ANSWERED'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ResponsiveFormGrid(
            children: [
              _DateField(
                label: 'Date received',
                controller: dateController,
                enabled: hasBeenReceived,
              ),
              _Field(
                label: 'Notes',
                hint: 'Optional notes',
                controller: notesController,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyChoiceChip extends StatelessWidget {
  const _TinyChoiceChip({
    required this.label,
    this.icon,
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.greenSoft : Colors.white,
          border: Border.all(
            color: active ? AppColors.green : const Color(0xFFD8E2EA),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: active ? AppColors.green : AppColors.muted,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.green : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftMetaChip extends StatelessWidget {
  const _SoftMetaChip({required this.label, this.danger = false});

  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF0F0) : const Color(0xFFF3F6F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: danger ? AppColors.red : AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LookupLoadingRows extends StatelessWidget {
  const _LookupLoadingRows({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < 3; index++)
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6F8),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
      ],
    );
  }
}

class _LookupErrorBox extends StatelessWidget {
  const _LookupErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _LookupMessageBox(
      icon: Icons.cloud_off_rounded,
      color: AppColors.red,
      message: message,
    );
  }
}

class _LookupEmptyBox extends StatelessWidget {
  const _LookupEmptyBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _LookupMessageBox(
      icon: Icons.info_outline_rounded,
      color: AppColors.muted,
      message: message,
    );
  }
}

class _LookupMessageBox extends StatelessWidget {
  const _LookupMessageBox({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousSchoolForm extends StatefulWidget {
  const _PreviousSchoolForm({
    required this.api,
    required this.customSchoolId,
    required this.draft,
    required this.errors,
  });

  final AdmissionsApiClient api;
  final String customSchoolId;
  final _StudentAdmissionDraft draft;
  final Map<String, String> errors;

  @override
  State<_PreviousSchoolForm> createState() => _PreviousSchoolFormState();
}

class _PreviousSchoolFormState extends State<_PreviousSchoolForm> {
  late final Future<List<AdmissionLookupOption>> _gradeLevelsFuture;
  late final Future<List<AdmissionLookupOption>> _skillsFuture;

  @override
  void initState() {
    super.initState();
    _gradeLevelsFuture = widget.api.getSchoolGradeLevels(widget.customSchoolId);
    _skillsFuture = widget.api.getSkills();
  }

  void _setFirstTimeStudent(bool value) {
    setState(() {
      widget.draft.firstTimeStudent = value;
      if (value) {
        widget.draft.previousSchoolName.clear();
        widget.draft.previousSchoolLocation.clear();
        widget.draft.lastGradeAttended.clear();
        widget.draft.previousSchoolFees.clear();
        widget.draft.reasonForLeaving.clear();
        widget.draft.reasonForLeavingChoice = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Column(
      children: [
        _DrawerFormSection(
          title: 'First-time student',
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'First-time student?',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Turn on if the student has never attended school before.',
            ),
            value: draft.firstTimeStudent,
            onChanged: _setFirstTimeStudent,
          ),
        ),
        if (!draft.firstTimeStudent) ...[
          const SizedBox(height: 12),
          _DrawerFormSection(
            title: 'Previous school',
            child: _ResponsiveFormGrid(
              children: [
                _Field(
                  label: 'School name',
                  hint: 'e.g. Achimota Basic School',
                  controller: draft.previousSchoolName,
                  errorText: widget.errors['previousSchoolName'],
                ),
                _LastGradeSelectField(
                  label: 'Last grade',
                  future: _gradeLevelsFuture,
                  controller: draft.lastGradeAttended,
                  errorText: widget.errors['lastGrade'],
                ),
                _Field(
                  label: 'School fees (GH\u00a2)',
                  hint: 'e.g. 350',
                  controller: draft.previousSchoolFees,
                  keyboardType: TextInputType.number,
                  errorText: widget.errors['previousSchoolFees'],
                ),
                _Field(
                  label: 'School address',
                  hint: 'e.g. Achimota, Accra',
                  controller: draft.previousSchoolLocation,
                  errorText: widget.errors['previousSchoolLocation'],
                ),
                _SelectField(
                  label: 'Reason for leaving',
                  value: 'Select reason',
                  options: const [
                    'Select reason',
                    ..._studentLeavingReasons,
                    _otherLeavingReason,
                  ],
                  selectedValue: draft.reasonForLeavingChoice.isEmpty
                      ? 'Select reason'
                      : draft.reasonForLeavingChoice,
                  onChanged: (value) => setState(() {
                    final next = value == 'Select reason' ? '' : (value ?? '');
                    final wasKnownReason = _studentLeavingReasons.contains(
                      draft.reasonForLeaving.text,
                    );
                    draft.reasonForLeavingChoice = next;
                    if (_studentLeavingReasons.contains(next)) {
                      draft.reasonForLeaving.text = next;
                    } else if (next == _otherLeavingReason && wasKnownReason) {
                      draft.reasonForLeaving.clear();
                    } else if (next.isEmpty) {
                      draft.reasonForLeaving.clear();
                    }
                  }),
                  errorText: widget.errors['reasonForLeaving'],
                ),
                if (draft.reasonForLeavingChoice == _otherLeavingReason)
                  _Field(
                    label: 'Other reason',
                    hint: 'Enter the reason for leaving',
                    controller: draft.reasonForLeaving,
                    maxLines: 3,
                    errorText: widget.errors['reasonForLeavingNote'],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _DrawerFormSection(
          title: 'Skills and interests',
          child: _LookupTagSelectionGrid(
            future: _skillsFuture,
            selected: draft.selectedSkillsAndInterests,
            onChanged: (values) => setState(() {
              draft.selectedSkillsAndInterests
                ..clear()
                ..addAll(values);
            }),
            emptyMessage: 'No suggested skills are configured.',
            customHint: 'Add another skill or interest',
          ),
        ),
      ],
    );
  }
}

class _LastGradeSelectField extends StatefulWidget {
  const _LastGradeSelectField({
    required this.label,
    required this.future,
    required this.controller,
    this.errorText,
  });

  final String label;
  final Future<List<AdmissionLookupOption>> future;
  final TextEditingController controller;
  final String? errorText;

  @override
  State<_LastGradeSelectField> createState() => _LastGradeSelectFieldState();
}

class _LastGradeSelectFieldState extends State<_LastGradeSelectField> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdmissionLookupOption>>(
      future: widget.future,
      builder: (context, snapshot) {
        final options = (snapshot.data ?? const <AdmissionLookupOption>[])
            .map((option) => option.name.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList();
        final savedValue = widget.controller.text.trim();
        final effectiveSelection =
            _selected ??
            (savedValue.isEmpty
                ? null
                : options.contains(savedValue)
                ? savedValue
                : _otherLeavingReason);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: effectiveSelection,
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: 'Select last grade',
                errorText: widget.errorText,
              ),
              items: [
                ...options.map(
                  (name) => DropdownMenuItem(value: name, child: Text(name)),
                ),
                const DropdownMenuItem(
                  value: _otherLeavingReason,
                  child: Text('Other'),
                ),
              ],
              onChanged: snapshot.connectionState != ConnectionState.done
                  ? null
                  : (value) => setState(() {
                      _selected = value;
                      if (value == null || value == _otherLeavingReason) {
                        widget.controller.clear();
                      } else {
                        widget.controller.text = value;
                      }
                    }),
            ),
            if (snapshot.connectionState != ConnectionState.done) ...[
              const SizedBox(height: 8),
              const Text(
                'Loading grades...',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            if (snapshot.connectionState == ConnectionState.done &&
                effectiveSelection == _otherLeavingReason) ...[
              const SizedBox(height: 8),
              TextField(
                controller: widget.controller,
                decoration: const InputDecoration(
                  labelText: 'Other grade',
                  hintText: 'Enter the last grade attended',
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StudentDocumentsForm extends StatefulWidget {
  const _StudentDocumentsForm({
    required this.api,
    required this.customSchoolId,
    required this.customStudentId,
  });

  final AdmissionsApiClient api;
  final String customSchoolId;
  final String customStudentId;

  @override
  State<_StudentDocumentsForm> createState() => _StudentDocumentsFormState();
}

class _StudentDocumentsFormState extends State<_StudentDocumentsForm> {
  static const _documentTypes = [
    (title: 'Student photo', type: 'PHOTO'),
    (title: 'Birth certificate', type: 'BIRTH_CERTIFICATE'),
    (title: 'Weighing card', type: 'WEIGHING_CARD'),
    (title: 'Immunization card', type: 'IMMUNIZATION_CARD'),
  ];

  late Future<List<AdmissionStudentDocument>> _documentsFuture;
  String? _uploadingType;
  String? _deletingType;

  @override
  void initState() {
    super.initState();
    _documentsFuture = _loadDocuments();
  }

  Future<List<AdmissionStudentDocument>> _loadDocuments() {
    if (widget.customStudentId.trim().isEmpty) {
      return Future.value(const <AdmissionStudentDocument>[]);
    }
    return widget.api.getStudentDocuments(
      customSchoolId: widget.customSchoolId,
      customStudentId: widget.customStudentId,
    );
  }

  void _reloadDocuments() {
    final nextDocuments = _loadDocuments();
    setState(() {
      _documentsFuture = nextDocuments;
    });
  }

  Future<void> _pickAndUpload(String documentType) async {
    if (_uploadingType != null) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024) {
      _showMessage('File must be 10MB or smaller.');
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('The selected file could not be read.');
      return;
    }

    setState(() => _uploadingType = documentType);
    try {
      await widget.api.uploadStudentDocument(
        customSchoolId: widget.customSchoolId,
        customStudentId: widget.customStudentId,
        documentType: documentType,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      _reloadDocuments();
      _showMessage('Document uploaded successfully.');
    } on AdmissionsApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _uploadingType = null);
    }
  }

  Future<void> _viewDocument(AdmissionStudentDocument document) async {
    if (document.documentId.trim().isEmpty) {
      _showMessage('The uploaded document link is unavailable.');
      return;
    }
    prepareDocumentWindow();
    try {
      final downloadUrl = await widget.api.getStudentDocumentDownloadUrl(
        customSchoolId: widget.customSchoolId,
        customStudentId: widget.customStudentId,
        documentId: document.documentId,
      );
      await openDocumentUrl(downloadUrl);
    } on AdmissionsApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not open this document securely.');
    }
  }

  Future<void> _removeDocument(AdmissionStudentDocument document) async {
    if (_deletingType != null) return;
    setState(() => _deletingType = document.documentType);
    try {
      await widget.api.deleteStudentDocument(
        customSchoolId: widget.customSchoolId,
        customStudentId: widget.customStudentId,
        fileUrl: document.fileUrl,
      );
      if (!mounted) return;
      _reloadDocuments();
      _showMessage('Document removed.');
    } on AdmissionsApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _deletingType = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customStudentId.trim().isEmpty) {
      return const _LookupEmptyBox(
        message: 'Save the student information before uploading documents.',
      );
    }
    return FutureBuilder<List<AdmissionStudentDocument>>(
      future: _documentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LookupLoadingRows(message: 'Loading documents');
        }
        if (snapshot.hasError) {
          return Column(
            children: [
              const _LookupErrorBox(
                message: 'Could not load the student documents.',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _reloadDocuments,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          );
        }
        final byType = {
          for (final document in snapshot.data ?? const [])
            document.documentType.toUpperCase(): document,
        };
        return Column(
          children: [
            for (final spec in _documentTypes) ...[
              _StudentDocumentTile(
                title: spec.title,
                documentType: spec.type,
                document: byType[spec.type],
                uploading: _uploadingType == spec.type,
                deleting: _deletingType == spec.type,
                onUpload: () => _pickAndUpload(spec.type),
                onView: byType[spec.type] == null
                    ? null
                    : () => _viewDocument(byType[spec.type]!),
                onRemove: byType[spec.type] == null
                    ? null
                    : () => _removeDocument(byType[spec.type]!),
              ),
              if (spec != _documentTypes.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _AdmissionReviewForm extends StatelessWidget {
  const _AdmissionReviewForm({
    required this.flow,
    required this.householdName,
    required this.totalSteps,
  });

  final _AdmissionFlowKind flow;
  final String householdName;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final reviewTitle = switch (flow) {
      _AdmissionFlowKind.primaryGuardian => 'Household path',
      _AdmissionFlowKind.additionalGuardian => 'Guardian path',
      _AdmissionFlowKind.student => 'Student path',
    };
    final reviewValue = switch (flow) {
      _AdmissionFlowKind.primaryGuardian =>
        'Create a new household with this primary guardian',
      _AdmissionFlowKind.additionalGuardian =>
        'Add this guardian to $householdName',
      _AdmissionFlowKind.student => 'Add this student to $householdName',
    };
    final nextAction = switch (flow) {
      _AdmissionFlowKind.primaryGuardian =>
        'Create household dashboard and return there',
      _AdmissionFlowKind.additionalGuardian =>
        'Save guardian and return to household dashboard',
      _AdmissionFlowKind.student =>
        'Submit student onboarding for school review',
    };
    return Column(
      children: [
        _ReviewBlock(title: reviewTitle, value: reviewValue),
        _ReviewBlock(
          title: 'Setup progress',
          value: '$totalSteps sections ready for confirmation',
        ),
        _ReviewBlock(title: 'Next backend action', value: nextAction),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            flow == _AdmissionFlowKind.student
                ? 'I confirm that the student information is accurate.'
                : 'I confirm that the guardian information is accurate.',
          ),
        ),
      ],
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: _TwoLine(title, value),
    );
  }
}

class _StudentDocumentTile extends StatelessWidget {
  const _StudentDocumentTile({
    required this.title,
    required this.documentType,
    required this.document,
    required this.uploading,
    required this.deleting,
    required this.onUpload,
    required this.onView,
    required this.onRemove,
  });

  final String title;
  final String documentType;
  final AdmissionStudentDocument? document;
  final bool uploading;
  final bool deleting;
  final VoidCallback onUpload;
  final VoidCallback? onView;
  final VoidCallback? onRemove;

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final saved = document;
    final busy = uploading || deleting;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: saved == null
                  ? const Color(0xFFF1F5F7)
                  : AppColors.greenSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              saved == null
                  ? Icons.upload_file_outlined
                  : Icons.description_outlined,
              color: saved == null ? AppColors.muted : AppColors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  saved == null
                      ? 'PDF, image, or Word document · max 10MB'
                      : [
                          saved.fileName.isEmpty
                              ? documentType
                              : saved.fileName,
                          _formatSize(saved.fileSize),
                        ].where((value) => value.isNotEmpty).join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: saved == null ? AppColors.muted : AppColors.green,
                    fontSize: 11,
                    fontWeight: saved == null
                        ? FontWeight.w600
                        : FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (saved != null)
              IconButton(
                tooltip: 'View document',
                onPressed: onView,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            OutlinedButton(
              onPressed: onUpload,
              child: Text(saved == null ? 'Upload' : 'Replace'),
            ),
            if (saved != null)
              IconButton(
                tooltip: 'Remove document',
                color: AppColors.red,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ],
      ),
    );
  }
}

class _ResponsiveFormGrid extends StatelessWidget {
  const _ResponsiveFormGrid({
    required this.children,
    this.minTwoColumnWidth = 720,
  });
  final List<Widget> children;
  final double minTwoColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= minTwoColumnWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: children
              .map(
                (child) => SizedBox(
                  width: twoColumns
                      ? (constraints.maxWidth - 14) / 2
                      : constraints.maxWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.onChanged,
    this.controller,
    this.keyboardType,
    this.errorText,
  });

  final String label;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        errorText: errorText,
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    this.options,
    this.selectedValue,
    this.onChanged,
    this.errorText,
  });
  final String label;
  final String value;
  final List<String>? options;
  final String? selectedValue;
  final ValueChanged<String?>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final items = options ?? [value];
    final current = selectedValue != null && items.contains(selectedValue)
        ? selectedValue
        : value;
    return DropdownButtonFormField<String>(
      value: items.contains(current) ? current : items.first,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    this.controller,
    this.errorText,
    this.enabled = true,
  });
  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      readOnly: true,
      onTap: !enabled
          ? null
          : () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(1900),
                lastDate: DateTime(now.year + 20),
              );
              if (selected != null) {
                controller?.text = selected.toIso8601String().split('T').first;
              }
            },
      decoration: InputDecoration(
        labelText: label,
        hintText: enabled ? 'Select date' : 'Available when received',
        suffixIcon: const Icon(Icons.calendar_today_rounded),
        errorText: errorText,
      ),
    );
  }
}

class _StartAdmissionOption extends StatelessWidget {
  const _StartAdmissionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: AppColors.muted, size: 36),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _AdmissionsLoadingCard extends StatelessWidget {
  const _AdmissionsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 14),
            Text(
              'Loading admissions data...',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdmissionsErrorCard extends StatelessWidget {
  const _AdmissionsErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.red, size: 34),
            const SizedBox(height: 10),
            const Text(
              'Unable to load admissions data',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantDetailScreen extends StatefulWidget {
  const _ApplicantDetailScreen({
    required this.application,
    required this.customSchoolId,
    required this.api,
  });

  final _StudentApplication application;
  final String customSchoolId;
  final AdmissionsApiClient api;

  @override
  State<_ApplicantDetailScreen> createState() => _ApplicantDetailScreenState();
}

class _ApplicantDetailScreenState extends State<_ApplicantDetailScreen> {
  late Future<_ApplicantDetailData> _detailFuture;
  late StudentApplicationStatus _status;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _status = widget.application.status;
    _detailFuture = _loadDetail();
  }

  Future<_ApplicantDetailData> _loadDetail() async {
    final student = await widget.api.getStudentDetails(
      customSchoolId: widget.customSchoolId,
      customStudentId: widget.application.studentId,
    );
    final householdId = student.householdId ?? widget.application.householdId;
    final results = await Future.wait([
      if (householdId != null)
        widget.api.getGuardians(
          customSchoolId: widget.customSchoolId,
          householdId: householdId,
        )
      else
        Future.value(const <AdmissionGuardian>[]),
      if (householdId != null)
        widget.api.getStudents(
          customSchoolId: widget.customSchoolId,
          householdId: householdId,
        )
      else
        Future.value(const <AdmissionStudent>[]),
      widget.api.getStudentDocuments(
        customSchoolId: widget.customSchoolId,
        customStudentId: student.customStudentId,
      ),
      widget.api.getDefaultMedicalConditions(),
      widget.api.getDefaultVaccinations(),
    ]);
    final guardians = results[0] as List<AdmissionGuardian>;
    AdmissionGuardian? guardian;
    if (guardians.isNotEmpty) {
      final summary = guardians.firstWhere(
        (item) => item.isPrimary,
        orElse: () => guardians.first,
      );
      guardian = await widget.api.getGuardianDetails(
        customSchoolId: widget.customSchoolId,
        customGuardianId: summary.customGuardianId,
      );
    }
    return _ApplicantDetailData(
      student: student,
      guardian: guardian,
      householdStudents: results[1] as List<AdmissionStudent>,
      documents: results[2] as List<AdmissionStudentDocument>,
      conditionOptions: results[3] as List<AdmissionMedicalConditionOption>,
      vaccinationOptions: results[4] as List<AdmissionVaccinationOption>,
    );
  }

  void _reloadDetail() {
    final nextDetail = _loadDetail();
    setState(() {
      _detailFuture = nextDetail;
    });
  }

  Future<void> _editApplication(
    AdmissionStudent student, {
    int initialStep = 0,
  }) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close student application form',
      barrierColor: Colors.black.withValues(alpha: 0.48),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _AdmissionSideDrawer(
            flow: _AdmissionFlowKind.student,
            householdName: widget.application.guardianName.isEmpty
                ? 'Applicant household'
                : '${widget.application.guardianName} Household',
            householdId: student.householdId ?? widget.application.householdId,
            customSchoolId: widget.customSchoolId,
            api: widget.api,
            existingStudent: student,
            initialStep: initialStep,
            onSaved: (_) => _reloadDetail(),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }

  Future<void> _changeStatus(
    StudentApplicationStatus nextStatus, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingStatus = true);
    try {
      await widget.api.updateStudentAdmissionStatus(
        customSchoolId: widget.customSchoolId,
        customStudentId: widget.application.studentId,
        status: switch (nextStatus) {
          StudentApplicationStatus.draft => 'DRAFT',
          StudentApplicationStatus.pendingApproval => 'PENDING_REVIEW',
          StudentApplicationStatus.approved => 'APPROVED',
          StudentApplicationStatus.rejected => 'REJECTED',
          StudentApplicationStatus.active => 'APPROVED',
        },
      );
      if (!mounted) return;
      setState(() => _status = nextStatus);
      _showMessage('$confirmLabel completed successfully.');
    } on AdmissionsApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _viewDocument(AdmissionStudentDocument document) async {
    if (document.documentId.trim().isEmpty) {
      _showMessage('The uploaded document link is unavailable.');
      return;
    }
    prepareDocumentWindow();
    try {
      final url = await widget.api.getStudentDocumentDownloadUrl(
        customSchoolId: widget.customSchoolId,
        customStudentId: widget.application.studentId,
        documentId: document.documentId,
      );
      await openDocumentUrl(url);
    } on AdmissionsApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Could not open this document securely.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _ApplicantDetailTopBar(
              application: widget.application,
              status: _status,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: FutureBuilder<_ApplicantDetailData>(
                future: _detailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: _AdmissionsLoadingCard(),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: _AdmissionsErrorCard(
                        message: snapshot.error.toString(),
                        onRetry: _reloadDetail,
                      ),
                    );
                  }
                  final data = snapshot.data!;
                  return _ApplicantDetailWorkspace(
                    application: widget.application,
                    data: data,
                    status: _status,
                    updatingStatus: _updatingStatus,
                    onEdit: () => _editApplication(data.student),
                    onEditStep: (step) =>
                        _editApplication(data.student, initialStep: step),
                    onApprove: () => _changeStatus(
                      StudentApplicationStatus.approved,
                      title: 'Approve application?',
                      message:
                          'This approves ${data.student.displayName} and activates the student record.',
                      confirmLabel: 'Approve application',
                    ),
                    onReject: () => _changeStatus(
                      StudentApplicationStatus.rejected,
                      title: 'Reject application?',
                      message:
                          'This application will be marked as rejected. You can return it to pending review later.',
                      confirmLabel: 'Reject application',
                      destructive: true,
                    ),
                    onRevert: () => _changeStatus(
                      StudentApplicationStatus.pendingApproval,
                      title: 'Return to pending review?',
                      message:
                          'The application will return to the review queue.',
                      confirmLabel: 'Return to pending',
                    ),
                    onViewDocument: _viewDocument,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicantDetailTopBar extends StatelessWidget {
  const _ApplicantDetailTopBar({
    required this.application,
    required this.status,
    required this.onBack,
  });

  final _StudentApplication application;
  final StudentApplicationStatus status;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to admissions',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          _InitialAvatar(name: application.studentName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  application.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Application ${application.admissionId ?? application.id ?? ''} · ${application.studentId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          _StatusPill(label: status.label, color: status.color),
        ],
      ),
    );
  }
}

class _ApplicantDetailWorkspace extends StatelessWidget {
  const _ApplicantDetailWorkspace({
    required this.application,
    required this.data,
    required this.status,
    required this.updatingStatus,
    required this.onEdit,
    required this.onEditStep,
    required this.onApprove,
    required this.onReject,
    required this.onRevert,
    required this.onViewDocument,
  });

  final _StudentApplication application;
  final _ApplicantDetailData data;
  final StudentApplicationStatus status;
  final bool updatingStatus;
  final VoidCallback onEdit;
  final ValueChanged<int> onEditStep;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevert;
  final ValueChanged<AdmissionStudentDocument> onViewDocument;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final content = _ApplicantInformationColumn(
          application: application,
          data: data,
          onEditStep: onEditStep,
          onViewDocument: onViewDocument,
        );
        final sidebar = _ApplicantDecisionSidebar(
          status: status,
          updating: updatingStatus,
          application: application,
          onEdit: onEdit,
          onApprove: onApprove,
          onReject: onReject,
          onRevert: onRevert,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1500),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: content),
                        const SizedBox(width: 18),
                        SizedBox(width: 310, child: sidebar),
                      ],
                    )
                  : Column(
                      children: [sidebar, const SizedBox(height: 16), content],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ApplicantInformationColumn extends StatelessWidget {
  const _ApplicantInformationColumn({
    required this.application,
    required this.data,
    required this.onEditStep,
    required this.onViewDocument,
  });

  final _StudentApplication application;
  final _ApplicantDetailData data;
  final ValueChanged<int> onEditStep;
  final ValueChanged<AdmissionStudentDocument> onViewDocument;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final raw = student.rawJson;
    final country = _admissionMap(raw['countryOfBirth']);
    final city = _admissionMap(raw['cityOfBirth']);
    return Column(
      children: [
        _ApplicantSectionCard(
          number: 1,
          title: 'Student Information',
          onEdit: () => onEditStep(0),
          child: _ApplicantDetailGrid(
            fields: [
              ('First name', _value(raw['firstName'])),
              ('Last name', _value(raw['lastName'])),
              ('Middle name', _value(raw['middleName'])),
              ('Gender', _value(student.gender)),
              ('Date of birth', _formatDateText(student.dateOfBirth)),
              ('Applying for class', _value(student.gradeLevel)),
              (
                'Country of birth',
                _value(country?['name'] ?? country?['countryName']),
              ),
              ('City of birth', _value(city?['name'])),
              ('Application type', application.type),
              ('Applied date', application.appliedDate),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ApplicantSectionCard(
          number: 2,
          title: 'Medical Conditions & Allergies',
          onEdit: () => onEditStep(2),
          child: _ApplicantMedicalContent(data: data),
        ),
        const SizedBox(height: 14),
        _ApplicantSectionCard(
          number: 3,
          title: 'Vaccination Records',
          onEdit: () => onEditStep(3),
          child: _ApplicantVaccinationContent(data: data),
        ),
        const SizedBox(height: 14),
        _ApplicantSectionCard(
          number: 4,
          title: 'School History',
          onEdit: () => onEditStep(4),
          child: _ApplicantSchoolHistory(student: student),
        ),
        const SizedBox(height: 14),
        _ApplicantSectionCard(
          number: 5,
          title: 'Required Documents',
          onEdit: () => onEditStep(5),
          child: _ApplicantDocuments(
            documents: data.documents,
            onViewDocument: onViewDocument,
          ),
        ),
        const SizedBox(height: 14),
        _ApplicantSectionCard(
          title: 'Guardian / Parent',
          child: _ApplicantGuardianContent(guardian: data.guardian),
        ),
        if (data.otherApplications.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ApplicantSectionCard(
            title: 'Other Applications from this Household',
            child: Column(
              children: data.otherApplications
                  .map((student) => _RelatedApplicationRow(student: student))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  static String _value(Object? value) {
    final text = _admissionText(value);
    return text.isEmpty ? 'Not provided' : text;
  }
}

class _ApplicantDecisionSidebar extends StatelessWidget {
  const _ApplicantDecisionSidebar({
    required this.status,
    required this.updating,
    required this.application,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onRevert,
  });

  final StudentApplicationStatus status;
  final bool updating;
  final _StudentApplication application;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ACTIONS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 14),
                if (updating)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (status == StudentApplicationStatus.pendingApproval) ...[
                    FilledButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Approve Application'),
                    ),
                    const SizedBox(height: 9),
                    OutlinedButton.icon(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Reject Application'),
                    ),
                  ],
                  if (status == StudentApplicationStatus.approved)
                    const _ApplicantApprovedNotice(),
                  if (status == StudentApplicationStatus.rejected)
                    OutlinedButton(
                      onPressed: onRevert,
                      child: const Text('Revert to Pending'),
                    ),
                  if (status == StudentApplicationStatus.draft)
                    const Text(
                      'Complete the application before submitting it for review.',
                      style: TextStyle(color: AppColors.muted, height: 1.45),
                    ),
                  if (status != StudentApplicationStatus.pendingApproval &&
                      status != StudentApplicationStatus.rejected)
                    const SizedBox(height: 4),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Application'),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIMELINE',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 14),
                ..._timelineItems().map(
                  (item) => _TimelineItem(
                    label: item.$1,
                    detail: item.$2,
                    state: item.$3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<(String, String, _TimelineState)> _timelineItems() {
    if (status == StudentApplicationStatus.draft) {
      return [
        ('Application started', application.appliedDate, _TimelineState.done),
        ('Submit for review', 'Not yet submitted', _TimelineState.current),
      ];
    }
    if (status == StudentApplicationStatus.rejected) {
      return [
        ('Application submitted', application.appliedDate, _TimelineState.done),
        ('Under review', 'Reviewed', _TimelineState.done),
        ('Application rejected', 'Not approved', _TimelineState.rejected),
      ];
    }
    final approved =
        status == StudentApplicationStatus.approved ||
        status == StudentApplicationStatus.active;
    return [
      ('Application submitted', application.appliedDate, _TimelineState.done),
      (
        'Under review',
        approved ? 'Reviewed' : 'Awaiting decision',
        approved ? _TimelineState.done : _TimelineState.current,
      ),
      (
        'Application approved',
        approved ? 'Approved' : 'Pending',
        approved ? _TimelineState.done : _TimelineState.pending,
      ),
      (
        'Student record activated',
        approved ? 'Active after approval' : 'Pending approval',
        approved ? _TimelineState.done : _TimelineState.pending,
      ),
    ];
  }
}

class _ApplicantApprovedNotice extends StatelessWidget {
  const _ApplicantApprovedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.green.withValues(alpha: .25)),
      ),
      child: const Column(
        children: [
          Icon(Icons.verified_rounded, color: AppColors.green),
          SizedBox(height: 6),
          Text(
            'Application approved',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 3),
          Text(
            'The student record is active.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ApplicantSectionCard extends StatelessWidget {
  const _ApplicantSectionCard({
    required this.title,
    required this.child,
    this.number,
    this.onEdit,
  });

  final int? number;
  final String title;
  final Widget child;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                if (number != null) ...[
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.green,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Edit'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _ApplicantDetailGrid extends StatelessWidget {
  const _ApplicantDetailGrid({required this.fields});
  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 650
            ? (constraints.maxWidth - 24) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 24,
          runSpacing: 16,
          children: fields
              .map(
                (field) => SizedBox(
                  width: width,
                  child: _ApplicantDetailField(
                    label: field.$1,
                    value: field.$2,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ApplicantDetailField extends StatelessWidget {
  const _ApplicantDetailField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .65,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: value == 'Not provided' ? AppColors.muted : AppColors.text,
            fontStyle: value == 'Not provided'
                ? FontStyle.italic
                : FontStyle.normal,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ApplicantMedicalContent extends StatelessWidget {
  const _ApplicantMedicalContent({required this.data});
  final _ApplicantDetailData data;

  @override
  Widget build(BuildContext context) {
    final medical = _admissionMap(data.student.rawJson['medicalCondition']);
    final records = <int, Map<String, dynamic>>{};
    final custom = <Map<String, dynamic>>[];
    for (final raw in _admissionList(medical?['medicalConditions'])) {
      final item = _admissionMap(raw);
      if (item == null) continue;
      final id = _admissionInt(item['conditionTypeId'] ?? item['id']);
      if (id == null) {
        custom.add(item);
      } else {
        records[id] = item;
      }
    }
    final conditions = <Map<String, dynamic>>[
      ...data.conditionOptions.map(
        (option) =>
            records[option.id] ??
            {
              'conditionName': option.name,
              'value': '3',
              'valueDescription': 'Not recorded',
            },
      ),
      ...custom,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ApplicantSubheading('Medical conditions'),
        ...conditions.map((item) => _MedicalConditionRow(item: item)),
        const SizedBox(height: 16),
        _AllergyGroup(
          title: 'Food allergies',
          values: _stringList(medical?['foodAllergies']),
          color: AppColors.amber,
        ),
        const SizedBox(height: 14),
        _AllergyGroup(
          title: 'Medical allergies',
          values: _stringList(medical?['medicalAllergies']),
          color: AppColors.red,
        ),
        const SizedBox(height: 14),
        _AllergyGroup(
          title: 'Environmental allergies',
          values: _stringList(medical?['environmentalAllergies']),
          color: AppColors.blue,
        ),
      ],
    );
  }
}

class _MedicalConditionRow extends StatelessWidget {
  const _MedicalConditionRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = _admissionText(item['conditionName'] ?? item['name']);
    final value = _admissionText(item['value']).toUpperCase();
    final yes = value == '1' || value == 'YES' || item['value'] == true;
    final no = value == '2' || value == 'NO' || item['value'] == false;
    final label = yes
        ? 'Yes'
        : no
        ? 'No'
        : 'Not recorded';
    final color = yes
        ? AppColors.green
        : no
        ? AppColors.red
        : AppColors.muted;
    final notes = _admissionText(item['notes']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Medical condition' : name),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _SmallValuePill(label: label, color: color),
        ],
      ),
    );
  }
}

class _AllergyGroup extends StatelessWidget {
  const _AllergyGroup({
    required this.title,
    required this.values,
    required this.color,
  });
  final String title;
  final List<String> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ApplicantSubheading(title),
        const SizedBox(height: 7),
        if (values.isEmpty)
          const Text('None recorded', style: TextStyle(color: AppColors.muted))
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: values
                .map((value) => _SmallValuePill(label: value, color: color))
                .toList(),
          ),
      ],
    );
  }
}

class _ApplicantVaccinationContent extends StatelessWidget {
  const _ApplicantVaccinationContent({required this.data});
  final _ApplicantDetailData data;

  @override
  Widget build(BuildContext context) {
    final records = <int, Map<String, dynamic>>{};
    for (final raw in _admissionList(
      data.student.rawJson['vaccinationRecords'],
    )) {
      final item = _admissionMap(raw);
      final id = _admissionInt(
        item?['vaccinationId'] ??
            item?['id'] ??
            _admissionMap(item?['vaccination'])?['id'],
      );
      if (id != null && item != null) records[id] = item;
    }
    if (data.vaccinationOptions.isEmpty && records.isEmpty) {
      return const Text(
        'No vaccination records available.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return Column(
      children: data.vaccinationOptions.map((option) {
        final record = records[option.id];
        final status = _admissionText(record?['status']).toUpperCase();
        final vaccinated =
            status == 'YES' || status == 'VACCINATED' || status == 'RECEIVED';
        final pending = status == 'PENDING';
        final label = vaccinated
            ? 'Vaccinated'
            : pending
            ? 'Pending'
            : status.isEmpty
            ? 'Not recorded'
            : 'Not vaccinated';
        final color = vaccinated
            ? AppColors.green
            : pending
            ? AppColors.amber
            : status.isEmpty
            ? AppColors.muted
            : AppColors.red;
        final date = _admissionDate(record?['dateReceived']);
        final notes = _admissionText(record?['notes']);
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (option.isRequired) ...[
                          const SizedBox(width: 6),
                          _SmallValuePill(
                            label: 'Required',
                            color: AppColors.amber,
                          ),
                        ],
                      ],
                    ),
                    if (option.protectedDisease.isNotEmpty)
                      Text(
                        option.protectedDisease,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    if (date.isNotEmpty || notes.isNotEmpty)
                      Text(
                        [
                          if (date.isNotEmpty) _formatDateText(date),
                          if (notes.isNotEmpty) notes,
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              _SmallValuePill(label: label, color: color),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ApplicantSchoolHistory extends StatelessWidget {
  const _ApplicantSchoolHistory({required this.student});
  final AdmissionStudent student;

  @override
  Widget build(BuildContext context) {
    final raw = student.rawJson;
    final formerSchool = _admissionText(raw['formerSchoolName']);
    final location = _admissionText(raw['formerSchoolLocation']);
    final reason = _admissionText(raw['reasonForLeaving']);
    final lastGrade = _admissionText(raw['lastGradeAttended']);
    final fees = _admissionText(raw['previousSchoolFees']);
    final firstTime = [
      formerSchool,
      location,
      reason,
      lastGrade,
      fees,
    ].every((value) => value.isEmpty);
    final skills = _admissionText(raw['skillsAndInterests'])
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ApplicantDetailGrid(
          fields: [
            (
              'First-time student',
              firstTime ? 'Yes - no previous school' : 'No - attended school',
            ),
            (
              'Previous school',
              formerSchool.isEmpty ? 'Not provided' : formerSchool,
            ),
            ('Last grade', lastGrade.isEmpty ? 'Not provided' : lastGrade),
            ('Previous fees (GH₵)', fees.isEmpty ? 'Not provided' : fees),
            ('School address', location.isEmpty ? 'Not provided' : location),
            ('Reason for leaving', reason.isEmpty ? 'Not provided' : reason),
          ],
        ),
        const SizedBox(height: 16),
        _AllergyGroup(
          title: 'Student skills & interests',
          values: skills,
          color: AppColors.green,
        ),
      ],
    );
  }
}

class _ApplicantDocuments extends StatelessWidget {
  const _ApplicantDocuments({
    required this.documents,
    required this.onViewDocument,
  });
  final List<AdmissionStudentDocument> documents;
  final ValueChanged<AdmissionStudentDocument> onViewDocument;

  static const _required = [
    ('PHOTO', 'Student photo'),
    ('BIRTH_CERTIFICATE', 'Birth certificate'),
    ('WEIGHING_CARD', 'Weighing card'),
    ('IMMUNIZATION_CARD', 'Immunization card'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _required.map((definition) {
        AdmissionStudentDocument? document;
        for (final item in documents) {
          if (item.documentType.toUpperCase() == definition.$1) {
            document = item;
            break;
          }
        }
        final uploaded = document != null;
        return InkWell(
          onTap: uploaded ? () => onViewDocument(document!) : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  uploaded
                      ? Icons.description_outlined
                      : Icons.file_present_outlined,
                  color: uploaded ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        definition.$2,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        uploaded ? document.fileName : 'Not uploaded',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _SmallValuePill(
                  label: uploaded ? 'View' : 'Missing',
                  color: uploaded ? AppColors.green : AppColors.muted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ApplicantGuardianContent extends StatelessWidget {
  const _ApplicantGuardianContent({required this.guardian});
  final AdmissionGuardian? guardian;

  @override
  Widget build(BuildContext context) {
    final value = guardian;
    if (value == null) {
      return const Text(
        'Guardian details are not available for this application.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    final raw = value.rawJson;
    final address = _admissionMap(raw['address']);
    final occupationValues =
        _admissionList(raw['occupations'] ?? raw['occupation'])
            .map((item) {
              final map = _admissionMap(item);
              return _admissionText(
                map?['name'] ?? map?['occupationName'] ?? item,
              );
            })
            .where((item) => item.isNotEmpty)
            .join(', ');
    final addressText = [
      _admissionText(address?['houseNumber']),
      _admissionText(address?['streetName']),
      _admissionText(_admissionMap(address?['city'])?['name']),
    ].where((item) => item.isNotEmpty).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InitialAvatar(name: value.displayName),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    [
                      if (value.relationship.isNotEmpty) value.relationship,
                      value.customGuardianId,
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (value.isPrimary)
              _SmallValuePill(label: 'Primary', color: AppColors.green),
          ],
        ),
        const SizedBox(height: 16),
        _ApplicantDetailGrid(
          fields: [
            ('Phone', value.phone.isEmpty ? 'Not provided' : value.phone),
            ('Email', value.email.isEmpty ? 'Not provided' : value.email),
            ('Address', addressText.isEmpty ? 'Not provided' : addressText),
            (
              'Occupation',
              occupationValues.isEmpty ? 'Not provided' : occupationValues,
            ),
          ],
        ),
      ],
    );
  }
}

class _RelatedApplicationRow extends StatelessWidget {
  const _RelatedApplicationRow({required this.student});
  final AdmissionStudent student;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _InitialAvatar(name: student.displayName),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${student.gradeLevel.isEmpty ? 'Class pending' : student.gradeLevel} · ${student.customStudentId}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          _SmallValuePill(
            label: _studentStatusLabel(student.status),
            color: _studentStatusColor(student.status),
          ),
        ],
      ),
    );
  }
}

class _ApplicantSubheading extends StatelessWidget {
  const _ApplicantSubheading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    );
  }
}

class _SmallValuePill extends StatelessWidget {
  const _SmallValuePill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: AppColors.green,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

enum _TimelineState { done, current, pending, rejected }

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.label,
    required this.detail,
    required this.state,
  });
  final String label;
  final String detail;
  final _TimelineState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _TimelineState.done => AppColors.green,
      _TimelineState.current => AppColors.blue,
      _TimelineState.rejected => AppColors.red,
      _TimelineState.pending => AppColors.border,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == _TimelineState.pending ? Colors.white : color,
              border: Border.all(color: color, width: 2),
            ),
            child: state == _TimelineState.done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : state == _TimelineState.current
                ? const Icon(Icons.circle, size: 8, color: Colors.white)
                : state == _TimelineState.rejected
                ? const Icon(Icons.close_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicantDetailData {
  const _ApplicantDetailData({
    required this.student,
    required this.guardian,
    required this.householdStudents,
    required this.documents,
    required this.conditionOptions,
    required this.vaccinationOptions,
  });

  final AdmissionStudent student;
  final AdmissionGuardian? guardian;
  final List<AdmissionStudent> householdStudents;
  final List<AdmissionStudentDocument> documents;
  final List<AdmissionMedicalConditionOption> conditionOptions;
  final List<AdmissionVaccinationOption> vaccinationOptions;

  List<AdmissionStudent> get otherApplications => householdStudents
      .where((item) => item.customStudentId != student.customStudentId)
      .toList();
}

List<String> _stringList(Object? value) {
  return _admissionList(value)
      .map(_admissionText)
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class _StudentApplication {
  const _StudentApplication({
    required this.id,
    required this.householdId,
    required this.admissionId,
    required this.studentName,
    required this.studentId,
    required this.guardianName,
    required this.guardianPhone,
    required this.applyingFor,
    required this.type,
    required this.appliedDate,
    required this.createdAt,
    required this.rawStatus,
    required this.status,
  });

  final int? id;
  final int? householdId;
  final int? admissionId;
  final String studentName;
  final String studentId;
  final String guardianName;
  final String guardianPhone;
  final String applyingFor;
  final String type;
  final String appliedDate;
  final String createdAt;
  final String rawStatus;
  final StudentApplicationStatus status;
}

class _HouseholdRecord {
  const _HouseholdRecord({
    this.householdId,
    this.admissionId,
    this.isPreview = false,
    required this.householdName,
    required this.primaryGuardian,
    required this.phone,
    required this.status,
    required this.statusColor,
    required this.students,
    required this.pendingGuardians,
    required this.started,
  });

  final int? householdId;
  final int? admissionId;
  final bool isPreview;
  final String householdName;
  final String primaryGuardian;
  final String phone;
  final String status;
  final Color statusColor;
  final int students;
  final int pendingGuardians;
  final String started;

  _HouseholdRecord copyWith({
    int? householdId,
    int? admissionId,
    bool? isPreview,
    String? householdName,
    String? primaryGuardian,
    String? phone,
    String? status,
    Color? statusColor,
    int? students,
    int? pendingGuardians,
    String? started,
  }) {
    return _HouseholdRecord(
      householdId: householdId ?? this.householdId,
      admissionId: admissionId ?? this.admissionId,
      isPreview: isPreview ?? this.isPreview,
      householdName: householdName ?? this.householdName,
      primaryGuardian: primaryGuardian ?? this.primaryGuardian,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      statusColor: statusColor ?? this.statusColor,
      students: students ?? this.students,
      pendingGuardians: pendingGuardians ?? this.pendingGuardians,
      started: started ?? this.started,
    );
  }
}

String _initialsForText(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '-';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

_HouseholdRecord _newHouseholdRecord() {
  return const _HouseholdRecord(
    householdName: 'New Household',
    primaryGuardian: 'Guardian pending',
    phone: 'Phone pending',
    status: 'Draft',
    statusColor: AppColors.muted,
    students: 0,
    pendingGuardians: 0,
    started: 'Today',
  );
}

String _guardianKey(AdmissionGuardian guardian) {
  final id = guardian.customGuardianId.trim();
  if (id.isNotEmpty) return id;
  final admissionId = guardian.admissionId;
  if (admissionId != null) return 'admission-$admissionId';
  return '${guardian.displayName}|${guardian.phone}|${guardian.email}';
}

class _HouseholdMember {
  const _HouseholdMember({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.color,
  });

  final String name;
  final String subtitle;
  final String status;
  final Color color;
}

class _HouseholdDashboardData {
  const _HouseholdDashboardData({
    required this.guardians,
    required this.students,
  });

  final List<AdmissionGuardian> guardians;
  final List<AdmissionStudent> students;
}

class _SummaryValue {
  const _SummaryValue(this.title, this.value, this.subtitle, this.color);
  final String title;
  final int value;
  final String subtitle;
  final Color color;
}

List<_HouseholdRecord> _householdsFromGuardians(
  List<AdmissionGuardian> guardians, {
  List<AdmissionStudent> students = const [],
}) {
  final studentCounts = <int, int>{};
  for (final student in students) {
    final householdId = student.householdId;
    if (householdId == null) continue;
    studentCounts.update(householdId, (count) => count + 1, ifAbsent: () => 1);
  }
  final grouped = <int, List<AdmissionGuardian>>{};
  for (final guardian in guardians) {
    final householdId = guardian.householdId;
    if (householdId == null) continue;
    grouped.putIfAbsent(householdId, () => []).add(guardian);
  }
  return grouped.entries.map((entry) {
    final records = entry.value;
    final primary = records.firstWhere(
      (guardian) => guardian.isPrimary,
      orElse: () => records.first,
    );
    final incomplete = records
        .where((guardian) => _isIncompleteGuardian(guardian.status))
        .length;
    final pending = records
        .where((guardian) => _isPendingReviewGuardian(guardian.status))
        .length;
    return _HouseholdRecord(
      householdId: entry.key,
      admissionId: primary.admissionId,
      householdName: '${primary.displayName} Household',
      primaryGuardian: primary.displayName,
      phone: primary.phone.isEmpty ? 'No phone yet' : primary.phone,
      status: incomplete > 0
          ? 'Guardian incomplete'
          : pending > 0
          ? 'Pending review'
          : 'Ready for student',
      statusColor: incomplete > 0
          ? AppColors.amber
          : pending > 0
          ? AppColors.blue
          : AppColors.green,
      students: studentCounts[entry.key] ?? 0,
      pendingGuardians: pending,
      started: _formatDateText(primary.createdAt),
    );
  }).toList()..sort((a, b) => a.householdName.compareTo(b.householdName));
}

bool _isIncompleteGuardian(String status) {
  final normalized = status.toUpperCase();
  return normalized.contains('DRAFT') || normalized.contains('INCOMPLETE');
}

bool _isPendingReviewGuardian(String status) {
  final normalized = status.toUpperCase();
  return normalized.contains('PENDING') || normalized.contains('REVIEW');
}

StudentApplicationStatus _studentStatusFromApi(String status) {
  final normalized = status.toUpperCase();
  if (normalized.contains('PENDING')) {
    return StudentApplicationStatus.pendingApproval;
  }
  if (normalized.contains('APPROVED')) return StudentApplicationStatus.approved;
  if (normalized.contains('REJECTED')) return StudentApplicationStatus.rejected;
  if (normalized.contains('ACTIVE')) return StudentApplicationStatus.active;
  return StudentApplicationStatus.draft;
}

String _guardianStatusLabel(String status) {
  final normalized = status.trim();
  if (normalized.isEmpty) return 'In progress';
  return _titleCase(normalized.replaceAll('_', ' '));
}

Color _guardianStatusColor(String status) {
  final normalized = status.toUpperCase();
  if (normalized.contains('APPROVED') || normalized.contains('ACTIVE')) {
    return AppColors.green;
  }
  if (normalized.contains('REJECTED')) return AppColors.red;
  if (normalized.contains('PENDING')) return AppColors.amber;
  return AppColors.blue;
}

String _studentStatusLabel(String status) {
  final normalized = status.trim();
  if (normalized.isEmpty) return 'In progress';
  return _titleCase(normalized.replaceAll('_', ' '));
}

Color _studentStatusColor(String status) {
  final normalized = status.toUpperCase();
  if (normalized.contains('ACTIVE') || normalized.contains('APPROVED')) {
    return AppColors.green;
  }
  if (normalized.contains('REJECTED')) return AppColors.red;
  if (normalized.contains('PENDING')) return AppColors.amber;
  return AppColors.blue;
}

String _titleCase(String value) {
  return value
      .split(RegExp(r'[\s_]+'))
      .where((part) => part.trim().isNotEmpty)
      .map((part) {
        final lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String _formatDateText(String value) {
  if (value.trim().isEmpty) return 'Not provided';
  final parsed = DateTime.tryParse(value) ?? _parseBackendDate(value);
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

DateTime? _parseBackendDate(String value) {
  final match = RegExp(
    r'^(\d{4})\D+(\d{1,2})\D+(\d{1,2})',
  ).firstMatch(value.trim());
  if (match == null) return null;

  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
