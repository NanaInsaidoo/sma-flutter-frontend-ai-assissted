import 'package:flutter/material.dart';

import '../data/classes_api_client.dart';
import '../domain/class_models.dart';
import '../../attendance/domain/attendance_models.dart';
import '../../theme/app_theme.dart';
import 'grade_detail_screen.dart';
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
  final VoidCallback? onOpenAssessments;
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
  _PhaseFilter _phase = _PhaseFilter.all;
  _StreamStatusFilter _status = _StreamStatusFilter.all;
  String _search = '';
  _SelectedStream? _selectedStream;
  bool _loading = true;
  String? _error;

  List<_GradeLevel> get _visibleLevels {
    final query = _search.trim().toLowerCase();
    final visible = <_GradeLevel>[];
    for (final level in _levels) {
      if (_phase != _PhaseFilter.all && level.phase != _phase) continue;
      final gradeMatches =
          query.isEmpty || level.name.toLowerCase().contains(query);
      final streams = level.streams.where((stream) {
        final matchesSearch =
            gradeMatches ||
            stream.name.toLowerCase().contains(query) ||
            stream.teacherName.toLowerCase().contains(query);
        final matchesStatus = switch (_status) {
          _StreamStatusFilter.all => true,
          _StreamStatusFilter.active => stream.active,
          _StreamStatusFilter.inactive => !stream.active,
          _StreamStatusFilter.noTeacher => stream.teacherName.isEmpty,
        };
        return matchesSearch && matchesStatus;
      }).toList();
      final showActiveGradeWithoutStreams =
          level.streams.isEmpty &&
          gradeMatches &&
          (_status == _StreamStatusFilter.all ||
              _status == _StreamStatusFilter.active);
      if (streams.isEmpty && !showActiveGradeWithoutStreams) continue;
      visible.add(
        _GradeLevel(
          id: level.id,
          gradeLevelId: level.gradeLevelId,
          name: level.name,
          phase: level.phase,
          custom: level.custom,
          displayOrder: level.displayOrder,
          streams: streams,
        ),
      );
    }
    return visible;
  }

  @override
  void initState() {
    super.initState();
    _loadGradeStreams();
  }

  Future<void> _loadGradeStreams() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.getGradeStreams(widget.customSchoolId),
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _openClassConfiguration({bool addCustomClass = false}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Classes and subjects')),
          body: ClassSubjectConfigurationScreen(
            customSchoolId: widget.customSchoolId,
            accessToken: widget.accessToken,
            onRefreshAccessToken: widget.onRefreshAccessToken,
            repository: _repository,
            startWithAddCustomClass: addCustomClass,
          ),
        ),
      ),
    );
    await _loadGradeStreams();
  }

  Future<void> _showAddClassOrSectionDialog() async {
    final choice = await showDialog<_AddClassOrSectionChoice>(
      context: context,
      builder: (context) => const _AddClassOrSectionDialog(),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AddClassOrSectionChoice.classLevel:
        await _openClassConfiguration(addCustomClass: true);
      case _AddClassOrSectionChoice.section:
        await _showAddStreamDialog();
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

  @override
  Widget build(BuildContext context) {
    final selected = _selectedStream;
    if (selected != null) {
      return GradeDetailScreen(
        customSchoolId: widget.customSchoolId,
        streamId: selected.streamId,
        gradeLevelId: selected.gradeLevelId,
        subjectGradeLevelId: selected.subjectGradeLevelId,
        gradeName: selected.gradeName,
        streamName: selected.streamName,
        enrolled: selected.enrolled,
        capacity: selected.capacity,
        active: selected.active,
        classTeacherName: selected.classTeacherName,
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
        repository: _repository,
        onClassTeachersChanged: _loadGradeStreams,
        onOpenAttendance: widget.onOpenAttendance,
        onOpenAssessments: widget.onOpenAssessments,
        onOpenIncidents: widget.onOpenIncidents,
        onOpenCalendar: widget.onOpenCalendar,
        attendanceRepository: widget.attendanceRepository,
        onBack: () => setState(() => _selectedStream = null),
      );
    }

    final totalStreams = _levels.fold<int>(
      0,
      (total, level) => total + level.streams.length,
    );

    return Column(
      children: [
        _Header(
          totalStreams: totalStreams,
          onConfigure: () => _openClassConfiguration(),
        ),
        _PhaseTabs(
          selected: _phase,
          counts: _phaseCounts,
          onChanged: (phase) => setState(() => _phase = phase),
        ),
        _Toolbar(
          search: _search,
          status: _status,
          onSearchChanged: (value) => setState(() => _search = value),
          onStatusChanged: (value) => setState(() => _status = value),
          onAddClassOrSection: _showAddClassOrSectionDialog,
        ),
        Expanded(
          child: _GradeStreamsBody(
            loading: _loading,
            error: _error,
            visibleLevels: _visibleLevels,
            onRetry: _loadGradeStreams,
            onOpenStream: _openStream,
            onDeleteStream: _deleteStream,
            onAddStream: (level) => _showAddStreamDialog(level.id),
          ),
        ),
      ],
    );
  }

  void _openStream(_GradeLevel level, _StreamSummary stream) {
    setState(() {
      _selectedStream = _SelectedStream(
        streamId: stream.id,
        // Attendance and student roster endpoints use the canonical grade-level
        // id carried by the live stream, not the school-grade configuration id.
        gradeLevelId: stream.gradeLevelId > 0
            ? stream.gradeLevelId
            : level.gradeLevelId,
        // Subject configuration is attached to the school's grade record.
        // Custom grades can have a different canonical roster grade id.
        subjectGradeLevelId: level.gradeLevelId,
        gradeName: level.name,
        streamName: stream.name,
        enrolled: stream.enrolled,
        capacity: stream.capacity,
        active: stream.active,
        classTeacherName: stream.teacherName,
      );
    });
  }

  Future<void> _deleteStream(_GradeLevel level, _StreamSummary stream) async {
    final completeLevel = _levels.firstWhere(
      (candidate) => candidate.id == level.id,
      orElse: () => level,
    );
    final activeStreamCount = completeLevel.streams
        .where((candidate) => candidate.active)
        .length;
    if (stream.active && activeStreamCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Every active class must keep at least one section. Make the class inactive before deleting its final section.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete section?'),
        content: Text(
          'This will delete ${stream.name} from ${level.name}. Continue only if this section is no longer needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteStreams(
        customSchoolId: widget.customSchoolId,
        streamIds: [stream.id],
      );
      await _loadGradeStreams();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete section. $error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _phase = level.phase);
  }

  Map<_PhaseFilter, int> get _phaseCounts {
    final counts = <_PhaseFilter, int>{
      for (final phase in _PhaseFilter.values) phase: 0,
    };
    for (final level in _levels) {
      counts[_PhaseFilter.all] = (counts[_PhaseFilter.all] ?? 0) + 1;
      counts[level.phase] = (counts[level.phase] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _showAddStreamDialog([int? initialGradeInternalId]) async {
    if (_levels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a class before creating a section.')),
      );
      return;
    }
    final created = await showDialog<_NewStreamDraft>(
      context: context,
      builder: (context) => _AddStreamDialog(
        levels: _levels,
        initialGradeInternalId: initialGradeInternalId,
      ),
    );
    if (created == null) return;

    final level = _levels.firstWhere(
      (level) => level.id == created.gradeInternalId,
      orElse: () => _levels.first,
    );
    setState(() => _error = null);
    try {
      await _repository.createStream(
        customSchoolId: widget.customSchoolId,
        gradeLevelId: level.gradeLevelId,
        streamName: created.streamName,
      );
      await _loadGradeStreams();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not add section. $error')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _phase = level.phase;
      _status = _StreamStatusFilter.all;
      _search = '';
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.totalStreams, required this.onConfigure});

  final int totalStreams;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Classes & Sections',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Manage classes & subjects'),
          ),
          const SizedBox(width: 14),
          Text(
            '$totalStreams sections configured',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseTabs extends StatelessWidget {
  const _PhaseTabs({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _PhaseFilter selected;
  final Map<_PhaseFilter, int> counts;
  final ValueChanged<_PhaseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: _PhaseFilter.values
            .map(
              (phase) => _TopTab(
                label: phase.label,
                count: counts[phase] ?? 0,
                selected: phase == selected,
                onTap: () => onChanged(phase),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.green : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? AppColors.greenSoft : const Color(0xFFEFF3F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.status,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onAddClassOrSection,
  });

  final String search;
  final _StreamStatusFilter status;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_StreamStatusFilter> onStatusChanged;
  final VoidCallback onAddClassOrSection;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6F8),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                hintText: 'Search classes or sections...',
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<_StreamStatusFilter>(
              value: status,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(12),
              ),
              items: _StreamStatusFilter.values
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onStatusChanged(value);
              },
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const ValueKey('add-class-or-section'),
            onPressed: onAddClassOrSection,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add class or section'),
          ),
        ],
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
    required this.onOpenStream,
    required this.onDeleteStream,
    required this.onAddStream,
  });

  final bool loading;
  final String? error;
  final List<_GradeLevel> visibleLevels;
  final VoidCallback onRetry;
  final void Function(_GradeLevel level, _StreamSummary stream) onOpenStream;
  final void Function(_GradeLevel level, _StreamSummary stream) onDeleteStream;
  final ValueChanged<_GradeLevel> onAddStream;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Builder(
            builder: (context) {
              if (loading) return const _StreamsLoadingCard();
              if (error != null) {
                return _StreamsErrorCard(message: error!, onRetry: onRetry);
              }
              if (visibleLevels.isEmpty) return const _EmptyStreamsCard();
              final children = <Widget>[];
              var customHeadingAdded = false;
              var standardHeadingAdded = false;
              for (final level in visibleLevels) {
                if (level.custom && !customHeadingAdded) {
                  children.add(
                    const _GradeGroupHeading(
                      title: 'Custom early-years classes',
                      subtitle:
                          'School-defined Creche and Nursery classes · ordered before KG1',
                    ),
                  );
                  customHeadingAdded = true;
                } else if (!level.custom && !standardHeadingAdded) {
                  children.add(
                    const _GradeGroupHeading(
                      title: 'GES grade levels',
                      subtitle: 'Kindergarten, Basic School and Junior High',
                    ),
                  );
                  standardHeadingAdded = true;
                }
                children.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: _GradeLevelSection(
                      level: level,
                      onOpenStream: onOpenStream,
                      onDeleteStream: onDeleteStream,
                      onAddStream: () => onAddStream(level),
                    ),
                  ),
                );
              }
              return Column(children: children);
            },
          ),
        ),
      ),
    );
  }
}

class _GradeGroupHeading extends StatelessWidget {
  const _GradeGroupHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeLevelSection extends StatelessWidget {
  const _GradeLevelSection({
    required this.level,
    required this.onOpenStream,
    required this.onDeleteStream,
    required this.onAddStream,
  });

  final _GradeLevel level;
  final void Function(_GradeLevel level, _StreamSummary stream) onOpenStream;
  final void Function(_GradeLevel level, _StreamSummary stream) onDeleteStream;
  final VoidCallback onAddStream;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              level.name,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(child: Divider(height: 1)),
            const SizedBox(width: 8),
            Text(
              '${level.streams.length} section${level.streams.length == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              key: ValueKey('add-section-${level.id}'),
              onPressed: onAddStream,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add section'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (level.streams.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: level.phase.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.meeting_room_outlined,
                      color: level.phase.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No sections configured yet',
                          style: TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'This class is active. Add its first section to assign students and teachers.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1280,
                child: DataTable(
                  headingRowHeight: 42,
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 58,
                  columnSpacing: 28,
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8FAF9),
                  ),
                  headingTextStyle: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: .55,
                    fontWeight: FontWeight.w900,
                  ),
                  dataTextStyle: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                  ),
                  columns: const [
                    DataColumn(label: Text('SECTION')),
                    DataColumn(label: Text('CLASS TEACHER')),
                    DataColumn(label: Text('ENROLLED / CAPACITY')),
                    DataColumn(label: Text('FILL')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('')),
                  ],
                  rows: level.streams
                      .map(
                        (stream) => DataRow(
                          key: ValueKey('stream-row-${stream.id}'),
                          cells: [
                            DataCell(
                              _OpenStreamButton(
                                stream: stream,
                                onOpen: () => onOpenStream(level, stream),
                              ),
                            ),
                            DataCell(_TeacherCell(name: stream.teacherName)),
                            DataCell(_EnrollmentText(stream: stream)),
                            DataCell(_FillCell(stream: stream)),
                            DataCell(_StatusChip(active: stream.active)),
                            DataCell(
                              _StreamActionsMenu(
                                onOpen: () => onOpenStream(level, stream),
                                onDelete: () => onDeleteStream(level, stream),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OpenStreamButton extends StatelessWidget {
  const _OpenStreamButton({required this.stream, required this.onOpen});

  final _StreamSummary stream;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onOpen,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.text,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
      child: _StreamNameCell(stream: stream),
    );
  }
}

class _StreamNameCell extends StatelessWidget {
  const _StreamNameCell({required this.stream});

  final _StreamSummary stream;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: stream.phase.color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Text(
              stream.initials,
              style: TextStyle(
                color: stream.phase.color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Text(stream.name, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _TeacherCell extends StatelessWidget {
  const _TeacherCell({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    if (name.trim().isEmpty) {
      return const Text(
        'Not assigned',
        style: TextStyle(color: AppColors.muted, fontStyle: FontStyle.italic),
      );
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.green.withValues(alpha: .16)),
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              color: AppColors.green,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(name),
      ],
    );
  }
}

class _EnrollmentText extends StatelessWidget {
  const _EnrollmentText({required this.stream});

  final _StreamSummary stream;

  @override
  Widget build(BuildContext context) {
    final capacityText = stream.capacity == null
        ? 'Not set'
        : '${stream.capacity}';
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(
            text: '${stream.enrolled}',
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: ' / $capacityText'),
        ],
      ),
    );
  }
}

class _FillCell extends StatelessWidget {
  const _FillCell({required this.stream});

  final _StreamSummary stream;

  @override
  Widget build(BuildContext context) {
    if (stream.capacity == null || stream.capacity! <= 0) {
      return const Text(
        'Capacity not set',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    final percentage = (stream.capacityRate * 100).round();
    final color = switch (stream.capacityState) {
      _CapacityState.ok => AppColors.green,
      _CapacityState.warning => AppColors.amber,
      _CapacityState.full => AppColors.red,
    };
    return Row(
      children: [
        SizedBox(
          width: 94,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: stream.capacityRate.clamp(0, 1),
              minHeight: 5,
              color: color,
              backgroundColor: const Color(0xFFEFF3F7),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$percentage%',
          style: TextStyle(
            color: percentage > 100 ? AppColors.red : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamActionsMenu extends StatelessWidget {
  const _StreamActionsMenu({required this.onOpen, required this.onDelete});

  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StreamAction>(
      tooltip: 'Section actions',
      onSelected: (action) {
        switch (action) {
          case _StreamAction.open:
            onOpen();
          case _StreamAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _StreamAction.open,
          child: _MenuActionLabel(
            icon: Icons.chevron_right_rounded,
            label: 'Open section',
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _StreamAction.delete,
          child: _MenuActionLabel(
            icon: Icons.delete_outline_rounded,
            label: 'Delete section',
            danger: true,
          ),
        ),
      ],
      child: const Icon(Icons.more_horiz_rounded, color: AppColors.muted),
    );
  }
}

class _MenuActionLabel extends StatelessWidget {
  const _MenuActionLabel({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.red : AppColors.text;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
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

class _AddClassOrSectionDialog extends StatelessWidget {
  const _AddClassOrSectionDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add class or section',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'What would you like to add?',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _AddChoiceCard(
                    key: const ValueKey('add-new-class-choice'),
                    icon: Icons.school_outlined,
                    title: 'Create a new class',
                    description:
                        'Add a school-specific class such as Creche or Nursery 1.',
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_AddClassOrSectionChoice.classLevel),
                  ),
                  const SizedBox(height: 12),
                  _AddChoiceCard(
                    key: const ValueKey('add-section-choice'),
                    icon: Icons.meeting_room_outlined,
                    title: 'Add a section to an existing class',
                    description:
                        'Choose a class and add another section, such as A or Section 2.',
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_AddClassOrSectionChoice.section),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChoiceCard extends StatelessWidget {
  const _AddChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddStreamDialog extends StatefulWidget {
  const _AddStreamDialog({required this.levels, this.initialGradeInternalId});

  final List<_GradeLevel> levels;
  final int? initialGradeInternalId;

  @override
  State<_AddStreamDialog> createState() => _AddStreamDialogState();
}

class _AddStreamDialogState extends State<_AddStreamDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _gradeInternalId;
  final _streamController = TextEditingController();

  bool get _classIsLocked =>
      widget.initialGradeInternalId != null &&
      widget.levels.any((level) => level.id == widget.initialGradeInternalId);

  _GradeLevel get _selectedLevel => widget.levels.firstWhere(
    (level) => level.id == _gradeInternalId,
    orElse: () => widget.levels.first,
  );

  @override
  void initState() {
    super.initState();
    final requested = widget.initialGradeInternalId;
    _gradeInternalId =
        requested != null && widget.levels.any((level) => level.id == requested)
        ? requested
        : widget.levels.first.id;
  }

  @override
  void dispose() {
    _streamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add section',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create another section under an existing class.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    if (_classIsLocked)
                      InputDecorator(
                        key: const ValueKey('locked-section-class'),
                        decoration: const InputDecoration(labelText: 'Class'),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.school_outlined,
                              size: 18,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _selectedLevel.name,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: _gradeInternalId,
                        decoration: const InputDecoration(labelText: 'Class'),
                        items: widget.levels
                            .map(
                              (level) => DropdownMenuItem(
                                value: level.id,
                                child: Text(level.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _gradeInternalId = value);
                          }
                        },
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _streamController,
                      decoration: const InputDecoration(
                        labelText: 'Section name',
                        hintText: 'e.g. Section 1 or A',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a section name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add section'),
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

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _NewStreamDraft(
        gradeInternalId: _gradeInternalId,
        streamName: _streamController.text.trim(),
      ),
    );
  }
}

enum _PhaseFilter {
  all('All', AppColors.green),
  earlyYears('Early Years', AppColors.green),
  kindergarten('Kindergarten', AppColors.amber),
  basic('Basic School', AppColors.blue),
  jhs('Junior High', AppColors.purple);

  const _PhaseFilter(this.label, this.color);

  final String label;
  final Color color;
}

enum _StreamStatusFilter {
  all('All Status'),
  active('Active'),
  inactive('Inactive'),
  noTeacher('No teacher');

  const _StreamStatusFilter(this.label);

  final String label;
}

enum _StreamAction { open, delete }

enum _AddClassOrSectionChoice { classLevel, section }

enum _CapacityState { ok, warning, full }

class _GradeLevel {
  const _GradeLevel({
    required this.id,
    required this.gradeLevelId,
    required this.name,
    required this.phase,
    required this.custom,
    required this.displayOrder,
    required this.streams,
  });

  factory _GradeLevel.fromApi(ClassGradeLevel level) {
    final phase = level.custom
        ? _PhaseFilter.earlyYears
        : _phaseForGradeName(level.name);
    return _GradeLevel(
      id: level.id,
      gradeLevelId: level.gradeLevelId,
      name: level.name,
      phase: phase,
      custom: level.custom,
      displayOrder: level.displayOrder,
      streams: level.streams
          .map(
            (stream) => _StreamSummary(
              id: stream.id,
              gradeLevelId: stream.gradeLevelId,
              name: stream.name,
              phase: phase,
              teacherName: stream.teacherName,
              enrolled: stream.enrolled,
              capacity: stream.capacity,
              active: stream.active,
            ),
          )
          .toList(),
    );
  }

  final int id;
  final int gradeLevelId;
  final String name;
  final _PhaseFilter phase;
  final bool custom;
  final int displayOrder;
  final List<_StreamSummary> streams;
}

class _SelectedStream {
  const _SelectedStream({
    required this.streamId,
    required this.gradeLevelId,
    required this.subjectGradeLevelId,
    required this.gradeName,
    required this.streamName,
    required this.enrolled,
    required this.capacity,
    required this.active,
    required this.classTeacherName,
  });

  final int streamId;
  final int gradeLevelId;
  final int subjectGradeLevelId;
  final String gradeName;
  final String streamName;
  final int enrolled;
  final int? capacity;
  final bool active;
  final String classTeacherName;
}

class _NewStreamDraft {
  const _NewStreamDraft({
    required this.gradeInternalId,
    required this.streamName,
  });

  final int gradeInternalId;
  final String streamName;
}

class _StreamSummary {
  const _StreamSummary({
    required this.id,
    required this.gradeLevelId,
    required this.name,
    required this.phase,
    required this.teacherName,
    required this.enrolled,
    required this.capacity,
    required this.active,
  });

  final int id;
  final int gradeLevelId;
  final String name;
  final _PhaseFilter phase;
  final String teacherName;
  final int enrolled;
  final int? capacity;
  final bool active;

  double get capacityRate =>
      capacity == null || capacity! <= 0 ? 0 : enrolled / capacity!;

  _CapacityState get capacityState {
    if (capacityRate >= 1) return _CapacityState.full;
    if (capacityRate >= .85) return _CapacityState.warning;
    return _CapacityState.ok;
  }

  String get initials {
    final parts = name
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

_PhaseFilter _phaseForGradeName(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.startsWith('kg') ||
      normalized.contains('kindergarten') ||
      normalized.contains('nursery')) {
    return _PhaseFilter.kindergarten;
  }
  if (normalized.startsWith('jhs') || normalized.contains('junior high')) {
    return _PhaseFilter.jhs;
  }
  return _PhaseFilter.basic;
}

bool _isSeniorSecondaryGrade(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized.startsWith('SHS') ||
      normalized.startsWith('SENIOR HIGH') ||
      normalized.startsWith('SENIOR SECONDARY');
}

String _initials(String name) {
  final parts = name
      .trim()
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
