import 'package:flutter/material.dart';

import '../../assessments/presentation/report_pdf_download.dart';
import '../../theme/app_theme.dart';
import '../data/management_report_api_client.dart';
import '../domain/management_report_models.dart';
import '../domain/report_access_policy.dart';

enum _ReportCategory { all, term, academic, finance, operations }

class ReportsLibraryScreen extends StatefulWidget {
  const ReportsLibraryScreen({
    super.key,
    required this.schoolName,
    required this.schoolId,
    required this.academicYear,
    required this.currentTerm,
    required this.viewerRole,
    this.accessToken,
    this.onRefreshAccessToken,
    this.repository,
  });

  final String schoolName;
  final String schoolId;
  final String academicYear;
  final String currentTerm;
  final String viewerRole;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final ManagementReportRepository? repository;

  @override
  State<ReportsLibraryScreen> createState() => _ReportsLibraryScreenState();
}

class _ReportsLibraryScreenState extends State<ReportsLibraryScreen> {
  final _searchController = TextEditingController();
  _ReportCategory _category = _ReportCategory.all;
  String _year = 'All years';
  String _term = 'All terms';
  final Set<String> _downloading = {};
  late final ManagementReportRepository _repository;
  List<_ReportItem> _reports = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ManagementReportApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    _load();
  }

  @override
  void didUpdateWidget(covariant ReportsLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ReportAccessPolicy.normalizeRole(oldWidget.viewerRole) !=
        ReportAccessPolicy.normalizeRole(widget.viewerRole)) {
      _clearFilters();
    }
  }

  Future<void> _load() async {
    try {
      final reports = await _repository.list(widget.schoolId);
      if (!mounted) return;
      setState(() {
        _reports = reports.map(_ReportItem.fromReport).toList();
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ReportItem> get _accessibleReports => _reports
      .where(
        (report) => ReportAccessPolicy.canViewReport(
          role: widget.viewerRole,
          type: report.type,
          category: report.category.name,
        ),
      )
      .toList(growable: false);

  List<_ReportItem> get _visibleReports {
    final query = _searchController.text.trim().toLowerCase();
    return _accessibleReports.where((report) {
      final matchesSearch =
          query.isEmpty ||
          report.title.toLowerCase().contains(query) ||
          report.description.toLowerCase().contains(query);
      return matchesSearch &&
          (_category == _ReportCategory.all || report.category == _category) &&
          (_year == 'All years' || report.year == _year) &&
          (_term == 'All terms' || report.term == _term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('reports-library-screen'),
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final pagePadding = compact ? 16.0 : 28.0;
          final contentWidth = (constraints.maxWidth - (pagePadding * 2))
              .clamp(0.0, 1420.0)
              .toDouble();
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pagePadding, 24, pagePadding, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(compact),
                    const SizedBox(height: 16),
                    _buildAccessNotice(),
                    const SizedBox(height: 20),
                    _buildPreviewNotice(),
                    const SizedBox(height: 20),
                    if (_loading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 20),
                    ],
                    if (_loadError != null) ...[
                      _buildLoadError(),
                      const SizedBox(height: 20),
                    ],
                    _buildSummary(contentWidth),
                    const SizedBox(height: 28),
                    _sectionHeading(
                      'All reports',
                      'Find current and historical reports by school year, term or area.',
                    ),
                    const SizedBox(height: 14),
                    _buildFilters(compact),
                    const SizedBox(height: 16),
                    _buildReportList(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool compact) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Management reports',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'View the current and historical reports available to your workspace.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: compact ? 15 : 17,
            height: 1.35,
          ),
        ),
      ],
    );
    final help = OutlinedButton.icon(
      onPressed: _showReportHelp,
      icon: const Icon(Icons.help_outline_rounded),
      label: const Text('How reports work'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        side: const BorderSide(color: AppColors.green),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [title, const SizedBox(height: 16), help],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: title),
        help,
      ],
    );
  }

  Widget _buildAccessNotice() {
    final roleLabel = ReportAccessPolicy.roleLabel(widget.viewerRole);
    return Container(
      key: const ValueKey('report-access-notice'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        border: Border.all(color: const Color(0xFFC9D8F5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.blue,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$roleLabel report access',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${ReportAccessPolicy.accessDescription(widget.viewerRole)} '
                  'Reports outside this responsibility are hidden.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F6),
        border: Border.all(color: const Color(0xFFCFE6E2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.green, size: 21),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Open-term reports update from recorded school data. Closed-term reports are final snapshots and cannot change.',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(_loadError ?? 'Reports could not be loaded.')),
          TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _loadError = null;
              });
              _load();
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );

  Widget _buildSummary(double width) {
    final cardWidth = width < 620
        ? width
        : width < 1040
        ? (width - 14) / 2
        : (width - 42) / 4;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _SummaryCard(
          width: cardWidth,
          label: 'Available reports',
          value: '${_accessibleReports.length}',
          icon: Icons.folder_copy_outlined,
          color: AppColors.blue,
        ),
        _SummaryCard(
          width: cardWidth,
          label: 'Final & locked',
          value:
              '${_accessibleReports.where((r) => r.status == _ReportStatus.finalReport).length}',
          icon: Icons.lock_outline_rounded,
          color: AppColors.green,
        ),
        _SummaryCard(
          width: cardWidth,
          label: 'Current term',
          value: widget.currentTerm,
          icon: Icons.calendar_today_outlined,
          color: AppColors.purple,
        ),
        _SummaryCard(
          width: cardWidth,
          label: 'School year',
          value: widget.academicYear,
          icon: Icons.school_outlined,
          color: AppColors.amber,
        ),
      ],
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFilters(bool compact) {
    final search = TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Search reports',
        hintText: 'e.g. facility, attendance, finance',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
    final years = [
      'All years',
      ..._accessibleReports
          .map((e) => e.year)
          .where((e) => e.isNotEmpty)
          .toSet(),
    ];
    final terms = [
      'All terms',
      ..._accessibleReports
          .map((e) => e.term)
          .where((e) => e.isNotEmpty)
          .toSet(),
    ];
    final year = DropdownButtonFormField<String>(
      value: _year,
      decoration: const InputDecoration(labelText: 'Academic year'),
      items: years
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => setState(() => _year = value ?? 'All years'),
    );
    final term = DropdownButtonFormField<String>(
      value: _term,
      decoration: const InputDecoration(labelText: 'Term'),
      items: terms
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) => setState(() => _term = value ?? 'All terms'),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              search,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: year),
                  const SizedBox(width: 10),
                  Expanded(child: term),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(flex: 2, child: search),
                  const SizedBox(width: 12),
                  Expanded(child: year),
                  const SizedBox(width: 12),
                  Expanded(child: term),
                ],
              ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _ReportCategory.values.map((category) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_categoryLabel(category)),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                      selectedColor: AppColors.greenSoft,
                      labelStyle: TextStyle(
                        color: _category == category
                            ? const Color(0xFF176D63)
                            : AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: _category == category
                            ? AppColors.green
                            : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportList() {
    final reports = _visibleReports;
    if (reports.isEmpty) {
      final noRoleReports = _accessibleReports.isEmpty;
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
          child: Center(
            child: Column(
              children: [
                const Icon(
                  Icons.find_in_page_outlined,
                  color: AppColors.muted,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  noRoleReports
                      ? 'No reports are available for this workspace yet.'
                      : 'No reports match these filters.',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (noRoleReports)
                  Text(
                    'Reports will appear here when an authorised report is generated for the ${ReportAccessPolicy.roleLabel(widget.viewerRole).toLowerCase()} workspace.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  )
                else
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: [
                Text(
                  '${reports.length} ${reports.length == 1 ? 'report' : 'reports'}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Closed-term reports are locked',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          ...reports.indexed.map(
            (entry) => _ReportRow(
              key: ValueKey('report-row-${entry.$2.termId}-${entry.$2.type}'),
              report: entry.$2,
              showDivider: entry.$1 != reports.length - 1,
              onView: () => _openPreview(entry.$2),
              onDownload: () => _downloadReport(entry.$2),
            ),
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _category = _ReportCategory.all;
      _year = 'All years';
      _term = 'All terms';
    });
  }

  void _showReportHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How reports work'),
        content: const SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpLine(
                icon: Icons.sync_outlined,
                title: 'Live reports',
                text: 'Update as work is recorded during the current term.',
              ),
              SizedBox(height: 18),
              _HelpLine(
                icon: Icons.lock_outline_rounded,
                title: 'Final reports',
                text: 'Become locked historical records when a term is closed.',
              ),
              SizedBox(height: 18),
              _HelpLine(
                icon: Icons.verified_user_outlined,
                title: 'Recorded sign-offs',
                text:
                    'Show the authorised user and submission time; names are not entered manually.',
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport(_ReportItem report) async {
    if (!_canAccess(report)) {
      _showAccessChangedMessage();
      return;
    }
    final key = '${report.title}-${report.term}-${report.year}';
    if (_downloading.contains(key)) return;
    setState(() => _downloading.add(key));
    try {
      final bytes = await _repository.downloadPdf(
        widget.schoolId,
        report.termId,
        report.type,
      );
      final stem = '${report.title}-${report.year}-${report.term}'
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final fileName = '$stem.pdf';
      final downloaded = await downloadReportPdf(fileName, bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              downloaded
                  ? '${report.title} downloaded.'
                  : 'PDF downloads are not available on this device.',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('The report PDF could not be downloaded. Try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _downloading.remove(key));
    }
  }

  void _openPreview(_ReportItem report) {
    if (!_canAccess(report)) {
      _showAccessChangedMessage();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => _ReportPreviewDialog(
        report: report,
        onDownload: () {
          Navigator.pop(context);
          _downloadReport(report);
        },
      ),
    );
  }

  bool _canAccess(_ReportItem report) => ReportAccessPolicy.canViewReport(
    role: widget.viewerRole,
    type: report.type,
    category: report.category.name,
  );

  void _showAccessChangedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'This report is not available in your current workspace.',
          ),
        ),
      );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    super.key,
    required this.report,
    required this.showDivider,
    required this.onView,
    required this.onDownload,
  });

  final _ReportItem report;
  final bool showDivider;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F5F5),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(report.icon, color: AppColors.green, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${report.term} • ${report.year}  ·  ${report.updated}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusPill(status: report.status),
                const SizedBox(width: 10),
                TextButton.icon(
                  key: ValueKey('report-view-${report.termId}-${report.type}'),
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                ),
                TextButton.icon(
                  key: ValueKey(
                    'report-download-${report.termId}-${report.type}',
                  ),
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download'),
                ),
              ],
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        identity,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: actions),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 14),
                        actions,
                      ],
                    ),
            );
          },
        ),
        if (showDivider) const Divider(height: 1, indent: 18, endIndent: 18),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, background, icon) = switch (status) {
      _ReportStatus.finalReport => (
        'Final · Locked',
        const Color(0xFF176D63),
        AppColors.greenSoft,
        Icons.lock_outline_rounded,
      ),
      _ReportStatus.live => (
        'Live',
        const Color(0xFF315EB6),
        const Color(0xFFEAF1FF),
        Icons.sync_rounded,
      ),
      _ReportStatus.published => (
        'Published',
        const Color(0xFF6548C7),
        const Color(0xFFF0ECFF),
        Icons.check_circle_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPreviewDialog extends StatelessWidget {
  const _ReportPreviewDialog({required this.report, required this.onDownload});

  final _ReportItem report;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: size.height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(report.icon, color: AppColors.green),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${report.term} • ${report.year}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        report.status == _ReportStatus.finalReport
                            ? 'Final snapshot — these figures were locked when the term closed.'
                            : 'Live report — figures update as school records are added.',
                        style: TextStyle(
                          color: Color(0xFF7A5612),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _previewContent(report),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
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

  Widget _previewContent(_ReportItem report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PreviewTitle(title: 'Report summary', text: report.description),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: report.metrics.entries
              .where((entry) => entry.value is! Iterable && entry.value is! Map)
              .map(
                (entry) => _PreviewMetric(
                  label: _readable(entry.key),
                  value: _metricValue(entry.key, entry.value),
                ),
              )
              .toList(),
        ),
        for (final section in report.sections) ...[
          const SizedBox(height: 24),
          Text(
            section.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 38,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 54,
              columns: section.headers
                  .map(
                    (header) => DataColumn(
                      label: Text(
                        header,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  )
                  .toList(),
              rows: section.rows
                  .map(
                    (row) => DataRow(
                      cells: List.generate(
                        section.headers.length,
                        (index) => DataCell(
                          Text(
                            index < row.length
                                ? _tableValue(
                                    section.headers[index],
                                    row[index],
                                  )
                                : '—',
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (report.notes.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Management notes',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...report.notes.map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '• $note',
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTitle extends StatelessWidget {
  const _PreviewTitle({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _HelpLine extends StatelessWidget {
  const _HelpLine({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.green, size: 22),
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
                text,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ReportStatus { finalReport, live, published }

class _ReportItem {
  const _ReportItem({
    required this.termId,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.year,
    required this.term,
    required this.status,
    required this.updated,
    required this.icon,
    required this.metrics,
    required this.sections,
    required this.notes,
  });

  final int termId;
  final String type;
  final String title;
  final String description;
  final _ReportCategory category;
  final String year;
  final String term;
  final _ReportStatus status;
  final String updated;
  final IconData icon;
  final Map<String, Object?> metrics;
  final List<ManagementReportSection> sections;
  final List<String> notes;

  factory _ReportItem.fromReport(ManagementReport report) {
    final type = report.type.toUpperCase();
    final category = switch (report.category.toUpperCase()) {
      'ACADEMIC' => _ReportCategory.academic,
      'FINANCE' => _ReportCategory.finance,
      'OPERATIONS' => _ReportCategory.operations,
      _ => _ReportCategory.term,
    };
    final icon = switch (type) {
      'HEADMASTER' => Icons.assignment_turned_in_outlined,
      'OWNER' => Icons.corporate_fare_outlined,
      'ACADEMIC_PERFORMANCE' => Icons.analytics_outlined,
      'FINANCE' => Icons.account_balance_outlined,
      'ADMISSIONS' => Icons.person_add_alt_1_outlined,
      'STAFF_PERFORMANCE' => Icons.reviews_outlined,
      'FACILITY' => Icons.domain_verification_outlined,
      'STUDENT_REPORTS' => Icons.school_outlined,
      'STUDENT_ATTENDANCE' => Icons.how_to_reg_outlined,
      'STAFF_ATTENDANCE' => Icons.badge_outlined,
      'INCIDENTS' => Icons.health_and_safety_outlined,
      'READINESS' => Icons.event_available_outlined,
      _ => Icons.description_outlined,
    };
    return _ReportItem(
      termId: report.termId,
      type: type,
      title: report.title,
      description: report.description,
      category: category,
      year: report.academicYear,
      term: report.term,
      status: report.status == 'FINAL_LOCKED'
          ? _ReportStatus.finalReport
          : _ReportStatus.live,
      updated: report.closedAt != null
          ? 'Closed ${_shortDate(report.closedAt!)}'
          : 'Live report',
      icon: icon,
      metrics: report.metrics,
      sections: report.sections,
      notes: report.notes,
    );
  }
}

String _shortDate(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _readable(String value) => value
    .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _displayValue(Object? value) {
  if (value == null) return '—';
  final text = '$value';
  final parsed = DateTime.tryParse(text);
  return parsed == null ? text : _shortDate(parsed);
}

String _metricValue(String key, Object? value) =>
    _isMoneyLabel(key) ? _moneyValue(value) : _displayValue(value);

String _tableValue(String header, Object? value) =>
    _isMoneyLabel(header) ? _moneyValue(value) : _displayValue(value);

String _moneyValue(Object? value) {
  if (value is! num) return _displayValue(value);
  return 'GH₵${value.toStringAsFixed(2)}';
}

bool _isMoneyLabel(String value) {
  final label = value.toLowerCase().replaceAll(' ', '');
  return label.contains('amount') ||
      label.contains('billed') ||
      label.contains('collected') ||
      label.contains('outstanding') ||
      label.contains('spend') ||
      label.contains('expense');
}

String _categoryLabel(_ReportCategory category) => switch (category) {
  _ReportCategory.all => 'All',
  _ReportCategory.term => 'Term',
  _ReportCategory.academic => 'Academic',
  _ReportCategory.finance => 'Finance',
  _ReportCategory.operations => 'Operations',
};
