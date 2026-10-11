import 'package:flutter/material.dart';

import '../data/classes_api_client.dart';
import '../domain/class_models.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../theme/app_theme.dart';
import 'class_subject_configuration_screen.dart';

class GradeStreamsScreen extends StatefulWidget {
  const GradeStreamsScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.onOpenAttendance,
    this.onOpenAssessments,
    this.onOpenIncidents,
    this.onOpenCalendar,
    this.attendanceRepository,
    ClassesRepository? repository,
  }) : _repository = repository;

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback? onOpenAttendance;
  final ValueChanged<int>? onOpenAssessments;
  final VoidCallback? onOpenIncidents;
  final VoidCallback? onOpenCalendar;
  final AttendanceRepository? attendanceRepository;
  final ClassesRepository? _repository;

  @override
  State<GradeStreamsScreen> createState() => _GradeStreamsScreenState();
}

class _GradeStreamsScreenState extends State<GradeStreamsScreen> {
  late final ClassesRepository _repository =
      widget._repository ??
      ClassesApiClient(
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
      );
  List<_GradeLevel> _levels = const [];
  _ClassSort _sort = _ClassSort.progression;
  String _search = '';
  int? _selectedGradeId;
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  String? _error;

  List<_GradeLevel> get _visibleLevels {
    final query = _search.trim().toLowerCase();
    final visible = <_GradeLevel>[];
    for (final level in _levels) {
      final matchesSearch =
          query.isEmpty ||
          level.name.toLowerCase().contains(query) ||
          level.streams.any(
            (stream) =>
                stream.name.toLowerCase().contains(query) ||
                stream.teacherName.toLowerCase().contains(query),
          );
      if (matchesSearch) visible.add(level);
    }
    visible.sort(_compareVisibleLevels);
    return visible;
  }

  int _compareVisibleLevels(_GradeLevel left, _GradeLevel right) {
    if (_sort == _ClassSort.activeFirst && left.active != right.active) {
      return left.active ? -1 : 1;
    }
    if (_sort == _ClassSort.inactiveFirst && left.active != right.active) {
      return left.active ? 1 : -1;
    }
    if (_sort == _ClassSort.name) {
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    }
    if (left.custom != right.custom) return left.custom ? -1 : 1;
    if (left.custom) {
      final displayOrder = left.displayOrder.compareTo(right.displayOrder);
      return displayOrder != 0
          ? displayOrder
          : _naturalNameCompare(left.name, right.name);
    }
    final progression = _gradeProgressionRank(
      left.name,
    ).compareTo(_gradeProgressionRank(right.name));
    return progression != 0
        ? progression
        : _naturalNameCompare(left.name, right.name);
  }

  @override
  void initState() {
    super.initState();
    _loadGradeStreams();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGradeStreams({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _repository.getAllGradeLevels(widget.customSchoolId),
        _repository.getAllStreams(widget.customSchoolId),
      ]);
      final levels = _mergeLiveStreamMetrics(
        levels: results[0],
        liveLevels: results[1],
      );
      if (!mounted) return;
      final orderedLevels =
          levels
              .where((level) => !_isSeniorSecondaryGrade(level.name))
              .map(_GradeLevel.fromApi)
              .toList()
            ..sort((a, b) {
              if (a.custom != b.custom) return a.custom ? -1 : 1;
              return a.displayOrder.compareTo(b.displayOrder);
            });
      setState(() {
        _levels = orderedLevels;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  List<ClassGradeLevel> _mergeLiveStreamMetrics({
    required List<ClassGradeLevel> levels,
    required List<ClassGradeLevel> liveLevels,
  }) {
    final liveByStreamId = <int, ClassStreamSummary>{
      for (final stream in liveLevels.expand((level) => level.streams))
        stream.id: stream,
    };
    if (liveByStreamId.isEmpty) return levels;

    return levels.map((level) {
      return ClassGradeLevel(
        id: level.id,
        gradeLevelId: level.gradeLevelId,
        name: level.name,
        status: level.status,
        streams: level.streams.map((stream) {
          final live = liveByStreamId[stream.id];
          if (live == null) return stream;
          return ClassStreamSummary(
            id: stream.id,
            name: stream.name,
            gradeLevelId: live.gradeLevelId > 0
                ? live.gradeLevelId
                : stream.gradeLevelId,
            teacherName: stream.teacherName.isNotEmpty
                ? stream.teacherName
                : live.teacherName,
            enrolled: live.enrolled,
            capacity: live.capacity,
            active: live.active,
          );
        }).toList(),
        custom: level.custom,
        studentCount: level.studentCount,
        displayOrder: level.displayOrder,
        nextGradeLevelId: level.nextGradeLevelId,
        nextGradeLevelName: level.nextGradeLevelName,
      );
    }).toList();
  }

  Future<void> _toggleGrade(_GradeLevel level, bool active) async {
    if (active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Activate ${level.name}?'),
          content: Text(
            level.streams.isEmpty
                ? '${level.name} does not have a section yet. Section 1 will be created because every active class must have at least one section.'
                : '${level.name} and its sections will become available for admissions, teacher assignments, attendance, and assessments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                level.streams.isEmpty
                    ? 'Create section and activate'
                    : 'Activate class',
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    final enrolled = level.streams.fold<int>(
      0,
      (total, stream) => total + stream.enrolled,
    );
    if (!active && enrolled > 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Cannot make ${level.name} inactive'),
          content: Text(
            '${level.name} has $enrolled actively enrolled student${enrolled == 1 ? '' : 's'}. Transfer, promote, withdraw, or graduate them before making this class inactive.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    if (!active) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Make ${level.name} inactive?'),
          content: Text(
            '${level.name} and its sections will no longer be available for new admissions, teacher assignments, attendance, or assessments. Existing records will remain available.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep active'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Make inactive'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _repository.setGradeLevelActive(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: level.gradeLevelId,
        active: active,
      );
      await _loadGradeStreams(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update ${level.name}. $error')),
      );
    }
  }

  Future<void> _addCustomClass() async {
    final name = TextEditingController();
    var sections = 1;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add custom class'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a school-defined class. Examples include Creche, Nursery 1, and Nursery 2. Custom classes appear before KG1.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('unified-custom-class-name'),
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Class name',
                    hintText: 'e.g. Creche or Nursery 1',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: sections,
                  decoration: const InputDecoration(labelText: 'Sections'),
                  items: List.generate(10, (index) => index + 1)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value section${value == 1 ? '' : 's'}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => sections = value ?? 1),
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
              onPressed: () {
                if (name.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('Create class'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await _repository.createCustomGradeLevel(
        customSchoolId: widget.customSchoolId,
        name: name.text.trim(),
        streamCount: sections,
      );
      await _loadGradeStreams(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add the class. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGradeId = _selectedGradeId;
    if (selectedGradeId != null) {
      return ClassSubjectConfigurationScreen(
        key: ValueKey('class-workspace-$selectedGradeId'),
        customSchoolId: widget.customSchoolId,
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
        repository: _repository,
        onOpenAttendance: widget.onOpenAttendance,
        onOpenAssessments: widget.onOpenAssessments,
        onOpenIncidents: widget.onOpenIncidents,
        onOpenCalendar: widget.onOpenCalendar,
        attendanceRepository: widget.attendanceRepository,
        initialGradeId: selectedGradeId,
        onBack: () async {
          setState(() => _selectedGradeId = null);
          await _loadGradeStreams(showLoading: false);
        },
      );
    }
    final totalStreams = _levels.fold<int>(
      0,
      (total, level) => total + level.streams.length,
    );
    final activeClasses = _levels.where((level) => level.active).length;

    return ColoredBox(
      color: const Color(0xFFF6F8F7),
      child: SingleChildScrollView(
        key: const ValueKey('classes-page-scroll'),
        controller: _scrollController,
        child: Column(
          children: [
            _Header(
              totalClasses: _levels.length,
              activeClasses: activeClasses,
              totalStreams: totalStreams,
              onAddCustomClass: _addCustomClass,
            ),
            _Toolbar(
              search: _search,
              sort: _sort,
              onSearchChanged: (value) => setState(() => _search = value),
              onSortChanged: (value) => setState(() => _sort = value),
            ),
            _GradeStreamsBody(
              loading: _loading,
              error: _error,
              visibleLevels: _visibleLevels,
              onRetry: _loadGradeStreams,
              onOpenGrade: (level) =>
                  setState(() => _selectedGradeId = level.id),
              onGradeActiveChanged: _toggleGrade,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.totalClasses,
    required this.activeClasses,
    required this.totalStreams,
    required this.onAddCustomClass,
  });

  final int totalClasses;
  final int activeClasses;
  final int totalStreams;
  final VoidCallback onAddCustomClass;

  @override
  Widget build(BuildContext context) {
    final inactiveClasses = totalClasses - activeClasses;
    return Container(
      color: const Color(0xFFF6F8F7),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Classes & Sections',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Activate classes here. Open a class to manage its sections and subjects.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _OverviewMetric(
                        value: '$activeClasses',
                        label: 'active',
                        color: AppColors.green,
                      ),
                      _OverviewMetric(
                        value: '$inactiveClasses',
                        label: 'inactive',
                        color: AppColors.muted,
                      ),
                      _OverviewMetric(
                        value: '$totalStreams',
                        label: 'sections',
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                ],
              );
              final addButton = FilledButton.icon(
                key: const ValueKey('add-class-or-section'),
                onPressed: onAddCustomClass,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add custom class'),
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 18), addButton],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 24),
                  addButton,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          '$value $label',
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.sort,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  final String search;
  final _ClassSort sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_ClassSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F8F7),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final searchField = TextField(
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 19),
                        hintText: 'Search classes',
                        isDense: true,
                      ),
                    );
                    final sortField = DropdownButtonFormField<_ClassSort>(
                      key: const ValueKey('class-sort'),
                      value: sort,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sort',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      items: _ClassSort.values
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onSortChanged(value);
                      },
                    );
                    if (constraints.maxWidth < 520) {
                      return Column(
                        children: [
                          searchField,
                          const SizedBox(height: 10),
                          sortField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 12),
                        SizedBox(width: 210, child: sortField),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradeStreamsBody extends StatelessWidget {
  const _GradeStreamsBody({
    required this.loading,
    required this.error,
    required this.visibleLevels,
    required this.onRetry,
    required this.onOpenGrade,
    required this.onGradeActiveChanged,
  });

  final bool loading;
  final String? error;
  final List<_GradeLevel> visibleLevels;
  final VoidCallback onRetry;
  final ValueChanged<_GradeLevel> onOpenGrade;
  final void Function(_GradeLevel level, bool active) onGradeActiveChanged;

  @override
  Widget build(BuildContext context) {
    final customLevels = visibleLevels.where((level) => level.custom).toList();
    final gesLevels = visibleLevels.where((level) => !level.custom).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Builder(
            builder: (context) {
              if (loading) return const _StreamsLoadingCard();
              if (error != null) {
                return _StreamsErrorCard(message: error!, onRetry: onRetry);
              }
              if (visibleLevels.isEmpty) return const _EmptyStreamsCard();
              return Column(
                children: [
                  if (customLevels.isNotEmpty)
                    _ClassGroupPanel(
                      title: 'Custom classes',
                      subtitle:
                          'School-defined classes shown before Kindergarten',
                      icon: Icons.auto_awesome_outlined,
                      levels: customLevels,
                      onOpenGrade: onOpenGrade,
                      onGradeActiveChanged: onGradeActiveChanged,
                    ),
                  if (customLevels.isNotEmpty && gesLevels.isNotEmpty)
                    const SizedBox(height: 18),
                  if (gesLevels.isNotEmpty)
                    _ClassGroupPanel(
                      title: 'GES grade levels',
                      subtitle: 'Kindergarten, Basic School and Junior High',
                      icon: Icons.school_outlined,
                      levels: gesLevels,
                      onOpenGrade: onOpenGrade,
                      onGradeActiveChanged: onGradeActiveChanged,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ClassGroupPanel extends StatelessWidget {
  const _ClassGroupPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.levels,
    required this.onOpenGrade,
    required this.onGradeActiveChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_GradeLevel> levels;
  final ValueChanged<_GradeLevel> onOpenGrade;
  final void Function(_GradeLevel level, bool active) onGradeActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: AppColors.green, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${levels.length}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < levels.length; index++) ...[
            _ClassOverviewRow(
              level: levels[index],
              onOpen: () => onOpenGrade(levels[index]),
              onActiveChanged: (active) =>
                  onGradeActiveChanged(levels[index], active),
            ),
            if (index != levels.length - 1)
              const Divider(height: 1, indent: 72),
          ],
        ],
      ),
    );
  }
}

class _ClassOverviewRow extends StatelessWidget {
  const _ClassOverviewRow({
    required this.level,
    required this.onOpen,
    required this.onActiveChanged,
  });

  final _GradeLevel level;
  final VoidCallback onOpen;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = level.active ? AppColors.green : AppColors.muted;
    final studentCount = level.streams.fold<int>(
      0,
      (total, stream) => total + stream.enrolled,
    );
    final sectionCount = level.streams.length;
    return ColoredBox(
      color: level.active ? Colors.white : const Color(0xFFFAFBFC),
      child: InkWell(
        key: ValueKey('open-grade-${level.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  level.custom
                      ? Icons.auto_awesome_outlined
                      : Icons.school_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name,
                      style: TextStyle(
                        color: level.active
                            ? AppColors.text
                            : const Color(0xFF6B7788),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sectionCount section${sectionCount == 1 ? '' : 's'}  ·  $studentCount student${studentCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                level.active ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                label:
                    '${level.name} is ${level.active ? 'active' : 'inactive'}',
                child: Switch(
                  key: ValueKey('grade-active-${level.id}'),
                  value: level.active,
                  onChanged: onActiveChanged,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStreamsCard extends StatelessWidget {
  const _EmptyStreamsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.account_tree_outlined,
                color: AppColors.muted,
                size: 34,
              ),
              SizedBox(height: 12),
              Text(
                'No sections match the selected filters.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamsLoadingCard extends StatelessWidget {
  const _StreamsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: List.generate(
            4,
            (index) => Padding(
              padding: EdgeInsets.only(bottom: index == 3 ? 0 : 16),
              child: const _LoadingRow(),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _loadingBlock(width: 42, height: 42),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loadingBlock(width: 180, height: 14),
              const SizedBox(height: 10),
              _loadingBlock(width: double.infinity, height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingBlock({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEED),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _StreamsErrorCard extends StatelessWidget {
  const _StreamsErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.red,
                size: 42,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load classes and sections',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ClassSort {
  progression('Level order'),
  activeFirst('Active first'),
  inactiveFirst('Inactive first'),
  name('Name A–Z');

  const _ClassSort(this.label);

  final String label;
}

class _GradeLevel {
  const _GradeLevel({
    required this.id,
    required this.gradeLevelId,
    required this.name,
    required this.custom,
    required this.active,
    required this.displayOrder,
    required this.streams,
  });

  factory _GradeLevel.fromApi(ClassGradeLevel level) {
    return _GradeLevel(
      id: level.id,
      gradeLevelId: level.gradeLevelId,
      name: level.name,
      custom: level.custom,
      active: level.active,
      displayOrder: level.displayOrder,
      streams: level.streams
          .map(
            (stream) => _StreamSummary(
              name: stream.name,
              teacherName: stream.teacherName,
              enrolled: stream.enrolled,
            ),
          )
          .toList(),
    );
  }

  final int id;
  final int gradeLevelId;
  final String name;
  final bool custom;
  final bool active;
  final int displayOrder;
  final List<_StreamSummary> streams;
}

class _StreamSummary {
  const _StreamSummary({
    required this.name,
    required this.teacherName,
    required this.enrolled,
  });

  final String name;
  final String teacherName;
  final int enrolled;
}

bool _isSeniorSecondaryGrade(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized.startsWith('SHS') ||
      normalized.startsWith('SENIOR HIGH') ||
      normalized.startsWith('SENIOR SECONDARY');
}

int _gradeProgressionRank(String value) {
  final normalized = value.trim().toLowerCase();
  final number =
      int.tryParse(RegExp(r'\d+').firstMatch(normalized)?.group(0) ?? '') ?? 99;
  if (normalized.startsWith('kg') || normalized.contains('kindergarten')) {
    return 100 + number;
  }
  if (normalized.startsWith('basic')) return 200 + number;
  if (normalized.startsWith('jhs') || normalized.contains('junior high')) {
    return 300 + number;
  }
  return 1000 + number;
}

int _naturalNameCompare(String left, String right) {
  final leftNumber = int.tryParse(
    RegExp(r'\d+').firstMatch(left)?.group(0) ?? '',
  );
  final rightNumber = int.tryParse(
    RegExp(r'\d+').firstMatch(right)?.group(0) ?? '',
  );
  final leftBase = left.replaceAll(RegExp(r'\d+'), '').trim().toLowerCase();
  final rightBase = right.replaceAll(RegExp(r'\d+'), '').trim().toLowerCase();
  final base = leftBase.compareTo(rightBase);
  if (base != 0) return base;
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  return left.toLowerCase().compareTo(right.toLowerCase());
}
