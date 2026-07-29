import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

enum _Route {
  dashboard,
  assessments,
  assessmentDetail,
  assessmentForm,
  scoreSheet,
  evaluations,
  evaluationStudents,
  evaluationForm,
  reportCards,
  studentReport,
  finalReports,
  classes,
  classDetail,
  studentProfile,
  parents,
  parentDetail,
}

class CompleteAssessmentWorkflow extends StatefulWidget {
  const CompleteAssessmentWorkflow({
    super.key,
    required this.schoolName,
    required this.term,
    required this.academicYear,
    this.viewerRole = 'Administrator',
    this.viewerName = 'Eric GoM',
  });

  final String schoolName;
  final String term;
  final String academicYear;
  final String viewerRole;
  final String viewerName;

  @override
  State<CompleteAssessmentWorkflow> createState() =>
      _CompleteAssessmentWorkflowState();
}

class _CompleteAssessmentWorkflowState
    extends State<CompleteAssessmentWorkflow> {
  _Route _route = _Route.dashboard;
  final List<_Route> _history = [];
  _AssessmentRecord? _selectedAssessment;
  _StudentRecord? _selectedStudent;
  _ParentRecord? _selectedParent;
  _StudentRecord? _selectedEvaluationStudent;
  _StudentRecord? _selectedReportStudent;
  String _selectedClass = 'Grade 5 - Stream A';
  bool _editingAssessment = false;
  String _assessmentQuery = '';
  String _assessmentTypeFilter = 'All Types';
  String _assessmentSubjectFilter = 'All Subjects';
  String _assessmentStatusFilter = 'All Statuses';
  String _evaluationQuery = '';
  String _evaluationStatusFilter = 'All Status';
  final Set<String> _selectedEvaluationStudents = {};
  String _finalReportGradeFilter = 'All Grade Levels';
  String _finalReportStreamFilter = 'All Streams';
  String _finalReportFilter = 'All Statuses';
  bool _isPublishingAllReports = false;
  bool _isGeneratingReports = false;
  double _reportGenerationProgress = 0;
  final Map<String, _EvaluationDraft> _evaluationDrafts = {};
  final Map<String, Map<String, double?>> _assessmentScores = {};
  final Map<String, String> _reportStatuses = {};
  final Set<String> _selectedReportStudents = {};
  final Set<String> _processingReportStudents = {};
  final Set<String> _publishingReportStudents = {};
  bool _refreshingReportCards = false;
  final Map<String, _ReportRemarksDraft> _reportRemarks = {
    'STU-24001': _ReportRemarksDraft.completed('Grade 6'),
    'STU-24002': _ReportRemarksDraft.completed('Grade 6'),
    'STU-24004': _ReportRemarksDraft.completed('Grade 6'),
  };
  final Map<String, _ReportAudit> _reportAudit = {
    'STU-24001': _ReportAudit(
      createdBy: 'Sarah Johnson',
      createdAt: '28 Mar 2026 09:15',
      updatedBy: 'Eric GoM',
      updatedAt: '29 Mar 2026 11:40',
    ),
    'STU-24004': _ReportAudit(
      createdBy: 'Sarah Johnson',
      createdAt: '27 Mar 2026 14:10',
      updatedBy: 'Michael Mensah',
      updatedAt: '29 Mar 2026 08:25',
    ),
  };
  String _reportCardFilter = 'All Students';
  final List<_FinalReportStream> _finalReportStreams = [
    _FinalReportStream('Grade 5 - A', 'Sarah Johnson', 47, 47, 43, 18),
    _FinalReportStream('Grade 5 - B', 'Michael Brown', 45, 45, 45, 45),
    _FinalReportStream('Basic 4 - A', 'Abena Kofi', 35, 35, 30, 30),
    _FinalReportStream('JHS 2 - A', 'Kweku Mensah', 62, 58, 52, 40),
  ];

  final List<_AssessmentRecord> _assessments = [
    _AssessmentRecord(
      id: 'ASS-001',
      title: 'CAT 1 – Number & Algebra',
      type: 'CAT 1',
      subject: 'Mathematics',
      date: '17 Jan 2024',
      maxScore: 30,
      entered: 47,
      totalStudents: 47,
      average: 22.4,
      passRate: 85.1,
      status: 'Graded',
      grading: 'Complete',
      curriculumIndicators: const [
        _CurriculumIndicator(
          code: 'B5.1.1.1',
          text:
              'Count, read and write numbers up to 10,000 in numerals and words.',
          strand: 'Number',
          subStrand: 'Counting & Place Value',
        ),
        _CurriculumIndicator(
          code: 'B5.1.2.1',
          text:
              'Use letters and symbols to represent unknown numbers in simple equations.',
          strand: 'Number',
          subStrand: 'Algebra',
        ),
        _CurriculumIndicator(
          code: 'B5.1.3.2',
          text: 'Solve multi-step word problems involving all four operations.',
          strand: 'Number',
          subStrand: 'Operations',
        ),
      ],
    ),
    _AssessmentRecord(
      id: 'ASS-002',
      title: 'CAT 2 – Geometry',
      type: 'CAT 2',
      subject: 'Mathematics',
      date: '04 Mar 2024',
      maxScore: 30,
      entered: 0,
      totalStudents: 47,
      average: 0,
      passRate: 0,
      status: 'Open',
      grading: 'Not started',
    ),
    _AssessmentRecord(
      id: 'ASS-003',
      title: 'CAT 1 – Reading Comprehension',
      type: 'CAT 1',
      subject: 'English Language',
      date: '21 Jan 2024',
      maxScore: 40,
      entered: 47,
      totalStudents: 47,
      average: 31.7,
      passRate: 91.5,
      status: 'Graded',
      grading: 'Complete',
    ),
    _AssessmentRecord(
      id: 'ASS-004',
      title: 'Environmental Science Project',
      type: 'Project',
      subject: 'Integrated Science',
      date: '13 Feb 2024',
      maxScore: 50,
      entered: 38,
      totalStudents: 47,
      average: 40.2,
      passRate: 78.9,
      status: 'Pending Review',
      grading: '38 of 47',
    ),
    _AssessmentRecord(
      id: 'ASS-005',
      title: 'End of Term Exam',
      type: 'End of Term',
      subject: 'Mathematics',
      date: '19 Mar 2024',
      maxScore: 100,
      entered: 47,
      totalStudents: 47,
      average: 68.3,
      passRate: 74.5,
      status: 'Closed',
      grading: 'Complete',
    ),
  ];

  final List<_StudentRecord> _students = [
    const _StudentRecord(
      id: 'STU-24001',
      name: 'Ama Boateng',
      gender: 'Female',
      average: 89,
      grade: 'A',
      readiness: 'Ready',
      reportStatus: 'Generated',
      parent: 'Mr. Kofi Boateng',
    ),
    const _StudentRecord(
      id: 'STU-24002',
      name: 'Kwame Asante',
      gender: 'Male',
      average: 82,
      grade: 'B',
      readiness: 'Ready',
      reportStatus: 'Draft',
      parent: 'Mrs. Adwoa Asante',
    ),
    const _StudentRecord(
      id: 'STU-24003',
      name: 'Abena Mensah',
      gender: 'Female',
      average: 78,
      grade: 'B',
      readiness: 'Missing remark',
      reportStatus: 'Not generated',
      parent: 'Mr. Kojo Mensah',
    ),
    const _StudentRecord(
      id: 'STU-24004',
      name: 'Yaw Darko',
      gender: 'Male',
      average: 74,
      grade: 'C',
      readiness: 'Ready',
      reportStatus: 'Published',
      parent: 'Mrs. Akua Darko',
    ),
    const _StudentRecord(
      id: 'STU-24005',
      name: 'Nana Owusu',
      gender: 'Male',
      average: 68,
      grade: 'C',
      readiness: 'Scores incomplete',
      reportStatus: 'Not generated',
      parent: 'Mr. Daniel Owusu',
    ),
  ];

  late final List<_ParentRecord> _parents = [
    _ParentRecord(
      id: 'PAR-001',
      name: 'Mr. Kofi Boateng',
      phone: '024 456 7890',
      email: 'kofi.boateng@example.com',
      children: [_students[0]],
    ),
    _ParentRecord(
      id: 'PAR-002',
      name: 'Mrs. Adwoa Asante',
      phone: '020 234 5678',
      email: 'adwoa.asante@example.com',
      children: [_students[1]],
    ),
    _ParentRecord(
      id: 'PAR-003',
      name: 'Mr. Kojo Mensah',
      phone: '055 890 1234',
      email: 'kojo.mensah@example.com',
      children: [_students[2]],
    ),
  ];

  void _open(_Route route) {
    setState(() {
      _history.add(_route);
      _route = route;
    });
  }

  void _back() {
    if (_history.isEmpty) {
      setState(() => _route = _Route.dashboard);
      return;
    }
    setState(() => _route = _history.removeLast());
  }

  void _openAssessment(_AssessmentRecord assessment) {
    _selectedAssessment = assessment;
    _open(_Route.assessmentDetail);
  }

  void _duplicateAssessment(_AssessmentRecord source) {
    final copy = _AssessmentRecord(
      id: 'ASS-${DateTime.now().millisecondsSinceEpoch}',
      title: '${source.title} (Copy)',
      type: source.type,
      subject: source.subject,
      date: source.date,
      maxScore: source.maxScore,
      entered: 0,
      totalStudents: source.totalStudents,
      average: 0,
      passRate: 0,
      status: 'Open',
      grading: 'Not started',
      description: source.description,
      term: source.term,
      academicYear: source.academicYear,
      officialSba: source.officialSba,
      curriculumIndicators: List.of(source.curriculumIndicators),
    );
    setState(() {
      _assessments.insert(0, copy);
      _selectedAssessment = copy;
    });
    _notice('Assessment duplicated.');
  }

  Future<void> _deleteAssessment(_AssessmentRecord assessment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete assessment?'),
        content: Text(
          '“${assessment.title}” and its saved scores will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _assessments.remove(assessment);
      _assessmentScores.remove(assessment.id);
      _selectedAssessment = null;
    });
    _back();
    _notice('Assessment deleted.');
  }

  Future<void> _showAssessmentReadiness() {
    final withoutScores = _assessments.where((a) => a.entered == 0).length;
    final incomplete = _assessments
        .where((a) => a.entered > 0 && a.entered < a.totalStudents)
        .length;
    final complete = _assessments
        .where((a) => a.entered == a.totalStudents)
        .length;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Assessment Readiness'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _readinessRow(
                Icons.check_circle_outline,
                'Complete',
                '$complete assessments have all scores entered',
                AppColors.green,
              ),
              _readinessRow(
                Icons.pending_actions_outlined,
                'In progress',
                '$incomplete assessments have missing scores',
                Colors.orange,
              ),
              _readinessRow(
                Icons.warning_amber_outlined,
                'Not started',
                '$withoutScores assessments have no scores',
                Colors.red,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _readinessRow(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    );
  }

  void _openStudent(_StudentRecord student) {
    _selectedStudent = student;
    _open(_Route.studentProfile);
  }

  void _openParent(_ParentRecord parent) {
    _selectedParent = parent;
    _open(_Route.parentDetail);
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectClass(String action) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ClassSelectorDialog(action: action),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedClass = result);
    switch (action) {
      case 'Enter Assessment':
        _editingAssessment = false;
        _open(_Route.assessmentForm);
      case 'Manage Assessments':
        _open(_Route.assessments);
      case 'Generate Report Cards':
        _open(_Route.reportCards);
      case 'Final Reports':
        _open(_Route.finalReports);
      case 'Student Evaluations':
        _open(_Route.evaluationStudents);
      default:
        _open(_Route.evaluations);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: switch (_route) {
        _Route.dashboard => _dashboard(),
        _Route.assessments => _assessmentRegister(),
        _Route.assessmentDetail => _assessmentDetail(),
        _Route.assessmentForm => _assessmentForm(),
        _Route.scoreSheet => _scoreSheet(),
        _Route.evaluations => _evaluationStudents(),
        _Route.evaluationStudents => _evaluationStudents(),
        _Route.evaluationForm => _evaluationForm(),
        _Route.reportCards => _reportCards(),
        _Route.studentReport => _studentReportPage(),
        _Route.finalReports => _finalReports(),
        _Route.classes => _classes(),
        _Route.classDetail => _classDetail(),
        _Route.studentProfile => _studentProfile(),
        _Route.parents => _parentsPage(),
        _Route.parentDetail => _parentDetail(),
      },
    );
  }

  Widget _page({
    required String title,
    required String subtitle,
    required List<Widget> children,
    List<Widget> actions = const [],
    bool showBack = true,
    bool compactHeader = false,
    double maxContentWidth = 1480,
    double pagePadding = 24,
  }) {
    return SingleChildScrollView(
      key: ValueKey('workflow-page-${_route.name}'),
      padding: EdgeInsets.all(pagePadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack) ...[
                    IconButton(
                      tooltip: 'Back',
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: compactHeader ? 20 : 27,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Wrap(spacing: 10, runSpacing: 8, children: actions),
                ],
              ),
              SizedBox(height: compactHeader ? 14 : 20),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboard() {
    return _page(
      title: 'Assessment Dashboard',
      subtitle: '${widget.term} - ${widget.academicYear} Academic Year',
      showBack: false,
      actions: [
        _outlineButton(
          'Classes',
          Icons.school_outlined,
          () => _open(_Route.classes),
        ),
        _outlineButton(
          'Parents',
          Icons.family_restroom_outlined,
          () => _open(_Route.parents),
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (_, constraints) => _statGrid(constraints.maxWidth, const [
            ('TOTAL STUDENTS', '580', 'Across 18 active classes'),
            ('ACTIVE ASSESSMENTS', '78', '15 pending review'),
            ('AVG SBA SCORE', '75.8%', '+2.4% from last term'),
            ('COMPLETION', '84%', '487 of 580 complete'),
          ]),
        ),
        const SizedBox(height: 18),
        _section(
          title: 'Quick Actions',
          child: LayoutBuilder(
            builder: (_, c) {
              final width = c.maxWidth >= 1000
                  ? (c.maxWidth - 36) / 4
                  : c.maxWidth >= 620
                  ? (c.maxWidth - 12) / 2
                  : c.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _actionCard(
                    width,
                    'Enter Assessment',
                    'Create and enter student scores',
                    Icons.edit_note_outlined,
                    AppColors.green,
                    () => _selectClass('Enter Assessment'),
                  ),
                  _actionCard(
                    width,
                    'Manage Assessments',
                    'View, edit and grade assessments',
                    Icons.assignment_outlined,
                    AppColors.blue,
                    () => _selectClass('Manage Assessments'),
                  ),
                  _actionCard(
                    width,
                    'Student Evaluations',
                    'Record terminal conduct',
                    Icons.fact_check_outlined,
                    AppColors.amber,
                    () => _selectClass('Student Evaluations'),
                  ),
                  _actionCard(
                    width,
                    'Generate Report Cards',
                    'Review readiness and publish',
                    Icons.description_outlined,
                    AppColors.purple,
                    () => _selectClass('Generate Report Cards'),
                  ),
                  _actionCard(
                    width,
                    'Final Reports',
                    'Manage reports across grades and streams',
                    Icons.inventory_2_outlined,
                    AppColors.green,
                    () => _selectClass('Final Reports'),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (_, c) {
            final stacked = c.maxWidth < 920;
            final recent = _section(
              title: 'Recent Assessments',
              action: TextButton(
                onPressed: () => _open(_Route.assessments),
                child: const Text('View all'),
              ),
              child: Column(
                children: _assessments
                    .take(4)
                    .map(
                      (a) => _listTile(
                        title: a.title,
                        subtitle:
                            '${a.subject} - ${a.entered}/${a.totalStudents} scores entered',
                        badge: a.status,
                        onTap: () => _openAssessment(a),
                      ),
                    )
                    .toList(),
              ),
            );
            final completion = _section(
              title: 'Assessment Completion',
              child: const Column(
                children: [
                  _ProgressRow('Completed', 487, 580, AppColors.green),
                  _ProgressRow('In progress', 68, 580, AppColors.amber),
                  _ProgressRow('Not started', 25, 580, AppColors.red),
                ],
              ),
            );
            return stacked
                ? Column(
                    children: [recent, const SizedBox(height: 16), completion],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: recent),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: completion),
                    ],
                  );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (_, c) {
            final stacked = c.maxWidth < 920;
            final performance = _section(
              title: 'Performance by Grade',
              child: const Column(
                children: [
                  _ProgressRow('Kindergarten', 84, 100, AppColors.purple),
                  _ProgressRow('Basic 1-3', 79, 100, AppColors.green),
                  _ProgressRow('Basic 4-6', 76, 100, AppColors.blue),
                  _ProgressRow('JHS 1-3', 72, 100, AppColors.amber),
                ],
              ),
            );
            final activity = _section(
              title: 'Recent Activity',
              child: Column(
                children: [
                  _activityRow(
                    'Sarah Johnson',
                    'Completed Mathematics CAT 1 for Grade 5 - 47 students',
                    'Today, 10:42 AM',
                  ),
                  _activityRow(
                    'Michael Brown',
                    'Started English assessment for JHS 2 - 62 students',
                    'Yesterday, 3:18 PM',
                  ),
                  _activityRow(
                    'Abena Kofi',
                    'Generated 35 report cards for Basic 4',
                    '24 Feb, 1:05 PM',
                  ),
                ],
              ),
            );
            return stacked
                ? Column(
                    children: [
                      performance,
                      const SizedBox(height: 16),
                      activity,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: performance),
                      const SizedBox(width: 16),
                      Expanded(child: activity),
                    ],
                  );
          },
        ),
        const SizedBox(height: 18),
        _section(
          title: 'Students Needing Attention',
          child: Column(
            children: [
              _attentionRow(
                'Abena Mensah',
                '3 assessment scores are missing',
                'Review scores',
              ),
              _attentionRow(
                'Nana Owusu',
                'Class teacher remark is incomplete',
                'Add remark',
              ),
              _attentionRow(
                'Daniel Ofori',
                'Average dropped by 14% this term',
                'View student',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _assessmentRegister() {
    final visibleAssessments = _assessments.where((assessment) {
      final query = _assessmentQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          assessment.title.toLowerCase().contains(query) ||
          assessment.id.toLowerCase().contains(query);
      final matchesType =
          _assessmentTypeFilter == 'All Types' ||
          assessment.type == _assessmentTypeFilter;
      final matchesSubject =
          _assessmentSubjectFilter == 'All Subjects' ||
          assessment.subject == _assessmentSubjectFilter;
      final matchesStatus =
          _assessmentStatusFilter == 'All Statuses' ||
          assessment.status == _assessmentStatusFilter;
      return matchesQuery && matchesType && matchesSubject && matchesStatus;
    }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _back,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.chevron_left,
                              size: 17,
                              color: Color(0xFF009688),
                            ),
                            Text(
                              'Dashboard',
                              style: TextStyle(
                                color: Color(0xFF009688),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '/',
                          style: TextStyle(color: Color(0xFFD1D5DB)),
                        ),
                      ),
                      const Text(
                        'Assessments',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDFF7F4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Grade 1 • Stream B',
                          style: const TextStyle(
                            color: Color(0xFF009688),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${widget.term} • ${widget.academicYear}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showAssessmentReadiness,
                    icon: const Icon(Icons.fact_check_outlined, size: 15),
                    label: const Text('Check Readiness'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      _editingAssessment = false;
                      _open(_Route.assessmentForm);
                    },
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('New Assessment'),
                  ),
                ],
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 12), actions],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: title),
                        actions,
                      ],
                    );
            },
          ),
          const SizedBox(height: 15),
          _assessmentFilterBar(),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: visibleAssessments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No assessments match the selected filters.',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 36,
                        dataRowMinHeight: 54,
                        dataRowMaxHeight: 62,
                        horizontalMargin: 15,
                        columnSpacing: 34,
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF9FAFB),
                        ),
                        headingTextStyle: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4,
                        ),
                        columns: const [
                          DataColumn(label: Text('ASSESSMENT')),
                          DataColumn(label: Text('TYPE')),
                          DataColumn(label: Text('SUBJECT')),
                          DataColumn(label: Text('DATE')),
                          DataColumn(label: Text('MAX SCORE')),
                          DataColumn(label: Text('SCORE ENTRY')),
                          DataColumn(label: Text('AVG SCORE')),
                          DataColumn(label: Text('PASS RATE')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('GRADING')),
                        ],
                        rows: visibleAssessments
                            .map((assessment) => _oldAssessmentRow(assessment))
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _assessmentFilterBar() {
    Widget filter(
      String value,
      List<String> items,
      ValueChanged<String?> onChanged,
    ) {
      return SizedBox(
        width: 142,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            onChanged: (value) => setState(() => _assessmentQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        filter(
          _assessmentTypeFilter,
          const ['All Types', 'CAT 1', 'CAT 2', 'Project', 'End of Term'],
          (value) => setState(() => _assessmentTypeFilter = value!),
        ),
        filter(
          _assessmentSubjectFilter,
          const [
            'All Subjects',
            'Mathematics',
            'English Language',
            'Integrated Science',
            'Social Studies',
          ],
          (value) => setState(() => _assessmentSubjectFilter = value!),
        ),
        filter(
          _assessmentStatusFilter,
          const ['All Statuses', 'Open', 'Graded', 'Pending Review', 'Closed'],
          (value) => setState(() => _assessmentStatusFilter = value!),
        ),
      ],
    );
  }

  DataRow _oldAssessmentRow(_AssessmentRecord assessment) {
    final progress = assessment.totalStudents == 0
        ? 0.0
        : assessment.entered / assessment.totalStudents;
    final gradingLabel = assessment.entered == 0
        ? 'Not Started'
        : assessment.entered == assessment.totalStudents
        ? 'Complete'
        : 'Partial';
    return DataRow(
      onSelectChanged: (_) => _openAssessment(assessment),
      cells: [
        DataCell(
          SizedBox(
            width: 260,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  assessment.id,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          _oldRegisterBadge(
            assessment.type,
            assessment.type == 'Project'
                ? const Color(0xFFF3E8FF)
                : assessment.type == 'End of Term'
                ? const Color(0xFFFFF1E8)
                : const Color(0xFFEFF6FF),
            assessment.type == 'Project'
                ? const Color(0xFF7C3AED)
                : assessment.type == 'End of Term'
                ? const Color(0xFFEA580C)
                : const Color(0xFF2563EB),
          ),
        ),
        DataCell(SizedBox(width: 150, child: Text(assessment.subject))),
        DataCell(SizedBox(width: 105, child: Text(assessment.date))),
        DataCell(
          Text(
            '${assessment.maxScore}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(
          SizedBox(
            width: 125,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: const Color(0xFF009688),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${assessment.entered}/${assessment.totalStudents}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          Text(
            assessment.average == 0
                ? '—'
                : assessment.average.toStringAsFixed(1),
            style: TextStyle(
              color: assessment.average == 0
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Text(
            assessment.passRate == 0
                ? '—'
                : '${assessment.passRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: assessment.passRate == 0
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF009688),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          _oldRegisterBadge(
            assessment.status,
            assessment.status == 'Open'
                ? const Color(0xFFDFF7EC)
                : assessment.status == 'Pending Review'
                ? const Color(0xFFFFF4D8)
                : assessment.status == 'Closed'
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFEFF6FF),
            assessment.status == 'Open'
                ? const Color(0xFF047857)
                : assessment.status == 'Pending Review'
                ? const Color(0xFFB45309)
                : assessment.status == 'Closed'
                ? const Color(0xFF475569)
                : const Color(0xFF2563EB),
          ),
        ),
        DataCell(
          _oldRegisterBadge(
            gradingLabel,
            gradingLabel == 'Not Started'
                ? const Color(0xFFFEF2F2)
                : gradingLabel == 'Partial'
                ? const Color(0xFFFFF7E6)
                : const Color(0xFFDFF7EC),
            gradingLabel == 'Not Started'
                ? const Color(0xFFDC2626)
                : gradingLabel == 'Partial'
                ? const Color(0xFFB45309)
                : const Color(0xFF047857),
          ),
        ),
      ],
    );
  }

  Widget _oldRegisterBadge(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _assessmentDetail() {
    final a = _selectedAssessment ?? _assessments.first;
    final savedScores =
        _assessmentScores[a.id]?.values.whereType<double>().toList() ??
        const <double>[];
    final highest = savedScores.isEmpty
        ? (a.average == 0 ? '—' : '29')
        : savedScores.reduce((x, y) => x > y ? x : y).toStringAsFixed(1);
    final lowest = savedScores.isEmpty
        ? (a.average == 0 ? '—' : '11')
        : savedScores.reduce((x, y) => x < y ? x : y).toStringAsFixed(1);
    final progress = a.totalStudents == 0 ? 0.0 : a.entered / a.totalStudents;
    void edit() {
      _editingAssessment = true;
      _open(_Route.assessmentForm);
    }

    void scores() => _open(_Route.scoreSheet);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _back,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left,
                              size: 18,
                              color: Color(0xFF009688),
                            ),
                            Text(
                              'Assessments',
                              style: TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_selectedClass • ${a.subject} • ${a.term} • ${a.academicYear.replaceAll(' Academic Year', '')}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: scores,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('View Score Sheet'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: edit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit Assessment'),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 14),
                            actions,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: heading),
                            actions,
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 920;
                  final left = Column(
                    children: [
                      _oldDetailCard(
                        title: 'Assessment Information',
                        child: LayoutBuilder(
                          builder: (_, cardConstraints) {
                            final fields = <Widget>[
                              _oldInfoField('Assessment ID', a.id, mono: true),
                              _oldInfoField('Title', a.title),
                              _oldInfoField(
                                'Type',
                                a.type,
                                badgeColor: const Color(0xFFEFF6FF),
                              ),
                              _oldInfoField(
                                'Status',
                                a.status,
                                badgeColor: const Color(0xFFEFF6FF),
                              ),
                              _oldInfoField('Date Given', a.date),
                              _oldInfoField(
                                'Max Score',
                                '${a.maxScore}',
                                valueColor: const Color(0xFF009688),
                                large: true,
                              ),
                              _oldInfoField('Grade Level', 'Grade 5'),
                              _oldInfoField('Stream', 'Stream A'),
                              _oldInfoField('Subject', a.subject),
                              _oldInfoField(
                                'Term & Year',
                                '${a.term} • ${a.academicYear.replaceAll(' Academic Year', '')}',
                              ),
                              _oldInfoField('Created By', 'Sarah Johnson'),
                              _oldInfoField(
                                'Last Updated',
                                '01 Feb 2024 10:30',
                              ),
                            ];
                            final width = cardConstraints.maxWidth < 600
                                ? cardConstraints.maxWidth
                                : (cardConstraints.maxWidth - 24) / 2;
                            return Wrap(
                              spacing: 24,
                              runSpacing: 14,
                              children: fields
                                  .map(
                                    (field) =>
                                        SizedBox(width: width, child: field),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _oldDetailCard(
                        title: 'Curriculum Indicators',
                        count: a.curriculumIndicators.length,
                        child: a.curriculumIndicators.isEmpty
                            ? const Text(
                                'No curriculum indicators linked.',
                                style: TextStyle(color: Color(0xFF9CA3AF)),
                              )
                            : Column(
                                children: a.curriculumIndicators
                                    .map(
                                      (indicator) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: _oldIndicatorRow(indicator),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  );
                  final right = Column(
                    children: [
                      _oldDetailCard(
                        title: 'Score Statistics',
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _oldStat(
                                    'Avg Score',
                                    a.average == 0
                                        ? '—'
                                        : a.average.toStringAsFixed(1),
                                    const Color(0xFF009688),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _oldStat(
                                    'Pass Rate',
                                    a.passRate == 0
                                        ? '—'
                                        : '${a.passRate.toStringAsFixed(1)}%',
                                    const Color(0xFF009688),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _oldStat(
                                    'Highest',
                                    highest,
                                    const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _oldStat(
                                    'Lowest',
                                    lowest,
                                    const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Score Entry',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${(progress * 100).round()}%',
                                        style: const TextStyle(
                                          color: Color(0xFF009688),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress.clamp(0, 1),
                                    minHeight: 7,
                                    borderRadius: BorderRadius.circular(5),
                                    backgroundColor: const Color(0xFFE5E7EB),
                                    color: const Color(0xFF009688),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        '${a.entered} entered',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${a.totalStudents} total',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Grading Status',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _oldBadge(
                                a.grading,
                                const Color(0xFFDFF7EC),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _oldDetailCard(
                        title: 'Record Info',
                        child: Column(
                          children: [
                            _oldMetaRow('Grade Level ID', '5'),
                            _oldMetaRow('Stream ID', '1'),
                            _oldMetaRow('Subject ID', '1'),
                            _oldMetaRow('Created At', '10 Jan 2024 08:00'),
                            _oldMetaRow('Updated At', '01 Feb 2024 10:30'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _oldActionsCard(a, scores, edit),
                    ],
                  );
                  if (narrow) {
                    return Column(
                      children: [left, const SizedBox(height: 16), right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: left),
                      const SizedBox(width: 16),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oldDetailCard({
    required String title,
    required Widget child,
    int? count,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                _oldBadge('$count', const Color(0xFFDFF7F4)),
              ],
              const SizedBox(width: 10),
              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _oldInfoField(
    String label,
    String value, {
    bool mono = false,
    Color? badgeColor,
    Color? valueColor,
    bool large = false,
  }) {
    final text = Text(
      value,
      style: TextStyle(
        color: valueColor ?? const Color(0xFF111827),
        fontFamily: mono ? 'monospace' : null,
        fontSize: large ? 20 : 13,
        fontWeight: large ? FontWeight.w800 : FontWeight.w600,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 3),
        if (badgeColor == null)
          text
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: text,
          ),
      ],
    );
  }

  Widget _oldStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _oldIndicatorRow(_CurriculumIndicator indicator) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFECFAF7),
        border: Border.all(color: const Color(0xFFB8EAE2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text('🎯', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  indicator.code,
                  style: const TextStyle(
                    color: Color(0xFF009688),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  indicator.text,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${indicator.strand} › ${indicator.subStrand}',
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _oldMetaRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _oldBadge(String text, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF087F6F),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _oldActionsCard(
    _AssessmentRecord assessment,
    VoidCallback scores,
    VoidCallback edit,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: scores,
              icon: const Icon(Icons.table_chart, size: 16),
              label: const Text('View Score Sheet'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: edit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Assessment'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _notice('Assessment report generated.'),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('Generate Report'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _duplicateAssessment(assessment),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Duplicate'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _deleteAssessment(assessment),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _assessmentForm() {
    final source = _editingAssessment ? _selectedAssessment : null;
    return _AssessmentFormPage(
      title: _editingAssessment ? 'Edit Assessment' : 'New Assessment',
      subtitle: _selectedClass,
      source: source,
      onBack: _back,
      onCurriculum: _showCurriculumDrawer,
      onSave: (record) {
        setState(() {
          if (_editingAssessment && _selectedAssessment != null) {
            final index = _assessments.indexOf(_selectedAssessment!);
            _assessments[index] = record;
          } else {
            _assessments.insert(0, record);
          }
          _selectedAssessment = record;
        });
        _notice(
          _editingAssessment
              ? 'Assessment changes saved.'
              : 'Assessment created.',
        );
        _back();
      },
    );
  }

  Widget _scoreSheet() {
    final a = _selectedAssessment ?? _assessments.first;
    return _ScoreSheetPage(
      assessment: a,
      students: _students,
      initialScores: _assessmentScores[a.id],
      onBack: _back,
      onExport: (csv) async {
        await Clipboard.setData(ClipboardData(text: csv));
        if (!mounted) return;
        _notice('Score sheet CSV copied to the clipboard.');
      },
      onSave: (scores) {
        setState(() {
          _assessmentScores[a.id] = Map.of(scores);
          a.entered = scores.values.where((value) => value != null).length;
          final valid = scores.values.whereType<double>().toList();
          a.average = valid.isEmpty
              ? 0
              : valid.reduce((x, y) => x + y) / valid.length;
          final passing = valid
              .where((score) => score / a.maxScore >= 0.5)
              .length;
          a.passRate = valid.isEmpty ? 0 : passing * 100 / valid.length;
          a.grading = a.entered == 0
              ? 'Not started'
              : a.entered == a.totalStudents
              ? 'Complete'
              : '${a.entered} of ${a.totalStudents}';
          if (a.status != 'Closed') {
            a.status = a.entered == a.totalStudents ? 'Graded' : 'Open';
          }
        });
        _notice('Scores saved successfully.');
      },
    );
  }

  _EvaluationDraft _evaluationFor(_StudentRecord student) {
    final index = _students.indexOf(student);
    const initialScores = [8.5, 7.2, 9.1, 6.8, null];
    const evaluatedDates = [
      'Today',
      'Today',
      'Yesterday',
      'Yesterday',
      'Never',
    ];
    return _evaluationDrafts.putIfAbsent(
      student.id,
      () => _EvaluationDraft(
        homework: 9,
        punctuality: 10,
        neatness: 8,
        attitude: 9,
        discipline: 8,
        organization: 8,
        status: index < 4 ? 'Submitted' : 'Not started',
        displayScore: initialScores[index],
        lastEvaluated: evaluatedDates[index],
      ),
    );
  }

  void _openEvaluation(_StudentRecord student) {
    setState(() => _selectedEvaluationStudent = student);
    _open(_Route.evaluationForm);
  }

  // Kept only as a reference while the direct-to-class evaluation flow is
  // migrated; it is intentionally not reachable from navigation.
  // ignore: unused_element
  Widget _evaluations() {
    final submitted = _students
        .where((student) => _evaluationFor(student).status == 'Submitted')
        .length;
    final drafts = _students
        .where((student) => _evaluationFor(student).status == 'Draft')
        .length;
    final notStarted = _students.length - submitted - drafts;
    return _page(
      title: 'Student Evaluations',
      subtitle: '${widget.term} - Conduct and terminal evaluation',
      actions: [
        _filledButton(
          'Evaluate by Student',
          Icons.rate_review_outlined,
          () => _open(_Route.evaluationStudents),
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (_, c) => _statGrid(c.maxWidth, [
            ('STUDENTS', '${_students.length}', 'In $_selectedClass'),
            ('COMPLETED', '$submitted', 'Submitted evaluations'),
            ('IN PROGRESS', '$drafts', 'Saved as draft'),
            ('NOT STARTED', '$notStarted', 'Awaiting evaluation'),
          ]),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Classes',
          child: LayoutBuilder(
            builder: (context, constraints) {
              const classes = [
                ('Basic 1 • Stream A', '5 students', '1 pending'),
                ('Basic 1 • Stream B', '5 students', '2 pending'),
                ('Basic 1 • new stream', '5 students', '1 pending'),
              ];
              final columns = constraints.maxWidth < 680 ? 1 : 3;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: classes
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedClass = item.$1);
                            _open(_Route.evaluationStudents);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F7F5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.groups_outlined,
                                    color: Color(0xFF009688),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.$1,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${item.$2} • ${item.$3}',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Current term progress',
          action: TextButton(
            onPressed: () => _open(_Route.evaluationStudents),
            child: const Text('Open evaluation queue'),
          ),
          child: Column(
            children: [
              _ProgressRow(
                'Submitted evaluations',
                submitted,
                _students.length,
                AppColors.green,
              ),
              const SizedBox(height: 12),
              _ProgressRow(
                'Draft evaluations',
                drafts,
                _students.length,
                Colors.orange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Recent evaluations',
          child: Column(
            children: _students.take(3).map((student) {
              final evaluation = _evaluationFor(student);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(student.initials)),
                title: Text(student.name),
                subtitle: Text(
                  'Conduct average ${evaluation.average.toStringAsFixed(1)}/10',
                ),
                trailing: _Pill(evaluation.status),
                onTap: () => _openEvaluation(student),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _evaluationStudents() {
    final filteredStudents = _students.where((student) {
      final evaluation = _evaluationFor(student);
      final query = _evaluationQuery.trim().toLowerCase();
      final evaluated = evaluation.status == 'Submitted';
      final matchesSearch =
          query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query);
      final matchesStatus =
          _evaluationStatusFilter == 'All Status' ||
          (_evaluationStatusFilter == 'Evaluated' && evaluated) ||
          (_evaluationStatusFilter == 'Pending' && !evaluated);
      return matchesSearch && matchesStatus;
    }).toList();
    final pending = _students
        .where((student) => _evaluationFor(student).status != 'Submitted')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: _back,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left,
                        size: 17,
                        color: Color(0xFF009688),
                      ),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: Color(0xFF009688),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text('/', style: TextStyle(color: Color(0xFFD1D5DB))),
                Text(
                  _selectedClass,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pending == 0
                        ? 'Evaluations Complete'
                        : 'Pending Evaluations',
                    style: const TextStyle(
                      color: Color(0xFF009688),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: _evaluationFilterRow(),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: filteredStudents
                        .map((student) => _mobileEvaluationRow(student))
                        .toList(),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowHeight: 42,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 64,
                      horizontalMargin: 10,
                      columnSpacing: 48,
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF9FAFB),
                      ),
                      headingTextStyle: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      columns: const [
                        DataColumn(label: Text('STUDENT')),
                        DataColumn(label: Text('CLASS')),
                        DataColumn(label: Text('CURRENT SCORE')),
                        DataColumn(label: Text('STATUS')),
                        DataColumn(label: Text('LAST EVALUATED')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: filteredStudents
                          .map((student) => _evaluationDataRow(student))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _evaluationFilterRow() {
    Widget dropdown(
      String value,
      List<String> values,
      ValueChanged<String?> onChanged,
    ) {
      return SizedBox(
        width: 190,
        child: DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          items: values
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        dropdown(
          _evaluationStatusFilter,
          const ['All Status', 'Evaluated', 'Pending'],
          (value) => setState(() => _evaluationStatusFilter = value!),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            onChanged: (value) => setState(() => _evaluationQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search students...',
              prefixIcon: Icon(Icons.search, size: 17),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _evaluationDataRow(_StudentRecord student) {
    final evaluation = _evaluationFor(student);
    final evaluated = evaluation.status == 'Submitted';
    return DataRow(
      selected: _selectedEvaluationStudents.contains(student.id),
      onSelectChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedEvaluationStudents.add(student.id);
          } else {
            _selectedEvaluationStudents.remove(student.id);
          }
        });
      },
      cells: [
        DataCell(
          SizedBox(
            width: 300,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFF009688),
                  child: Text(
                    student.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'ID: ${student.id}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        DataCell(SizedBox(width: 160, child: Text(_selectedClass))),
        DataCell(_evaluationScoreBadge(evaluation.displayScore)),
        DataCell(_evaluationStatus(evaluated)),
        DataCell(SizedBox(width: 140, child: Text(evaluation.lastEvaluated))),
        DataCell(
          SizedBox(
            width: 190,
            child: evaluated
                ? OutlinedButton(
                    onPressed: () => _openEvaluation(student),
                    child: const Text('View/Edit'),
                  )
                : FilledButton(
                    onPressed: () => _openEvaluation(student),
                    child: const Text('Evaluate'),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _evaluationScoreBadge(double? score) {
    if (score == null) {
      return const Text('—', style: TextStyle(color: Color(0xFF9CA3AF)));
    }
    final background = score >= 9
        ? const Color(0xFFECFDF5)
        : score >= 7.5
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFFFFBEB);
    final foreground = score >= 9
        ? const Color(0xFF047857)
        : score >= 7.5
        ? const Color(0xFF1D4ED8)
        : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _evaluationStatus(bool evaluated) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(evaluated ? '✅' : '⏳', style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          evaluated ? 'Evaluated' : 'Pending',
          style: TextStyle(
            color: evaluated
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _mobileEvaluationRow(_StudentRecord student) {
    final evaluation = _evaluationFor(student);
    final evaluated = evaluation.status == 'Submitted';
    return InkWell(
      onTap: () => _openEvaluation(student),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF009688),
                  child: Text(
                    student.initials,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${student.id} • $_selectedClass',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _evaluationScoreBadge(evaluation.displayScore),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _evaluationStatus(evaluated),
                const SizedBox(width: 12),
                Text(
                  evaluation.lastEvaluated,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                evaluated
                    ? OutlinedButton(
                        onPressed: () => _openEvaluation(student),
                        child: const Text('View/Edit'),
                      )
                    : FilledButton(
                        onPressed: () => _openEvaluation(student),
                        child: const Text('Evaluate'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _evaluationForm() {
    final student = _selectedEvaluationStudent ?? _students.first;
    final evaluation = _evaluationFor(student);
    void save() {
      setState(() {
        evaluation.status = 'Submitted';
        evaluation.displayScore = evaluation.average;
        evaluation.lastEvaluated = 'Today';
      });
      _notice('Evaluation saved successfully.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final heading = Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back, size: 15),
                        label: const Text('Back'),
                      ),
                      const Text(
                        '/',
                        style: TextStyle(color: Color(0xFFD1D5DB)),
                      ),
                      const Text(
                        'Student Evaluation',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.term.replaceAll('Term ', 'Term'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(evaluation.reset),
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: save,
                        icon: const Icon(Icons.save, size: 15),
                        label: const Text('Save Evaluation'),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: heading),
                            actions,
                          ],
                        );
                },
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Information',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCDEDEC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: const Color(0xFF009E91),
                            child: Text(
                              student.initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    color: Color(0xFF111827),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedClass,
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'ID: ${student.id}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${evaluation.average.toStringAsFixed(1)}/10',
                              style: const TextStyle(
                                color: Color(0xFF00796B),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _back,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text('← Change Student'),
                    ),
                    const SizedBox(height: 8),
                    _evaluationScoreSummary(evaluation),
                    const SizedBox(height: 16),
                    const Text(
                      'Evaluation Criteria',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _evaluationCriterion(
                      evaluation,
                      keyName: 'homework',
                      icon: '📚',
                      title: 'Homework Completion',
                      description:
                          'Consistency in completing and submitting assigned homework',
                      value: evaluation.homework,
                      onChanged: (value) =>
                          setState(() => evaluation.homework = value),
                    ),
                    _evaluationCriterion(
                      evaluation,
                      keyName: 'attentiveness',
                      icon: '💡',
                      title: 'Attentiveness',
                      description:
                          'Ability to focus and pay attention during lessons',
                      value: evaluation.punctuality,
                      onChanged: (value) =>
                          setState(() => evaluation.punctuality = value),
                    ),
                    _evaluationCriterion(
                      evaluation,
                      keyName: 'teamwork',
                      icon: '🤝',
                      title: 'Teamwork',
                      description:
                          'Ability to work cooperatively with peers in group activities',
                      value: evaluation.neatness,
                      onChanged: (value) =>
                          setState(() => evaluation.neatness = value),
                    ),
                    _evaluationCriterion(
                      evaluation,
                      keyName: 'participation',
                      icon: '🙋',
                      title: 'Class Participation',
                      description:
                          'Active involvement in class discussions and activities',
                      value: evaluation.attitude,
                      onChanged: (value) =>
                          setState(() => evaluation.attitude = value),
                    ),
                    _evaluationCriterion(
                      evaluation,
                      keyName: 'discipline',
                      icon: '⚖️',
                      title: 'Respect & Discipline',
                      description:
                          'Shows respect for others and follows classroom expectations',
                      value: evaluation.discipline,
                      onChanged: (value) =>
                          setState(() => evaluation.discipline = value),
                    ),
                    _evaluationCriterion(
                      evaluation,
                      keyName: 'neatness',
                      icon: '✨',
                      title: 'Neatness',
                      description:
                          'Personal appearance, organization of materials, and workspace cleanliness',
                      value: evaluation.organization,
                      onChanged: (value) =>
                          setState(() => evaluation.organization = value),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      key: ValueKey('${student.id}-${evaluation.remark}'),
                      initialValue: evaluation.remark,
                      maxLines: 3,
                      onChanged: (value) => evaluation.remark = value,
                      decoration: const InputDecoration(
                        labelText: 'Overall teacher remark',
                        hintText: 'Add a concise overall evaluation remark',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(evaluation.reset),
                          child: const Text('Reset'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: save,
                          icon: const Icon(Icons.save, size: 15),
                          label: const Text('Save Evaluation'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _evaluationScoreSummary(_EvaluationDraft evaluation) {
    Widget summaryItem(
      String value,
      String label,
      Color background,
      Color foreground,
    ) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: foreground,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Score Summary',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              summaryItem(
                evaluation.average.toStringAsFixed(1),
                'Average',
                const Color(0xFFECFDF5),
                const Color(0xFF047857),
              ),
              const SizedBox(width: 10),
              summaryItem(
                '6',
                'Criteria',
                const Color(0xFFEFF6FF),
                const Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              summaryItem(
                '60',
                'Max Score',
                const Color(0xFFFFFBEB),
                const Color(0xFFB45309),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _evaluationCriterion(
    _EvaluationDraft evaluation, {
    required String keyName,
    required String icon,
    required String title,
    required String description,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final comment = evaluation.comments[keyName];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF9CA3AF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$value  / 10',
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (next) => onChanged(next.round()),
          ),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: () => _editEvaluationComment(evaluation, keyName, title),
            child: Text(
              comment == null || comment.isEmpty
                  ? '💬 Add Comment'
                  : '💬 $comment',
              style: const TextStyle(
                color: Color(0xFF00897B),
                fontSize: 11,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEvaluationComment(
    _EvaluationDraft evaluation,
    String keyName,
    String title,
  ) async {
    final controller = TextEditingController(
      text: evaluation.comments[keyName] ?? '',
    );
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$title Comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add an optional comment',
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
            child: const Text('Save Comment'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (comment == null || !mounted) return;
    setState(() {
      if (comment.isEmpty) {
        evaluation.comments.remove(keyName);
      } else {
        evaluation.comments[keyName] = comment;
      }
    });
  }

  String _reportStatusFor(_StudentRecord student) {
    if (_processingReportStudents.contains(student.id)) return 'Processing';
    if (_publishingReportStudents.contains(student.id)) return 'Publishing';
    return _reportStatuses[student.id] ?? student.reportStatus;
  }

  bool _remarksComplete(_StudentRecord student) =>
      _reportRemarks[student.id]?.remarksComplete ?? false;

  bool _gradesComplete(_StudentRecord student) =>
      student.readiness != 'Scores incomplete';

  String _publicationReadiness(_StudentRecord student) {
    final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    final status = _reportStatusFor(student);
    if (!_gradesComplete(student)) return 'Missing grades';
    if (status != 'Generated' && status != 'Published') {
      return 'Not generated';
    }
    if (remarks.classTeacherRemarks.isEmpty) return 'Teacher remark pending';
    if (!remarks.headTeacherRequirementSatisfied) {
      return 'Head comment pending';
    }
    if (remarks.promotedTo.isEmpty) return 'Promotion pending';
    return 'Ready to publish';
  }

  bool _readyToPublish(_StudentRecord student) =>
      _publicationReadiness(student) == 'Ready to publish';

  _ReportAudit _auditFor(_StudentRecord student) {
    return _reportAudit.putIfAbsent(
      student.id,
      () => _ReportAudit(
        createdBy: widget.viewerName,
        createdAt: _reportTimestamp(),
        updatedBy: widget.viewerName,
        updatedAt: _reportTimestamp(),
      ),
    );
  }

  void _touchReportAudit(_StudentRecord student) {
    final audit = _auditFor(student);
    audit.updatedBy = widget.viewerName;
    audit.updatedAt = _reportTimestamp();
  }

  String _reportTimestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.day)} ${_reportMonth(now.month)} ${now.year} '
        '${two(now.hour)}:${two(now.minute)}';
  }

  String _reportMonth(int month) => const [
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
  ][month - 1];

  Future<void> _generateReports(Iterable<_StudentRecord> students) async {
    final ready = students.where(_gradesComplete).toList();
    if (ready.isEmpty) {
      _notice('Select at least one student whose report is ready.');
      return;
    }
    setState(() {
      _isGeneratingReports = true;
      _reportGenerationProgress = .25;
      _processingReportStudents.addAll(ready.map((student) => student.id));
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _reportGenerationProgress = .75);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      for (final student in ready) {
        _reportStatuses[student.id] = 'Generated';
        _processingReportStudents.remove(student.id);
        _touchReportAudit(student);
      }
      _isGeneratingReports = _processingReportStudents.isNotEmpty;
      _reportGenerationProgress = _isGeneratingReports ? .75 : 1;
    });
    _notice('${ready.length} report card(s) generated.');
  }

  Future<void> _publishStudentReports(Iterable<_StudentRecord> students) async {
    final generated = students
        .where(
          (student) =>
              _reportStatusFor(student) == 'Generated' &&
              _readyToPublish(student),
        )
        .toList();
    if (generated.isEmpty) {
      _notice(
        'No selected report meets all publication-readiness requirements.',
      );
      return;
    }
    setState(() {
      _publishingReportStudents.addAll(generated.map((student) => student.id));
    });
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    setState(() {
      for (final student in generated) {
        _reportStatuses[student.id] = 'Published';
        _publishingReportStudents.remove(student.id);
        _touchReportAudit(student);
      }
    });
    _notice('${generated.length} report card(s) published.');
  }

  void _regenerateStudentReport(_StudentRecord student) {
    setState(() => _reportStatuses[student.id] = 'Not Generated');
    _generateReports([student]);
  }

  Future<void> _refreshReportCards() async {
    if (_refreshingReportCards) return;
    setState(() => _refreshingReportCards = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _refreshingReportCards = false);
    _notice('Report card statuses refreshed.');
  }

  void _openStudentReport(_StudentRecord student) {
    setState(() => _selectedReportStudent = student);
    _open(_Route.studentReport);
  }

  Widget _reportCards() {
    final missingGrades = _students
        .where((student) => !_gradesComplete(student))
        .length;
    final missingTeacherRemarks = _students.where((student) {
      return (_reportRemarks[student.id]?.classTeacherRemarks ?? '').isEmpty;
    }).length;
    final pendingHeadComments = _students.where((student) {
      final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
      return !remarks.headTeacherRequirementSatisfied;
    }).length;
    final missingPromotion = _students.where((student) {
      return (_reportRemarks[student.id]?.promotedTo ?? '').isEmpty;
    }).length;
    final readyToPublish = _students.where(_readyToPublish).length;
    final filteredStudents = _students.where((student) {
      final status = _reportStatusFor(student);
      final matchesFilter = switch (_reportCardFilter) {
        'Ready' => _readyToPublish(student),
        'Needs Attention' => !_readyToPublish(student),
        'Generated' => status == 'Generated',
        'Published' => status == 'Published',
        'Pending Generation' => status != 'Generated' && status != 'Published',
        'Missing Grades' => !_gradesComplete(student),
        'Missing Teacher Remarks' =>
          (_reportRemarks[student.id]?.classTeacherRemarks ?? '').isEmpty,
        'Pending Head Comments' =>
          !(_reportRemarks[student.id] ?? _ReportRemarksDraft.empty())
              .headTeacherRequirementSatisfied,
        'Missing Promotion' =>
          (_reportRemarks[student.id]?.promotedTo ?? '').isEmpty,
        _ => true,
      };
      return matchesFilter;
    }).toList();
    return _page(
      title: 'Report Cards',
      subtitle: _selectedClass,
      compactHeader: true,
      maxContentWidth: 1700,
      pagePadding: 14,
      children: [
        LayoutBuilder(
          builder: (_, c) => _reportCardStatGrid(
            c.maxWidth,
            total: _students.length,
            readyToPublish: readyToPublish,
            missingGrades: missingGrades,
            missingTeacherRemarks: missingTeacherRemarks,
            pendingHeadComments: pendingHeadComments,
            missingPromotion: missingPromotion,
          ),
        ),
        if (_isGeneratingReports) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _reportGenerationProgress),
          const SizedBox(height: 6),
          const Text('Generating report cards...'),
        ],
        const SizedBox(height: 18),
        _reportCardStudentRegister(filteredStudents),
      ],
    );
  }

  Widget _reportCardStatGrid(
    double maxWidth, {
    required int total,
    required int readyToPublish,
    required int missingGrades,
    required int missingTeacherRemarks,
    required int pendingHeadComments,
    required int missingPromotion,
  }) {
    final stats = <(String, String, String, IconData, Color, String)>[
      (
        'TOTAL STUDENTS',
        '$total',
        'All students in stream',
        Icons.groups_outlined,
        const Color(0xFF374151),
        'All Students',
      ),
      (
        'READY TO PUBLISH',
        '$readyToPublish',
        'All requirements satisfied',
        Icons.check_circle,
        const Color(0xFF009688),
        'Ready',
      ),
      (
        'MISSING GRADES',
        '$missingGrades',
        'Assessments not fully graded',
        Icons.more_horiz,
        const Color(0xFFF59E0B),
        'Missing Grades',
      ),
      (
        'TEACHER REMARKS',
        '$missingTeacherRemarks',
        'Class teacher remarks missing',
        Icons.rate_review_outlined,
        const Color(0xFF8B5CF6),
        'Missing Teacher Remarks',
      ),
      (
        'HEAD COMMENTS',
        '$pendingHeadComments',
        'Comment or Ignore required',
        Icons.record_voice_over_outlined,
        const Color(0xFFEF4444),
        'Pending Head Comments',
      ),
      (
        'MISSING PROMOTION',
        '$missingPromotion',
        'Next grade not selected',
        Icons.trending_up,
        const Color(0xFFF59E0B),
        'Missing Promotion',
      ),
    ];
    final columns = maxWidth >= 1350
        ? 6
        : maxWidth >= 820
        ? 3
        : maxWidth >= 560
        ? 2
        : 1;
    final cardWidth = (maxWidth - ((columns - 1) * 14)) / columns;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: stats.map((stat) {
        final selected = _reportCardFilter == stat.$6;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _reportCardFilter = stat.$6),
            borderRadius: BorderRadius.circular(11),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: cardWidth,
              height: 104,
              padding: const EdgeInsets.fromLTRB(16, 13, 14, 11),
              decoration: BoxDecoration(
                color: selected
                    ? stat.$5.withValues(alpha: .055)
                    : Colors.white,
                border: Border.all(
                  color: selected ? stat.$5 : const Color(0xFFE5E7EB),
                  width: selected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stat.$1,
                          style: const TextStyle(
                            color: Color(0xFF718096),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .45,
                          ),
                        ),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: stat.$5.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(stat.$4, size: 15, color: stat.$5),
                      ),
                    ],
                  ),
                  Text(
                    stat.$2,
                    style: const TextStyle(
                      color: Color(0xFF1A2332),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    stat.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8A9AB5),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _reportCardStudentRegister(List<_StudentRecord> students) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: _reportCardFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                    ),
                    items:
                        const [
                          'All Students',
                          'Ready',
                          'Needs Attention',
                          'Generated',
                          'Pending Generation',
                          'Published',
                          'Missing Grades',
                          'Missing Teacher Remarks',
                          'Pending Head Comments',
                          'Missing Promotion',
                        ].map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                    onChanged: (value) =>
                        setState(() => _reportCardFilter = value!),
                  ),
                ),
                const Spacer(),
                if (widget.viewerRole.toLowerCase().contains('admin') ||
                    widget.viewerRole.toLowerCase().contains('head teacher'))
                  OutlinedButton.icon(
                    onPressed: _openBulkPromotion,
                    icon: const Icon(Icons.trending_up, size: 14),
                    label: Text(
                      _selectedReportStudents.isEmpty
                          ? 'Set Promotion'
                          : 'Set Promotion (${_selectedReportStudents.length})',
                    ),
                  ),
                if (widget.viewerRole.toLowerCase().contains('admin') ||
                    widget.viewerRole.toLowerCase().contains('head teacher'))
                  const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _refreshingReportCards
                      ? null
                      : _refreshReportCards,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: _refreshingReportCards
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 14),
                  label: Text(
                    _refreshingReportCards ? 'Refreshing…' : 'Refresh',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (students.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Text('No students match the current filter.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 960;
                if (compact) {
                  return Column(
                    children: students
                        .map((student) => _reportCardStudentTile(student))
                        .toList(),
                  );
                }
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(width: 46),
                          SizedBox(
                            width: 30,
                            child: _FinalReportHeader('#', centered: true),
                          ),
                          Expanded(
                            flex: 3,
                            child: _FinalReportHeader('STUDENT'),
                          ),
                          Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'ASSESSMENTS',
                              centered: true,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'REMARKS',
                              centered: true,
                            ),
                          ),
                          Expanded(
                            child: _FinalReportHeader(
                              'AVG SCORE',
                              centered: true,
                            ),
                          ),
                          Expanded(
                            child: _FinalReportHeader(
                              'OVERALL GRADE',
                              centered: true,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'READINESS',
                              centered: true,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'REPORT STATUS',
                              centered: true,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _FinalReportHeader('ACTION', centered: true),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...students.asMap().entries.map(
                      (entry) =>
                          _reportCardStudentRow(entry.value, entry.key + 1),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _reportCardStudentRow(_StudentRecord student, int index) {
    final selected = _selectedReportStudents.contains(student.id);
    final status = _reportStatusFor(student);
    final readiness = _publicationReadiness(student);
    return InkWell(
      onTap: () => _openStudentReport(student),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Checkbox(
                value: selected,
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _selectedReportStudents.add(student.id);
                  } else {
                    _selectedReportStudents.remove(student.id);
                  }
                }),
              ),
            ),
            SizedBox(
              width: 30,
              child: Text(
                '$index',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFF009688),
                        child: Text(
                          student.name
                              .split(' ')
                              .map((part) => part[0])
                              .take(2)
                              .join(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              student.id,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: student.readiness == 'Scores incomplete'
                            ? .72
                            : 1,
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    student.readiness == 'Scores incomplete' ? '4/6' : '6/6',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(child: _remarksReadinessButton(student)),
            ),
            _reportTableValue('${student.average.toStringAsFixed(1)}%', 1),
            _reportTableValue(student.grade, 1),
            Expanded(
              flex: 2,
              child: Center(child: _reportStateBadge(readiness)),
            ),
            Expanded(flex: 2, child: Center(child: _reportStateBadge(status))),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _openStudentReport(student),
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: const Text('Open Report'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(132, 32),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportTableValue(String value, int flex) => Expanded(
    flex: flex,
    child: Text(
      value,
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );

  Widget _reportStateBadge(String label) {
    final normalized = label.toLowerCase();
    final (foreground, background) = switch (normalized) {
      'ready' => (const Color(0xFF4F8F84), const Color(0xFFF0F8F6)),
      'generated' => (const Color(0xFF527AA8), const Color(0xFFF1F6FB)),
      'published' => (const Color(0xFF4F8F84), const Color(0xFFF0F8F6)),
      'processing' ||
      'publishing' => (const Color(0xFF667085), const Color(0xFFF3F4F6)),
      'draft' => (const Color(0xFF8A7350), const Color(0xFFFAF7F1)),
      _ => (const Color(0xFF7A8597), const Color(0xFFF5F6F8)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _remarksReadinessButton(_StudentRecord student) {
    final complete = _remarksComplete(student);
    return InkWell(
      onTap: () => _openStudentReport(student),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: complete ? const Color(0xFFF0F8F6) : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: complete ? const Color(0xFFD8ECE8) : const Color(0xFFF0E5D3),
          ),
        ),
        child: Text(
          complete ? 'Complete' : 'Pending',
          style: TextStyle(
            color: complete ? const Color(0xFF4F8F84) : const Color(0xFF8A7350),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _openBulkPromotion() async {
    String? grade;
    var replaceExisting = false;
    final targets = _selectedReportStudents.isEmpty
        ? _students
        : _students
              .where((student) => _selectedReportStudents.contains(student.id))
              .toList();
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Student Promotion'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedReportStudents.isEmpty
                      ? 'Apply a promotion grade to all ${targets.length} students.'
                      : 'Apply a promotion grade to ${targets.length} selected student(s).',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: grade,
                  decoration: const InputDecoration(labelText: 'Promoted To'),
                  hint: const Text('Select class or grade level'),
                  items:
                      const [
                        'Grade 1',
                        'Grade 2',
                        'Grade 3',
                        'Basic 4',
                        'Grade 5',
                        'Grade 6',
                        'JHS 1',
                        'JHS 2',
                        'JHS 3',
                      ].map((item) {
                        return DropdownMenuItem(value: item, child: Text(item));
                      }).toList(),
                  onChanged: (value) => setDialogState(() => grade = value),
                ),
                CheckboxListTile(
                  value: replaceExisting,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Replace existing promotions'),
                  onChanged: (value) =>
                      setDialogState(() => replaceExisting = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: grade == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Apply Promotion'),
            ),
          ],
        ),
      ),
    );
    if (applied != true || !mounted) return;
    setState(() {
      for (final student in targets) {
        final current =
            _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
        if (current.promotedTo.isNotEmpty && !replaceExisting) continue;
        _reportRemarks[student.id] = _ReportRemarksDraft(
          classTeacherRemarks: current.classTeacherRemarks,
          headTeacherRemarks: current.headTeacherRemarks,
          promotedTo: grade!,
          ignoreHeadTeacherRemark: current.ignoreHeadTeacherRemark,
        );
        _touchReportAudit(student);
      }
    });
    _notice('Promotion updated for ${targets.length} student(s).');
  }

  // ignore: unused_element
  Future<void> _openRemarksEditor(_StudentRecord student) async {
    final existing = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    final classController = TextEditingController(
      text: existing.classTeacherRemarks,
    );
    final headController = TextEditingController(
      text: existing.headTeacherRemarks,
    );
    var promotedTo = existing.promotedTo;
    var ignoreHeadTeacherRemark = existing.ignoreHeadTeacherRemark;
    final role = widget.viewerRole.toLowerCase();
    final isAdministrator = role.contains('admin');
    final canEditClass = isAdministrator || role.contains('class teacher');
    final canEditHead = isAdministrator || role.contains('head teacher');
    final drawerWidth = MediaQuery.sizeOf(context).width < 560
        ? MediaQuery.sizeOf(context).width
        : 520.0;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close report remarks',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setDrawerState) => Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.white,
              elevation: 18,
              child: SizedBox(
                width: drawerWidth,
                height: double.infinity,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Student Report Remarks',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${student.name} • ${student.id}',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _remarksStudentSummary(student),
                              const SizedBox(height: 22),
                              _remarksSectionLabel('Class Teacher'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: classController,
                                enabled: canEditClass,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Class Teacher Remarks',
                                  hintText:
                                      'Add a concise academic and conduct remark',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sarah Johnson • Class Teacher',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _remarksSectionLabel('Head Teacher'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: headController,
                                enabled:
                                    canEditHead && !ignoreHeadTeacherRemark,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Head Teacher Remarks',
                                  hintText: 'Add the final head teacher remark',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Michael Mensah • Head Teacher',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CheckboxListTile(
                                value: ignoreHeadTeacherRemark,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'Ignore Head Teacher comment',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Treat this requirement as satisfied without a comment.',
                                  style: TextStyle(fontSize: 11),
                                ),
                                onChanged: canEditHead
                                    ? (value) => setDrawerState(
                                        () => ignoreHeadTeacherRemark =
                                            value ?? false,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 22),
                              _remarksSectionLabel('Promotion'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: promotedTo.isEmpty ? null : promotedTo,
                                isExpanded: true,
                                hint: const Text('Select class or grade level'),
                                decoration: const InputDecoration(
                                  labelText: 'Promoted To',
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                                items:
                                    const [
                                      'Grade 1',
                                      'Grade 2',
                                      'Grade 3',
                                      'Basic 4',
                                      'Grade 5',
                                      'Grade 6',
                                      'JHS 1',
                                      'JHS 2',
                                      'JHS 3',
                                    ].map((grade) {
                                      return DropdownMenuItem(
                                        value: grade,
                                        child: Text(grade),
                                      );
                                    }).toList(),
                                onChanged: canEditHead
                                    ? (value) => setDrawerState(
                                        () => promotedTo = value ?? '',
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _saveReportRemarks(
                                  student,
                                  classController.text,
                                  headController.text,
                                  promotedTo,
                                  ignoreHeadTeacherRemark:
                                      ignoreHeadTeacherRemark,
                                  draft: true,
                                );
                                Navigator.pop(dialogContext);
                              },
                              child: const Text('Save Draft'),
                            ),
                            FilledButton.icon(
                              onPressed: () {
                                _saveReportRemarks(
                                  student,
                                  classController.text,
                                  headController.text,
                                  promotedTo,
                                  ignoreHeadTeacherRemark:
                                      ignoreHeadTeacherRemark,
                                );
                                Navigator.pop(dialogContext);
                              },
                              icon: const Icon(Icons.save_outlined, size: 15),
                              label: const Text('Save Remarks'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
    classController.dispose();
    headController.dispose();
  }

  Widget _remarksStudentSummary(_StudentRecord student) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$_selectedClass • ${widget.term}\nViewing as ${widget.viewerRole}',
        style: const TextStyle(
          color: Color(0xFF416D66),
          fontSize: 12,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _remarksSectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: Color(0xFF64748B),
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .6,
    ),
  );

  void _saveReportRemarks(
    _StudentRecord student,
    String classRemarks,
    String headRemarks,
    String promotedTo, {
    bool ignoreHeadTeacherRemark = false,
    bool draft = false,
  }) {
    final remarks = _ReportRemarksDraft(
      classTeacherRemarks: classRemarks.trim(),
      headTeacherRemarks: headRemarks.trim(),
      promotedTo: promotedTo,
      ignoreHeadTeacherRemark: ignoreHeadTeacherRemark,
    );
    setState(() => _reportRemarks[student.id] = remarks);
    _notice(
      draft
          ? '${student.name} remarks saved as draft.'
          : remarks.remarksComplete && remarks.promotedTo.isNotEmpty
          ? '${student.name} remarks completed.'
          : 'Remarks saved. Complete all fields to make the report ready.',
    );
  }

  Widget _reportCardStudentTile(_StudentRecord student) {
    final status = _reportStatusFor(student);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      leading: Checkbox(
        value: _selectedReportStudents.contains(student.id),
        onChanged: (checked) => setState(() {
          if (checked ?? false) {
            _selectedReportStudents.add(student.id);
          } else {
            _selectedReportStudents.remove(student.id);
          }
        }),
      ),
      title: Text(
        student.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${student.id} • ${student.average.toStringAsFixed(1)}% • ${student.grade}\nRemarks: ${_remarksComplete(student) ? 'Complete' : 'Pending'} • ${_publicationReadiness(student)} • $status',
      ),
      isThreeLine: true,
      onTap: () => _openStudentReport(student),
      trailing: IconButton(
        tooltip: 'Open report',
        onPressed: () => _openStudentReport(student),
        icon: const Icon(Icons.arrow_forward),
      ),
    );
  }

  Widget _studentReportPage() {
    final student = _selectedReportStudent ?? _students.first;
    final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    final evaluation = _evaluationFor(student);
    final status = _reportStatusFor(student);
    final generated = status == 'Generated' || status == 'Published';
    final role = widget.viewerRole.toLowerCase();
    final administrator = role.contains('admin');
    final canEditClass = administrator || role.contains('class teacher');
    final canEditHead = administrator || role.contains('head teacher');

    return _page(
      title: 'Student Report',
      subtitle: '${student.name} • ${student.id} • $_selectedClass',
      compactHeader: true,
      maxContentWidth: 1320,
      actions: [
        _outlineButton('Save Draft', Icons.save_outlined, () {
          setState(() => _touchReportAudit(student));
          _notice('${student.name} report saved as draft.');
        }),
        _outlineButton(
          'Preview',
          Icons.visibility_outlined,
          generated ? () => _showReportCard(student) : null,
        ),
        if (status != 'Published')
          _filledButton(
            generated ? 'Regenerate' : 'Generate',
            generated ? Icons.refresh : Icons.description_outlined,
            _gradesComplete(student)
                ? () => generated
                      ? _regenerateStudentReport(student)
                      : _generateReports([student])
                : null,
          ),
        if (status != 'Published')
          _filledButton(
            'Publish',
            Icons.send,
            generated && _readyToPublish(student)
                ? () => _publishStudentReports([student])
                : null,
          ),
      ],
      children: [
        _studentReportIdentity(student, status),
        const SizedBox(height: 16),
        _reportReadinessSection(student),
        const SizedBox(height: 16),
        _section(
          title: 'Academic Performance',
          child: _tableCard(
            embedded: true,
            columns: const [
              'SUBJECT',
              'CLASS SCORE',
              'EXAM',
              'TOTAL',
              'GRADE',
              'REMARK',
            ],
            rows: const [
              ['Mathematics', '54', '35', '89', 'A', 'Excellent'],
              ['English Language', '50', '32', '82', 'B', 'Very good'],
              ['Integrated Science', '48', '30', '78', 'B', 'Good'],
              ['Social Studies', '45', '29', '74', 'C', 'Good'],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _studentReportEvaluation(student, evaluation),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final remarksSection = _studentReportRemarksSection(
              student,
              remarks,
              canEditClass: canEditClass,
              canEditHead: canEditHead,
            );
            final promotionSection = _studentReportPromotionSection(
              student,
              remarks,
              canEdit: canEditHead,
            );
            if (compact) {
              return Column(
                children: [
                  remarksSection,
                  const SizedBox(height: 16),
                  promotionSection,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: remarksSection),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: promotionSection),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _studentReportAuditSection(student),
      ],
    );
  }

  Widget _studentReportIdentity(_StudentRecord student, String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF009688),
            child: Text(
              student.name.split(' ').map((part) => part[0]).take(2).join(),
              style: const TextStyle(
                color: Colors.white,
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
                  student.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${student.id} • $_selectedClass • ${widget.term}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _reportStateBadge(status),
        ],
      ),
    );
  }

  Widget _reportReadinessSection(_StudentRecord student) {
    final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    final status = _reportStatusFor(student);
    final checks = <(String, bool)>[
      ('All grades entered', _gradesComplete(student)),
      ('Report generated', status == 'Generated' || status == 'Published'),
      ('Class Teacher remark', remarks.classTeacherRemarks.isNotEmpty),
      ('Head comment or Ignore', remarks.headTeacherRequirementSatisfied),
      ('Promotion selected', remarks.promotedTo.isNotEmpty),
    ];
    return _section(
      title: 'Publication Readiness',
      action: _reportStateBadge(_publicationReadiness(student)),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: checks.map((check) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: check.$2
                  ? const Color(0xFFF0F8F6)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: check.$2
                    ? const Color(0xFFD8ECE8)
                    : const Color(0xFFFED7AA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  check.$2 ? Icons.check_circle : Icons.error_outline,
                  size: 15,
                  color: check.$2
                      ? const Color(0xFF4F8F84)
                      : const Color(0xFFC27832),
                ),
                const SizedBox(width: 6),
                Text(
                  check.$1,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _studentReportEvaluation(
    _StudentRecord student,
    _EvaluationDraft evaluation,
  ) {
    final items = [
      ('Homework', evaluation.homework),
      ('Attentiveness', evaluation.punctuality),
      ('Teamwork', evaluation.neatness),
      ('Participation', evaluation.attitude),
      ('Discipline', evaluation.discipline),
      ('Neatness', evaluation.organization),
    ];
    return _section(
      title: 'Student Evaluation',
      action: OutlinedButton.icon(
        onPressed: () => _editEvaluationOnReport(student),
        icon: const Icon(Icons.edit_outlined, size: 14),
        label: const Text('Edit Evaluation'),
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items.map((item) {
              return Container(
                width: 160,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.$1,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${item.$2}/10',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Average: ${evaluation.average.toStringAsFixed(1)}/10',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (evaluation.remark.isNotEmpty) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    evaluation.remark,
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _studentReportRemarksSection(
    _StudentRecord student,
    _ReportRemarksDraft remarks, {
    required bool canEditClass,
    required bool canEditHead,
  }) {
    return _section(
      title: 'Teacher Remarks',
      child: Column(
        children: [
          TextFormField(
            key: ValueKey('${student.id}-class-report-remark'),
            initialValue: remarks.classTeacherRemarks,
            enabled: canEditClass,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Class Teacher Remarks',
              alignLabelWithHint: true,
            ),
            onChanged: (value) =>
                _updateReportRemarks(student, classTeacherRemarks: value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${student.id}-head-report-remark'),
            initialValue: remarks.headTeacherRemarks,
            enabled: canEditHead && !remarks.ignoreHeadTeacherRemark,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Head Teacher Remarks',
              alignLabelWithHint: true,
            ),
            onChanged: (value) =>
                _updateReportRemarks(student, headTeacherRemarks: value),
          ),
          CheckboxListTile(
            value: remarks.ignoreHeadTeacherRemark,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Ignore Head Teacher comment',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Treat the Head Teacher requirement as satisfied.',
              style: TextStyle(fontSize: 11),
            ),
            onChanged: canEditHead
                ? (value) => _updateReportRemarks(
                    student,
                    ignoreHeadTeacherRemark: value ?? false,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _studentReportPromotionSection(
    _StudentRecord student,
    _ReportRemarksDraft remarks, {
    required bool canEdit,
  }) {
    return _section(
      title: 'Promotion & Attendance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: remarks.promotedTo.isEmpty ? null : remarks.promotedTo,
            isExpanded: true,
            hint: const Text('Select class or grade level'),
            decoration: const InputDecoration(
              labelText: 'Promoted To',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items:
                const [
                  'Grade 1',
                  'Grade 2',
                  'Grade 3',
                  'Basic 4',
                  'Grade 5',
                  'Grade 6',
                  'JHS 1',
                  'JHS 2',
                  'JHS 3',
                ].map((grade) {
                  return DropdownMenuItem(value: grade, child: Text(grade));
                }).toList(),
            onChanged: canEdit
                ? (value) =>
                      _updateReportRemarks(student, promotedTo: value ?? '')
                : null,
          ),
          const SizedBox(height: 18),
          _reportInfoLine('School days', '90'),
          _reportInfoLine('Present', '88'),
          _reportInfoLine('Absent', '2'),
          _reportInfoLine('Late', '1'),
        ],
      ),
    );
  }

  Widget _reportInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _studentReportAuditSection(_StudentRecord student) {
    final audit = _auditFor(student);
    return _section(
      title: 'Record Information',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            ('Created by', audit.createdBy),
            ('Created at', audit.createdAt),
            ('Last updated by', audit.updatedBy),
            ('Last updated at', audit.updatedAt),
          ];
          final width = constraints.maxWidth < 700
              ? constraints.maxWidth
              : (constraints.maxWidth - 30) / 4;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: fields.map((field) {
              return Container(
                width: width,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.$1.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      field.$2,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _updateReportRemarks(
    _StudentRecord student, {
    String? classTeacherRemarks,
    String? headTeacherRemarks,
    String? promotedTo,
    bool? ignoreHeadTeacherRemark,
  }) {
    final current = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    setState(() {
      _reportRemarks[student.id] = current.copyWith(
        classTeacherRemarks: classTeacherRemarks,
        headTeacherRemarks: headTeacherRemarks,
        promotedTo: promotedTo,
        ignoreHeadTeacherRemark: ignoreHeadTeacherRemark,
      );
    });
  }

  Future<void> _editEvaluationOnReport(_StudentRecord student) async {
    final evaluation = _evaluationFor(student);
    var homework = evaluation.homework;
    var attentiveness = evaluation.punctuality;
    var teamwork = evaluation.neatness;
    var participation = evaluation.attitude;
    var discipline = evaluation.discipline;
    var neatness = evaluation.organization;
    final criterionComments = Map<String, String>.from(evaluation.comments);
    final remarkController = TextEditingController(text: evaluation.remark);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget scoreRow(
            String keyName,
            String label,
            int value,
            ValueChanged<int> update,
          ) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 125,
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: value.toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          onChanged: (next) =>
                              setDialogState(() => update(next.round())),
                        ),
                      ),
                      SizedBox(
                        width: 38,
                        child: Text(
                          '$value/10',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    key: ValueKey('${student.id}-$keyName-report-comment'),
                    initialValue: criterionComments[keyName] ?? '',
                    maxLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Optional one-line comment',
                      prefixIcon: Icon(Icons.chat_bubble_outline, size: 16),
                      isDense: true,
                    ),
                    onChanged: (comment) =>
                        criterionComments[keyName] = comment,
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Edit Student Evaluation'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scoreRow(
                      'homework',
                      'Homework',
                      homework,
                      (value) => homework = value,
                    ),
                    scoreRow(
                      'punctuality',
                      'Attentiveness',
                      attentiveness,
                      (value) => attentiveness = value,
                    ),
                    scoreRow(
                      'neatness',
                      'Teamwork',
                      teamwork,
                      (value) => teamwork = value,
                    ),
                    scoreRow(
                      'attitude',
                      'Participation',
                      participation,
                      (value) => participation = value,
                    ),
                    scoreRow(
                      'discipline',
                      'Discipline',
                      discipline,
                      (value) => discipline = value,
                    ),
                    scoreRow(
                      'organization',
                      'Neatness',
                      neatness,
                      (value) => neatness = value,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarkController,
                      maxLines: 1,
                      decoration: const InputDecoration(
                        labelText: 'Overall Evaluation Remark',
                        hintText: 'Add one concise overall comment',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.save_outlined, size: 15),
                label: const Text('Save Evaluation'),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        evaluation.homework = homework;
        evaluation.punctuality = attentiveness;
        evaluation.neatness = teamwork;
        evaluation.attitude = participation;
        evaluation.discipline = discipline;
        evaluation.organization = neatness;
        evaluation.remark = remarkController.text.trim();
        evaluation.comments
          ..clear()
          ..addAll(
            criterionComments.map((key, value) => MapEntry(key, value.trim()))
              ..removeWhere((key, value) => value.isEmpty),
          );
        evaluation.status = 'Submitted';
        evaluation.displayScore = evaluation.average;
        evaluation.lastEvaluated = 'Today';
        _touchReportAudit(student);
      });
      _notice('${student.name} evaluation saved.');
    }
    remarkController.dispose();
  }

  Future<void> _publishStream(_FinalReportStream stream) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Publish ${stream.name}?'),
        content: Text(
          '${stream.pendingPublication > 0 ? stream.pendingPublication : stream.published} report(s) will be published and visible to parents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => stream.publishing = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      stream.published = stream.ready;
      stream.publishing = false;
    });
    _notice('${stream.name} reports published.');
  }

  Widget _finalReports() {
    final students = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.students,
    );
    final published = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.published,
    );
    final generated = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.generated,
    );
    final pendingGeneration = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.pendingGeneration,
    );
    final pendingPublication = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.pendingPublication,
    );
    final streamsWithPending = _finalReportStreams
        .where((stream) => stream.pendingPublication > 0)
        .length;
    final gradeLevels =
        _finalReportStreams
            .map((stream) => stream.name.split(' - ').first)
            .toSet()
            .toList()
          ..sort();
    final availableStreams =
        _finalReportStreams
            .where(
              (stream) =>
                  _finalReportGradeFilter == 'All Grade Levels' ||
                  stream.name.split(' - ').first == _finalReportGradeFilter,
            )
            .map((stream) => stream.name.split(' - ').last)
            .toSet()
            .toList()
          ..sort();
    final filteredStreams = _finalReportStreams.where((stream) {
      final grade = stream.name.split(' - ').first;
      final streamName = stream.name.split(' - ').last;
      final matchesGrade =
          _finalReportGradeFilter == 'All Grade Levels' ||
          grade == _finalReportGradeFilter;
      final matchesStream =
          _finalReportStreamFilter == 'All Streams' ||
          streamName == _finalReportStreamFilter;
      final matchesFilter = switch (_finalReportFilter) {
        'Generated' => stream.generated > 0,
        'Pending Generation' => stream.pendingGeneration > 0,
        'Pending Publication' => stream.pendingPublication > 0,
        'Published' => stream.published > 0,
        _ => true,
      };
      return matchesGrade && matchesStream && matchesFilter;
    }).toList();

    Future<void> publishAll() async {
      final publishable = _finalReportStreams
          .where((stream) => stream.pendingPublication > 0)
          .toList();
      if (publishable.isEmpty) {
        _notice('There are no report cards ready to publish.');
        return;
      }
      setState(() => _isPublishingAllReports = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        for (final stream in publishable) {
          stream.published = stream.ready;
        }
        _isPublishingAllReports = false;
      });
      _notice('${publishable.length} stream(s) published.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          const Text(
                            'Final Report Management',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F7F5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${widget.term} ${widget.academicYear.replaceAll(' Academic Year', '')}',
                              style: const TextStyle(
                                color: Color(0xFF009688),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'All streams for the current term. Publish generated report cards to complete the term.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Refresh'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () =>
                            _notice('Final report register exported.'),
                        icon: const Icon(Icons.download_outlined, size: 15),
                        label: const Text('Export Report'),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: heading),
                            actions,
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = [
                    _finalReportStat(
                      'Total Streams',
                      '${_finalReportStreams.length}',
                      'All grade streams',
                      Icons.class_outlined,
                      const Color(0xFF3B82F6),
                    ),
                    _finalReportStat(
                      'Total Students',
                      '$students',
                      'Across all streams',
                      Icons.groups_outlined,
                      const Color(0xFF8B5CF6),
                    ),
                    _finalReportStat(
                      'Generated',
                      '$generated',
                      'Report cards created',
                      Icons.description_outlined,
                      const Color(0xFF3B82F6),
                    ),
                    _finalReportStat(
                      'Pending Generation',
                      '$pendingGeneration',
                      'Still to be generated',
                      Icons.pending_actions_outlined,
                      const Color(0xFFF59E0B),
                    ),
                    _finalReportStat(
                      'Published',
                      '$published',
                      'Report cards released',
                      Icons.check_circle_outline,
                      const Color(0xFF059669),
                    ),
                  ];
                  final columns = constraints.maxWidth < 600
                      ? 1
                      : constraints.maxWidth < 980
                      ? 2
                      : 5;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: stats
                        .map((stat) => SizedBox(width: width, child: stat))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F5),
                  border: Border.all(color: const Color(0xFFCCEDE9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF009688),
                      size: 20,
                    ),
                    Text(
                      '$pendingPublication generated report cards across $streamsWithPending stream${streamsWithPending == 1 ? '' : 's'} are ready to publish.',
                      style: const TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 12.5,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isPublishingAllReports ? null : publishAll,
                      icon: _isPublishingAllReports
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, size: 14),
                      label: Text(
                        _isPublishingAllReports
                            ? 'Publishing...'
                            : 'Publish All ($pendingPublication)',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      value: _finalReportGradeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                        prefixIcon: Icon(Icons.school_outlined, size: 18),
                      ),
                      items: ['All Grade Levels', ...gradeLevels]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() {
                        _finalReportGradeFilter = value!;
                        _finalReportStreamFilter = 'All Streams';
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      value: _finalReportStreamFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Stream',
                        prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
                      ),
                      items: ['All Streams', ...availableStreams]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _finalReportStreamFilter = value!),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: DropdownButtonFormField<String>(
                      value: _finalReportFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Report Status',
                        prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
                      ),
                      items:
                          const [
                                'All Statuses',
                                'Generated',
                                'Pending Generation',
                                'Pending Publication',
                                'Published',
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                    item,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => _finalReportFilter = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _finalReportRegister(filteredStreams),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finalReportStat(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalReportRegister(List<_FinalReportStream> streams) {
    if (streams.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'No streams match the current filter.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }
    final grouped = <String, List<_FinalReportStream>>{};
    for (final stream in streams) {
      final grade = stream.name.split(' - ').first;
      grouped.putIfAbsent(grade, () => []).add(stream);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 760;
          return Column(
            children: [
              if (!mobile)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  color: const Color(0xFFF9FAFB),
                  child: const Row(
                    children: [
                      SizedBox(width: 20),
                      Expanded(flex: 3, child: _FinalReportHeader('STREAM')),
                      Expanded(
                        flex: 2,
                        child: _FinalReportHeader('STUDENTS', centered: true),
                      ),
                      Expanded(
                        flex: 2,
                        child: _FinalReportHeader('GENERATED', centered: true),
                      ),
                      Expanded(
                        flex: 3,
                        child: _FinalReportHeader(
                          'PENDING GENERATION',
                          centered: true,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _FinalReportHeader('PUBLISHED', centered: true),
                      ),
                      Expanded(
                        flex: 3,
                        child: _FinalReportHeader('ACTIONS', trailing: true),
                      ),
                    ],
                  ),
                ),
              for (final entry in grouped.entries) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F7F5),
                    border: Border(
                      top: BorderSide(color: Color(0xFFCCEDE9)),
                      bottom: BorderSide(color: Color(0xFFCCEDE9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009688),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.length} stream${entry.value.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF00796B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final stream in entry.value)
                  mobile
                      ? _finalReportMobileCard(stream)
                      : _finalReportRow(stream),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _finalReportRow(_FinalReportStream stream) {
    final color = stream.pendingPublication > 0
        ? const Color(0xFFF59E0B)
        : stream.published > 0
        ? const Color(0xFF009688)
        : const Color(0xFFD1D5DB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stream.name.split(' - ').last,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  stream.teacher,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _finalReportNumber('${stream.students}', const Color(0xFF374151), 2),
          _finalReportNumber(
            '${stream.generated}',
            stream.generated > 0
                ? const Color(0xFF3B82F6)
                : const Color(0xFFD1D5DB),
            2,
          ),
          _finalReportNumber(
            stream.pendingGeneration > 0 ? '${stream.pendingGeneration}' : '—',
            stream.pendingGeneration > 0
                ? const Color(0xFFF59E0B)
                : const Color(0xFFD1D5DB),
            3,
          ),
          _finalReportNumber(
            stream.published > 0 ? '${stream.published}' : '—',
            stream.published > 0
                ? const Color(0xFF009688)
                : const Color(0xFFD1D5DB),
            2,
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedClass = stream.name);
                    _open(_Route.reportCards);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View'),
                ),
                _finalReportPublishAction(stream),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _finalReportNumber(String value, Color color, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _finalReportMobileCard(_FinalReportStream stream) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stream.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            stream.teacher,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _finalMobileValue('Students', '${stream.students}'),
              ),
              Expanded(
                child: _finalMobileValue('Generated', '${stream.generated}'),
              ),
              Expanded(
                child: _finalMobileValue(
                  'Pending generation',
                  '${stream.pendingGeneration}',
                ),
              ),
              Expanded(
                child: _finalMobileValue('Published', '${stream.published}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedClass = stream.name);
                    _open(_Route.reportCards);
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _finalReportPublishAction(stream)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _finalReportPublishAction(_FinalReportStream stream) {
    final onPressed = stream.ready == 0 || stream.publishing
        ? null
        : () => _publishStream(stream);
    if (stream.publishing) {
      return FilledButton(onPressed: null, child: const Text('Publishing...'));
    }
    if (stream.pendingPublication > 0) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.send, size: 14),
        label: Text('Publish (${stream.pendingPublication})'),
      );
    }
    if (stream.published > 0) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 14),
        label: const Text('Republish'),
      );
    }
    return FilledButton(onPressed: null, child: const Text('Publish (0)'));
  }

  Widget _finalMobileValue(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9.5),
        ),
      ],
    );
  }

  Widget _classes() {
    return _page(
      title: 'Classes',
      subtitle: '${widget.academicYear} - ${widget.term}',
      children: [
        _filterBar(
          hint: 'Search classes',
          filters: const ['All school levels'],
        ),
        const SizedBox(height: 14),
        _tableCard(
          columns: const [
            'STREAM',
            'DIVISION',
            'CLASS TEACHER',
            'STUDENTS',
            'ASSESSMENTS',
            'AVG SCORE',
            'COMPLETION',
          ],
          rows: const [
            [
              'Grade 5 - Stream A',
              'Basic 4-6',
              'Sarah Johnson',
              '47',
              '8',
              '78.4%',
              '92%',
            ],
            [
              'Grade 5 - Stream B',
              'Basic 4-6',
              'Michael Brown',
              '45',
              '8',
              '75.1%',
              '88%',
            ],
            [
              'Basic 4 - Stream A',
              'Basic 4-6',
              'Abena Kofi',
              '35',
              '7',
              '81.3%',
              '86%',
            ],
            [
              'JHS 2 - Stream A',
              'Junior High',
              'Kweku Mensah',
              '62',
              '9',
              '72.8%',
              '79%',
            ],
          ],
          onRowTap: (index) {
            _selectedClass = const [
              'Grade 5 - Stream A',
              'Grade 5 - Stream B',
              'Basic 4 - Stream A',
              'JHS 2 - Stream A',
            ][index];
            _open(_Route.classDetail);
          },
        ),
      ],
    );
  }

  Widget _classDetail() {
    return _page(
      title: _selectedClass,
      subtitle: 'Class performance and student records',
      actions: [
        _outlineButton(
          'Assessments',
          Icons.assignment_outlined,
          () => _open(_Route.assessments),
        ),
        _filledButton(
          'Enter Scores',
          Icons.edit_note_outlined,
          () => _open(_Route.scoreSheet),
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (_, c) => _statGrid(c.maxWidth, const [
            ('STUDENTS', '47', '24 female - 23 male'),
            ('ASSESSMENTS', '8', '7 graded - 1 open'),
            ('CLASS AVERAGE', '78.4%', '+3.1% from last term'),
            ('COMPLETION', '92%', '43 students complete'),
          ]),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Students',
          child: Column(
            children: _students
                .map(
                  (student) => _listTile(
                    title: student.name,
                    subtitle:
                        '${student.id} - Average ${student.average.toStringAsFixed(1)}%',
                    badge: student.grade,
                    onTap: () => _openStudent(student),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _studentProfile() {
    final student = _selectedStudent ?? _students.first;
    return _page(
      title: student.name,
      subtitle: '${student.id} - $_selectedClass',
      actions: [
        _outlineButton('Parent', Icons.family_restroom_outlined, () {
          final parent = _parents.firstWhere(
            (parent) => parent.name == student.parent,
            orElse: () => _parents.first,
          );
          _openParent(parent);
        }),
        _filledButton(
          'View Report Card',
          Icons.description_outlined,
          () => _showReportCard(student),
        ),
      ],
      children: [
        _section(
          title: 'Medical Alert',
          child: const Row(
            children: [
              Icon(Icons.medical_information_outlined, color: AppColors.red),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sickle cell trait recorded. Emergency contact must be notified before strenuous activity.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (_, c) => _detailGrid(c.maxWidth, [
            ('FULL NAME', student.name),
            ('STUDENT ID', student.id),
            ('GENDER', student.gender),
            ('CLASS', _selectedClass),
            ('DATE OF BIRTH', '22 Jul 2014'),
            ('PRIMARY GUARDIAN', student.parent),
            ('AVERAGE SCORE', '${student.average.toStringAsFixed(1)}%'),
            ('OVERALL GRADE', student.grade),
          ]),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Academic Performance',
          child: _tableCard(
            embedded: true,
            columns: const [
              'SUBJECT',
              'CLASS (60)',
              'EXAM (40)',
              'TOTAL (100)',
              'GRADE',
              'REMARKS',
            ],
            rows: const [
              ['Mathematics', '54.0', '35.0', '89.0', 'A', 'Excellent'],
              ['English', '50.0', '32.0', '82.0', 'B', 'Good'],
              ['Science', '48.0', '30.0', '78.0', 'B', 'Good'],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Attendance Record',
          child: LayoutBuilder(
            builder: (_, c) => _detailGrid(c.maxWidth, const [
              ('TOTAL DAYS', '90'),
              ('PRESENT', '88'),
              ('ABSENT', '2'),
              ('LATE', '1'),
              ('PUNCTUALITY', 'Excellent'),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Conduct / Terminal Evaluation',
          child: LayoutBuilder(
            builder: (_, c) => _detailGrid(c.maxWidth, const [
              ('HOMEWORK', '9/10 - Excellent'),
              ('PUNCTUALITY', '10/10 - Excellent'),
              ('NEATNESS', '8/10 - Good'),
              ('ATTITUDE', '9/10 - Excellent'),
              ('CONDUCT AVERAGE', '9.0'),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Teacher Remarks',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Class Teacher: "Excellent performance. Keep it up!"'),
              SizedBox(height: 12),
              Text('Head Teacher: "Outstanding student. Well done!"'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Promotion & Next Term',
          child: LayoutBuilder(
            builder: (_, c) => _detailGrid(c.maxWidth, const [
              ('PROMOTED TO', 'JHS 2A'),
              ('NEXT TERM BEGINS', '5 January 2026'),
              ('NEXT TERM FEES', 'GHc 850.00'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _parentsPage() {
    return _page(
      title: 'Parents & Guardians',
      subtitle: 'Family contacts linked to students',
      actions: [
        _filledButton(
          'Add Parent',
          Icons.person_add_alt_1_outlined,
          _showParentDialog,
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (_, c) => _statGrid(c.maxWidth, const [
            ('TOTAL PARENTS', '412', 'Across all households'),
            ('ACTIVE CONTACTS', '397', 'Contact details verified'),
            ('CHILDREN LINKED', '580', 'Current enrolled students'),
            ('MISSING CONTACT', '15', 'Requires attention'),
          ]),
        ),
        const SizedBox(height: 16),
        _filterBar(
          hint: 'Search parents by name, phone or email',
          filters: const ['All contact statuses'],
        ),
        const SizedBox(height: 14),
        _tableCard(
          columns: const [
            'PARENT / GUARDIAN',
            'PHONE',
            'EMAIL',
            'CHILDREN',
            'PRIMARY FOR',
            'STATUS',
          ],
          rows: _parents
              .map(
                (p) => [
                  p.name,
                  p.phone,
                  p.email,
                  '${p.children.length}',
                  p.children.first.name,
                  'Active',
                ],
              )
              .toList(),
          onRowTap: (index) => _openParent(_parents[index]),
        ),
      ],
    );
  }

  Widget _parentDetail() {
    final parent = _selectedParent ?? _parents.first;
    return _page(
      title: parent.name,
      subtitle: '${parent.id} - Parent / Guardian',
      actions: [
        _outlineButton('Edit Contact', Icons.edit_outlined, _showParentDialog),
      ],
      children: [
        LayoutBuilder(
          builder: (_, c) => _detailGrid(c.maxWidth, [
            ('PHONE', parent.phone),
            ('EMAIL', parent.email),
            ('RELATIONSHIP', 'Parent / Guardian'),
            ('PREFERRED CONTACT', 'SMS and email'),
            ('ADDRESS', '14 Banana Inn Road, Accra'),
            ('STATUS', 'Active'),
          ]),
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Linked Students',
          child: Column(
            children: parent.children
                .map(
                  (student) => _listTile(
                    title: student.name,
                    subtitle: '${student.id} - $_selectedClass',
                    badge: student.grade,
                    onTap: () => _openStudent(student),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<List<_CurriculumIndicator>?> _showCurriculumDrawer(
    List<_CurriculumIndicator> initialSelection,
  ) {
    return showGeneralDialog<List<_CurriculumIndicator>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close curriculum indicators',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) =>
          _CurriculumDialog(initialSelection: initialSelection),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }

  Future<void> _showParentDialog() async {
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Parent / Guardian Details'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(decoration: InputDecoration(labelText: 'Full name')),
                SizedBox(height: 12),
                TextField(decoration: InputDecoration(labelText: 'Phone')),
                SizedBox(height: 12),
                TextField(decoration: InputDecoration(labelText: 'Email')),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(labelText: 'Relationship'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _notice('Parent details saved.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportCard(_StudentRecord student) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.schoolName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text('${widget.term} - ${widget.academicYear}'),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STUDENT INFORMATION',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${student.name}  |  ${student.id}  |  $_selectedClass',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ACADEMIC PERFORMANCE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _tableCard(
                        embedded: true,
                        columns: const [
                          'SUBJECT',
                          'CLASS (60)',
                          'EXAM (40)',
                          'TOTAL',
                          'GRADE',
                          'REMARKS',
                        ],
                        rows: const [
                          ['Mathematics', '54', '35', '89', 'A', 'Excellent'],
                          ['English', '50', '32', '82', 'B', 'Good'],
                          ['Science', '48', '30', '78', 'B', 'Good'],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'AVERAGE: ${student.average.toStringAsFixed(1)}  |  GRADE: ${student.grade}  |  POSITION: 3/35',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      _reportSection('ATTENDANCE RECORD', const [
                        ('Total school days', '90'),
                        ('Present', '88'),
                        ('Absent', '2'),
                        ('Late', '1'),
                        ('Punctuality', 'Excellent'),
                      ]),
                      const SizedBox(height: 16),
                      _reportSection('CONDUCT / TERMINAL EVALUATION', const [
                        ('Homework', '9/10 - Excellent'),
                        ('Punctuality', '10/10 - Excellent'),
                        ('Neatness', '8/10 - Good'),
                        ('Attitude', '9/10 - Excellent'),
                        ('Conduct average', '9.0'),
                      ]),
                      const SizedBox(height: 16),
                      _reportSection('TEACHER REMARKS', [
                        (
                          'Class teacher',
                          _reportRemarks[student.id]
                                      ?.classTeacherRemarks
                                      .isNotEmpty ==
                                  true
                              ? _reportRemarks[student.id]!.classTeacherRemarks
                              : 'Pending',
                        ),
                        (
                          'Head teacher',
                          _reportRemarks[student.id]?.ignoreHeadTeacherRemark ==
                                  true
                              ? 'Ignored'
                              : _reportRemarks[student.id]
                                        ?.headTeacherRemarks
                                        .isNotEmpty ==
                                    true
                              ? _reportRemarks[student.id]!.headTeacherRemarks
                              : 'Pending',
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _reportSection('PROMOTION & NEXT TERM', [
                        (
                          'Promoted to',
                          _reportRemarks[student.id]?.promotedTo.isNotEmpty ==
                                  true
                              ? _reportRemarks[student.id]!.promotedTo
                              : 'Not set',
                        ),
                        ('Next term begins', '5 January 2026'),
                        ('Next term fees', 'GHS 850.00'),
                      ]),
                      const SizedBox(height: 16),
                      _reportSection('REPORT RECORD', [
                        ('Created by', _auditFor(student).createdBy),
                        ('Created at', _auditFor(student).createdAt),
                        ('Last updated by', _auditFor(student).updatedBy),
                        ('Last updated at', _auditFor(student).updatedAt),
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Back to Report'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _notice('Report card print preview opened.'),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: () => _notice('Report card downloaded.'),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportSection(String title, List<(String, String)> entries) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      entry.$1,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

  Widget _statGrid(double maxWidth, List<(String, String, String)> items) {
    final columns = maxWidth >= 1050
        ? (items.length > 5 ? 5 : items.length)
        : maxWidth >= 620
        ? 2
        : 1;
    final width = (maxWidth - ((columns - 1) * 14)) / columns;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: items
          .map(
            (item) => SizedBox(
              width: width,
              child: _card(
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.$3,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _detailGrid(double maxWidth, List<(String, String)> details) {
    final columns = maxWidth >= 900
        ? 3
        : maxWidth >= 560
        ? 2
        : 1;
    final width = (maxWidth - ((columns - 1) * 12)) / columns;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: details
          .map(
            (detail) => SizedBox(
              width: width,
              child: _card(
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.$1,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _actionCard(
    double width,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _listTile({
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(badge),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityRow(String actor, String activity, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.greenSoft,
            child: Text(
              actor.split(' ').map((part) => part[0]).take(2).join(),
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  activity,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _attentionRow(String student, String issue, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(issue, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          TextButton(onPressed: () => _notice(action), child: Text(action)),
        ],
      ),
    );
  }

  Widget _filterBar({required String hint, required List<String> filters}) {
    return _card(
      Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (_, c) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: c.maxWidth >= 720 ? 360 : c.maxWidth,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              ...filters.map(
                (filter) => SizedBox(
                  width: c.maxWidth >= 720 ? 180 : c.maxWidth,
                  child: DropdownButtonFormField<String>(
                    value: filter,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [filter]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableCard({
    required List<String> columns,
    required List<List<String>> rows,
    ValueChanged<int>? onRowTap,
    bool embedded = false,
  }) {
    final table = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF7F9F9)),
        columns: columns
            .map(
              (column) => DataColumn(
                label: Text(
                  column,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
        rows: rows
            .asMap()
            .entries
            .map(
              (entry) => DataRow(
                onSelectChanged: onRowTap == null
                    ? null
                    : (_) => onRowTap(entry.key),
                cells: entry.value
                    .map(
                      (value) => DataCell(
                        Text(value, style: const TextStyle(fontSize: 13)),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
    return embedded ? table : _card(table);
  }

  Widget _outlineButton(String label, IconData icon, VoidCallback? onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _filledButton(String label, IconData icon, VoidCallback? onPressed) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AssessmentFormPage extends StatefulWidget {
  const _AssessmentFormPage({
    required this.title,
    required this.subtitle,
    required this.source,
    required this.onBack,
    required this.onCurriculum,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final _AssessmentRecord? source;
  final VoidCallback onBack;
  final Future<List<_CurriculumIndicator>?> Function(List<_CurriculumIndicator>)
  onCurriculum;
  final ValueChanged<_AssessmentRecord> onSave;

  @override
  State<_AssessmentFormPage> createState() => _AssessmentFormPageState();
}

class _AssessmentFormPageState extends State<_AssessmentFormPage> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _maxScore;
  late final TextEditingController _description;
  late final TextEditingController _indicatorSearch;
  String? _selectedClass;
  String? _type;
  String? _subject;
  String? _term;
  String? _academicYear;
  String? _status;
  DateTime? _dateGiven;
  bool _officialSba = false;
  String? _indicatorError;
  final List<_CurriculumIndicator> _selectedIndicators = [];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.source?.title ?? '');
    _maxScore = TextEditingController(
      text: widget.source?.maxScore.toString() ?? '',
    );
    _description = TextEditingController();
    _indicatorSearch = TextEditingController();
    if (widget.source != null) {
      _selectedClass = widget.subtitle;
      _type = widget.source!.type;
      _subject = widget.source!.subject;
      _term = widget.source!.term;
      _academicYear = widget.source!.academicYear;
      _status = widget.source!.status;
      _dateGiven = _parseAssessmentDate(widget.source!.date);
      _officialSba = widget.source!.officialSba;
      _description.text = widget.source!.description;
      _selectedIndicators.addAll(widget.source!.curriculumIndicators);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _maxScore.dispose();
    _description.dispose();
    _indicatorSearch.dispose();
    super.dispose();
  }

  Future<void> _openCurriculumDrawer() async {
    final selection = await widget.onCurriculum(_selectedIndicators);
    if (!mounted || selection == null) return;
    setState(() {
      _selectedIndicators
        ..clear()
        ..addAll(selection);
      if (_selectedIndicators.isNotEmpty) {
        _indicatorError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source != null) return _buildOldEditPage();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageToolbar(),
          const SizedBox(height: 18),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  _informationBanner(),
                  const SizedBox(height: 16),
                  _assessmentDetailsCard(),
                  const SizedBox(height: 16),
                  _curriculumCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOldEditPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 700;
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: widget.onBack,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left,
                              size: 18,
                              color: Color(0xFF009688),
                            ),
                            Text(
                              'Assessment Detail',
                              style: TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Edit Assessment',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${widget.subtitle} • ${_subject ?? ''}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: widget.onBack,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save Changes'),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: heading),
                            actions,
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              Form(
                key: _key,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 820;
                    final basic = _oldEditCard(
                      title: 'Basic Information',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _title,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              hintText: 'Enter assessment title',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the assessment title'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          _responsivePair(
                            _dropdown(
                              label: 'Type',
                              hint: 'Select type',
                              value: _type,
                              values: const [
                                'CAT 1',
                                'CAT 2',
                                'Project',
                                'Exam',
                              ],
                              onChanged: (value) =>
                                  setState(() => _type = value),
                            ),
                            _dropdown(
                              label: 'Status',
                              hint: 'Select status',
                              value: _status,
                              values: const [
                                'Open',
                                'Closed',
                                'Graded',
                                'Pending Review',
                              ],
                              onChanged: (value) =>
                                  setState(() => _status = value),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _responsivePair(
                            _dateField(),
                            TextFormField(
                              controller: _maxScore,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Score',
                                hintText: 'Max marks',
                              ),
                              validator: (value) {
                                final score = int.tryParse(value ?? '');
                                return score == null || score <= 0
                                    ? 'Enter a valid score'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                          _responsivePair(
                            _dropdown(
                              label: 'Subject',
                              hint: 'Select subject',
                              value: _subject,
                              values: const [
                                'Mathematics',
                                'English Language',
                                'Integrated Science',
                                'Social Studies',
                              ],
                              onChanged: (value) =>
                                  setState(() => _subject = value),
                            ),
                            _dropdown(
                              label: 'Term',
                              hint: 'Select term',
                              value: _term,
                              values: const ['Term 1', 'Term 2', 'Term 3'],
                              onChanged: (value) =>
                                  setState(() => _term = value),
                            ),
                          ),
                        ],
                      ),
                    );
                    final curriculum = _oldEditCard(
                      title: 'Curriculum Indicators',
                      count: _selectedIndicators.length,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Link performance indicators from the GES curriculum to this assessment. Click Browse Indicators to search and add.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openCurriculumDrawer,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Browse & Add Indicators'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_selectedIndicators.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '🎯 No indicators linked.\nBrowse indicators to add curriculum standards.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  height: 1.6,
                                ),
                              ),
                            )
                          else
                            for (final indicator in _selectedIndicators)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _oldEditIndicator(indicator),
                              ),
                        ],
                      ),
                    );
                    if (narrow) {
                      return Column(
                        children: [
                          basic,
                          const SizedBox(height: 16),
                          curriculum,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 14, child: basic),
                        const SizedBox(width: 16),
                        Expanded(flex: 10, child: curriculum),
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

  Widget _oldEditCard({
    required String title,
    required Widget child,
    int? count,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF7F4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFF009688),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _oldEditIndicator(_CurriculumIndicator indicator) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFECFAF7),
        border: Border.all(color: const Color(0xFFB8EAE2)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Text('🎯'),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  indicator.code,
                  style: const TextStyle(
                    color: Color(0xFF009688),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(indicator.text, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () =>
                setState(() => _selectedIndicators.remove(indicator)),
            icon: const Icon(Icons.close, size: 17, color: Color(0xFFEF4444)),
          ),
        ],
      ),
    );
  }

  Widget _pageToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final breadcrumb = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: widget.onBack,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chevron_left,
                      size: 18,
                      color: AppColors.green,
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('/', style: TextStyle(color: AppColors.muted)),
            ),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: widget.onBack,
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save_outlined, size: 17),
              label: Text(
                widget.source == null ? 'Create Assessment' : 'Save Changes',
              ),
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              breadcrumb,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: breadcrumb),
            actions,
          ],
        );
      },
    );
  }

  Widget _informationBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F6),
        border: Border.all(color: const Color(0xFFB8E7E1)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fill in the assessment details below to create a new assessment entry.',
              style: TextStyle(color: Color(0xFF245F59)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _assessmentDetailsCard() {
    return _formCard(
      child: Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assessment Details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _responsivePair(
              _dropdown(
                label: 'Class',
                hint: 'Select Class',
                value: _selectedClass,
                values: _classOptions,
                onChanged: (value) => setState(() => _selectedClass = value),
              ),
              _dropdown(
                label: 'Subject',
                hint: 'Select Subject',
                value: _subject,
                values: const [
                  'Mathematics',
                  'English Language',
                  'Integrated Science',
                  'Social Studies',
                ],
                onChanged: (value) => setState(() => _subject = value),
              ),
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Assessment Type',
              hint: 'Select Type',
              value: _type,
              values: const ['CAT 1', 'CAT 2', 'Project', 'Exam'],
              onChanged: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 14),
            _responsivePair(
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Assessment Title *',
                  hintText: 'e.g., Fractions Exercise 1',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the assessment title'
                    : null,
              ),
              TextFormField(
                controller: _maxScore,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Score *',
                  hintText: '0',
                ),
                validator: (value) {
                  final score = int.tryParse(value ?? '');
                  return score == null || score <= 0
                      ? 'Enter a valid score'
                      : null;
                },
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F6),
                border: Border.all(color: const Color(0xFFB8E7E1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 17, color: AppColors.green),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Student scores will be converted from the assessment maximum to a 100-point scale for final calculations. Example: 8/10 = 80/100.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF245F59),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _dropdown(
                    label: 'Term',
                    hint: 'Select Term',
                    value: _term,
                    values: const ['Term 1', 'Term 2', 'Term 3'],
                    onChanged: (value) => setState(() => _term = value),
                  ),
                  _dateField(),
                  _dropdown(
                    label: 'Academic Year',
                    hint: 'Select Year',
                    value: _academicYear,
                    values: const [
                      '2024 Academic Year',
                      '2025 Academic Year',
                      '2026 Academic Year',
                    ],
                    onChanged: (value) => setState(() => _academicYear = value),
                  ),
                ];
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        fields[index],
                        if (index != fields.length - 1)
                          const SizedBox(height: 14),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[1]),
                    const SizedBox(width: 12),
                    Expanded(child: fields[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Official SBA Assessment',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Mark as an official GES School-Based Assessment record',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _officialSba,
                    onChanged: (value) => setState(() => _officialSba = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Brief description of what this assessment covers...',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _curriculumCard() {
    return _formCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _openCurriculumDrawer,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.library_books_outlined,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Curriculum Mapping',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Link this assessment to specific curriculum standards',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: AppColors.green),
                ],
              ),
            ),
          ),
          const Divider(height: 28),
          const Text(
            'Search Learning Indicators *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _indicatorSearch,
            readOnly: true,
            onTap: _openCurriculumDrawer,
            decoration: InputDecoration(
              hintText:
                  'Type indicator code or keyword... (e.g., B5.1.2 or fractions)',
              prefixIcon: const Icon(Icons.search),
              errorText: _indicatorError,
              suffixIcon: IconButton(
                tooltip: 'Browse indicators',
                onPressed: _openCurriculumDrawer,
                icon: const Icon(Icons.tune),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click to search and browse GES curriculum indicators',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          if (_selectedIndicators.isEmpty)
            InkWell(
              onTap: _openCurriculumDrawer,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 82),
                padding: const EdgeInsets.all(18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFCFD),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'No indicators linked yet. Use the search above to find and add curriculum indicators.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Linked Indicators',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF4F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedIndicators.length}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final indicator in _selectedIndicators) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF9F7),
                  border: Border.all(color: const Color(0xFFB8E7E1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            indicator.code,
                            style: const TextStyle(
                              color: AppColors.green,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            indicator.text,
                            style: const TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${indicator.strand} › ${indicator.subStrand}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Remove ${indicator.code}',
                      onPressed: () =>
                          setState(() => _selectedIndicators.remove(indicator)),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE7E7),
                        foregroundColor: const Color(0xFFFF4D4F),
                        minimumSize: const Size(30, 30),
                        maximumSize: const Size(30, 30),
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.close, size: 17),
                    ),
                  ],
                ),
              ),
              if (indicator != _selectedIndicators.last)
                const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _formCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _responsivePair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(children: [first, const SizedBox(height: 14), second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 14),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _dropdown({
    required String label,
    required String hint,
    required String? value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      hint: Text(hint),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (selected) =>
          selected == null || selected.isEmpty ? 'Select $label' : null,
    );
  }

  Widget _dateField() {
    return FormField<DateTime>(
      initialValue: _dateGiven,
      validator: (_) => _dateGiven == null ? 'Select a date' : null,
      builder: (field) {
        return InkWell(
          onTap: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: _dateGiven ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (selected == null) return;
            setState(() => _dateGiven = selected);
            field.didChange(selected);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date Given',
              errorText: field.errorText,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(
              _dateGiven == null
                  ? 'mm/dd/yyyy'
                  : '${_dateGiven!.month.toString().padLeft(2, '0')}/${_dateGiven!.day.toString().padLeft(2, '0')}/${_dateGiven!.year}',
              style: TextStyle(
                color: _dateGiven == null ? AppColors.muted : null,
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> get _classOptions {
    final options = <String>[
      'Grade 1 A',
      'Grade 1 B',
      'Grade 2 A',
      'Grade 2 B',
    ];
    if (widget.subtitle.trim().isNotEmpty &&
        !options.contains(widget.subtitle.trim())) {
      options.insert(0, widget.subtitle.trim());
    }
    return options;
  }

  void _submit() {
    final detailsAreValid = _key.currentState!.validate();
    final indicatorsAreValid = _selectedIndicators.isNotEmpty;
    setState(() {
      _indicatorError = indicatorsAreValid
          ? null
          : 'Please select at least one curriculum indicator';
    });
    if (!detailsAreValid || !indicatorsAreValid) return;
    final max = int.parse(_maxScore.text);
    final date = _dateGiven!;
    widget.onSave(
      _AssessmentRecord(
        id: widget.source?.id ?? 'ASS-${DateTime.now().millisecondsSinceEpoch}',
        title: _title.text.trim(),
        type: _type!,
        subject: _subject!,
        date:
            '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}',
        maxScore: max,
        entered: widget.source?.entered ?? 0,
        totalStudents: widget.source?.totalStudents ?? 47,
        average: widget.source?.average ?? 0,
        passRate: widget.source?.passRate ?? 0,
        status: _status ?? 'Open',
        grading: widget.source?.grading ?? 'Not started',
        description: _description.text.trim(),
        term: _term!,
        academicYear: _academicYear!,
        officialSba: _officialSba,
        curriculumIndicators: List.of(_selectedIndicators),
      ),
    );
  }

  DateTime? _parseAssessmentDate(String value) {
    final parts = value.split(' ');
    if (parts.length != 3) return null;
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
    final day = int.tryParse(parts[0]);
    final month = months.indexOf(parts[1]) + 1;
    final year = int.tryParse(parts[2]);
    if (day == null || month == 0 || year == null) return null;
    return DateTime(year, month, day);
  }

  String _monthName(int month) {
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
    return months[month - 1];
  }
}

class _ScoreSheetPage extends StatefulWidget {
  const _ScoreSheetPage({
    required this.assessment,
    required this.students,
    required this.initialScores,
    required this.onBack,
    required this.onExport,
    required this.onSave,
  });

  final _AssessmentRecord assessment;
  final List<_StudentRecord> students;
  final Map<String, double?>? initialScores;
  final VoidCallback onBack;
  final ValueChanged<String> onExport;
  final ValueChanged<Map<String, double?>> onSave;

  @override
  State<_ScoreSheetPage> createState() => _ScoreSheetPageState();
}

class _ScoreSheetPageState extends State<_ScoreSheetPage> {
  static const _oldAppSampleScores = [3.0, 15.0, 23.4, 22.2, 20.4];
  final _searchController = TextEditingController();
  String _query = '';
  late final Map<String, TextEditingController> _controllers = {
    for (var index = 0; index < widget.students.length; index++)
      widget.students[index].id: TextEditingController(
        text:
            widget.initialScores?.containsKey(widget.students[index].id) == true
            ? widget.initialScores![widget.students[index].id]?.toString() ?? ''
            : widget.assessment.entered == 0
            ? ''
            : _oldAppSampleScores[index % _oldAppSampleScores.length]
                  .toString()
                  .replaceFirst(RegExp(r'\.0$'), ''),
      ),
  };
  late final Map<String, TextEditingController> _remarkControllers = {
    for (final student in widget.students) student.id: TextEditingController(),
  };

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final controller in _remarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleStudents = widget.students.where((student) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query);
    }).toList();
    final values = _controllers.values
        .map((controller) => double.tryParse(controller.text.trim()))
        .whereType<double>()
        .toList();
    final average = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final high = values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
    final low = values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
    final passRate = values.isEmpty
        ? null
        : values
                  .where((score) => score >= widget.assessment.maxScore * .5)
                  .length *
              100 /
              values.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final heading = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: widget.onBack,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chevron_left,
                              size: 18,
                              color: Color(0xFF009688),
                            ),
                            Text(
                              'Assessment Detail',
                              style: TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score Sheet – ${widget.assessment.title}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Grade 5 • Stream A • ${widget.assessment.subject} • Max: ${widget.assessment.maxScore} marks',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.onExport(_buildCsv()),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Export CSV'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 16),
                        label: const Text('Save Scores'),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            heading,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: heading),
                            actions,
                          ],
                        );
                },
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = [
                    _oldScoreStat(
                      'Total Students',
                      '${widget.students.length}',
                      const Color(0xFF111827),
                    ),
                    _oldScoreStat(
                      'Scores Entered',
                      '${values.length}',
                      const Color(0xFF009688),
                    ),
                    _oldScoreStat(
                      'Average Score',
                      average?.toStringAsFixed(1) ?? '—',
                      const Color(0xFF009688),
                    ),
                    _oldScoreStat(
                      'Pass Rate',
                      passRate == null
                          ? '—'
                          : '${passRate.toStringAsFixed(1)}%',
                      const Color(0xFF009688),
                    ),
                    _oldScoreStat(
                      'Hi / Lo',
                      high == null
                          ? '—'
                          : '${high.toStringAsFixed(0)} / ${low!.toStringAsFixed(0)}',
                      const Color(0xFF111827),
                    ),
                  ];
                  final columns = constraints.maxWidth < 620
                      ? 2
                      : constraints.maxWidth < 900
                      ? 3
                      : 5;
                  final width =
                      (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: stats
                        .map((stat) => SizedBox(width: width, child: stat))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Search students...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    if (visibleStudents.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No students match your search.',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 760) {
                            return Column(
                              children: visibleStudents
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _oldMobileScoreRow(
                                      entry.key,
                                      entry.value,
                                    ),
                                  )
                                  .toList(),
                            );
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF9FAFB),
                              ),
                              headingTextStyle: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                              columns: [
                                const DataColumn(label: Text('#')),
                                const DataColumn(label: Text('STUDENT')),
                                const DataColumn(label: Text('STUDENT ID')),
                                DataColumn(
                                  label: Text(
                                    'SCORE / ${widget.assessment.maxScore}',
                                  ),
                                ),
                                const DataColumn(label: Text('VISUAL')),
                                const DataColumn(label: Text('GRADE')),
                                const DataColumn(label: Text('PASS/FAIL')),
                                const DataColumn(label: Text('REMARKS')),
                              ],
                              rows: visibleStudents
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => _oldDesktopScoreRow(
                                      entry.key,
                                      entry.value,
                                    ),
                                  )
                                  .toList(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oldScoreStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  double? _scoreFor(_StudentRecord student) =>
      double.tryParse(_controllers[student.id]!.text.trim());

  String _gradeFor(double? score) {
    if (score == null) return '—';
    final percent = score / widget.assessment.maxScore * 100;
    if (percent >= 80) return 'A';
    if (percent >= 70) return 'B';
    if (percent >= 60) return 'C';
    if (percent >= 50) return 'D';
    return 'F';
  }

  Widget _oldScoreInput(_StudentRecord student) {
    final score = _scoreFor(student);
    final invalid = score != null && score > widget.assessment.maxScore;
    return SizedBox(
      width: 92,
      child: TextField(
        controller: _controllers[student.id],
        onChanged: (_) => setState(() {}),
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          hintText: '—',
          isDense: true,
          errorText: invalid ? 'Too high' : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _oldScoreVisual(double? score) {
    final percent =
        (score == null ? 0.0 : (score / widget.assessment.maxScore).clamp(0, 1))
            .toDouble();
    return SizedBox(
      width: 130,
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: const Color(0xFFE5E7EB),
              color: percent >= .5
                  ? const Color(0xFF009688)
                  : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            score == null ? '—' : '${(percent * 100).round()}%',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _oldPassBadge(double? score) {
    if (score == null) {
      return const Text('—', style: TextStyle(color: Color(0xFF9CA3AF)));
    }
    final passed = score >= widget.assessment.maxScore * .5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: passed ? const Color(0xFFDFF7EC) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        passed ? 'Pass' : 'Fail',
        style: TextStyle(
          color: passed ? const Color(0xFF087F6F) : const Color(0xFFDC2626),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  DataRow _oldDesktopScoreRow(int index, _StudentRecord student) {
    final score = _scoreFor(student);
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          SizedBox(
            width: 175,
            child: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(Text(student.id)),
        DataCell(_oldScoreInput(student)),
        DataCell(_oldScoreVisual(score)),
        DataCell(
          Text(
            _gradeFor(score),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        DataCell(_oldPassBadge(score)),
        DataCell(
          SizedBox(
            width: 180,
            child: TextField(
              controller: _remarkControllers[student.id],
              decoration: const InputDecoration(
                hintText: 'Add remark...',
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _oldMobileScoreRow(int index, _StudentRecord student) {
    final score = _scoreFor(student);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${index + 1}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      student.id,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _oldPassBadge(score),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _oldScoreInput(student),
              const SizedBox(width: 12),
              Expanded(child: _oldScoreVisual(score)),
              const SizedBox(width: 10),
              Text(
                _gradeFor(score),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remarkControllers[student.id],
            decoration: const InputDecoration(
              hintText: 'Add remark...',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final scores = <String, double?>{};
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      final score = value.isEmpty ? null : double.tryParse(value);
      if (score != null && (score < 0 || score > widget.assessment.maxScore)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Scores must be between 0 and ${widget.assessment.maxScore}.',
            ),
          ),
        );
        return;
      }
      scores[entry.key] = score;
    }
    widget.onSave(scores);
  }

  String _buildCsv() {
    final rows = <String>[
      'Student ID,Student Name,Score,Maximum Score,Grade,Result,Remarks',
      for (final student in widget.students)
        [
          student.id,
          '"${student.name.replaceAll('"', '""')}"',
          _controllers[student.id]!.text.trim(),
          widget.assessment.maxScore,
          _gradeFor(_scoreFor(student)),
          _scoreFor(student) == null
              ? ''
              : _scoreFor(student)! >= widget.assessment.maxScore * .5
              ? 'Pass'
              : 'Fail',
          '"${_remarkControllers[student.id]!.text.replaceAll('"', '""')}"',
        ].join(','),
    ];
    return rows.join('\n');
  }
}

class _ClassSelectorDialog extends StatefulWidget {
  const _ClassSelectorDialog({required this.action});

  final String action;

  @override
  State<_ClassSelectorDialog> createState() => _ClassSelectorDialogState();
}

class _ClassSelectorDialogState extends State<_ClassSelectorDialog> {
  String _grade = 'Grade 5';
  String _stream = 'Stream A';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.action),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a class and stream to continue.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: _grade,
              decoration: const InputDecoration(labelText: 'Grade level'),
              items: const ['Grade 5', 'Basic 4', 'JHS 2']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _grade = value ?? _grade),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _stream,
              decoration: const InputDecoration(labelText: 'Stream'),
              items: const ['Stream A', 'Stream B']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _stream = value ?? _stream),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, '$_grade - $_stream'),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _CurriculumIndicator {
  const _CurriculumIndicator({
    required this.code,
    required this.text,
    required this.strand,
    required this.subStrand,
  });

  final String code;
  final String text;
  final String strand;
  final String subStrand;

  @override
  bool operator ==(Object other) =>
      other is _CurriculumIndicator && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class _CurriculumDialog extends StatefulWidget {
  const _CurriculumDialog({required this.initialSelection});

  final List<_CurriculumIndicator> initialSelection;

  @override
  State<_CurriculumDialog> createState() => _CurriculumDialogState();
}

class _CurriculumDialogState extends State<_CurriculumDialog> {
  static const _indicators = [
    _CurriculumIndicator(
      code: 'B5.1.1.1',
      text: 'Count, read and write numbers up to 10,000 in numerals and words.',
      strand: 'Number',
      subStrand: 'Counting & Place Value',
    ),
    _CurriculumIndicator(
      code: 'B5.1.1.2',
      text:
          'Compare and order whole numbers up to 10,000 using <, > and = symbols.',
      strand: 'Number',
      subStrand: 'Counting & Place Value',
    ),
    _CurriculumIndicator(
      code: 'B5.1.1.3',
      text: 'Round numbers to the nearest 10, 100 and 1,000.',
      strand: 'Number',
      subStrand: 'Counting & Place Value',
    ),
    _CurriculumIndicator(
      code: 'B5.1.2.1',
      text:
          'Use letters and symbols to represent unknown numbers in simple equations.',
      strand: 'Number',
      subStrand: 'Algebra',
    ),
    _CurriculumIndicator(
      code: 'B5.1.2.2',
      text: 'Identify and continue number patterns.',
      strand: 'Number',
      subStrand: 'Algebra',
    ),
    _CurriculumIndicator(
      code: 'B5.2.1.3',
      text: 'Identify, describe and classify 2D and 3D shapes.',
      strand: 'Geometry',
      subStrand: 'Shapes & Space',
    ),
    _CurriculumIndicator(
      code: 'B5.2.2.1',
      text: 'Calculate perimeter and area of rectangles and triangles.',
      strand: 'Geometry',
      subStrand: 'Measurement',
    ),
    _CurriculumIndicator(
      code: 'B5.3.1.1',
      text: 'Collect, organise and interpret data in tables and bar charts.',
      strand: 'Data',
      subStrand: 'Statistics',
    ),
    _CurriculumIndicator(
      code: 'B5.5.1.2',
      text:
          'Read and understand a variety of texts, identifying main ideas and supporting details.',
      strand: 'Reading',
      subStrand: 'Comprehension',
    ),
    _CurriculumIndicator(
      code: 'B5.5.2.1',
      text: 'Use context clues to determine the meaning of unfamiliar words.',
      strand: 'Reading',
      subStrand: 'Vocabulary',
    ),
  ];

  final _searchController = TextEditingController();
  late final Set<_CurriculumIndicator> _selected;
  String _activeStrand = 'All';

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _strands => [
    'All',
    ...{for (final indicator in _indicators) indicator.strand},
  ];

  List<_CurriculumIndicator> get _filteredIndicators {
    final query = _searchController.text.trim().toLowerCase();
    return _indicators.where((indicator) {
      final matchesStrand =
          _activeStrand == 'All' || indicator.strand == _activeStrand;
      final matchesQuery =
          query.isEmpty ||
          indicator.code.toLowerCase().contains(query) ||
          indicator.text.toLowerCase().contains(query) ||
          indicator.strand.toLowerCase().contains(query) ||
          indicator.subStrand.toLowerCase().contains(query);
      return matchesStrand && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;
    final width = size.width < 600
        ? size.width
        : size.width < 1000
        ? size.width * 0.85
        : 680.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.white,
        elevation: 24,
        shadowColor: Colors.black54,
        child: SafeArea(
          child: SizedBox(
            width: width,
            height: size.height,
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                Expanded(
                  child: isMobile
                      ? _buildCatalogue()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildCatalogue()),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: 300,
                              child: _buildSelectedPanel(showFooter: true),
                            ),
                          ],
                        ),
                ),
                if (isMobile) _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 18),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Curriculum Indicators',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Browse by strand or search by code, keyword, or topic',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogue() {
    final indicators = _filteredIndicators;
    final groups = <String, List<_CurriculumIndicator>>{};
    for (final indicator in indicators) {
      final heading = _activeStrand == 'All'
          ? indicator.strand
          : indicator.subStrand;
      groups.putIfAbsent(heading, () => []).add(indicator);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search indicators...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _strands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final strand = _strands[index];
              final selected = strand == _activeStrand;
              return InkWell(
                onTap: () => setState(() => _activeStrand = strand),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? AppColors.green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    strand,
                    style: TextStyle(
                      color: selected ? AppColors.green : AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: indicators.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No curriculum indicators match your search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 14, bottom: 24),
                  children: [
                    for (final entry in groups.entries)
                      _buildIndicatorGroup(entry.key, entry.value),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildIndicatorGroup(
    String heading,
    List<_CurriculumIndicator> indicators,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              heading.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 9),
          for (final indicator in indicators) _buildIndicatorTile(indicator),
        ],
      ),
    );
  }

  Widget _buildIndicatorTile(_CurriculumIndicator indicator) {
    final selected = _selected.contains(indicator);
    return InkWell(
      onTap: () => setState(() {
        selected ? _selected.remove(indicator) : _selected.add(indicator);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F7F5) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: selected ? AppColors.green : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.green : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        indicator.code,
                        style: const TextStyle(
                          color: AppColors.green,
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          indicator.subStrand,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    indicator.text,
                    style: const TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    indicator.strand,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPanel({required bool showFooter}) {
    final selected = _selected.toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Selected indicators',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF4F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${selected.length}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selected.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                      'Choose indicators from the catalogue. Your selections will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: selected.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final indicator = selected[index];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FA),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  indicator.code,
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  indicator.text,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            onPressed: () =>
                                setState(() => _selected.remove(indicator)),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        if (showFooter) _buildFooter(),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selectionCount = Text(
            '${_selected.length} selected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => Navigator.pop(context, _selected.toList()),
                child: const Text('Apply Selection'),
              ),
            ],
          );

          if (constraints.maxWidth < 430) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                selectionCount,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: selectionCount),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _EvaluationDraft {
  _EvaluationDraft({
    required this.homework,
    required this.punctuality,
    required this.neatness,
    required this.attitude,
    required this.discipline,
    required this.organization,
    this.status = 'Not started',
    this.displayScore,
    this.lastEvaluated = 'Never',
  });

  int homework;
  int punctuality;
  int neatness;
  int attitude;
  int discipline;
  int organization;
  String remark = '';
  final Map<String, String> comments = {};
  String status;
  double? displayScore;
  String lastEvaluated;

  double get average =>
      (homework +
          punctuality +
          neatness +
          attitude +
          discipline +
          organization) /
      6;

  void reset() {
    homework = 5;
    punctuality = 5;
    neatness = 5;
    attitude = 5;
    discipline = 5;
    organization = 5;
    remark = '';
    comments.clear();
    status = 'Not started';
    displayScore = null;
    lastEvaluated = 'Never';
  }
}

class _FinalReportStream {
  _FinalReportStream(
    this.name,
    this.teacher,
    this.students,
    this.generated,
    this.ready,
    this.published,
  );

  final String name;
  final String teacher;
  final int students;
  final int generated;
  final int ready;
  int published;
  bool publishing = false;

  int get pendingPublication {
    final value = ready - published;
    return value < 0 ? 0 : value;
  }

  int get pendingGeneration {
    final value = students - generated;
    return value < 0 ? 0 : value;
  }

  String get status {
    if (published >= students) return 'Published';
    if (ready < students || generated < students) return 'Needs attention';
    return 'Ready';
  }
}

class _ReportRemarksDraft {
  const _ReportRemarksDraft({
    required this.classTeacherRemarks,
    required this.headTeacherRemarks,
    required this.promotedTo,
    this.ignoreHeadTeacherRemark = false,
  });

  factory _ReportRemarksDraft.empty() => const _ReportRemarksDraft(
    classTeacherRemarks: '',
    headTeacherRemarks: '',
    promotedTo: '',
    ignoreHeadTeacherRemark: false,
  );

  factory _ReportRemarksDraft.completed(String promotedTo) =>
      _ReportRemarksDraft(
        classTeacherRemarks:
            'Demonstrates consistent effort and positive academic progress.',
        headTeacherRemarks:
            'A commendable performance. Continue working diligently.',
        promotedTo: promotedTo,
        ignoreHeadTeacherRemark: false,
      );

  final String classTeacherRemarks;
  final String headTeacherRemarks;
  final String promotedTo;
  final bool ignoreHeadTeacherRemark;

  _ReportRemarksDraft copyWith({
    String? classTeacherRemarks,
    String? headTeacherRemarks,
    String? promotedTo,
    bool? ignoreHeadTeacherRemark,
  }) {
    return _ReportRemarksDraft(
      classTeacherRemarks: classTeacherRemarks ?? this.classTeacherRemarks,
      headTeacherRemarks: headTeacherRemarks ?? this.headTeacherRemarks,
      promotedTo: promotedTo ?? this.promotedTo,
      ignoreHeadTeacherRemark:
          ignoreHeadTeacherRemark ?? this.ignoreHeadTeacherRemark,
    );
  }

  bool get headTeacherRequirementSatisfied =>
      headTeacherRemarks.isNotEmpty || ignoreHeadTeacherRemark;

  bool get remarksComplete =>
      classTeacherRemarks.isNotEmpty && headTeacherRequirementSatisfied;
}

class _ReportAudit {
  _ReportAudit({
    required this.createdBy,
    required this.createdAt,
    required this.updatedBy,
    required this.updatedAt,
  });

  final String createdBy;
  final String createdAt;
  String updatedBy;
  String updatedAt;
}

class _FinalReportHeader extends StatelessWidget {
  const _FinalReportHeader(
    this.label, {
    this.centered = false,
    this.trailing = false,
  });

  final String label;
  final bool centered;
  final bool trailing;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: trailing
          ? TextAlign.right
          : centered
          ? TextAlign.center
          : TextAlign.left,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: .35,
      ),
    );
  }
}

class _AssessmentRecord {
  _AssessmentRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.date,
    required this.maxScore,
    required this.entered,
    required this.totalStudents,
    required this.average,
    required this.passRate,
    required this.status,
    required this.grading,
    this.description = '',
    this.term = 'Term 1',
    this.academicYear = '2024 Academic Year',
    this.officialSba = false,
    this.curriculumIndicators = const [],
  });

  final String id;
  final String title;
  final String type;
  final String subject;
  final String date;
  final int maxScore;
  int entered;
  final int totalStudents;
  double average;
  double passRate;
  String status;
  String grading;
  String description;
  String term;
  String academicYear;
  bool officialSba;
  List<_CurriculumIndicator> curriculumIndicators;
}

class _StudentRecord {
  const _StudentRecord({
    required this.id,
    required this.name,
    required this.gender,
    required this.average,
    required this.grade,
    required this.readiness,
    required this.reportStatus,
    required this.parent,
  });

  final String id;
  final String name;
  final String gender;
  final double average;
  final String grade;
  final String readiness;
  final String reportStatus;
  final String parent;

  String get initials => name.split(' ').map((part) => part[0]).take(2).join();
}

class _ParentRecord {
  const _ParentRecord({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.children,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final List<_StudentRecord> children;
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.label, this.value, this.total, this.color);

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 7,
            borderRadius: BorderRadius.circular(10),
            color: color,
            backgroundColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
