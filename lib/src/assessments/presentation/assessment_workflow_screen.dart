import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/assessment_api_client.dart';
import '../domain/teacher_assessment_scope.dart';
import '../../dashboard/data/teacher_workspace_api_client.dart';
import '../../approvals/data/approval_api_client.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../platform/presentation/document_opener.dart';
import '../../theme/app_theme.dart';
import 'assessment_csv_export.dart';
import 'report_pdf_download.dart';
import 'report_dashboard_rules.dart';
import 'report_print_package_dialog.dart';
import 'term_evaluation_workflow_screen.dart';

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

const _reportBasedAssessmentCategory = 'Report-Based Assessment';
const _practiceBasedAssessmentCategory = 'Practice-Based Assessment';

const _assessmentCategories = <String>[
  _reportBasedAssessmentCategory,
  _practiceBasedAssessmentCategory,
];

const _classroomAssessmentTypes = <String>[
  'Class Exercise',
  'Homework',
  'Quiz',
  'Class Test',
  'Project',
  'Practical',
  'Experiment',
  'Oral Assessment',
  'Performance Assessment',
];

const _schoolBasedAssessmentTypes = <String>[
  'CAT 1',
  'CAT 2',
  'CAT 3',
  'CAT 4',
];

const _examinationTypes = <String>['End-of-Term Examination'];

const _reportBasedAssessmentTypes = <String>[
  ..._schoolBasedAssessmentTypes,
  ..._examinationTypes,
];

const _allAssessmentTypes = <String>[
  ..._classroomAssessmentTypes,
  ..._schoolBasedAssessmentTypes,
  ..._examinationTypes,
];

List<String> _typesForAssessmentCategory(String? category) =>
    switch (category) {
      _reportBasedAssessmentCategory => _reportBasedAssessmentTypes,
      _practiceBasedAssessmentCategory => _classroomAssessmentTypes,
      _ => const <String>[],
    };

String _categoryForAssessmentType(String? type) {
  if (_classroomAssessmentTypes.contains(type)) {
    return _practiceBasedAssessmentCategory;
  }
  return _reportBasedAssessmentCategory;
}

String _canonicalAssessmentTypeLabel(String type) => switch (type) {
  'CAT 4 – Project/Assignment' => 'CAT 4',
  'End-of-Term Exam' => 'End-of-Term Examination',
  'Practical and Experiment' => 'Practical',
  'Performance and Oral Assessment' => 'Performance Assessment',
  _ => type,
};

class CompleteAssessmentWorkflow extends StatefulWidget {
  const CompleteAssessmentWorkflow({
    super.key,
    required this.schoolName,
    required this.term,
    required this.academicYear,
    required this.customSchoolId,
    required this.accessToken,
    required this.viewerRole,
    required this.viewerName,
    this.initialStreamId,
    this.openFinalReportsOnLoad = false,
    this.onRefreshAccessToken,
  });

  final String schoolName;
  final String term;
  final String academicYear;
  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final String viewerRole;
  final String viewerName;
  final int? initialStreamId;
  final bool openFinalReportsOnLoad;

  @override
  State<CompleteAssessmentWorkflow> createState() =>
      _CompleteAssessmentWorkflowState();
}

class _CompleteAssessmentWorkflowState
    extends State<CompleteAssessmentWorkflow> {
  late final AssessmentApiClient _assessmentApi;
  late Future<AssessmentFormSetup> _assessmentFormSetup;
  AssessmentFormSetup? _loadedSetup;
  bool _loadingAssessments = true;
  String? _assessmentLoadError;
  _GradingRequirementsSnapshot? _gradingRequirements;
  bool _checkingGradingRequirements = false;
  String? _gradingRequirementsError;
  _Route _route = _Route.dashboard;
  final List<_Route> _history = [];
  _AssessmentRecord? _selectedAssessment;
  _StudentRecord? _selectedStudent;
  _ParentRecord? _selectedParent;
  _StudentRecord? _selectedEvaluationStudent;
  _StudentRecord? _selectedReportStudent;
  String _selectedClass = '';
  bool _editingAssessment = false;
  final TextEditingController _assessmentSearchController =
      TextEditingController();
  final ScrollController _assessmentTableScrollController = ScrollController();
  String _assessmentQuery = '';
  final Set<String> _assessmentTypeFilters = {};
  final Set<String> _assessmentSubjectFilters = {};
  final Set<String> _assessmentStatusFilters = {};
  int _assessmentSortColumnIndex = 0;
  bool _assessmentSortAscending = true;
  String _evaluationQuery = '';
  String _evaluationStatusFilter = 'All Status';
  final Set<String> _selectedEvaluationStudents = {};
  String _finalReportSearchQuery = '';
  String _finalReportFilter = 'All Streams';
  bool _isPublishingAllReports = false;
  final Set<int> _selectedFinalReportStreams = {};
  bool _isGeneratingReports = false;
  int _generatedReportsInCurrentRun = 0;
  int _failedReportsInCurrentRun = 0;
  String? _reportGenerationError;
  final Map<String, _EvaluationDraft> _evaluationDrafts = {};
  final Map<String, Map<String, double?>> _assessmentScores = {};
  final Map<String, String> _reportStatuses = {};
  final Set<String> _selectedReportStudents = {};
  final Set<String> _processingReportStudents = {};
  final Set<String> _publishingReportStudents = {};
  final Set<String> _reportPdfActions = {};
  final Set<String> _reopenedReportStudents = {};
  List<_StudentRecord>? _liveReportStudents;
  final Map<String, int> _reportAssessmentsCompleted = {};
  final Map<String, int> _reportAssessmentsRequired = {};
  final Map<String, List<String>> _reportMissingComponents = {};
  final Map<String, Map<String, dynamic>> _studentReportCards = {};
  final Map<String, Map<String, dynamic>> _activeReportCorrections = {};
  List<String> _configuredGradeLevels = const [];
  bool _refreshingReportCards = false;
  final Map<String, _ReportRemarksDraft> _reportRemarks = {};
  final Map<String, _ReportAudit> _reportAudit = {};
  String _reportCardFilter = 'All Students';
  final List<_FinalReportStream> _finalReportStreams = [];
  bool _loadingFinalReports = false;
  String? _finalReportLoadError;
  String get _displayTerm {
    final configured = widget.term.trim();
    if (configured.isNotEmpty) return configured;
    final loaded = _loadedSetup?.termName.trim() ?? '';
    return loaded.isEmpty ? 'Current Term' : loaded;
  }

  String get _displayAcademicYear {
    final configured = widget.academicYear.trim();
    if (configured.isNotEmpty) return configured;
    final loaded = _loadedSetup?.academicYearName.trim() ?? '';
    return loaded.isEmpty ? 'Current Academic Year' : loaded;
  }

  bool get _evaluationManager {
    final role = widget.viewerRole.trim().toUpperCase();
    return role == 'ADMIN' ||
        role == 'ADMINISTRATOR' ||
        role == 'HEADMASTER' ||
        role == 'HEAD_TEACHER' ||
        role == 'ASSISTANT_HEAD_TEACHER';
  }

  bool get _teacherViewer {
    final role = widget.viewerRole.trim().toUpperCase();
    return role == 'CLASS_TEACHER' ||
        role == 'SUBJECT_TEACHER' ||
        role == 'TEACHER';
  }

  @override
  void initState() {
    super.initState();
    if (widget.openFinalReportsOnLoad && _evaluationManager) {
      _route = _Route.finalReports;
    }
    _assessmentApi = AssessmentApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    _assessmentFormSetup = widget.customSchoolId.trim().isEmpty
        ? Future.error(
            const AssessmentApiException(
              'A school must be selected before loading assessments.',
            ),
          )
        : _loadAssessmentSetup();
    if (widget.openFinalReportsOnLoad && _evaluationManager) {
      _loadFinalReportOverview();
    } else {
      _loadLiveAssessments();
    }
  }

  @override
  void dispose() {
    _assessmentSearchController.dispose();
    _assessmentTableScrollController.dispose();
    super.dispose();
  }

  Future<AssessmentFormSetup> _loadAssessmentSetup() async {
    final setup = await _assessmentApi.getFormSetup(widget.customSchoolId);
    if (!_teacherViewer) return setup;

    TeacherWorkspaceSnapshot workspace;
    try {
      workspace = await TeacherWorkspaceApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      ).get(widget.customSchoolId);
    } catch (_) {
      throw const AssessmentApiException(
        'Your teaching assignments could not be loaded. Please try again.',
      );
    }
    return scopeAssessmentSetupForTeacher(setup, workspace);
  }

  Future<void> _loadLiveAssessments() async {
    if (mounted) {
      setState(() {
        _loadingAssessments = true;
        _assessmentLoadError = null;
      });
    }
    try {
      final setup = await _assessmentFormSetup;
      if (mounted) {
        setState(() => _loadedSetup = setup);
      } else {
        _loadedSetup = setup;
      }
      final orderedGrades = [...setup.gradeLevels]
        ..sort((a, b) {
          final aOrder = a.displayOrder == 0 ? a.id : a.displayOrder;
          final bOrder = b.displayOrder == 0 ? b.id : b.displayOrder;
          return aOrder.compareTo(bOrder);
        });
      _configuredGradeLevels = orderedGrades
          .map((grade) => grade.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      if (setup.streams.isEmpty) {
        throw AssessmentApiException(
          _teacherViewer
              ? 'No active class is assigned to this teacher account.'
              : 'No active class streams are configured for this school.',
        );
      }
      var stream = setup.streams.first;
      if (_selectedClass.isEmpty && widget.initialStreamId != null) {
        for (final option in setup.streams) {
          if (option.id == widget.initialStreamId) {
            stream = option;
            break;
          }
        }
      }
      for (final option in setup.streams) {
        if (option.label == _selectedClass) {
          stream = option;
          break;
        }
      }
      final values = await _assessmentApi.getAssessments(
        customSchoolId: widget.customSchoolId,
        streamId: stream.id,
        term: setup.termSequence,
        academicYearId: setup.academicYearId,
      );
      if (!mounted) return;
      setState(() {
        _selectedClass = stream.label;
        final selectedId = _selectedAssessment?.id;
        _assessments
          ..clear()
          ..addAll(values.map((item) => _assessmentFromApi(item, setup)));
        if (selectedId != null) {
          final refreshed = _assessments.where(
            (assessment) => assessment.id == selectedId,
          );
          if (refreshed.isNotEmpty) _selectedAssessment = refreshed.first;
        }
        _loadingAssessments = false;
      });
      if (_teacherViewer) {
        await _refreshGradingRequirements();
      }
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _assessmentLoadError = error.message;
        _loadingAssessments = false;
      });
    }
  }

  _AssessmentRecord _assessmentFromApi(
    Map<String, dynamic> item,
    AssessmentFormSetup setup,
  ) {
    final streamId = _jsonInt(item['streamId']);
    final stream = setup.streams.where((option) => option.id == streamId);
    final classOption = stream.isEmpty ? null : stream.first;
    final type = _assessmentTypeLabel(item['type']?.toString() ?? '');
    final entered = _jsonInt(item['scoresEntered']);
    final total = _jsonInt(item['totalStudents']);
    final statusValue = item['status']?.toString() ?? 'NOT_STARTED';
    final mapping = item['curriculum'];
    final indicators = mapping is Map<String, dynamic>
        ? (mapping['indicators'] is List
              ? mapping['indicators'] as List
              : const [])
        : const [];
    return _AssessmentRecord(
      id: item['assessmentId']?.toString() ?? '',
      title: item['title']?.toString() ?? 'Untitled assessment',
      type: type,
      subject: item['subjectName']?.toString() ?? '',
      date: _displayApiDate(item['date']),
      maxScore: _jsonNumber(item['maxScore']).round(),
      entered: entered,
      totalStudents: total,
      average: _jsonNumber(item['averageScore']),
      passRate: _jsonNumber(item['passRate']),
      highestScore: _jsonNumber(item['highestScore']),
      lowestScore: _jsonNumber(item['lowestScore']),
      status: _assessmentStatusLabel(statusValue),
      grading: entered == 0
          ? 'Not started'
          : total > 0 && entered >= total
          ? 'Fully graded'
          : 'In progress ($entered of $total)',
      term: setup.termName,
      academicYear: item['academicYear']?.toString() ?? setup.academicYearName,
      curriculumIndicators: indicators
          .whereType<Map<String, dynamic>>()
          .map(
            (indicator) => _CurriculumIndicator(
              code: indicator['code']?.toString() ?? '',
              text: indicator['description']?.toString() ?? '',
              strand: indicator['strand']?.toString() ?? '',
              subStrand: indicator['substrand']?.toString() ?? '',
            ),
          )
          .where((indicator) => indicator.code.isNotEmpty)
          .toList(),
      streamId: streamId,
      gradeLevelId: classOption?.gradeLevelId ?? _jsonInt(item['gradeLevelId']),
      schoolSubjectId: _jsonInt(item['schoolSubjectId']),
      description: item['description']?.toString() ?? '',
      officialSba: item['isOfficialSBA'] == true,
      className:
          classOption?.label ??
          [
            item['gradeName']?.toString() ?? '',
            item['streamName']?.toString() ?? '',
          ].where((value) => value.isNotEmpty).join(' - '),
      gradeName: item['gradeName']?.toString() ?? classOption?.gradeName ?? '',
      streamName:
          item['streamName']?.toString() ?? classOption?.streamName ?? '',
      academicYearId: setup.academicYearId,
      termSequence: setup.termSequence,
      createdBy: item['createdBy']?.toString() ?? '',
      updatedBy: item['updatedBy']?.toString() ?? '',
      createdAt: _displayApiDateTime(item['createdAt']),
      updatedAt: _displayApiDateTime(item['updatedAt']),
    );
  }

  int _jsonInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  double _jsonNumber(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String _displayApiDate(dynamic value) {
    DateTime? date;
    if (value is List && value.length >= 3) {
      date = DateTime(
        _jsonInt(value[0]),
        _jsonInt(value[1]),
        _jsonInt(value[2]),
      );
    } else {
      date = DateTime.tryParse(value?.toString() ?? '');
    }
    if (date == null) return value?.toString() ?? '';
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
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _displayApiDateTime(dynamic value) {
    if (value == null) return '';
    DateTime? date;
    if (value is List && value.length >= 5) {
      date = DateTime(
        _jsonInt(value[0]),
        _jsonInt(value[1]),
        _jsonInt(value[2]),
        _jsonInt(value[3]),
        _jsonInt(value[4]),
      );
    } else {
      date = DateTime.tryParse(value.toString());
    }
    if (date == null) return value.toString();
    return '${_displayApiDate(date.toIso8601String())} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _assessmentTypeLabel(String value) => switch (value) {
    'CAT1' => 'CAT 1',
    'CAT2' => 'CAT 2',
    'CAT3' => 'CAT 3',
    'CAT4' => 'CAT 4',
    'END_OF_TERM_EXAM' => 'End-of-Term Examination',
    'CLASS_EXERCISE' => 'Class Exercise',
    'HOMEWORK' => 'Homework',
    'QUIZ' => 'Quiz',
    'CLASS_TEST' => 'Class Test',
    'PROJECT' => 'Project',
    'PRACTICAL' => 'Practical',
    'EXPERIMENT' => 'Experiment',
    'ORAL' => 'Oral Assessment',
    'PERFORMANCE' => 'Performance Assessment',
    'PRACTICAL_EXPERIMENT' => 'Practical',
    'PERFORMANCE_ORAL' => 'Performance Assessment',
    _ => 'Assessment',
  };

  String _assessmentStatusLabel(String value) => switch (value) {
    'NOT_STARTED' => 'Not Started',
    'COMPLETE' => 'Graded',
    'IN_PROGRESS' => 'In Progress',
    'CLOSED' => 'Closed',
    _ => 'Not Started',
  };

  final List<_AssessmentRecord> _assessments = [];
  final List<_StudentRecord> _students = [];
  final List<_ParentRecord> _parents = [];

  void _open(_Route route) {
    setState(() {
      _history.add(_route);
      _route = route;
    });
  }

  void _back() {
    final destination = _history.isEmpty
        ? _Route.dashboard
        : _history.removeLast();
    setState(() => _route = destination);
    if (destination == _Route.finalReports) {
      _loadFinalReportOverview();
    }
  }

  Future<void> _openAssessment(_AssessmentRecord assessment) async {
    if (widget.customSchoolId.trim().isEmpty) {
      _selectedAssessment = assessment;
      _open(_Route.assessmentDetail);
      return;
    }
    try {
      final detail = await _assessmentApi.getAssessment(
        customSchoolId: widget.customSchoolId,
        assessmentId: assessment.id,
      );
      final setup = await _assessmentFormSetup;
      if (!mounted) return;
      _selectedAssessment = _assessmentFromApi(detail, setup);
      _open(_Route.assessmentDetail);
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<void> _duplicateAssessment(_AssessmentRecord source) async {
    try {
      final parsedDate = _apiDate(source.date);
      await _assessmentApi.createAssessment(
        customSchoolId: widget.customSchoolId,
        body: {
          'streamId': source.streamId,
          'schoolSubjectId': source.schoolSubjectId,
          'type': _assessmentTypeApiValue(source.type),
          'title': '${source.title} (Copy)',
          'date': parsedDate,
          'maxScore': source.maxScore,
          'term': source.termSequence,
          'academicYearId': source.academicYearId,
          'description': source.description,
          'isOfficialSBA': source.officialSba,
          'curriculumIndicatorCodes': source.curriculumIndicators
              .map((indicator) => indicator.code)
              .toList(),
        },
      );
      await _loadLiveAssessments();
      if (mounted) _notice('Assessment duplicated.');
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  String _assessmentTypeApiValue(String value) => switch (value) {
    'CAT 1' => 'CAT1',
    'CAT 2' => 'CAT2',
    'CAT 3' => 'CAT3',
    'CAT 4' || 'CAT 4 – Project/Assignment' => 'CAT4',
    'End of Term' ||
    'End-of-Term Exam' ||
    'End-of-Term Examination' ||
    'Exam' => 'END_OF_TERM_EXAM',
    'Homework' => 'HOMEWORK',
    'Class Exercise' => 'CLASS_EXERCISE',
    'Quiz' => 'QUIZ',
    'Project' => 'PROJECT',
    'Practical' => 'PRACTICAL',
    'Experiment' => 'EXPERIMENT',
    'Oral Assessment' => 'ORAL',
    'Performance Assessment' => 'PERFORMANCE',
    _ => 'CLASS_TEST',
  };

  String _apiDate(String value) {
    final parts = value.split(' ');
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    if (parts.length != 3 || months[parts[1]] == null) {
      return DateTime.now().toIso8601String().substring(0, 10);
    }
    return '${parts[2]}-${months[parts[1]].toString().padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
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
    try {
      await _assessmentApi.deleteAssessment(
        customSchoolId: widget.customSchoolId,
        assessmentId: assessment.id,
      );
      if (!mounted) return;
      setState(() {
        _assessments.remove(assessment);
        _assessmentScores.remove(assessment.id);
        _selectedAssessment = null;
      });
      _back();
      _notice('Assessment deleted.');
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<_GradingRequirementsSnapshot?> _refreshGradingRequirements() async {
    if (mounted) {
      setState(() {
        _checkingGradingRequirements = true;
        _gradingRequirementsError = null;
      });
    }
    try {
      final snapshot = await _fetchGradingRequirements();
      if (!mounted) return snapshot;
      setState(() {
        _gradingRequirements = snapshot;
        _checkingGradingRequirements = false;
      });
      return snapshot;
    } on AssessmentApiException catch (error) {
      if (!mounted) return null;
      setState(() {
        _checkingGradingRequirements = false;
        _gradingRequirementsError = error.message;
      });
      return null;
    } catch (_) {
      if (!mounted) return null;
      setState(() {
        _checkingGradingRequirements = false;
        _gradingRequirementsError =
            'Grading requirements could not be checked. Please try again.';
      });
      return null;
    }
  }

  Future<_GradingRequirementsSnapshot> _fetchGradingRequirements() async {
    if (widget.customSchoolId.trim().isEmpty) {
      return _localGradingRequirementsSnapshot();
    }
    final setup = await _assessmentFormSetup;
    final streams = setup.streams.where(
      (stream) => stream.label == _selectedClass,
    );
    if (streams.isEmpty) {
      throw const AssessmentApiException(
        'The selected class could not be resolved.',
      );
    }
    final response = await _assessmentApi.getStreamReportReadiness(
      customSchoolId: widget.customSchoolId,
      streamId: streams.first.id,
      term: setup.termSequence,
      academicYearId: setup.academicYearId,
      academicTermId: setup.termId,
    );
    final subjects = (response['subjectBreakdown'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final duplicates = _duplicateReportComponentsBySubject();
    final issues = <_GradingSubjectIssue>[];
    var requiredAssessments = 0;
    var presentAssessments = 0;
    var requiredScores = 0;
    var enteredScores = 0;
    var completeSubjects = 0;
    final classStudentCount = _jsonInt(response['totalStudents']);

    for (final subject in subjects) {
      final subjectName =
          subject['subjectName']?.toString().trim().isNotEmpty == true
          ? subject['subjectName'].toString().trim()
          : 'Subject';
      final rawBreakdown = subject['assessmentBreakdown'];
      final missingComponents = <String>[];
      var missingScores = 0;
      if (rawBreakdown is Map && rawBreakdown.isNotEmpty) {
        for (final entry in rawBreakdown.entries) {
          if (entry.value is! Map) continue;
          final component = Map<String, dynamic>.from(entry.value as Map);
          final componentLabel = _readinessAssessmentTypeLabel(
            entry.key.toString(),
          );
          final required = _jsonInt(component['totalStudents']);
          final entered = _jsonInt(
            component['studentsScored'],
          ).clamp(0, required);
          requiredAssessments++;
          requiredScores += required;
          enteredScores += entered;
          if (component['exists'] == true) {
            presentAssessments++;
            missingScores += (required - entered).clamp(0, required);
          } else {
            missingComponents.add(componentLabel);
          }
        }
      } else {
        missingComponents.addAll(_reportBasedAssessmentTypes);
        requiredAssessments += _reportBasedAssessmentTypes.length;
        requiredScores +=
            _reportBasedAssessmentTypes.length * classStudentCount;
      }
      final duplicateComponents =
          duplicates[subjectName.toLowerCase()] ?? const <String>[];
      final issue = _GradingSubjectIssue(
        subjectName: subjectName,
        missingComponents: missingComponents,
        missingScores: missingScores,
        duplicateComponents: duplicateComponents,
      );
      if (issue.hasIssues) {
        issues.add(issue);
      } else {
        completeSubjects++;
      }
    }

    return _GradingRequirementsSnapshot(
      totalSubjects: subjects.length,
      completeSubjects: completeSubjects,
      requiredAssessments: requiredAssessments,
      presentAssessments: presentAssessments,
      requiredScores: requiredScores,
      enteredScores: enteredScores,
      subjectIssues: issues,
    );
  }

  _GradingRequirementsSnapshot _localGradingRequirementsSnapshot() {
    final reportAssessments = _assessments.where((assessment) {
      final type = _canonicalAssessmentTypeLabel(assessment.type);
      return _reportBasedAssessmentTypes.contains(type);
    }).toList();
    final subjectNames = reportAssessments
        .map((assessment) => assessment.subject.trim())
        .where((subject) => subject.isNotEmpty)
        .toSet();
    final duplicates = _duplicateReportComponentsBySubject();
    final issues = <_GradingSubjectIssue>[];
    var completeSubjects = 0;
    var presentAssessments = 0;
    var requiredScores = 0;
    var enteredScores = 0;
    for (final subjectName in subjectNames) {
      final subjectAssessments = reportAssessments
          .where((assessment) => assessment.subject == subjectName)
          .toList();
      final presentTypes = subjectAssessments
          .map((assessment) => _canonicalAssessmentTypeLabel(assessment.type))
          .toSet();
      final missingComponents = _reportBasedAssessmentTypes
          .where((component) => !presentTypes.contains(component))
          .toList();
      var missingScores = 0;
      for (final assessment in subjectAssessments) {
        presentAssessments++;
        requiredScores += assessment.totalStudents;
        enteredScores += assessment.entered.clamp(0, assessment.totalStudents);
        missingScores += (assessment.totalStudents - assessment.entered).clamp(
          0,
          assessment.totalStudents,
        );
      }
      final issue = _GradingSubjectIssue(
        subjectName: subjectName,
        missingComponents: missingComponents,
        missingScores: missingScores,
        duplicateComponents:
            duplicates[subjectName.toLowerCase()] ?? const <String>[],
      );
      if (issue.hasIssues) {
        issues.add(issue);
      } else {
        completeSubjects++;
      }
    }
    return _GradingRequirementsSnapshot(
      totalSubjects: subjectNames.length,
      completeSubjects: completeSubjects,
      requiredAssessments:
          subjectNames.length * _reportBasedAssessmentTypes.length,
      presentAssessments: presentAssessments,
      requiredScores: requiredScores,
      enteredScores: enteredScores,
      subjectIssues: issues,
    );
  }

  Map<String, List<String>> _duplicateReportComponentsBySubject() {
    final counts = <String, Map<String, int>>{};
    for (final assessment in _assessments) {
      final type = _canonicalAssessmentTypeLabel(assessment.type);
      if (!_reportBasedAssessmentTypes.contains(type)) continue;
      final subject = assessment.subject.trim().toLowerCase();
      if (subject.isEmpty) continue;
      final subjectCounts = counts.putIfAbsent(subject, () => {});
      subjectCounts[type] = (subjectCounts[type] ?? 0) + 1;
    }
    return {
      for (final entry in counts.entries)
        entry.key: entry.value.entries
            .where((component) => component.value > 1)
            .map((component) => component.key)
            .toList(),
    };
  }

  Future<void> _showGradingRequirements() async {
    final snapshot = await _refreshGradingRequirements();
    if (!mounted) return;
    if (snapshot == null) {
      _notice(
        _gradingRequirementsError ??
            'Grading requirements could not be checked. Please try again.',
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: snapshot.met
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFFF3D6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                snapshot.met
                    ? Icons.celebration_outlined
                    : Icons.warning_amber_rounded,
                color: snapshot.met
                    ? const Color(0xFF087A5B)
                    : const Color(0xFFB65B00),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                snapshot.met
                    ? 'Grading requirements met'
                    : 'Grading requirements not met',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: ListView(
              shrinkWrap: true,
              children: [
                const SizedBox(height: 8),
                Text(
                  snapshot.met
                      ? 'Great work! All required assessments and student scores are complete for $_selectedClass and meet the configured GES grading requirements.'
                      : _gradingRequirementsLead(snapshot),
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _gradingRequirementChecks(snapshot),
                const SizedBox(height: 12),
                _gradingRequirementDetails(snapshot),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _gradingRequirementsLead(_GradingRequirementsSnapshot snapshot) {
    if (snapshot.totalSubjects == 0) {
      return 'No grading requirements are available for this class yet.';
    }
    if (snapshot.noAssessmentsCreated) {
      return 'No grading data has been entered for this class.';
    }
    if (snapshot.noScoresEntered) {
      return 'No student scores have been entered for this class.';
    }
    final count = snapshot.subjectIssues.length;
    return '$count subject${count == 1 ? '' : 's'} need attention before the configured GES grading requirements are met.';
  }

  Widget _gradingRequirementTotals(_GradingRequirementsSnapshot snapshot) {
    final color = snapshot.met
        ? const Color(0xFF087A5B)
        : const Color(0xFFB65B00);
    final background = snapshot.met
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFF8E8);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${snapshot.totalSubjects} subject${snapshot.totalSubjects == 1 ? '' : 's'} checked',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            '${snapshot.presentAssessments} of ${snapshot.requiredAssessments} required assessments created',
            style: const TextStyle(color: AppColors.text),
          ),
          const SizedBox(height: 3),
          Text(
            '${snapshot.enteredScores} of ${snapshot.requiredScores} required scores entered',
            style: const TextStyle(color: AppColors.text),
          ),
        ],
      ),
    );
  }

  Widget _gradingRequirementChecks(
    _GradingRequirementsSnapshot snapshot,
  ) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        _gradingRequirementCheckRow(
          complete: snapshot.assessmentComponentsComplete,
          title: 'Required assessments',
          detail:
              'All subjects have CAT 1, CAT 2, CAT 3, CAT 4 and Examination.',
        ),
        const Divider(height: 1),
        _gradingRequirementCheckRow(
          complete: snapshot.allScoresEntered,
          title: 'Score entry',
          detail: 'All required assessments are fully graded.',
        ),
      ],
    ),
  );

  Widget _gradingRequirementCheckRow({
    required bool complete,
    required String title,
    required String detail,
  }) {
    final color = complete ? const Color(0xFF087A5B) : const Color(0xFFB65B00);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            complete ? 'Complete' : 'Incomplete',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _gradingRequirementDetails(_GradingRequirementsSnapshot snapshot) =>
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text(
            'View details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Show subjects and grading totals'),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          children: [
            _gradingRequirementTotals(snapshot),
            if (snapshot.subjectIssues.isNotEmpty) ...[
              const SizedBox(height: 12),
              _gradingSubjectDetails(snapshot.subjectIssues),
            ],
          ],
        ),
      );

  Widget _gradingSubjectDetails(List<_GradingSubjectIssue> issues) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        for (var index = 0; index < issues.length; index++) ...[
          _gradingSubjectIssueRow(issues[index]),
          if (index < issues.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );

  Widget _gradingSubjectIssueRow(_GradingSubjectIssue issue) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFB65B00),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                issue.subjectName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                issue.detail,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Incomplete',
          style: TextStyle(
            color: Color(0xFFB65B00),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  String _readinessAssessmentTypeLabel(String value) =>
      switch (value.toUpperCase()) {
        'CAT1' => 'CAT 1',
        'CAT2' => 'CAT 2',
        'CAT3' => 'CAT 3',
        'CAT4' => 'CAT 4',
        'EXAM' || 'END_OF_TERM_EXAM' => 'End-of-Term Examination',
        _ => value,
      };

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
    AssessmentFormSetup setup;
    try {
      setup = await _assessmentFormSetup;
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
      return;
    }
    if (!mounted) return;
    if (setup.streams.isEmpty) {
      _notice('No active class streams are configured for this school.');
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ClassSelectorDialog(action: action, streams: setup.streams),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedClass = result);
    switch (action) {
      case 'Enter Assessment':
        _editingAssessment = false;
        _open(_Route.assessmentForm);
      case 'Manage Assessments':
        if (widget.customSchoolId.trim().isNotEmpty) {
          await _loadLiveAssessments();
          if (!mounted) return;
        }
        _open(_Route.assessments);
      case 'Generate Report Cards':
        if (!_evaluationManager) {
          _notice(
            'Only authorized academic managers can generate report cards.',
          );
          return;
        }
        if (widget.customSchoolId.trim().isNotEmpty) {
          await _loadLiveReportReadiness(setup, result);
          if (!mounted) return;
        }
        _open(_Route.reportCards);
      case 'Final Reports':
        _open(_Route.finalReports);
      case 'Evaluations & Comments':
        if (widget.customSchoolId.trim().isNotEmpty) {
          await _loadLiveReportReadiness(setup, result);
          if (!mounted) return;
        }
        _open(_Route.evaluationStudents);
      default:
        _open(_Route.evaluations);
    }
  }

  Future<void> _changeDashboardClass() async {
    AssessmentFormSetup setup;
    try {
      setup = await _assessmentFormSetup;
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
      return;
    } catch (_) {
      if (mounted) _notice('Your teaching assignments could not be loaded.');
      return;
    }
    if (!mounted || setup.streams.length < 2) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ClassSelectorDialog(
        action: 'View assessments for',
        streams: setup.streams,
      ),
    );
    if (result == null || !mounted || result == _selectedClass) return;
    setState(() => _selectedClass = result);
    await _loadLiveAssessments();
  }

  Future<void> _openFinalReportManagement() async {
    if (!_evaluationManager) {
      _notice(
        'Final Report Management is available to authorized academic managers only.',
      );
      return;
    }
    _open(_Route.finalReports);
    await _loadFinalReportOverview();
  }

  Future<void> _loadFinalReportOverview() async {
    if (widget.customSchoolId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _finalReportStreams.clear();
          _finalReportLoadError =
              'A school must be selected before loading final reports.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loadingFinalReports = true;
        _finalReportLoadError = null;
      });
    }
    try {
      final setup = await _assessmentFormSetup;
      _loadedSetup = setup;
      final orderedGrades = [...setup.gradeLevels]
        ..sort((a, b) {
          final aOrder = a.displayOrder == 0 ? a.id : a.displayOrder;
          final bOrder = b.displayOrder == 0 ? b.id : b.displayOrder;
          return aOrder.compareTo(bOrder);
        });
      _configuredGradeLevels = orderedGrades
          .map((grade) => grade.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();
      var failedStreams = 0;
      var evaluationProgressUnavailable = false;
      var progressionUnavailable = false;
      final evaluationReviewStatusByStudent = <String, String>{};
      final progressionByStudent = <String, String>{};
      try {
        final evaluationDashboard = await _assessmentApi
            .getTermEvaluationDashboard(
              schoolId: widget.customSchoolId,
              termId: setup.termId,
            );
        final evaluationReadiness = evaluationDashboard['readiness'];
        if (evaluationReadiness is Map) {
          final readinessStudents =
              (evaluationReadiness['students'] as List? ?? const [])
                  .whereType<Map>();
          for (final student in readinessStudents) {
            final studentId =
                student['customStudentId']?.toString().trim() ?? '';
            if (studentId.isEmpty) continue;
            evaluationReviewStatusByStudent[studentId] =
                student['reviewStatus']?.toString().trim().toUpperCase() ??
                'PENDING';
          }
        }
      } on AssessmentApiException {
        evaluationProgressUnavailable = true;
      }
      try {
        final remarks = await _assessmentApi.getReportCardRemarks(
          customSchoolId: widget.customSchoolId,
          termId: setup.termId,
        );
        for (final remark in remarks) {
          final studentId = remark['customStudentId']?.toString().trim() ?? '';
          if (studentId.isEmpty) continue;
          progressionByStudent[studentId] =
              remark['promotedTo']?.toString().trim() ?? '';
        }
      } on AssessmentApiException {
        progressionUnavailable = true;
      }
      final streams = await Future.wait(
        setup.streams.map((stream) async {
          if (stream.studentCount <= 0) {
            return _FinalReportStream(
              id: stream.id,
              name: stream.label,
              students: 0,
              generated: 0,
              ready: 0,
              published: 0,
              updateRequired: 0,
              academicGradesComplete: 0,
              evaluationsApproved: 0,
              evaluationsAwaitingApproval: 0,
              evaluationsNotSubmitted: 0,
              evaluationsRejected: 0,
              progressionSelected: 0,
              readinessAvailable: true,
              progressionAvailable: !progressionUnavailable,
            );
          }
          try {
            final response = await _assessmentApi.getStreamReportReadiness(
              customSchoolId: widget.customSchoolId,
              streamId: stream.id,
              term: setup.termSequence,
              academicYearId: setup.academicYearId,
              academicTermId: setup.termId,
            );
            final details =
                (response['studentReadinessDetails'] as List? ?? const [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
            final totalStudents = _jsonInt(response['totalStudents']) > 0
                ? _jsonInt(response['totalStudents'])
                : details.isNotEmpty
                ? details.length
                : stream.studentCount;
            final statuses = details
                .map(
                  (detail) =>
                      normalizeReportStatus(detail['reportStatus']?.toString()),
                )
                .toList();
            final published = statuses
                .where((status) => status == 'Published')
                .length;
            final updateRequired = statuses.where(reportNeedsUpdate).length;
            final pendingPublication = statuses
                .where((status) => status == 'Generated')
                .length;
            final generated = statuses.where(reportHasGeneratedVersion).length;
            final academicGradesComplete = details
                .where((detail) => detail['assessmentDataReady'] == true)
                .length;
            var evaluationsApproved = 0;
            var evaluationsAwaitingApproval = 0;
            var evaluationsNotSubmitted = 0;
            var evaluationsRejected = 0;
            var progressionSelected = 0;
            for (final detail in details) {
              final studentId =
                  detail['customStudentId']?.toString().trim() ?? '';
              final reviewStatus =
                  evaluationReviewStatusByStudent[studentId] ?? '';
              final blockers =
                  (detail['evaluationBlockers'] as List? ?? const [])
                      .map((value) => value.toString().toLowerCase())
                      .join(' ');
              if (detail['evaluationReady'] == true) {
                evaluationsApproved++;
              } else if (reviewStatus == 'CHANGES_REQUESTED' ||
                  reviewStatus == 'REJECTED' ||
                  blockers.contains('evaluation rejected')) {
                evaluationsRejected++;
              } else if (const {
                    'SUBMITTED',
                    'FINALIZED',
                    'UNDER_REVIEW',
                  }.contains(reviewStatus) ||
                  blockers.contains('leadership review pending') ||
                  blockers.contains('leadership approval pending')) {
                evaluationsAwaitingApproval++;
              } else if (detail['classTeacherCommentReady'] == true) {
                evaluationsNotSubmitted++;
              }

              final progression = progressionByStudent[studentId] ?? '';
              if (progression.isNotEmpty &&
                  progression.toLowerCase() != 'pending review') {
                progressionSelected++;
              }
            }
            return _FinalReportStream(
              id: stream.id,
              name: stream.label,
              students: totalStudents,
              generated: generated,
              ready: pendingPublication,
              published: published,
              updateRequired: updateRequired,
              academicGradesComplete: academicGradesComplete,
              evaluationsApproved: evaluationsApproved,
              evaluationsAwaitingApproval: evaluationsAwaitingApproval,
              evaluationsNotSubmitted: evaluationsNotSubmitted,
              evaluationsRejected: evaluationsRejected,
              progressionSelected: progressionSelected,
              readinessAvailable: true,
              progressionAvailable: !progressionUnavailable,
            );
          } on AssessmentApiException {
            failedStreams++;
            return _FinalReportStream(
              id: stream.id,
              name: stream.label,
              students: stream.studentCount,
              generated: 0,
              ready: 0,
              published: 0,
              updateRequired: 0,
              academicGradesComplete: 0,
              evaluationsApproved: 0,
              evaluationsAwaitingApproval: 0,
              evaluationsNotSubmitted: 0,
              evaluationsRejected: 0,
              progressionSelected: 0,
              readinessAvailable: false,
              progressionAvailable: !progressionUnavailable,
            );
          }
        }),
      );
      streams.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _finalReportStreams
          ..clear()
          ..addAll(streams);
        _selectedFinalReportStreams.removeWhere(
          (streamId) => !streams.any(
            (stream) => stream.id == streamId && stream.pendingPublication > 0,
          ),
        );
        _loadingFinalReports = false;
        final warnings = <String>[
          if (failedStreams > 0)
            'Report totals could not be loaded for $failedStreams stream${failedStreams == 1 ? '' : 's'}.',
          if (evaluationProgressUnavailable)
            'Evaluation progress could not be loaded.',
          if (progressionUnavailable)
            'Progression decisions could not be loaded.',
        ];
        _finalReportLoadError = warnings.isEmpty
            ? null
            : '${warnings.join(' ')} The streams are still shown.';
      });
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _finalReportStreams.clear();
        _loadingFinalReports = false;
        _finalReportLoadError = error.message;
      });
    }
  }

  Future<void> _openFinalReportStream(_FinalReportStream stream) async {
    try {
      final setup = await _assessmentFormSetup;
      setState(() => _selectedClass = stream.name);
      final loaded = await _loadLiveReportReadiness(setup, stream.name);
      if (!loaded || !mounted) return;
      _open(_Route.reportCards);
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<void> _openFinalReportEvaluations() async {
    try {
      final setup = await _assessmentFormSetup;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TermEvaluationWorkflowScreen(
            api: _assessmentApi,
            schoolId: widget.customSchoolId,
            viewerName: widget.viewerName,
            viewerRole: widget.viewerRole,
            setup: setup,
            managementProgressOnly: true,
          ),
        ),
      );
      if (mounted) await _loadFinalReportOverview();
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  List<_StudentRecord> get _reportCardStudents =>
      _liveReportStudents ?? _students;

  Map<String, dynamic>? _activeCorrectionFor(_StudentRecord student) =>
      _activeReportCorrections[student.id];

  String _activeCorrectionStatus(_StudentRecord student) =>
      '${_activeCorrectionFor(student)?['status'] ?? ''}'.toUpperCase();

  String _reportCardDisplayStatus(_StudentRecord student) =>
      switch (_activeCorrectionStatus(student)) {
        'PENDING' => 'Correction pending',
        'APPROVED_REGENERATION_REQUIRED' => 'Update required',
        'REGENERATION_IN_PROGRESS' => 'Regenerating',
        'REGENERATION_FAILED' => 'Regeneration failed',
        'REGENERATED_AWAITING_PUBLICATION' => 'Awaiting publication',
        'PUBLICATION_IN_PROGRESS' => 'Publishing',
        'PUBLICATION_FAILED' => 'Publication failed',
        _ => _reportStatusFor(student),
      };

  Future<bool> _loadLiveReportReadiness(
    AssessmentFormSetup setup,
    String classLabel,
  ) async {
    final matching = setup.streams.where(
      (stream) => stream.label == classLabel,
    );
    if (matching.isEmpty) {
      _notice('The selected stream could not be resolved.');
      return false;
    }
    try {
      final response = await _assessmentApi.getStreamReportReadiness(
        customSchoolId: widget.customSchoolId,
        streamId: matching.first.id,
        term: setup.termSequence,
        academicYearId: setup.academicYearId,
        academicTermId: setup.termId,
      );
      final remarkRows = await _assessmentApi.getReportCardRemarks(
        customSchoolId: widget.customSchoolId,
        termId: setup.termId,
      );
      final gradeRows = await _assessmentApi.getStreamGrades(
        customSchoolId: widget.customSchoolId,
        streamId: matching.first.id,
        term: setup.termSequence,
        academicYearId: setup.academicYearId,
      );
      List<Map<String, dynamic>> correctionRows;
      try {
        correctionRows = await _assessmentApi.getReportCorrections(
          customSchoolId: widget.customSchoolId,
        );
      } on AssessmentApiException {
        // Correction status is an enhancement to the report-card list. Keep
        // core readiness available if this auxiliary endpoint is unavailable.
        correctionRows = const [];
      }
      final activeCorrections = <String, Map<String, dynamic>>{};
      for (final item in correctionRows) {
        final status = '${item['status'] ?? ''}'.toUpperCase();
        final studentId = '${item['customStudentId'] ?? ''}'.trim();
        if (_jsonInt(item['termId']) != setup.termId ||
            studentId.isEmpty ||
            !const {
              'PENDING',
              'APPROVED_REGENERATION_REQUIRED',
              'REGENERATION_IN_PROGRESS',
              'REGENERATION_FAILED',
              'REGENERATED_AWAITING_PUBLICATION',
              'PUBLICATION_IN_PROGRESS',
              'PUBLICATION_FAILED',
            }.contains(status)) {
          continue;
        }
        activeCorrections.putIfAbsent(studentId, () => item);
      }
      final gradesByStudent = <String, List<Map<String, dynamic>>>{};
      for (final grade in gradeRows) {
        final studentId = grade['customStudentId']?.toString() ?? '';
        if (studentId.isNotEmpty) {
          gradesByStudent.putIfAbsent(studentId, () => []).add(grade);
        }
      }
      final values = response['studentReadinessDetails'];
      final students = values is List
          ? values
                .whereType<Map<String, dynamic>>()
                .map((item) {
                  final ready = item['canGenerateReport'] == true;
                  final assessmentDataReady =
                      item['assessmentDataReady'] == true;
                  final evaluationReady = item['evaluationReady'] != false;
                  final classTeacherCommentReady =
                      item['classTeacherCommentReady'] == true;
                  final evaluationBlockers =
                      (item['evaluationBlockers'] as List? ?? const [])
                          .map((value) => value.toString())
                          .where((value) => value.trim().isNotEmpty)
                          .toList();
                  final reportUpdateReasons =
                      (item['reportUpdateReasons'] as List? ?? const [])
                          .map((value) => value.toString())
                          .where((value) => value.trim().isNotEmpty)
                          .toList();
                  final studentId = item['customStudentId']?.toString() ?? '';
                  final studentGrades =
                      gradesByStudent[studentId] ??
                      const <Map<String, dynamic>>[];
                  final percentages = studentGrades
                      .where((grade) => grade['percentage'] != null)
                      .map((grade) => _jsonNumber(grade['percentage']))
                      .toList();
                  final average = percentages.isEmpty
                      ? 0.0
                      : percentages.reduce((a, b) => a + b) /
                            percentages.length;
                  final reportStatus = item['reportStatus']
                      ?.toString()
                      .trim()
                      .toUpperCase();
                  return _StudentRecord(
                    id: studentId,
                    name: item['studentName']?.toString() ?? 'Student',
                    gender: '',
                    average: average,
                    grade: percentages.isEmpty
                        ? '—'
                        : _gesOverallGrade(classLabel, average),
                    readiness: ready
                        ? 'Ready'
                        : assessmentDataReady
                        ? 'Evaluation incomplete'
                        : 'Scores incomplete',
                    assessmentDataReady: assessmentDataReady,
                    evaluationReady: evaluationReady,
                    classTeacherCommentReady: classTeacherCommentReady,
                    evaluationBlockers: evaluationBlockers,
                    reportStatus: normalizeReportStatus(reportStatus),
                    reportUpdateReasons: reportUpdateReasons,
                    reportRegenerationRequired:
                        item['reportRegenerationRequired'] == true,
                    reportRepublishRequired:
                        item['reportRepublishRequired'] == true,
                    reportVersion: _jsonInt(item['reportVersion']),
                    reportGeneratedAt:
                        item['reportGeneratedAt']?.toString() ?? '',
                    parent: '',
                  );
                })
                .where((student) => student.id.isNotEmpty)
                .toList()
          : <_StudentRecord>[];
      final evaluationRows = await Future.wait(
        students.map(
          (student) => _assessmentApi.getStudentEvaluations(
            customStudentId: student.id,
            termId: setup.termId,
          ),
        ),
      );
      final completed = <String, int>{};
      final required = <String, int>{};
      final missing = <String, List<String>>{};
      if (values is List) {
        for (final value in values.whereType<Map<String, dynamic>>()) {
          final id = value['customStudentId']?.toString() ?? '';
          if (id.isEmpty) continue;
          completed[id] = _jsonInt(value['assessmentsCompleted']);
          required[id] = _jsonInt(value['totalAssessmentsRequired']);
          final missingItems = <String>[];
          final incomplete = value['incompleteSubjects'];
          if (incomplete is List) {
            for (final subject
                in incomplete.whereType<Map<String, dynamic>>()) {
              final subjectName = subject['subjectName']?.toString() ?? '';
              final components = subject['missingAssessments'];
              if (components is List) {
                missingItems.addAll(
                  components.map(
                    (component) =>
                        '${subjectName.isEmpty ? 'Subject' : subjectName}: $component',
                  ),
                );
              }
            }
          }
          missing[id] = missingItems;
        }
      }
      setState(() {
        _activeReportCorrections
          ..clear()
          ..addAll(activeCorrections);
        _liveReportStudents = students;
        if (_selectedReportStudent != null) {
          final selectedId = _selectedReportStudent!.id;
          final selected = students.where(
            (student) => student.id == selectedId,
          );
          _selectedReportStudent = selected.isEmpty ? null : selected.first;
        }
        for (var index = 0; index < students.length; index++) {
          _hydrateLiveEvaluation(students[index], evaluationRows[index]);
        }
        for (final student in students) {
          _reportStatuses[student.id] = student.reportStatus;
          // Remarks and progression are term-specific. Clear any values held
          // by the long-lived workflow screen before hydrating the current
          // term so an empty API response cannot display a previous term's
          // decision as complete.
          _reportRemarks.remove(student.id);
          _reportAudit.remove(student.id);
        }
        for (final row in remarkRows) {
          final studentId = row['customStudentId']?.toString() ?? '';
          if (studentId.isEmpty) continue;
          _reportRemarks[studentId] = _ReportRemarksDraft(
            classTeacherRemarks: row['classTeacherRemarks']?.toString() ?? '',
            headTeacherRemarks: row['headTeacherRemarks']?.toString() ?? '',
            promotedTo: row['promotedTo']?.toString() ?? '',
            ignoreHeadTeacherRemark: row['ignoreHeadTeacherRemarks'] == true,
            reportStatus: row['reportStatus']?.toString() ?? 'DRAFT',
          );
          _reportAudit[studentId] = _ReportAudit(
            createdBy: row['createdBy']?.toString().trim().isNotEmpty == true
                ? row['createdBy'].toString()
                : widget.viewerName,
            createdAt: _displayApiDateTime(row['createdAt']),
            updatedBy: row['updatedBy']?.toString().trim().isNotEmpty == true
                ? row['updatedBy'].toString()
                : widget.viewerName,
            updatedAt: _displayApiDateTime(row['updatedAt']),
          );
        }
        _reportAssessmentsCompleted
          ..clear()
          ..addAll(completed);
        _reportAssessmentsRequired
          ..clear()
          ..addAll(required);
        _reportMissingComponents
          ..clear()
          ..addAll(missing);
      });
      return true;
    } on AssessmentApiException catch (error) {
      _notice(error.message);
      return false;
    }
  }

  String _gesOverallGrade(String classLabel, double average) {
    final basicMatch = RegExp(
      r'(?:Basic|Grade)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(classLabel);
    final level = int.tryParse(basicMatch?.group(1) ?? '') ?? 1;
    if (average >= 80) return 'HP';
    if (level <= 6) {
      if (average >= 66) return 'P';
      if (average >= 50) return 'AP';
      return 'D';
    }
    if (average >= 68) return 'P';
    if (average >= 54) return 'AP';
    if (average >= 40) return 'D';
    return 'E';
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
        _Route.reportCards =>
          _evaluationManager ? _reportCards() : _assessmentRegister(),
        _Route.studentReport =>
          _evaluationManager ? _studentReportPage() : _assessmentRegister(),
        _Route.finalReports =>
          _evaluationManager ? _finalReports() : _assessmentRegister(),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final stackActions =
                      actions.isNotEmpty && constraints.maxWidth < 820;
                  final titleBlock = Column(
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
                  );
                  final heading = Row(
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
                      Expanded(child: titleBlock),
                    ],
                  );
                  if (actions.isEmpty) return heading;
                  final actionWrap = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: actions,
                  );
                  if (stackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 12),
                        actionWrap,
                      ],
                    );
                  }
                  return Row(
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
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      actionWrap,
                    ],
                  );
                },
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
    final completed = _assessments
        .where((assessment) => assessment.entered >= assessment.totalStudents)
        .length;
    final enteredScores = _assessments.fold<int>(
      0,
      (total, assessment) => total + assessment.entered,
    );
    final requiredScores = _assessments.fold<int>(
      0,
      (total, assessment) => total + assessment.totalStudents,
    );
    final average = _assessments.isEmpty
        ? 0.0
        : _assessments.fold<double>(
                0,
                (total, assessment) => total + assessment.average,
              ) /
              _assessments.length;
    final assignedClassCount = _loadedSetup?.streams.length ?? 0;
    final selectedStream = _loadedSetup?.streams
        .where((stream) => stream.label == _selectedClass)
        .firstOrNull;
    final assignedSubjectCount =
        _loadedSetup?.subjects
            .where((subject) => subject.isAvailableIn(selectedStream?.id))
            .length ??
        0;
    return _page(
      title: _teacherViewer ? 'My Assessments' : 'Assessment Dashboard',
      subtitle: _teacherViewer && _selectedClass.isNotEmpty
          ? '$_selectedClass • $_displayTerm • $_displayAcademicYear'
          : '$_displayTerm - $_displayAcademicYear',
      showBack: false,
      actions: [
        if (_teacherViewer && assignedClassCount > 1)
          _outlineButton(
            'Change class',
            Icons.swap_horiz_rounded,
            _changeDashboardClass,
          ),
        TextButton.icon(
          onPressed: _showTermReportGuide,
          icon: const Icon(Icons.help_outline_rounded, size: 17),
          label: const Text('How term reports work'),
        ),
        if (_teacherViewer)
          FilledButton.icon(
            onPressed: () {
              _editingAssessment = false;
              _open(_Route.assessmentForm);
            },
            icon: const Icon(Icons.add, size: 17),
            label: const Text('New Assessment'),
          ),
      ],
      children: [
        if (_teacherViewer) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              border: Border.all(color: AppColors.green.withValues(alpha: .25)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    assignedClassCount == 0
                        ? 'No active teaching assignment is connected to your account.'
                        : 'Showing only your assigned class${assignedClassCount == 1 ? '' : 'es'} and $assignedSubjectCount available subject${assignedSubjectCount == 1 ? '' : 's'} for this class.',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(
          builder: (_, constraints) => _statGrid(constraints.maxWidth, [
            (
              _teacherViewer ? 'MY ASSESSMENTS' : 'ACTIVE ASSESSMENTS',
              '${_assessments.length}',
              _teacherViewer ? 'For $_selectedClass' : 'For the selected term',
            ),
            ('FULLY GRADED', '$completed', 'Assessments with all scores'),
            (
              'AVG SCORE',
              average.toStringAsFixed(1),
              'Raw score across assessments',
            ),
            (
              'SCORE ENTRY',
              requiredScores == 0
                  ? '0%'
                  : '${(enteredScores * 100 / requiredScores).toStringAsFixed(0)}%',
              '$enteredScores of $requiredScores scores entered',
            ),
          ]),
        ),
        if (_teacherViewer) ...[
          if (_gradingRequirements?.met == true) ...[
            const SizedBox(height: 18),
            _gradingRequirementsBanner(),
          ],
          const SizedBox(height: 18),
          _teacherAssessmentRegisterPanel(),
        ] else ...[
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
                    if (!_evaluationManager)
                      _actionCard(
                        width,
                        'Evaluations & Comments',
                        'Complete ratings and class-teacher comments',
                        Icons.fact_check_outlined,
                        AppColors.amber,
                        _openTermEvaluations,
                      ),
                    if (_evaluationManager) ...[
                      _actionCard(
                        width,
                        'Generate Report Cards',
                        'Review readiness and generate reports',
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
                        _openFinalReportManagement,
                      ),
                    ],
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
                title: _teacherViewer
                    ? 'My Recent Assessments'
                    : 'Recent Assessments',
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
                child: Column(
                  children: [
                    _ProgressRow(
                      'Completed',
                      completed,
                      _assessments.length,
                      AppColors.green,
                    ),
                    _ProgressRow(
                      'In progress',
                      _assessments
                          .where(
                            (assessment) =>
                                assessment.entered > 0 &&
                                assessment.entered < assessment.totalStudents,
                          )
                          .length,
                      _assessments.length,
                      AppColors.amber,
                    ),
                    _ProgressRow(
                      'Not started',
                      _assessments
                          .where((assessment) => assessment.entered == 0)
                          .length,
                      _assessments.length,
                      AppColors.red,
                    ),
                  ],
                ),
              );
              return stacked
                  ? Column(
                      children: [
                        recent,
                        const SizedBox(height: 16),
                        completion,
                      ],
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
        ],
      ],
    );
  }

  Widget _teacherAssessmentRegisterPanel() {
    final visibleAssessments = _visibleAssessments();
    return _section(
      title: 'Assessment register',
      action: OutlinedButton.icon(
        onPressed: _checkingGradingRequirements
            ? null
            : _showGradingRequirements,
        icon: const Icon(Icons.fact_check_outlined, size: 16),
        label: const Text('Check grading requirements'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _assessmentFilterBar(),
          const SizedBox(height: 16),
          _assessmentTable(visibleAssessments),
        ],
      ),
    );
  }

  Widget _gradingRequirementsBanner() {
    const color = Color(0xFF087A5B);
    const background = Color(0xFFECFDF5);
    const border = Color(0xFFA7F3D0);
    return Container(
      key: const ValueKey('grading-requirements-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.celebration_outlined, color: color, size: 25),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grading requirements met',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Great work! All required assessments and student scores are complete.',
                      style: const TextStyle(color: AppColors.text),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Required CAT 1–4 and Examination complete · All assessments fully graded',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = OutlinedButton(
            onPressed: _checkingGradingRequirements
                ? null
                : _showGradingRequirements,
            child: const Text('View grading summary'),
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 18),
              action,
            ],
          );
        },
      ),
    );
  }

  Future<void> _showTermReportGuide() async {
    Widget step({
      required String number,
      required String title,
      required String detail,
      required Color color,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
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
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 16),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.route_outlined,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From assessment to term report',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'How work moves from the teacher to the head teacher',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TEACHER PREPARES THE RECORDS',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      step(
                        number: '1',
                        title: 'Create the required assessments',
                        detail:
                            'Create the term-report assessments for each assigned class and subject.',
                        color: AppColors.green,
                      ),
                      step(
                        number: '2',
                        title: 'Enter and verify every score',
                        detail:
                            'Complete score entry for every student. Correct mistakes before the assessment is treated as fully graded.',
                        color: AppColors.green,
                      ),
                      step(
                        number: '3',
                        title: 'Complete evaluations and remarks',
                        detail:
                            'Submit the required student evaluations and class-teacher remarks for the term.',
                        color: AppColors.green,
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Handoff: when scores, evaluations and remarks are complete, the class becomes ready for the head teacher’s review.',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const Text(
                        'HEAD TEACHER COMPLETES THE REPORT',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      step(
                        number: '4',
                        title: 'Check readiness and resolve gaps',
                        detail:
                            'Open Generate Report Cards. Students under Needs Attention show what is still missing. Generate only when they are ready.',
                        color: const Color(0xFF2563EB),
                      ),
                      step(
                        number: '5',
                        title: 'Review, then publish',
                        detail:
                            'Review the generated report, add any required head-teacher remark, and publish the approved report to make it official.',
                        color: const Color(0xFF2563EB),
                      ),
                      const Text(
                        'If scores, evaluations or remarks change after generation, regenerate the report before publishing the updated version.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTermEvaluations() async {
    try {
      final setup = await _assessmentFormSetup;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TermEvaluationWorkflowScreen(
            api: _assessmentApi,
            schoolId: widget.customSchoolId,
            viewerName: widget.viewerName,
            viewerRole: widget.viewerRole,
            setup: setup,
          ),
        ),
      );
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Widget _assessmentRegister() {
    final visibleAssessments = _visibleAssessments();
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
                          _selectedClass,
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
                    '$_displayTerm • $_displayAcademicYear',
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
                    onPressed: _checkingGradingRequirements
                        ? null
                        : _showGradingRequirements,
                    icon: const Icon(Icons.fact_check_outlined, size: 15),
                    label: const Text('Check grading requirements'),
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
          _assessmentTable(visibleAssessments),
        ],
      ),
    );
  }

  List<_AssessmentRecord> _visibleAssessments() {
    final visible = _assessments.where((assessment) {
      final query = _assessmentQuery.trim().toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          assessment.title.toLowerCase().contains(query) ||
          assessment.id.toLowerCase().contains(query);
      final matchesType =
          _assessmentTypeFilters.isEmpty ||
          _assessmentTypeFilters.contains(assessment.type);
      final matchesSubject =
          _assessmentSubjectFilters.isEmpty ||
          _assessmentSubjectFilters.contains(assessment.subject);
      final matchesStatus =
          _assessmentStatusFilters.isEmpty ||
          _assessmentStatusFilters.contains(assessment.status);
      return matchesQuery && matchesType && matchesSubject && matchesStatus;
    }).toList();
    visible.sort(_compareVisibleAssessments);
    return visible;
  }

  Widget _assessmentTable(List<_AssessmentRecord> visibleAssessments) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _loadingAssessments
          ? const Padding(
              padding: EdgeInsets.all(46),
              child: Center(child: CircularProgressIndicator()),
            )
          : _assessmentLoadError != null
          ? Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _assessmentLoadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loadLiveAssessments,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : visibleAssessments.isEmpty
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
              child: LayoutBuilder(
                builder: (context, constraints) => Scrollbar(
                  controller: _assessmentTableScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _assessmentTableScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        sortColumnIndex: _assessmentSortColumnIndex,
                        sortAscending: _assessmentSortAscending,
                        headingRowHeight: 36,
                        dataRowMinHeight: 54,
                        dataRowMaxHeight: 62,
                        horizontalMargin: 14,
                        columnSpacing: 20,
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF9FAFB),
                        ),
                        headingTextStyle: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4,
                        ),
                        columns: [
                          DataColumn(
                            label: const Text('ASSESSMENT'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('TYPE'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('SUBJECT'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('DATE'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('MAX SCORE'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('SCORE ENTRY'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('AVG SCORE'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('PASS RATE'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('STATUS'),
                            onSort: _sortAssessmentRegister,
                          ),
                          DataColumn(
                            label: const Text('GRADING'),
                            onSort: _sortAssessmentRegister,
                          ),
                        ],
                        rows: visibleAssessments
                            .map((assessment) => _oldAssessmentRow(assessment))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _sortAssessmentRegister(int columnIndex, bool ascending) {
    setState(() {
      _assessmentSortColumnIndex = columnIndex;
      _assessmentSortAscending = ascending;
    });
  }

  int _compareVisibleAssessments(
    _AssessmentRecord left,
    _AssessmentRecord right,
  ) {
    final comparison = switch (_assessmentSortColumnIndex) {
      0 => left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      1 => left.type.toLowerCase().compareTo(right.type.toLowerCase()),
      2 => left.subject.toLowerCase().compareTo(right.subject.toLowerCase()),
      3 => _apiDate(left.date).compareTo(_apiDate(right.date)),
      4 => left.maxScore.compareTo(right.maxScore),
      5 => _scoreEntryProgress(left).compareTo(_scoreEntryProgress(right)),
      6 => left.average.compareTo(right.average),
      7 => left.passRate.compareTo(right.passRate),
      8 => left.status.toLowerCase().compareTo(right.status.toLowerCase()),
      9 => _gradingLabel(left).compareTo(_gradingLabel(right)),
      _ => 0,
    };
    final resolved = comparison == 0
        ? left.title.toLowerCase().compareTo(right.title.toLowerCase())
        : comparison;
    return _assessmentSortAscending ? resolved : -resolved;
  }

  double _scoreEntryProgress(_AssessmentRecord assessment) =>
      assessment.totalStudents == 0
      ? 0
      : assessment.entered / assessment.totalStudents;

  String _gradingLabel(_AssessmentRecord assessment) => assessment.entered == 0
      ? 'Not Started'
      : assessment.entered == assessment.totalStudents
      ? 'Fully Graded'
      : 'In Progress';

  Future<void> _showAssessmentMultiSelect({
    required String title,
    required List<String> options,
    required Set<String> selected,
  }) async {
    final pending = Set<String>.from(selected);
    var searchQuery = '';
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final query = searchQuery.trim().toLowerCase();
          final visible = options
              .where((option) => option.toLowerCase().contains(query))
              .toList();
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 380,
              height: 430,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (value) =>
                        setDialogState(() => searchQuery = value),
                    decoration: const InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: visible.isEmpty
                        ? const Center(child: Text('No matches found'))
                        : ListView.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              final option = visible[index];
                              return CheckboxListTile(
                                value: pending.contains(option),
                                title: Text(option),
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                onChanged: (checked) => setDialogState(() {
                                  if (checked == true) {
                                    pending.add(option);
                                  } else {
                                    pending.remove(option);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(pending.clear),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => setDialogState(() {
                  pending
                    ..clear()
                    ..addAll(options);
                }),
                child: const Text('Select all'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, pending),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      selected
        ..clear()
        ..addAll(result);
    });
  }

  Widget _assessmentMultiSelectButton({
    required String allLabel,
    required String pluralLabel,
    required List<String> options,
    required Set<String> selected,
    double width = 170,
  }) {
    final label = selected.isEmpty
        ? allLabel
        : selected.length == 1
        ? selected.first
        : '${selected.length} $pluralLabel selected';
    return SizedBox(
      width: width,
      height: 56,
      child: OutlinedButton(
        onPressed: () => _showAssessmentMultiSelect(
          title: 'Select $pluralLabel',
          options: options,
          selected: selected,
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: const BorderSide(color: Color(0xFFD7DEE3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _assessmentFilterBar() {
    final subjects =
        _assessments.map((assessment) => assessment.subject).toSet().toList()
          ..sort();
    final hasActiveFilters =
        _assessmentQuery.trim().isNotEmpty ||
        _assessmentTypeFilters.isNotEmpty ||
        _assessmentSubjectFilters.isNotEmpty ||
        _assessmentStatusFilters.isNotEmpty;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: _assessmentSearchController,
            onChanged: (value) => setState(() => _assessmentQuery = value),
            decoration: const InputDecoration(
              hintText: 'Search...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        _assessmentMultiSelectButton(
          allLabel: 'All Types',
          pluralLabel: 'types',
          options: _allAssessmentTypes,
          selected: _assessmentTypeFilters,
          width: 220,
        ),
        _assessmentMultiSelectButton(
          allLabel: 'All Subjects',
          pluralLabel: 'subjects',
          options: subjects,
          selected: _assessmentSubjectFilters,
        ),
        _assessmentMultiSelectButton(
          allLabel: 'All Statuses',
          pluralLabel: 'statuses',
          options: const ['Not Started', 'In Progress', 'Graded', 'Closed'],
          selected: _assessmentStatusFilters,
        ),
        if (hasActiveFilters)
          SizedBox(
            height: 56,
            child: TextButton.icon(
              onPressed: () {
                _assessmentSearchController.clear();
                setState(() {
                  _assessmentQuery = '';
                  _assessmentTypeFilters.clear();
                  _assessmentSubjectFilters.clear();
                  _assessmentStatusFilters.clear();
                });
              },
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Clear all'),
            ),
          ),
      ],
    );
  }

  DataRow _oldAssessmentRow(_AssessmentRecord assessment) {
    final progress = _scoreEntryProgress(assessment);
    final gradingLabel = _gradingLabel(assessment);
    return DataRow(
      onSelectChanged: (_) => _openAssessment(assessment),
      cells: [
        DataCell(
          SizedBox(
            width: 220,
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
            assessment.type == 'CAT 4 – Project/Assignment'
                ? const Color(0xFFF3E8FF)
                : assessment.type == 'End-of-Term Exam'
                ? const Color(0xFFFFF1E8)
                : const Color(0xFFEFF6FF),
            assessment.type == 'CAT 4 – Project/Assignment'
                ? const Color(0xFF7C3AED)
                : assessment.type == 'End-of-Term Exam'
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
            assessment.entered == 0
                ? '—'
                : assessment.average.toStringAsFixed(1),
            style: TextStyle(
              color: assessment.entered == 0
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          Text(
            assessment.entered == 0
                ? '—'
                : '${assessment.passRate.toStringAsFixed(1)}%',
            style: TextStyle(
              color: assessment.entered == 0
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF009688),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DataCell(
          _oldRegisterBadge(
            assessment.status,
            assessment.status == 'In Progress'
                ? const Color(0xFFDFF7EC)
                : assessment.status == 'Not Started'
                ? const Color(0xFFFFF4D8)
                : assessment.status == 'Closed'
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFEFF6FF),
            assessment.status == 'In Progress'
                ? const Color(0xFF047857)
                : assessment.status == 'Not Started'
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
                : gradingLabel == 'In Progress'
                ? const Color(0xFFFFF7E6)
                : const Color(0xFFDFF7EC),
            gradingLabel == 'Not Started'
                ? const Color(0xFFDC2626)
                : gradingLabel == 'In Progress'
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
        ? (a.entered == 0 ? '—' : a.highestScore.toStringAsFixed(1))
        : savedScores.reduce((x, y) => x > y ? x : y).toStringAsFixed(1);
    final lowest = savedScores.isEmpty
        ? (a.entered == 0 ? '—' : a.lowestScore.toStringAsFixed(1))
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
                              _oldInfoField('Grade Level', a.gradeName),
                              _oldInfoField('Stream', a.streamName),
                              _oldInfoField('Subject', a.subject),
                              _oldInfoField(
                                'Term & Year',
                                '${a.term} • ${a.academicYear.replaceAll(' Academic Year', '')}',
                              ),
                              _oldInfoField(
                                'Created By',
                                a.createdBy.isEmpty ? '—' : a.createdBy,
                              ),
                              _oldInfoField(
                                'Last Updated',
                                a.updatedAt.isNotEmpty
                                    ? a.updatedAt
                                    : a.createdAt.isNotEmpty
                                    ? a.createdAt
                                    : '—',
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
                                    a.entered == 0
                                        ? '—'
                                        : a.average.toStringAsFixed(1),
                                    const Color(0xFF009688),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _oldStat(
                                    'Pass Rate',
                                    a.entered == 0
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
                            _oldMetaRow('Grade Level ID', '${a.gradeLevelId}'),
                            _oldMetaRow('Stream ID', '${a.streamId}'),
                            _oldMetaRow('Subject ID', '${a.schoolSubjectId}'),
                            _oldMetaRow('Created At', a.createdAt),
                            _oldMetaRow('Updated At', a.updatedAt),
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
    return FutureBuilder<AssessmentFormSetup>(
      future: _assessmentFormSetup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _AssessmentSetupError(
            message: snapshot.error is AssessmentApiException
                ? (snapshot.error! as AssessmentApiException).message
                : 'Unable to load the assessment form.',
            onRetry: () => setState(() {
              _assessmentFormSetup = _loadAssessmentSetup();
            }),
            onBack: _back,
          );
        }
        return _AssessmentFormPage(
          title: _editingAssessment ? 'Edit Assessment' : 'New Assessment',
          subtitle: _selectedClass,
          selectedStream: snapshot.data!.streams
              .where((stream) => stream.label == _selectedClass)
              .firstOrNull,
          source: source,
          setup: snapshot.data!,
          api: _assessmentApi,
          customSchoolId: widget.customSchoolId,
          onBack: _back,
          onCurriculum: _showCurriculumDrawer,
          onSave: (record) {
            setState(() {
              if (_editingAssessment && _selectedAssessment != null) {
                final index = _assessments.indexWhere(
                  (assessment) => assessment.id == _selectedAssessment!.id,
                );
                if (index >= 0) {
                  _assessments[index] = record;
                } else {
                  _assessments.insert(0, record);
                }
              } else {
                _assessments.insert(0, record);
              }
              _selectedAssessment = record;
              _selectedClass = record.className;
            });
            _notice(
              _editingAssessment
                  ? 'Assessment changes saved.'
                  : 'Assessment created.',
            );
            _back();
            _loadLiveAssessments();
          },
        );
      },
    );
  }

  Widget _scoreSheet() {
    final a = _selectedAssessment ?? _assessments.first;
    return _ScoreSheetPage(
      assessment: a,
      gradingGradeLevelId: _gradingGradeLevelId(a),
      api: _assessmentApi,
      customSchoolId: widget.customSchoolId,
      submittedBy: widget.viewerName,
      onBack: _back,
      onExport: (csv) async {
        final downloaded = await exportAssessmentCsv(
          _assessmentCsvFileName(a),
          csv,
        );
        if (!mounted) return;
        _notice(
          downloaded
              ? 'Score sheet CSV downloaded.'
              : 'Score sheet CSV copied to the clipboard.',
        );
      },
      onSaved: () {
        _loadLiveAssessments();
        _notice('Scores saved successfully.');
      },
    );
  }

  int _gradingGradeLevelId(_AssessmentRecord assessment) {
    final gradeName = assessment.gradeName.trim().toLowerCase();
    final isPreBasic =
        gradeName.contains('creche') ||
        gradeName.contains('nursery') ||
        gradeName.contains('kindergarten') ||
        RegExp(r'\bkg\s*[12]?\b').hasMatch(gradeName) ||
        gradeName.contains('pre-basic') ||
        gradeName.contains('pre basic');
    if (isPreBasic) {
      for (final grade in _loadedSetup?.gradeLevels ?? const []) {
        final name = grade.name.trim().toLowerCase();
        if (name == 'basic 1' || name == 'grade 1') return grade.id;
      }
      return 3;
    }
    return assessment.gradeLevelId;
  }

  String _assessmentCsvFileName(_AssessmentRecord assessment) {
    final safeTitle = assessment.title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${safeTitle.isEmpty ? assessment.id : safeTitle}-scores.csv';
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
        status: index >= 0 && index < 4 ? 'Submitted' : 'Not started',
        displayScore: index >= 0 ? initialScores[index] : null,
        lastEvaluated: index >= 0 ? evaluatedDates[index] : 'Never',
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
      title: 'Evaluations & Comments',
      subtitle: '$_displayTerm - Conduct and terminal evaluation',
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
    final evaluationStudents = _reportCardStudents;
    final filteredStudents = evaluationStudents.where((student) {
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
    final pending = evaluationStudents
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
        DataCell(SizedBox(width: 100, child: _evaluationStatus(evaluated))),
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
    Future<void> save() async {
      if (widget.customSchoolId.trim().isNotEmpty) {
        final entries = <Map<String, dynamic>>[
          {
            'criterion': 'HOMEWORK',
            'score': evaluation.homework,
            'teacherComments': evaluation.comments['homework'] ?? '',
          },
          {
            'criterion': 'ATTENTIVENESS',
            'score': evaluation.punctuality,
            'teacherComments': evaluation.comments['punctuality'] ?? '',
          },
          {
            'criterion': 'TEAMWORK',
            'score': evaluation.neatness,
            'teacherComments': evaluation.comments['neatness'] ?? '',
          },
          {
            'criterion': 'CLASS_PARTICIPATION',
            'score': evaluation.attitude,
            'teacherComments': evaluation.comments['attitude'] ?? '',
          },
          {
            'criterion': 'RESPECT_AND_DISCIPLINE',
            'score': evaluation.discipline,
            'teacherComments': evaluation.comments['discipline'] ?? '',
          },
          {
            'criterion': 'NEATNESS',
            'score': evaluation.organization,
            'teacherComments': evaluation.comments['organization'] ?? '',
          },
        ];
        for (final entry in entries) {
          entry['overallComment'] = evaluation.remark;
        }
        try {
          final setup = await _assessmentFormSetup;
          await _assessmentApi.saveStudentEvaluations(
            customSchoolId: widget.customSchoolId,
            customStudentId: student.id,
            termId: setup.termId,
            evaluatedBy: widget.viewerName,
            evaluations: entries,
          );
        } on AssessmentApiException catch (error) {
          if (mounted) _notice(error.message);
          return;
        }
      }
      if (!mounted) return;
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
                          _displayTerm.replaceAll('Term ', 'Term'),
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
    return normalizeReportStatus(
      _reportStatuses[student.id] ?? student.reportStatus,
    );
  }

  bool _gradesComplete(_StudentRecord student) => student.assessmentDataReady;

  bool _evaluationComplete(_StudentRecord student) => student.evaluationReady;

  String _classTeacherCommentFor(
    _StudentRecord student,
    _ReportRemarksDraft legacyRemarks,
  ) {
    if (!student.classTeacherCommentReady) return '';
    final generatedComment =
        _studentReportCards[student.id]?['classTeacherRemarks']
            ?.toString()
            .trim();
    if (generatedComment != null &&
        generatedComment.isNotEmpty &&
        generatedComment.toLowerCase() != 'remarks pending') {
      return generatedComment;
    }
    return legacyRemarks.classTeacherRemarks.trim();
  }

  List<String> _reportReadinessBlockers(_StudentRecord student) {
    final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    return [
      if (!_gradesComplete(student)) 'Grades incomplete',
      if (!_evaluationComplete(student)) 'Evaluation pending',
      if (!student.classTeacherCommentReady) 'Teacher remark pending',
      if (remarks.promotedTo.trim().isEmpty) 'Progression decision pending',
    ];
  }

  bool _generationReady(_StudentRecord student) =>
      _reportReadinessBlockers(student).isEmpty;

  String _evaluationAndCommentsStatusFor(_StudentRecord student) {
    if (student.evaluationReady) return 'Approved';
    final blockers = student.evaluationBlockers
        .map((blocker) => blocker.toLowerCase())
        .join(' ');
    if (blockers.contains('rejected') ||
        blockers.contains('changes requested')) {
      return 'Rejected';
    }
    if (blockers.contains('leadership review pending') ||
        blockers.contains('leadership approval pending')) {
      return 'Awaiting approval';
    }
    if (student.classTeacherCommentReady) return 'Not submitted';
    return 'Incomplete';
  }

  String _progressionStatusFor(_StudentRecord student) {
    final decision = (_reportRemarks[student.id] ?? _ReportRemarksDraft.empty())
        .promotedTo
        .trim();
    return decision.isNotEmpty && decision.toLowerCase() != 'pending review'
        ? 'Selected'
        : 'Pending';
  }

  bool _canGenerateOrRegenerate(_StudentRecord student) {
    final status = _reportStatusFor(student);
    return _generationReady(student) &&
        (status == 'Not Generated' || student.reportRegenerationRequired);
  }

  String _reportReadinessSummary(_StudentRecord student) {
    return summarizeReportReadiness(_reportReadinessBlockers(student));
  }

  String _publicationReadiness(_StudentRecord student) {
    final blockers = _reportReadinessBlockers(student);
    if (blockers.isNotEmpty) return _reportReadinessSummary(student);
    final status = _reportStatusFor(student);
    if (status == 'Update required' ||
        status == 'Published · update required') {
      return status;
    }
    if (status != 'Generated' && status != 'Published') {
      return 'Ready to generate';
    }
    return status == 'Published' ? 'Published' : 'Ready to publish';
  }

  bool _readyToPublish(_StudentRecord student) =>
      reportStatusCanBePublished(
        _reportStatusFor(student),
        republishRequired: student.reportRepublishRequired,
        regenerationRequired: student.reportRegenerationRequired,
      ) &&
      _generationReady(student);

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

  Future<void> _showReportGenerationFeedback({
    required int generated,
    required int failed,
    String? error,
  }) async {
    if (!mounted) return;
    final hasError = error != null && error.trim().isNotEmpty;
    final successful = !hasError && failed == 0 && generated > 0;
    final color = successful
        ? const Color(0xFF0F766E)
        : hasError
        ? const Color(0xFFB91C1C)
        : const Color(0xFFB45309);
    final background = successful
        ? const Color(0xFFE6F4F1)
        : hasError
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFFF7ED);
    final title = successful
        ? 'Reports generated'
        : hasError
        ? 'Unable to generate reports'
        : 'Generation completed with issues';
    final summary = successful
        ? '$generated report${generated == 1 ? '' : 's'} generated successfully.'
        : generated > 0
        ? '$generated generated; $failed could not be generated.'
        : error ?? 'No reports could be generated.';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('report-generation-feedback'),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(
            successful
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 28,
          ),
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary, textAlign: TextAlign.center),
              if (hasError && generated > 0) ...[
                const SizedBox(height: 10),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReports(
    Iterable<_StudentRecord> students, {
    String? vacationOverrideReason,
  }) async {
    final ready = students.toList();
    if (ready.isEmpty) {
      _notice('Select at least one student.');
      return;
    }
    final blocked = ready
        .where((student) => !_generationReady(student))
        .toList();
    if (blocked.isNotEmpty) {
      _notice(
        '${blocked.length} selected student${blocked.length == 1 ? '' : 's'} still have report requirements to complete.',
      );
      return;
    }
    final startsNewRun = _processingReportStudents.isEmpty;
    setState(() {
      if (startsNewRun) {
        _generatedReportsInCurrentRun = 0;
        _failedReportsInCurrentRun = 0;
        _reportGenerationError = null;
      }
      _isGeneratingReports = true;
      _processingReportStudents.addAll(ready.map((student) => student.id));
    });
    if (widget.customSchoolId.trim().isNotEmpty) {
      try {
        final setup = await _assessmentFormSetup;
        final streams = setup.streams.where(
          (stream) => stream.label == _selectedClass,
        );
        if (streams.isEmpty) {
          throw const AssessmentApiException(
            'The selected stream could not be resolved.',
          );
        }
        final response = await _assessmentApi.generateStreamReports(
          customSchoolId: widget.customSchoolId,
          streamId: streams.first.id,
          term: setup.termSequence,
          academicYearId: setup.academicYearId,
          generatedBy: widget.viewerName,
          customStudentIds: ready.map((student) => student.id).toList(),
          vacationOverrideReason: vacationOverrideReason,
        );
        final results = response['generationResults'];
        final generated = results is Map<String, dynamic>
            ? _jsonInt(results['reportsGenerated'])
            : 0;
        final failedRows = response['failedStudents'];
        final failures = failedRows is List ? failedRows.length : 0;
        await _loadLiveReportReadiness(setup, _selectedClass);
        if (!mounted) return;
        var showFeedback = false;
        var generatedTotal = 0;
        var failedTotal = 0;
        String? feedbackError;
        setState(() {
          _generatedReportsInCurrentRun += generated;
          _failedReportsInCurrentRun += failures;
          _processingReportStudents.removeAll(
            ready.map((student) => student.id),
          );
          _isGeneratingReports = _processingReportStudents.isNotEmpty;
          showFeedback = !_isGeneratingReports;
          if (showFeedback) {
            generatedTotal = _generatedReportsInCurrentRun;
            failedTotal = _failedReportsInCurrentRun;
            feedbackError = _reportGenerationError;
          }
        });
        if (showFeedback) {
          await _showReportGenerationFeedback(
            generated: generatedTotal,
            failed: failedTotal,
            error: feedbackError,
          );
        }
        return;
      } on AssessmentApiException catch (error) {
        if (!mounted) return;
        final requiresVacationReason =
            vacationOverrideReason == null &&
            error.message.toLowerCase().contains('teaching begins');
        var showFeedback = false;
        var generatedTotal = 0;
        var failedTotal = 0;
        String? feedbackError;
        setState(() {
          if (!requiresVacationReason) {
            _failedReportsInCurrentRun += ready.length;
            _reportGenerationError = error.message;
          }
          _processingReportStudents.removeAll(
            ready.map((student) => student.id),
          );
          _isGeneratingReports = _processingReportStudents.isNotEmpty;
          showFeedback = !_isGeneratingReports && !requiresVacationReason;
          if (showFeedback) {
            generatedTotal = _generatedReportsInCurrentRun;
            failedTotal = _failedReportsInCurrentRun;
            feedbackError = _reportGenerationError;
          }
        });
        if (requiresVacationReason) {
          final reason = await _requestReportVacationReason(error.message);
          if (reason != null && mounted) {
            await _generateReports(ready, vacationOverrideReason: reason);
          }
          return;
        }
        if (showFeedback) {
          await _showReportGenerationFeedback(
            generated: generatedTotal,
            failed: failedTotal,
            error: feedbackError,
          );
        }
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    var showFeedback = false;
    var generatedTotal = 0;
    var failedTotal = 0;
    String? feedbackError;
    setState(() {
      for (final student in ready) {
        _reportStatuses[student.id] = 'Generated';
        _processingReportStudents.remove(student.id);
        _touchReportAudit(student);
      }
      _generatedReportsInCurrentRun += ready.length;
      _isGeneratingReports = _processingReportStudents.isNotEmpty;
      showFeedback = !_isGeneratingReports;
      if (showFeedback) {
        generatedTotal = _generatedReportsInCurrentRun;
        failedTotal = _failedReportsInCurrentRun;
        feedbackError = _reportGenerationError;
      }
    });
    if (showFeedback) {
      await _showReportGenerationFeedback(
        generated: generatedTotal,
        failed: failedTotal,
        error: feedbackError,
      );
    }
  }

  Future<void> _confirmAndPublishStudentReports(
    Iterable<_StudentRecord> students,
  ) async {
    final publishable = students.where(_readyToPublish).toList();
    if (publishable.isEmpty) {
      _notice(
        'No selected report meets all publication-readiness requirements.',
      );
      return;
    }
    final count = publishable.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('bulk-publish-confirmation'),
        title: Text('Publish $count report${count == 1 ? '' : 's'}?'),
        content: Text(
          'The $count eligible report${count == 1 ? '' : 's'} will become '
          'the official published version for $_selectedClass.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const ValueKey('confirm-bulk-publish'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.publish_outlined, size: 16),
            label: const Text('Publish now'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _publishStudentReports(publishable);
    }
  }

  Future<void> _publishStudentReports(Iterable<_StudentRecord> students) async {
    final generated = students.where(_readyToPublish).toList();
    if (generated.isEmpty) {
      _notice(
        'No selected report meets all publication-readiness requirements.',
      );
      return;
    }
    setState(() {
      _publishingReportStudents.addAll(generated.map((student) => student.id));
    });
    if (widget.customSchoolId.trim().isNotEmpty) {
      try {
        final setup = await _assessmentFormSetup;
        await Future.wait(
          generated.map(
            (student) => _assessmentApi.publishStudentReportCard(
              customSchoolId: widget.customSchoolId,
              customStudentId: student.id,
              termId: setup.termId,
              term: setup.termSequence,
              academicYearId: setup.academicYearId,
              publishedBy: widget.viewerName,
            ),
          ),
        );
        if (!mounted) return;
        setState(() {
          for (final student in generated) {
            _reportStatuses[student.id] = 'Published';
            _publishingReportStudents.remove(student.id);
            _touchReportAudit(student);
          }
          _selectedReportStudents.removeAll(
            generated.map((student) => student.id),
          );
        });
        _notice('${generated.length} report card(s) published.');
        return;
      } on AssessmentApiException catch (error) {
        if (!mounted) return;
        setState(
          () => _publishingReportStudents.removeAll(
            generated.map((student) => student.id),
          ),
        );
        _notice(error.message);
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    setState(() {
      for (final student in generated) {
        _reportStatuses[student.id] = 'Published';
        _publishingReportStudents.remove(student.id);
        _touchReportAudit(student);
      }
      _selectedReportStudents.removeAll(generated.map((student) => student.id));
    });
    _notice('${generated.length} report card(s) published.');
  }

  void _regenerateStudentReport(_StudentRecord student) {
    _generateReports([student]);
  }

  Future<void> _refreshReportCards() async {
    if (_refreshingReportCards) return;
    setState(() => _refreshingReportCards = true);
    try {
      if (widget.customSchoolId.trim().isNotEmpty) {
        final setup = await _assessmentFormSetup;
        await _loadLiveReportReadiness(setup, _selectedClass);
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 650));
      }
      if (mounted) _notice('Report card readiness refreshed.');
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    } finally {
      if (mounted) setState(() => _refreshingReportCards = false);
    }
  }

  Future<String?> _requestReportVacationReason(String warning) async {
    final controller = TextEditingController();
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('Teaching has not started'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(warning),
              const SizedBox(height: 16),
              TextField(
                key: const Key('report-vacation-reason'),
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for generating reports early',
                  errorText: validation,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('continue-early-report-generation'),
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.length < 5) {
                  setDialogState(() {
                    validation = 'Enter a reason of at least 5 characters.';
                  });
                  return;
                }
                Navigator.pop(dialogContext, reason);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openStudentReport(_StudentRecord student) async {
    setState(() => _selectedReportStudent = student);
    if (widget.customSchoolId.trim().isNotEmpty) {
      try {
        final setup = await _assessmentFormSetup;
        final results = await Future.wait([
          _assessmentApi.getStudentReportCard(
            customSchoolId: widget.customSchoolId,
            customStudentId: student.id,
            termId: setup.termId,
            academicYearId: setup.academicYearId,
          ),
          _assessmentApi.getStudentEvaluations(
            customStudentId: student.id,
            termId: setup.termId,
          ),
        ]);
        if (mounted) {
          setState(() {
            _studentReportCards[student.id] =
                results[0] as Map<String, dynamic>;
            _hydrateLiveEvaluation(
              student,
              results[1] as List<Map<String, dynamic>>,
            );
          });
        }
      } on AssessmentApiException catch (error) {
        if (mounted) _notice(error.message);
      }
    }
    if (!mounted) return;
    _open(_Route.studentReport);
  }

  void _hydrateLiveEvaluation(
    _StudentRecord student,
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.isEmpty) return;
    final byCriterion = {
      for (final row in rows)
        row['criterion']?.toString().toUpperCase() ?? '': row,
    };
    int score(String criterion) =>
        _jsonInt(byCriterion[criterion]?['score']).clamp(0, 10);
    final draft = _EvaluationDraft(
      homework: score('HOMEWORK'),
      punctuality: score('ATTENTIVENESS'),
      neatness: score('TEAMWORK'),
      attitude: score('CLASS_PARTICIPATION'),
      discipline: score('RESPECT_AND_DISCIPLINE'),
      organization: score('NEATNESS'),
      status: 'Submitted',
      lastEvaluated: _displayApiDate(
        rows
            .map((row) => row['updatedAt'] ?? row['createdAt'])
            .where((value) => value != null)
            .firstOrNull,
      ),
    );
    draft.displayScore = draft.average;
    draft.remark = rows
        .map((row) => row['overallComment']?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    const commentKeys = {
      'HOMEWORK': 'homework',
      'ATTENTIVENESS': 'punctuality',
      'TEAMWORK': 'neatness',
      'CLASS_PARTICIPATION': 'attitude',
      'RESPECT_AND_DISCIPLINE': 'discipline',
      'NEATNESS': 'organization',
    };
    for (final entry in commentKeys.entries) {
      final comment =
          byCriterion[entry.key]?['teacherComments']?.toString().trim() ?? '';
      if (comment.isNotEmpty) draft.comments[entry.value] = comment;
    }
    _evaluationDrafts[student.id] = draft;
  }

  Widget _reportCards() {
    final readyToGenerate = _reportCardStudents
        .where(_canGenerateOrRegenerate)
        .length;
    final needsAttention = _reportCardStudents
        .where(
          (student) =>
              !_generationReady(student) ||
              _activeCorrectionStatus(student) == 'PENDING',
        )
        .length;
    final generated = _reportCardStudents
        .where(
          (student) =>
              _reportStatusFor(student) == 'Generated' ||
              _activeCorrectionStatus(student) ==
                  'REGENERATED_AWAITING_PUBLICATION',
        )
        .length;
    final updateRequired = _reportCardStudents
        .where(
          (student) =>
              reportNeedsUpdate(_reportStatusFor(student)) ||
              const {
                'APPROVED_REGENERATION_REQUIRED',
                'REGENERATED_AWAITING_PUBLICATION',
              }.contains(_activeCorrectionStatus(student)),
        )
        .length;
    final published = _reportCardStudents
        .where(
          (student) =>
              _reportStatusFor(student) == 'Published' &&
              !const {
                'APPROVED_REGENERATION_REQUIRED',
                'REGENERATED_AWAITING_PUBLICATION',
              }.contains(_activeCorrectionStatus(student)),
        )
        .length;
    final filteredStudents = _reportCardStudents.where((student) {
      final status = _reportStatusFor(student);
      final correctionStatus = _activeCorrectionStatus(student);
      final matchesFilter = switch (_reportCardFilter) {
        'Ready' => _canGenerateOrRegenerate(student),
        'Needs Attention' =>
          !_generationReady(student) || correctionStatus == 'PENDING',
        'Not Generated' => status == 'Not Generated',
        'Generated' => status == 'Generated',
        'Update Required' =>
          reportNeedsUpdate(status) ||
              correctionStatus == 'APPROVED_REGENERATION_REQUIRED' ||
              correctionStatus == 'REGENERATED_AWAITING_PUBLICATION',
        'Published' => status == 'Published',
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
      actions: [
        TextButton.icon(
          onPressed: _showTermReportGuide,
          icon: const Icon(Icons.help_outline_rounded, size: 16),
          label: const Text('Report guide'),
        ),
      ],
      children: [
        LayoutBuilder(
          builder: (_, c) => _reportCardStatGrid(
            c.maxWidth,
            total: _reportCardStudents.length,
            readyToGenerate: readyToGenerate,
            needsAttention: needsAttention,
            generated: generated,
            updateRequired: updateRequired,
            published: published,
          ),
        ),
        if (_isGeneratingReports) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 6),
          Text(
            'Generating ${_processingReportStudents.length} report'
            '${_processingReportStudents.length == 1 ? '' : 's'}…',
          ),
        ],
        const SizedBox(height: 18),
        _reportCardStudentRegister(filteredStudents),
      ],
    );
  }

  Widget _reportCardStatGrid(
    double maxWidth, {
    required int total,
    required int readyToGenerate,
    required int needsAttention,
    required int generated,
    required int updateRequired,
    required int published,
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
        'NEEDS ATTENTION',
        '$needsAttention',
        'One or more requirements pending',
        Icons.warning_amber_outlined,
        const Color(0xFFF59E0B),
        'Needs Attention',
      ),
      (
        'READY TO GENERATE',
        '$readyToGenerate',
        'All requirements complete',
        Icons.check_circle,
        const Color(0xFF009688),
        'Ready',
      ),
      (
        'GENERATED',
        '$generated',
        'Created but not published',
        Icons.description_outlined,
        const Color(0xFF3B82F6),
        'Generated',
      ),
      (
        'UPDATE REQUIRED',
        '$updateRequired',
        'Source data changed',
        Icons.update_outlined,
        const Color(0xFFD97706),
        'Update Required',
      ),
      (
        'PUBLISHED',
        '$published',
        'Official reports released',
        Icons.verified_outlined,
        const Color(0xFF059669),
        'Published',
      ),
    ];
    final columns = maxWidth >= 1350
        ? 6
        : maxWidth >= 1050
        ? 4
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
    final selectedStudents = _reportCardStudents
        .where((student) => _selectedReportStudents.contains(student.id))
        .toList();
    final generationCandidates = selectedStudents.isEmpty
        ? students
        : selectedStudents;
    final generationTargets = generationCandidates
        .where(_canGenerateOrRegenerate)
        .toList();
    final selectionContainsBlocked =
        selectedStudents.isNotEmpty &&
        generationTargets.length != selectedStudents.length;
    final publicationCandidates = selectedStudents.isEmpty
        ? students
        : selectedStudents;
    final publicationTargets = publicationCandidates
        .where(_readyToPublish)
        .toList();
    final allVisibleSelected =
        students.isNotEmpty &&
        students.every(
          (student) => _selectedReportStudents.contains(student.id),
        );
    final someVisibleSelected = students.any(
      (student) => _selectedReportStudents.contains(student.id),
    );
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
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                          'Not Generated',
                          'Generated',
                          'Update Required',
                          'Published',
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: _isGeneratingReports
                          ? FilledButton.styleFrom(
                              disabledForegroundColor: const Color(0xFF0F766E),
                              disabledBackgroundColor: const Color(0xFFE6F4F1),
                            )
                          : null,
                      onPressed:
                          _isGeneratingReports ||
                              generationTargets.isEmpty ||
                              selectionContainsBlocked
                          ? null
                          : () => _generateReports(generationTargets),
                      icon: _isGeneratingReports
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0F766E),
                              ),
                            )
                          : const Icon(Icons.description_outlined, size: 14),
                      label: Text(
                        _isGeneratingReports
                            ? 'Generating ${_processingReportStudents.length}…'
                            : selectedStudents.isEmpty
                            ? 'Generate all ready (${generationTargets.length})'
                            : 'Generate selected (${selectedStudents.length})',
                      ),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('bulk-publish-reports'),
                      onPressed:
                          publicationTargets.isEmpty ||
                              _publishingReportStudents.isNotEmpty
                          ? null
                          : () => _confirmAndPublishStudentReports(
                              publicationTargets,
                            ),
                      icon: const Icon(Icons.publish_outlined, size: 14),
                      label: Text(
                        bulkPublishLabel(
                          selectedCount: selectedStudents.length,
                          eligibleCount: publicationTargets.length,
                        ),
                      ),
                    ),
                    if (_evaluationManager)
                      OutlinedButton.icon(
                        onPressed: _openBulkPromotion,
                        icon: const Icon(Icons.trending_up, size: 14),
                        label: Text(
                          _selectedReportStudents.isEmpty
                              ? 'Set Progression'
                              : 'Set Progression (${_selectedReportStudents.length})',
                        ),
                      ),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 46,
                            child: Checkbox(
                              key: const ValueKey(
                                'select-all-visible-report-students',
                              ),
                              tristate: true,
                              value: allVisibleSelected
                                  ? true
                                  : someVisibleSelected
                                  ? null
                                  : false,
                              onChanged: (_) => setState(() {
                                if (allVisibleSelected) {
                                  _selectedReportStudents.removeAll(
                                    students.map((student) => student.id),
                                  );
                                } else {
                                  _selectedReportStudents.addAll(
                                    students.map((student) => student.id),
                                  );
                                }
                              }),
                            ),
                          ),
                          const SizedBox(
                            width: 30,
                            child: _FinalReportHeader('#', centered: true),
                          ),
                          const Expanded(
                            flex: 3,
                            child: _FinalReportHeader('STUDENT'),
                          ),
                          const Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'ACADEMIC GRADES',
                              centered: true,
                            ),
                          ),
                          const Expanded(
                            flex: 3,
                            child: _FinalReportHeader(
                              'EVALUATIONS & COMMENTS',
                              centered: true,
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'PROGRESSION',
                              centered: true,
                            ),
                          ),
                          const Expanded(
                            flex: 2,
                            child: _FinalReportHeader(
                              'REPORT STATUS',
                              centered: true,
                            ),
                          ),
                          const Expanded(
                            flex: 4,
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
    final status = _reportCardDisplayStatus(student);
    return AnimatedContainer(
      key: ValueKey('report-card-row-${student.id}'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FAF8) : Colors.white,
        border: Border(
          left: BorderSide(
            color: selected ? const Color(0xFF0F8F83) : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
            child: Center(
              child: _studentRequirementBadge(
                _gradesComplete(student) ? 'Complete' : 'Incomplete',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: _studentRequirementBadge(
                _evaluationAndCommentsStatusFor(student),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _studentRequirementBadge(_progressionStatusFor(student)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: _reportStateBadge(
                status,
                onTap: _activeCorrectionFor(student) != null
                    ? () => _openStudentCorrectionWorkflow(student)
                    : reportNeedsUpdate(status)
                    ? () => _showReportUpdateDetails(student)
                    : null,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _reportCardRowActions(student),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentRequirementBadge(String label) {
    final normalized = label.toLowerCase();
    final (foreground, background, border) = switch (normalized) {
      'complete' || 'selected' || 'approved' => (
        const Color(0xFF047857),
        const Color(0xFFECFDF5),
        const Color(0xFFA7F3D0),
      ),
      'awaiting approval' => (
        const Color(0xFF1D4ED8),
        const Color(0xFFEFF6FF),
        const Color(0xFFBFDBFE),
      ),
      'not submitted' || 'pending' => (
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
        const Color(0xFFFED7AA),
      ),
      'rejected' => (
        const Color(0xFFB91C1C),
        const Color(0xFFFEF2F2),
        const Color(0xFFFECACA),
      ),
      _ => (
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
        const Color(0xFFFED7AA),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _reportStateBadge(String label, {VoidCallback? onTap}) {
    final normalized = label.toLowerCase();
    final (foreground, background) = switch (normalized) {
      'ready' => (const Color(0xFF4F8F84), const Color(0xFFF0F8F6)),
      'generated' => (const Color(0xFF527AA8), const Color(0xFFF1F6FB)),
      'published' => (const Color(0xFF4F8F84), const Color(0xFFF0F8F6)),
      'correction pending' => (
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
      ),
      'awaiting publication' => (
        const Color(0xFF1D4ED8),
        const Color(0xFFEFF6FF),
      ),
      'update required' => (const Color(0xFFB45309), const Color(0xFFFFF7ED)),
      'published · update required' => (
        const Color(0xFFB45309),
        const Color(0xFFFFF7ED),
      ),
      'processing' ||
      'publishing' => (const Color(0xFF667085), const Color(0xFFF3F4F6)),
      'draft' => (const Color(0xFF8A7350), const Color(0xFFFAF7F1)),
      _ => (const Color(0xFF7A8597), const Color(0xFFF5F6F8)),
    };
    final badge = Container(
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
    if (onTap == null) return badge;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: badge,
      ),
    );
  }

  Future<void> _openStudentCorrectionWorkflow(_StudentRecord student) async {
    final correction = _activeCorrectionFor(student);
    final requestId = (correction?['id'] as num?)?.toInt();
    if (correction == null || requestId == null) return;
    final repository = ApprovalApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    try {
      final inbox = await repository.getInbox(widget.customSchoolId);
      final approvalMatches = inbox.myApprovals.where(
        (item) =>
            (item.type == 'REPORT_SCORE_CORRECTION' ||
                item.type == 'REPORT_CORRECTION') &&
            item.entityId == requestId,
      );
      final requestMatches = inbox.myRequests.where(
        (item) =>
            (item.type == 'REPORT_SCORE_CORRECTION' ||
                item.type == 'REPORT_CORRECTION') &&
            item.entityId == requestId,
      );
      final item = approvalMatches.isNotEmpty
          ? approvalMatches.first
          : requestMatches.isNotEmpty
          ? requestMatches.first
          : null;
      if (!mounted) return;
      if (item == null) {
        await _showCorrectionAssignment(correction);
        return;
      }
      await showApprovalItemPanel(
        context: context,
        item: item,
        onAction: (action, reason) async {
          await repository.performAction(
            schoolId: widget.customSchoolId,
            item: item,
            action: action,
            reason: reason,
          );
        },
        correctionRepository: repository,
        schoolId: widget.customSchoolId,
        canManageCorrection: approvalMatches.isNotEmpty,
      );
      if (mounted) await _refreshReportCards();
    } on ApprovalApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<void> _showCorrectionAssignment(
    Map<String, dynamic> correction,
  ) async {
    final status = '${correction['status'] ?? ''}'.toUpperCase();
    final label = switch (status) {
      'PENDING' => 'Pending approval',
      'APPROVED_REGENERATION_REQUIRED' => 'Regeneration required',
      'REGENERATED_AWAITING_PUBLICATION' => 'Publication required',
      _ => status.replaceAll('_', ' ').toLowerCase(),
    };
    final approver = '${correction['assignedApproverName'] ?? ''}'.trim();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report correction'),
        content: Text(
          '$label. ${approver.isEmpty ? 'The assigned approver' : approver} must complete this workflow.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportUpdateDetails(_StudentRecord student) async {
    final status = _reportStatusFor(student);
    final reasons = student.reportUpdateReasons.isEmpty
        ? const ['Report source data changed.']
        : student.reportUpdateReasons;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${student.name} · $status'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (student.reportVersion > 0)
                Text(
                  'Latest generated version: ${student.reportVersion}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (student.reportVersion > 0) const SizedBox(height: 12),
              for (final reason in reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.update_outlined,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Text(reason)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (student.reportRegenerationRequired)
            FilledButton.icon(
              onPressed: _generationReady(student)
                  ? () {
                      Navigator.pop(dialogContext);
                      _regenerateStudentReport(student);
                    }
                  : null,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Regenerate Report'),
            )
          else if (student.reportRepublishRequired)
            FilledButton.icon(
              onPressed: _generationReady(student)
                  ? () {
                      Navigator.pop(dialogContext);
                      _publishStudentReports([student]);
                    }
                  : null,
              icon: const Icon(Icons.send, size: 17),
              label: const Text('Publish Updated Version'),
            ),
        ],
      ),
    );
  }

  Widget _reportCardRowActions(_StudentRecord student) {
    final correction = _activeCorrectionFor(student);
    if (correction != null) {
      final correctionStatus = _activeCorrectionStatus(student);
      final label = switch (correctionStatus) {
        'PENDING' => 'View correction',
        'APPROVED_REGENERATION_REQUIRED' => 'Regenerate report',
        'REGENERATED_AWAITING_PUBLICATION' => 'View & publish',
        _ => 'View correction',
      };
      final icon = switch (correctionStatus) {
        'APPROVED_REGENERATION_REQUIRED' => Icons.refresh_rounded,
        'REGENERATED_AWAITING_PUBLICATION' => Icons.publish_outlined,
        _ => Icons.rule_rounded,
      };
      return Center(
        child: FilledButton.tonalIcon(
          key: ValueKey('report-correction-${student.id}'),
          onPressed: () => _openStudentCorrectionWorkflow(student),
          icon: Icon(icon, size: 14),
          label: Text(label),
        ),
      );
    }
    final status = _reportStatusFor(student);
    if (status == 'Processing' || status == 'Publishing') {
      final generating = status == 'Processing';
      return Center(
        child: FilledButton.icon(
          key: ValueKey(
            generating
                ? 'report-generation-progress-${student.id}'
                : 'report-publication-progress-${student.id}',
          ),
          style: FilledButton.styleFrom(
            disabledForegroundColor: const Color(0xFF0F766E),
            disabledBackgroundColor: const Color(0xFFE6F4F1),
          ),
          onPressed: null,
          icon: const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF0F766E),
            ),
          ),
          label: Text(generating ? 'Generating…' : 'Publishing…'),
        ),
      );
    }
    if (status == 'Not Generated') {
      return Center(
        child: FilledButton.icon(
          onPressed: _generationReady(student)
              ? () => _generateReports([student])
              : null,
          icon: const Icon(Icons.description_outlined, size: 14),
          label: const Text('Generate report'),
        ),
      );
    }
    if (reportNeedsUpdate(status) && student.reportRegenerationRequired) {
      return Center(
        child: FilledButton.icon(
          onPressed: _generationReady(student)
              ? () => _regenerateStudentReport(student)
              : null,
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text('Regenerate'),
        ),
      );
    }
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _openStudentReport(student),
        icon: const Icon(Icons.visibility_outlined, size: 14),
        label: const Text('View report'),
      ),
    );
  }

  Future<void> _showGuardianDeliveryOptions(_StudentRecord student) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send report to guardian'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.phone_android_outlined),
                title: Text('In-app access'),
                subtitle: Text(
                  'The published report is available to authorized guardians in the app.',
                ),
                trailing: Icon(Icons.check_circle, color: Color(0xFF009688)),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.email_outlined),
                title: Text('Email'),
                subtitle: Text('Guardian email delivery is not connected yet.'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.chat_outlined),
                title: Text('WhatsApp'),
                subtitle: Text(
                  'WhatsApp Business delivery is not connected yet.',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<String> _promotionGradeOptions([String? currentValue]) {
    final values = <String>{
      'Repeat current grade',
      'Pending review',
      ..._configuredGradeLevels,
      if (_configuredGradeLevels.isNotEmpty &&
          _selectedClass.trim().toLowerCase() ==
              _configuredGradeLevels.last.trim().toLowerCase())
        'Graduate',
      if (currentValue != null && currentValue.trim().isNotEmpty)
        currentValue.trim(),
    }.toList();
    return values;
  }

  Future<void> _openBulkPromotion() async {
    String? grade;
    var replaceExisting = false;
    final gradeOptions = _promotionGradeOptions();
    if (gradeOptions.isEmpty) {
      _notice('No active grade levels are configured for this school.');
      return;
    }
    final targets = _selectedReportStudents.isEmpty
        ? _reportCardStudents
        : _reportCardStudents
              .where((student) => _selectedReportStudents.contains(student.id))
              .toList();
    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set progression decision'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedReportStudents.isEmpty
                      ? 'Apply a progression decision to all ${targets.length} students.'
                      : 'Apply a progression decision to ${targets.length} selected student(s).',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: grade,
                  decoration: const InputDecoration(labelText: 'Decision'),
                  hint: const Text('Promote, repeat, review or graduate'),
                  items: gradeOptions.map((item) {
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
              child: const Text('Apply decision'),
            ),
          ],
        ),
      ),
    );
    if (applied != true || !mounted) return;
    final changedTargets = <_StudentRecord>[];
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
        changedTargets.add(student);
        _touchReportAudit(student);
      }
    });
    if (changedTargets.isEmpty) {
      _notice('No progression decisions were changed.');
      return;
    }
    if (widget.customSchoolId.trim().isNotEmpty) {
      try {
        final setup = await _assessmentFormSetup;
        await Future.wait(
          changedTargets.map((student) {
            final remarks = _reportRemarks[student.id]!;
            return _assessmentApi.saveReportCardRemarks(
              submittedBy: widget.viewerName,
              body: {
                'customStudentId': student.id,
                'customSchoolId': widget.customSchoolId,
                'termId': setup.termId,
                'classTeacherRemarks': remarks.classTeacherRemarks,
                'headTeacherRemarks': remarks.headTeacherRemarks,
                'ignoreHeadTeacherRemarks': remarks.ignoreHeadTeacherRemark,
                'classTeacherName': widget.viewerName,
                'classTeacherId': widget.viewerName,
                'promotedTo': remarks.promotedTo,
              },
            );
          }),
        );
        await _loadLiveReportReadiness(setup, _selectedClass);
      } on AssessmentApiException catch (error) {
        if (!mounted) return;
        _notice(error.message);
        return;
      }
    }
    if (!mounted) return;
    _notice(
      'Progression decision updated for ${changedTargets.length} student(s).',
    );
  }

  // ignore: unused_element
  Future<void> _openRemarksEditor(_StudentRecord student) async {
    final existing = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    if (existing.reportStatus.toUpperCase() == 'PUBLISHED') {
      _notice('Reopen the published report before making corrections.');
      return;
    }
    final classController = TextEditingController(
      text: _classTeacherCommentFor(student, existing),
    );
    final headController = TextEditingController(
      text: existing.headTeacherRemarks,
    );
    var promotedTo = existing.promotedTo;
    final isAcademicManager = _evaluationManager;
    final canEditClass = isAcademicManager;
    final canEditHead = isAcademicManager;
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
                                readOnly: true,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Final Class Teacher Comment',
                                  hintText: 'Pending evaluation finalization',
                                  helperText:
                                      'Created from Evaluations & Comments → Student comments.',
                                  suffixIcon: Icon(Icons.lock_outline),
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.viewerName} • Class Teacher',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 22),
                              _remarksSectionLabel('Head Teacher'),
                              const SizedBox(height: 10),
                              TextField(
                                controller: headController,
                                enabled: canEditHead,
                                maxLines: 5,
                                decoration: const InputDecoration(
                                  labelText: 'Head Teacher Remarks (optional)',
                                  hintText:
                                      'Add a head teacher remark if needed',
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
                              const SizedBox(height: 22),
                              _remarksSectionLabel('Progression decision'),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: promotedTo.isEmpty ? null : promotedTo,
                                isExpanded: true,
                                hint: const Text(
                                  'Promote, repeat, review or graduate',
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Decision',
                                  prefixIcon: Icon(Icons.school_outlined),
                                ),
                                items: _promotionGradeOptions(promotedTo).map((
                                  grade,
                                ) {
                                  return DropdownMenuItem(
                                    value: grade,
                                    child: Text(grade),
                                  );
                                }).toList(),
                                onChanged: canEditClass
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
                                  ignoreHeadTeacherRemark: false,
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
                                  ignoreHeadTeacherRemark: false,
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
        '$_selectedClass • $_displayTerm\nViewing as ${widget.viewerRole}',
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

  Future<void> _saveReportRemarks(
    _StudentRecord student,
    String classRemarks,
    String headRemarks,
    String promotedTo, {
    bool ignoreHeadTeacherRemark = false,
    bool draft = false,
    bool correction = false,
  }) async {
    final correctionReason = correction
        ? await _promptReportCorrectionReason(student)
        : null;
    if (correction && correctionReason == null) return;
    if (!mounted) return;
    final remarks = _ReportRemarksDraft(
      classTeacherRemarks: classRemarks.trim(),
      headTeacherRemarks: headRemarks.trim(),
      promotedTo: promotedTo,
      ignoreHeadTeacherRemark: ignoreHeadTeacherRemark,
      reportStatus: _reportRemarks[student.id]?.reportStatus ?? 'DRAFT',
    );
    setState(() => _reportRemarks[student.id] = remarks);
    if (widget.customSchoolId.trim().isNotEmpty) {
      try {
        final setup = await _assessmentFormSetup;
        if (correctionReason != null) {
          await _assessmentApi.reopenPublishedReport(
            customSchoolId: widget.customSchoolId,
            customStudentId: student.id,
            termId: setup.termId,
            reason: correctionReason,
          );
        }
        await _assessmentApi.saveReportCardRemarks(
          submittedBy: widget.viewerName,
          body: {
            'customStudentId': student.id,
            'customSchoolId': widget.customSchoolId,
            'termId': setup.termId,
            'classTeacherRemarks': remarks.classTeacherRemarks,
            'headTeacherRemarks': remarks.headTeacherRemarks,
            'ignoreHeadTeacherRemarks': remarks.ignoreHeadTeacherRemark,
            'classTeacherName': widget.viewerName,
            'classTeacherId': widget.viewerName,
            'promotedTo': remarks.promotedTo,
          },
        );
        await _loadLiveReportReadiness(setup, _selectedClass);
      } on AssessmentApiException catch (error) {
        if (mounted) _notice(error.message);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _reopenedReportStudents.remove(student.id);
      _touchReportAudit(student);
    });
    _notice(
      correction
          ? '${student.name} correction saved. The reason was added to the audit log; regenerate the report before publishing.'
          : draft
          ? '${student.name} remarks saved as draft.'
          : remarks.remarksComplete && remarks.promotedTo.isNotEmpty
          ? '${student.name} remarks completed.'
          : 'Remarks saved. Complete all fields to make the report ready.',
    );
  }

  Future<String?> _promptReportCorrectionReason(_StudentRecord student) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save report correction'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explain the changes made to ${student.name}\'s report. The reason and correction will be recorded in the audit log.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Correction reason',
                  hintText:
                      'For example: progression decision corrected after academic review',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.length < 10) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enter a clear reason of at least 10 characters.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Save correction'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    return reason;
  }

  Future<void> _requestRatingCorrection(
    _StudentRecord student,
    dynamic rawConduct,
  ) async {
    if (await _resumeExistingCorrection(student)) return;
    final original = <String, String>{};
    if (rawConduct is List) {
      for (final raw in rawConduct.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final key = _evaluationCriterionKey('${item['criterion'] ?? ''}');
        final rating = '${item['rating'] ?? ''}'.trim();
        if (key != null && rating.isNotEmpty) original[key] = rating;
      }
    }
    const labels = <String, String>{
      'HOMEWORK_HABITS': 'Homework habits',
      'ATTENTIVENESS': 'Attentiveness',
      'TEAMWORK': 'Teamwork',
      'CLASS_PARTICIPATION': 'Class participation',
      'RESPECT_AND_DISCIPLINE': 'Respect and discipline',
      'NEATNESS': 'Neatness',
    };
    if (!labels.keys.every(original.containsKey)) {
      _notice(
        'The complete generated evaluation could not be loaded. Refresh and try again.',
      );
      return;
    }
    List<Map<String, dynamic>> approvers;
    try {
      approvers = await _assessmentApi.getReportCorrectionApprovers(
        customSchoolId: widget.customSchoolId,
      );
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
      return;
    }
    if (!mounted) return;
    final proposed = Map<String, String>.from(original);
    final reasonController = TextEditingController();
    String? approver;
    const ratings = [
      'Excellent',
      'Good',
      'Satisfactory',
      'Needs improvement',
      'Not observed',
    ];
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request evaluation-rating correction'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student.name} · The official ratings remain unchanged until the selected approver accepts this request.',
                  ),
                  const SizedBox(height: 16),
                  ...labels.entries.map(
                    (criterion) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${criterion.value}\nCurrent: ${original[criterion.key]}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 210,
                            child: DropdownButtonFormField<String>(
                              value: proposed[criterion.key],
                              decoration: const InputDecoration(
                                labelText: 'Proposed rating',
                              ),
                              items: ratings
                                  .map(
                                    (rating) => DropdownMenuItem(
                                      value: rating,
                                      child: Text(rating),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setDialogState(
                                () => proposed[criterion.key] = value!,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('source-correction-approver'),
                    value: approver,
                    decoration: const InputDecoration(
                      labelText: 'Approver',
                      hintText: 'Choose who will approve this correction',
                    ),
                    items: _correctionApproverItems(approvers),
                    onChanged: (value) =>
                        setDialogState(() => approver = value),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Reason for correction',
                      alignLabelWithHint: true,
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
            FilledButton(
              onPressed: () {
                if (approver == null) {
                  _dialogNotice(dialogContext, 'Choose an approver.');
                  return;
                }
                if (reasonController.text.trim().length < 5) {
                  _dialogNotice(
                    dialogContext,
                    'Enter a clear reason of at least 5 characters.',
                  );
                  return;
                }
                if (labels.keys.every(
                  (key) => original[key] == proposed[key],
                )) {
                  _dialogNotice(dialogContext, 'Change at least one rating.');
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit for approval'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (submitted != true || approver == null || !mounted) return;
    await _submitSourceCorrection(
      student: student,
      type: 'EVALUATION_RATINGS',
      proposedRatings: proposed,
      reason: reason,
      approver: approver!,
    );
  }

  Future<void> _requestTextSourceCorrection({
    required _StudentRecord student,
    required String type,
    required String label,
    required String currentValue,
    required bool allowEmpty,
    required bool multiline,
    List<String>? choices,
  }) async {
    if (await _resumeExistingCorrection(student)) return;
    List<Map<String, dynamic>> approvers;
    try {
      approvers = await _assessmentApi.getReportCorrectionApprovers(
        customSchoolId: widget.customSchoolId,
      );
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
      return;
    }
    if (!mounted) return;
    final valueController = TextEditingController(text: currentValue);
    final reasonController = TextEditingController();
    String proposed = currentValue;
    String? approver;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Request $label correction'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student.name} · The official value remains unchanged until approval.',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Current $label\n${currentValue.trim().isEmpty ? 'Not set' : currentValue}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (choices != null)
                    DropdownButtonFormField<String>(
                      value: choices.contains(proposed) ? proposed : null,
                      decoration: InputDecoration(labelText: 'Proposed $label'),
                      items: choices
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => proposed = value ?? ''),
                    )
                  else
                    TextField(
                      controller: valueController,
                      minLines: multiline ? 4 : 1,
                      maxLines: multiline ? 7 : 1,
                      decoration: InputDecoration(
                        labelText: 'Proposed $label',
                        alignLabelWithHint: multiline,
                      ),
                      onChanged: (value) => proposed = value,
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: approver,
                    decoration: const InputDecoration(
                      labelText: 'Approver',
                      hintText: 'Choose who will approve this correction',
                    ),
                    items: _correctionApproverItems(approvers),
                    onChanged: (value) =>
                        setDialogState(() => approver = value),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Reason for correction',
                      alignLabelWithHint: true,
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
            FilledButton(
              onPressed: () {
                proposed = choices == null
                    ? valueController.text.trim()
                    : proposed.trim();
                if (!allowEmpty && proposed.isEmpty) {
                  _dialogNotice(dialogContext, 'Enter the proposed value.');
                  return;
                }
                if (proposed == currentValue.trim()) {
                  _dialogNotice(
                    dialogContext,
                    'Change the current value first.',
                  );
                  return;
                }
                if (approver == null) {
                  _dialogNotice(dialogContext, 'Choose an approver.');
                  return;
                }
                if (reasonController.text.trim().length < 5) {
                  _dialogNotice(
                    dialogContext,
                    'Enter a clear reason of at least 5 characters.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit for approval'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text.trim();
    proposed = choices == null ? valueController.text.trim() : proposed.trim();
    valueController.dispose();
    reasonController.dispose();
    if (submitted != true || approver == null || !mounted) return;
    await _submitSourceCorrection(
      student: student,
      type: type,
      proposedValue: proposed,
      reason: reason,
      approver: approver!,
    );
  }

  Future<void> _requestProgressionCorrection(
    _StudentRecord student,
    _ReportRemarksDraft remarks,
  ) => _requestTextSourceCorrection(
    student: student,
    type: 'PROGRESSION',
    label: 'progression decision',
    currentValue: remarks.promotedTo,
    allowEmpty: false,
    multiline: false,
    choices: _promotionGradeOptions(remarks.promotedTo),
  );

  Future<void> _submitSourceCorrection({
    required _StudentRecord student,
    required String type,
    String proposedValue = '',
    Map<String, String> proposedRatings = const {},
    required String reason,
    required String approver,
  }) async {
    try {
      final setup = await _assessmentFormSetup;
      await _assessmentApi.requestReportSourceCorrection(
        customSchoolId: widget.customSchoolId,
        studentId: student.id,
        termId: setup.termId,
        correctionType: type,
        proposedValue: proposedValue,
        proposedRatings: proposedRatings,
        reason: reason,
        assignedApprover: approver,
      );
      await _loadLiveReportReadiness(setup, _selectedClass);
      if (mounted) {
        _notice('$type correction submitted to the selected approver.');
      }
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
  }

  Future<bool> _resumeExistingCorrection(_StudentRecord student) async {
    if (_activeCorrectionFor(student) == null) return false;
    await _openStudentCorrectionWorkflow(student);
    return true;
  }

  List<DropdownMenuItem<String>> _correctionApproverItems(
    List<Map<String, dynamic>> approvers,
  ) => approvers
      .map((entry) {
        final username = '${entry['username'] ?? ''}'.trim();
        final name = '${entry['name'] ?? username}'.trim();
        final role = '${entry['role'] ?? ''}'
            .replaceAll('_', ' ')
            .toLowerCase();
        return DropdownMenuItem(
          value: username,
          child: Text(role.isEmpty ? name : '$name · $role'),
        );
      })
      .where((item) => item.value?.isNotEmpty == true)
      .toList();

  String? _evaluationCriterionKey(String value) {
    final normalized = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return switch (normalized) {
      'HOMEWORK' || 'HOMEWORK_HABITS' => 'HOMEWORK_HABITS',
      'ATTENTIVENESS' => 'ATTENTIVENESS',
      'TEAMWORK' => 'TEAMWORK',
      'PARTICIPATION' || 'CLASS_PARTICIPATION' => 'CLASS_PARTICIPATION',
      'DISCIPLINE' ||
      'RESPECT_DISCIPLINE' ||
      'RESPECT_AND_DISCIPLINE' => 'RESPECT_AND_DISCIPLINE',
      'NEATNESS' => 'NEATNESS',
      _ => null,
    };
  }

  void _dialogNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _reportCardStudentTile(_StudentRecord student) {
    final selected = _selectedReportStudents.contains(student.id);
    final status = _reportCardDisplayStatus(student);
    return AnimatedContainer(
      key: ValueKey('report-card-tile-${student.id}'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0FAF8) : Colors.white,
        border: Border(
          left: BorderSide(
            color: selected ? const Color(0xFF0F8F83) : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: Color(0xFFF3F4F6)),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(
              value: selected,
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
            subtitle: Text(student.id),
            trailing: _reportStateBadge(status),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 0, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _mobileRequirement(
                      'Academic grades',
                      _gradesComplete(student) ? 'Complete' : 'Incomplete',
                    ),
                    _mobileRequirement(
                      'Evaluations & comments',
                      _evaluationAndCommentsStatusFor(student),
                    ),
                    _mobileRequirement(
                      'Progression',
                      _progressionStatusFor(student),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: _reportCardRowActions(student),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileRequirement(String label, String status) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          _studentRequirementBadge(status),
        ],
      ),
    );
  }

  Widget _studentReportPage() {
    final student = _selectedReportStudent ?? _reportCardStudents.first;
    final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    final classTeacherComment = _classTeacherCommentFor(student, remarks);
    final evaluation = _evaluationFor(student);
    final status = _reportStatusFor(student);
    final displayStatus = _reportCardDisplayStatus(student);
    final generated = reportHasGeneratedVersion(status);
    final published = canDistributeReport(status);
    final academicManager = _evaluationManager;
    final canEditClass = academicManager && !generated;
    final canEditHead = academicManager && !generated;
    final reportSubjects = _studentReportCards[student.id]?['subjects'];
    final generatedAcademicRows = reportSubjects is List
        ? reportSubjects.whereType<Map>().map((rawSubject) {
            final subject = Map<String, dynamic>.from(rawSubject);
            String score(dynamic value) =>
                _jsonNumber(value).toStringAsFixed(1);
            return [
              subject['subjectName']?.toString() ?? 'Subject',
              score(subject['classScore']),
              score(subject['examScore']),
              score(subject['totalScore']),
              subject['grade']?.toString() ?? '—',
              subject['remarks']?.toString() ?? '—',
            ];
          }).toList()
        : <List<String>>[];
    final generatedSubjectNames = generatedAcademicRows
        .map((row) => row.first)
        .toSet();
    final pendingSubjectNames =
        (_reportMissingComponents[student.id] ?? const [])
            .map((item) => item.split(':').first.trim())
            .where(
              (name) =>
                  name.isNotEmpty && !generatedSubjectNames.contains(name),
            )
            .toSet();
    final academicRows = <List<String>>[
      ...generatedAcademicRows,
      ...pendingSubjectNames.map(
        (subject) => [
          subject,
          'Results pending',
          'Results pending',
          'Results pending',
          '—',
          'Results pending',
        ],
      ),
    ];

    return _page(
      title: 'Student Report',
      subtitle: '${student.name} • ${student.id} • $_selectedClass',
      compactHeader: true,
      maxContentWidth: 1320,
      actions: [
        if (academicManager && !generated)
          _outlineButton(
            'Save Draft',
            Icons.save_outlined,
            () => _saveReportRemarks(
              student,
              classTeacherComment,
              remarks.headTeacherRemarks,
              remarks.promotedTo,
              ignoreHeadTeacherRemark: false,
              draft: true,
            ),
          ),
        _outlineButton(
          published ? 'View PDF' : 'Preview',
          Icons.visibility_outlined,
          generated && !_reportPdfActions.contains(student.id)
              ? () => _previewReportPdf(student)
              : null,
        ),
        if (published)
          _outlineButton(
            'Print',
            Icons.print_outlined,
            _reportPdfActions.contains(student.id)
                ? null
                : () => _previewReportPdf(student),
          ),
        if (published)
          _outlineButton(
            'Send to Guardian',
            Icons.forward_to_inbox_outlined,
            () => _showGuardianDeliveryOptions(student),
          ),
        if (published)
          _filledButton(
            'Download',
            Icons.download_outlined,
            _reportPdfActions.contains(student.id)
                ? null
                : () => _downloadReportPdf(student),
          ),
        if (!published &&
            !(status == 'Published · update required' &&
                student.reportRepublishRequired))
          _filledButton(
            student.reportRegenerationRequired
                ? 'Regenerate Report'
                : generated
                ? 'Regenerate'
                : 'Generate',
            generated ? Icons.refresh : Icons.description_outlined,
            _generationReady(student)
                ? () => generated
                      ? _regenerateStudentReport(student)
                      : _generateReports([student])
                : null,
          ),
        if (!published && _readyToPublish(student))
          _filledButton(
            status == 'Published · update required'
                ? 'Publish Updated Version'
                : 'Publish',
            Icons.send,
            () => _publishStudentReports([student]),
          ),
      ],
      children: [
        _studentReportIdentity(student, displayStatus),
        if (_activeCorrectionFor(student) != null) ...[
          const SizedBox(height: 16),
          _studentCorrectionProgressPanel(student),
        ],
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
            rows: academicRows,
          ),
        ),
        const SizedBox(height: 16),
        _studentReportEvaluation(
          student,
          evaluation,
          canRequestCorrection: academicManager && generated,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final remarksSection = _studentReportRemarksSection(
              student,
              remarks,
              classTeacherComment: classTeacherComment,
              canEditHead: canEditHead,
              canRequestCorrection: academicManager && generated,
            );
            final promotionSection = _studentReportPromotionSection(
              student,
              remarks,
              canEdit: canEditClass,
              canRequestCorrection: academicManager && generated,
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
                  '${student.id} • $_selectedClass • $_displayTerm',
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

  Widget _studentCorrectionProgressPanel(_StudentRecord student) {
    final correction = _activeCorrectionFor(student)!;
    final status = _activeCorrectionStatus(student);
    final source = switch ('${correction['correctionType'] ?? ''}'
        .toUpperCase()) {
      'SCORE' => 'Score',
      'EVALUATION' => 'Evaluation & comment',
      'EVALUATION_RATINGS' => 'Evaluation ratings',
      'CLASS_TEACHER_COMMENT' => 'Class-teacher comment',
      'HEAD_TEACHER_COMMENT' => 'Head-teacher comment',
      'PROGRESSION' => 'Progression decision',
      _ => '${correction['sourceLabel'] ?? 'Report'}',
    };
    final message = switch (status) {
      'PENDING' => 'Awaiting approval',
      'APPROVED_REGENERATION_REQUIRED' =>
        'Approved · report regeneration required',
      'REGENERATION_IN_PROGRESS' => 'Regenerating the report',
      'REGENERATION_FAILED' => 'Regeneration failed · retry required',
      'REGENERATED_AWAITING_PUBLICATION' =>
        'Regenerated · publication required',
      'PUBLICATION_IN_PROGRESS' => 'Publishing the updated report',
      'PUBLICATION_FAILED' => 'Publication failed · retry required',
      _ => 'Correction in progress',
    };
    final currentStep = switch (status) {
      'PENDING' => 1,
      'APPROVED_REGENERATION_REQUIRED' ||
      'REGENERATION_IN_PROGRESS' ||
      'REGENERATION_FAILED' => 2,
      'REGENERATED_AWAITING_PUBLICATION' ||
      'PUBLICATION_IN_PROGRESS' ||
      'PUBLICATION_FAILED' => 3,
      _ => 0,
    };
    const steps = ['Requested', 'Approval', 'Regenerate', 'Publish'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFF6D68A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_outlined,
                color: Color(0xFFB56100),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$source correction',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF8A5200),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openStudentCorrectionWorkflow(student),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('View correction'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(steps.length, (index) {
              final completed = index < currentStep;
              final current = index == currentStep;
              return Chip(
                avatar: Icon(
                  completed
                      ? Icons.check_circle
                      : current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: completed
                      ? const Color(0xFF0B806C)
                      : current
                      ? const Color(0xFFB56100)
                      : const Color(0xFF94A3B8),
                ),
                label: Text(steps[index]),
                backgroundColor: completed
                    ? const Color(0xFFE8F7F3)
                    : current
                    ? const Color(0xFFFFF3D6)
                    : const Color(0xFFF8FAFC),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _reportReadinessSection(_StudentRecord student) {
    final remarks = _reportRemarks[student.id] ?? _ReportRemarksDraft.empty();
    final status = _reportStatusFor(student);
    final checks = <(String, bool)>[
      ('All grades entered', _gradesComplete(student)),
      ('Student evaluation', _evaluationComplete(student)),
      ('Report generated', reportHasGeneratedVersion(status)),
      ('Class Teacher remark', student.classTeacherCommentReady),
      ('Progression selected', remarks.promotedTo.isNotEmpty),
    ];
    return _section(
      title: 'Publication Readiness',
      action: _reportStateBadge(_publicationReadiness(student)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: checks.map((check) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
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
          if (reportNeedsUpdate(status)) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showReportUpdateDetails(student),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.update_outlined,
                      color: Color(0xFFD97706),
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        student.reportUpdateReasons.isEmpty
                            ? 'Report source data changed. Open to review the update.'
                            : '${student.reportUpdateReasons.first} Open to review.',
                        style: const TextStyle(
                          color: Color(0xFF9A5B08),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFD97706)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _studentReportEvaluation(
    _StudentRecord student,
    _EvaluationDraft evaluation, {
    required bool canRequestCorrection,
  }) {
    final hasActiveCorrection = _activeCorrectionFor(student) != null;
    final rawConduct = _studentReportCards[student.id]?['conductItems'];
    final consolidatedItems = rawConduct is List
        ? rawConduct.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            return (
              item['criterion']?.toString() ?? 'Criterion',
              item['rating']?.toString() ?? 'Not entered',
            );
          }).toList()
        : <(String, String)>[];
    final hasConsolidated = consolidatedItems.isNotEmpty;
    final items = hasConsolidated
        ? consolidatedItems
        : <(String, String)>[
            ('Homework', '${evaluation.homework}/10'),
            ('Attentiveness', '${evaluation.punctuality}/10'),
            ('Teamwork', '${evaluation.neatness}/10'),
            ('Participation', '${evaluation.attitude}/10'),
            ('Discipline', '${evaluation.discipline}/10'),
            ('Neatness', '${evaluation.organization}/10'),
          ];
    return _section(
      title: 'Student Evaluation',
      action: canRequestCorrection && hasConsolidated
          ? OutlinedButton.icon(
              onPressed: () => _requestRatingCorrection(student, rawConduct),
              icon: Icon(
                hasActiveCorrection
                    ? Icons.pending_actions_outlined
                    : Icons.rate_review_outlined,
                size: 14,
              ),
              label: Text(
                hasActiveCorrection ? 'View correction' : 'Request correction',
              ),
            )
          : hasConsolidated
          ? null
          : OutlinedButton.icon(
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
                      item.$2,
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
          if (!hasConsolidated) ...[
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
        ],
      ),
    );
  }

  Widget _studentReportRemarksSection(
    _StudentRecord student,
    _ReportRemarksDraft remarks, {
    required String classTeacherComment,
    required bool canEditHead,
    required bool canRequestCorrection,
  }) {
    final hasActiveCorrection = _activeCorrectionFor(student) != null;
    return _section(
      title: 'Teacher Remarks',
      action: canRequestCorrection
          ? hasActiveCorrection
                ? OutlinedButton.icon(
                    onPressed: () => _openStudentCorrectionWorkflow(student),
                    icon: const Icon(Icons.pending_actions_outlined, size: 14),
                    label: const Text('View correction'),
                  )
                : PopupMenuButton<String>(
                    tooltip: 'Request a remark correction',
                    onSelected: (value) {
                      if (value == 'CLASS_TEACHER_COMMENT') {
                        _requestTextSourceCorrection(
                          student: student,
                          type: value,
                          label: 'Class-teacher comment',
                          currentValue: classTeacherComment,
                          allowEmpty: false,
                          multiline: true,
                        );
                      } else {
                        _requestTextSourceCorrection(
                          student: student,
                          type: value,
                          label: 'Head-teacher comment',
                          currentValue: remarks.headTeacherRemarks,
                          allowEmpty: true,
                          multiline: true,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'CLASS_TEACHER_COMMENT',
                        child: Text('Class-teacher comment'),
                      ),
                      PopupMenuItem(
                        value: 'HEAD_TEACHER_COMMENT',
                        child: Text('Head-teacher comment'),
                      ),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.edit_note_outlined, size: 16),
                      label: Text('Request correction'),
                    ),
                  )
          : null,
      child: Column(
        children: [
          TextFormField(
            key: ValueKey('${student.id}-class-report-remark'),
            initialValue: classTeacherComment,
            readOnly: true,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Final Class Teacher Comment',
              hintText: 'Pending evaluation finalization',
              helperText:
                  'Created from Evaluations & Comments → Student comments.',
              suffixIcon: Icon(Icons.lock_outline),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${student.id}-head-report-remark'),
            initialValue: remarks.headTeacherRemarks,
            enabled: canEditHead,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Head Teacher Remarks (optional)',
              alignLabelWithHint: true,
            ),
            onChanged: (value) => _updateReportRemarks(
              student,
              headTeacherRemarks: value,
              ignoreHeadTeacherRemark: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentReportPromotionSection(
    _StudentRecord student,
    _ReportRemarksDraft remarks, {
    required bool canEdit,
    required bool canRequestCorrection,
  }) {
    final hasActiveCorrection = _activeCorrectionFor(student) != null;
    return _section(
      title: 'Progression & Attendance',
      action: canRequestCorrection
          ? OutlinedButton.icon(
              onPressed: () => _requestProgressionCorrection(student, remarks),
              icon: Icon(
                hasActiveCorrection
                    ? Icons.pending_actions_outlined
                    : Icons.trending_up_rounded,
                size: 14,
              ),
              label: Text(
                hasActiveCorrection ? 'View correction' : 'Request correction',
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: remarks.promotedTo.isEmpty ? null : remarks.promotedTo,
            isExpanded: true,
            hint: const Text('Promote, repeat, review or graduate'),
            decoration: const InputDecoration(
              labelText: 'Progression decision',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: _promotionGradeOptions(remarks.promotedTo).map((grade) {
              return DropdownMenuItem(value: grade, child: Text(grade));
            }).toList(),
            onChanged: canEdit
                ? (value) =>
                      _updateReportRemarks(student, promotedTo: value ?? '')
                : null,
          ),
          const SizedBox(height: 18),
          _reportInfoLine(
            'School days',
            _reportValue(student, 'totalSchoolDays'),
          ),
          _reportInfoLine('Present', _reportValue(student, 'daysPresent')),
          _reportInfoLine('Absent', _reportValue(student, 'daysAbsent')),
          _reportInfoLine('Late', _reportValue(student, 'lateness')),
          _reportInfoLine('Punctuality', _reportValue(student, 'punctuality')),
        ],
      ),
    );
  }

  String _reportValue(_StudentRecord student, String key) {
    final value = _studentReportCards[student.id]?[key];
    if (value == null || value.toString().trim().isEmpty) return '—';
    return value.toString();
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
      final overallComment = remarkController.text.trim();
      final entries =
          <(String, int, String)>[
            ('HOMEWORK', homework, 'homework'),
            ('ATTENTIVENESS', attentiveness, 'punctuality'),
            ('TEAMWORK', teamwork, 'neatness'),
            ('CLASS_PARTICIPATION', participation, 'attitude'),
            ('RESPECT_AND_DISCIPLINE', discipline, 'discipline'),
            ('NEATNESS', neatness, 'organization'),
          ].map((entry) {
            return {
              'criterion': entry.$1,
              'score': entry.$2,
              'teacherComments': criterionComments[entry.$3]?.trim() ?? '',
              'overallComment': overallComment,
            };
          }).toList();
      if (widget.customSchoolId.trim().isNotEmpty) {
        try {
          final setup = await _assessmentFormSetup;
          await _assessmentApi.saveStudentEvaluations(
            customSchoolId: widget.customSchoolId,
            customStudentId: student.id,
            termId: setup.termId,
            evaluatedBy: widget.viewerName,
            evaluations: entries,
          );
        } on AssessmentApiException catch (error) {
          if (mounted) _notice(error.message);
          remarkController.dispose();
          return;
        }
      }
      setState(() {
        evaluation.homework = homework;
        evaluation.punctuality = attentiveness;
        evaluation.neatness = teamwork;
        evaluation.attitude = participation;
        evaluation.discipline = discipline;
        evaluation.organization = neatness;
        evaluation.remark = overallComment;
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

  Future<int> _publishGeneratedReportsForStream(
    _FinalReportStream stream,
  ) async {
    if (widget.customSchoolId.trim().isEmpty) {
      throw const AssessmentApiException(
        'A live school session is required to publish report cards.',
      );
    }
    final setup = await _assessmentFormSetup;
    final loaded = await _loadLiveReportReadiness(setup, stream.name);
    if (!loaded || !mounted) return 0;
    final generated = _reportCardStudents
        .where(
          (student) =>
              normalizeReportStatus(_reportStatusFor(student)) == 'Generated',
        )
        .toList();
    if (generated.isEmpty) return 0;
    await Future.wait(
      generated.map(
        (student) => _assessmentApi.publishStudentReportCard(
          customSchoolId: widget.customSchoolId,
          customStudentId: student.id,
          termId: setup.termId,
          term: setup.termSequence,
          academicYearId: setup.academicYearId,
          publishedBy: widget.viewerName,
        ),
      ),
    );
    return generated.length;
  }

  Future<void> _openReportPrintPackage() async {
    if (widget.customSchoolId.trim().isEmpty) {
      _notice('A school must be selected before preparing report packages.');
      return;
    }
    try {
      final setup = await _assessmentFormSetup;
      if (!mounted) return;
      await showReportPrintPackageDialog(
        context: context,
        api: _assessmentApi,
        customSchoolId: widget.customSchoolId,
        setup: setup,
      );
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    }
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
    final notGenerated = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.pendingGeneration,
    );
    final pendingPublication = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.pendingPublication,
    );
    final updateRequired = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.updateRequired,
    );
    final streamsWithPending = _finalReportStreams
        .where((stream) => stream.pendingPublication > 0)
        .length;
    final approvedEvaluations = _finalReportStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.evaluationsApproved,
    );
    final evaluationPercent = students == 0
        ? 0
        : (approvedEvaluations * 100 / students).round().clamp(0, 100);
    final evaluationRemainingPercent = 100 - evaluationPercent;
    final filteredStreams = _finalReportStreams.where((stream) {
      final matchesSearch = stream.name.toLowerCase().contains(
        _finalReportSearchQuery.trim().toLowerCase(),
      );
      final matchesFilter = switch (_finalReportFilter) {
        'Pending Publication' => stream.pendingPublication > 0,
        'Published' => stream.published > 0,
        'Update Required' => stream.updateRequired > 0,
        'Not Generated' => stream.pendingGeneration > 0,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    final selectedPublishableStreams = _finalReportStreams
        .where(
          (stream) =>
              _selectedFinalReportStreams.contains(stream.id) &&
              stream.pendingPublication > 0,
        )
        .toList();
    final selectedPublicationCount = selectedPublishableStreams.fold<int>(
      0,
      (sum, stream) => sum + stream.pendingPublication,
    );

    Future<void> publishStreams(
      List<_FinalReportStream> publishable, {
      required bool allStreams,
    }) async {
      if (publishable.isEmpty) {
        _notice('There are no report cards ready to publish.');
        return;
      }
      final reportCount = publishable.fold<int>(
        0,
        (sum, stream) => sum + stream.pendingPublication,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            allStreams
                ? 'Publish all generated reports?'
                : 'Publish reports for selected classes?',
          ),
          content: Text(
            '$reportCount generated report${reportCount == 1 ? '' : 's'} '
            'across ${publishable.length} class${publishable.length == 1 ? '' : 'es'} '
            'will be published and visible to parents.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                allStreams ? 'Publish all reports' : 'Publish selected',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() {
        _isPublishingAllReports = true;
        for (final stream in publishable) {
          stream.publishing = true;
        }
      });
      try {
        var publishedReports = 0;
        for (final stream in publishable) {
          publishedReports += await _publishGeneratedReportsForStream(stream);
        }
        if (!mounted) return;
        setState(() {
          _isPublishingAllReports = false;
          _selectedFinalReportStreams.clear();
          for (final stream in publishable) {
            stream.publishing = false;
          }
        });
        await _loadFinalReportOverview();
        if (!mounted) return;
        _notice('$publishedReports report card(s) published.');
      } on AssessmentApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _isPublishingAllReports = false;
          for (final stream in publishable) {
            stream.publishing = false;
          }
        });
        _notice(error.message);
      }
    }

    Future<void> publishAll() => publishStreams(
      _finalReportStreams
          .where((stream) => stream.pendingPublication > 0)
          .toList(),
      allStreams: true,
    );

    Future<void> publishSelected() =>
        publishStreams(selectedPublishableStreams, allStreams: false);

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
                              '$_displayTerm ${_displayAcademicYear.replaceAll(' Academic Year', '')}',
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
                  final actions = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'How term reports work',
                        onPressed: _showTermReportGuide,
                        icon: const Icon(Icons.help_outline_rounded, size: 19),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loadingFinalReports
                            ? null
                            : _loadFinalReportOverview,
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text('Refresh'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('prepare-school-print-package'),
                        onPressed: _loadingFinalReports
                            ? null
                            : _openReportPrintPackage,
                        icon: const Icon(Icons.print_outlined, size: 15),
                        label: const Text('Prepare print package'),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _isPublishingAllReports || pendingPublication == 0
                            ? null
                            : publishAll,
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
                              : 'Publish all generated ($pendingPublication)',
                        ),
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
              if (_loadingFinalReports) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_finalReportLoadError != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    border: Border.all(color: const Color(0xFFF7C873)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _finalReportLoadError!,
                    style: const TextStyle(
                      color: Color(0xFF8A5A00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = [
                    _finalReportStat(
                      'Total Streams',
                      '${_finalReportStreams.length}',
                      const Color(0xFF111827),
                    ),
                    _finalReportStat(
                      'Total Students',
                      '$students',
                      const Color(0xFF111827),
                    ),
                    _finalReportStat(
                      'Published',
                      '$published',
                      const Color(0xFF009688),
                    ),
                    _finalReportStat(
                      'Pending Publication',
                      '$pendingPublication',
                      const Color(0xFFD97706),
                    ),
                    _finalReportStat(
                      'Update Required',
                      '$updateRequired',
                      const Color(0xFFD97706),
                    ),
                    _finalReportStat(
                      'Not Generated',
                      '$notGenerated',
                      const Color(0xFFDC2626),
                    ),
                  ];
                  final columns = constraints.maxWidth < 600
                      ? 1
                      : constraints.maxWidth < 980
                      ? 2
                      : 6;
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
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  key: const ValueKey('final-report-evaluation-progress'),
                  onTap: _openFinalReportEvaluations,
                  borderRadius: BorderRadius.circular(12),
                  hoverColor: const Color(0xFFEAF8F6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD8E7E5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final summary = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fact_check_outlined,
                                  color: Color(0xFF009688),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Evaluations & comments approval',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '$approvedEvaluations of $students student evaluations and comments approved · ${students - approvedEvaluations} remaining',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                        final progress = SizedBox(
                          width: constraints.maxWidth < 700
                              ? constraints.maxWidth
                              : 380,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$evaluationPercent% done',
                                    style: const TextStyle(
                                      color: Color(0xFF00897B),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '$evaluationRemainingPercent% remaining',
                                    style: const TextStyle(
                                      color: Color(0xFFD97706),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: evaluationPercent / 100,
                                  minHeight: 8,
                                  color: const Color(0xFF009688),
                                  backgroundColor: const Color(0xFFFDECC8),
                                ),
                              ),
                            ],
                          ),
                        );
                        final open = const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View by staff or class',
                              style: TextStyle(
                                color: Color(0xFF00796B),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Color(0xFF00796B),
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 900) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              summary,
                              const SizedBox(height: 14),
                              progress,
                              const SizedBox(height: 12),
                              open,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: summary),
                            progress,
                            const SizedBox(width: 24),
                            open,
                          ],
                        );
                      },
                    ),
                  ),
                ),
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
                child: LayoutBuilder(
                  builder: (context, _) {
                    final message = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF009688),
                          size: 17,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '$pendingPublication report cards pending publication across $streamsWithPending stream${streamsWithPending == 1 ? '' : 's'} · $updateRequired update${updateRequired == 1 ? '' : 's'} required.',
                            style: const TextStyle(
                              color: Color(0xFF047857),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                    return message;
                  },
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'Search stream or grade...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                      ),
                      onChanged: (value) =>
                          setState(() => _finalReportSearchQuery = value),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: _finalReportFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items:
                          const [
                                'All Streams',
                                'Published',
                                'Pending Publication',
                                'Update Required',
                                'Not Generated',
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
              if (selectedPublishableStreams.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F6),
                    border: Border.all(color: const Color(0xFFBFE5DF)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${selectedPublishableStreams.length} class${selectedPublishableStreams.length == 1 ? '' : 'es'} selected '
                        '· $selectedPublicationCount generated report${selectedPublicationCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Color(0xFF065F56),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _isPublishingAllReports
                                ? null
                                : () => setState(
                                    _selectedFinalReportStreams.clear,
                                  ),
                            child: const Text('Clear selection'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _isPublishingAllReports
                                ? null
                                : publishSelected,
                            icon: const Icon(Icons.send, size: 14),
                            label: Text(
                              'Publish selected ($selectedPublicationCount)',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _finalReportRegister(filteredStreams),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finalReportStat(String title, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 23,
              fontWeight: FontWeight.w800,
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
    final eligibleStreams = streams
        .where((stream) => stream.pendingPublication > 0 && !stream.publishing)
        .toList();
    final selectedEligibleCount = eligibleStreams
        .where((stream) => _selectedFinalReportStreams.contains(stream.id))
        .length;
    final bool? selectAllValue = eligibleStreams.isEmpty
        ? false
        : selectedEligibleCount == 0
        ? false
        : selectedEligibleCount == eligibleStreams.length
        ? true
        : null;
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
          final mobile = constraints.maxWidth < 1050;
          return Column(
            children: [
              if (!mobile)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  color: const Color(0xFFF9FAFB),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Checkbox(
                          tristate: true,
                          value: selectAllValue,
                          onChanged:
                              eligibleStreams.isEmpty || _isPublishingAllReports
                              ? null
                              : (checked) => setState(() {
                                  if (checked ?? false) {
                                    _selectedFinalReportStreams.addAll(
                                      eligibleStreams.map(
                                        (stream) => stream.id,
                                      ),
                                    );
                                  } else {
                                    _selectedFinalReportStreams.removeAll(
                                      eligibleStreams.map(
                                        (stream) => stream.id,
                                      ),
                                    );
                                  }
                                }),
                        ),
                      ),
                      const Expanded(
                        flex: 3,
                        child: _FinalReportHeader('CLASS'),
                      ),
                      const Expanded(
                        flex: 1,
                        child: _FinalReportHeader('STUDENTS', centered: true),
                      ),
                      const Expanded(
                        flex: 2,
                        child: _FinalReportHeader(
                          'ACADEMIC GRADES',
                          centered: true,
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: _FinalReportHeader(
                          'EVALUATIONS & COMMENTS',
                          centered: true,
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: _FinalReportHeader(
                          'PROGRESSION',
                          centered: true,
                        ),
                      ),
                      const Expanded(
                        flex: 2,
                        child: _FinalReportHeader('REPORT STATUS'),
                      ),
                      const Expanded(
                        flex: 2,
                        child: _FinalReportHeader('ACTIONS', trailing: true),
                      ),
                    ],
                  ),
                ),
              for (final stream in streams)
                mobile
                    ? _finalReportMobileCard(stream)
                    : _finalReportRow(stream),
            ],
          );
        },
      ),
    );
  }

  Widget _finalReportRow(_FinalReportStream stream) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openFinalReportStream(stream),
        hoverColor: const Color(0xFFEAF8F6),
        highlightColor: const Color(0xFFDFF3F0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Checkbox(
                  value: _selectedFinalReportStreams.contains(stream.id),
                  onChanged:
                      stream.pendingPublication == 0 ||
                          stream.publishing ||
                          _isPublishingAllReports
                      ? null
                      : (checked) => setState(() {
                          if (checked ?? false) {
                            _selectedFinalReportStreams.add(stream.id);
                          } else {
                            _selectedFinalReportStreams.remove(stream.id);
                          }
                        }),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  stream.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              _finalReportNumber(
                '${stream.students}',
                const Color(0xFF374151),
                1,
              ),
              Expanded(flex: 2, child: _academicGradesStatus(stream)),
              Expanded(flex: 2, child: _evaluationAndCommentsStatus(stream)),
              Expanded(flex: 2, child: _progressionStatus(stream)),
              Expanded(flex: 2, child: _finalReportStatus(stream)),
              Expanded(
                flex: 2,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _openFinalReportStream(stream),
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text('Open class'),
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
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openFinalReportStream(stream),
        hoverColor: const Color(0xFFEAF8F6),
        highlightColor: const Color(0xFFDFF3F0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _selectedFinalReportStreams.contains(stream.id),
                    onChanged:
                        stream.pendingPublication == 0 ||
                            stream.publishing ||
                            _isPublishingAllReports
                        ? null
                        : (checked) => setState(() {
                            if (checked ?? false) {
                              _selectedFinalReportStreams.add(stream.id);
                            } else {
                              _selectedFinalReportStreams.remove(stream.id);
                            }
                          }),
                  ),
                  Expanded(
                    child: Text(
                      stream.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _finalReportMobileCheck(
                'Academic grades',
                _academicGradesStatus(stream),
              ),
              _finalReportMobileCheck(
                'Evaluations & comments',
                _evaluationAndCommentsStatus(stream),
              ),
              _finalReportMobileCheck(
                'Progression',
                _progressionStatus(stream),
              ),
              _finalReportMobileCheck(
                'Report status',
                _finalReportStatus(stream),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openFinalReportStream(stream),
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: const Text('Open class'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finalReportMobileCheck(String label, Widget status) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: status),
        ],
      ),
    );
  }

  Widget _academicGradesStatus(_FinalReportStream stream) {
    if (stream.students == 0) {
      return _finalReportCheckStatus('No students', const Color(0xFF64748B));
    }
    if (!stream.readinessAvailable) {
      return _finalReportCheckStatus('Unavailable', const Color(0xFF64748B));
    }
    return _finalReportCheckStatus(
      stream.academicGradesReady ? 'Complete' : 'Incomplete',
      stream.academicGradesReady
          ? const Color(0xFF047857)
          : const Color(0xFFD97706),
      detail: '${stream.academicGradesComplete} of ${stream.students} complete',
    );
  }

  Widget _evaluationAndCommentsStatus(_FinalReportStream stream) {
    final status = stream.evaluationAndCommentsStatus;
    final color = switch (status) {
      'Approved' => const Color(0xFF047857),
      'Awaiting approval' => const Color(0xFF2563EB),
      'Rejected' => const Color(0xFFB91C1C),
      'Not submitted' => const Color(0xFFB45309),
      'Incomplete' => const Color(0xFFD97706),
      _ => const Color(0xFF64748B),
    };
    final detail = stream.students == 0 || !stream.readinessAvailable
        ? null
        : '${stream.evaluationsApproved} of ${stream.students} approved';
    return _finalReportCheckStatus(status, color, detail: detail);
  }

  Widget _progressionStatus(_FinalReportStream stream) {
    if (stream.students == 0) {
      return _finalReportCheckStatus('No students', const Color(0xFF64748B));
    }
    if (!stream.progressionAvailable || !stream.readinessAvailable) {
      return _finalReportCheckStatus('Unavailable', const Color(0xFF64748B));
    }
    return _finalReportCheckStatus(
      stream.progressionReady ? 'Selected' : 'Pending',
      stream.progressionReady
          ? const Color(0xFF047857)
          : const Color(0xFFD97706),
      detail: '${stream.progressionSelected} of ${stream.students} selected',
    );
  }

  Widget _finalReportCheckStatus(String label, Color color, {String? detail}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5),
          ),
        ],
      ],
    );
  }

  Widget _finalReportStatus(_FinalReportStream stream) {
    late final String label;
    late final String detail;
    late final Color color;
    late final Color background;
    if (stream.students == 0) {
      label = 'No students';
      detail = 'No reports required';
      color = const Color(0xFF64748B);
      background = const Color(0xFFF1F5F9);
    } else if (stream.updateRequired > 0) {
      label = 'Update required';
      detail =
          '${stream.updateRequired} report${stream.updateRequired == 1 ? '' : 's'}';
      color = const Color(0xFFB45309);
      background = const Color(0xFFFFF7E6);
    } else if (stream.published >= stream.students) {
      label = 'Published';
      detail = '${stream.published} report${stream.published == 1 ? '' : 's'}';
      color = const Color(0xFF047857);
      background = const Color(0xFFECFDF5);
    } else if (stream.generated >= stream.students) {
      label = 'Generated';
      detail = stream.published > 0
          ? '${stream.published} published · ${stream.pendingPublication} ready'
          : '${stream.generated} ready to publish';
      color = const Color(0xFFB45309);
      background = const Color(0xFFFFF7E6);
    } else if (stream.generated > 0) {
      label = 'Partially generated';
      detail = '${stream.generated} of ${stream.students} generated';
      color = const Color(0xFFB45309);
      background = const Color(0xFFFFF7E6);
    } else {
      label = 'Not generated';
      detail = '${stream.students} report${stream.students == 1 ? '' : 's'}';
      color = const Color(0xFFB91C1C);
      background = const Color(0xFFFEF2F2);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              detail,
              style: TextStyle(
                color: color.withValues(alpha: .8),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classes() {
    return _page(
      title: 'Classes',
      subtitle: '$_displayAcademicYear - $_displayTerm',
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
          rows: const [],
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
        if (_evaluationManager)
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
    String className,
    String subject,
  ) {
    return showGeneralDialog<List<_CurriculumIndicator>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close curriculum indicators',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => _CurriculumDialog(
        initialSelection: initialSelection,
        api: _assessmentApi,
        grade: _curriculumGrade(className),
        subject: subject,
      ),
      transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }

  String _curriculumGrade(String className) {
    final normalized = className.trim().toLowerCase();
    final isPreBasic =
        normalized.contains('creche') ||
        normalized.contains('nursery') ||
        normalized.contains('kindergarten') ||
        RegExp(r'\bkg\s*[12]?\b').hasMatch(normalized) ||
        normalized.contains('pre-basic') ||
        normalized.contains('pre basic');
    if (isPreBasic) return 'Grade 1';
    final match = RegExp(
      r'(?:Grade|Basic|KG|JHS)\s*\d+',
      caseSensitive: false,
    ).firstMatch(className);
    final value = match?.group(0) ?? className.trim();
    if (value.toLowerCase().startsWith('basic ')) {
      return 'Grade ${value.substring(6)}';
    }
    return value;
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
    if (!_evaluationManager) {
      _notice(
        'Official report cards are managed by authorized academic managers.',
      );
      return;
    }
    final published = canDistributeReport(_reportStatusFor(student));
    final classTeacherComment = _classTeacherCommentFor(
      student,
      _reportRemarks[student.id] ?? _ReportRemarksDraft.empty(),
    );
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
                          Text('$_displayTerm - $_displayAcademicYear'),
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
                      _reportSection('ATTENDANCE RECORD', [
                        (
                          'Total school days',
                          _reportValue(student, 'totalSchoolDays'),
                        ),
                        ('Present', _reportValue(student, 'daysPresent')),
                        ('Absent', _reportValue(student, 'daysAbsent')),
                        ('Late', _reportValue(student, 'lateness')),
                        ('Punctuality', _reportValue(student, 'punctuality')),
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
                          classTeacherComment.isNotEmpty
                              ? classTeacherComment
                              : 'Pending',
                        ),
                        (
                          'Head teacher',
                          _reportRemarks[student.id]
                                      ?.headTeacherRemarks
                                      .isNotEmpty ==
                                  true
                              ? _reportRemarks[student.id]!.headTeacherRemarks
                              : 'Not provided',
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
                    if (published) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _reportPdfActions.contains(student.id)
                            ? null
                            : () => _previewReportPdf(student),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Print'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _reportPdfActions.contains(student.id)
                            ? null
                            : () => _downloadReportPdf(student),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Download'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<int>> _loadReportPdf(
    _StudentRecord student, {
    bool download = false,
  }) async {
    if (widget.customSchoolId.trim().isEmpty) {
      throw const AssessmentApiException(
        'A live school session is required to generate the PDF.',
      );
    }
    final setup = await _assessmentFormSetup;
    return _assessmentApi.getStudentReportCardPdf(
      customSchoolId: widget.customSchoolId,
      customStudentId: student.id,
      termId: setup.termId,
      academicYearId: setup.academicYearId,
      download: download,
    );
  }

  Future<void> _previewReportPdf(_StudentRecord student) async {
    if (_reportPdfActions.contains(student.id)) return;
    prepareDocumentWindow();
    setState(() => _reportPdfActions.add(student.id));
    try {
      final bytes = await _loadReportPdf(student);
      await openDocumentBytes(
        bytes,
        'application/pdf',
        _reportPdfFileName(student),
      );
      if (mounted) _notice('${student.name} report preview opened.');
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    } on UnsupportedError catch (error) {
      if (mounted) _notice(error.message ?? 'PDF preview is unavailable.');
    } finally {
      if (mounted) setState(() => _reportPdfActions.remove(student.id));
    }
  }

  Future<void> _downloadReportPdf(_StudentRecord student) async {
    if (_reportPdfActions.contains(student.id)) return;
    if (!canDistributeReport(_reportStatusFor(student))) {
      _notice('Publish this report before downloading it.');
      return;
    }
    setState(() => _reportPdfActions.add(student.id));
    try {
      final bytes = await _loadReportPdf(student, download: true);
      final downloaded = await downloadReportPdf(
        _reportPdfFileName(student),
        bytes,
      );
      if (mounted) {
        _notice(
          downloaded
              ? '${student.name} report downloaded.'
              : 'PDF download is currently available on web.',
        );
      }
    } on AssessmentApiException catch (error) {
      if (mounted) _notice(error.message);
    } finally {
      if (mounted) setState(() => _reportPdfActions.remove(student.id));
    }
  }

  String _reportPdfFileName(_StudentRecord student) {
    final safeName = student.name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'Report_Card_${safeName.isEmpty ? student.id : safeName}.pdf';
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
    required this.selectedStream,
    required this.source,
    required this.setup,
    required this.api,
    required this.customSchoolId,
    required this.onBack,
    required this.onCurriculum,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final AssessmentStreamOption? selectedStream;
  final _AssessmentRecord? source;
  final AssessmentFormSetup setup;
  final AssessmentApiClient api;
  final String customSchoolId;
  final VoidCallback onBack;
  final Future<List<_CurriculumIndicator>?> Function(
    List<_CurriculumIndicator>,
    String,
    String,
  )
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
  String? _assessmentCategory;
  String? _type;
  String? _subject;
  String? _term;
  String? _academicYear;
  String? _status;
  DateTime? _dateGiven;
  bool _saving = false;
  String? _saveError;
  String? _indicatorError;
  final List<_CurriculumIndicator> _selectedIndicators = [];

  bool get _hasEnteredScores => (widget.source?.entered ?? 0) > 0;

  bool get _gradedAssessment =>
      widget.source?.status == 'Graded' ||
      (widget.source != null &&
          widget.source!.totalStudents > 0 &&
          widget.source!.entered >= widget.source!.totalStudents);

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
      _selectedClass = widget.source!.className;
      _type = _canonicalAssessmentTypeLabel(widget.source!.type);
      _assessmentCategory = _categoryForAssessmentType(_type);
      _subject = widget.source!.subject;
      _term = widget.source!.term;
      _academicYear = widget.source!.academicYear;
      _status = widget.source!.status;
      _dateGiven = _parseAssessmentDate(widget.source!.date);
      _description.text = widget.source!.description;
      _selectedIndicators.addAll(widget.source!.curriculumIndicators);
    } else {
      _selectedClass = widget.selectedStream?.label;
      _term = widget.setup.termName;
      _academicYear = widget.setup.academicYearName;
    }
  }

  void _selectAssessmentCategory(String? category) {
    setState(() {
      _assessmentCategory = category;
      if (!_typesForAssessmentCategory(category).contains(_type)) {
        _type = null;
      }
    });
  }

  void _selectSubject(String? subject) {
    setState(() {
      if (_subject != subject) {
        _selectedIndicators.clear();
        _indicatorError = null;
      }
      _subject = subject;
    });
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
    if (_selectedClass == null || _subject == null) {
      setState(() {
        _indicatorError = 'Select a subject before browsing.';
      });
      return;
    }
    final selection = await widget.onCurriculum(
      _selectedIndicators,
      _selectedClass!,
      _subject!,
    );
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
                  if (_saveError != null) ...[
                    const SizedBox(height: 12),
                    _assessmentSaveError(),
                  ],
                  const SizedBox(height: 16),
                  _assessmentDetailsCard(),
                  const SizedBox(height: 16),
                  _curriculumCard(),
                  const SizedBox(height: 16),
                  _formActions(),
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
                        onPressed: _saving || widget.setup.termClosed
                            ? null
                            : _submit,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(_saving ? 'Saving…' : 'Save Changes'),
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
              if (_saveError != null) ...[
                _assessmentSaveError(),
                const SizedBox(height: 16),
              ],
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
                          _dropdown(
                            label: 'Assessment Category',
                            hint: 'Select category',
                            value: _assessmentCategory,
                            values: _assessmentCategories,
                            onChanged: _hasEnteredScores
                                ? null
                                : _selectAssessmentCategory,
                          ),
                          if (_hasEnteredScores) ...[
                            const SizedBox(height: 8),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Category, type, subject, term and maximum score are locked because scores have been entered.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _responsivePair(
                            _dropdown(
                              label: 'Assessment Type',
                              hint: _assessmentCategory == null
                                  ? 'Select category first'
                                  : 'Select type',
                              value: _type,
                              values: _typesForAssessmentCategory(
                                _assessmentCategory,
                              ),
                              onChanged:
                                  _assessmentCategory == null ||
                                      _hasEnteredScores
                                  ? null
                                  : (value) => setState(() => _type = value),
                            ),
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                suffixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              child: Text(
                                _status ?? 'Not Started',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _responsivePair(
                            _dateField(),
                            TextFormField(
                              controller: _maxScore,
                              keyboardType: TextInputType.number,
                              readOnly: _hasEnteredScores,
                              decoration: InputDecoration(
                                labelText: 'Max Score',
                                hintText: 'Max marks',
                                helperText: _hasEnteredScores
                                    ? 'Reset entered scores before changing this value.'
                                    : null,
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
                              values: _subjectOptions,
                              onChanged: _hasEnteredScores
                                  ? null
                                  : _selectSubject,
                            ),
                            _dropdown(
                              label: 'Term',
                              hint: 'Select term',
                              value: _term,
                              values: [widget.setup.termName],
                              onChanged: _hasEnteredScores
                                  ? null
                                  : (value) => setState(() => _term = value),
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
    return Row(
      children: [
        Flexible(
          child: InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left,
                    size: 18,
                    color: AppColors.green,
                  ),
                  Flexible(
                    child: Text(
                      widget.subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('/', style: TextStyle(color: AppColors.muted)),
        ),
        Flexible(
          child: Text(
            widget.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _formActions() {
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _saving ? null : widget.onBack,
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving || widget.setup.termClosed ? null : _submit,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Creating…' : 'Create Assessment'),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review the details above before creating this assessment.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Review the details above before creating this assessment.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
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

  Widget _assessmentSaveError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _saveError!,
              style: const TextStyle(color: Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formNotice(String message, Color background, Color foreground) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(message, style: TextStyle(color: foreground)),
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
            if (widget.setup.termClosed) ...[
              _formNotice(
                'The current term is closed. Assessments cannot be changed.',
                const Color(0xFFFFF7ED),
                const Color(0xFF9A3412),
              ),
              const SizedBox(height: 14),
            ],
            if (_selectedClass != null && _subjectOptions.isEmpty) ...[
              _formNotice(
                'No subjects are available for this class in the current term or your teaching allocation. Ask an administrator to review the class subject availability.',
                const Color(0xFFFFFBEB),
                const Color(0xFF92400E),
              ),
              const SizedBox(height: 14),
            ],
            if (_selectedClass == null) ...[
              _formNotice(
                'The selected class stream is unavailable. Return to Assessments and select the stream again.',
                const Color(0xFFFFF1F2),
                const Color(0xFF991B1B),
              ),
              const SizedBox(height: 14),
            ],
            _dropdown(
              label: 'Subject',
              hint: 'Select Subject',
              value: _subject,
              values: _subjectOptions,
              onChanged: _selectedClass == null ? null : _selectSubject,
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Assessment Category',
              hint: 'Select Category',
              value: _assessmentCategory,
              values: _assessmentCategories,
              onChanged: _selectAssessmentCategory,
            ),
            const SizedBox(height: 14),
            _dropdown(
              label: 'Assessment Type',
              hint: _assessmentCategory == null
                  ? 'Select a category first'
                  : 'Select Type',
              value: _type,
              values: _typesForAssessmentCategory(_assessmentCategory),
              onChanged: _assessmentCategory == null
                  ? null
                  : (value) => setState(() => _type = value),
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
                readOnly: (widget.source?.entered ?? 0) > 0,
                decoration: InputDecoration(
                  labelText: 'Maximum Score *',
                  hintText: '0',
                  helperText: (widget.source?.entered ?? 0) > 0
                      ? 'Reset entered scores before changing this value.'
                      : null,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 17,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      switch (_assessmentCategory) {
                        _practiceBasedAssessmentCategory =>
                          'This assessment records practice and classroom progress. It does not automatically affect the term report.',
                        _reportBasedAssessmentCategory =>
                          'This is an official CAT or examination score used for the term report.',
                        _ =>
                          'Select an assessment category to see how the score will be used.',
                      },
                      style: const TextStyle(
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
                    values: [widget.setup.termName],
                    onChanged: null,
                  ),
                  _dateField(),
                  _dropdown(
                    label: 'Academic Year',
                    hint: 'Select Year',
                    value: _academicYear,
                    values: [widget.setup.academicYearName],
                    onChanged: null,
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
    required ValueChanged<String?>? onChanged,
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

  AssessmentStreamOption? get _selectedStream {
    if (widget.source == null) return widget.selectedStream;
    for (final stream in widget.setup.streams) {
      if (stream.id == widget.source!.streamId) return stream;
    }
    for (final stream in widget.setup.streams) {
      if (stream.label == _selectedClass) return stream;
    }
    return null;
  }

  List<String> get _subjectOptions {
    final gradeLevelId =
        _selectedStream?.gradeLevelId ?? widget.source?.gradeLevelId;
    return widget.setup.subjects
        .where(
          (subject) =>
              (gradeLevelId == null || subject.gradeLevelId == gradeLevelId) &&
              subject.isAvailableIn(_selectedStream?.id),
        )
        .map((subject) => subject.name)
        .toSet()
        .toList();
  }

  AssessmentSubjectOption? get _selectedSubject {
    if (widget.source != null && _subject == widget.source!.subject) {
      for (final subject in widget.setup.subjects) {
        if (subject.id == widget.source!.schoolSubjectId) return subject;
      }
    }
    final gradeLevelId =
        _selectedStream?.gradeLevelId ?? widget.source?.gradeLevelId;
    for (final subject in widget.setup.subjects) {
      if (subject.name == _subject &&
          (gradeLevelId == null || subject.gradeLevelId == gradeLevelId) &&
          subject.isAvailableIn(_selectedStream?.id)) {
        return subject;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    String? changeReason;
    final sourceDate = widget.source == null
        ? null
        : _parseAssessmentDate(widget.source!.date);
    final dateChanged =
        sourceDate != null &&
        _dateGiven != null &&
        (sourceDate.year != _dateGiven!.year ||
            sourceDate.month != _dateGiven!.month ||
            sourceDate.day != _dateGiven!.day);
    if (_gradedAssessment || (_hasEnteredScores && dateChanged)) {
      changeReason = await _requestAssessmentChangeReason(
        dateChanged: dateChanged,
        graded: _gradedAssessment,
      );
      if (changeReason == null || !mounted) return;
    }
    await _submitWithReason(null, changeReason: changeReason);
  }

  Future<void> _submitWithReason(
    String? vacationOverrideReason, {
    String? changeReason,
  }) async {
    final detailsAreValid = _key.currentState!.validate();
    final indicatorsAreValid = _selectedIndicators.isNotEmpty;
    setState(() {
      _indicatorError = indicatorsAreValid
          ? null
          : 'Please select at least one curriculum indicator';
    });
    if (!detailsAreValid || !indicatorsAreValid) return;
    final stream = _selectedStream;
    final subject = _selectedSubject;
    if (stream == null || subject == null) {
      setState(
        () => _saveError =
            'The selected stream or subject is no longer configured.',
      );
      return;
    }
    final max = int.parse(_maxScore.text);
    final date = _dateGiven!;
    final body = <String, dynamic>{
      if (widget.source == null) 'streamId': stream.id,
      'schoolSubjectId': subject.id,
      'type': _assessmentTypeValue(_type!),
      'title': _title.text.trim(),
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'maxScore': max,
      'term': widget.setup.termSequence,
      if (widget.source == null) 'academicYearId': widget.setup.academicYearId,
      'description': _description.text.trim(),
      'isOfficialSBA': _schoolBasedAssessmentTypes.contains(_type),
      'curriculumIndicatorCodes': _selectedIndicators
          .map((indicator) => indicator.code)
          .toList(),
      if (vacationOverrideReason?.trim().isNotEmpty == true)
        'vacationOverrideReason': vacationOverrideReason!.trim(),
      if (changeReason?.trim().isNotEmpty == true)
        'changeReason': changeReason!.trim(),
    };

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final response = widget.source == null
          ? await widget.api.createAssessment(
              customSchoolId: widget.customSchoolId,
              body: body,
            )
          : await widget.api.updateAssessment(
              customSchoolId: widget.customSchoolId,
              assessmentId: widget.source!.id,
              body: body,
            );
      if (!mounted) return;
      final assessment = response['assessment'] is Map<String, dynamic>
          ? response['assessment'] as Map<String, dynamic>
          : response;
      final assessmentId =
          assessment['assessmentId']?.toString() ??
          response['assessmentId']?.toString() ??
          widget.source?.id;
      widget.onSave(
        _AssessmentRecord(
          id: assessmentId!,
          title: _title.text.trim(),
          type: _type!,
          subject: _subject!,
          streamId: stream.id,
          gradeLevelId: stream.gradeLevelId,
          schoolSubjectId: subject.id,
          className: stream.label,
          gradeName: stream.gradeName,
          streamName: stream.streamName,
          academicYearId: widget.setup.academicYearId,
          termSequence: widget.setup.termSequence,
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
          officialSba: _schoolBasedAssessmentTypes.contains(_type),
          curriculumIndicators: List.of(_selectedIndicators),
        ),
      );
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      if (vacationOverrideReason == null &&
          error.message.toLowerCase().contains('teaching begins')) {
        setState(() => _saving = false);
        final reason = await _requestEarlyAcademicReason(error.message);
        if (reason != null && mounted) {
          await _submitWithReason(reason, changeReason: changeReason);
        }
        return;
      }
      setState(() => _saveError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _requestAssessmentChangeReason({
    required bool dateChanged,
    required bool graded,
  }) async {
    final controller = TextEditingController();
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.history_rounded, color: AppColors.green),
          title: Text(
            graded
                ? 'Reason for changing this graded assessment'
                : 'Reason for changing the assessment date',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                graded
                    ? 'This assessment already has completed scores. Explain why the change is needed.'
                    : 'Scores have already been entered. Explain why the assessment date is changing.',
              ),
              if (dateChanged && graded) ...[
                const SizedBox(height: 8),
                const Text('The assessment date is also being changed.'),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Reason for change',
                  hintText: 'Enter a clear reason',
                  errorText: validation,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length < 5) {
                  setDialogState(() => validation = 'Enter a clear reason.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _requestEarlyAcademicReason(String warning) async {
    final controller = TextEditingController();
    String? validation;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('Teaching has not started'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(warning),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for recording this early',
                  errorText: validation,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length < 5) {
                  setDialogState(() => validation = 'Enter a clear reason.');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  String _assessmentTypeValue(String label) => switch (label) {
    'CAT 1' => 'CAT1',
    'CAT 2' => 'CAT2',
    'CAT 3' => 'CAT3',
    'CAT 4' || 'CAT 4 – Project/Assignment' => 'CAT4',
    'Exam' ||
    'End of Term' ||
    'End-of-Term Exam' ||
    'End-of-Term Examination' => 'END_OF_TERM_EXAM',
    'Class Exercise' => 'CLASS_EXERCISE',
    'Homework' => 'HOMEWORK',
    'Quiz' => 'QUIZ',
    'Project' => 'PROJECT',
    'Practical' => 'PRACTICAL',
    'Experiment' => 'EXPERIMENT',
    'Oral Assessment' => 'ORAL',
    'Performance Assessment' => 'PERFORMANCE',
    _ => 'CLASS_TEST',
  };

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
    required this.gradingGradeLevelId,
    required this.api,
    required this.customSchoolId,
    required this.submittedBy,
    required this.onBack,
    required this.onExport,
    required this.onSaved,
  });

  final _AssessmentRecord assessment;
  final int gradingGradeLevelId;
  final AssessmentApiClient api;
  final String customSchoolId;
  final String submittedBy;
  final VoidCallback onBack;
  final ValueChanged<String> onExport;
  final VoidCallback onSaved;

  @override
  State<_ScoreSheetPage> createState() => _ScoreSheetPageState();
}

class _ScoreSheetPageState extends State<_ScoreSheetPage> {
  final _searchController = TextEditingController();
  String _query = '';
  List<AssessmentStudentScore> _students = const [];
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  AssessmentGradingScale? _gradingScale;
  final Set<String> _resettingStudents = {};

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
    if (widget.customSchoolId.trim().isEmpty) {
      setState(() {
        _error = 'A school must be selected before loading the score sheet.';
        _loading = false;
      });
      return;
    }
    try {
      if (widget.gradingGradeLevelId <= 0) {
        throw const AssessmentApiException(
          'The grading scale could not be resolved for this class.',
        );
      }
      final gradingScale = await widget.api.getActiveGradingScale(
        gradeLevelId: widget.gradingGradeLevelId,
      );
      final sheet = await widget.api.getScoreSheet(
        customSchoolId: widget.customSchoolId,
        assessmentId: widget.assessment.id,
      );
      if (!mounted) return;
      _gradingScale = gradingScale;
      _replaceStudents(sheet.students);
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _replaceStudents(List<AssessmentStudentScore> students) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    for (final student in students) {
      _controllers[student.studentId] = TextEditingController(
        text: student.score == null
            ? ''
            : student.score!
                  .toStringAsFixed(2)
                  .replaceFirst(RegExp(r'\.?0+$'), ''),
      );
    }
    setState(() {
      _students = students;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _showGradingScale() => showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scale = _gradingScale!;
      return AlertDialog(
        title: const Text('Grading scale'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in scale.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          item.grade,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_formatPercentage(item.minPercentage)}–${_formatPercentage(item.maxPercentage)}%  ${item.descriptor}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  scale.gradeLevelName.isEmpty
                      ? 'School grading scale'
                      : '${scale.gradeLevelName} grading scale',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );

  String _formatPercentage(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _AssessmentSetupError(
        message: _error!,
        onRetry: _load,
        onBack: widget.onBack,
      );
    }
    final visibleStudents = _students.where((student) {
      final query = _query.trim().toLowerCase();
      return query.isEmpty ||
          student.name.toLowerCase().contains(query) ||
          student.studentId.toLowerCase().contains(query);
    }).toList();
    final values = _controllers.values
        .map((controller) => double.tryParse(controller.text.trim()))
        .whereType<double>()
        .where((score) => score >= 0 && score <= widget.assessment.maxScore)
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
    final allReportsLocked =
        _students.isNotEmpty &&
        _students.every((student) => student.reportGenerated);
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
                        '${widget.assessment.className} • ${widget.assessment.subject} • Max: ${widget.assessment.maxScore} marks',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                  final actions = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _showGradingScale,
                        child: const Text('View grading scale'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onExport(_buildCsv()),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('Export CSV'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving || allReportsLocked ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 16),
                        label: Text(
                          _saving
                              ? 'Saving…'
                              : allReportsLocked
                              ? 'Scores locked'
                              : 'Save Scores',
                        ),
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
              if (_students.any((student) => student.reportGenerated)) ...[
                _scoreSheetLockNotice(),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final stats = [
                    _oldScoreStat(
                      'Total Students',
                      '${_students.length}',
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
                          : '${high.toStringAsFixed(1)} / ${low!.toStringAsFixed(1)}',
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
                                const DataColumn(label: Text('ACTION')),
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

  double? _scoreFor(AssessmentStudentScore student) =>
      double.tryParse(_controllers[student.studentId]!.text.trim());

  double? _validScoreForDisplay(AssessmentStudentScore student) {
    final score = _scoreFor(student);
    if (score == null || score < 0 || score > widget.assessment.maxScore) {
      return null;
    }
    return score;
  }

  String _gradeFor(double? score) {
    if (score == null) return '—';
    final percent = score / widget.assessment.maxScore * 100;
    for (final item in _gradingScale!.items) {
      if (percent >= item.minPercentage && percent <= item.maxPercentage) {
        return item.grade;
      }
    }
    return '—';
  }

  Widget _oldScoreInput(AssessmentStudentScore student) {
    final score = _scoreFor(student);
    final invalid =
        score != null && (score < 0 || score > widget.assessment.maxScore);
    return SizedBox(
      width: 92,
      child: TextField(
        controller: _controllers[student.studentId],
        readOnly: student.reportGenerated,
        onChanged: (_) => setState(() {}),
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        decoration: InputDecoration(
          hintText: '—',
          isDense: true,
          errorText: invalid ? 'Out of range' : null,
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

  Widget _scoreGrade(AssessmentStudentScore student, double? officialScore) {
    final officialGrade = _gradeFor(officialScore);
    return Text(
      officialGrade,
      style: const TextStyle(fontWeight: FontWeight.w800),
    );
  }

  Widget _scorePassOutcome(
    AssessmentStudentScore student,
    double? officialScore,
  ) => _oldPassBadge(officialScore);

  DataRow _oldDesktopScoreRow(int index, AssessmentStudentScore student) {
    final score = _validScoreForDisplay(student);
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
        DataCell(Text(student.studentId)),
        DataCell(_oldScoreInput(student)),
        DataCell(_oldScoreVisual(score)),
        DataCell(_scoreGrade(student, score)),
        DataCell(_scorePassOutcome(student, score)),
        DataCell(_resetScoreAction(student)),
      ],
    );
  }

  Widget _oldMobileScoreRow(int index, AssessmentStudentScore student) {
    final score = _validScoreForDisplay(student);
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
                      student.studentId,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _scorePassOutcome(student, score),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _oldScoreInput(student),
              const SizedBox(width: 12),
              Expanded(child: _oldScoreVisual(score)),
              const SizedBox(width: 10),
              _scoreGrade(student, score),
            ],
          ),
          if (student.score != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: _resetScoreAction(student),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreSheetLockNotice() {
    final active = _students
        .where((student) => student.reportGenerated)
        .where(
          (student) => const {
            'PENDING',
            'APPROVED_REGENERATION_REQUIRED',
            'REGENERATED_AWAITING_PUBLICATION',
          }.contains(student.correctionStatus.toUpperCase()),
        )
        .toList();
    final statuses = active
        .map((student) => student.correctionStatus.toUpperCase())
        .toSet();
    final count = active.length;
    final noun = count == 1 ? 'student' : 'students';
    final message = switch (statuses.singleOrNull) {
      'PENDING' => 'Correction awaiting leadership approval for $count $noun.',
      'APPROVED_REGENERATION_REQUIRED' =>
        'Correction approved — report regeneration pending for $count $noun.',
      'REGENERATED_AWAITING_PUBLICATION' =>
        'Updated report awaiting publication for $count $noun.',
      _ when active.isNotEmpty =>
        'Score corrections are in progress for $count $noun. See each row for its current status.',
      _ =>
        'Scores locked — used in generated reports. Use Request correction to change a score.',
    };
    final hasActiveCorrection = active.isNotEmpty;
    final foreground = hasActiveCorrection
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF92400E);
    final background = hasActiveCorrection
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFFFFBEB);
    final border = hasActiveCorrection
        ? const Color(0xFFBFDBFE)
        : const Color(0xFFFDE68A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            hasActiveCorrection
                ? Icons.pending_actions_outlined
                : Icons.lock_outline,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resetScoreAction(AssessmentStudentScore student) {
    if (student.score == null) return const SizedBox.shrink();
    if (student.reportGenerated) {
      final status = student.correctionStatus.toUpperCase();
      final active = const {
        'PENDING',
        'APPROVED_REGENERATION_REQUIRED',
        'REGENERATED_AWAITING_PUBLICATION',
      }.contains(status);
      final label = switch (status) {
        'PENDING' => 'Awaiting approval',
        'APPROVED_REGENERATION_REQUIRED' => 'Awaiting regeneration',
        'REGENERATED_AWAITING_PUBLICATION' => 'Awaiting publication',
        _ => 'Request correction',
      };
      if (active) {
        final awaitingDecision = status == 'PENDING';
        final foreground = awaitingDecision
            ? const Color(0xFF92400E)
            : const Color(0xFF1D4ED8);
        final background = awaitingDecision
            ? const Color(0xFFFFF7ED)
            : const Color(0xFFEFF6FF);
        final border = awaitingDecision
            ? const Color(0xFFF59E0B)
            : const Color(0xFF60A5FA);
        return Container(
          key: ValueKey('score-correction-status-${student.studentId}'),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }
      return OutlinedButton.icon(
        key: ValueKey('request-score-correction-${student.studentId}'),
        onPressed: () => _requestScoreCorrection(student),
        icon: const Icon(Icons.edit_note_outlined, size: 16),
        label: Text(label),
      );
    }
    final resetting = _resettingStudents.contains(student.studentId);
    return TextButton.icon(
      onPressed: resetting ? null : () => _confirmResetScore(student),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
      icon: resetting
          ? const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.restart_alt, size: 16),
      label: Text(resetting ? 'Resetting…' : 'Reset score'),
    );
  }

  Future<void> _confirmResetScore(AssessmentStudentScore student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset score?'),
        content: Text(
          'Reset ${student.name}’s score? The recorded score will be removed, and the student will return to “Not entered”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Reset score'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resettingStudents.add(student.studentId));
    try {
      await widget.api.resetStudentScore(
        customSchoolId: widget.customSchoolId,
        assessmentId: widget.assessment.id,
        studentId: student.studentId,
      );
      if (!mounted) return;
      await _load();
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name}’s score was reset.')),
        );
      }
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _resettingStudents.remove(student.studentId));
      }
    }
  }

  Future<void> _requestScoreCorrection(AssessmentStudentScore student) async {
    List<Map<String, dynamic>> approvers;
    try {
      approvers = await widget.api.getReportCorrectionApprovers(
        customSchoolId: widget.customSchoolId,
      );
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    final proposedScore = TextEditingController(
      text: student.score
          ?.toStringAsFixed(2)
          .replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    final reason = TextEditingController();
    String? selectedApprover;
    final proposal = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request score correction'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${student.name} · ${widget.assessment.title}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The official score remains unchanged until leadership approves this request. Leadership will then regenerate and publish the updated report.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Current score',
                        ),
                        child: Text(
                          '${student.score?.toStringAsFixed(2) ?? 'Not entered'} / ${widget.assessment.maxScore}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('score-correction-proposed-score'),
                        controller: proposedScore,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'New score',
                          suffixText: '/ ${widget.assessment.maxScore}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('score-correction-approver'),
                  value: selectedApprover,
                  decoration: const InputDecoration(
                    labelText: 'Approver',
                    hintText: 'Choose approver',
                  ),
                  items: approvers.map((approver) {
                    final username = '${approver['username'] ?? ''}'.trim();
                    final name = '${approver['name'] ?? username}'.trim();
                    final role = '${approver['role'] ?? ''}'
                        .replaceAll('_', ' ')
                        .toLowerCase();
                    final roleLabel = role.isEmpty
                        ? ''
                        : '${role[0].toUpperCase()}${role.substring(1)}';
                    return DropdownMenuItem(
                      value: username,
                      child: Text(
                        roleLabel.isEmpty ? name : '$name · $roleLabel',
                      ),
                    );
                  }).toList(),
                  onChanged: approvers.isEmpty
                      ? null
                      : (value) =>
                            setDialogState(() => selectedApprover = value),
                ),
                if (approvers.isEmpty) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'No eligible approver is available. Ask an administrator to assign a school leader.',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('score-correction-reason'),
                  controller: reason,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Reason for correction',
                    hintText:
                        'Explain what was wrong and why this value is correct',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('submit-score-correction'),
              onPressed: selectedApprover == null
                  ? null
                  : () {
                      final score = double.tryParse(proposedScore.text.trim());
                      final explanation = reason.text.trim();
                      if (score == null ||
                          score < 0 ||
                          score > widget.assessment.maxScore) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Enter a score between 0 and ${widget.assessment.maxScore}.',
                            ),
                          ),
                        );
                        return;
                      }
                      if (student.score != null &&
                          (score - student.score!).abs() < .0001) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a different score first.'),
                          ),
                        );
                        return;
                      }
                      if (explanation.length < 5) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a clear reason of at least 5 characters.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogContext, {
                        'score': score,
                        'reason': explanation,
                        'approver': selectedApprover,
                      });
                    },
              child: const Text('Submit for approval'),
            ),
          ],
        ),
      ),
    );
    proposedScore.dispose();
    reason.dispose();
    if (proposal == null || !mounted) return;
    try {
      await widget.api.requestReportScoreCorrection(
        customSchoolId: widget.customSchoolId,
        studentId: student.studentId,
        assessmentId: widget.assessment.id,
        proposedScore: proposal['score'] as double,
        proposedRemarks: student.remarks,
        reason: proposal['reason'] as String,
        assignedApprover: proposal['approver'] as String,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correction submitted for approval. The official score is unchanged.',
          ),
        ),
      );
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _save() async {
    final scores = <Map<String, dynamic>>[];
    for (final entry in _controllers.entries) {
      final student = _students.firstWhere(
        (candidate) => candidate.studentId == entry.key,
      );
      if (student.reportGenerated) continue;
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
      final scoreChanged =
          score != null &&
          (student.score == null || (score - student.score!).abs() > .0001);
      if (score != null && scoreChanged) {
        scores.add({
          'studentId': entry.key,
          'score': score,
          'maxScore': widget.assessment.maxScore,
          'remarks': student.remarks,
        });
      }
    }
    if (scores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no editable changes to save.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.saveScoreSheet(
        customSchoolId: widget.customSchoolId,
        assessmentId: widget.assessment.id,
        submittedBy: widget.submittedBy,
        scores: scores,
      );
      if (!mounted) return;
      await _load();
      widget.onSaved();
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      if (error.message.toLowerCase().contains('report has been generated')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A report was generated while this page was open. Refresh and use Request correction for that student.',
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildCsv() {
    final rows = <String>[
      'Student ID,Student Name,Score,Maximum Score,Grade,Result',
      for (final student in _students)
        [
          student.studentId,
          '"${student.name.replaceAll('"', '""')}"',
          _controllers[student.studentId]!.text.trim(),
          widget.assessment.maxScore,
          _gradeFor(_scoreFor(student)),
          _scoreFor(student) == null
              ? ''
              : _scoreFor(student)! >= widget.assessment.maxScore * .5
              ? 'Pass'
              : 'Fail',
        ].join(','),
    ];
    return rows.join('\n');
  }
}

class _ClassSelectorDialog extends StatefulWidget {
  const _ClassSelectorDialog({required this.action, required this.streams});

  final String action;
  final List<AssessmentStreamOption> streams;

  @override
  State<_ClassSelectorDialog> createState() => _ClassSelectorDialogState();
}

class _ClassSelectorDialogState extends State<_ClassSelectorDialog> {
  late String _grade = widget.streams.first.gradeName;
  late int _streamId = widget.streams
      .firstWhere((stream) => stream.gradeName == _grade)
      .id;

  List<String> get _grades =>
      widget.streams.map((stream) => stream.gradeName).toSet().toList();

  List<AssessmentStreamOption> get _gradeStreams =>
      widget.streams.where((stream) => stream.gradeName == _grade).toList();

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
              items: _grades
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _grade = value ?? _grade;
                _streamId = _gradeStreams.first.id;
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _streamId,
              decoration: const InputDecoration(labelText: 'Stream'),
              items: _gradeStreams
                  .map(
                    (stream) => DropdownMenuItem(
                      value: stream.id,
                      child: Text(stream.streamName),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setState(() => _streamId = value ?? _streamId),
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
          onPressed: () => Navigator.pop(
            context,
            widget.streams.firstWhere((stream) => stream.id == _streamId).label,
          ),
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
  const _CurriculumDialog({
    required this.initialSelection,
    required this.api,
    required this.grade,
    required this.subject,
  });

  final List<_CurriculumIndicator> initialSelection;
  final AssessmentApiClient api;
  final String grade;
  final String subject;

  @override
  State<_CurriculumDialog> createState() => _CurriculumDialogState();
}

class _CurriculumDialogState extends State<_CurriculumDialog> {
  final _searchController = TextEditingController();
  late final Set<_CurriculumIndicator> _selected;
  List<_CurriculumIndicator> _indicators = const [];
  String _activeStrand = 'All';
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
    _loadIndicators();
  }

  Future<void> _loadIndicators() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await widget.api.getCurriculumIndicators(
        grade: widget.grade,
        subject: widget.subject,
      );
      if (!mounted) return;
      final indicators = result
          .map(
            (item) => _CurriculumIndicator(
              code: item.code,
              text: item.description,
              strand: item.strand,
              subStrand: item.substrand,
            ),
          )
          .toList();
      final validCodes = indicators.map((indicator) => indicator.code).toSet();
      setState(() {
        _indicators = indicators;
        _selected.removeWhere(
          (indicator) => !validCodes.contains(indicator.code),
        );
        _loading = false;
      });
    } on AssessmentApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message;
        _loading = false;
      });
    }
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Curriculum Indicators',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.grade} • ${widget.subject}',
                  style: const TextStyle(color: AppColors.muted),
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
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Loading curriculum indicators…',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                color: AppColors.muted,
                size: 34,
              ),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loadIndicators,
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
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
  _FinalReportStream({
    required this.id,
    required this.name,
    required this.students,
    required this.generated,
    required this.ready,
    required this.published,
    required this.updateRequired,
    required this.academicGradesComplete,
    required this.evaluationsApproved,
    required this.evaluationsAwaitingApproval,
    required this.evaluationsNotSubmitted,
    required this.evaluationsRejected,
    required this.progressionSelected,
    required this.readinessAvailable,
    required this.progressionAvailable,
  });

  final int id;
  final String name;
  final int students;
  final int generated;
  final int ready;
  int published;
  final int updateRequired;
  final int academicGradesComplete;
  final int evaluationsApproved;
  final int evaluationsAwaitingApproval;
  final int evaluationsNotSubmitted;
  final int evaluationsRejected;
  final int progressionSelected;
  final bool readinessAvailable;
  final bool progressionAvailable;
  bool publishing = false;

  String get displayName {
    final parts = name
        .split(' - ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 3 && parts[0] == parts[1]) {
      return <String>[parts.first, ...parts.skip(2)].join(' - ');
    }
    return name;
  }

  bool get academicGradesReady =>
      students > 0 && academicGradesComplete >= students;

  bool get progressionReady => students > 0 && progressionSelected >= students;

  String get evaluationAndCommentsStatus {
    if (students == 0) return 'No students';
    if (!readinessAvailable) return 'Unavailable';
    if (evaluationsRejected > 0) return 'Rejected';
    if (evaluationsApproved >= students) return 'Approved';
    if (evaluationsAwaitingApproval > 0) return 'Awaiting approval';
    if (evaluationsNotSubmitted > 0) return 'Not submitted';
    return 'Incomplete';
  }

  int get pendingPublication {
    return ready;
  }

  int get pendingGeneration {
    final value = students - generated;
    return value < 0 ? 0 : value;
  }

  String get status {
    if (published >= students) return 'Published';
    if (updateRequired > 0 || ready < students || generated < students) {
      return 'Needs attention';
    }
    return 'Ready';
  }
}

class _ReportRemarksDraft {
  const _ReportRemarksDraft({
    required this.classTeacherRemarks,
    required this.headTeacherRemarks,
    required this.promotedTo,
    this.ignoreHeadTeacherRemark = false,
    this.reportStatus = 'DRAFT',
  });

  factory _ReportRemarksDraft.empty() => const _ReportRemarksDraft(
    classTeacherRemarks: '',
    headTeacherRemarks: '',
    promotedTo: '',
    ignoreHeadTeacherRemark: false,
  );

  final String classTeacherRemarks;
  final String headTeacherRemarks;
  final String promotedTo;
  final bool ignoreHeadTeacherRemark;
  final String reportStatus;

  _ReportRemarksDraft copyWith({
    String? classTeacherRemarks,
    String? headTeacherRemarks,
    String? promotedTo,
    bool? ignoreHeadTeacherRemark,
    String? reportStatus,
  }) {
    return _ReportRemarksDraft(
      classTeacherRemarks: classTeacherRemarks ?? this.classTeacherRemarks,
      headTeacherRemarks: headTeacherRemarks ?? this.headTeacherRemarks,
      promotedTo: promotedTo ?? this.promotedTo,
      ignoreHeadTeacherRemark:
          ignoreHeadTeacherRemark ?? this.ignoreHeadTeacherRemark,
      reportStatus: reportStatus ?? this.reportStatus,
    );
  }

  bool get remarksComplete => classTeacherRemarks.isNotEmpty;
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

class _GradingRequirementsSnapshot {
  const _GradingRequirementsSnapshot({
    required this.totalSubjects,
    required this.completeSubjects,
    required this.requiredAssessments,
    required this.presentAssessments,
    required this.requiredScores,
    required this.enteredScores,
    required this.subjectIssues,
  });

  final int totalSubjects;
  final int completeSubjects;
  final int requiredAssessments;
  final int presentAssessments;
  final int requiredScores;
  final int enteredScores;
  final List<_GradingSubjectIssue> subjectIssues;

  bool get met =>
      totalSubjects > 0 &&
      completeSubjects == totalSubjects &&
      assessmentComponentsComplete &&
      allScoresEntered &&
      subjectIssues.isEmpty;

  bool get assessmentComponentsComplete =>
      totalSubjects > 0 &&
      requiredAssessments > 0 &&
      presentAssessments == requiredAssessments &&
      !subjectIssues.any((issue) => issue.duplicateComponents.isNotEmpty);

  bool get allScoresEntered =>
      requiredScores > 0 &&
      enteredScores == requiredScores &&
      assessmentComponentsComplete;

  bool get noAssessmentsCreated => presentAssessments == 0;
  bool get noScoresEntered => enteredScores == 0;
}

class _GradingSubjectIssue {
  const _GradingSubjectIssue({
    required this.subjectName,
    required this.missingComponents,
    required this.missingScores,
    required this.duplicateComponents,
  });

  final String subjectName;
  final List<String> missingComponents;
  final int missingScores;
  final List<String> duplicateComponents;

  bool get hasIssues =>
      missingComponents.isNotEmpty ||
      missingScores > 0 ||
      duplicateComponents.isNotEmpty;

  String get summary {
    final parts = <String>[
      if (missingComponents.isNotEmpty)
        '${missingComponents.length} assessment${missingComponents.length == 1 ? '' : 's'} missing',
      if (missingScores > 0)
        '$missingScores score${missingScores == 1 ? '' : 's'} missing',
      if (duplicateComponents.isNotEmpty)
        '${duplicateComponents.length} duplicate${duplicateComponents.length == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }

  String get detail {
    final parts = <String>[
      if (missingComponents.isNotEmpty)
        'Missing ${missingComponents.join(', ')}',
      if (missingScores > 0)
        '$missingScores score${missingScores == 1 ? '' : 's'} missing',
      if (duplicateComponents.isNotEmpty)
        'Duplicate ${duplicateComponents.join(', ')}',
    ];
    return parts.join(' · ');
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
    this.streamId = 0,
    this.gradeLevelId = 0,
    this.schoolSubjectId = 0,
    this.className = 'Grade 5 - Stream A',
    this.academicYearId = 0,
    this.termSequence = 1,
    this.gradeName = 'Grade 5',
    this.streamName = 'Stream A',
    this.highestScore = 0,
    this.lowestScore = 0,
    this.createdBy = '',
    this.updatedBy = '',
    this.createdAt = '',
    this.updatedAt = '',
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
  final int streamId;
  final int gradeLevelId;
  final int schoolSubjectId;
  final String className;
  final int academicYearId;
  final int termSequence;
  final String gradeName;
  final String streamName;
  final double highestScore;
  final double lowestScore;
  final String createdBy;
  final String updatedBy;
  final String createdAt;
  final String updatedAt;
}

class _AssessmentSetupError extends StatelessWidget {
  const _AssessmentSetupError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 40,
                color: AppColors.muted,
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton(onPressed: onBack, child: const Text('Back')),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentRecord {
  const _StudentRecord({
    required this.id,
    required this.name,
    required this.gender,
    required this.average,
    required this.grade,
    required this.readiness,
    required this.assessmentDataReady,
    required this.evaluationReady,
    required this.classTeacherCommentReady,
    required this.evaluationBlockers,
    required this.reportStatus,
    required this.reportUpdateReasons,
    required this.reportRegenerationRequired,
    required this.reportRepublishRequired,
    required this.reportVersion,
    required this.reportGeneratedAt,
    required this.parent,
  });

  final String id;
  final String name;
  final String gender;
  final double average;
  final String grade;
  final String readiness;
  final bool assessmentDataReady;
  final bool evaluationReady;
  final bool classTeacherCommentReady;
  final List<String> evaluationBlockers;
  final String reportStatus;
  final List<String> reportUpdateReasons;
  final bool reportRegenerationRequired;
  final bool reportRepublishRequired;
  final int reportVersion;
  final String reportGeneratedAt;
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
