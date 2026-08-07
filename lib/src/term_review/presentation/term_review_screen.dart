import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/staff_review_models.dart';
import '../domain/teacher_term_review_models.dart';
import '../domain/bursar_term_closure_models.dart';
import '../domain/headmaster_term_closure_models.dart';
import 'teacher_review_management_panel.dart';
import 'bursar_term_closing_screen.dart';
import 'headmaster_term_closure_screen.dart';

class TermReviewScreen extends StatefulWidget {
  const TermReviewScreen({
    super.key,
    required this.schoolId,
    required this.repository,
    this.teacherReviewRepository,
    this.bursarClosureRepository,
    this.headmasterClosureRepository,
    this.reviewerUserId,
  });
  final String schoolId;
  final StaffReviewRepository repository;
  final TeacherTermReviewRepository? teacherReviewRepository;
  final BursarTermClosureRepository? bursarClosureRepository;
  final HeadmasterTermClosureRepository? headmasterClosureRepository;
  final int? reviewerUserId;
  @override
  State<TermReviewScreen> createState() => _TermReviewScreenState();
}

class _TermReviewScreenState extends State<TermReviewScreen> {
  late Future<StaffReviewDashboardData> _future;
  String _filter = 'ALL';
  String _query = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = widget.repository.getDashboard(widget.schoolId);
  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: FutureBuilder<StaffReviewDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: '${snapshot.error}', retry: _refresh);
        }
        final data = snapshot.requireData;
        final rows = data.reviews.where((review) {
          final matchesFilter = _filter == 'ALL' || review.status == _filter;
          final q = _query.toLowerCase();
          return matchesFilter &&
              (review.staffName.toLowerCase().contains(q) ||
                  review.role.toLowerCase().contains(q));
        }).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
            children: [
              if (widget.headmasterClosureRepository != null) ...[
                SizedBox(
                  height: 1500,
                  child: HeadmasterTermClosureScreen(
                    schoolId: widget.schoolId,
                    actorUserId: widget.reviewerUserId,
                    repository: widget.headmasterClosureRepository!,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (widget.teacherReviewRepository != null) ...[
                TeacherReviewManagementPanel(
                  schoolId: widget.schoolId,
                  actorUserId: widget.reviewerUserId,
                  repository: widget.teacherReviewRepository!,
                ),
                const SizedBox(height: 24),
              ],
              if (widget.bursarClosureRepository != null) ...[
                SizedBox(
                  height: 510,
                  child: BursarTermClosingScreen(
                    schoolId: widget.schoolId,
                    actorUserId: widget.reviewerUserId,
                    repository: widget.bursarClosureRepository!,
                    management: true,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff performance reviews',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Review every staff member before the term is closed.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  _Pill(
                    icon: Icons.calendar_today_outlined,
                    label: data.termName,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Metric(
                    label: 'All staff',
                    value: data.total,
                    color: AppColors.green,
                  ),
                  _Metric(
                    label: 'Not started',
                    value: data.notStarted,
                    color: AppColors.muted,
                  ),
                  _Metric(
                    label: 'Draft',
                    value: data.draft,
                    color: AppColors.amber,
                  ),
                  _Metric(
                    label: 'Completed',
                    value: data.completed,
                    color: AppColors.green,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                decoration: _card(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search staff or role',
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        DropdownButton<String>(
                          value: _filter,
                          items: const [
                            DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All statuses'),
                            ),
                            DropdownMenuItem(
                              value: 'NOT_STARTED',
                              child: Text('Not started'),
                            ),
                            DropdownMenuItem(
                              value: 'DRAFT',
                              child: Text('Draft'),
                            ),
                            DropdownMenuItem(
                              value: 'COMPLETED',
                              child: Text('Completed'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _filter = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Text('No staff match this filter.'),
                      )
                    else
                      ...rows.map(
                        (review) => _ReviewRow(
                          review: review,
                          onOpen: () => _open(review),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _open(StaffReview summary) async {
    final current = await widget.repository.getReview(
      widget.schoolId,
      summary.staffId,
    );
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ReviewForm(
          review: current,
          schoolId: widget.schoolId,
          repository: widget.repository,
          reviewerUserId: widget.reviewerUserId,
        ),
      ),
    );
    if (mounted) await _refresh();
  }
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({
    required this.review,
    required this.schoolId,
    required this.repository,
    required this.reviewerUserId,
  });
  final StaffReview review;
  final String schoolId;
  final StaffReviewRepository repository;
  final int? reviewerUserId;
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late StaffReview _review;
  late Map<String, int> _ratings;
  late int? _overall;
  late final TextEditingController _strengths,
      _improvements,
      _training,
      _actions,
      _comments;
  late bool _followUp;
  bool _saving = false;
  bool get _locked => _review.status == 'COMPLETED';

  static const _common = <(String, String)>[
    ('professionalism', 'Professionalism and conduct'),
    ('quality', 'Quality and accuracy of work'),
    ('reliability', 'Reliability and responsibility'),
    ('communication', 'Communication'),
    ('teamwork', 'Teamwork and cooperation'),
    ('initiative', 'Initiative and problem solving'),
    ('policy', 'Compliance with school policies'),
  ];
  List<(String, String)> get _roleQuestions {
    final role = _review.role.toUpperCase();
    if (role.contains('TEACH')) {
      return const [
        ('teachingQuality', 'Teaching quality'),
        ('classroomManagement', 'Classroom management'),
        ('assessmentCompletion', 'Assessment completion'),
      ];
    }
    if (role.contains('BURSAR') || role.contains('FINANCE')) {
      return const [
        ('financialAccuracy', 'Financial accuracy'),
        ('financialControls', 'Financial controls and reporting'),
        ('confidentiality', 'Confidentiality'),
      ];
    }
    if (role.contains('ADMIN')) {
      return const [
        ('recordAccuracy', 'Record accuracy'),
        ('responsiveness', 'Responsiveness'),
        ('organisation', 'Organisation'),
      ];
    }
    return const [
      ('dutyQuality', 'Quality of assigned duties'),
      ('safety', 'Safety awareness'),
    ];
  }

  @override
  void initState() {
    super.initState();
    _review = widget.review;
    _ratings = {..._review.ratings};
    _overall = _review.overallRating;
    _strengths = TextEditingController(text: _review.strengths);
    _improvements = TextEditingController(text: _review.improvementAreas);
    _training = TextEditingController(text: _review.trainingSupport);
    _actions = TextEditingController(text: _review.nextTermActions);
    _comments = TextEditingController(text: _review.finalComments);
    _followUp = _review.formalFollowUp;
  }

  @override
  void dispose() {
    for (final c in [
      _strengths,
      _improvements,
      _training,
      _actions,
      _comments,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(_review.staffName),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(child: _Status(status: _review.status)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
      children: [
        Container(
          decoration: _card(),
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.green.withValues(alpha: .12),
                child: Text(
                  _initials(_review.staffName),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _review.staffName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _review.role,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (_locked)
                OutlinedButton.icon(
                  onPressed: _reopen,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('Reopen review'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Performance ratings',
          subtitle:
              'Rate each area from 1 (needs significant improvement) to 5 (excellent).',
          child: Column(
            children: [
              ...[..._common, ..._roleQuestions].map(
                (q) => _RatingRow(
                  label: q.$2,
                  value: _ratings[q.$1],
                  enabled: !_locked,
                  onChanged: (v) => setState(() => _ratings[q.$1] = v),
                ),
              ),
              const Divider(height: 30),
              _RatingRow(
                label: 'Overall performance',
                value: _overall,
                enabled: !_locked,
                emphasized: true,
                onChanged: (v) => setState(() => _overall = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Written assessment',
          subtitle: 'Record clear evidence and practical next steps.',
          child: Column(
            children: [
              _field(_strengths, 'Strengths demonstrated', required: true),
              _field(
                _improvements,
                'Areas requiring improvement',
                required: true,
              ),
              _field(_training, 'Support or training required'),
              _field(
                _actions,
                'Recommended actions for next term',
                required: true,
              ),
              _field(_comments, 'Final comments'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _followUp,
                onChanged: _locked
                    ? null
                    : (v) => setState(() => _followUp = v),
                title: const Text(
                  'Formal follow-up required',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Flag this review for a documented follow-up next term.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (!_locked)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => _save(false),
                child: const Text('Save draft'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete review'),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      enabled: !_locked,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        alignLabelWithHint: true,
      ),
    ),
  );
  StaffReviewInput get _input => StaffReviewInput(
    reviewerUserId: widget.reviewerUserId,
    ratings: _ratings,
    overallRating: _overall,
    strengths: _strengths.text.trim(),
    improvementAreas: _improvements.text.trim(),
    trainingSupport: _training.text.trim(),
    nextTermActions: _actions.text.trim(),
    formalFollowUp: _followUp,
    finalComments: _comments.text.trim(),
  );
  Future<void> _save(bool complete) async {
    if (complete) {
      final missingRatings = [
        ..._common,
        ..._roleQuestions,
      ].any((q) => !_ratings.containsKey(q.$1));
      if (missingRatings ||
          _overall == null ||
          _strengths.text.trim().isEmpty ||
          _improvements.text.trim().isEmpty ||
          _actions.text.trim().isEmpty) {
        _message(
          'Complete every rating and the required written fields before completing the review.',
          error: true,
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final saved = complete
          ? await widget.repository.complete(
              widget.schoolId,
              _review.staffId,
              _input,
            )
          : await widget.repository.saveDraft(
              widget.schoolId,
              _review.staffId,
              _input,
            );
      if (!mounted) return;
      setState(() {
        _review = saved;
        _saving = false;
      });
      _message(complete ? 'Review completed.' : 'Draft saved.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _message('$e', error: true);
      }
    }
  }

  Future<void> _reopen() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen completed review?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for reopening *',
            hintText: 'This reason will be stored in the audit history.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 5) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    try {
      final reopened = await widget.repository.reopen(
        widget.schoolId,
        _review.staffId,
        reviewerUserId: widget.reviewerUserId,
        reason: reason,
      );
      if (mounted) {
        setState(() => _review = reopened);
        _message('Review reopened as a draft.');
      }
    } catch (e) {
      if (mounted) _message('$e', error: true);
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? AppColors.red : AppColors.green,
        ),
      );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, required this.onOpen});
  final StaffReview review;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.green.withValues(alpha: .1),
            child: Text(
              _initials(review.staffName),
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Text(
              review.staffName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              review.role,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          _Status(status: review.status),
          const SizedBox(width: 18),
          Text(
            review.status == 'COMPLETED'
                ? 'View review'
                : review.status == 'DRAFT'
                ? 'Continue'
                : 'Start review',
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    ),
  );
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.emphasized = false,
  });
  final String label;
  final int? value;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final bool emphasized;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        ...List.generate(5, (i) {
          final n = i + 1;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text('$n'),
              selected: value == n,
              onSelected: enabled ? (_) => onChanged(n) : null,
            ),
          );
        }),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: _card(),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(18),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _Status extends StatelessWidget {
  const _Status({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final c = status == 'COMPLETED'
        ? AppColors.green
        : status == 'DRAFT'
        ? AppColors.amber
        : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('_', ' ').toLowerCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.green),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});
  final String message;
  final Future<void> Function() retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 44, color: AppColors.red),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 16),
        FilledButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

BoxDecoration _card() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: AppColors.border),
);
String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((e) => e.isNotEmpty)
    .take(2)
    .map((e) => e[0])
    .join()
    .toUpperCase();
