import 'dart:async';

import 'package:flutter/material.dart';

import '../data/assessment_api_client.dart';

const _criteria = <String, String>{
  'HOMEWORK_HABITS': 'Homework habits',
  'ATTENTIVENESS': 'Attentiveness',
  'TEAMWORK': 'Teamwork',
  'CLASS_PARTICIPATION': 'Class participation',
  'RESPECT_AND_DISCIPLINE': 'Respect and discipline',
  'NEATNESS': 'Neatness',
};

const _questions = <String, String>{
  'HOMEWORK_HABITS':
      'How consistently does each student complete assigned homework?',
  'ATTENTIVENESS':
      'How consistently does each student pay attention during lessons?',
  'TEAMWORK': 'How effectively does each student work with others?',
  'CLASS_PARTICIPATION':
      'How actively and appropriately does each student participate in class?',
  'RESPECT_AND_DISCIPLINE':
      'How consistently does each student demonstrate respect and discipline?',
  'NEATNESS':
      'How consistently does each student maintain personal and academic neatness?',
};

const _ratings = <String>[
  'Excellent',
  'Good',
  'Satisfactory',
  'Needs improvement',
  'Not observed',
];

class TermEvaluationWorkflowScreen extends StatefulWidget {
  const TermEvaluationWorkflowScreen({
    super.key,
    required this.api,
    required this.schoolId,
    required this.viewerName,
    required this.viewerRole,
    required this.setup,
    this.initialStreamId,
    this.initialStreamName,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final String viewerName;
  final String viewerRole;
  final AssessmentFormSetup setup;
  final int? initialStreamId;
  final String? initialStreamName;

  @override
  State<TermEvaluationWorkflowScreen> createState() =>
      _TermEvaluationWorkflowScreenState();
}

class _TermEvaluationWorkflowScreenState
    extends State<TermEvaluationWorkflowScreen> {
  final _readinessSearch = TextEditingController();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  String _managerView = 'Assignments';
  String _readinessFilter = 'All students';
  String _classFilter = 'All classes';

  bool get _manager {
    final role = widget.viewerRole.toLowerCase();
    return role.contains('admin') || role.contains('head');
  }

  bool get _headmaster =>
      widget.viewerRole.toLowerCase().contains('headmaster');

  String get _focusedStreamName {
    final value = widget.initialStreamName?.trim() ?? '';
    final parts = value
        .split(' - ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 3 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
      return [parts.first, ...parts.skip(2)].join(' - ');
    }
    return value.isEmpty ? 'Selected stream' : value;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _readinessSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _data = await widget.api.getTermEvaluationDashboard(
        schoolId: widget.schoolId,
        termId: widget.setup.termId,
      );
    } on AssessmentApiException catch (error) {
      _error = error.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _release() async {
    try {
      await widget.api.releaseTermEvaluations(
        schoolId: widget.schoolId,
        termId: widget.setup.termId,
        actor: widget.viewerName,
      );
      await _load();
      _message('Evaluation exercise released and assignments generated.');
    } on AssessmentApiException catch (error) {
      _message(error.message);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final dashboardRows = (_data?['assignments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final focusedStream = widget.initialStreamId != null;
    final rows =
        dashboardRows.where((assignment) {
          if (!focusedStream) return true;
          final value = assignment['streamId'];
          final streamId = value is num
              ? value.toInt()
              : int.tryParse(value?.toString() ?? '');
          return streamId == widget.initialStreamId;
        }).toList()..sort((left, right) {
          final leftSubmitted = left['status'] == 'SUBMITTED';
          final rightSubmitted = right['status'] == 'SUBMITTED';
          if (leftSubmitted == rightSubmitted) {
            return left['staffName'].toString().compareTo(
              right['staffName'].toString(),
            );
          }
          return leftSubmitted ? 1 : -1;
        });
    final submittedAssignments = rows
        .where((assignment) => assignment['status'] == 'SUBMITTED')
        .length;
    final incompleteAssignments = rows.length - submittedAssignments;
    final readiness = _readiness;
    final readyStudents = (readiness?['readyStudents'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          focusedStream
              ? 'Evaluation progress'
              : 'Term-end student evaluations',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            focusedStream
                                ? 'Evaluation progress — $_focusedStreamName'
                                : 'Evaluation exercise',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${widget.setup.termName} · ${widget.setup.academicYearName}',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    if (_manager)
                      FilledButton.icon(
                        onPressed: _release,
                        icon: const Icon(Icons.campaign_outlined),
                        label: Text(
                          rows.isEmpty
                              ? 'Release evaluations'
                              : 'Refresh assignments',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _metric(
                      focusedStream ? 'Assigned' : 'Assignments',
                      '${focusedStream ? rows.length : _data?['totalAssignments'] ?? 0}',
                    ),
                    _metric(
                      'Submitted',
                      '${focusedStream ? submittedAssignments : _data?['submitted'] ?? 0}',
                    ),
                    _metric(
                      'Pending',
                      '${focusedStream ? incompleteAssignments : _data?['incomplete'] ?? 0}',
                    ),
                    if (!focusedStream)
                      _metric('Ready for reports', '$readyStudents'),
                  ],
                ),
                const SizedBox(height: 22),
                if (_manager && !focusedStream) ...[
                  _managerTabs(),
                  const SizedBox(height: 16),
                ],
                if (_manager &&
                    !focusedStream &&
                    _managerView == 'Report readiness')
                  _readinessView()
                else
                  _assignmentsView(
                    rows,
                    streamName: focusedStream ? widget.initialStreamName : null,
                  ),
              ],
            ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
    width: 190,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blueGrey,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ),
  );

  Map<String, dynamic>? get _readiness {
    final raw = _data?['readiness'];
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  List<Map<String, dynamic>> get _readinessStudents =>
      (_readiness?['students'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) => value.map((key, item) => MapEntry(key.toString(), item)),
          )
          .toList();

  Widget _managerTabs() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(
        value: 'Assignments',
        icon: Icon(Icons.assignment_ind_outlined),
        label: Text('Teacher assignments'),
      ),
      ButtonSegment(
        value: 'Report readiness',
        icon: Icon(Icons.fact_check_outlined),
        label: Text('Report readiness'),
      ),
    ],
    selected: {_managerView},
    onSelectionChanged: (value) => setState(() => _managerView = value.first),
  );

  Widget _assignmentsView(
    List<Map<String, dynamic>> rows, {
    String? streamName,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        streamName == null
            ? 'Teacher assignments'
            : 'Teachers and assigned evaluations',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      if (streamName != null) ...[
        const SizedBox(height: 4),
        Text(
          'Pending assignments are listed first. Open the related report when all required teachers have submitted.',
          style: const TextStyle(color: Colors.blueGrey),
        ),
      ],
      const SizedBox(height: 10),
      if (rows.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              _data?['released'] == true
                  ? 'No assignments were generated. Add active subject-teacher and class-teacher allocations, then refresh assignments.'
                  : 'The headmaster must release the exercise before teachers can evaluate students.',
            ),
          ),
        )
      else
        ...rows.map(_assignmentCard),
    ],
  );

  Widget _readinessView() {
    final readiness = _readiness;
    if (readiness == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Report readiness is not available yet. Refresh the evaluation assignments and try again.',
          ),
        ),
      );
    }
    final students = _readinessStudents;
    final classNames =
        students
            .map((student) => student['streamName']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (_classFilter != 'All classes' && !classNames.contains(_classFilter)) {
      _classFilter = 'All classes';
    }
    final query = _readinessSearch.text.trim().toLowerCase();
    final filtered = students.where((student) {
      final ready = student['ready'] == true;
      final matchesStatus = switch (_readinessFilter) {
        'Ready' => ready,
        'Blocked' => !ready,
        _ => true,
      };
      final matchesClass =
          _classFilter == 'All classes' ||
          student['streamName']?.toString() == _classFilter;
      final searchable =
          '${student['studentName']} ${student['customStudentId']} ${student['streamName']}'
              .toLowerCase();
      return matchesStatus &&
          matchesClass &&
          (query.isEmpty || searchable.contains(query));
    }).toList();
    final readyForAll = readiness['readyForReportCards'] == true;
    final released = readiness['released'] == true;
    final blocked = (readiness['blockedStudents'] as num?)?.toInt() ?? 0;
    final incompleteAssignments =
        (readiness['incompleteAssignments'] as num?)?.toInt() ?? 0;

    return Column(
      key: const ValueKey('evaluation-report-readiness-view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: !released
                ? const Color(0xFFF1F5F9)
                : readyForAll
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: !released
                  ? const Color(0xFFCBD5E1)
                  : readyForAll
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFED7AA),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                !released
                    ? Icons.lock_clock_outlined
                    : readyForAll
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: !released
                    ? Colors.blueGrey
                    : readyForAll
                    ? const Color(0xFF047857)
                    : const Color(0xFFC27832),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !released
                          ? 'Evaluation exercise has not been released'
                          : readyForAll
                          ? 'All students are ready for report cards'
                          : '$blocked student${blocked == 1 ? '' : 's'} blocked from report generation',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !released
                          ? 'Release evaluations to create teacher assignments and begin readiness tracking.'
                          : incompleteAssignments > 0
                          ? '$incompleteAssignments teacher assignment${incompleteAssignments == 1 ? ' is' : 's are'} still incomplete. Open a student to see whether it is a report blocker.'
                          : readyForAll
                          ? 'Required observations, the class-teacher submission, and final reviews are complete.'
                          : 'Open a blocked student to see the exact missing teacher, criterion, or review action.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _readinessSearch,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Search students',
                ),
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String>(
                value: _classFilter,
                decoration: const InputDecoration(labelText: 'Class'),
                items: ['All classes', ...classNames]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _classFilter = value ?? 'All classes'),
              ),
            ),
            for (final value in const ['All students', 'Ready', 'Blocked'])
              ChoiceChip(
                label: Text(value),
                selected: _readinessFilter == value,
                onSelected: (_) => setState(() => _readinessFilter = value),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          '${filtered.length} student${filtered.length == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text('No students match the selected readiness filters.'),
            ),
          )
        else
          ...filtered.map(_studentReadinessCard),
      ],
    );
  }

  Widget _studentReadinessCard(Map<String, dynamic> student) {
    final ready = student['ready'] == true;
    final blockers = (student['blockers'] as List? ?? const []);
    return Card(
      child: ListTile(
        key: ValueKey('evaluation-readiness-${student['customStudentId']}'),
        onTap: () => _showReadinessDetail(student),
        leading: CircleAvatar(
          backgroundColor: ready
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFFFEDD5),
          child: Icon(
            ready ? Icons.check_rounded : Icons.priority_high_rounded,
            color: ready ? const Color(0xFF047857) : const Color(0xFFC2410C),
          ),
        ),
        title: Text(
          student['studentName']?.toString() ?? 'Student',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${student['streamName'] ?? 'Unassigned class'} · ${student['customStudentId']}\n'
          '${student['reviewStatus'] == 'FINALIZED' ? 'Final review complete' : 'Final review pending'} · '
          '${blockers.length} blocker${blockers.length == 1 ? '' : 's'}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(ready ? 'READY' : 'BLOCKED')),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<void> _showReadinessDetail(Map<String, dynamic> student) async {
    final blockers = (student['blockers'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => value.map((key, item) => MapEntry(key.toString(), item)),
        )
        .toList();
    final assignmentRows = (student['assignments'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => value.map((key, item) => MapEntry(key.toString(), item)),
        )
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        minChildSize: .55,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 30),
          children: [
            Text(
              student['studentName']?.toString() ?? 'Student',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              '${student['streamName'] ?? 'Unassigned class'} · ${student['customStudentId']}',
              style: const TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            Text(
              student['ready'] == true
                  ? 'Ready for report cards'
                  : 'What is blocking this report',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (blockers.isEmpty)
              const Card(
                color: Color(0xFFECFDF5),
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('All evaluation requirements are complete.'),
                ),
              )
            else
              ...blockers.map(
                (blocker) => Card(
                  color: const Color(0xFFFFF7ED),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: Text(
                      blocker['title']?.toString() ?? 'Evaluation pending',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(blocker['message']?.toString() ?? ''),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Teacher contributions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...assignmentRows.map((assignment) {
              final submitted = assignment['status'] == 'SUBMITTED';
              final progress =
                  (assignment['completionPercent'] as num?)?.round() ?? 0;
              final missing =
                  (assignment['missingCriteria'] as List? ?? const [])
                      .map((value) => value.toString())
                      .toList();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        child: Icon(
                          assignment['assignmentType'] == 'CLASS_TEACHER'
                              ? Icons.groups_2_outlined
                              : Icons.menu_book_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              assignment['staffName']?.toString() ??
                                  'Assigned teacher',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              assignment['subjectName']?.toString() ??
                                  'Class-teacher evaluation',
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 5,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              missing.isEmpty
                                  ? '$progress% complete'
                                  : '$progress% complete · Missing: ${missing.join(', ')}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (submitted)
                        const Chip(label: Text('SUBMITTED'))
                      else
                        OutlinedButton.icon(
                          onPressed: () =>
                              _remindById(assignment['assignmentId']),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Remind'),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _remindById(dynamic assignmentId) async {
    final id = assignmentId is num
        ? assignmentId.toInt()
        : int.tryParse(assignmentId?.toString() ?? '');
    final rows = (_data?['assignments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((assignment) => assignment['id'] == id)
        .toList();
    if (rows.isEmpty) {
      _message(
        'The teacher assignment could not be found. Refresh and try again.',
      );
      return;
    }
    await _remind(rows.single);
  }

  Widget _assignmentCard(Map<String, dynamic> assignment) {
    final own =
        assignment['staffName'].toString().trim().toLowerCase() ==
        widget.viewerName.trim().toLowerCase();
    final submitted = assignment['status'] == 'SUBMITTED';
    final progress = (assignment['completionPercent'] as num?)?.round() ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(
              assignment['assignmentType'] == 'CLASS_TEACHER'
                  ? Icons.groups_2_outlined
                  : Icons.menu_book_outlined,
            ),
          ),
          title: Text(
            '${assignment['staffName']} · ${assignment['subjectName']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${assignment['streamName'] ?? 'Unassigned class'} · '
                '${assignment['studentCount']} students · '
                '${assignment['assignmentType'].toString().replaceAll('_', ' ')}',
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: progress / 100, minHeight: 5),
              const SizedBox(height: 3),
              Text('$progress% rated', style: const TextStyle(fontSize: 11)),
            ],
          ),
          trailing: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Chip(
                label: Text(
                  assignment['status'].toString().replaceAll('_', ' '),
                ),
              ),
              if (own && !submitted)
                FilledButton(
                  onPressed: () => _openAssignment(assignment),
                  child: Text(progress == 0 ? 'Start' : 'Continue'),
                ),
              if (own &&
                  submitted &&
                  assignment['assignmentType'] == 'CLASS_TEACHER')
                FilledButton.tonal(
                  onPressed: () => _review(assignment),
                  child: const Text('Review class'),
                )
              else if (own && submitted)
                const Chip(label: Text('Submitted · locked')),
              if (_headmaster &&
                  !own &&
                  submitted &&
                  assignment['assignmentType'] == 'CLASS_TEACHER')
                FilledButton.tonalIcon(
                  key: ValueKey('manager-review-${assignment['id']}'),
                  onPressed: () => _review(assignment),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Review results'),
                ),
              if (_manager && submitted)
                TextButton(
                  onPressed: () => _reopen(assignment),
                  child: const Text('Reopen'),
                ),
              if (_manager && !submitted)
                TextButton.icon(
                  onPressed: () => _remind(assignment),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Remind'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAssignment(Map<String, dynamic> summary) async {
    try {
      final assignment = await widget.api.getTermEvaluationAssignment(
        assignmentId: summary['id'],
        schoolId: widget.schoolId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AssignmentEntry(
            api: widget.api,
            schoolId: widget.schoolId,
            assignment: assignment,
          ),
        ),
      );
      await _load();
    } on AssessmentApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _review(Map<String, dynamic> assignment) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConsolidatedReview(
          api: widget.api,
          schoolId: widget.schoolId,
          termId: widget.setup.termId,
          staffId: assignment['staffId'].toString(),
          canManageFinalWordings: _headmaster,
          students: (assignment['students'] as List)
              .whereType<Map<String, dynamic>>()
              .toList(),
        ),
      ),
    );
    await _load();
  }

  Future<void> _remind(Map<String, dynamic> assignment) async {
    await widget.api.remindTermEvaluationTeacher(
      assignmentId: assignment['id'],
      schoolId: widget.schoolId,
      termId: widget.setup.termId,
      actor: widget.viewerName,
      message: 'Please complete and submit your term-end student evaluations.',
    );
    _message('Reminder recorded for ${assignment['staffName']}.');
  }

  Future<void> _reopen(Map<String, dynamic> assignment) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reopen submitted evaluation'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Recorded reason *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await widget.api.reopenTermEvaluationAssignment(
      assignmentId: assignment['id'],
      schoolId: widget.schoolId,
      actor: widget.viewerName,
      reason: reason,
    );
    await _load();
  }
}

class _AssignmentEntry extends StatefulWidget {
  const _AssignmentEntry({
    required this.api,
    required this.schoolId,
    required this.assignment,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final Map<String, dynamic> assignment;

  @override
  State<_AssignmentEntry> createState() => _AssignmentEntryState();
}

class _AssignmentEntryState extends State<_AssignmentEntry> {
  final _values = <String, Map<String, String?>>{};
  final _search = TextEditingController();
  Timer? _saveTimer;
  int _step = 0;
  String _filter = 'All students';
  bool _busy = false;
  String _saveState = 'Draft not saved';

  List<Map<String, dynamic>> get _students =>
      (widget.assignment['students'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();

  bool get _complete =>
      _values.isNotEmpty &&
      _values.values.every(
        (student) =>
            _criteria.keys.every((criterion) => student[criterion] != null),
      );

  @override
  void initState() {
    super.initState();
    final saved = (widget.assignment['ratings'] as Map?) ?? const {};
    for (final student in _students) {
      final id = student['id'].toString();
      final ratings = saved[id] is Map ? saved[id] as Map : const {};
      _values[id] = {
        for (final criterion in _criteria.keys)
          criterion: ratings[criterion]?.toString(),
      };
    }
    if (saved.isNotEmpty) _saveState = 'Saved draft loaded';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String studentId, String criterion, String value) {
    setState(() {
      _values[studentId]![criterion] = value;
      _saveState = 'Saving draft…';
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () => _saveDraft());
  }

  List<Map<String, dynamic>> _payload() => _values.entries
      .map(
        (student) => {
          'customStudentId': student.key,
          'ratings': student.value.entries
              .where((rating) => rating.value != null)
              .map(
                (rating) => {'criterion': rating.key, 'rating': rating.value},
              )
              .toList(),
        },
      )
      .where((student) => (student['ratings'] as List).isNotEmpty)
      .toList();

  Future<bool> _saveDraft({bool announce = false}) async {
    if (_busy || _payload().isEmpty) return false;
    setState(() => _busy = true);
    try {
      await widget.api.saveTermEvaluationAssignment(
        assignmentId: widget.assignment['id'],
        schoolId: widget.schoolId,
        staffId: widget.assignment['staffId'],
        students: _payload(),
      );
      if (!mounted) return true;
      setState(() => _saveState = 'Draft saved just now');
      if (announce) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation draft saved.')),
        );
      }
      return true;
    } on AssessmentApiException catch (error) {
      if (mounted) {
        setState(() => _saveState = 'Draft could not be saved');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_complete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit and lock evaluations?'),
        content: const Text(
          'I have reviewed these evaluations and confirm that they reflect my observations of these students. Submitted ratings can only be changed after an authorized reopening.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit and lock'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _saveDraft()) return;
    try {
      await widget.api.submitTermEvaluationAssignment(
        assignmentId: widget.assignment['id'],
        schoolId: widget.schoolId,
        staffId: widget.assignment['staffId'],
      );
      if (mounted) Navigator.pop(context);
    } on AssessmentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = _step == _criteria.length;
    final criterion = review ? null : _criteria.entries.elementAt(_step);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assignment['subjectName'].toString()),
        actions: [
          Center(
            child: Text(
              _saveState,
              key: const ValueKey('evaluation-save-state'),
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _progressHeader(review, criterion),
          if (!review) _toolbar(criterion!.key),
          Expanded(
            child: review
                ? _reviewStep()
                : _criterionStudentList(criterion!.key),
          ),
          _navigation(review),
        ],
      ),
    );
  }

  Widget _progressHeader(
    bool review,
    MapEntry<String, String>? criterion,
  ) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
    color: const Color(0xFFF4FAF8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          review
              ? 'FINAL REVIEW · 7 OF 7'
              : '${criterion!.value.toUpperCase()} · ${_step + 1} OF ${_criteria.length}',
          style: const TextStyle(
            color: Color(0xFF087B69),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          review
              ? 'Review every student before submission'
              : _questions[criterion!.key]!,
          key: const ValueKey('active-evaluation-question'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: (_step + 1) / (_criteria.length + 1),
          minHeight: 6,
        ),
      ],
    ),
  );

  Widget _toolbar(String criterion) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search students',
            ),
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _filter,
          items: const ['All students', 'Unrated', 'Not observed']
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) => setState(() => _filter = value!),
        ),
        const SizedBox(width: 16),
        Text(
          '${_values.values.where((student) => student[criterion] != null).length}/${_students.length} rated',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _criterionStudentList(String criterion) {
    final query = _search.text.trim().toLowerCase();
    final visible = _students.where((student) {
      final id = student['id'].toString();
      final value = _values[id]![criterion];
      final matchesSearch =
          query.isEmpty ||
          student['name'].toString().toLowerCase().contains(query) ||
          id.toLowerCase().contains(query);
      final matchesFilter =
          _filter == 'All students' ||
          (_filter == 'Unrated' && value == null) ||
          (_filter == 'Not observed' && value == 'Not observed');
      return matchesSearch && matchesFilter;
    }).toList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = visible[index];
        final id = student['id'].toString();
        final selected = _values[id]![criterion];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(
                    student['name'].toString().isEmpty
                        ? '?'
                        : student['name'].toString()[0],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 210,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        id,
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: _ratings
                        .map(
                          (rating) => ChoiceChip(
                            label: Text(rating),
                            selected: selected == rating,
                            onSelected: (_) => _changed(id, criterion, rating),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reviewStep() => ListView.separated(
    padding: const EdgeInsets.all(24),
    itemCount: _students.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final student = _students[index];
      final id = student['id'].toString();
      final values = _values[id]!;
      final missing = values.entries
          .where((entry) => entry.value == null)
          .toList();
      return Card(
        child: ExpansionTile(
          leading: Icon(
            missing.isEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
            color: missing.isEmpty ? Colors.green : Colors.orange,
          ),
          title: Text(student['name'].toString()),
          subtitle: Text(
            missing.isEmpty
                ? 'All criteria completed'
                : '${missing.length} criteria missing',
          ),
          children: _criteria.entries
              .map(
                (criterion) => ListTile(
                  title: Text(criterion.value),
                  trailing: Text(values[criterion.key] ?? 'Unrated'),
                  onTap: () => setState(
                    () =>
                        _step = _criteria.keys.toList().indexOf(criterion.key),
                  ),
                ),
              )
              .toList(),
        ),
      );
    },
  );

  Widget _navigation(bool review) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8E6))),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _step == 0 ? null : () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _busy ? null : () => _saveDraft(announce: true),
            child: const Text('Save draft'),
          ),
          const Spacer(),
          if (review)
            FilledButton.icon(
              key: const ValueKey('submit-term-evaluations'),
              onPressed: _complete && !_busy ? _submit : null,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Submit and lock'),
            )
          else
            FilledButton.icon(
              onPressed: () => setState(() => _step++),
              icon: const Icon(Icons.arrow_forward),
              label: Text(
                _step + 1 == _criteria.length ? 'Review' : 'Next criterion',
              ),
            ),
        ],
      ),
    ),
  );
}

class _ConsolidatedReview extends StatelessWidget {
  const _ConsolidatedReview({
    required this.api,
    required this.schoolId,
    required this.termId,
    required this.staffId,
    required this.canManageFinalWordings,
    required this.students,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String staffId;
  final bool canManageFinalWordings;
  final List<Map<String, dynamic>> students;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        canManageFinalWordings
            ? 'Final evaluation review'
            : 'Class-teacher evaluation review',
      ),
    ),
    body: ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final student = students[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(student['name'].toString()),
            subtitle: Text(student['id'].toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _StudentFinalReview(
                  api: api,
                  schoolId: schoolId,
                  termId: termId,
                  staffId: staffId,
                  canManageFinalWordings: canManageFinalWordings,
                  student: student,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _StudentFinalReview extends StatefulWidget {
  const _StudentFinalReview({
    required this.api,
    required this.schoolId,
    required this.termId,
    required this.staffId,
    required this.canManageFinalWordings,
    required this.student,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String staffId;
  final bool canManageFinalWordings;
  final Map<String, dynamic> student;

  @override
  State<_StudentFinalReview> createState() => _StudentFinalReviewState();
}

class _StudentFinalReviewState extends State<_StudentFinalReview> {
  final _comment = TextEditingController();
  final _final = <String, String>{};
  final _originalFinal = <String, String>{};
  List<Map<String, dynamic>> _audit = const [];
  Map<String, String> _calculated = const {};
  bool _loading = true;
  bool _busy = false;
  bool _suggestionLoading = false;
  String? _suggestion;
  String? _appliedSuggestion;
  String? _suggestionMessage;
  int _suggestionVariant = 0;
  int _suggestionRequest = 0;
  String _status = 'PENDING';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.api.getTermEvaluationReview(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
      );
      final calculated = (data['calculated'] as Map? ?? const {}).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final finalRatings = (data['finalRatings'] as Map? ?? calculated).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      if (!mounted) return;
      setState(() {
        _calculated = calculated;
        _final
          ..clear()
          ..addAll(finalRatings);
        _originalFinal
          ..clear()
          ..addAll(finalRatings);
        _comment.text = data['comment']?.toString() ?? '';
        _status = data['status']?.toString() ?? 'PENDING';
        _audit = (data['audit'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (entry) =>
                  entry.map((key, value) => MapEntry(key.toString(), value)),
            )
            .where(
              (entry) =>
                  entry['action']?.toString() ==
                  'HEADMASTER_FINAL_WORDING_CHANGED',
            )
            .toList();
        _loading = false;
      });
      if (!widget.canManageFinalWordings) {
        await _loadSuggestion(resetVariant: true);
      }
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _loadSuggestion({bool resetVariant = false}) async {
    if (resetVariant) _suggestionVariant = 0;
    final request = ++_suggestionRequest;
    setState(() {
      _suggestionLoading = true;
      _suggestionMessage = null;
    });
    try {
      final data = await widget.api.suggestTermEvaluationComment(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
        finalRatings: Map<String, String>.from(_final),
        variant: _suggestionVariant,
      );
      if (!mounted || request != _suggestionRequest) return;
      setState(() {
        _suggestionLoading = false;
        if (data['available'] == true) {
          _suggestion = data['suggestion']?.toString();
          _suggestionMessage = null;
        } else {
          _suggestion = null;
          _suggestionMessage =
              data['message']?.toString() ??
              'A suggestion is not available for this student yet.';
        }
      });
    } on AssessmentApiException catch (error) {
      if (!mounted || request != _suggestionRequest) return;
      setState(() {
        _suggestionLoading = false;
        _suggestion = null;
        _suggestionMessage = error.message;
      });
    }
  }

  void _tryAnotherSuggestion() {
    if (_appliedSuggestion != null && _comment.text == _appliedSuggestion) {
      _comment.clear();
    }
    _appliedSuggestion = null;
    _suggestionVariant += 1;
    _loadSuggestion();
  }

  void _useSuggestion() {
    final suggestion = _suggestion;
    if (suggestion == null) return;
    setState(() {
      _comment.text = suggestion;
      _appliedSuggestion = suggestion;
    });
  }

  Future<void> _previewAndFinalize() async {
    final comment = _comment.text.trim();
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a comment or choose Use suggestion first.'),
        ),
      );
      return;
    }
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Preview report-card comment'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.student['name'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(
                    dialogContext,
                  ).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    comment,
                    key: const ValueKey('evaluation-comment-preview'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This exact wording will appear as the class-teacher comment on the report card.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Back to edit'),
          ),
          FilledButton.icon(
            key: const ValueKey('send-student-evaluation'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_outlined),
            label: Text(
              _status == 'FINALIZED' ? 'Send updated comment' : 'Send comment',
            ),
          ),
        ],
      ),
    );
    if (send == true && mounted) await _finalize();
  }

  Future<void> _finalize() async {
    setState(() => _busy = true);
    try {
      await widget.api.finalizeTermEvaluationReview(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
        staffId: widget.staffId,
        finalRatings: _calculated,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      setState(() => _status = 'FINALIZED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student evaluation finalized.')),
      );
    } on AssessmentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveManagerChanges() async {
    var enteredReason = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirm final wording changes'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These wordings will replace the calculated wording on the report card. The change and your reason will be recorded in the audit history.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('headmaster-wording-reason'),
                  autofocus: true,
                  maxLines: 3,
                  onChanged: (value) =>
                      setDialogState(() => enteredReason = value),
                  decoration: const InputDecoration(
                    labelText: 'Reason for change',
                    hintText: 'Explain why the calculated result must change',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep current wording'),
            ),
            FilledButton(
              key: const ValueKey('confirm-headmaster-wordings'),
              onPressed: enteredReason.trim().length >= 5
                  ? () => Navigator.pop(dialogContext, enteredReason.trim())
                  : null,
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.adjustFinalTermEvaluationWordings(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
        finalRatings: Map<String, String>.from(_final),
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Final wording updated and recorded in the audit history.',
          ),
        ),
      );
      await _load();
    } on AssessmentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _historyTitle(Map<String, dynamic> entry) {
    final details = entry['reason']?.toString() ?? '';
    final change = details.split('; reason:').first.trim();
    final separator = change.indexOf(':');
    if (separator < 0) return 'Final wording changed';
    final criterion = change.substring(0, separator).trim();
    final transition = change.substring(separator + 1).trim();
    return '${_criteria[criterion] ?? criterion.replaceAll('_', ' ')} · $transition';
  }

  String _historyReason(Map<String, dynamic> entry) {
    final details = entry['reason']?.toString() ?? '';
    const marker = '; reason:';
    final separator = details.indexOf(marker);
    return separator < 0
        ? details
        : details.substring(separator + marker.length).trim();
  }

  String _historyMeta(Map<String, dynamic> entry) {
    final actor = entry['actor']?.toString().trim() ?? '';
    final rawCreatedAt = entry['createdAt'];
    DateTime? parsed;
    if (rawCreatedAt is List && rawCreatedAt.length >= 5) {
      final parts = rawCreatedAt
          .take(6)
          .map((value) => int.tryParse(value.toString()))
          .toList();
      if (parts.take(5).every((value) => value != null)) {
        parsed = DateTime(
          parts[0]!,
          parts[1]!,
          parts[2]!,
          parts[3]!,
          parts[4]!,
          parts.length > 5 ? parts[5] ?? 0 : 0,
        );
      }
    } else {
      parsed = DateTime.tryParse(rawCreatedAt?.toString() ?? '')?.toLocal();
    }
    final date = parsed == null
        ? rawCreatedAt?.toString() ?? ''
        : '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} · ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    return [actor, date].where((value) => value.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final complete = _calculated.keys.toSet().containsAll(_criteria.keys);
    final finalized = _status == 'FINALIZED';
    final differsFromCalculated = _criteria.keys
        .where((criterion) => _final[criterion] != _calculated[criterion])
        .length;
    final edited = _criteria.keys
        .where((criterion) => _final[criterion] != _originalFinal[criterion])
        .length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.student['name'].toString())),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      complete
                          ? widget.canManageFinalWordings
                                ? finalized
                                      ? 'Review the combined teacher evaluation. Only the headmaster can correct the final report-card wording.'
                                      : 'The combined wording is ready, but the class teacher must add the final comment and finalize it first.'
                                : finalized
                                ? 'The combined teacher evaluation and your report-card comment are finalized.'
                                : 'Review the combined teacher evaluation and add the final class-teacher comment.'
                          : 'Teacher submissions are incomplete. This student cannot be finalized yet.',
                    ),
                  ),
                  Chip(label: Text(_status)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._criteria.entries.map(
            (criterion) => Card(
              child: ListTile(
                title: Text(
                  criterion.value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Calculated: ${_calculated[criterion.key] ?? 'Incomplete'}',
                ),
                trailing: SizedBox(
                  width: 280,
                  child: widget.canManageFinalWordings && finalized
                      ? DropdownButtonFormField<String>(
                          key: ValueKey('headmaster-wording-${criterion.key}'),
                          isExpanded: true,
                          value: _final[criterion.key],
                          decoration: const InputDecoration(
                            labelText: 'Final report wording',
                          ),
                          items: _ratings
                              .where((rating) => rating != 'Not observed')
                              .map(
                                (rating) => DropdownMenuItem(
                                  value: rating,
                                  child: Text(rating),
                                ),
                              )
                              .toList(),
                          onChanged: complete
                              ? (value) => setState(
                                  () => _final[criterion.key] = value!,
                                )
                              : null,
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _final[criterion.key] ?? 'Incomplete',
                            key: ValueKey('final-wording-${criterion.key}'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!widget.canManageFinalWordings)
            Card(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Suggested class-teacher comment',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_suggestionLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _suggestion ??
                          _suggestionMessage ??
                          'Preparing a suggestion from the consolidated evaluation…',
                      key: const ValueKey('evaluation-comment-suggestion'),
                    ),
                    if (_suggestion != null) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            key: const ValueKey('use-evaluation-suggestion'),
                            onPressed: finalized ? null : _useSuggestion,
                            icon: const Icon(Icons.check),
                            label: const Text('Use suggestion'),
                          ),
                          TextButton.icon(
                            key: const ValueKey(
                              'try-another-evaluation-suggestion',
                            ),
                            onPressed: finalized || _suggestionLoading
                                ? null
                                : _tryAnotherSuggestion,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try another'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        finalized
                            ? 'This suggestion is informational. The finalized comment is shown below and cannot be changed without reopening the evaluation.'
                            : 'Review and edit the wording before finalizing. The suggestion is never saved automatically.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (!widget.canManageFinalWordings) const SizedBox(height: 12),
          TextField(
            key: const ValueKey('evaluation-final-comment'),
            controller: _comment,
            readOnly: finalized || widget.canManageFinalWordings,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Final class-teacher comment',
              hintText: 'Comment that will accompany the finalized evaluation',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.canManageFinalWordings &&
              (edited > 0 || differsFromCalculated > 0))
            Text(
              edited > 0
                  ? '$edited ${edited == 1 ? 'wording edit is' : 'wording edits are'} waiting to be saved. A reason is required and every change will be audited.'
                  : '$differsFromCalculated final ${differsFromCalculated == 1 ? 'wording differs' : 'wordings differ'} from the calculated result because of an existing authorized correction.',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 18),
          if (widget.canManageFinalWordings && finalized)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('save-headmaster-wordings'),
                onPressed: edited > 0 && !_busy ? _saveManagerChanges : null,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Save wording changes'),
              ),
            )
          else if (finalized)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This evaluation is finalized. The combined wording cannot be changed by the class teacher; only the headmaster can correct it with a recorded reason.',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!widget.canManageFinalWordings)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const ValueKey('preview-student-evaluation'),
                onPressed: complete && !_busy && _comment.text.trim().isNotEmpty
                    ? _previewAndFinalize
                    : null,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Preview comment'),
              ),
            ),
          if (widget.canManageFinalWordings && _audit.isNotEmpty) ...[
            const SizedBox(height: 22),
            Card(
              key: const ValueKey('evaluation-wording-history'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history_outlined),
                        SizedBox(width: 8),
                        Text(
                          'Wording change history',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Every headmaster correction is retained with its reason.',
                    ),
                    const Divider(height: 26),
                    ..._audit.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          child: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        title: Text(
                          _historyTitle(entry),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${_historyReason(entry)}\n${_historyMeta(entry)}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
