import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/teacher_term_review_models.dart';

class TeacherTermClosingScreen extends StatefulWidget {
  const TeacherTermClosingScreen({
    super.key,
    required this.schoolId,
    required this.teacherUserId,
    required this.repository,
    this.onOpenAssessments,
    this.onOpenIncidents,
  });
  final String schoolId;
  final int teacherUserId;
  final TeacherTermReviewRepository repository;
  final VoidCallback? onOpenAssessments, onOpenIncidents;
  @override
  State<TeacherTermClosingScreen> createState() =>
      _TeacherTermClosingScreenState();
}

class _TeacherTermClosingScreenState extends State<TeacherTermClosingScreen> {
  late Future<TeacherTermReview> _future;
  TeacherTermReview? _review;
  bool _saving = false;
  final _reflection = <String, TextEditingController>{};
  final _leadership = <String, String>{};
  final _recommendations = <NextTermRecommendation>[];
  bool _damage = false, _recommendationsFinal = false, _serious = false;
  final _concern = TextEditingController();
  static const reflectionQuestions = <String, String>{
    'workedWell': 'What worked well in your teaching this term?',
    'challenges': 'What teaching challenges occurred?',
    'changeNextTerm': 'What should change next term?',
    'supportNeeded': 'What support or training do you need?',
    'personalCircumstances':
        'Are there personal or professional circumstances management should consider? (Optional)',
  };
  static const leadershipQuestions = <String, String>{
    'performance': 'How would you assess the headmaster’s performance?',
    'professionalism': 'How professional and fair was the headmaster?',
    'demonstration':
        'How often did the headmaster demonstrate or model effective teaching?',
    'support': 'How adequate was the support you received?',
    'safe': 'Do you feel safe at this school?',
    'speakFreely': 'Do you feel able to speak your mind without retaliation?',
  };
  @override
  void initState() {
    super.initState();
    _future = widget.repository.getTeacherReview(
      widget.schoolId,
      widget.teacherUserId,
    );
    _future.then(_hydrate);
  }

  void _hydrate(TeacherTermReview r) {
    if (!mounted) return;
    _review = r;
    for (final e in reflectionQuestions.entries) {
      _reflection[e.key] = TextEditingController(
        text: r.reflection[e.key] ?? '',
      );
    }
    _leadership.addAll(r.leadership);
    _recommendations.addAll(r.recommendations);
    _damage = r.damageConfirmed;
    _recommendationsFinal = r.recommendationsSubmitted;
    _serious = r.seriousConcern;
    _concern.text = r.seriousConcernDetails;
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _reflection.values) {
      c.dispose();
    }
    _concern.dispose();
    super.dispose();
  }

  bool get _locked =>
      _review?.reviewStatus == 'SUBMITTED' || _review?.reviewStatus == 'CLOSED';
  bool get _available =>
      _review?.status == 'OPEN' &&
      (_review?.opensOn == null ||
          !DateTime.now().isBefore(_review!.opensOn!)) &&
      (_review?.deadline == null ||
          !DateTime.now().isAfter(
            _review!.deadline!.add(const Duration(days: 1)),
          ));
  @override
  Widget build(BuildContext context) => FutureBuilder<TeacherTermReview>(
    future: _future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) return Center(child: Text('${s.error}'));
      final r = _review ?? s.requireData;
      if (_review == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate(r));
      }
      return ColoredBox(
        color: AppColors.background,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Close your teaching term',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Resolve outstanding work, reflect, and submit your end-of-term review.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _Status(r.reviewStatus),
              ],
            ),
            const SizedBox(height: 18),
            if (!_available && !_locked)
              _Notice(
                icon: Icons.lock_clock_outlined,
                title: r.status == 'NOT_RELEASED'
                    ? 'The review has not been released'
                    : 'The review window is closed',
                message: r.status == 'NOT_RELEASED'
                    ? 'Your headmaster will release this review at the appropriate time.'
                    : 'Contact the headmaster if you need the review reopened.',
              ),
            if (_available || _locked) ...[
              _outstanding(r),
              const SizedBox(height: 18),
              _reflectionSection(),
              const SizedBox(height: 18),
              _damageSection(),
              const SizedBox(height: 18),
              _recommendationSection(),
              const SizedBox(height: 18),
              _leadershipSection(),
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
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit term review'),
                    ),
                  ],
                ),
            ],
          ],
        ),
      );
    },
  );
  Widget _outstanding(TeacherTermReview r) => _Section(
    title: 'Items requiring action',
    subtitle: 'Only items that can block submission appear here.',
    child: Column(
      children: [
        _ActionRow(
          label: 'Assessment records',
          detail: r.assessmentIncompleteCount == 0
              ? 'Complete'
              : '${r.assessmentIncompleteCount} incomplete',
          complete: r.assessmentIncompleteCount == 0,
          onTap: widget.onOpenAssessments,
        ),
        _ActionRow(
          label: 'Student evaluations',
          detail: r.evaluationIncompleteCount == 0
              ? 'Submitted'
              : '${r.evaluationIncompleteCount} not submitted',
          complete: r.evaluationIncompleteCount == 0,
          onTap: widget.onOpenAssessments,
        ),
        _ActionRow(
          label: 'Loss and damage declaration',
          detail: _damage ? 'Confirmed' : 'Not confirmed',
          complete: _damage,
          onTap: widget.onOpenIncidents,
        ),
        _ActionRow(
          label: 'Next-term recommendations',
          detail: _recommendationsFinal
              ? 'Finalized'
              : _recommendations.isEmpty
              ? 'No items added'
              : '${_recommendations.length} item(s) still in draft',
          complete: _recommendationsFinal,
          onTap: null,
        ),
      ],
    ),
  );
  Widget _reflectionSection() => _Section(
    title: 'Teaching reflection',
    subtitle: 'Give management concise, practical information for next term.',
    child: Column(
      children: reflectionQuestions.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _reflection[e.key],
                enabled: !_locked,
                maxLines: e.key == 'personalCircumstances' ? 2 : 3,
                decoration: InputDecoration(
                  labelText: e.value,
                  alignLabelWithHint: true,
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
  Widget _damageSection() => _Section(
    title: 'Loss and damage',
    subtitle:
        'All known loss or damage must be recorded through Incident Management.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _damage,
          onChanged: _locked
              ? null
              : (v) => setState(() => _damage = v == true),
          title: const Text(
            'I confirm that all known losses and damages have been reported.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.onOpenIncidents,
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('Report loss or damage'),
        ),
      ],
    ),
  );
  Widget _recommendationSection() => _Section(
    title: 'Recommendations for next term',
    subtitle:
        'Recommend student, classroom, or teacher items. Prices are estimates only.',
    child: Column(
      children: [
        for (final entry in _recommendations.asMap().entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              entry.value.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${entry.value.category} · Qty ${entry.value.quantity} · GH₵${entry.value.unitPrice.toStringAsFixed(2)}\n${entry.value.reason}',
            ),
            isThreeLine: true,
            trailing: _locked
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        setState(() => _recommendations.removeAt(entry.key)),
                  ),
          ),
        if (!_locked)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addRecommendation,
              icon: const Icon(Icons.add),
              label: const Text('Add recommendation'),
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _recommendationsFinal,
          onChanged: _locked
              ? null
              : (value) =>
                    setState(() => _recommendationsFinal = value == true),
          title: const Text(
            'My recommendations are ready for bursar review.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  Widget _leadershipSection() => _Section(
    title: 'Confidential headmaster assessment',
    subtitle:
        'Individual answers are not shown to the headmaster. Serious concerns are restricted and escalated.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...leadershipQuestions.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
              value: _leadership[e.key],
              decoration: InputDecoration(labelText: e.value),
              items: _options(
                e.key,
              ).map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: _locked
                  ? null
                  : (v) => setState(() => _leadership[e.key] = v!),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _serious,
          onChanged: _locked ? null : (v) => setState(() => _serious = v),
          title: const Text(
            'Report a serious concern',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.red),
          ),
          subtitle: const Text(
            'This will be restricted and escalated outside the normal headmaster summary.',
          ),
        ),
        if (_serious)
          TextField(
            controller: _concern,
            enabled: !_locked,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Serious concern details *',
              alignLabelWithHint: true,
            ),
          ),
      ],
    ),
  );
  List<String> _options(String key) => key == 'demonstration'
      ? ['Frequently', 'Sometimes', 'Rarely', 'Never', 'Not applicable']
      : key == 'safe' || key == 'speakFreely'
      ? ['Yes', 'Mostly', 'Sometimes', 'No', 'Prefer not to answer']
      : [
          'Excellent',
          'Good',
          'Satisfactory',
          'Needs improvement',
          'Poor',
          'Prefer not to answer',
        ];
  Future<void> _addRecommendation() async {
    final value = await showDialog<NextTermRecommendation>(
      context: context,
      builder: (_) => const _RecommendationDialog(),
    );
    if (value != null) setState(() => _recommendations.add(value));
  }

  TeacherTermReviewInput get _input => TeacherTermReviewInput(
    reflection: _reflection.map((k, v) => MapEntry(k, v.text.trim())),
    leadership: _leadership,
    recommendations: _recommendations,
    damageConfirmed: _damage,
    recommendationsSubmitted: _recommendationsFinal,
    seriousConcern: _serious,
    seriousConcernDetails: _concern.text.trim(),
  );
  Future<void> _save(bool submit) async {
    setState(() => _saving = true);
    try {
      final r = submit
          ? await widget.repository.submit(
              widget.schoolId,
              widget.teacherUserId,
              _input,
            )
          : await widget.repository.saveDraft(
              widget.schoolId,
              widget.teacherUserId,
              _input,
            );
      if (mounted) {
        setState(() {
          _review = r;
          _saving = false;
        });
        _msg(submit ? 'Term review submitted.' : 'Draft saved.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _msg('$e', error: true);
      }
    }
  }

  void _msg(String m, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(m),
          backgroundColor: error ? AppColors.red : AppColors.green,
        ),
      );
}

class _RecommendationDialog extends StatefulWidget {
  const _RecommendationDialog();
  @override
  State<_RecommendationDialog> createState() => _RecommendationDialogState();
}

class _RecommendationDialogState extends State<_RecommendationDialog> {
  final n = TextEditingController(),
      d = TextEditingController(),
      q = TextEditingController(text: '1'),
      p = TextEditingController(),
      r = TextEditingController();
  String c = 'Classroom';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add recommendation'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'Item name *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: c,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: [
                'Student item',
                'Classroom',
                'Teacher/teaching',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => c = v!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: d,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: q,
                    decoration: const InputDecoration(labelText: 'Quantity *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: p,
                    decoration: const InputDecoration(
                      labelText: 'Estimated unit price *',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: r,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason needed *'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (n.text.trim().isEmpty ||
              d.text.trim().isEmpty ||
              r.text.trim().isEmpty) {
            return;
          }
          Navigator.pop(
            context,
            NextTermRecommendation(
              name: n.text.trim(),
              category: c,
              description: d.text.trim(),
              quantity: int.tryParse(q.text) ?? 1,
              unitPrice: double.tryParse(p.text) ?? 0,
              reason: r.text.trim(),
            ),
          );
        },
        child: const Text('Add item'),
      ),
    ],
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
    padding: const EdgeInsets.all(22),
    decoration: _card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.detail,
    required this.complete,
    this.onTap,
  });
  final String label, detail;
  final bool complete;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      complete ? Icons.check_circle : Icons.error_outline,
      color: complete ? AppColors.green : AppColors.amber,
    ),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(detail),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

class _Status extends StatelessWidget {
  const _Status(this.s);
  final String s;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      s.replaceAll('_', ' ').toLowerCase(),
      style: const TextStyle(
        color: AppColors.green,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title, message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: _card(),
    child: Row(
      children: [
        Icon(icon, size: 38, color: AppColors.amber),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(message, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

BoxDecoration _card() => BoxDecoration(
  color: Colors.white,
  border: Border.all(color: AppColors.border),
  borderRadius: BorderRadius.circular(16),
);
