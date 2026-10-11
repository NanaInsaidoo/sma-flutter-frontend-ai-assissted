import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../assessments/presentation/report_pdf_download.dart';
import '../../theme/app_theme.dart';
import '../domain/headmaster_term_closure_models.dart';
import 'facility_checklist_template_pdf.dart';

class FacilityInspectionPrototype extends StatefulWidget {
  const FacilityInspectionPrototype({
    super.key,
    required this.onBack,
    required this.schoolId,
    required this.termName,
    required this.repository,
    this.actorUserId,
    this.onChanged,
  });

  final VoidCallback onBack;
  final String schoolId;
  final String termName;
  final HeadmasterTermClosureRepository repository;
  final int? actorUserId;
  final VoidCallback? onChanged;

  @override
  State<FacilityInspectionPrototype> createState() =>
      _FacilityInspectionPrototypeState();
}

enum _InspectionTab { checklist, flags, report }

enum _Condition { good, fair, poor, notApplicable }

class _FacilityInspectionPrototypeState
    extends State<FacilityInspectionPrototype> {
  _InspectionTab _tab = _InspectionTab.checklist;
  final Set<String> _openDetails = {};
  final Map<String, _Condition> _ratings = {};
  final Map<String, _FlagDetail> _flagDetails = {};
  final Map<String, List<_EvidencePhoto>> _evidencePhotos = {};
  Map<String, String> _acknowledgements = {};
  Map<String, dynamic> _existingFacilities = {};
  bool _loading = true;
  bool _saving = false;
  bool _submitted = false;
  DateTime? _savedAt;
  DateTime? _closingDate;
  final _headteacher = TextEditingController(text: 'Nana Boateng');
  final _assistantHead = TextEditingController(text: 'Adwoa Mensah');
  final _communityChair = TextEditingController(text: 'Ama Nyarko');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headteacher.dispose();
    _assistantHead.dispose();
    _communityChair.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final closure = await widget.repository.get(widget.schoolId);
      final facilities = Map<String, dynamic>.from(closure.facilities);
      final storedRatings = facilities['ratings'];
      final storedFlags = facilities['findings'];
      if (!mounted) return;
      setState(() {
        _acknowledgements = Map<String, String>.from(closure.acknowledgements);
        _existingFacilities = facilities;
        _submitted = facilities['inspectionCompleted'] == true;
        _savedAt = DateTime.tryParse('${facilities['savedAt'] ?? ''}');
        _closingDate = _parseDate(
          closure.transitionPreview['currentTermClosingDate'],
        );
        if (storedRatings is Map) {
          for (final entry in storedRatings.entries) {
            final parsed = _conditionFromApi('${entry.value}');
            if (parsed != null) _ratings['${entry.key}'] = parsed;
          }
        }
        if (storedFlags is Map) {
          for (final entry in storedFlags.entries) {
            if (entry.value is Map) {
              _flagDetails['${entry.key}'] = _FlagDetail.fromMap(
                Map<String, dynamic>.from(entry.value as Map),
              );
            }
          }
        }
        final signoff = facilities['signoff'];
        if (signoff is Map) {
          _headteacher.text = '${signoff['headteacher'] ?? ''}';
          _assistantHead.text = '${signoff['assistantHead'] ?? ''}';
          _communityChair.text = '${signoff['communityChair'] ?? ''}';
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not load the inspection: $error', error: true);
    }
  }

  int get _totalItems => _sections.fold(0, (sum, s) => sum + s.items.length);
  int get _completed => _ratings.length;
  int get _flags => _flagDetails.length;
  int get _toInspect => _totalItems - _completed;
  int get _score {
    var points = 0.0;
    var rated = 0;
    for (final condition in _ratings.values) {
      if (condition == _Condition.notApplicable) continue;
      rated++;
      if (condition == _Condition.good) points += 1;
      if (condition == _Condition.fair) points += .5;
    }
    return rated == 0 ? 0 : (points / rated * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 52),
        children: [
          _pageHeader(),
          const SizedBox(height: 18),
          _previewNotice(),
          const SizedBox(height: 16),
          _summaryStrip(),
          const SizedBox(height: 14),
          _tabs(),
          const SizedBox(height: 18),
          switch (_tab) {
            _InspectionTab.checklist => _checklist(),
            _InspectionTab.flags => _managementFlags(),
            _InspectionTab.report => _report(),
          },
        ],
      ),
    );
  }

  Widget _pageHeader() => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = constraints.maxWidth < 760;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to Term Closure'),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 8),
          const Text(
            'End-of-term facility inspection',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Inspect every applicable area, document problems and assign follow-up work before the school closes.',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Meta(icon: Icons.flag_outlined, label: widget.termName),
              if (_closingDate != null)
                _Meta(
                  icon: Icons.event_outlined,
                  label: 'Term closes ${_formatDate(_closingDate!)}',
                ),
            ],
          ),
        ],
      );
      final actions = Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: _downloadChecklistTemplate,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download checklist template'),
          ),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _save(submit: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save draft'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(submit: true),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(_submitted ? 'Update inspection' : 'Submit inspection'),
          ),
        ],
      );
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 16), actions],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: title),
          const SizedBox(width: 24),
          actions,
        ],
      );
    },
  );

  Widget _previewNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: _submitted ? AppColors.greenSoft : const Color(0xFFEFF6FF),
      border: Border.all(
        color: _submitted
            ? AppColors.green.withValues(alpha: .3)
            : AppColors.blue.withValues(alpha: .25),
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          _submitted ? Icons.verified_outlined : Icons.cloud_done_outlined,
          color: _submitted ? AppColors.green : AppColors.blue,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _submitted
                ? 'Inspection submitted. You can update and resubmit it until the term is closed.'
                : _savedAt == null
                ? 'This inspection is connected to the term closure record. Save a draft at any time.'
                : 'Draft saved. Continue the inspection and submit it when every applicable item is rated.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (_saving) ...[
          const SizedBox(width: 12),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    ),
  );

  Widget _summaryStrip() => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      _SummaryMetric(
        label: 'Condition score',
        value: '$_score%',
        icon: Icons.speed_outlined,
        color: _score >= 80 ? AppColors.green : AppColors.amber,
      ),
      _SummaryMetric(
        label: 'Inspected',
        value: '$_completed / $_totalItems',
        icon: Icons.fact_check_outlined,
        color: AppColors.blue,
      ),
      _SummaryMetric(
        label: 'Management flags',
        value: '$_flags',
        icon: Icons.flag_outlined,
        color: AppColors.red,
      ),
      _SummaryMetric(
        label: 'Still to inspect',
        value: '$_toInspect',
        icon: Icons.pending_actions_outlined,
        color: AppColors.muted,
      ),
    ],
  );

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _tabButton(
          _InspectionTab.checklist,
          Icons.checklist_rounded,
          'Checklist',
        ),
        _tabButton(
          _InspectionTab.flags,
          Icons.flag_outlined,
          'Management flags',
          badge: _flags,
        ),
        _tabButton(
          _InspectionTab.report,
          Icons.summarize_outlined,
          'Report & sign-off',
        ),
      ],
    ),
  );

  Widget _tabButton(
    _InspectionTab tab,
    IconData icon,
    String label, {
    int? badge,
  }) {
    final selected = _tab == tab;
    return TextButton.icon(
      onPressed: () => setState(() => _tab = tab),
      icon: Icon(icon, size: 19),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (badge != null) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white : AppColors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$badge',
                style: TextStyle(
                  color: selected ? AppColors.red : Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
      style: TextButton.styleFrom(
        foregroundColor: selected ? Colors.white : AppColors.muted,
        backgroundColor: selected ? AppColors.navy : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  Widget _checklist() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _inspectionDetails(),
      const SizedBox(height: 18),
      ..._sections.map(
        (section) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _section(section),
        ),
      ),
      _bottomActions(),
    ],
  );

  Widget _inspectionDetails() => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: const Text(
        'Inspection details and applicable facilities',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'School and term information is filled automatically.',
        style: TextStyle(color: AppColors.muted),
      ),
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FacilityChip(label: 'ICT lab', selected: true),
            _FacilityChip(label: 'Science lab', selected: true),
            _FacilityChip(label: 'Library', selected: true),
            _FacilityChip(label: 'Kitchen / school feeding', selected: true),
            _FacilityChip(label: 'Boarding', selected: false),
          ],
        ),
        const SizedBox(height: 14),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sections for facilities the school does not have are marked N/A automatically.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _section(_InspectionSection section) {
    final done = section.items
        .where((item) => _ratings.containsKey(item.id))
        .length;
    final sectionFlags = section.items
        .where((item) => _flagDetails.containsKey(item.id))
        .length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: section.id == 'classrooms',
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(section.icon, color: AppColors.green, size: 21),
        ),
        title: Text(
          section.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              Text(
                '$done of ${section.items.length} inspected',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (sectionFlags > 0) ...[
                const SizedBox(width: 10),
                Text(
                  '$sectionFlags flagged',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        children: [
          const Divider(height: 1),
          ...section.items.map((item) => _inspectionItem(item)),
        ],
      ),
    );
  }

  Widget _inspectionItem(_InspectionItem item) {
    final condition = _ratings[item.id];
    final flagged = _flagDetails.containsKey(item.id);
    final evidenceCount = _evidencePhotos[item.id]?.length ?? 0;
    final detailOpen = _openDetails.contains(item.id);
    return Container(
      decoration: BoxDecoration(
        color: flagged ? const Color(0xFFFFFAF1) : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final question = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (item.safety)
                          const _SmallTag(
                            label: 'Safety',
                            color: AppColors.red,
                          ),
                        if (item.quantity)
                          const _SmallTag(
                            label: 'Asset count',
                            color: AppColors.blue,
                          ),
                        if (evidenceCount > 0)
                          _SmallTag(
                            label:
                                '$evidenceCount ${evidenceCount == 1 ? 'photo' : 'photos'}',
                            color: AppColors.purple,
                          ),
                      ],
                    ),
                  ),
                  if (condition != null)
                    IconButton(
                      tooltip: 'Add finding details',
                      onPressed: () => setState(() {
                        detailOpen
                            ? _openDetails.remove(item.id)
                            : _openDetails.add(item.id);
                      }),
                      icon: Icon(
                        detailOpen ? Icons.expand_less : Icons.notes_outlined,
                        color: flagged ? AppColors.red : AppColors.muted,
                      ),
                    ),
                ],
              );
              final choices = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _Condition.values
                    .map(
                      (value) => _conditionChoice(
                        item: item,
                        value: value,
                        selected: condition == value,
                      ),
                    )
                    .toList(),
              );
              if (constraints.maxWidth < 820) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [question, const SizedBox(height: 10), choices],
                );
              }
              return Row(
                children: [
                  Expanded(child: question),
                  const SizedBox(width: 18),
                  choices,
                ],
              );
            },
          ),
          if (detailOpen) ...[const SizedBox(height: 12), _findingDetail(item)],
        ],
      ),
    );
  }

  Widget _conditionChoice({
    required _InspectionItem item,
    required _Condition value,
    required bool selected,
  }) {
    final (label, color) = switch (value) {
      _Condition.good => ('Good', AppColors.green),
      _Condition.fair => ('Fair', AppColors.amber),
      _Condition.poor => ('Poor', AppColors.red),
      _Condition.notApplicable => ('N/A', AppColors.muted),
    };
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _ratings[item.id] = value;
        if (value == _Condition.poor) {
          _flagDetails.putIfAbsent(
            item.id,
            () => _FlagDetail(
              severity: item.safety ? 'Urgent' : 'High',
              finding: '',
              assignedTo: '',
              due: '',
              status: 'Open',
            ),
          );
          _openDetails.add(item.id);
        } else if (value == _Condition.notApplicable) {
          _openDetails.add(item.id);
          _flagDetails.remove(item.id);
        } else {
          _flagDetails.remove(item.id);
        }
        _submitted = false;
      }),
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? color : AppColors.border),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _findingDetail(_InspectionItem item) {
    final flag = _flagDetails[item.id];
    final photos = _evidencePhotos[item.id] ?? const <_EvidencePhoto>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (flag != null) ...[
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: AppColors.red, size: 19),
                const SizedBox(width: 7),
                Text(
                  'Sent to management · ${flag.severity}',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            initialValue: flag?.finding ?? '',
            onChanged: (value) => _updateFlag(
              item,
              (current) => current.copyWith(finding: value),
            ),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: _ratings[item.id] == _Condition.notApplicable
                  ? 'Reason this does not apply'
                  : 'Finding or comment',
              hintText: 'Describe the location, extent and action needed.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (item.quantity)
                const SizedBox(
                  width: 240,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(labelText: 'Found'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(labelText: 'Expected'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (flag != null) ...[
                SizedBox(
                  width: 190,
                  child: TextFormField(
                    initialValue: flag.assignedTo,
                    onChanged: (value) => _updateFlag(
                      item,
                      (current) => current.copyWith(assignedTo: value),
                    ),
                    decoration: const InputDecoration(labelText: 'Assigned to'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    initialValue: flag.due,
                    onChanged: (value) => _updateFlag(
                      item,
                      (current) => current.copyWith(due: value),
                    ),
                    decoration: const InputDecoration(labelText: 'Fix by'),
                  ),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () => _pickEvidencePhotos(item),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add evidence photo'),
              ),
            ],
          ),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: photos
                  .map((photo) => _evidencePhotoCard(item, photo))
                  .toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photo previews are attached to this form only. Permanent storage will be connected with the backend.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _managementFlags() {
    final flags = _flagDetails.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          'Management flags',
          'Poor conditions, safety risks and significant asset shortages are collected here automatically.',
          trailing: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list_rounded),
            label: const Text('Open flags'),
          ),
        ),
        const SizedBox(height: 14),
        ...flags.map((entry) {
          final item = _itemById(entry.key);
          final flag = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Severity(label: flag.severity),
                        _SmallTag(
                          label: _sectionForItem(entry.key).name,
                          color: AppColors.muted,
                        ),
                        _SmallTag(label: flag.status, color: AppColors.blue),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      flag.finding,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 22,
                      runSpacing: 8,
                      children: [
                        _Meta(
                          icon: Icons.person_outline,
                          label: flag.assignedTo,
                        ),
                        _Meta(
                          icon: Icons.event_outlined,
                          label: 'Fix by ${flag.due}',
                        ),
                        _Meta(
                          icon: Icons.photo_outlined,
                          label:
                              (_evidencePhotos[entry.key]?.isNotEmpty ?? false)
                              ? '${_evidencePhotos[entry.key]!.length} photo evidence'
                              : 'Evidence required',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _tab = _InspectionTab.checklist;
                            _openDetails.add(entry.key);
                          }),
                          child: const Text('Open checklist item'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.tonal(
                          onPressed: () => setState(() {
                            _tab = _InspectionTab.checklist;
                            _openDetails.add(entry.key);
                          }),
                          child: const Text('Update follow-up'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _report() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionHeading(
        'Inspection report',
        'A closure-ready summary for school leadership and the SMC/PTA.',
        trailing: OutlinedButton.icon(
          onPressed: () => _showMessage(
            'The final closure report includes this submitted inspection.',
          ),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Preview PDF'),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final score = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall condition',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_score%',
                    style: const TextStyle(
                      fontSize: 48,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
              final counts = Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _CountDot(
                    color: AppColors.green,
                    label: '${_count(_Condition.good)} good',
                  ),
                  _CountDot(
                    color: AppColors.amber,
                    label: '${_count(_Condition.fair)} fair',
                  ),
                  _CountDot(
                    color: AppColors.red,
                    label: '${_count(_Condition.poor)} poor',
                  ),
                  _CountDot(
                    color: AppColors.muted,
                    label: '${_count(_Condition.notApplicable)} N/A',
                  ),
                  _CountDot(
                    color: AppColors.blue,
                    label: '$_toInspect not rated',
                  ),
                ],
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [score, const SizedBox(height: 18), counts],
                );
              }
              return Row(
                children: [
                  score,
                  const SizedBox(width: 44),
                  Expanded(child: counts),
                ],
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          border: Border.all(color: const Color(0xFFF2B9B9)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety_outlined, color: AppColors.red),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2 urgent safety issues require acknowledgement',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'The score does not override safety. Each urgent issue must have an owner and due date before the report can be submitted.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Section condition',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ..._sections.map((section) => _reportSectionRow(section)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Photo evidence',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Photos attached to checklist findings appear here for review.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  _SmallTag(
                    label:
                        '$_evidencePhotoCount ${_evidencePhotoCount == 1 ? 'photo' : 'photos'}',
                    color: AppColors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_evidencePhotoCount == 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.photo_outlined, color: AppColors.muted),
                      SizedBox(width: 10),
                      Text(
                        'No photo evidence has been added.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in _evidencePhotos.entries)
                      for (final photo in entry.value)
                        _reportEvidencePhoto(entry.key, photo),
                  ],
                ),
              if (_evidencePhotoCount > 0) ...[
                const SizedBox(height: 10),
                const Text(
                  'Preview only: permanent photo storage will be connected with the backend.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign-off',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              const Text(
                'Names are recorded when the final inspection is submitted.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _headteacher,
                      decoration: const InputDecoration(
                        labelText: 'Headteacher',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _assistantHead,
                      decoration: const InputDecoration(
                        labelText: 'Assistant head',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _communityChair,
                      decoration: const InputDecoration(
                        labelText: 'SMC / PTA chair',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(submit: true),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Submit final inspection'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _reportSectionRow(_InspectionSection section) {
    final done = section.items
        .where((item) => _ratings.containsKey(item.id))
        .length;
    final progress = section.items.isEmpty ? 0.0 : done / section.items.length;
    final flags = section.items
        .where((item) => _flagDetails.containsKey(item.id))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 190,
            child: Text(
              section.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: AppColors.border,
              color: flags > 0 ? AppColors.amber : AppColors.green,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 88,
            child: Text(
              '$done/${section.items.length}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              flags == 0 ? 'No flags' : '$flags flagged',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: flags == 0 ? AppColors.green : AppColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle, {Widget? trailing}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 16), trailing],
        ],
      );

  Widget _bottomActions() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _save(submit: false),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save draft'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: () => setState(() => _tab = _InspectionTab.report),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Review report'),
        ),
      ],
    ),
  );

  int _count(_Condition condition) =>
      _ratings.values.where((value) => value == condition).length;

  int get _evidencePhotoCount =>
      _evidencePhotos.values.fold(0, (total, photos) => total + photos.length);

  Future<void> _pickEvidencePhotos(_InspectionItem item) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final existing = _evidencePhotos[item.id] ?? <_EvidencePhoto>[];
      final available = 5 - existing.length;
      if (available <= 0) {
        _showMessage(
          'You can attach up to 5 photos to each checklist item.',
          error: true,
        );
        return;
      }
      final selected = <_EvidencePhoto>[];
      var rejectedForSize = 0;
      for (final file in result.files.take(available)) {
        if (file.size > 10 * 1024 * 1024) {
          rejectedForSize++;
          continue;
        }
        if (file.bytes == null) continue;
        selected.add(
          _EvidencePhoto(name: file.name, size: file.size, bytes: file.bytes!),
        );
      }
      if (selected.isNotEmpty) {
        setState(() {
          _evidencePhotos[item.id] = [...existing, ...selected];
          _submitted = false;
        });
      }
      if (rejectedForSize > 0) {
        _showMessage(
          '$rejectedForSize ${rejectedForSize == 1 ? 'photo was' : 'photos were'} larger than 10 MB and ${rejectedForSize == 1 ? 'was' : 'were'} not added.',
          error: true,
        );
      } else if (selected.isNotEmpty) {
        _showMessage(
          '${selected.length} photo${selected.length == 1 ? '' : 's'} added to this checklist item.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not select photos: $error', error: true);
    }
  }

  Widget _evidencePhotoCard(_InspectionItem item, _EvidencePhoto photo) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F9),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              photo.bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _fileSize(photo.size),
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove photo',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              _evidencePhotos[item.id]?.remove(photo);
              if (_evidencePhotos[item.id]?.isEmpty ?? false) {
                _evidencePhotos.remove(item.id);
              }
              _submitted = false;
            }),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _reportEvidencePhoto(String itemId, _EvidencePhoto photo) {
    final item = _itemById(itemId);
    return Container(
      width: 230,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(
              photo.bytes,
              width: double.infinity,
              height: 112,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            '${photo.name} · ${_fileSize(photo.size)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadChecklistTemplate() async {
    try {
      final bytes = await buildFacilityChecklistTemplatePdf(
        schoolLabel: widget.schoolId,
        termName: widget.termName,
        sections: _sections
            .map(
              (section) => FacilityChecklistTemplateSection(
                name: section.name,
                items: section.items.map((item) => item.label).toList(),
              ),
            )
            .toList(),
      );
      final downloaded = await downloadReportPdf(
        facilityChecklistTemplateFileName(widget.termName),
        bytes,
      );
      if (!mounted) return;
      _showMessage(
        downloaded
            ? 'Facility checklist template downloaded.'
            : 'PDF downloads are not available on this device.',
        error: !downloaded,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        'Could not create the checklist template: $error',
        error: true,
      );
    }
  }

  String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  _InspectionSection _sectionForItem(String id) => _sections.firstWhere(
    (section) => section.items.any((item) => item.id == id),
  );

  _InspectionItem _itemById(String id) =>
      _sectionForItem(id).items.firstWhere((item) => item.id == id);

  void _updateFlag(
    _InspectionItem item,
    _FlagDetail Function(_FlagDetail current) update,
  ) {
    if (_ratings[item.id] != _Condition.poor) return;
    final current =
        _flagDetails[item.id] ??
        _FlagDetail(
          severity: item.safety ? 'Urgent' : 'High',
          finding: '',
          assignedTo: '',
          due: '',
          status: 'Open',
        );
    _flagDetails[item.id] = update(current);
    _submitted = false;
  }

  Future<void> _save({required bool submit}) async {
    if (submit) {
      if (_toInspect > 0) {
        _showMessage(
          'Inspect all $_totalItems items before submitting. $_toInspect remain.',
          error: true,
        );
        setState(() => _tab = _InspectionTab.checklist);
        return;
      }
      final incompleteFlags = _flagDetails.values.where(
        (flag) =>
            flag.finding.trim().isEmpty ||
            flag.assignedTo.trim().isEmpty ||
            flag.due.trim().isEmpty,
      );
      if (incompleteFlags.isNotEmpty) {
        _showMessage(
          'Every poor condition needs a finding, owner and fix-by date.',
          error: true,
        );
        setState(() => _tab = _InspectionTab.flags);
        return;
      }
      if (_headteacher.text.trim().isEmpty) {
        _showMessage('Add the headteacher sign-off.', error: true);
        setState(() => _tab = _InspectionTab.report);
        return;
      }
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final facilities = <String, dynamic>{
      ..._existingFacilities,
      'inspectionCompleted': submit,
      'status': submit ? 'SUBMITTED' : 'DRAFT',
      'savedAt': now.toIso8601String(),
      if (submit) 'submittedAt': now.toIso8601String(),
      'score': _score,
      'itemsInspected': _completed,
      'itemsTotal': _totalItems,
      'ratings': {
        for (final entry in _ratings.entries)
          entry.key: _conditionToApi(entry.value),
      },
      'findings': {
        for (final entry in _flagDetails.entries)
          entry.key: entry.value.toMap(),
      },
      'applicableFacilities': {
        'ictLab': true,
        'scienceLab': true,
        'library': true,
        'kitchen': true,
        'boarding': false,
      },
      'signoff': {
        'headteacher': _headteacher.text.trim(),
        'assistantHead': _assistantHead.text.trim(),
        'communityChair': _communityChair.text.trim(),
      },
    };
    try {
      await widget.repository.saveDraft(
        widget.schoolId,
        HeadmasterTermClosureInput(
          actorUserId: widget.actorUserId,
          acknowledgements: _acknowledgements,
          facilities: facilities,
        ),
      );
      if (!mounted) return;
      setState(() {
        _existingFacilities = facilities;
        _submitted = submit;
        _savedAt = now;
        _saving = false;
      });
      widget.onChanged?.call();
      _showMessage(
        submit
            ? 'Facility inspection submitted and added to term closure.'
            : 'Facility inspection draft saved.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Could not save the inspection: $error', error: true);
    }
  }

  _Condition? _conditionFromApi(String value) => switch (value) {
    'GOOD' => _Condition.good,
    'FAIR' => _Condition.fair,
    'POOR' => _Condition.poor,
    'NOT_APPLICABLE' => _Condition.notApplicable,
    _ => null,
  };

  String _conditionToApi(_Condition value) => switch (value) {
    _Condition.good => 'GOOD',
    _Condition.fair => 'FAIR',
    _Condition.poor => 'POOR',
    _Condition.notApplicable => 'NOT_APPLICABLE',
  };

  DateTime? _parseDate(dynamic value) {
    if (value is List && value.length >= 3) {
      final year = int.tryParse('${value[0]}');
      final month = int.tryParse('${value[1]}');
      final day = int.tryParse('${value[2]}');
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse('${value ?? ''}');
  }

  String _formatDate(DateTime value) {
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
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.red : null,
        content: Text(message),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 215,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
    ],
  );
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => FilterChip(
    selected: selected,
    onSelected: (_) {},
    showCheckmark: true,
    label: Text(label),
    selectedColor: AppColors.greenSoft,
    checkmarkColor: AppColors.green,
    side: const BorderSide(color: AppColors.border),
  );
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      border: Border.all(color: color.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
    ),
  );
}

class _Severity extends StatelessWidget {
  const _Severity({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Urgent' => const Color(0xFF9B1834),
      'High' => AppColors.red,
      'Medium' => AppColors.amber,
      _ => AppColors.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

class _InspectionSection {
  const _InspectionSection({
    required this.id,
    required this.name,
    required this.icon,
    required this.items,
  });

  final String id;
  final String name;
  final IconData icon;
  final List<_InspectionItem> items;
}

class _InspectionItem {
  const _InspectionItem(
    this.id,
    this.label, {
    this.safety = false,
    this.quantity = false,
  });

  final String id;
  final String label;
  final bool safety;
  final bool quantity;
}

class _FlagDetail {
  const _FlagDetail({
    required this.severity,
    required this.finding,
    required this.assignedTo,
    required this.due,
    required this.status,
  });

  final String severity;
  final String finding;
  final String assignedTo;
  final String due;
  final String status;

  factory _FlagDetail.fromMap(Map<String, dynamic> map) => _FlagDetail(
    severity: '${map['severity'] ?? 'High'}',
    finding: '${map['finding'] ?? ''}',
    assignedTo: '${map['assignedTo'] ?? ''}',
    due: '${map['due'] ?? ''}',
    status: '${map['status'] ?? 'Open'}',
  );

  _FlagDetail copyWith({
    String? severity,
    String? finding,
    String? assignedTo,
    String? due,
    String? status,
  }) => _FlagDetail(
    severity: severity ?? this.severity,
    finding: finding ?? this.finding,
    assignedTo: assignedTo ?? this.assignedTo,
    due: due ?? this.due,
    status: status ?? this.status,
  );

  Map<String, dynamic> toMap() => {
    'severity': severity,
    'finding': finding,
    'assignedTo': assignedTo,
    'due': due,
    'status': status,
  };
}

class _EvidencePhoto {
  const _EvidencePhoto({
    required this.name,
    required this.size,
    required this.bytes,
  });

  final String name;
  final int size;
  final Uint8List bytes;
}

const _sections = <_InspectionSection>[
  _InspectionSection(
    id: 'classrooms',
    name: 'Classrooms',
    icon: Icons.meeting_room_outlined,
    items: [
      _InspectionItem(
        'classrooms.roof',
        'Roof has no leaks, missing sheets or loose nails',
        safety: true,
      ),
      _InspectionItem(
        'classrooms.ceiling',
        'Ceiling has no sagging or water stains',
      ),
      _InspectionItem(
        'classrooms.walls',
        'Walls and floors have no cracks, holes or termite damage',
      ),
      _InspectionItem(
        'classrooms.doors',
        'Doors, windows, hinges and locks work correctly',
      ),
      _InspectionItem(
        'classrooms.boards',
        'Chalkboards and whiteboards are usable',
      ),
      _InspectionItem(
        'classrooms.desks',
        'Dual desks and chairs agree with inventory',
        quantity: true,
      ),
      _InspectionItem(
        'classrooms.electrical',
        'Fans, bulbs and sockets work with no exposed wiring',
        safety: true,
      ),
      _InspectionItem(
        'classrooms.clean',
        'Rooms are swept and cleared for vacation',
      ),
    ],
  ),
  _InspectionSection(
    id: 'sanitation',
    name: 'Sanitation and water',
    icon: Icons.water_drop_outlined,
    items: [
      _InspectionItem(
        'sanitation.toilets',
        'Toilets are clean, secure and not full',
        safety: true,
      ),
      _InspectionItem(
        'sanitation.girls',
        'Girls’ facility is separate, lockable and has a disposal bin',
      ),
      _InspectionItem(
        'sanitation.handwashing',
        'Handwashing stations and taps work',
      ),
      _InspectionItem(
        'sanitation.water',
        'Water source works and tanks are covered',
      ),
      _InspectionItem(
        'sanitation.refuse',
        'Refuse bins and dump area are cleared',
      ),
      _InspectionItem(
        'sanitation.drains',
        'Drains and gutters are clear with no stagnant water',
      ),
    ],
  ),
  _InspectionSection(
    id: 'safety',
    name: 'Electricity and safety',
    icon: Icons.health_and_safety_outlined,
    items: [
      _InspectionItem(
        'safety.meter',
        'Prepaid meter has units and the meter box is secured',
      ),
      _InspectionItem(
        'safety.switches',
        'Main switches are off in unused blocks',
      ),
      _InspectionItem(
        'safety.extinguishers',
        'Fire extinguishers are present, charged and in date',
        safety: true,
      ),
      _InspectionItem(
        'safety.firstaid',
        'First-aid box is stocked and the sick bay is clean',
      ),
      _InspectionItem(
        'safety.exits',
        'Emergency exits and corridors are clear',
        safety: true,
      ),
      _InspectionItem(
        'safety.trees',
        'No dangerous trees, branches or structures threaten classrooms',
        safety: true,
      ),
    ],
  ),
  _InspectionSection(
    id: 'ict',
    name: 'ICT lab',
    icon: Icons.computer_outlined,
    items: [
      _InspectionItem(
        'ict.computers',
        'Computers agree with the asset register',
        quantity: true,
      ),
      _InspectionItem(
        'ict.accessories',
        'Projector, router and accessories are secured',
      ),
      _InspectionItem(
        'ict.covered',
        'Machines are unplugged and covered against dust',
      ),
    ],
  ),
  _InspectionSection(
    id: 'science',
    name: 'Science lab',
    icon: Icons.science_outlined,
    items: [
      _InspectionItem(
        'science.chemicals',
        'Chemicals are labelled and locked away',
        safety: true,
      ),
      _InspectionItem(
        'science.apparatus',
        'Apparatus agrees with the lab inventory',
        quantity: true,
      ),
      _InspectionItem(
        'science.gas',
        'Gas supply is turned off at source',
        safety: true,
      ),
    ],
  ),
  _InspectionSection(
    id: 'library',
    name: 'Library',
    icon: Icons.local_library_outlined,
    items: [
      _InspectionItem(
        'library.books',
        'Books are returned and agree with the register',
        quantity: true,
      ),
      _InspectionItem('library.shelves', 'Shelves are stable and intact'),
      _InspectionItem(
        'library.dry',
        'The room is dry with no leaks onto books',
      ),
    ],
  ),
  _InspectionSection(
    id: 'offices',
    name: 'Offices and stores',
    icon: Icons.inventory_2_outlined,
    items: [
      _InspectionItem(
        'offices.files',
        'Staff-room and office files are secured',
      ),
      _InspectionItem(
        'offices.stock',
        'Store stock agrees with the ledger',
        quantity: true,
      ),
      _InspectionItem(
        'offices.keys',
        'Store is locked and keys are accounted for',
      ),
    ],
  ),
  _InspectionSection(
    id: 'kitchen',
    name: 'Kitchen and feeding',
    icon: Icons.soup_kitchen_outlined,
    items: [
      _InspectionItem(
        'kitchen.clean',
        'Kitchen is cleaned and utensils are stored',
      ),
      _InspectionItem(
        'kitchen.utensils',
        'Cooking utensils are counted',
        quantity: true,
      ),
      _InspectionItem(
        'kitchen.food',
        'Food stock is recorded with nothing left to spoil',
      ),
      _InspectionItem(
        'kitchen.gas',
        'Gas cylinders are disconnected and stored safely',
        safety: true,
      ),
      _InspectionItem(
        'kitchen.dining',
        'Dining tables and benches are in good repair',
      ),
    ],
  ),
  _InspectionSection(
    id: 'dormitories',
    name: 'Dormitories',
    icon: Icons.bed_outlined,
    items: [
      _InspectionItem(
        'dormitories.beds',
        'Beds and mattresses are counted',
        quantity: true,
      ),
      _InspectionItem(
        'dormitories.nets',
        'Mosquito nets and window nets are intact',
      ),
      _InspectionItem(
        'dormitories.washrooms',
        'Washrooms and bathhouses are cleaned',
      ),
      _InspectionItem(
        'dormitories.reports',
        'Housemaster or housemistress reports are submitted',
      ),
    ],
  ),
  _InspectionSection(
    id: 'compound',
    name: 'Compound and security',
    icon: Icons.fence_outlined,
    items: [
      _InspectionItem(
        'compound.fence',
        'Fence or wall is intact with no gaps',
        safety: true,
      ),
      _InspectionItem('compound.gate', 'Gate locks are working'),
      _InspectionItem(
        'compound.field',
        'Field is weeded and goalposts are sound',
      ),
      _InspectionItem(
        'compound.sports',
        'Sports equipment is counted',
        quantity: true,
      ),
      _InspectionItem(
        'compound.farm',
        'Vacation arrangements are made for the school farm',
      ),
      _InspectionItem(
        'compound.watch',
        'Watchman roster and contacts cover the whole vacation',
      ),
      _InspectionItem(
        'compound.keys',
        'Master key register is updated and all keys returned',
      ),
    ],
  ),
  _InspectionSection(
    id: 'records',
    name: 'Records and follow-up',
    icon: Icons.assignment_outlined,
    items: [
      _InspectionItem('records.tlm', 'Textbook and TLM inventory is updated'),
      _InspectionItem('records.repairs', 'Repairs are prioritised by urgency'),
      _InspectionItem(
        'records.costs',
        'Repairs are costed and linked to a funding source',
      ),
      _InspectionItem(
        'records.shared',
        'Report is shared with SMC/PTA and the Circuit Supervisor',
      ),
      _InspectionItem(
        'records.reinspection',
        'Pre-reopening re-inspection date is set',
      ),
    ],
  ),
];
