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
  });

  final AssessmentApiClient api;
  final String schoolId;
  final String viewerName;
  final String viewerRole;
  final AssessmentFormSetup setup;

  @override
  State<TermEvaluationWorkflowScreen> createState() =>
      _TermEvaluationWorkflowScreenState();
}

class _TermEvaluationWorkflowScreenState
    extends State<TermEvaluationWorkflowScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  bool get _manager {
    final role = widget.viewerRole.toLowerCase();
    return role.contains('admin') || role.contains('head');
  }

  @override
  void initState() {
    super.initState();
    _load();
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
    final rows = (_data?['assignments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final readyForReview = rows
        .where(
          (value) =>
              value['assignmentType'] == 'CLASS_TEACHER' &&
              value['status'] == 'SUBMITTED',
        )
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Term-end student evaluations')),
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
                          const Text(
                            'Evaluation exercise',
                            style: TextStyle(
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
                      'Assignments',
                      '${_data?['totalAssignments'] ?? 0}',
                    ),
                    _metric('Submitted', '${_data?['submitted'] ?? 0}'),
                    _metric('Incomplete', '${_data?['incomplete'] ?? 0}'),
                    _metric('Ready for review', '$readyForReview'),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Teacher assignments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
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
                '${assignment['studentCount']} students · ${assignment['assignmentType'].toString().replaceAll('_', ' ')}',
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
    required this.students,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String staffId;
  final List<Map<String, dynamic>> students;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class-teacher evaluation review')),
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
    required this.student,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String staffId;
  final Map<String, dynamic> student;

  @override
  State<_StudentFinalReview> createState() => _StudentFinalReviewState();
}

class _StudentFinalReviewState extends State<_StudentFinalReview> {
  final _comment = TextEditingController();
  final _final = <String, String>{};
  Map<String, String> _calculated = const {};
  bool _loading = true;
  bool _busy = false;
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
        _comment.text = data['comment']?.toString() ?? '';
        _status = data['status']?.toString() ?? 'PENDING';
        _loading = false;
      });
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _finalize() async {
    setState(() => _busy = true);
    try {
      await widget.api.finalizeTermEvaluationReview(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
        staffId: widget.staffId,
        finalRatings: _final,
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final complete = _calculated.keys.toSet().containsAll(_criteria.keys);
    final changed = _criteria.keys
        .where((criterion) => _final[criterion] != _calculated[criterion])
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
                          ? 'Review the calculated wording and set the final report-card wording.'
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
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _final[criterion.key],
                    decoration: const InputDecoration(
                      labelText: 'Final wording',
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
                        ? (value) =>
                              setState(() => _final[criterion.key] = value!)
                        : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Final class-teacher comment',
              hintText: 'Comment that will accompany the finalized evaluation',
            ),
          ),
          const SizedBox(height: 12),
          if (changed > 0)
            Text(
              '$changed calculated ${changed == 1 ? 'wording has' : 'wordings have'} been adjusted. The changes will be recorded automatically.',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const ValueKey('finalize-student-evaluation'),
              onPressed: complete && !_busy ? _finalize : null,
              icon: const Icon(Icons.verified_outlined),
              label: Text(
                _status == 'FINALIZED'
                    ? 'Save final changes'
                    : 'Finalize evaluation',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
