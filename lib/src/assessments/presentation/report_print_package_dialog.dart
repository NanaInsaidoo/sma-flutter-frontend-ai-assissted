import 'package:flutter/material.dart';

import '../data/assessment_api_client.dart';
import 'report_pdf_download.dart';

Future<bool?> showReportPrintPackageDialog({
  required BuildContext context,
  required AssessmentApiClient api,
  required String customSchoolId,
  required AssessmentFormSetup setup,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ReportPrintPackageDialog(
    api: api,
    customSchoolId: customSchoolId,
    setup: setup,
  ),
);

class ReportPrintPackageDialog extends StatefulWidget {
  const ReportPrintPackageDialog({
    super.key,
    required this.api,
    required this.customSchoolId,
    required this.setup,
  });

  final AssessmentApiClient api;
  final String customSchoolId;
  final AssessmentFormSetup setup;

  @override
  State<ReportPrintPackageDialog> createState() =>
      _ReportPrintPackageDialogState();
}

class _ReportPrintPackageDialogState extends State<ReportPrintPackageDialog> {
  late final Future<ReportPrintPackageOptions> _options = widget.api
      .getReportPrintPackageOptions(
        customSchoolId: widget.customSchoolId,
        termId: widget.setup.termId,
        academicYearId: widget.setup.academicYearId,
      );
  String _scope = 'ENTIRE_SCHOOL';
  String _organization = 'HOUSEHOLD';
  bool _householdCover = true;
  bool _preparing = false;
  bool _completed = false;
  String? _error;
  String _studentSearch = '';
  final Set<int> _gradeLevelIds = {};
  final Set<int> _streamIds = {};
  final Set<String> _studentIds = {};

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('report-print-package-dialog'),
    titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
    contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
    actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
    title: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F6F4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.print_outlined, color: Color(0xFF007D72)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prepare print package',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 2),
              Text(
                'Arrange official report cards for physical distribution.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: _preparing ? null : () => Navigator.pop(context, false),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
    content: SizedBox(
      width: 760,
      child: FutureBuilder<ReportPrintPackageOptions>(
        future: _options,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SizedBox(
              height: 260,
              child: _LoadError(
                message: snapshot.error is AssessmentApiException
                    ? (snapshot.error! as AssessmentApiException).message
                    : 'Report options could not be loaded.',
                onClose: () => Navigator.pop(context, false),
              ),
            );
          }
          return _content(snapshot.data!);
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: _preparing ? null : () => Navigator.pop(context, _completed),
        child: Text(_completed ? 'Close' : 'Cancel'),
      ),
      if (!_completed)
        FutureBuilder<ReportPrintPackageOptions>(
          future: _options,
          builder: (context, snapshot) {
            final ready = snapshot.hasData
                ? _selected(
                    snapshot.data!,
                  ).where((student) => student.ready).length
                : 0;
            return FilledButton.icon(
              key: const ValueKey('prepare-report-print-package'),
              onPressed: _preparing || ready == 0 || !snapshot.hasData
                  ? null
                  : () => _prepare(snapshot.data!),
              icon: _preparing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(_preparing ? 'Preparing PDF…' : 'Prepare PDF'),
            );
          },
        ),
    ],
  );

  Widget _content(ReportPrintPackageOptions options) {
    final selected = _selected(options);
    final ready = selected.where((student) => student.ready).toList();
    final excluded = selected.length - ready.length;
    final households = ready
        .map((student) => student.householdId)
        .whereType<int>()
        .toSet()
        .length;
    final classes = ready
        .map((student) => student.streamId)
        .whereType<int>()
        .toSet()
        .length;
    final unassigned = ready
        .where((student) => student.householdId == null)
        .length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 690),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(number: '1', title: 'Choose reports'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ScopeChoice(
                  key: const ValueKey('print-scope-entire-school'),
                  selected: _scope == 'ENTIRE_SCHOOL',
                  icon: Icons.apartment_outlined,
                  label: 'Entire school',
                  onTap: () => setState(() => _scope = 'ENTIRE_SCHOOL'),
                ),
                _ScopeChoice(
                  selected: _scope == 'EDUCATION_LEVEL',
                  icon: Icons.layers_outlined,
                  label: 'Education level',
                  onTap: () => setState(() => _scope = 'EDUCATION_LEVEL'),
                ),
                _ScopeChoice(
                  selected: _scope == 'SELECTED_CLASSES',
                  icon: Icons.meeting_room_outlined,
                  label: 'Selected classes',
                  onTap: () => setState(() => _scope = 'SELECTED_CLASSES'),
                ),
                _ScopeChoice(
                  selected: _scope == 'SELECTED_STUDENTS',
                  icon: Icons.person_search_outlined,
                  label: 'Selected students',
                  onTap: () => setState(() => _scope = 'SELECTED_STUDENTS'),
                ),
              ],
            ),
            if (_scope == 'EDUCATION_LEVEL') ...[
              const SizedBox(height: 10),
              _selectionBox(
                widget.setup.gradeLevels.map((level) {
                  final selected = _gradeLevelIds.contains(level.id);
                  return FilterChip(
                    label: Text(level.name),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      value
                          ? _gradeLevelIds.add(level.id)
                          : _gradeLevelIds.remove(level.id);
                    }),
                  );
                }).toList(),
              ),
            ],
            if (_scope == 'SELECTED_CLASSES') ...[
              const SizedBox(height: 10),
              _selectionBox(
                widget.setup.streams.map((stream) {
                  final selected = _streamIds.contains(stream.id);
                  return FilterChip(
                    label: Text(stream.label),
                    selected: selected,
                    onSelected: (value) => setState(() {
                      value
                          ? _streamIds.add(stream.id)
                          : _streamIds.remove(stream.id);
                    }),
                  );
                }).toList(),
              ),
            ],
            if (_scope == 'SELECTED_STUDENTS') ...[
              const SizedBox(height: 10),
              _studentSelector(options),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4FAF9),
                border: Border.all(color: const Color(0xFFCBE5E1)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF00897B), size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Only include reports ready for printing',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'Default',
                    style: TextStyle(
                      color: Color(0xFF007D72),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionTitle(number: '2', title: 'Organize package by'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _OrganizationChoice(
                    key: const ValueKey('organize-by-household'),
                    selected: _organization == 'HOUSEHOLD',
                    icon: Icons.family_restroom_outlined,
                    title: 'Household / family',
                    subtitle: 'Best for parent collection',
                    onTap: () => setState(() => _organization = 'HOUSEHOLD'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OrganizationChoice(
                    key: const ValueKey('organize-by-class'),
                    selected: _organization == 'CLASS',
                    icon: Icons.class_outlined,
                    title: 'Class and section',
                    subtitle: 'Best for class-teacher distribution',
                    onTap: () => setState(() => _organization = 'CLASS'),
                  ),
                ),
              ],
            ),
            if (_organization == 'HOUSEHOLD') ...[
              const SizedBox(height: 10),
              SwitchListTile(
                key: const ValueKey('household-cover-sheet'),
                value: _householdCover,
                onChanged: (value) => setState(() => _householdCover = value),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: const Color(0xFFF8FAFC),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                title: const Text(
                  'Add a household cover sheet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Lists the students and their classes. On by default.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const _SectionTitle(number: '3', title: 'Output format'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0F9D8C), width: 1.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF007D72)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'One combined school PDF',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(Icons.check_circle, color: Color(0xFF00897B)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SummaryCard(
              ready: ready.length,
              excluded: excluded,
              households: households,
              classes: classes,
              unassigned: unassigned,
              organization: _organization,
              includeHouseholdCover: _householdCover,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              _InlineMessage(message: _error!, error: true),
            ],
            if (_completed) ...[
              const SizedBox(height: 10),
              const _InlineMessage(
                message:
                    'Print package prepared. The PDF download has started.',
                error: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _selectionBox(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Wrap(spacing: 7, runSpacing: 7, children: children),
  );

  Widget _studentSelector(ReportPrintPackageOptions options) {
    final query = _studentSearch.trim().toLowerCase();
    final students = options.students
        .where(
          (student) =>
              query.isEmpty ||
              student.studentName.toLowerCase().contains(query) ||
              student.customStudentId.toLowerCase().contains(query) ||
              student.className.toLowerCase().contains(query),
        )
        .toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search student, ID or class',
              prefixIcon: Icon(Icons.search, size: 19),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _studentSearch = value),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _studentIds.contains(student.customStudentId),
                  onChanged: (value) => setState(() {
                    value == true
                        ? _studentIds.add(student.customStudentId)
                        : _studentIds.remove(student.customStudentId);
                  }),
                  title: Text(
                    student.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${student.customStudentId} · ${student.className} · ${student.readinessLabel}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<ReportPrintPackageStudent> _selected(
    ReportPrintPackageOptions options,
  ) => switch (_scope) {
    'EDUCATION_LEVEL' =>
      options.students
          .where((student) => _gradeLevelIds.contains(student.gradeLevelId))
          .toList(),
    'SELECTED_CLASSES' =>
      options.students
          .where((student) => _streamIds.contains(student.streamId))
          .toList(),
    'SELECTED_STUDENTS' =>
      options.students
          .where((student) => _studentIds.contains(student.customStudentId))
          .toList(),
    _ => options.students,
  };

  Future<void> _prepare(ReportPrintPackageOptions options) async {
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      final bytes = await widget.api.prepareReportPrintPackage(
        customSchoolId: widget.customSchoolId,
        termId: widget.setup.termId,
        academicYearId: widget.setup.academicYearId,
        scope: _scope,
        organization: _organization,
        includeHouseholdCoverSheet:
            _organization == 'HOUSEHOLD' && _householdCover,
        gradeLevelIds: _gradeLevelIds.toList(),
        streamIds: _streamIds.toList(),
        customStudentIds: _studentIds.toList(),
      );
      final safeTerm = widget.setup.termName.replaceAll(RegExp(r'\W+'), '_');
      final safeYear = widget.setup.academicYearName.replaceAll(
        RegExp(r'\W+'),
        '_',
      );
      await downloadReportPdf(
        'School_Report_Print_Package_${safeTerm}_$safeYear.pdf',
        bytes,
      );
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _completed = true;
      });
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparing = false;
        _error = 'The school print package could not be prepared.';
      });
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF007D72),
        ),
        child: Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _ScopeChoice extends StatelessWidget {
  const _ScopeChoice({
    super.key,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(9),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F6F4) : Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFF0F9D8C) : const Color(0xFFD5DEE7),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF007D72)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (selected) ...[
            const SizedBox(width: 7),
            const Icon(Icons.check_circle, size: 16, color: Color(0xFF00897B)),
          ],
        ],
      ),
    ),
  );
}

class _OrganizationChoice extends StatelessWidget {
  const _OrganizationChoice({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8F6F4) : Colors.white,
        border: Border.all(
          color: selected ? const Color(0xFF0F9D8C) : const Color(0xFFD5DEE7),
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF007D72)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? const Color(0xFF00897B) : const Color(0xFF94A3B8),
          ),
        ],
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.ready,
    required this.excluded,
    required this.households,
    required this.classes,
    required this.unassigned,
    required this.organization,
    required this.includeHouseholdCover,
  });
  final int ready;
  final int excluded;
  final int households;
  final int classes;
  final int unassigned;
  final String organization;
  final bool includeHouseholdCover;

  @override
  Widget build(BuildContext context) {
    final byHousehold = organization == 'HOUSEHOLD';
    return Container(
      key: const ValueKey('report-print-package-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFDCE5ED)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Package summary',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            '$ready ready report${ready == 1 ? '' : 's'} · '
            '${byHousehold ? '$households household${households == 1 ? '' : 's'}' : '$classes class${classes == 1 ? '' : 'es'}'}',
          ),
          Text(
            'Organized by ${byHousehold ? 'household / family' : 'class and section'}'
            '${byHousehold && includeHouseholdCover ? ' · Cover sheets included' : ''}',
            style: const TextStyle(color: Color(0xFF475569)),
          ),
          if (excluded > 0)
            Text(
              '$excluded report${excluded == 1 ? '' : 's'} excluded because ${excluded == 1 ? 'it is' : 'they are'} not ready',
              style: const TextStyle(color: Color(0xFFB45309)),
            ),
          if (byHousehold && unassigned > 0)
            Text(
              '$unassigned student${unassigned == 1 ? '' : 's'} without a household will be placed at the end',
              style: const TextStyle(color: Color(0xFFB45309)),
            ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.error});
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: error ? const Color(0xFFB91C1C) : const Color(0xFF047857),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 44,
          color: Color(0xFFDC2626),
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onClose, child: const Text('Close')),
      ],
    ),
  );
}
