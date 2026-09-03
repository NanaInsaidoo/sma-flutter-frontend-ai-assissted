import 'package:flutter/material.dart';
import '../data/admissions_api_client.dart';

String recordFieldLabel(String value) => value
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    )
    .replaceAll('_', ' ');

String recordValueText(Object? value) {
  if (value == null || value == '') return 'Not recorded';
  if (value is List) {
    return value.isEmpty ? 'None' : value.map(recordValueText).join('\n');
  }
  if (value is Map) {
    final name =
        value['name'] ?? value['conditionName'] ?? value['vaccinationName'];
    if (name != null && value.length <= 5) return '$name';
    return value.entries
        .where((entry) => entry.key != 'navigation')
        .map(
          (entry) =>
              '${recordFieldLabel('${entry.key}')}: ${recordValueText(entry.value)}',
        )
        .join('\n');
  }
  return '$value';
}

Future<String?> requestStudentChangeReason(
  BuildContext context,
  String title,
) => showDialog<String>(
  context: context,
  builder: (_) => _StudentChangeReasonDialog(title: title),
);

class _StudentChangeReasonDialog extends StatefulWidget {
  const _StudentChangeReasonDialog({required this.title});
  final String title;

  @override
  State<_StudentChangeReasonDialog> createState() =>
      _StudentChangeReasonDialogState();
}

class _StudentChangeReasonDialogState
    extends State<_StudentChangeReasonDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    // The closing dialog still uses this controller during its exit animation.
    // Dispose with its widget, not as soon as Navigator.pop returns a result.
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: TextField(
        controller: controller,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 1000,
        decoration: const InputDecoration(
          labelText: 'Reason for this change',
          helperText: 'Recorded in the audit trail.',
        ),
        onChanged: (_) => setState(() {}),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: controller.text.trim().length < 5
            ? null
            : () => Navigator.pop(context, controller.text.trim()),
        child: const Text('Continue'),
      ),
    ],
  );
}

Future<Map<String, dynamic>?> reviewStudentRecordChange({
  required BuildContext context,
  required AdmissionsApiClient api,
  required String school,
  required String student,
  required Map<String, dynamic> recordContext,
  required Map<String, dynamic> sections,
}) async {
  final reason = await requestStudentChangeReason(
    context,
    'Review student changes',
  );
  if (reason == null || !context.mounted) return null;
  final body = <String, dynamic>{
    'baseVersion': recordContext['baseVersion'],
    'reason': reason,
    'sections': sections,
  };
  final preview = await api.previewStudentRecordChange(school, student, body);
  if (!context.mounted) return null;
  final needsApproval = preview['requiresApproval'] == true;
  final approvers = (recordContext['approvers'] as List? ?? [])
      .whereType<Map>()
      .toList();
  int? approverId;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(needsApproval ? 'Request approval' : 'Confirm changes'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  needsApproval
                      ? 'The existing record stays unchanged until another administrator approves. All selected sections are submitted together.'
                      : 'These changes take effect immediately. Other authorized administrators will be notified.',
                ),
                const SizedBox(height: 12),
                Text('Reason: $reason'),
                const SizedBox(height: 12),
                StudentRecordDiff(
                  before: Map<String, dynamic>.from(
                    preview['before'] as Map? ?? {},
                  ),
                  proposed: sections,
                ),
                if (needsApproval) ...[
                  const SizedBox(height: 16),
                  if (approvers.isEmpty)
                    const Text(
                      'No other authorized administrator is available. An eligible second administrator is required; you cannot approve your own changes.',
                    )
                  else
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Approving administrator',
                      ),
                      value: approverId,
                      items: approvers
                          .map(
                            (a) => DropdownMenuItem(
                              value: (a['id'] as num).toInt(),
                              child: Text('${a['name']}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => approverId = value),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: needsApproval && approverId == null
                ? null
                : () => Navigator.pop(context, true),
            child: Text(needsApproval ? 'Submit for approval' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true) return null;
  return api.submitStudentRecordChange(school, student, {
    ...body,
    if (approverId != null) 'approverId': approverId,
  });
}

class StudentRecordDiff extends StatelessWidget {
  const StudentRecordDiff({
    super.key,
    required this.before,
    required this.proposed,
  });
  final Map<String, dynamic> before;
  final Map<String, dynamic> proposed;
  @override
  Widget build(BuildContext context) => Column(
    children: proposed.entries
        .map(
          (entry) => ExpansionTile(
            title: Text(recordFieldLabel(entry.key)),
            initiallyExpanded: proposed.length == 1,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    Widget value(String title, Object? data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(recordValueText(data)),
                      ],
                    );
                    if (constraints.maxWidth < 500) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          value('Before', before[entry.key]),
                          const SizedBox(height: 12),
                          value('Proposed / saved', entry.value),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: value('Before', before[entry.key])),
                        const SizedBox(width: 18),
                        Expanded(child: value('Proposed / saved', entry.value)),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        )
        .toList(),
  );
}

class StudentRecordHistoryPanel extends StatefulWidget {
  const StudentRecordHistoryPanel({
    super.key,
    required this.api,
    required this.school,
    required this.student,
    required this.onChanged,
  });
  final AdmissionsApiClient api;
  final String school;
  final String student;
  final VoidCallback onChanged;
  @override
  State<StudentRecordHistoryPanel> createState() =>
      _StudentRecordHistoryPanelState();
}

class _StudentRecordHistoryPanelState extends State<StudentRecordHistoryPanel> {
  late Future<List<Map<String, dynamic>>> _history;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = widget.api.getStudentRecordChanges(
      widget.school,
      widget.student,
    );
  }

  @override
  void didUpdateWidget(covariant StudentRecordHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student != widget.student || oldWidget.api != widget.api) {
      _reload();
    }
  }

  Future<void> _decide(Map<String, dynamic> change, String action) async {
    if (_busy) return;
    var reason = '';
    if (action != 'APPROVE') {
      final value = await requestStudentChangeReason(
        context,
        '${recordFieldLabel(action.toLowerCase())} change',
      );
      if (value == null || !mounted) return;
      reason = value;
    }
    setState(() => _busy = true);
    try {
      await widget.api.decideStudentRecordChange(
        widget.school,
        widget.student,
        (change['id'] as num).toInt(),
        action,
        reason,
      );
      if (!mounted) return;
      setState(_reload);
      widget.onChanged();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _history,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return ListTile(
          title: const Text('Change history unavailable'),
          subtitle: Text('${snapshot.error}'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_reload),
          ),
        );
      }
      final history = snapshot.data ?? [];
      final pending = history
          .where((change) => change['status'] == 'PENDING_APPROVAL')
          .length;
      return Card(
        child: ExpansionTile(
          key: ValueKey('student-record-history-${widget.student}'),
          initiallyExpanded: pending > 0,
          title: const Text('Change history'),
          subtitle: Text(
            '$pending pending changes · ${history.length} recorded changes',
          ),
          children: [
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No changes recorded yet. History starts when this workflow is enabled.',
                ),
              ),
            ...history.map(
              (change) => ExpansionTile(
                title: Text('${change['status']} · ${change['requesterName']}'),
                subtitle: Text('${change['createdAt']}\n${change['reason']}'),
                children: [
                  if (change['approverName'] != null)
                    ListTile(
                      title: Text('Approver: ${change['approverName']}'),
                      subtitle: Text(
                        '${change['decisionReason'] ?? 'Awaiting decision'}',
                      ),
                    ),
                  StudentRecordDiff(
                    before: Map<String, dynamic>.from(
                      change['before'] as Map? ?? {},
                    ),
                    proposed: Map<String, dynamic>.from(
                      change['proposed'] as Map? ?? {},
                    ),
                  ),
                  for (final event
                      in (change['events'] as List? ?? []).whereType<Map>())
                    ListTile(
                      title: Text('${event['action']} · ${event['actorName']}'),
                      subtitle: Text(
                        '${event['occurredAt']}\n${event['reason']}\n${(event['notifications'] as List? ?? []).whereType<Map>().map((n) => '${n['recipient']}: ${n['readAt'] == null ? 'Delivered, not acknowledged' : 'Acknowledged ${n['readAt']}'}').join('\n')}',
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (change['canApprove'] == true) ...[
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _decide(change, 'APPROVE'),
                          child: const Text('Approve'),
                        ),
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _decide(change, 'REJECT'),
                          child: const Text('Reject'),
                        ),
                      ],
                      if (change['canWithdraw'] == true)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _decide(change, 'WITHDRAW'),
                          child: const Text('Withdraw request'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
