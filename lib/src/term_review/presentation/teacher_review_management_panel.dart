import 'package:flutter/material.dart';

import '../../common/display_formatters.dart';
import '../../theme/app_theme.dart';
import '../domain/teacher_term_review_models.dart';

class TeacherReviewManagementPanel extends StatefulWidget {
  const TeacherReviewManagementPanel({
    super.key,
    required this.schoolId,
    required this.actorUserId,
    required this.repository,
    this.onChanged,
  });
  final String schoolId;
  final int? actorUserId;
  final TeacherTermReviewRepository repository;
  final VoidCallback? onChanged;
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
            _header(d),
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
              runSpacing: 8,
              children: [
                _count('Teachers', d.total, AppColors.green),
                _count('Not started', d.notStarted, AppColors.muted),
                _count('Draft', d.draft, AppColors.amber),
                _count('Submitted', d.submitted, AppColors.blue),
                _count('Closed', d.closed, AppColors.green),
              ],
            ),
            const SizedBox(height: 24),
            _staffList(d.teachers),
          ],
        ),
      );
    },
  );
  Widget _header(TeacherReviewDashboard dashboard) => LayoutBuilder(
    builder: (context, constraints) {
      const title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teacher term-closing reviews',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Control when teachers can complete their closing reflection.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      );
      final controls = Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _WindowStatus(dashboard.status),
          if (dashboard.status == 'OPEN')
            OutlinedButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.lock_outline),
              label: const Text('End review submissions'),
            )
          else
            FilledButton.icon(
              onPressed: () => _release(dashboard),
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(
                dashboard.status == 'CLOSED'
                    ? 'Reopen review submissions'
                    : 'Release reviews',
              ),
            ),
        ],
      );
      if (constraints.maxWidth < 620) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 12), controls],
        );
      }
      return Row(
        children: [
          const Expanded(child: title),
          const SizedBox(width: 16),
          controls,
        ],
      );
    },
  );

  Widget _staffList(List<TeacherReviewRow> teachers) {
    if (teachers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No staff reviews for this term.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                if (!compact)
                  ColoredBox(
                    color: AppColors.background,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          color: Color(0xFF475467),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        child: _staffColumns(
                          person: const Text('Staff member'),
                          status: const Text('Review status'),
                          action: const Text('Action'),
                        ),
                      ),
                    ),
                  ),
                for (final (index, teacher) in teachers.indexed) ...[
                  if (!compact || index > 0)
                    const Divider(height: 1, color: AppColors.border),
                  _staffRow(teacher, compact: compact),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _staffRow(TeacherReviewRow teacher, {required bool compact}) {
    final name = teacher.name.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final person = Row(
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.greenSoft,
            foregroundColor: const Color(0xFF17685C),
            child: initials.isEmpty
                ? const Icon(Icons.person_outline, size: 19)
                : Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Unnamed staff member' : name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                switch (teacher.role.trim().toUpperCase().replaceAll(
                  '_',
                  ' ',
                )) {
                  'CLASS TEACHER' => 'Class teacher',
                  'SUBJECT TEACHER' => 'Subject teacher',
                  _ => displayRoleName(teacher.role),
                },
                style: const TextStyle(color: Color(0xFF475467), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
    final status = _TeacherStatus(teacher.status);
    final action = teacher.status == 'SUBMITTED' || teacher.status == 'CLOSED'
        ? TextButton.icon(
            onPressed: () => _reopenTeacher(teacher),
            icon: const Icon(Icons.lock_open_outlined, size: 17),
            label: const Text('Reopen review'),
          )
        : null;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 12 : 10,
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                person,
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [status, if (action != null) action],
                ),
              ],
            )
          : _staffColumns(person: person, status: status, action: action),
    );
  }

  Widget _staffColumns({
    required Widget person,
    required Widget status,
    Widget? action,
  }) => Row(
    children: [
      Expanded(flex: 5, child: person),
      const SizedBox(width: 16),
      Expanded(
        flex: 3,
        child: Align(alignment: Alignment.centerLeft, child: status),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 156,
        child: Align(alignment: Alignment.centerRight, child: action),
      ),
    ],
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
      widget.onChanged?.call();
    }
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End review submissions?'),
        content: const Text(
          'Teachers will no longer be able to submit their term reviews. '
          'Draft and unstarted reviews will still count as incomplete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End review submissions'),
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
      widget.onChanged?.call();
    }
  }

  Future<void> _reopenTeacher(TeacherReviewRow t) async {
    var input = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reopen ${t.name}’s review?'),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            onChanged: (value) => setDialogState(() => input = value.trim()),
            decoration: const InputDecoration(labelText: 'Reason *'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: input.length >= 5
                  ? () => Navigator.pop(context, input)
                  : null,
              child: const Text('Reopen review'),
            ),
          ],
        ),
      ),
    );
    if (reason != null && mounted) {
      await widget.repository.reopen(
        widget.schoolId,
        t.teacherUserId,
        actorUserId: widget.actorUserId,
        reason: reason,
      );
      reload();
      widget.onChanged?.call();
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
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (s) {
      'DRAFT' => (
        'Draft',
        Icons.edit_note_outlined,
        const Color(0xFF854B0A),
        const Color(0xFFFFF3DC),
      ),
      'SUBMITTED' => (
        'Submitted',
        Icons.check_circle_outline,
        const Color(0xFF174A91),
        const Color(0xFFEDF3FF),
      ),
      'CLOSED' => (
        'Closed',
        Icons.lock_outline,
        const Color(0xFF17685C),
        AppColors.greenSoft,
      ),
      _ => (
        'Not started',
        Icons.schedule_outlined,
        const Color(0xFF475467),
        const Color(0xFFF0F2F5),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 16),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
