import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/teacher_term_review_models.dart';

class TeacherReviewManagementPanel extends StatefulWidget {
  const TeacherReviewManagementPanel({
    super.key,
    required this.schoolId,
    required this.actorUserId,
    required this.repository,
  });
  final String schoolId;
  final int? actorUserId;
  final TeacherTermReviewRepository repository;
  @override
  State<TeacherReviewManagementPanel> createState() =>
      _TeacherReviewManagementPanelState();
}

class _TeacherReviewManagementPanelState
    extends State<TeacherReviewManagementPanel> {
  late Future<TeacherReviewDashboard> future;
  @override
  void initState() {
    super.initState();
    future = widget.repository.getDashboard(widget.schoolId);
  }

  void reload() {
    setState(() {
      future = widget.repository.getDashboard(widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherReviewDashboard>(
    future: future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (s.hasError) {
        return Text(
          'Teacher review controls unavailable: ${s.error}',
          style: const TextStyle(color: AppColors.red),
        );
      }
      final d = s.requireData;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
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
                        'Teacher term-closing reviews',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Control when teachers can complete their closing reflection.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _WindowStatus(d.status),
                const SizedBox(width: 10),
                if (d.status != 'OPEN')
                  FilledButton.icon(
                    onPressed: () => _release(d),
                    icon: const Icon(Icons.lock_open_outlined),
                    label: Text(
                      d.status == 'CLOSED'
                          ? 'Reopen window'
                          : 'Release reviews',
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Close window'),
                  ),
              ],
            ),
            if (d.deadline != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Deadline: ${_date(d.deadline!)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: [
                _count('Teachers', d.total, AppColors.green),
                _count('Not started', d.notStarted, AppColors.muted),
                _count('Draft', d.draft, AppColors.amber),
                _count('Submitted', d.submitted, AppColors.blue),
                _count('Closed', d.closed, AppColors.green),
              ],
            ),
            if (d.teachers.isNotEmpty) ...[
              const Divider(height: 28),
              ...d.teachers.map(
                (t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    t.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(t.role),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TeacherStatus(t.status),
                      if (t.status == 'SUBMITTED' || t.status == 'CLOSED')
                        TextButton(
                          onPressed: () => _reopenTeacher(t),
                          child: const Text('Reopen'),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
  Widget _count(String l, int v, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: c.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$l  $v',
      style: TextStyle(color: c, fontWeight: FontWeight.w700),
    ),
  );
  Future<void> _release(TeacherReviewDashboard d) async {
    DateTime open = DateTime.now(),
        deadline = DateTime.now().add(const Duration(days: 7));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Release teacher reviews'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Opening date'),
                  subtitle: Text(_date(open)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final v = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: open,
                    );
                    if (v != null) setDialog(() => open = v);
                  },
                ),
                ListTile(
                  title: const Text('Submission deadline'),
                  subtitle: Text(_date(deadline)),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final v = await showDatePicker(
                      context: context,
                      firstDate: open,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: deadline.isBefore(open) ? open : deadline,
                    );
                    if (v != null) setDialog(() => deadline = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Release'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.repository.release(
        widget.schoolId,
        actorUserId: widget.actorUserId,
        opensOn: open,
        deadline: deadline,
      );
      reload();
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close teacher reviews?'),
        content: const Text(
          'Submitted teacher reviews will be locked. Draft and unstarted reviews remain incomplete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Close window'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.repository.close(
        widget.schoolId,
        actorUserId: widget.actorUserId,
      );
      reload();
    }
  }

  Future<void> _reopenTeacher(TeacherReviewRow t) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reopen ${t.name}’s review?'),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => c.text.trim().length >= 5
                ? Navigator.pop(context, c.text.trim())
                : null,
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    c.dispose();
    if (reason != null) {
      await widget.repository.reopen(
        widget.schoolId,
        t.teacherUserId,
        actorUserId: widget.actorUserId,
        reason: reason,
      );
      reload();
    }
  }

  String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  static const _months = [
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
}

class _WindowStatus extends StatelessWidget {
  const _WindowStatus(this.s);
  final String s;
  @override
  Widget build(BuildContext context) {
    final c = s == 'OPEN'
        ? AppColors.green
        : s == 'CLOSED'
        ? AppColors.red
        : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        s.replaceAll('_', ' ').toLowerCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TeacherStatus extends StatelessWidget {
  const _TeacherStatus(this.s);
  final String s;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      s.replaceAll('_', ' ').toLowerCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    ),
  );
}
