import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/staff_review_models.dart';
import '../domain/teacher_term_review_models.dart';
import '../domain/bursar_term_closure_models.dart';
import '../domain/headmaster_term_closure_models.dart';
import 'teacher_review_management_panel.dart';
import 'bursar_term_closing_screen.dart';
import 'facility_inspection_prototype.dart';
import 'headmaster_term_closure_screen.dart';

enum _TermReviewView {
  dashboard,
  teacherReviews,
  finance,
  staffReviews,
  facilityInspection,
}

class TermReviewScreen extends StatefulWidget {
  const TermReviewScreen({
    super.key,
    required this.schoolId,
    required this.repository,
    this.teacherReviewRepository,
    this.bursarClosureRepository,
    this.headmasterClosureRepository,
    this.onConfirmNoFinanceActivity,
    this.reviewerUserId,
    this.reviewerDisplayName,
    this.onTermTransitioned,
    this.onOpenAttendance,
    this.onOpenStaffAttendance,
    this.onOpenEvaluations,
    this.onOpenFinalReports,
    this.onOpenIncidents,
    this.onOpenSettings,
    this.onOpenTermDates,
    this.onEditCurrentTermDates,
    this.onSetUpNextTerm,
    this.onBeginNextTerm,
    this.onOpenFees,
  });
  final String schoolId;
  final StaffReviewRepository repository;
  final TeacherTermReviewRepository? teacherReviewRepository;
  final BursarTermClosureRepository? bursarClosureRepository;
  final HeadmasterTermClosureRepository? headmasterClosureRepository;
  final Future<HeadmasterTermClosure> Function(int termId)?
  onConfirmNoFinanceActivity;
  final int? reviewerUserId;
  final String? reviewerDisplayName;
  final VoidCallback? onTermTransitioned;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenStaffAttendance;
  final VoidCallback? onOpenEvaluations;
  final VoidCallback? onOpenFinalReports;
  final VoidCallback? onOpenIncidents;
  final VoidCallback? onOpenSettings;
  final Future<bool> Function()? onOpenTermDates;
  final Future<bool> Function(int termId)? onEditCurrentTermDates;
  final Future<bool> Function(int termId)? onSetUpNextTerm;
  final Future<Map<String, dynamic>> Function(int closedTermId, int nextTermId)?
  onBeginNextTerm;
  final ValueChanged<int>? onOpenFees;
  @override
  State<TermReviewScreen> createState() => _TermReviewScreenState();
}

class _TermReviewScreenState extends State<TermReviewScreen> {
  late Future<StaffReviewDashboardData> _future;
  late _TermReviewView _view;
  int _termGeneration = 0;
  String _filter = 'ALL';
  String _query = '';
  @override
  void initState() {
    super.initState();
    _view = widget.headmasterClosureRepository == null
        ? _TermReviewView.staffReviews
        : _TermReviewView.dashboard;
    _load();
  }

  void _load() => _future = widget.repository.getDashboard(widget.schoolId);
  Future<void> _refresh() async {
    setState(() {
      _termGeneration++;
      _load();
    });
    await _future;
  }

  void _handleTermTransitioned() {
    setState(() {
      _termGeneration++;
      _load();
    });
    widget.onTermTransitioned?.call();
  }

  void _handleWorkstreamChanged() {
    if (!mounted) return;
    setState(() {
      _termGeneration++;
      _load();
    });
  }

  void _showView(_TermReviewView view) {
    setState(() => _view = view);
  }

  void _backToDashboard() {
    setState(() {
      _view = _TermReviewView.dashboard;
      _termGeneration++;
      _load();
    });
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
        return switch (_view) {
          _TermReviewView.dashboard => _dashboardView(),
          _TermReviewView.teacherReviews => _teacherReviewView(),
          _TermReviewView.finance => _financeView(),
          _TermReviewView.staffReviews => _staffReviewView(data, rows),
          _TermReviewView.facilityInspection => FacilityInspectionPrototype(
            onBack: _backToDashboard,
            schoolId: widget.schoolId,
            termName: data.termName,
            repository: widget.headmasterClosureRepository!,
            actorUserId: widget.reviewerUserId,
            actorDisplayName: widget.reviewerDisplayName,
          ),
        };
      },
    ),
  );

  Widget _dashboardView() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: EdgeInsets.zero,
      children: [
        HeadmasterTermClosureScreen(
          key: ValueKey('headmaster-closure-$_termGeneration'),
          schoolId: widget.schoolId,
          actorUserId: widget.reviewerUserId,
          repository: widget.headmasterClosureRepository!,
          embedded: true,
          onOpenTermDates: widget.onOpenTermDates,
          onEditCurrentTermDates: widget.onEditCurrentTermDates,
          onSetUpNextTerm: widget.onSetUpNextTerm,
          onBeginNextTerm: widget.onBeginNextTerm,
          onOpenFees: widget.onOpenFees,
          onConfirmNoFinanceActivity: widget.onConfirmNoFinanceActivity,
          onOpenFacilities: () => _showView(_TermReviewView.facilityInspection),
          workstreamActions: {
            if (widget.teacherReviewRepository != null)
              'TEACHER_REVIEWS': () =>
                  _showView(_TermReviewView.teacherReviews),
            if (widget.bursarClosureRepository != null)
              'FINANCE': () => _showView(_TermReviewView.finance),
            'STAFF_REVIEWS': () => _showView(_TermReviewView.staffReviews),
            if (widget.onOpenAttendance != null)
              'STUDENT_ATTENDANCE': widget.onOpenAttendance!,
            if (widget.onOpenStaffAttendance != null)
              'STAFF_ATTENDANCE': widget.onOpenStaffAttendance!,
            if (widget.onOpenFinalReports != null)
              'REPORTS': widget.onOpenFinalReports!,
            if (widget.onOpenFinalReports != null)
              'REPORT_CORRECTIONS': widget.onOpenFinalReports!,
            if (widget.onOpenEvaluations != null)
              'EVALUATION_APPROVALS': widget.onOpenEvaluations!,
            if (widget.onOpenIncidents != null)
              'INCIDENTS': widget.onOpenIncidents!,
            if (widget.onOpenSettings != null)
              'NEXT_TERM': widget.onOpenSettings!,
            if (widget.onOpenSettings != null)
              'TERM_DATE': widget.onOpenSettings!,
            if (widget.onOpenSettings != null)
              'CLOSING_DATE': widget.onOpenSettings!,
            if (widget.onOpenSettings != null)
              'TERM_CLOSING_DATE': widget.onOpenSettings!,
          },
          onTermTransitioned: _handleTermTransitioned,
        ),
      ],
    ),
  );

  Widget _teacherReviewView() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
      children: [
        _backButton(),
        const SizedBox(height: 16),
        TeacherReviewManagementPanel(
          key: ValueKey('teacher-reviews-$_termGeneration'),
          schoolId: widget.schoolId,
          actorUserId: widget.reviewerUserId,
          repository: widget.teacherReviewRepository!,
          onChanged: _handleWorkstreamChanged,
        ),
      ],
    ),
  );

  Widget _financeView() => RefreshIndicator(
    onRefresh: _refresh,
    child: LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: ((constraints.maxWidth - 1120) / 2).clamp(
            16.0,
            double.infinity,
          ),
        ).copyWith(top: 24, bottom: 48),
        children: [
          _backButton(),
          const SizedBox(height: 16),
          BursarTermClosingScreen(
            key: ValueKey('bursar-closure-$_termGeneration'),
            schoolId: widget.schoolId,
            actorUserId: widget.reviewerUserId,
            repository: widget.bursarClosureRepository!,
            management: true,
            embedded: true,
            onChanged: _handleWorkstreamChanged,
          ),
        ],
      ),
    ),
  );

  Widget _staffReviewView(
    StaffReviewDashboardData data,
    List<StaffReview> rows,
  ) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
      children: [
        if (widget.headmasterClosureRepository != null) ...[
          _backButton(),
          const SizedBox(height: 16),
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
            _Pill(icon: Icons.calendar_today_outlined, label: data.termName),
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
            _Metric(label: 'Draft', value: data.draft, color: AppColors.amber),
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
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
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
                  (review) =>
                      _ReviewRow(review: review, onOpen: () => _open(review)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _backButton() => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: _backToDashboard,
      icon: const Icon(Icons.arrow_back_rounded),
      label: const Text('Back to Term Closure'),
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
  final _strengths = TextEditingController();
  final _improvements = TextEditingController();
  final _training = TextEditingController();
  final _actions = TextEditingController();
  final _comments = TextEditingController();
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
    _loadReview(widget.review);
  }

  void _loadReview(StaffReview review) {
    _review = review;
    _ratings = {...review.ratings};
    _overall = review.overallRating;
    _strengths.text = review.strengths;
    _improvements.text = review.improvementAreas;
    _training.text = review.trainingSupport;
    _actions.text = review.nextTermActions;
    _comments.text = review.finalComments;
    _followUp = review.formalFollowUp;
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
      padding: EdgeInsets.symmetric(
        horizontal: ((MediaQuery.sizeOf(context).width - 720) / 2).clamp(
          12.0,
          double.infinity,
        ),
      ).copyWith(top: 24, bottom: 48),
      children: [
        Container(
          decoration: _card(),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                ],
              ),
              if (_locked) ...[
                const Divider(height: 24, color: AppColors.border),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 18,
                          color: Color(0xFF475467),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Read-only review',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475467),
                            ),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _reopen,
                      icon: const Icon(Icons.lock_open_outlined),
                      label: const Text('Reopen review'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Performance ratings',
          subtitle: _locked
              ? null
              : 'Rate each area from 1 (needs significant improvement) to 5 (excellent).',
          child: Column(
            children: [
              ...[..._common, ..._roleQuestions].map(
                (q) => _RatingRow(
                  key: ValueKey(q.$1),
                  label: q.$2,
                  value: _ratings[q.$1],
                  onChanged: _locked
                      ? null
                      : (v) => setState(() => _ratings[q.$1] = v),
                ),
              ),
              const SizedBox(height: 8),
              _RatingRow(
                key: const ValueKey('overallRating'),
                label: 'Overall performance',
                value: _overall,
                emphasized: true,
                onChanged: _locked ? null : (v) => setState(() => _overall = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Section(
          title: 'Written assessment',
          subtitle: _locked
              ? null
              : 'Record clear evidence and practical next steps.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              if (_locked)
                _savedField('Formal follow-up', _followUp ? 'Required' : 'None')
              else
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _followUp,
                  onChanged: (v) => setState(() => _followUp = v),
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
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _saving ? null : () => _save(false),
                child: const Text('Save draft'),
              ),
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
  }) {
    if (_locked) return _savedField(label, controller.text);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _savedField(String label, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text.trim().isEmpty ? 'None recorded' : text,
          style: const TextStyle(color: Color(0xFF475467)),
        ),
      ],
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
        if (complete) {
          _loadReview(saved);
        } else {
          _review = saved;
        }
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
    var input = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reopen completed review?'),
          content: TextField(
            autofocus: true,
            maxLines: 3,
            onChanged: (value) => setDialogState(() => input = value.trim()),
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
              onPressed: input.length >= 5
                  ? () => Navigator.pop(context, input)
                  : null,
              child: const Text('Reopen'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || reason == null) return;
    setState(() => _saving = true);
    try {
      final reopened = await widget.repository.reopen(
        widget.schoolId,
        _review.staffId,
        reviewerUserId: widget.reviewerUserId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() => _loadReview(reopened));
      _message('Review reopened as a draft.');
    } catch (e) {
      if (mounted) _message('$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emphasized = false,
  });
  final String label;
  final int? value;
  final ValueChanged<int>? onChanged;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final criterion = Text(
      label,
      style: TextStyle(
        color: AppColors.text,
        fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    final onScoreChanged = onChanged;
    final score = value;
    final rating = onScoreChanged == null
        ? Text(
            score == null ? 'No score recorded' : '$score / 5',
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          )
        : _scorePicker(colors, onScoreChanged);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized ? AppColors.greenSoft : AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 488) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [criterion, const SizedBox(height: 4), rating],
            );
          }
          return Row(
            children: [
              Expanded(child: criterion),
              const SizedBox(width: 16),
              rating,
            ],
          );
        },
      ),
    );
  }

  Widget _scorePicker(ColorScheme colors, ValueChanged<int> onScoreChanged) {
    return SizedBox(
      width: 240,
      child: SegmentedButton<int>(
        expandedInsets: EdgeInsets.zero,
        showSelectedIcon: false,
        emptySelectionAllowed: value == null,
        selected: {if (value != null) value!},
        onSelectionChanged: (selection) => onScoreChanged(selection.single),
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFF81968E)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary
                : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onPrimary
                : AppColors.text,
          ),
        ),
        segments: [
          for (var rating = 1; rating <= 5; rating++)
            ButtonSegment(
              value: rating,
              label: Semantics(
                label: '$label, $rating out of 5',
                excludeSemantics: true,
                child: Text('$rating'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
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
        if (subtitle case final description?) ...[
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: AppColors.muted)),
        ],
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
