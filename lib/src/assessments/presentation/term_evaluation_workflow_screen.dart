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

String _termEvaluationReviewStatusLabel(String status) {
  return switch (status.toUpperCase()) {
    'SUBMITTED' || 'FINALIZED' => 'Awaiting approval',
    'COMMENTS_IN_PROGRESS' => 'Comment saved',
    'UNDER_REVIEW' => 'Under review',
    'CHANGES_REQUESTED' => 'Rejected',
    'APPROVED' => 'Approved',
    'DRAFT' || 'IN_PROGRESS' => 'In progress',
    _ => 'Not started',
  };
}

String _assignmentWorkflowStatusLabel(Map<String, dynamic> assignment) {
  final status = assignment['workflowStatus']?.toString().toUpperCase();
  return switch (status) {
    'RATINGS_COMPLETE' => 'Ratings complete',
    'COMMENTS_IN_PROGRESS' => 'Comments in progress',
    'COMMENTS_COMPLETE' => 'Ready to submit',
    'READY_FOR_LEADERSHIP' => 'Awaiting approval',
    'UNDER_REVIEW' => 'Under review',
    'REJECTED' => 'Rejected',
    'APPROVED' => 'Approved',
    'RATINGS_IN_PROGRESS' =>
      ((assignment['completionPercent'] as num?)?.round() ?? 0) > 0
          ? 'Ratings in progress'
          : 'Not started',
    _ =>
      assignment['status']?.toString().toUpperCase() == 'SUBMITTED'
          ? 'Ratings complete'
          : assignment['status'].toString().replaceAll('_', ' '),
  };
}

class _EvaluationProgressGroup {
  const _EvaluationProgressGroup({
    required this.name,
    required this.assignmentCount,
    required this.assignedEvaluations,
    required this.completedEvaluations,
    required this.remainingEvaluations,
    required this.ratedCriteria,
    required this.requiredCriteria,
    required this.commentStudents,
    required this.commentsCompleted,
    required this.commentsSubmitted,
    required this.commentsUnderReview,
    required this.commentsApproved,
  });

  final String name;
  final int assignmentCount;
  final int assignedEvaluations;
  final int completedEvaluations;
  final int remainingEvaluations;
  final int ratedCriteria;
  final int requiredCriteria;
  final int commentStudents;
  final int commentsCompleted;
  final int commentsSubmitted;
  final int commentsUnderReview;
  final int commentsApproved;

  int get completedPercent => requiredCriteria == 0
      ? 0
      : (ratedCriteria * 100 / requiredCriteria).round().clamp(0, 100);

  int get remainingPercent => 100 - completedPercent;

  int get commentPercent => commentStudents == 0
      ? 0
      : (commentsCompleted * 100 / commentStudents).round().clamp(0, 100);

  int get commentsAwaitingApproval =>
      (commentsSubmitted - commentsUnderReview - commentsApproved).clamp(
        0,
        commentStudents,
      );

  String get approvalStatus {
    if (commentStudents == 0) return 'Not required';
    if (commentsApproved == commentStudents) return 'Approved';
    if (commentsUnderReview > 0) return 'Under review';
    if (commentsAwaitingApproval > 0) return 'Awaiting approval';
    if (commentsCompleted == commentStudents) return 'Ready to submit';
    if (commentsCompleted > 0) return 'Comments in progress';
    return 'Not started';
  }
}

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
    this.managementProgressOnly = false,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final String viewerName;
  final String viewerRole;
  final AssessmentFormSetup setup;
  final int? initialStreamId;
  final String? initialStreamName;
  final bool managementProgressOnly;

  @override
  State<TermEvaluationWorkflowScreen> createState() =>
      _TermEvaluationWorkflowScreenState();
}

class _TermEvaluationWorkflowScreenState
    extends State<TermEvaluationWorkflowScreen> {
  final _readinessSearch = TextEditingController();
  final _teacherProgressSearch = TextEditingController();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  bool _updatingWindow = false;
  bool _syncingEvaluations = false;
  String _managerView = 'Teacher progress';
  String _overviewView = 'By class';
  String _readinessFilter = 'All students';
  String _classFilter = 'All classes';
  String _readinessSortColumn = 'student';
  bool _readinessSortAscending = true;
  String _progressSortColumn = 'ratings';
  bool _progressSortAscending = false;
  String _teacherProgressSort = 'Teacher A–Z';
  bool _teacherProgressSortAscending = true;
  String _teacherClassFilter = 'All classes';
  List<Map<String, dynamic>> _pendingCorrections = const [];

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
    if (widget.managementProgressOnly) _managerView = 'Overview';
    _load();
  }

  @override
  void dispose() {
    _readinessSearch.dispose();
    _teacherProgressSearch.dispose();
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
      if (_manager) {
        _pendingCorrections = await widget.api.getReportCorrections(
          customSchoolId: widget.schoolId,
          status: 'PENDING',
        );
      }
    } on AssessmentApiException catch (error) {
      _error = error.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _release() async {
    if (_updatingWindow) return;
    setState(() => _updatingWindow = true);
    try {
      await widget.api.releaseTermEvaluations(
        schoolId: widget.schoolId,
        termId: widget.setup.termId,
        actor: widget.viewerName,
      );
      await _load();
      _message('Evaluations released. Teachers can now save and submit work.');
    } on AssessmentApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _updatingWindow = false);
    }
  }

  Future<void> _syncEvaluationRecords() async {
    if (_syncingEvaluations) return;
    setState(() => _syncingEvaluations = true);
    try {
      final result = await widget.api.syncTermEvaluations(
        schoolId: widget.schoolId,
        termId: widget.setup.termId,
      );
      final created = (result['assignmentsCreated'] as num?)?.toInt() ?? 0;
      final updated = (result['assignmentsUpdated'] as num?)?.toInt() ?? 0;
      await _load();
      final changes = <String>[
        if (created > 0)
          '$created evaluation ${created == 1 ? 'record was' : 'records were'} added',
        if (updated > 0)
          '$updated ${updated == 1 ? 'responsibility was' : 'responsibilities were'} updated',
      ];
      _message(
        changes.isEmpty
            ? 'Evaluation responsibilities are already up to date.'
            : 'Evaluations updated. ${changes.join(' and ')}.',
      );
    } on AssessmentApiException catch (error) {
      _message(error.message);
    } finally {
      if (mounted) setState(() => _syncingEvaluations = false);
    }
  }

  bool get _teacherEntryOpen {
    if (_data?['teacherEntryOpen'] is bool) {
      return _data!['teacherEntryOpen'] == true;
    }
    final status = _data?['cycleStatus']?.toString().toUpperCase();
    if (status != null && status.isNotEmpty) {
      return status == 'RELEASED' || status == 'LOCKED';
    }
    return _data?['released'] == true;
  }

  Future<void> _confirmWindowChange() async {
    if (_teacherEntryOpen) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release evaluations?'),
        content: const Text(
          'Teacher evaluation records will be created from current teaching allocations. Teachers can work until leadership starts reviewing each student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: ValueKey('confirm-release-evaluations'),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Release evaluations'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _release();
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
    final responsibilityRows = _consolidateTeacherClassResponsibilities(
      dashboardRows,
    );
    final focusedStream = widget.initialStreamId != null;
    final rows =
        responsibilityRows.where((assignment) {
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
    final classTeacherAssignments = rows
        .where((assignment) => assignment['assignmentType'] == 'CLASS_TEACHER')
        .toList();
    final commentStudentCount = classTeacherAssignments.fold<int>(
      0,
      (total, assignment) => total + _intValue(assignment['studentCount']),
    );
    final completedStudentComments = classTeacherAssignments.fold<int>(
      0,
      (total, assignment) => total + _intValue(assignment['commentsCompleted']),
    );
    final sentToLeadership = classTeacherAssignments.where((assignment) {
      final status = assignment['workflowStatus']?.toString().toUpperCase();
      return const {
        'READY_FOR_LEADERSHIP',
        'UNDER_REVIEW',
        'APPROVED',
      }.contains(status);
    }).length;
    final managerWorkspace = _manager && !focusedStream;
    final progress = _evaluationProgress(rows);
    final readiness = _readiness;
    final readyStudents = (readiness?['readyStudents'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          managerWorkspace
              ? 'Evaluations & comments'
              : focusedStream
              ? 'Ratings & comments progress'
              : 'Evaluations & comments',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1320),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                managerWorkspace
                                    ? 'Evaluations & comments'
                                    : focusedStream
                                    ? 'Ratings & comments progress — $_focusedStreamName'
                                    : 'My evaluation responsibilities',
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
                          _evaluationWindowControls()
                        else
                          _evaluationWindowStatusBadge(),
                      ],
                    ),
                    if (managerWorkspace && _pendingCorrections.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _correctionBanner(),
                    ],
                    if (managerWorkspace &&
                        _data?['setupChangesDetected'] == true) ...[
                      const SizedBox(height: 14),
                      _evaluationSetupChangesBanner(),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: managerWorkspace
                          ? [
                              _metric(
                                'Ratings complete',
                                '${progress.completedEvaluations} / ${progress.assignedEvaluations}',
                              ),
                              _metric(
                                'Comments complete',
                                '${progress.commentsCompleted} / ${progress.commentStudents}',
                              ),
                              _metric(
                                'Submitted for approval',
                                '${progress.commentsSubmitted} / ${progress.commentStudents}',
                              ),
                              _metric('Ready for reports', '$readyStudents'),
                            ]
                          : _manager
                          ? [
                              _metric(
                                'Teacher responsibilities',
                                '${rows.length}',
                              ),
                              _metric('Submitted', '$submittedAssignments'),
                              _metric('Pending', '$incompleteAssignments'),
                            ]
                          : [
                              _metric('Responsibilities', '${rows.length}'),
                              _metric(
                                'Ratings complete',
                                '$submittedAssignments / ${rows.length}',
                              ),
                              _metric(
                                'Student comments',
                                '$completedStudentComments / $commentStudentCount',
                              ),
                              _metric(
                                'Submitted for approval',
                                '$sentToLeadership / ${classTeacherAssignments.length}',
                              ),
                            ],
                    ),
                    const SizedBox(height: 22),
                    if (managerWorkspace) ...[
                      _workspaceTabs(),
                      const SizedBox(height: 16),
                      if (_managerView == 'Overview')
                        _overviewWorkspace(rows)
                      else if (_managerView == 'Report readiness')
                        _readinessView()
                      else
                        _assignmentsView(rows),
                    ] else
                      _assignmentsView(
                        rows,
                        streamName: focusedStream
                            ? widget.initialStreamName
                            : null,
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  List<Map<String, dynamic>> _consolidateTeacherClassResponsibilities(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final staff = row['staffId']?.toString().trim();
      final stream = row['streamId']?.toString().trim();
      final fallbackStaff = row['staffName']?.toString().trim() ?? 'Teacher';
      final fallbackStream = row['streamName']?.toString().trim() ?? 'Class';
      final key =
          '${staff?.isNotEmpty == true ? staff : fallbackStaff}:'
          '${stream?.isNotEmpty == true ? stream : fallbackStream}';
      grouped.putIfAbsent(key, () => []).add(row);
    }

    return grouped.values.map((group) {
      final sorted = [...group]
        ..sort((left, right) {
          final role = _assignmentRolePriority(
            right,
          ).compareTo(_assignmentRolePriority(left));
          if (role != 0) return role;
          final status = _assignmentStatusPriority(
            right,
          ).compareTo(_assignmentStatusPriority(left));
          if (status != 0) return status;
          return _intValue(
            right['completionPercent'],
          ).compareTo(_intValue(left['completionPercent']));
        });
      final result = Map<String, dynamic>.from(sorted.first);
      final subjects = <String>{};
      for (final row in group) {
        final values = row['subjectNames'];
        if (values is List) {
          subjects.addAll(
            values
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty),
          );
        }
        final type = row['assignmentType']?.toString();
        final subject = row['subjectName']?.toString().trim() ?? '';
        if (type == 'SUBJECT_TEACHER' &&
            subject.isNotEmpty &&
            !subject.toLowerCase().contains('teacher evaluation')) {
          subjects.addAll(
            subject
                .split(',')
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty),
          );
        }
      }
      final subjectNames = subjects.toList()
        ..sort(
          (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
        );
      result['subjectNames'] = subjectNames;
      result['responsibilityLabel'] = _responsibilityLabel(
        result,
        subjectNames,
      );
      return result;
    }).toList();
  }

  int _assignmentRolePriority(Map<String, dynamic> assignment) =>
      switch (assignment['assignmentType']?.toString()) {
        'CLASS_TEACHER' => 3,
        'SUPPORTING_CLASS_TEACHER' => 2,
        _ => 1,
      };

  int _assignmentStatusPriority(Map<String, dynamic> assignment) =>
      switch (assignment['status']?.toString()) {
        'SUBMITTED' => 3,
        'DRAFT' || 'IN_PROGRESS' => 2,
        _ => 1,
      };

  String _responsibilityLabel(
    Map<String, dynamic> assignment,
    List<String> subjects,
  ) {
    final role = switch (assignment['assignmentType']?.toString()) {
      'CLASS_TEACHER' => 'Class teacher',
      'SUPPORTING_CLASS_TEACHER' => 'Supporting class teacher',
      _ => 'Subject teacher',
    };
    return subjects.isEmpty ? role : '$role · ${subjects.join(', ')}';
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

  Widget _correctionBanner() => Card(
    color: const Color(0xFFFFF7ED),
    child: ListTile(
      leading: const Icon(Icons.rule_folder_outlined, color: Color(0xFFB45309)),
      title: Text(
        '${_pendingCorrections.length} report ${_pendingCorrections.length == 1 ? 'correction needs' : 'corrections need'} a decision',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Review the teacher’s proposed value and reason. Approval applies the change and regenerates the affected student report.',
      ),
      trailing: FilledButton.tonal(
        key: const ValueKey('review-report-corrections'),
        onPressed: _showCorrections,
        child: const Text('Review requests'),
      ),
    ),
  );

  Widget _evaluationSetupChangesBanner() => Card(
    color: const Color(0xFFEFF8F6),
    child: ListTile(
      leading: const Icon(Icons.sync_alt, color: Color(0xFF00796B)),
      title: const Text(
        'New class or teacher changes found',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Update evaluations to include the latest setup. Existing and submitted work will not be changed.',
      ),
      trailing: FilledButton.tonal(
        key: const ValueKey('update-evaluations'),
        onPressed: _syncingEvaluations ? null : _syncEvaluationRecords,
        child: Text(_syncingEvaluations ? 'Updating…' : 'Update evaluations'),
      ),
    ),
  );

  Future<void> _showCorrections() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report correction requests'),
          content: SizedBox(
            width: 760,
            child: _pendingCorrections.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No correction requests are awaiting a decision.',
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _pendingCorrections.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final request = _pendingCorrections[index];
                      final original =
                          request['originalScore']?.toString() ?? '—';
                      final proposed =
                          request['proposedScore']?.toString() ?? '—';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${request['customStudentId']} · ${request['assessmentTitle'] ?? request['assessmentId']}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '$original → $proposed\n${request['reason'] ?? ''}\nRequested by ${request['requestedBy'] ?? 'Unknown'}${request['assignedApprover'] == null ? '' : ' · Assigned to ${request['assignedApprover']}'}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            TextButton(
                              onPressed: () => _decideCorrection(
                                dialogContext,
                                setDialogState,
                                request,
                                approve: false,
                              ),
                              child: const Text('Reject'),
                            ),
                            FilledButton(
                              onPressed: () => _decideCorrection(
                                dialogContext,
                                setDialogState,
                                request,
                                approve: true,
                              ),
                              child: const Text('Approve & regenerate'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decideCorrection(
    BuildContext dialogContext,
    StateSetter setDialogState,
    Map<String, dynamic> request, {
    required bool approve,
  }) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Approve correction?' : 'Reject correction?'),
        content: TextField(
          controller: note,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: approve
                ? 'Approval note (optional)'
                : 'Rejection reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Approve & regenerate' : 'Reject'),
          ),
        ],
      ),
    );
    final decisionNote = note.text.trim();
    note.dispose();
    if (confirmed != true || !mounted) return;
    if (!approve && decisionNote.length < 5) {
      _message('Enter a clear rejection reason of at least 5 characters.');
      return;
    }
    try {
      await widget.api.decideReportCorrection(
        customSchoolId: widget.schoolId,
        requestId: (request['id'] as num).toInt(),
        approve: approve,
        note: decisionNote,
      );
      _pendingCorrections = await widget.api.getReportCorrections(
        customSchoolId: widget.schoolId,
        status: 'PENDING',
      );
      if (!mounted) return;
      setDialogState(() {});
      setState(() {});
      _message(
        approve
            ? 'Correction approved and the student report was regenerated.'
            : 'Correction request rejected. Official data was not changed.',
      );
    } on AssessmentApiException catch (error) {
      _message(error.message);
    }
  }

  Widget _evaluationWindowControls() {
    final open = _teacherEntryOpen;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        _evaluationWindowStatusBadge(),
        if (!open)
          FilledButton.icon(
            key: const ValueKey('release-evaluations'),
            onPressed: _updatingWindow ? null : _confirmWindowChange,
            icon: const Icon(Icons.lock_open_outlined),
            label: const Text('Release evaluations'),
          ),
      ],
    );
  }

  Widget _evaluationWindowStatusBadge() {
    final open = _teacherEntryOpen;
    final color = open ? const Color(0xFF00897B) : const Color(0xFF64748B);
    return Container(
      key: const ValueKey('evaluation-window-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: open ? const Color(0xFFE0F2F1) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: open ? const Color(0xFF99D5CE) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open ? Icons.lock_open_outlined : Icons.lock_outline,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            open ? 'Released' : 'Locked',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

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

  Widget _workspaceTabs() => SegmentedButton<String>(
    key: const ValueKey('evaluation-workspace-tabs'),
    segments: const [
      ButtonSegment(
        value: 'Overview',
        icon: Icon(Icons.dashboard_outlined),
        label: Text('Overview'),
      ),
      ButtonSegment(
        value: 'Teacher progress',
        icon: Icon(Icons.assignment_ind_outlined),
        label: Text('Teacher progress'),
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

  Widget _overviewTabs() => SegmentedButton<String>(
    key: const ValueKey('evaluation-overview-tabs'),
    segments: const [
      ButtonSegment(
        value: 'By staff',
        icon: Icon(Icons.people_outline),
        label: Text('By staff'),
      ),
      ButtonSegment(
        value: 'By class',
        icon: Icon(Icons.school_outlined),
        label: Text('By class'),
      ),
      ButtonSegment(
        value: 'Insights',
        icon: Icon(Icons.insights_outlined),
        label: Text('Insights'),
      ),
    ],
    selected: {_overviewView},
    onSelectionChanged: (value) => setState(() => _overviewView = value.first),
  );

  Widget _overviewWorkspace(List<Map<String, dynamic>> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ratings & comments overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Monitor teacher ratings and class-teacher comments by class or staff, then open Teacher progress when action is needed.',
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ],
            ),
          ),
          _overviewTabs(),
        ],
      ),
      const SizedBox(height: 16),
      _progressDashboard(rows, view: _overviewView),
    ],
  );

  Widget _progressDashboard(List<Map<String, dynamic>> rows, {String? view}) {
    final selectedView = view ?? _managerView;
    if (selectedView == 'Insights') {
      return _insightsDashboard(_evaluationProgress(rows));
    }
    final byStaff = selectedView == 'By staff';
    final groups = _sortProgressGroups(
      _groupEvaluationProgress(rows, byStaff: byStaff),
    );
    return Column(
      key: ValueKey(byStaff ? 'evaluation-by-staff' : 'evaluation-by-class'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          byStaff
              ? 'Ratings & comments progress by staff'
              : 'Ratings & comments progress by class',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          byStaff
              ? 'See completed ratings and class-teacher comments for each staff member.'
              : 'See ratings, comments and approval progress across every class.',
          style: const TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                _data?['released'] == true
                    ? 'No teacher rating or comment responsibilities are available yet.'
                    : 'Release evaluations and comments to generate progress information.',
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 820
                ? Column(
                    children: groups
                        .map(
                          (group) => _progressCard(
                            group,
                            onTap: byStaff
                                ? null
                                : () => _openClassEvaluations(group.name, rows),
                          ),
                        )
                        .toList(),
                  )
                : _progressTable(groups, byStaff: byStaff, sourceRows: rows),
          ),
      ],
    );
  }

  Widget _insightsDashboard(_EvaluationProgressGroup progress) {
    final raw = _data?['insights'];
    final insights = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final totalStudents = _intValue(insights['totalStudents']);
    final criteria = (insights['criteria'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.map((key, item) => MapEntry('$key', item)))
        .toList();
    final distributionRaw = insights['overallDistribution'];
    final distribution = distributionRaw is Map
        ? distributionRaw.map((key, value) => MapEntry('$key', value))
        : <String, dynamic>{};
    return Column(
      key: const ValueKey('evaluation-insights'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evaluation insights',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'School-wide patterns from submitted evaluations. Individual teacher ratings are not shown.',
          style: TextStyle(color: Colors.blueGrey),
        ),
        if (progress.remainingEvaluations > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              border: Border.all(color: const Color(0xFFFFD58A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Preliminary analysis: ${progress.completedEvaluations} of '
              '${progress.assignedEvaluations} assigned evaluations are submitted. '
              'Results may change as the remaining ${progress.remainingEvaluations} '
              'are completed.',
              style: const TextStyle(
                color: Color(0xFF8A5A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (totalStudents == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Insights will appear after teacher evaluations contain student observations.',
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _insightMetric(
                'Students analyzed',
                '${_intValue(insights['studentsAnalyzed'])} of $totalStudents',
                Icons.groups_outlined,
              ),
              _insightMetric(
                'Observed criteria in submitted work',
                '${_intValue(insights['observationCompletenessPercent'])}%',
                Icons.fact_check_outlined,
              ),
              _insightMetric(
                'Not observed responses',
                '${_intValue(insights['notObservedPercent'])}%',
                Icons.visibility_off_outlined,
              ),
              _insightMetric(
                'Students missing observations',
                '${_intValue(insights['studentsMissingObservations'])}',
                Icons.warning_amber_rounded,
                warning: _intValue(insights['studentsMissingObservations']) > 0,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Overall wording distribution',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _ratings
                .where((rating) => rating != 'Not observed')
                .map(
                  (rating) => _distributionCard(
                    rating,
                    _intValue(distribution[rating]),
                    distribution.values.fold<int>(
                      0,
                      (total, value) => total + _intValue(value),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Analysis by evaluation criterion',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Needs support counts only students whose combined wording is Needs improvement.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 900
                ? Column(children: criteria.map(_criterionInsightCard).toList())
                : _criterionInsightsTable(criteria),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.history, size: 18, color: Colors.blueGrey),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Previous-term comparison will appear once a comparable completed term has evaluation results.',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _insightMetric(
    String label,
    String value,
    IconData icon, {
    bool warning = false,
  }) => SizedBox(
    width: 230,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: warning
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE0F2F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: warning
                    ? const Color(0xFFD97706)
                    : const Color(0xFF00897B),
              ),
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
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11,
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

  Widget _distributionCard(String rating, int count, int total) => Container(
    width: 210,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 36,
          decoration: BoxDecoration(
            color: _ratingColor(rating),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rating, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                '$count result${count == 1 ? '' : 's'} · ${total == 0 ? 0 : (count * 100 / total).round()}%',
                style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _criterionInsightsTable(List<Map<String, dynamic>> criteria) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('CRITERION', style: _progressHeaderStyle),
                  ),
                  Expanded(
                    child: Text(
                      'EXCELLENT',
                      textAlign: TextAlign.center,
                      style: _progressHeaderStyle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'GOOD',
                      textAlign: TextAlign.center,
                      style: _progressHeaderStyle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'SATISFACTORY',
                      textAlign: TextAlign.center,
                      style: _progressHeaderStyle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'NEEDS SUPPORT',
                      textAlign: TextAlign.center,
                      style: _progressHeaderStyle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'MISSING',
                      textAlign: TextAlign.center,
                      style: _progressHeaderStyle,
                    ),
                  ),
                ],
              ),
            ),
            ...criteria.map((criterion) {
              final raw = criterion['distribution'];
              final values = raw is Map
                  ? raw.map((key, value) => MapEntry('$key', value))
                  : <String, dynamic>{};
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        criterion['label']?.toString() ?? 'Criterion',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _insightNumber(_intValue(values['Excellent'])),
                    _insightNumber(_intValue(values['Good'])),
                    _insightNumber(_intValue(values['Satisfactory'])),
                    _insightNumber(
                      _intValue(criterion['needsSupportStudents']),
                      warning: _intValue(criterion['needsSupportStudents']) > 0,
                    ),
                    _insightNumber(
                      _intValue(criterion['missingStudents']),
                      warning: _intValue(criterion['missingStudents']) > 0,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );

  Widget _insightNumber(int value, {bool warning = false}) => Expanded(
    child: Text(
      '$value',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        color: warning ? const Color(0xFFD97706) : const Color(0xFF334155),
      ),
    ),
  );

  Widget _criterionInsightCard(Map<String, dynamic> criterion) {
    final raw = criterion['distribution'];
    final values = raw is Map
        ? raw.map((key, value) => MapEntry('$key', value))
        : <String, dynamic>{};
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              criterion['label']?.toString() ?? 'Criterion',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final rating in _ratings.where(
                  (value) => value != 'Not observed',
                ))
                  Text('$rating ${_intValue(values[rating])}'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${_intValue(criterion['needsSupportStudents'])} need support · ${_intValue(criterion['missingStudents'])} missing observations',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _ratingColor(String rating) => switch (rating) {
    'Excellent' => const Color(0xFF00897B),
    'Good' => const Color(0xFF3B82F6),
    'Satisfactory' => const Color(0xFFD97706),
    _ => const Color(0xFFDC2626),
  };

  Widget _progressTable(
    List<_EvaluationProgressGroup> groups, {
    required bool byStaff,
    required List<Map<String, dynamic>> sourceRows,
  }) => LayoutBuilder(
    builder: (context, constraints) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            key: const ValueKey('evaluation-progress-table'),
            sortColumnIndex: _progressSortColumnIndex,
            sortAscending: _progressSortAscending,
            showCheckboxColumn: false,
            headingRowHeight: 48,
            dataRowMinHeight: 68,
            dataRowMaxHeight: 76,
            horizontalMargin: 18,
            columnSpacing: 28,
            dividerThickness: .75,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            headingTextStyle: _progressHeaderStyle,
            columns: [
              DataColumn(
                label: Text(byStaff ? 'STAFF' : 'CLASS'),
                onSort: (_, ascending) => _sortProgress('name', ascending),
              ),
              DataColumn(
                label: const Text('RATINGS'),
                onSort: (_, ascending) => _sortProgress('ratings', ascending),
              ),
              DataColumn(
                label: const Text('COMMENTS'),
                onSort: (_, ascending) => _sortProgress('comments', ascending),
              ),
              DataColumn(
                label: const Text('APPROVAL STATUS'),
                onSort: (_, ascending) => _sortProgress('approval', ascending),
              ),
              if (!byStaff) const DataColumn(label: Text('ACTION')),
            ],
            rows: [
              for (var index = 0; index < groups.length; index++)
                _progressDataRow(
                  groups[index],
                  index: index,
                  byStaff: byStaff,
                  sourceRows: sourceRows,
                ),
            ],
          ),
        ),
      ),
    ),
  );

  DataRow _progressDataRow(
    _EvaluationProgressGroup group, {
    required int index,
    required bool byStaff,
    required List<Map<String, dynamic>> sourceRows,
  }) {
    void openClass() => _openClassEvaluations(group.name, sourceRows);
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFF0FDFA);
        }
        return index.isOdd ? const Color(0xFFFCFDFE) : Colors.white;
      }),
      onSelectChanged: byStaff ? null : (_) => openClass(),
      cells: [
        DataCell(
          SizedBox(
            width: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${group.assignmentCount} teacher responsibilit${group.assignmentCount == 1 ? 'y' : 'ies'}',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: _adminProgressIndicator(
              completed: group.completedEvaluations,
              total: group.assignedEvaluations,
              percent: group.completedPercent,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: group.commentStudents == 0
                ? const Text(
                    'Not required',
                    style: TextStyle(color: Colors.blueGrey),
                  )
                : _adminProgressIndicator(
                    completed: group.commentsCompleted,
                    total: group.commentStudents,
                    percent: group.commentPercent,
                    comment: true,
                  ),
          ),
        ),
        DataCell(_adminApprovalBadge(group.approvalStatus)),
        if (!byStaff)
          DataCell(
            TextButton.icon(
              onPressed: openClass,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('View'),
            ),
          ),
      ],
    );
  }

  Widget _adminProgressIndicator({
    required int completed,
    required int total,
    required int percent,
    bool comment = false,
  }) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$completed of $total complete',
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: percent / 100,
        minHeight: 6,
        borderRadius: BorderRadius.circular(999),
        backgroundColor: const Color(0xFFE2E8F0),
        color: percent == 100
            ? const Color(0xFF00897B)
            : comment
            ? const Color(0xFFF59E0B)
            : const Color(0xFF14B8A6),
      ),
    ],
  );

  Widget _adminApprovalBadge(String label) {
    final approved = label == 'Approved';
    final pending = label == 'Awaiting approval' || label == 'Under review';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: approved
            ? const Color(0xFFECFDF5)
            : pending
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: approved
              ? const Color(0xFFA7F3D0)
              : pending
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: approved
              ? const Color(0xFF047857)
              : pending
              ? const Color(0xFF1D4ED8)
              : const Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _progressCard(
    _EvaluationProgressGroup group, {
    VoidCallback? onTap,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${group.assignmentCount} teacher responsibilit${group.assignmentCount == 1 ? 'y' : 'ies'}',
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ratings',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
            _adminProgressIndicator(
              completed: group.completedEvaluations,
              total: group.assignedEvaluations,
              percent: group.completedPercent,
            ),
            const SizedBox(height: 10),
            if (group.commentStudents > 0) ...[
              const Text(
                'Comments',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
              _adminProgressIndicator(
                completed: group.commentsCompleted,
                total: group.commentStudents,
                percent: group.commentPercent,
                comment: true,
              ),
              const SizedBox(height: 10),
            ],
            _adminApprovalBadge(group.approvalStatus),
          ],
        ),
      ),
    ),
  );

  Future<void> _openClassEvaluations(
    String className,
    List<Map<String, dynamic>> rows,
  ) async {
    final classRows = rows
        .where((row) => row['streamName']?.toString() == className)
        .toList();
    final studentsById = <String, Map<String, dynamic>>{};
    for (final assignment in classRows) {
      for (final raw in assignment['students'] as List? ?? const []) {
        if (raw is! Map) continue;
        final student = raw.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final id = student['id']?.toString() ?? '';
        if (id.isNotEmpty) studentsById[id] = student;
      }
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClassEvaluationResultsView(
          api: widget.api,
          schoolId: widget.schoolId,
          termId: widget.setup.termId,
          className: className,
          students: studentsById.values.toList(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  static const _progressHeaderStyle = TextStyle(
    color: Color(0xFF64748B),
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: .35,
  );

  int get _progressSortColumnIndex => switch (_progressSortColumn) {
    'ratings' => 1,
    'comments' => 2,
    'approval' => 3,
    _ => 0,
  };

  void _sortProgress(String column, bool ascending) {
    setState(() {
      _progressSortColumn = column;
      _progressSortAscending = ascending;
    });
  }

  List<_EvaluationProgressGroup> _sortProgressGroups(
    List<_EvaluationProgressGroup> groups,
  ) {
    final sorted = [...groups];
    sorted.sort((left, right) {
      final comparison = switch (_progressSortColumn) {
        'ratings' => left.completedPercent.compareTo(right.completedPercent),
        'comments' => left.commentPercent.compareTo(right.commentPercent),
        'approval' => left.approvalStatus.compareTo(right.approvalStatus),
        _ => left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      };
      if (comparison != 0) {
        return _progressSortAscending ? comparison : -comparison;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return sorted;
  }

  _EvaluationProgressGroup _evaluationProgress(
    List<Map<String, dynamic>> rows,
  ) => _aggregateEvaluationProgress('All evaluations', rows);

  List<_EvaluationProgressGroup> _groupEvaluationProgress(
    List<Map<String, dynamic>> rows, {
    required bool byStaff,
  }) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final names = <String, String>{};
    for (final row in rows) {
      final keyValue = byStaff ? row['staffId'] : row['streamId'];
      final nameValue = byStaff ? row['staffName'] : row['streamName'];
      final name = nameValue?.toString().trim();
      final key = keyValue?.toString().trim();
      final resolvedName = name == null || name.isEmpty
          ? (byStaff ? 'Unassigned staff' : 'Unassigned class')
          : name;
      final resolvedKey = key == null || key.isEmpty ? resolvedName : key;
      grouped.putIfAbsent(resolvedKey, () => []).add(row);
      names[resolvedKey] = resolvedName;
    }
    final result =
        grouped.entries
            .map(
              (entry) =>
                  _aggregateEvaluationProgress(names[entry.key]!, entry.value),
            )
            .toList()
          ..sort((left, right) {
            final pending = right.remainingEvaluations.compareTo(
              left.remainingEvaluations,
            );
            return pending != 0 ? pending : left.name.compareTo(right.name);
          });
    return result;
  }

  _EvaluationProgressGroup _aggregateEvaluationProgress(
    String name,
    List<Map<String, dynamic>> rows,
  ) {
    var assigned = 0;
    var completed = 0;
    var remaining = 0;
    var rated = 0;
    var required = 0;
    var commentStudents = 0;
    var commentsCompleted = 0;
    var commentsSubmitted = 0;
    var commentsUnderReview = 0;
    var commentsApproved = 0;
    for (final row in rows) {
      final students = _intValue(row['studentCount']);
      final rowRequired = _intValue(row['requiredCount']) > 0
          ? _intValue(row['requiredCount'])
          : students * _criteria.length;
      final percent = _intValue(row['completionPercent']).clamp(0, 100);
      final rowRated = row.containsKey('ratedCount')
          ? _intValue(row['ratedCount']).clamp(0, rowRequired)
          : (rowRequired * percent / 100).round();
      final rowCompleted = row.containsKey('completedStudentCount')
          ? _intValue(row['completedStudentCount']).clamp(0, students)
          : row['status'] == 'SUBMITTED'
          ? students
          : (students * percent / 100).floor();
      final rowRemaining = row.containsKey('remainingStudentCount')
          ? _intValue(row['remainingStudentCount']).clamp(0, students)
          : students - rowCompleted;
      assigned += students;
      completed += rowCompleted;
      remaining += rowRemaining;
      rated += rowRated;
      required += rowRequired;
      if (row['assignmentType'] == 'CLASS_TEACHER') {
        commentStudents += students;
        commentsCompleted += _intValue(
          row['commentsCompleted'],
        ).clamp(0, students);
        commentsSubmitted += _intValue(
          row['commentsSubmitted'],
        ).clamp(0, students);
        commentsUnderReview += _intValue(
          row['commentsUnderReview'],
        ).clamp(0, students);
        commentsApproved += _intValue(
          row['commentsApproved'],
        ).clamp(0, students);
      }
    }
    return _EvaluationProgressGroup(
      name: name,
      assignmentCount: rows.length,
      assignedEvaluations: assigned,
      completedEvaluations: completed,
      remainingEvaluations: remaining,
      ratedCriteria: rated,
      requiredCriteria: required,
      commentStudents: commentStudents,
      commentsCompleted: commentsCompleted,
      commentsSubmitted: commentsSubmitted,
      commentsUnderReview: commentsUnderReview,
      commentsApproved: commentsApproved,
    );
  }

  int _intValue(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  Widget _assignmentsView(
    List<Map<String, dynamic>> rows, {
    String? streamName,
  }) {
    final personalDashboard = streamName == null && !_manager;
    final classNames =
        rows
            .map((row) => row['streamName']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
    if (_teacherClassFilter != 'All classes' &&
        !classNames.contains(_teacherClassFilter)) {
      _teacherClassFilter = 'All classes';
    }
    final query = _teacherProgressSearch.text.trim().toLowerCase();
    final visible = rows.where((row) {
      final matchesClass =
          _teacherClassFilter == 'All classes' ||
          row['streamName']?.toString() == _teacherClassFilter;
      final searchable =
          '${row['staffName']} ${row['subjectName']} ${row['subjectNames']} '
                  '${row['responsibilityLabel']} ${row['streamName']} ${row['status']}'
              .toLowerCase();
      return matchesClass && (query.isEmpty || searchable.contains(query));
    }).toList();
    visible.sort((left, right) {
      int result;
      switch (_teacherProgressSort) {
        case 'Class A–Z':
          result = (left['streamName']?.toString() ?? '').compareTo(
            right['streamName']?.toString() ?? '',
          );
        case 'Comments':
          result = _intValue(
            left['commentsCompleted'],
          ).compareTo(_intValue(right['commentsCompleted']));
        case 'Subject A–Z':
          result = _teacherResponsibilityLabel(
            left,
          ).compareTo(_teacherResponsibilityLabel(right));
        case 'Status':
          result = _teacherApprovalSortKey(
            left,
          ).compareTo(_teacherApprovalSortKey(right));
        case 'Students':
          result = _intValue(
            left['studentCount'],
          ).compareTo(_intValue(right['studentCount']));
        case 'Completion':
          result = _intValue(
            left['completionPercent'],
          ).compareTo(_intValue(right['completionPercent']));
        default:
          result = (left['staffName']?.toString() ?? '').compareTo(
            right['staffName']?.toString() ?? '',
          );
      }
      if (result != 0) {
        return _teacherProgressSortAscending ? result : -result;
      }
      return (left['streamName']?.toString() ?? '').compareTo(
        right['streamName']?.toString() ?? '',
      );
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          streamName == null
              ? (_manager
                    ? 'Teacher ratings & comments progress'
                    : 'Responsibilities by class')
              : 'Teacher ratings & comment responsibilities',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (personalDashboard) ...[
          const SizedBox(height: 4),
          const Text(
            'One responsibility per class. Subjects taught in the same class are grouped together.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        ] else if (streamName != null) ...[
          const SizedBox(height: 4),
          Text(
            'Each teacher appears once for this class, with all assigned subjects shown together.',
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
        const SizedBox(height: 10),
        if (rows.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  controller: _teacherProgressSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: personalDashboard
                        ? 'Search class or role'
                        : 'Search teacher, class or responsibility',
                  ),
                ),
              ),
              if (streamName == null && classNames.length > 1)
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String>(
                    key: const ValueKey('teacher-responsibility-class-filter'),
                    value: _teacherClassFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: ['All classes', ...classNames]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _teacherClassFilter = value ?? 'All classes',
                    ),
                  ),
                ),
              Text(
                '${visible.length} of ${rows.length} responsibilities',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (rows.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                _data?['released'] == true
                    ? 'No teacher evaluations were created. Add active subject-teacher and class-teacher allocations, then refresh this page.'
                    : 'The headmaster must release the exercise before teachers can evaluate students.',
              ),
            ),
          )
        else if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No teacher evaluations match this search.'),
            ),
          )
        else
          _teacherProgressTable(visible, personal: personalDashboard),
      ],
    );
  }

  int get _teacherProgressSortColumn => switch (_teacherProgressSort) {
    'Subject A–Z' => 1,
    'Class A–Z' => 2,
    'Students' => 3,
    'Completion' => 4,
    'Status' => 5,
    _ => 0,
  };

  int get _personalResponsibilitySortColumn => switch (_teacherProgressSort) {
    'Completion' => 1,
    'Comments' => 2,
    'Status' => 3,
    _ => 0,
  };

  void _sortTeacherProgress(String field, bool ascending) {
    setState(() {
      _teacherProgressSort = field;
      _teacherProgressSortAscending = ascending;
    });
  }

  List<String> _teacherResponsibilitySubjects(Map<String, dynamic> assignment) {
    final raw = assignment['subjectNames'];
    final values = raw is List
        ? raw
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    if (values.isEmpty &&
        assignment['assignmentType']?.toString() == 'SUBJECT_TEACHER') {
      final subject = assignment['subjectName']?.toString().trim() ?? '';
      if (subject.isNotEmpty &&
          !subject.toLowerCase().contains('teacher evaluation')) {
        values.addAll(
          subject
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
    }
    values.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return values;
  }

  String _teacherResponsibilityRole(Map<String, dynamic> assignment) =>
      switch (assignment['assignmentType']?.toString()) {
        'CLASS_TEACHER' => 'Class teacher',
        'SUPPORTING_CLASS_TEACHER' => 'Supporting class teacher',
        _ => 'Subject teacher',
      };

  String _teacherResponsibilityLabel(Map<String, dynamic> assignment) {
    final role = _teacherResponsibilityRole(assignment);
    final subjects = _teacherResponsibilitySubjects(assignment);
    return subjects.isEmpty ? role : '$role · ${subjects.join(', ')}';
  }

  String? _teacherResponsibilityDetail(Map<String, dynamic> assignment) {
    final subjects = _teacherResponsibilitySubjects(assignment);
    if (subjects.isEmpty) return null;
    return assignment['assignmentType']?.toString() == 'SUBJECT_TEACHER'
        ? subjects.join(', ')
        : 'Also teaches: ${subjects.join(', ')}';
  }

  String _teacherApprovalSortKey(Map<String, dynamic> assignment) {
    if (assignment['assignmentType']?.toString() != 'CLASS_TEACHER') {
      return '6-not-required';
    }
    return switch (assignment['workflowStatus']?.toString().toUpperCase()) {
      'REJECTED' => '1-rejected',
      'READY_FOR_LEADERSHIP' => '2-awaiting-approval',
      'UNDER_REVIEW' => '3-under-review',
      'APPROVED' => '4-approved',
      _ => '0-not-submitted',
    };
  }

  Widget _teacherProgressTable(
    List<Map<String, dynamic>> rows, {
    bool personal = false,
  }) {
    if (personal) return _personalResponsibilitiesTable(rows);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1400) {
            return Column(
              children: rows.map(_teacherProgressCompactRow).toList(),
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                sortColumnIndex: _teacherProgressSortColumn,
                sortAscending: _teacherProgressSortAscending,
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                headingTextStyle: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
                horizontalMargin: 18,
                columnSpacing: 24,
                columns: [
                  DataColumn(
                    label: const Text('TEACHER'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Teacher A–Z', ascending),
                  ),
                  DataColumn(
                    label: const Text('RESPONSIBILITIES'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Subject A–Z', ascending),
                  ),
                  DataColumn(
                    label: const Text('CLASS'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Class A–Z', ascending),
                  ),
                  DataColumn(
                    label: const Text('STUDENTS'),
                    numeric: true,
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Students', ascending),
                  ),
                  DataColumn(
                    label: const Text('COMPLETION'),
                    numeric: true,
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Completion', ascending),
                  ),
                  DataColumn(
                    label: const Text('STATUS'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Status', ascending),
                  ),
                  const DataColumn(label: Text('ACTIONS')),
                ],
                rows: rows.map(_teacherProgressRow).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _personalResponsibilitiesTable(List<Map<String, dynamic>> rows) =>
      LayoutBuilder(
        builder: (context, constraints) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                key: const ValueKey('teacher-responsibilities-table'),
                sortColumnIndex: _personalResponsibilitySortColumn,
                sortAscending: _teacherProgressSortAscending,
                showCheckboxColumn: false,
                headingRowHeight: 48,
                dataRowMinHeight: 78,
                dataRowMaxHeight: 92,
                horizontalMargin: 18,
                columnSpacing: 28,
                dividerThickness: .75,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                headingTextStyle: _progressHeaderStyle,
                columns: [
                  DataColumn(
                    label: const Text('CLASS'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Class A–Z', ascending),
                  ),
                  DataColumn(
                    label: const Text('RATINGS'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Completion', ascending),
                  ),
                  DataColumn(
                    label: const Text('COMMENTS'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Comments', ascending),
                  ),
                  DataColumn(
                    label: const Text('APPROVAL STATUS'),
                    onSort: (_, ascending) =>
                        _sortTeacherProgress('Status', ascending),
                  ),
                  const DataColumn(label: Text('ACTION')),
                ],
                rows: [
                  for (var index = 0; index < rows.length; index++)
                    _personalResponsibilityDataRow(rows[index], index),
                ],
              ),
            ),
          ),
        ),
      );

  DataRow _personalResponsibilityDataRow(
    Map<String, dynamic> assignment,
    int index,
  ) {
    final progress = _intValue(assignment['completionPercent']).clamp(0, 100);
    final className =
        assignment['streamName']?.toString().trim() ?? 'Unassigned class';
    final students = _intValue(assignment['studentCount']);
    final subjectCount = _teacherResponsibilitySubjects(assignment).length;
    final role = _teacherResponsibilityRole(assignment);
    final classTeacher = assignment['assignmentType'] == 'CLASS_TEACHER';
    final commentsCompleted = _intValue(
      assignment['commentsCompleted'],
    ).clamp(0, students);
    final ratingsCompleted = students == 0
        ? 0
        : (students * progress / 100).round().clamp(0, students).toInt();

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFF0FDFA);
        }
        return index.isOdd ? const Color(0xFFFCFDFE) : Colors.white;
      }),
      cells: [
        DataCell(
          SizedBox(
            width: 275,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  key: ValueKey('responsibility-class-$className'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    role,
                    '$students ${students == 1 ? 'student' : 'students'}',
                    if (subjectCount > 0)
                      '$subjectCount ${subjectCount == 1 ? 'subject' : 'subjects'}',
                  ].join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: _adminProgressIndicator(
              completed: ratingsCompleted,
              total: students,
              percent: progress,
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: classTeacher
                ? _adminProgressIndicator(
                    completed: commentsCompleted,
                    total: students,
                    percent: students == 0
                        ? 0
                        : (commentsCompleted * 100 / students).round(),
                    comment: true,
                  )
                : const Text(
                    'Not required',
                    style: TextStyle(color: Colors.blueGrey),
                  ),
          ),
        ),
        DataCell(_personalApprovalStatus(assignment)),
        DataCell(
          SizedBox(
            width: 270,
            child: Align(
              alignment: Alignment.centerRight,
              child: _personalResponsibilityActions(assignment),
            ),
          ),
        ),
      ],
    );
  }

  Widget _personalApprovalStatus(Map<String, dynamic> assignment) {
    if (assignment['assignmentType']?.toString() != 'CLASS_TEACHER') {
      return _adminApprovalBadge('Not required');
    }
    return _approvalStatusBadge(assignment) ??
        _adminApprovalBadge('Not submitted');
  }

  Widget? _approvalStatusBadge(Map<String, dynamic> assignment) {
    final pendingGeneration = assignment['pendingGeneration'] == true;
    final workflowStatus = assignment['workflowStatus']
        ?.toString()
        .toUpperCase();
    final label = pendingGeneration
        ? 'Available after release'
        : switch (workflowStatus) {
            'READY_FOR_LEADERSHIP' => 'Awaiting approval',
            'UNDER_REVIEW' => 'Under review',
            'APPROVED' => 'Approved',
            'REJECTED' => 'Rejected',
            _ => null,
          };
    if (label == null) return null;
    final normalized = label.toLowerCase();
    final (background, border, foreground) = switch (normalized) {
      'approved' => (
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
        const Color(0xFF047857),
      ),
      'awaiting approval' => (
        const Color(0xFFEFF8F6),
        const Color(0xFF99D5CE),
        const Color(0xFF087B69),
      ),
      'under review' => (
        const Color(0xFFEFF6FF),
        const Color(0xFFBFDBFE),
        const Color(0xFF1D4ED8),
      ),
      'rejected' => (
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
        const Color(0xFFB91C1C),
      ),
      _ => (
        const Color(0xFFF8FAFC),
        const Color(0xFFCBD5E1),
        const Color(0xFF475569),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _personalResponsibilityActions(Map<String, dynamic> assignment) {
    final own =
        assignment['staffName'].toString().trim().toLowerCase() ==
        widget.viewerName.trim().toLowerCase();
    final submitted = assignment['status'] == 'SUBMITTED';
    final pendingGeneration = assignment['pendingGeneration'] == true;
    final progress = _intValue(assignment['completionPercent']);
    final classTeacher = assignment['assignmentType'] == 'CLASS_TEACHER';
    final commentsCompleted = _intValue(assignment['commentsCompleted']);
    final actions = <Widget>[];

    if (own && !submitted && !pendingGeneration && _teacherEntryOpen) {
      actions.add(
        FilledButton(
          onPressed: () => _openAssignment(assignment),
          child: Text(progress == 0 ? 'Start' : 'Continue'),
        ),
      );
    }
    if (own && !submitted && !pendingGeneration && !_teacherEntryOpen) {
      actions.add(
        const Text(
          'Entry locked',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (own && submitted && classTeacher) {
      actions.add(
        FilledButton.tonal(
          onPressed: () => _review(assignment),
          child: Text(
            commentsCompleted == 0
                ? 'Add student comments'
                : 'Continue student comments',
          ),
        ),
      );
    }
    if (own && submitted && !pendingGeneration && _teacherEntryOpen) {
      actions.add(
        OutlinedButton(
          onPressed: () => _openAssignment(assignment),
          child: const Text('Edit ratings'),
        ),
      );
    }
    if (pendingGeneration) {
      actions.add(
        const Text('No action yet', style: TextStyle(color: Color(0xFF64748B))),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
  }

  DataRow _teacherProgressRow(Map<String, dynamic> assignment) {
    final own =
        assignment['staffName'].toString().trim().toLowerCase() ==
        widget.viewerName.trim().toLowerCase();
    final submitted = assignment['status'] == 'SUBMITTED';
    final pendingGeneration = assignment['pendingGeneration'] == true;
    final progress = (assignment['completionPercent'] as num?)?.round() ?? 0;
    final classTeacher = assignment['assignmentType'] == 'CLASS_TEACHER';
    final commentsCompleted =
        (assignment['commentsCompleted'] as num?)?.toInt() ?? 0;
    return DataRow(
      cells: [
        DataCell(
          Text(
            assignment['staffName']?.toString() ?? 'Teacher',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _teacherResponsibilityRole(assignment),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (_teacherResponsibilityDetail(assignment) case final detail?)
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                ),
            ],
          ),
        ),
        DataCell(Text(assignment['streamName']?.toString() ?? 'Unassigned')),
        DataCell(Text('${assignment['studentCount'] ?? 0}')),
        DataCell(
          SizedBox(
            width: 125,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 7),
                Text('$progress%'),
              ],
            ),
          ),
        ),
        DataCell(
          Chip(
            label: Text(
              pendingGeneration
                  ? 'AVAILABLE ON RELEASE'
                  : _assignmentWorkflowStatusLabel(assignment),
            ),
          ),
        ),
        DataCell(
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (own && !submitted && !pendingGeneration && _teacherEntryOpen)
                TextButton(
                  onPressed: () => _openAssignment(assignment),
                  child: Text(progress == 0 ? 'Start' : 'Continue'),
                ),
              if (own && !submitted && !pendingGeneration && !_teacherEntryOpen)
                const Text('Entry locked'),
              if (own && submitted && !pendingGeneration && _teacherEntryOpen)
                TextButton(
                  onPressed: () => _openAssignment(assignment),
                  child: const Text('Edit ratings'),
                ),
              if (own && submitted && classTeacher)
                FilledButton.tonal(
                  onPressed: () => _review(assignment),
                  child: Text(
                    commentsCompleted == 0
                        ? 'Add student comments'
                        : 'Continue student comments',
                  ),
                ),
              if (_manager && submitted && (!classTeacher || own))
                TextButton(
                  onPressed: () => _viewAssignment(assignment),
                  child: const Text('View'),
                ),
              if (_manager && !own && submitted && classTeacher)
                TextButton(
                  onPressed: () => _review(assignment, leadershipReview: true),
                  child: const Text('Review results'),
                ),
              if (_manager && !submitted && !pendingGeneration)
                TextButton.icon(
                  onPressed: () => _remind(assignment),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Remind'),
                ),
              if (pendingGeneration)
                const Tooltip(
                  message:
                      'This becomes editable when evaluations are released.',
                  child: Icon(
                    Icons.lock_clock_outlined,
                    color: Colors.blueGrey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teacherProgressCompactRow(Map<String, dynamic> assignment) {
    final own =
        assignment['staffName'].toString().trim().toLowerCase() ==
        widget.viewerName.trim().toLowerCase();
    final submitted = assignment['status'] == 'SUBMITTED';
    final pendingGeneration = assignment['pendingGeneration'] == true;
    final progress = (assignment['completionPercent'] as num?)?.round() ?? 0;
    final classTeacher = assignment['assignmentType'] == 'CLASS_TEACHER';
    final commentsCompleted =
        (assignment['commentsCompleted'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${assignment['staffName']} · '
                  '${_teacherResponsibilityRole(assignment)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Chip(
                label: Text(
                  pendingGeneration
                      ? 'AVAILABLE ON RELEASE'
                      : _assignmentWorkflowStatusLabel(assignment),
                ),
              ),
            ],
          ),
          Text(
            '${assignment['streamName'] ?? 'Unassigned'} · '
            '${assignment['studentCount'] ?? 0} students',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
          if (_teacherResponsibilityDetail(assignment) case final detail?)
            Text(
              detail,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress / 100, minHeight: 5),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (own && !submitted && !pendingGeneration && _teacherEntryOpen)
                TextButton(
                  onPressed: () => _openAssignment(assignment),
                  child: Text(progress == 0 ? 'Start' : 'Continue'),
                ),
              if (own && !submitted && !pendingGeneration && !_teacherEntryOpen)
                const Text('Entry locked'),
              if (own && submitted && !pendingGeneration && _teacherEntryOpen)
                TextButton(
                  onPressed: () => _openAssignment(assignment),
                  child: const Text('Edit ratings'),
                ),
              if (own && submitted && classTeacher)
                FilledButton.tonal(
                  onPressed: () => _review(assignment),
                  child: Text(
                    commentsCompleted == 0
                        ? 'Add student comments'
                        : 'Continue student comments',
                  ),
                ),
              if (_manager && submitted && (!classTeacher || own))
                TextButton(
                  onPressed: () => _viewAssignment(assignment),
                  child: const Text('View'),
                ),
              if (_manager && !own && submitted && classTeacher)
                TextButton(
                  onPressed: () => _review(assignment, leadershipReview: true),
                  child: const Text('Review results'),
                ),
              if (_manager && !submitted && !pendingGeneration)
                TextButton.icon(
                  onPressed: () => _remind(assignment),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Remind'),
                ),
              if (pendingGeneration)
                const Text(
                  'Locked until evaluations are released',
                  style: TextStyle(color: Colors.blueGrey),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readinessView() {
    final readiness = _readiness;
    if (readiness == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Report readiness is not available yet. Refresh the teacher evaluations and try again.',
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
    filtered.sort((left, right) {
      Comparable<Object> valueFor(Map<String, dynamic> student) =>
          switch (_readinessSortColumn) {
            'id' => student['customStudentId']?.toString().toLowerCase() ?? '',
            'class' => student['streamName']?.toString().toLowerCase() ?? '',
            'review' => student['reviewStatus'] == 'APPROVED' ? 1 : 0,
            'blockers' => (student['blockers'] as List? ?? const []).length,
            'readiness' => student['ready'] == true ? 1 : 0,
            _ => student['studentName']?.toString().toLowerCase() ?? '',
          };
      final result = valueFor(left).compareTo(valueFor(right));
      return _readinessSortAscending ? result : -result;
    });
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
                          ? 'Release evaluations to create teacher evaluation records and begin readiness tracking.'
                          : incompleteAssignments > 0
                          ? '$incompleteAssignments teacher evaluation${incompleteAssignments == 1 ? ' is' : 's are'} still incomplete. Open a student to see whether it is a report blocker.'
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
          _studentReadinessTable(filtered),
      ],
    );
  }

  void _sortReadiness(String column, bool ascending) {
    setState(() {
      _readinessSortColumn = column;
      _readinessSortAscending = ascending;
    });
  }

  Widget _studentReadinessTable(List<Map<String, dynamic>> students) {
    final sortColumnIndex = switch (_readinessSortColumn) {
      'student' => 0,
      'id' => 1,
      'class' => 2,
      'review' => 3,
      'blockers' => 4,
      'readiness' => 5,
      _ => 0,
    };

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              sortColumnIndex: sortColumnIndex,
              sortAscending: _readinessSortAscending,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              headingTextStyle: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .35,
              ),
              dataTextStyle: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
              ),
              columnSpacing: 30,
              horizontalMargin: 20,
              showCheckboxColumn: false,
              columns: [
                DataColumn(
                  label: const Text('STUDENT'),
                  onSort: (_, ascending) =>
                      _sortReadiness('student', ascending),
                ),
                DataColumn(
                  label: const Text('STUDENT ID'),
                  onSort: (_, ascending) => _sortReadiness('id', ascending),
                ),
                DataColumn(
                  label: const Text('CLASS'),
                  onSort: (_, ascending) => _sortReadiness('class', ascending),
                ),
                DataColumn(
                  label: const Text('FINAL REVIEW'),
                  onSort: (_, ascending) => _sortReadiness('review', ascending),
                ),
                DataColumn(
                  label: const Text('MISSING ITEMS'),
                  numeric: true,
                  onSort: (_, ascending) =>
                      _sortReadiness('blockers', ascending),
                ),
                DataColumn(
                  label: const Text('READINESS'),
                  onSort: (_, ascending) =>
                      _sortReadiness('readiness', ascending),
                ),
                const DataColumn(label: Text('ACTION')),
              ],
              rows: students.map(_studentReadinessRow).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _studentReadinessRow(Map<String, dynamic> student) {
    final ready = student['ready'] == true;
    final reviewStatus =
        student['reviewStatus']?.toString().toUpperCase() ?? 'PENDING';
    final blockers = (student['blockers'] as List? ?? const []).length;
    final statusColor = ready
        ? const Color(0xFF047857)
        : const Color(0xFFC2410C);
    final statusBackground = ready
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFF7ED);

    return DataRow(
      key: ValueKey('evaluation-readiness-${student['customStudentId']}'),
      onSelectChanged: (_) => _showReadinessDetail(student),
      cells: [
        DataCell(
          Row(
            key: ValueKey('evaluation-readiness-${student['customStudentId']}'),
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: statusBackground,
                child: Icon(
                  ready ? Icons.check_rounded : Icons.priority_high_rounded,
                  size: 18,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                student['studentName']?.toString() ?? 'Student',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        DataCell(Text(student['customStudentId']?.toString() ?? '—')),
        DataCell(Text(student['streamName']?.toString() ?? 'Unassigned')),
        DataCell(Text(_termEvaluationReviewStatusLabel(reviewStatus))),
        DataCell(
          Text(
            '$blockers',
            style: TextStyle(
              color: blockers == 0 ? const Color(0xFF047857) : statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              ready ? 'Ready' : 'Blocked',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        DataCell(
          TextButton.icon(
            onPressed: () => _showReadinessDetail(student),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('View'),
          ),
        ),
      ],
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
    final noAssignments =
        assignmentRows.isEmpty ||
        blockers.any(
          (blocker) => blocker['title'].toString().toLowerCase().contains(
            'no evaluation assignments',
          ),
        );
    final displayedBlockers = <Map<String, dynamic>>[];
    if (noAssignments) {
      displayedBlockers.add(
        blockers.firstWhere(
          (blocker) => blocker['title'].toString().toLowerCase().contains(
            'no evaluation assignments',
          ),
          orElse: () => {
            'title': 'Teacher evaluations have not been created',
            'message':
                'Assign the class and subject teachers, then refresh the evaluation exercise.',
          },
        ),
      );
    } else {
      final observationBlockers = blockers
          .where(
            (blocker) => blocker['title'].toString().toLowerCase().contains(
              'needs more observations',
            ),
          )
          .toList();
      if (observationBlockers.isNotEmpty) {
        final criteria = observationBlockers
            .map(
              (blocker) => blocker['title'].toString().replaceFirst(
                RegExp(r' needs more observations.*$'),
                '',
              ),
            )
            .join(', ');
        displayedBlockers.add({
          'title':
              '${observationBlockers.length} evaluation criteria need observations',
          'message': 'Still awaiting teacher input for: $criteria.',
        });
      }
      displayedBlockers.addAll(
        blockers.where(
          (blocker) => !blocker['title'].toString().toLowerCase().contains(
            'needs more observations',
          ),
        ),
      );
    }
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
            if (displayedBlockers.isEmpty)
              const Card(
                color: Color(0xFFECFDF5),
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('All evaluation requirements are complete.'),
                ),
              )
            else
              ...displayedBlockers.map(
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
            if (assignmentRows.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.person_add_alt_1_outlined),
                  title: Text('No teacher contributions yet'),
                  subtitle: Text(
                    'Contributions will appear after teacher evaluation records are created.',
                  ),
                ),
              )
            else
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
                          const Chip(label: Text('RATINGS COMPLETE'))
                        else
                          OutlinedButton.icon(
                            onPressed: () =>
                                _remindById(assignment['assignmentId']),
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
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
        'The teacher evaluation could not be found. Refresh and try again.',
      );
      return;
    }
    await _remind(rows.single);
  }

  Future<void> _openAssignment(Map<String, dynamic> summary) async {
    try {
      final assignment = await widget.api.getTermEvaluationAssignment(
        assignmentId: summary['id'],
        schoolId: widget.schoolId,
      );
      if (!mounted) return;
      final next = await Navigator.push<String>(
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
      if (next == 'comments' && mounted) {
        final refreshedRows = (_data?['assignments'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((row) => row['id'] == summary['id'])
            .toList();
        await _review(refreshedRows.isEmpty ? summary : refreshedRows.first);
      }
    } on AssessmentApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _viewAssignment(Map<String, dynamic> summary) async {
    try {
      final assignment = await widget.api.getTermEvaluationAssignment(
        assignmentId: _intValue(summary['id']),
        schoolId: widget.schoolId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AssignmentReadOnlyView(assignment: assignment),
        ),
      );
    } on AssessmentApiException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _review(
    Map<String, dynamic> assignment, {
    bool leadershipReview = false,
  }) async {
    final assignmentRows = (_data?['assignments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where(
          (row) =>
              row['streamId'] == assignment['streamId'] &&
              row['pendingGeneration'] != true,
        )
        .toList();
    final pendingTeacherEvaluations = assignmentRows
        .where((row) => row['status']?.toString() != 'SUBMITTED')
        .length;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ConsolidatedReview(
          api: widget.api,
          schoolId: widget.schoolId,
          termId: widget.setup.termId,
          staffId: assignment['staffId'].toString(),
          canReviewLeadership: leadershipReview && _manager,
          canEditFinalWordings: leadershipReview && _headmaster,
          assignmentId: _intValue(assignment['id']),
          pendingTeacherEvaluations: pendingTeacherEvaluations,
          className: assignment['streamName']?.toString() ?? 'Class',
          teacherName: assignment['staffName']?.toString() ?? '',
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
}

class _ClassEvaluationResultsView extends StatefulWidget {
  const _ClassEvaluationResultsView({
    required this.api,
    required this.schoolId,
    required this.termId,
    required this.className,
    required this.students,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String className;
  final List<Map<String, dynamic>> students;

  @override
  State<_ClassEvaluationResultsView> createState() =>
      _ClassEvaluationResultsViewState();
}

class _ClassEvaluationResultsViewState
    extends State<_ClassEvaluationResultsView> {
  final _search = TextEditingController();
  final _selectedStudents = <String>{};
  late Future<List<Map<String, dynamic>>> _results;
  String _statusFilter = 'All';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _results = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() => Future.wait(
    widget.students.map((student) async {
      final id = student['id']?.toString() ?? '';
      try {
        final review = await widget.api.getTermEvaluationReview(
          studentId: id,
          schoolId: widget.schoolId,
          termId: widget.termId,
        );
        return {...student, 'review': review};
      } on AssessmentApiException catch (error) {
        return {...student, 'loadError': error.message};
      }
    }),
  );

  bool _awaitingApproval(String status) =>
      const {'SUBMITTED', 'FINALIZED'}.contains(status.toUpperCase());

  String _rowStatus(Map<String, dynamic> row) =>
      ((row['review'] as Map?)?['status']?.toString() ?? 'PENDING')
          .toUpperCase();

  bool _matchesStatusFilter(Map<String, dynamic> row) {
    final status = _rowStatus(row);
    return switch (_statusFilter) {
      'Awaiting' => _awaitingApproval(status),
      'Approved' => status == 'APPROVED',
      'Rejected' => status == 'CHANGES_REQUESTED',
      _ => true,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _selectedStudents.clear();
      _results = _load();
    });
    await _results;
  }

  Future<void> _approveStudents(Iterable<String> studentIds) async {
    if (_busy) return;
    final selected = studentIds.toSet().toList()..sort();
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Approve ${selected.length} student${selected.length == 1 ? '' : 's'}?',
        ),
        content: Text(
          'The selected ratings and class-teacher comments for ${widget.className} will be locked. Their evaluation approval requirement will be completed and report readiness will be recalculated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.api.approveTermEvaluationLeadershipReviews(
        schoolId: widget.schoolId,
        termId: widget.termId,
        studentIds: selected,
      );
      await _refresh();
      if (mounted) {
        final approved = (result['approved'] as num?)?.toInt() ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$approved student${approved == 1 ? '' : 's'} approved.',
            ),
          ),
        );
      }
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

  Future<void> _rejectStudent(String studentId, String status) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject ratings and comment?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a clear reason of at least 5 characters.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (_awaitingApproval(status)) {
        await widget.api.startTermEvaluationLeadershipReview(
          studentId: studentId,
          schoolId: widget.schoolId,
          termId: widget.termId,
        );
      }
      await widget.api.requestTermEvaluationChanges(
        studentId: studentId,
        schoolId: widget.schoolId,
        termId: widget.termId,
        reason: reason,
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ratings and comment rejected.')),
        );
      }
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Class ratings & comments approval')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _results,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final allRows = snapshot.data ?? const [];
        final query = _search.text.trim().toLowerCase();
        final rows = allRows.where((row) {
          final text = '${row['name']} ${row['id']}'.toLowerCase();
          return (query.isEmpty || text.contains(query)) &&
              _matchesStatusFilter(row);
        }).toList();
        rows.sort(
          (left, right) => (left['name']?.toString() ?? '').compareTo(
            right['name']?.toString() ?? '',
          ),
        );

        final awaiting = allRows
            .where((row) => _awaitingApproval(_rowStatus(row)))
            .length;
        final approved = allRows
            .where((row) => _rowStatus(row) == 'APPROVED')
            .length;
        final rejected = allRows
            .where((row) => _rowStatus(row) == 'CHANGES_REQUESTED')
            .length;
        final visibleAwaitingIds = rows
            .where((row) => _awaitingApproval(_rowStatus(row)))
            .map((row) => row['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        final selectedVisible = visibleAwaitingIds
            .where(_selectedStudents.contains)
            .length;
        final allVisibleSelected =
            visibleAwaitingIds.isNotEmpty &&
            selectedVisible == visibleAwaitingIds.length;
        final someVisibleSelected = selectedVisible > 0 && !allVisibleSelected;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 14,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.className,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${allRows.length} students · Review ratings and class-teacher comments together, then approve or reject them.',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('approve-selected-class-results'),
                      onPressed: _selectedStudents.isEmpty || _busy
                          ? null
                          : () => _approveStudents(_selectedStudents),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _selectedStudents.isEmpty
                            ? 'Select students to approve'
                            : 'Approve selected (${_selectedStudents.length})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'All',
                          label: Text('All ${allRows.length}'),
                        ),
                        ButtonSegment(
                          value: 'Awaiting',
                          label: Text('Awaiting $awaiting'),
                        ),
                        ButtonSegment(
                          value: 'Approved',
                          label: Text('Approved $approved'),
                        ),
                        ButtonSegment(
                          value: 'Rejected',
                          label: Text('Rejected $rejected'),
                        ),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (selected) => setState(() {
                        _statusFilter = selected.first;
                        _selectedStudents.clear();
                      }),
                    ),
                    SizedBox(
                      width: 330,
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {
                          _selectedStudents.clear();
                        }),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search name or student ID',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ratingLegend(),
                  ],
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text('No students match the selected filters.'),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: constraints.maxWidth < 1100
                              ? 1100
                              : constraints.maxWidth,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                color: const Color(0xFFF8FAFC),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 52,
                                      child: Checkbox(
                                        key: const ValueKey(
                                          'select-all-awaiting-class-results',
                                        ),
                                        tristate: true,
                                        value: someVisibleSelected
                                            ? null
                                            : allVisibleSelected,
                                        onChanged: visibleAwaitingIds.isEmpty
                                            ? null
                                            : (selected) => setState(() {
                                                if (selected == true) {
                                                  _selectedStudents.addAll(
                                                    visibleAwaitingIds,
                                                  );
                                                } else {
                                                  _selectedStudents.removeAll(
                                                    visibleAwaitingIds,
                                                  );
                                                }
                                              }),
                                      ),
                                    ),
                                    const Expanded(
                                      flex: 3,
                                      child: Text('STUDENT'),
                                    ),
                                    const Expanded(
                                      flex: 3,
                                      child: Text('RATINGS'),
                                    ),
                                    const Expanded(
                                      flex: 5,
                                      child: Text("CLASS TEACHER'S COMMENT"),
                                    ),
                                    const Expanded(
                                      flex: 2,
                                      child: Text('STATUS'),
                                    ),
                                    const SizedBox(
                                      width: 190,
                                      child: Text('DECISION'),
                                    ),
                                    const SizedBox(width: 36),
                                  ],
                                ),
                              ),
                              for (
                                var index = 0;
                                index < rows.length;
                                index++
                              ) ...[
                                _studentResultCard(rows[index]),
                                if (index < rows.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _studentResultCard(Map<String, dynamic> row) {
    final review = row['review'] as Map? ?? const {};
    final ratings =
        (review['finalRatings'] as Map?) ??
        (review['calculated'] as Map?) ??
        const {};
    final comment = review['comment']?.toString().trim() ?? '';
    final reviewStatus =
        review['status']?.toString().toUpperCase() ?? 'PENDING';
    final studentId = row['id']?.toString() ?? '';
    final eligible = _awaitingApproval(reviewStatus);
    final canDecide = eligible || reviewStatus == 'UNDER_REVIEW';
    final longComment = comment.length > 150;
    return ExpansionTile(
      key: ValueKey('class-result-$studentId'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(62, 0, 46, 20),
      leading: SizedBox(
        width: 38,
        child: Checkbox(
          key: ValueKey('select-class-result-$studentId'),
          value: _selectedStudents.contains(studentId),
          onChanged: eligible && !_busy
              ? (selected) => setState(() {
                  if (selected == true) {
                    _selectedStudents.add(studentId);
                  } else {
                    _selectedStudents.remove(studentId);
                  }
                })
              : null,
        ),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['name']?.toString() ?? 'Student',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  studentId.isEmpty ? '—' : studentId,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: _criteria.keys
                  .map(
                    (criterion) =>
                        _ratingSummaryBadge(ratings[criterion]?.toString()),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.isEmpty
                        ? 'No class-teacher comment has been added.'
                        : comment,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: comment.isEmpty
                          ? const Color(0xFF64748B)
                          : const Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                  if (longComment) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'Expand to read the full comment',
                      style: TextStyle(
                        color: Color(0xFF087B69),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _classApprovalStatusBadge(reviewStatus),
            ),
          ),
          SizedBox(
            width: 190,
            child: canDecide
                ? Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _rejectStudent(studentId, reviewStatus),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318),
                        ),
                        child: const Text('Reject'),
                      ),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _approveStudents([studentId]),
                        child: const Text('Approve'),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      children: [
        const Divider(height: 1),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Teacher ratings',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 760
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _criteria.entries
                  .map(
                    (criterion) => SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                criterion.value,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            _classRatingBadge(
                              ratings[criterion.key]?.toString(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCCFBF1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Class-teacher comment',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                row['loadError']?.toString() ??
                    (comment.isEmpty
                        ? 'No comment has been added for this student.'
                        : comment),
                style: TextStyle(
                  color: comment.isEmpty
                      ? const Color(0xFF64748B)
                      : const Color(0xFF334155),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratingLegend() => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: const [
      Text('Key:', style: TextStyle(fontWeight: FontWeight.w800)),
      Text('E  Excellent'),
      Text('G  Good'),
      Text('S  Satisfactory'),
      Text('NI  Needs improvement'),
      Text('NO  Not observed'),
    ],
  );

  Widget _classApprovalStatusBadge(String status) {
    final label = _termEvaluationReviewStatusLabel(status);
    final (background, foreground, dot) = switch (status) {
      'APPROVED' => (
        const Color(0xFFE8F6F2),
        const Color(0xFF087B69),
        const Color(0xFF087B69),
      ),
      'CHANGES_REQUESTED' => (
        const Color(0xFFFEF3F2),
        const Color(0xFFB42318),
        const Color(0xFFD92D20),
      ),
      'SUBMITTED' || 'FINALIZED' => (
        const Color(0xFFFFF4D6),
        const Color(0xFF8A5700),
        const Color(0xFFD4900A),
      ),
      'UNDER_REVIEW' => (
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
        const Color(0xFF3B82F6),
      ),
      _ => (
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        const Color(0xFF94A3B8),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingSummaryBadge(String? rating) {
    final value = rating?.trim() ?? '';
    final short = switch (value) {
      'Excellent' => 'E',
      'Good' => 'G',
      'Satisfactory' => 'S',
      'Needs improvement' => 'NI',
      'Not observed' => 'NO',
      _ => '—',
    };
    final (background, foreground) = switch (value) {
      'Needs improvement' => (const Color(0xFFFFF4D6), const Color(0xFF8A5700)),
      'Not observed' => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
      '' => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
      _ => (const Color(0xFFE8F6F2), const Color(0xFF087B69)),
    };
    return Tooltip(
      message: value.isEmpty ? 'Pending' : value,
      child: Container(
        constraints: const BoxConstraints(minWidth: 28),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          short,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _classRatingBadge(String? rating) {
    final text = rating?.trim().isNotEmpty == true ? rating! : 'Pending';
    final pending = text == 'Pending' || text == 'Incomplete';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: pending ? const Color(0xFFC2410C) : const Color(0xFF047857),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AssignmentReadOnlyView extends StatefulWidget {
  const _AssignmentReadOnlyView({required this.assignment});

  final Map<String, dynamic> assignment;

  @override
  State<_AssignmentReadOnlyView> createState() =>
      _AssignmentReadOnlyViewState();
}

class _AssignmentReadOnlyViewState extends State<_AssignmentReadOnlyView> {
  final _search = TextEditingController();
  final _ratingsScroll = ScrollController();
  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  List<Map<String, dynamic>> get _students =>
      (widget.assignment['students'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (student) =>
                student.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();

  Map<String, Map<String, String>> get _ratings {
    final saved = widget.assignment['ratings'] as Map? ?? const {};
    return {
      for (final entry in saved.entries)
        entry.key.toString(): {
          if (entry.value is Map)
            for (final rating in (entry.value as Map).entries)
              rating.key.toString(): rating.value?.toString() ?? '—',
        },
    };
  }

  @override
  void dispose() {
    _search.dispose();
    _ratingsScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final ratings = _ratings;
    final students = _students.where((student) {
      final text = '${student['name']} ${student['id']}'.toLowerCase();
      return query.isEmpty || text.contains(query);
    }).toList();
    students.sort((left, right) {
      String value(Map<String, dynamic> student) {
        if (_sortColumnIndex == 0) {
          return student['name']?.toString().toLowerCase() ?? '';
        }
        if (_sortColumnIndex == 1) {
          return student['id']?.toString().toLowerCase() ?? '';
        }
        final criterion = _criteria.keys.elementAt(_sortColumnIndex - 2);
        return ratings[student['id']?.toString()]?[criterion]?.toLowerCase() ??
            '';
      }

      final result = value(left).compareTo(value(right));
      return _sortAscending ? result : -result;
    });

    final teacher = widget.assignment['staffName']?.toString() ?? 'Teacher';
    final subject =
        widget.assignment['subjectName']?.toString() ?? 'Evaluation';
    final className =
        widget.assignment['streamName']?.toString() ?? 'Unassigned class';

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher evaluation')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.fact_check_outlined),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$teacher · $subject',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$className · ${students.length} students',
                          style: const TextStyle(color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  const Chip(
                    avatar: Icon(Icons.lock_outline, size: 16),
                    label: Text('READ ONLY'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search student name or ID',
                ),
              ),
              const SizedBox(height: 14),
              Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (MediaQuery.sizeOf(context).width < 900) {
                      return Column(
                        children: students
                            .map(
                              (student) => _studentRatingCard(student, ratings),
                            )
                            .toList(),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                          alignment: Alignment.centerRight,
                          child: const Text(
                            'Scroll ratings to view all criteria  →',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 335,
                              child: DataTable(
                                sortColumnIndex: _sortColumnIndex < 2
                                    ? _sortColumnIndex
                                    : null,
                                sortAscending: _sortAscending,
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF8FAFC),
                                ),
                                headingTextStyle: _tableHeadingStyle,
                                horizontalMargin: 18,
                                columnSpacing: 22,
                                columns: [
                                  _column('STUDENT', 0),
                                  _column('STUDENT ID', 1),
                                ],
                                rows: students
                                    .map(
                                      (student) => DataRow(
                                        cells: [
                                          DataCell(
                                            SizedBox(
                                              width: 120,
                                              child: Text(
                                                student['name']?.toString() ??
                                                    'Student',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            SizedBox(
                                              width: 135,
                                              child: Text(
                                                student['id']?.toString() ?? '',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 56.0 * (students.length + 1),
                              color: const Color(0xFFE2E8F0),
                            ),
                            Expanded(
                              child: Scrollbar(
                                controller: _ratingsScroll,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _ratingsScroll,
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    sortColumnIndex: _sortColumnIndex >= 2
                                        ? _sortColumnIndex - 2
                                        : null,
                                    sortAscending: _sortAscending,
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF8FAFC),
                                    ),
                                    headingTextStyle: _tableHeadingStyle,
                                    horizontalMargin: 18,
                                    columnSpacing: 34,
                                    columns: [
                                      for (
                                        var index = 0;
                                        index < _criteria.length;
                                        index++
                                      )
                                        _column(
                                          _criteria.values
                                              .elementAt(index)
                                              .toUpperCase(),
                                          index + 2,
                                        ),
                                    ],
                                    rows: students.map((student) {
                                      final id =
                                          student['id']?.toString() ?? '';
                                      final studentRatings =
                                          ratings[id] ?? const {};
                                      return DataRow(
                                        cells: [
                                          for (final criterion
                                              in _criteria.keys)
                                            DataCell(
                                              _ratingBadge(
                                                studentRatings[criterion] ??
                                                    'Not rated',
                                              ),
                                            ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
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
    );
  }

  DataColumn _column(String label, int index) => DataColumn(
    label: Text(label),
    onSort: (_, ascending) => setState(() {
      _sortColumnIndex = index;
      _sortAscending = ascending;
    }),
  );

  TextStyle get _tableHeadingStyle => const TextStyle(
    color: Color(0xFF475569),
    fontSize: 12,
    fontWeight: FontWeight.w800,
  );

  Widget _studentRatingCard(
    Map<String, dynamic> student,
    Map<String, Map<String, String>> ratings,
  ) {
    final id = student['id']?.toString() ?? '';
    final studentRatings = ratings[id] ?? const {};
    return ExpansionTile(
      leading: CircleAvatar(
        child: Text(
          (student['name']?.toString().trim().isNotEmpty ?? false)
              ? student['name'].toString().trim()[0].toUpperCase()
              : '?',
        ),
      ),
      title: Text(
        student['name']?.toString() ?? 'Student',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(id),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              for (final criterion in _criteria.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(child: Text(criterion.value)),
                      _ratingBadge(
                        studentRatings[criterion.key] ?? 'Not rated',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratingBadge(String rating) {
    final observed = rating != 'Not observed' && rating != 'Not rated';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: observed ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rating,
        style: TextStyle(
          color: observed ? const Color(0xFF047857) : const Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
  bool _submitted = false;
  bool _reopened = false;
  bool _hasSavedRatings = false;

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
    _submitted = widget.assignment['status'] == 'SUBMITTED';
    _reopened = widget.assignment['reopenedAt'] != null;
    _hasSavedRatings = saved.isNotEmpty;
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
      setState(() {
        _hasSavedRatings = true;
        _saveState = _submitted
            ? 'Update saved just now'
            : 'Draft saved just now';
      });
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

  Future<void> _finishSubmittedUpdate() async {
    _saveTimer?.cancel();
    if (await _saveDraft() && mounted) Navigator.pop(context);
  }

  Future<void> _submit({bool isUpdate = false}) async {
    if (!_complete) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isUpdate
              ? 'Resubmit evaluation update?'
              : 'Submit evaluations for review?',
        ),
        content: Text(
          isUpdate
              ? 'Your updated ratings will replace the previous submission and remain editable until leadership starts reviewing an affected student.'
              : 'I have reviewed these evaluations and confirm that they reflect my observations of these students. You may continue editing until leadership starts review for an affected student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isUpdate ? 'Resubmit update' : 'Submit for review'),
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
      if (!mounted) return;
      if (!isUpdate &&
          widget.assignment['assignmentType']?.toString() == 'CLASS_TEACHER') {
        final continueToComments = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF087B69),
            ),
            title: const Text('Teacher ratings complete'),
            content: const Text(
              'Next, add a final class-teacher comment for each student.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back to evaluations'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to student comments'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.pop(
            context,
            continueToComments == true ? 'comments' : null,
          );
        }
      } else {
        Navigator.pop(context);
      }
    } on AssessmentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _clearAllResponses() async {
    if (_busy || !_hasSavedRatings) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
        title: const Text('Clear all evaluation responses?'),
        content: const Text(
          'This removes every rating for every student in this evaluation. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear responses'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _saveTimer?.cancel();
    setState(() => _busy = true);
    try {
      await widget.api.clearTermEvaluationAssignment(
        assignmentId: widget.assignment['id'],
        schoolId: widget.schoolId,
      );
      if (!mounted) return;
      setState(() {
        for (final ratings in _values.values) {
          for (final criterion in _criteria.keys) {
            ratings[criterion] = null;
          }
        }
        _submitted = false;
        _reopened = false;
        _hasSavedRatings = false;
        _step = 0;
        _saveState = 'All responses cleared';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All evaluation responses were cleared.')),
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
          if (_hasSavedRatings)
            PopupMenuButton<String>(
              tooltip: 'Evaluation actions',
              enabled: !_busy,
              onSelected: (value) {
                if (value == 'clear') _clearAllResponses();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, color: Colors.red),
                      SizedBox(width: 10),
                      Text(
                        'Clear responses',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
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
        ],
      ),
      bottomNavigationBar: _navigation(review),
    );
  }

  Widget _progressHeader(
    bool review,
    MapEntry<String, String>? criterion,
  ) => Container(
    width: double.infinity,
    color: const Color(0xFFF4FAF8),
    child: Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (_step + 1) / (_criteria.length + 1),
                minHeight: 6,
              ),
              const SizedBox(height: 12),
              _stepNavigator(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _stepNavigator() {
    final steps = <String>[
      for (var index = 0; index < _criteria.length; index++) '${index + 1}',
      'Review',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(steps.length, (index) {
          final selected = _step == index;
          final tooltip = index < _criteria.length
              ? 'Question ${index + 1}: ${_criteria.values.elementAt(index)}'
              : 'Final review';
          return Padding(
            padding: EdgeInsets.only(right: index == steps.length - 1 ? 0 : 8),
            child: Tooltip(
              message: tooltip,
              child: InkWell(
                key: ValueKey('evaluation-step-$index'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _step = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 34,
                  constraints: BoxConstraints(
                    minWidth: index == steps.length - 1 ? 72 : 34,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF087B69) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF087B69)
                          : const Color(0xFFCAD8D5),
                    ),
                  ),
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF47625D),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

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

  Widget _reviewStep() => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
                missing.isEmpty
                    ? Icons.check_circle
                    : Icons.warning_amber_rounded,
                color: missing.isEmpty ? Colors.green : Colors.orange,
              ),
              title: Text(student['name'].toString()),
              subtitle: Text(
                missing.isEmpty
                    ? 'All criteria completed'
                    : '${missing.length} criteria missing',
              ),
              children: _criteria.entries.map((criterion) {
                final rating = values[criterion.key] ?? 'Unrated';
                return InkWell(
                  onTap: () => setState(
                    () =>
                        _step = _criteria.keys.toList().indexOf(criterion.key),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            criterion.value,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 24),
                        SizedBox(
                          width: 150,
                          child: Text(
                            rating,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: rating == 'Unrated'
                                  ? Colors.orange.shade800
                                  : const Color(0xFF344A47),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    ),
  );

  Widget _navigation(bool review) => SafeArea(
    top: false,
    child: Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x220F172A),
      child: Align(
        alignment: Alignment.center,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final editingExisting = _submitted || _reopened;
                final updateLabel = _submitted
                    ? 'Save update'
                    : 'Resubmit update';
                final updateIcon = _submitted
                    ? Icons.save_outlined
                    : Icons.refresh_rounded;
                final VoidCallback? updateAction = _busy
                    ? null
                    : _submitted
                    ? _finishSubmittedUpdate
                    : _complete
                    ? () => _submit(isUpdate: true)
                    : null;
                final primary = FilledButton.icon(
                  key: review
                      ? const ValueKey('submit-term-evaluations')
                      : null,
                  onPressed: review
                      ? (editingExisting
                            ? updateAction
                            : (_complete && !_busy ? () => _submit() : null))
                      : () => setState(() => _step++),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  icon: Icon(
                    review && editingExisting
                        ? updateIcon
                        : review
                        ? Icons.send_outlined
                        : Icons.arrow_forward,
                  ),
                  label: Text(
                    review && editingExisting
                        ? updateLabel
                        : review
                        ? 'Submit for review'
                        : (_step + 1 == _criteria.length
                              ? 'Review'
                              : 'Next criterion'),
                  ),
                );
                final quickUpdate = !review && editingExisting
                    ? FilledButton.tonalIcon(
                        key: ValueKey(
                          _submitted
                              ? 'save-evaluation-update'
                              : 'resubmit-evaluation-update',
                        ),
                        onPressed: updateAction,
                        icon: Icon(updateIcon, size: 18),
                        label: Text(updateLabel),
                      )
                    : null;
                final secondary = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _step == 0
                          ? null
                          : () => setState(() => _step--),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _saveDraft(announce: true),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(_submitted ? 'Save changes' : 'Save draft'),
                    ),
                  ],
                );
                if (compact) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      secondary,
                      if (quickUpdate != null) ...[
                        const SizedBox(height: 8),
                        quickUpdate,
                      ],
                      const SizedBox(height: 8),
                      primary,
                    ],
                  );
                }
                return Row(
                  children: [
                    secondary,
                    const Spacer(),
                    if (quickUpdate != null) ...[
                      quickUpdate,
                      const SizedBox(width: 8),
                    ],
                    primary,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _ConsolidatedReview extends StatefulWidget {
  const _ConsolidatedReview({
    required this.api,
    required this.schoolId,
    required this.termId,
    required this.staffId,
    required this.canReviewLeadership,
    required this.canEditFinalWordings,
    required this.assignmentId,
    required this.pendingTeacherEvaluations,
    required this.className,
    required this.teacherName,
    required this.students,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String staffId;
  final bool canReviewLeadership;
  final bool canEditFinalWordings;
  final int assignmentId;
  final int pendingTeacherEvaluations;
  final String className;
  final String teacherName;
  final List<Map<String, dynamic>> students;

  @override
  State<_ConsolidatedReview> createState() => _ConsolidatedReviewState();
}

class _ConsolidatedReviewState extends State<_ConsolidatedReview> {
  final _search = TextEditingController();
  final _reviewStatuses = <String, String>{};
  final _reviews = <String, Map<String, dynamic>>{};
  final _selectedStudents = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadReviewStatuses();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadReviewStatuses() async {
    final loaded = await Future.wait(
      widget.students.map((student) async {
        final studentId = student['id'].toString();
        try {
          final review = await widget.api.getTermEvaluationReview(
            studentId: studentId,
            schoolId: widget.schoolId,
            termId: widget.termId,
          );
          return MapEntry(studentId, review);
        } on AssessmentApiException {
          return MapEntry<String, Map<String, dynamic>>(studentId, const {
            'status': 'PENDING',
          });
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _reviews
        ..clear()
        ..addEntries(loaded);
      _reviewStatuses
        ..clear()
        ..addEntries(
          loaded.map(
            (entry) => MapEntry(
              entry.key,
              entry.value['status']?.toString().toUpperCase() ?? 'PENDING',
            ),
          ),
        );
      _selectedStudents.removeWhere(
        (id) => !_leadershipEligible(_reviewStatuses[id]),
      );
    });
  }

  Future<void> _openStudent(Map<String, dynamic> student) async {
    var index = widget.students.indexWhere(
      (value) => value['id']?.toString() == student['id']?.toString(),
    );
    if (index < 0) return;
    final navigator = Navigator.of(context);
    while (mounted && index < widget.students.length) {
      final moveNext = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => _StudentFinalReview(
            api: widget.api,
            schoolId: widget.schoolId,
            termId: widget.termId,
            staffId: widget.staffId,
            canReviewLeadership: widget.canReviewLeadership,
            canEditFinalWordings: widget.canEditFinalWordings,
            hasNextStudent:
                !widget.canReviewLeadership &&
                index < widget.students.length - 1,
            student: widget.students[index],
          ),
        ),
      );
      if (!mounted) return;
      await _loadReviewStatuses();
      if (moveNext != true || widget.canReviewLeadership) return;
      index++;
    }
  }

  bool _leadershipEligible(String? status) => const {
    'SUBMITTED',
    'FINALIZED',
    'UNDER_REVIEW',
  }.contains(status?.toUpperCase());

  int get _commentsCompleted => widget.students.where((student) {
    final id = student['id'].toString();
    final comment = _reviews[id]?['comment']?.toString().trim();
    return comment?.isNotEmpty == true &&
        _reviewStatuses[id] != 'CHANGES_REQUESTED';
  }).length;

  int get _commentsSent => _reviewStatuses.values.where((status) {
    return const {
      'SUBMITTED',
      'FINALIZED',
      'UNDER_REVIEW',
      'APPROVED',
    }.contains(status);
  }).length;

  int get _pendingTeacherEvaluations {
    var pending = widget.pendingTeacherEvaluations;
    for (final review in _reviews.values) {
      final value = (review['pendingTeacherEvaluations'] as num?)?.toInt() ?? 0;
      if (value > pending) pending = value;
    }
    return pending;
  }

  Future<void> _submitClassEvaluation() async {
    if (_busy || _commentsCompleted != widget.students.length) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit class evaluation for approval?'),
        content: Text(
          'All ${widget.students.length} student ratings and comments will be submitted to leadership for approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_outlined),
            label: const Text('Submit for approval'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.submitTermEvaluationClassComments(
        assignmentId: widget.assignmentId,
        schoolId: widget.schoolId,
      );
      await _loadReviewStatuses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class evaluation submitted for approval.'),
          ),
        );
      }
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

  Future<void> _approveSelected() async {
    if (_busy || _selectedStudents.isEmpty) return;
    final selected = _selectedStudents.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Approve ${selected.length} student evaluation${selected.length == 1 ? '' : 's'}?',
        ),
        content: const Text(
          'Only complete evaluations that are ready or already under review will be approved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve selected'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.api.approveTermEvaluationLeadershipReviews(
        schoolId: widget.schoolId,
        termId: widget.termId,
        studentIds: selected,
      );
      await _loadReviewStatuses();
      if (mounted) {
        final approved = (result['approved'] as num?)?.toInt() ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$approved student evaluations approved.')),
        );
      }
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

  String get _leadershipStageStatus {
    if (_reviewStatuses.values.isNotEmpty &&
        _reviewStatuses.values.every((status) => status == 'APPROVED')) {
      return 'Approved';
    }
    if (_reviewStatuses.values.any((status) => status == 'UNDER_REVIEW')) {
      return 'Under review';
    }
    if (_reviewStatuses.values.any((status) => status == 'CHANGES_REQUESTED')) {
      return 'Rejected';
    }
    if (_commentsSent == widget.students.length && widget.students.isNotEmpty) {
      return 'Awaiting approval';
    }
    return 'Not ready';
  }

  Map<String, dynamic>? get _nextStudentForComment {
    for (final student in widget.students) {
      final id = student['id'].toString();
      final comment = _reviews[id]?['comment']?.toString().trim();
      if (comment?.isNotEmpty != true ||
          _reviewStatuses[id] == 'CHANGES_REQUESTED') {
        return student;
      }
    }
    return null;
  }

  Widget _workflowOverview() {
    final ratingsComplete = _pendingTeacherEvaluations == 0;
    final commentsComplete =
        _commentsCompleted == widget.students.length &&
        widget.students.isNotEmpty;
    final leadershipComplete = _leadershipStageStatus == 'Approved';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stages = [
              _workflowStage(
                number: 1,
                title: 'Teacher ratings',
                status: ratingsComplete
                    ? 'Complete'
                    : '$_pendingTeacherEvaluations remaining',
                complete: ratingsComplete,
              ),
              _workflowStage(
                number: 2,
                title: 'Student comments',
                status:
                    '$_commentsCompleted of ${widget.students.length} completed',
                complete: commentsComplete,
              ),
              _workflowStage(
                number: 3,
                title: 'Leadership review',
                status: _leadershipStageStatus,
                complete: leadershipComplete,
              ),
            ];
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  for (var index = 0; index < stages.length; index++) ...[
                    stages[index],
                    if (index < stages.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.blueGrey,
                          size: 18,
                        ),
                      ),
                  ],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: stages[0]),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                Expanded(child: stages[1]),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.blueGrey,
                  ),
                ),
                Expanded(child: stages[2]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _workflowStage({
    required int number,
    required String title,
    required String status,
    required bool complete,
  }) => Row(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: complete
            ? const Color(0xFF087B69)
            : const Color(0xFFE2E8F0),
        child: complete
            ? const Icon(Icons.check, color: Colors.white, size: 19)
            : Text(
                '$number',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              status,
              style: TextStyle(
                color: complete ? const Color(0xFF087B69) : Colors.blueGrey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _nextActionCard() {
    if (widget.canReviewLeadership) {
      final eligible = _reviewStatuses.values.where(_leadershipEligible).length;
      return _actionBanner(
        title: eligible > 0 ? 'Awaiting approval' : 'No action needed',
        detail: eligible > 0
            ? '$eligible student evaluation${eligible == 1 ? ' is' : 's are'} ready. Open one to review it or select several below for approval.'
            : 'There are no student evaluations awaiting approval in this class.',
      );
    }
    if (_pendingTeacherEvaluations > 0) {
      return _actionBanner(
        warning: true,
        title: 'Waiting for teacher evaluations',
        detail:
            'Waiting for $_pendingTeacherEvaluations teacher evaluation${_pendingTeacherEvaluations == 1 ? '' : 's'} before student comments can be finalized.',
      );
    }
    final nextStudent = _nextStudentForComment;
    if (nextStudent != null) {
      return _actionBanner(
        title: 'Next action',
        detail:
            'Ratings are complete. Add a final class-teacher comment for each student.',
        action: FilledButton.icon(
          onPressed: _busy ? null : () => _openStudent(nextStudent),
          icon: const Icon(Icons.arrow_forward),
          label: Text(
            _commentsCompleted == 0
                ? 'Continue to student comments'
                : 'Continue student comments',
          ),
        ),
      );
    }
    if (_commentsSent < widget.students.length) {
      return _actionBanner(
        title: 'Student comments complete',
        detail:
            'Every student has final ratings and a class-teacher comment. Submit the class evaluation for approval when ready.',
        action: FilledButton.icon(
          key: const ValueKey('submit-class-evaluation'),
          onPressed: _busy ? null : _submitClassEvaluation,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Submit for approval'),
        ),
      );
    }
    return _actionBanner(
      title: 'Awaiting approval',
      detail:
          'All student ratings and comments were submitted for approval. They remain editable until leadership starts review.',
    );
  }

  Widget _actionBanner({
    required String title,
    required String detail,
    bool warning = false,
    Widget? action,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDFA),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: warning ? const Color(0xFFFED7AA) : const Color(0xFF99F6E4),
      ),
    ),
    child: Wrap(
      spacing: 18,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(detail),
            ],
          ),
        ),
        if (action != null) action,
      ],
    ),
  );

  Widget _leadershipBulkActions() {
    final eligible = widget.students.where(
      (student) =>
          _leadershipEligible(_reviewStatuses[student['id'].toString()]),
    );
    final eligibleIds = eligible
        .map((student) => student['id'].toString())
        .toSet();
    final allSelected =
        eligibleIds.isNotEmpty && _selectedStudents.containsAll(eligibleIds);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Checkbox(
            value: allSelected,
            onChanged: eligibleIds.isEmpty
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _selectedStudents.addAll(eligibleIds);
                    } else {
                      _selectedStudents.removeAll(eligibleIds);
                    }
                  }),
          ),
          Text(
            'Select all eligible (${eligibleIds.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (_selectedStudents.isNotEmpty)
            FilledButton.icon(
              key: const ValueKey('approve-selected-evaluations'),
              onPressed: _busy ? null : _approveSelected,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Approve selected (${_selectedStudents.length})'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = widget.students.where((student) {
      if (query.isEmpty) return true;
      return student['name'].toString().toLowerCase().contains(query) ||
          student['id'].toString().toLowerCase().contains(query);
    }).toList();
    final title = widget.canReviewLeadership
        ? 'Leadership evaluation review'
        : 'Student comments';
    final compact = MediaQuery.sizeOf(context).width < 800;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: compact ? 56 : 190,
        leading: compact
            ? IconButton(
                tooltip: 'Back to evaluations and comments',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              )
            : TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, size: 19),
                label: const Text('Back to evaluations & comments'),
              ),
        title: Text(title),
        centerTitle: true,
        actions: compact
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Center(
                    child: Text(
                      '${widget.className} · ${widget.students.length} students',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                children: [
                  _workflowOverview(),
                  const SizedBox(height: 14),
                  _nextActionCard(),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF163B3A), Color(0xFF2F9487)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 18,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 650),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.className,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.canReviewLeadership
                                    ? 'Review the submitted ratings and class-teacher comment for each student.'
                                    : 'Add and save one final report-card comment for each student.',
                                style: const TextStyle(
                                  color: Color(0xFFDDF4F0),
                                  height: 1.35,
                                ),
                              ),
                              if (widget.teacherName.trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Class teacher: ${widget.teacherName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.students.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Students',
                                style: TextStyle(color: Color(0xFFDDF4F0)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.canReviewLeadership
                                          ? 'Leadership review queue'
                                          : 'Student comments',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      widget.canReviewLeadership
                                          ? 'Review students individually or select several for approval.'
                                          : 'Add or edit each student’s final class-teacher comment.',
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 290,
                                child: TextField(
                                  controller: _search,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search students...',
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.canReviewLeadership)
                          _leadershipBulkActions(),
                        const Divider(height: 1),
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No students match your search.'),
                          )
                        else
                          for (
                            var index = 0;
                            index < filtered.length;
                            index++
                          ) ...[
                            _studentRow(filtered[index]),
                            if (index < filtered.length - 1)
                              const Divider(height: 1, indent: 72),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRow(Map<String, dynamic> student) {
    final name = student['name'].toString();
    final studentId = student['id'].toString();
    final status = _reviewStatuses[studentId];
    final comment = _reviews[studentId]?['comment']?.toString().trim() ?? '';
    final eligible = _leadershipEligible(status);
    final locked = status == 'UNDER_REVIEW' || status == 'APPROVED';
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return InkWell(
      onTap: () => _openStudent(student),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (widget.canReviewLeadership) ...[
              Checkbox(
                value: _selectedStudents.contains(studentId),
                onChanged: eligible
                    ? (selected) => setState(() {
                        if (selected == true) {
                          _selectedStudents.add(studentId);
                        } else {
                          _selectedStudents.remove(studentId);
                        }
                      })
                    : null,
              ),
              const SizedBox(width: 6),
            ],
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE4F5F2),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Color(0xFF16766B),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student['id'].toString(),
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            _reviewStatusBadge(status),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () => _openStudent(student),
              icon: Icon(
                widget.canReviewLeadership
                    ? Icons.rate_review_outlined
                    : locked
                    ? Icons.visibility_outlined
                    : comment.isEmpty
                    ? Icons.add_comment_outlined
                    : Icons.edit_note_outlined,
                size: 18,
              ),
              label: Text(
                widget.canReviewLeadership
                    ? 'Review'
                    : locked
                    ? 'View'
                    : comment.isEmpty
                    ? 'Add comment'
                    : 'Edit comment',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStatusBadge(String? status) {
    if (status == null) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final normalized = status.toUpperCase();
    final approved = normalized == 'APPROVED';
    final inProgress = const {
      'IN_PROGRESS',
      'DRAFT',
      'COMMENTS_IN_PROGRESS',
      'SUBMITTED',
      'UNDER_REVIEW',
      'CHANGES_REQUESTED',
    }.contains(normalized);
    final label = !widget.canReviewLeadership && normalized == 'PENDING'
        ? 'Missing'
        : _termEvaluationReviewStatusLabel(normalized);
    final foreground = approved
        ? const Color(0xFF16766B)
        : inProgress
        ? const Color(0xFF9A5B08)
        : Colors.blueGrey;
    final background = approved
        ? const Color(0xFFE4F5F2)
        : inProgress
        ? const Color(0xFFFFF4D8)
        : const Color(0xFFF1F5F9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StudentFinalReview extends StatefulWidget {
  const _StudentFinalReview({
    required this.api,
    required this.schoolId,
    required this.termId,
    required this.staffId,
    required this.canReviewLeadership,
    required this.canEditFinalWordings,
    required this.hasNextStudent,
    required this.student,
  });

  final AssessmentApiClient api;
  final String schoolId;
  final int termId;
  final String staffId;
  final bool canReviewLeadership;
  final bool canEditFinalWordings;
  final bool hasNextStudent;
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
  String? _leadershipReviewer;
  String? _leadershipDecisionNote;

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
        _leadershipReviewer = data['leadershipReviewer']?.toString();
        _leadershipDecisionNote = data['leadershipDecisionNote']?.toString();
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
      if (!widget.canReviewLeadership) {
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

  Future<void> _saveCommentAndContinue() async {
    final comment = _comment.text.trim();
    if (comment.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.saveTermEvaluationComment(
        studentId: widget.student['id'].toString(),
        schoolId: widget.schoolId,
        termId: widget.termId,
        comment: comment,
      );
      if (!mounted) return;
      Navigator.pop(context, widget.hasNextStudent);
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

  Future<String?> _rejectionReason() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject evaluation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _startLeadershipReview() async {
    setState(() => _busy = true);
    try {
      await widget.api.startTermEvaluationLeadershipReview(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
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

  Future<void> _approveLeadershipReview() async {
    setState(() => _busy = true);
    try {
      await widget.api.approveTermEvaluationLeadershipReview(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evaluation approved for report generation.'),
          ),
        );
      }
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

  Future<void> _rejectLeadershipReview() async {
    final reason = await _rejectionReason();
    if (reason == null || !mounted) return;
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a clear reason of at least 5 characters.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.requestTermEvaluationChanges(
        studentId: widget.student['id'],
        schoolId: widget.schoolId,
        termId: widget.termId,
        reason: reason,
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
    final lockedForReview = _status == 'UNDER_REVIEW' || _status == 'APPROVED';
    final submitted = _status == 'SUBMITTED';
    final differsFromCalculated = _criteria.keys
        .where((criterion) => _final[criterion] != _calculated[criterion])
        .length;
    final edited = _criteria.keys
        .where((criterion) => _final[criterion] != _originalFinal[criterion])
        .length;
    final summaryMessage = !complete
        ? 'Teacher submissions are incomplete. This student cannot be finalized yet.'
        : widget.canReviewLeadership
        ? switch (_status) {
            'SUBMITTED' =>
              'The class teacher submitted the final comment. Start review to lock this student’s evaluation and make a decision.',
            'UNDER_REVIEW' =>
              'Review the submitted ratings and class-teacher comment. Only the headmaster can correct the final rating wording.',
            'APPROVED' =>
              'This evaluation is approved and ready for report generation.',
            'CHANGES_REQUESTED' =>
              'This evaluation was rejected and returned to the class teacher.',
            _ =>
              'The class teacher must add the final comment and submit this evaluation before leadership can review it.',
          }
        : lockedForReview
        ? 'Leadership is reviewing this submitted evaluation.'
        : switch (_status) {
            'SUBMITTED' || 'FINALIZED' =>
              'This student is awaiting approval. The comment remains editable until leadership starts review.',
            'COMMENTS_IN_PROGRESS' =>
              'The student comment is saved. Continue with the remaining students.',
            'CHANGES_REQUESTED' =>
              'Leadership rejected this evaluation. Update the student comment and save it again.',
            _ =>
              'Review the combined teacher ratings and add the student’s final class-teacher comment.',
          };
    return Scaffold(
      appBar: AppBar(title: Text(widget.student['name'].toString())),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(child: Text(summaryMessage)),
                      Chip(
                        label: Text(_termEvaluationReviewStatusLabel(_status)),
                      ),
                    ],
                  ),
                ),
              ),
              if (_status == 'CHANGES_REQUESTED' &&
                  (_leadershipDecisionNote?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFFFFF7ED),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.assignment_return_outlined,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Rejected${_leadershipReviewer == null ? '' : ' by $_leadershipReviewer'}\n$_leadershipDecisionNote',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_status == 'UNDER_REVIEW' &&
                  (_leadershipReviewer?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: 12),
                Text(
                  'Assigned reviewer: $_leadershipReviewer',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
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
                      child: widget.canEditFinalWordings && lockedForReview
                          ? DropdownButtonFormField<String>(
                              key: ValueKey(
                                'headmaster-wording-${criterion.key}',
                              ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!widget.canReviewLeadership)
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                key: const ValueKey(
                                  'use-evaluation-suggestion',
                                ),
                                onPressed: lockedForReview
                                    ? null
                                    : _useSuggestion,
                                icon: const Icon(Icons.check),
                                label: const Text('Use suggestion'),
                              ),
                              TextButton.icon(
                                key: const ValueKey(
                                  'try-another-evaluation-suggestion',
                                ),
                                onPressed: lockedForReview || _suggestionLoading
                                    ? null
                                    : _tryAnotherSuggestion,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try another'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            lockedForReview
                                ? 'This suggestion is informational while leadership review is in progress.'
                                : 'Review and edit the wording before submitting. The suggestion is never saved automatically.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (!widget.canReviewLeadership) const SizedBox(height: 12),
              TextField(
                key: const ValueKey('evaluation-final-comment'),
                controller: _comment,
                readOnly: lockedForReview || widget.canReviewLeadership,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Final class-teacher comment',
                  hintText:
                      'Comment that will accompany the finalized evaluation',
                ),
              ),
              const SizedBox(height: 12),
              if (widget.canEditFinalWordings &&
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
              if (widget.canReviewLeadership)
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (submitted)
                      FilledButton.icon(
                        onPressed: _busy ? null : _startLeadershipReview,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Start review'),
                      ),
                    if (_status == 'UNDER_REVIEW') ...[
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _rejectLeadershipReview,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _approveLeadershipReview,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approve'),
                      ),
                    ],
                    if (_status == 'APPROVED')
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _rejectLeadershipReview,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
                      ),
                    if (widget.canEditFinalWordings &&
                        lockedForReview &&
                        edited > 0)
                      FilledButton.icon(
                        key: const ValueKey('save-headmaster-wordings'),
                        onPressed: !_busy ? _saveManagerChanges : null,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Save wording changes'),
                      ),
                  ],
                )
              else if (lockedForReview)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Leadership review has started. The evaluation is locked until it is approved or returned for changes.',
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!widget.canReviewLeadership)
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    key: const ValueKey('save-student-comment'),
                    onPressed:
                        complete && !_busy && _comment.text.trim().isNotEmpty
                        ? _saveCommentAndContinue
                        : null,
                    icon: Icon(
                      widget.hasNextStudent
                          ? Icons.arrow_forward
                          : Icons.save_outlined,
                    ),
                    label: Text(
                      widget.hasNextStudent
                          ? 'Save and next student'
                          : 'Save comment',
                    ),
                  ),
                ),
              if (widget.canEditFinalWordings && _audit.isNotEmpty) ...[
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
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
        ),
      ),
    );
  }
}
