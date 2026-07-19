import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../domain/student_models.dart';

const _allClasses = 'All classes';
const _allStatuses = 'All statuses';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({
    super.key,
    required this.term,
    required this.academicYear,
    required this.repository,
    this.onOpenHousehold,
  });

  final String term;
  final String academicYear;
  final StudentsRepository repository;
  final VoidCallback? onOpenHousehold;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late Future<List<EnrolledStudent>> _studentsFuture;
  String _query = '';
  String _selectedClass = _allClasses;
  String _selectedStatus = _allStatuses;
  bool _newThisTermOnly = false;
  EnrolledStudent? _selectedStudent;
  Future<EnrolledStudent>? _selectedStudentFuture;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _studentsFuture = widget.repository.getEnrolledStudents();
  }

  void _retry() {
    setState(() {
      _studentsFuture = widget.repository.getEnrolledStudents();
    });
  }

  void _openStudent(String studentId) {
    setState(() {
      _selectedStudent = null;
      _selectedStudentId = studentId;
      _selectedStudentFuture = widget.repository.getStudent(studentId);
    });
  }

  void _closeStudent() {
    setState(() {
      _selectedStudent = null;
      _selectedStudentId = null;
      _selectedStudentFuture = null;
    });
  }

  List<EnrolledStudent> _visibleStudents(List<EnrolledStudent> students) {
    final query = _query.trim().toLowerCase();
    return students.where((student) {
      if (_selectedClass != _allClasses &&
          student.className != _selectedClass) {
        return false;
      }
      if (_selectedStatus != _allStatuses &&
          _statusLabel(student.status) != _selectedStatus) {
        return false;
      }
      if (_newThisTermOnly && !student.newThisTerm) return false;
      if (query.isEmpty) return true;
      return student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query) ||
          student.guardianName.toLowerCase().contains(query) ||
          student.householdId.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedStudentFuture case final future?) {
      return FutureBuilder<EnrolledStudent>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _StudentProfileLoadingView();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _StudentProfileErrorView(
              onBack: _closeStudent,
              onRetry: () => _openStudent(_selectedStudentId!),
            );
          }
          _selectedStudent = snapshot.requireData;
          return StudentProfileView(
            student: snapshot.requireData,
            term: widget.term,
            academicYear: widget.academicYear,
            onBack: _closeStudent,
            onOpenStudent: _openStudent,
            onOpenHousehold: widget.onOpenHousehold,
          );
        },
      );
    }
    if (_selectedStudent != null) {
      return StudentProfileView(
        student: _selectedStudent!,
        term: widget.term,
        academicYear: widget.academicYear,
        onBack: _closeStudent,
        onOpenStudent: _openStudent,
        onOpenHousehold: widget.onOpenHousehold,
      );
    }

    return FutureBuilder<List<EnrolledStudent>>(
      future: _studentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StudentsLoadingView();
        }
        if (snapshot.hasError) {
          return _StudentsErrorView(onRetry: _retry);
        }

        final students = snapshot.data ?? const <EnrolledStudent>[];
        final classes = students.map((student) => student.className).toSet()
          ..add(_allClasses);
        final visible = _visibleStudents(students);
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 850;
            return SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StudentsHeader(
                    term: widget.term,
                    academicYear: widget.academicYear,
                  ),
                  const SizedBox(height: 20),
                  _StudentSummary(students: students),
                  const SizedBox(height: 20),
                  _StudentFilters(
                    classes: classes.toList()..sort(),
                    selectedClass: _selectedClass,
                    selectedStatus: _selectedStatus,
                    newThisTermOnly: _newThisTermOnly,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onClassChanged: (value) =>
                        setState(() => _selectedClass = value),
                    onStatusChanged: (value) =>
                        setState(() => _selectedStatus = value),
                    onNewThisTermChanged: (value) =>
                        setState(() => _newThisTermOnly = value),
                    onClear: () => setState(() {
                      _query = '';
                      _selectedClass = _allClasses;
                      _selectedStatus = _allStatuses;
                      _newThisTermOnly = false;
                    }),
                  ),
                  const SizedBox(height: 14),
                  _StudentsRegister(
                    students: visible,
                    totalStudents: students.length,
                    compact: compact,
                    onSelected: (student) => _openStudent(student.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentsHeader extends StatelessWidget {
  const _StudentsHeader({required this.term, required this.academicYear});

  final String term;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 14,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const SizedBox(
          width: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Students',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Enrolled student register and current-term progress.',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ],
          ),
        ),
        _TermBadge(term: term, academicYear: academicYear),
      ],
    );
  }
}

class _TermBadge extends StatelessWidget {
  const _TermBadge({required this.term, required this.academicYear});

  final String term;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 18,
            color: AppColors.green,
          ),
          const SizedBox(width: 8),
          Text(
            '$term  ·  $academicYear',
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentSummary extends StatelessWidget {
  const _StudentSummary({required this.students});

  final List<EnrolledStudent> students;

  @override
  Widget build(BuildContext context) {
    final active = students
        .where((student) => student.status == EnrolledStudentStatus.active)
        .length;
    final newThisTerm = students.where((student) => student.newThisTerm).length;
    final attention = students
        .where(
          (student) =>
              student.attendanceRate < 90 ||
              student.feeBalance > 0 ||
              student.requirementsOutstanding > 0,
        )
        .length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((count - 1) * 14)) / count;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _SummaryCard(
              width: width,
              label: 'Total enrolled',
              value: '${students.length}',
              caption: 'Students in the register',
              icon: Icons.school_rounded,
              color: AppColors.green,
            ),
            _SummaryCard(
              width: width,
              label: 'Active students',
              value: '$active',
              caption: 'Currently attending',
              icon: Icons.verified_rounded,
              color: AppColors.blue,
            ),
            _SummaryCard(
              width: width,
              label: 'New this term',
              value: '$newThisTerm',
              caption: 'Recently enrolled',
              icon: Icons.person_add_alt_1_rounded,
              color: AppColors.purple,
            ),
            _SummaryCard(
              width: width,
              label: 'Needs attention',
              value: '$attention',
              caption: 'Fees, attendance or supplies',
              icon: Icons.notification_important_rounded,
              color: AppColors.amber,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentFilters extends StatelessWidget {
  const _StudentFilters({
    required this.classes,
    required this.selectedClass,
    required this.selectedStatus,
    required this.newThisTermOnly,
    required this.onSearchChanged,
    required this.onClassChanged,
    required this.onStatusChanged,
    required this.onNewThisTermChanged,
    required this.onClear,
  });

  final List<String> classes;
  final String selectedClass;
  final String selectedStatus;
  final bool newThisTermOnly;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onClassChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onNewThisTermChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 850;
            final search = TextField(
              key: const Key('students-search'),
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by student, ID, guardian or household',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            );
            final controls = [
              SizedBox(
                width: stacked ? double.infinity : 190,
                child: DropdownButtonFormField<String>(
                  value: selectedClass,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Class'),
                  items: classes
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onClassChanged(value);
                  },
                ),
              ),
              SizedBox(
                width: stacked ? double.infinity : 175,
                child: DropdownButtonFormField<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      const [_allStatuses, 'Active', 'Inactive', 'Transferred']
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) onStatusChanged(value);
                  },
                ),
              ),
              FilterChip(
                selected: newThisTermOnly,
                label: const Text('New this term'),
                avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
                onSelected: onNewThisTermChanged,
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear'),
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 12),
                  ...controls.expand(
                    (control) => [control, const SizedBox(height: 10)],
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                ...controls.expand(
                  (control) => [control, const SizedBox(width: 10)],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentsRegister extends StatelessWidget {
  const _StudentsRegister({
    required this.students,
    required this.totalStudents,
    required this.compact,
    required this.onSelected,
  });

  final List<EnrolledStudent> students;
  final int totalStudents;
  final bool compact;
  final ValueChanged<EnrolledStudent> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Enrolled students (${students.length})',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  students.length == totalStudents
                      ? 'Current register'
                      : 'Filtered from $totalStudents',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (students.isEmpty)
            const _EmptyRegister()
          else if (compact)
            ...students.map(
              (student) => _StudentCompactRow(
                student: student,
                onTap: () => onSelected(student),
              ),
            )
          else ...[
            const _StudentTableHeader(),
            ...students.map(
              (student) => _StudentTableRow(
                student: student,
                onTap: () => onSelected(student),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StudentTableHeader extends StatelessWidget {
  const _StudentTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFA),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: const Row(
        children: [
          Expanded(flex: 23, child: _ColumnLabel('STUDENT')),
          Expanded(flex: 10, child: _ColumnLabel('CLASS')),
          Expanded(flex: 19, child: _ColumnLabel('PRIMARY GUARDIAN')),
          Expanded(flex: 11, child: _ColumnLabel('ATTENDANCE')),
          Expanded(flex: 12, child: _ColumnLabel('FEE BALANCE')),
          Expanded(flex: 12, child: _ColumnLabel('ITEMS & SUPPLIES')),
          Expanded(flex: 9, child: _ColumnLabel('STATUS')),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StudentTableRow extends StatelessWidget {
  const _StudentTableRow({required this.student, required this.onTap});

  final EnrolledStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('student-row-${student.id}'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(flex: 23, child: _StudentIdentity(student: student)),
            Expanded(
              flex: 10,
              child: Text(
                student.className,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 19,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.guardianName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${student.guardianRelationship} · ${student.guardianPhone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 11,
              child: _AttendanceValue(rate: student.attendanceRate),
            ),
            Expanded(
              flex: 12,
              child: Text(
                student.feeBalance == 0
                    ? 'Paid'
                    : 'GH\u20b5 ${student.feeBalance.toStringAsFixed(0)}',
                style: TextStyle(
                  color: student.feeBalance == 0
                      ? AppColors.green
                      : AppColors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(flex: 12, child: _RequirementValue(student: student)),
            Expanded(flex: 9, child: _StatusBadge(status: student.status)),
            const SizedBox(
              width: 32,
              child: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentCompactRow extends StatelessWidget {
  const _StudentCompactRow({required this.student, required this.onTap});

  final EnrolledStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('student-row-${student.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _StudentIdentity(student: student)),
                _StatusBadge(status: student.status),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _MiniValue(icon: Icons.class_rounded, label: student.className),
                _MiniValue(
                  icon: Icons.person_outline_rounded,
                  label: student.guardianName,
                ),
                _MiniValue(
                  icon: Icons.fact_check_outlined,
                  label:
                      '${student.attendanceRate.toStringAsFixed(1)}% attendance',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentIdentity extends StatelessWidget {
  const _StudentIdentity({required this.student});

  final EnrolledStudent student;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _InitialsAvatar(name: student.name),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (student.newThisTerm) ...[
                    const SizedBox(width: 7),
                    const _NewBadge(),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${student.id} · ${student.householdId}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.green,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: AppColors.purple,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AttendanceValue extends StatelessWidget {
  const _AttendanceValue({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final color = rate >= 95
        ? AppColors.green
        : rate >= 90
        ? AppColors.amber
        : AppColors.red;
    return Text(
      '${rate.toStringAsFixed(1)}%',
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

class _RequirementValue extends StatelessWidget {
  const _RequirementValue({required this.student});

  final EnrolledStudent student;

  @override
  Widget build(BuildContext context) {
    final complete = student.requirementsOutstanding == 0;
    return Text(
      complete
          ? 'Complete'
          : '${student.requirementsCompleted}/${student.requirementsTotal} received',
      style: TextStyle(
        color: complete ? AppColors.green : AppColors.amber,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final EnrolledStudentStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      EnrolledStudentStatus.active => AppColors.green,
      EnrolledStudentStatus.inactive => AppColors.muted,
      EnrolledStudentStatus.transferred => AppColors.blue,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          _statusLabel(status),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

class _EmptyRegister extends StatelessWidget {
  const _EmptyRegister();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 58, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 42, color: AppColors.muted),
            SizedBox(height: 12),
            Text(
              'No enrolled students match these filters.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 5),
            Text(
              'Clear one or more filters to view the register.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

enum _StudentProfileTab {
  overview,
  medical,
  attendance,
  fees,
  requirements,
  documents,
}

class StudentProfileView extends StatefulWidget {
  const StudentProfileView({
    super.key,
    required this.student,
    required this.term,
    required this.academicYear,
    required this.onBack,
    required this.onOpenStudent,
    this.onOpenHousehold,
  });

  final EnrolledStudent student;
  final String term;
  final String academicYear;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenStudent;
  final VoidCallback? onOpenHousehold;

  @override
  State<StudentProfileView> createState() => _StudentProfileViewState();
}

class _StudentProfileViewState extends State<StudentProfileView> {
  _StudentProfileTab _tab = _StudentProfileTab.overview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                key: const Key('back-to-students'),
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to students'),
              ),
              const SizedBox(height: 8),
              _StudentProfileHeader(
                student: widget.student,
                term: widget.term,
                academicYear: widget.academicYear,
              ),
              const SizedBox(height: 16),
              _ProfileTabs(
                selected: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 16),
              switch (_tab) {
                _StudentProfileTab.overview => _OverviewTab(
                  student: widget.student,
                  compact: compact,
                  onOpenStudent: widget.onOpenStudent,
                  onOpenHousehold: widget.onOpenHousehold,
                ),
                _StudentProfileTab.medical => _MedicalTab(
                  student: widget.student,
                ),
                _StudentProfileTab.attendance => _AttendanceTab(
                  student: widget.student,
                ),
                _StudentProfileTab.fees => _FeesTab(
                  student: widget.student,
                  term: widget.term,
                  academicYear: widget.academicYear,
                ),
                _StudentProfileTab.requirements => _RequirementsTab(
                  student: widget.student,
                ),
                _StudentProfileTab.documents => _DocumentsTab(
                  student: widget.student,
                ),
              },
            ],
          ),
        );
      },
    );
  }
}

class _StudentProfileHeader extends StatelessWidget {
  const _StudentProfileHeader({
    required this.student,
    required this.term,
    required this.academicYear,
  });

  final EnrolledStudent student;
  final String term;
  final String academicYear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final identity = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InitialsAvatar(name: student.name, size: 64),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${student.id} · ${student.className} · ${student.householdId}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final contextBadge = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBadge(status: student.status),
                const SizedBox(width: 10),
                _TermBadge(term: term, academicYear: academicYear),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 16), contextBadge],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                contextBadge,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({required this.selected, required this.onSelected});

  final _StudentProfileTab selected;
  final ValueChanged<_StudentProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = {
      _StudentProfileTab.overview: 'Overview',
      _StudentProfileTab.medical: 'Medical',
      _StudentProfileTab.attendance: 'Attendance',
      _StudentProfileTab.fees: 'Fees',
      _StudentProfileTab.requirements: 'Items & Supplies',
      _StudentProfileTab.documents: 'Documents',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((entry) {
          final active = selected == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              key: Key('student-tab-${entry.key.name}'),
              onPressed: () => onSelected(entry.key),
              style: OutlinedButton.styleFrom(
                backgroundColor: active ? AppColors.greenSoft : Colors.white,
                foregroundColor: active ? AppColors.green : AppColors.muted,
                side: BorderSide(
                  color: active ? AppColors.green : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
              ),
              child: Text(
                entry.value,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.student,
    required this.compact,
    required this.onOpenStudent,
    this.onOpenHousehold,
  });

  final EnrolledStudent student;
  final bool compact;
  final ValueChanged<String> onOpenStudent;
  final VoidCallback? onOpenHousehold;

  @override
  Widget build(BuildContext context) {
    final primary = Column(
      children: [
        _SectionCard(
          title: 'Personal information',
          icon: Icons.person_outline_rounded,
          child: _InfoGrid(
            values: {
              'Full name': student.name,
              'Date of birth': _formatDate(student.dateOfBirth),
              'Gender': student.gender,
              'Religion': student.religion,
              'Country of birth': student.countryOfBirth,
              'City of birth': student.cityOfBirth,
            },
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Enrollment information',
          icon: Icons.school_outlined,
          child: _InfoGrid(
            values: {
              'Student ID': student.id,
              'Current class': student.className,
              'Enrolled on': _formatDate(student.enrolledOn),
              'Household ID': student.householdId,
              'Enrollment status': _statusLabel(student.status),
              'Address': student.address,
            },
          ),
        ),
      ],
    );
    final secondary = Column(
      children: [
        _SectionCard(
          title: 'Current-term snapshot',
          icon: Icons.insights_rounded,
          child: Column(
            children: [
              _SnapshotRow(
                label: 'Attendance',
                value: '${student.attendanceRate.toStringAsFixed(1)}%',
                color: student.attendanceRate >= 90
                    ? AppColors.green
                    : AppColors.red,
              ),
              _SnapshotRow(
                label: 'Fee balance',
                value: student.feeBalance == 0
                    ? 'Paid'
                    : 'GH\u20b5 ${student.feeBalance.toStringAsFixed(0)} due',
                color: student.feeBalance == 0
                    ? AppColors.green
                    : AppColors.red,
              ),
              _SnapshotRow(
                label: 'Items & supplies',
                value:
                    '${student.requirementsCompleted}/${student.requirementsTotal} complete',
                color: student.requirementsOutstanding == 0
                    ? AppColors.green
                    : AppColors.amber,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _HouseholdMembersCard(
          student: student,
          onOpenStudent: onOpenStudent,
          onOpenHousehold: onOpenHousehold,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Medical alerts',
          icon: Icons.medical_information_outlined,
          child: student.medicalAlerts.isEmpty
              ? const Text(
                  'No medical alerts recorded.',
                  style: TextStyle(color: AppColors.muted),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: student.medicalAlerts
                      .map(
                        (alert) => Chip(
                          avatar: const Icon(
                            Icons.warning_amber_rounded,
                            size: 17,
                            color: AppColors.red,
                          ),
                          label: Text(alert),
                          backgroundColor: AppColors.red.withValues(
                            alpha: 0.08,
                          ),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
    if (compact) {
      return Column(children: [primary, const SizedBox(height: 14), secondary]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: primary),
        const SizedBox(width: 14),
        Expanded(child: secondary),
      ],
    );
  }
}

class _HouseholdMembersCard extends StatelessWidget {
  const _HouseholdMembersCard({
    required this.student,
    required this.onOpenStudent,
    this.onOpenHousehold,
  });

  final EnrolledStudent student;
  final ValueChanged<String> onOpenStudent;
  final VoidCallback? onOpenHousehold;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Household members',
      icon: Icons.family_restroom_rounded,
      child: Column(
        children: student.householdMembers.map((member) {
          final isStudent = member.type == StudentHouseholdMemberType.student;
          final isCurrentStudent = isStudent && member.id == student.id;
          return _HouseholdMemberRow(
            key: Key('household-member-${member.id}'),
            member: member,
            currentStudent: isCurrentStudent,
            onTap: isCurrentStudent
                ? null
                : isStudent
                ? () => onOpenStudent(member.id)
                : onOpenHousehold,
          );
        }).toList(),
      ),
    );
  }
}

class _HouseholdMemberRow extends StatelessWidget {
  const _HouseholdMemberRow({
    super.key,
    required this.member,
    required this.currentStudent,
    this.onTap,
  });

  final StudentHouseholdMember member;
  final bool currentStudent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final guardian = member.type == StudentHouseholdMemberType.guardian;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: guardian
            ? AppColors.greenSoft
            : AppColors.blue.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white,
                  foregroundColor: guardian ? AppColors.green : AppColors.blue,
                  child: Icon(
                    guardian
                        ? Icons.supervisor_account_outlined
                        : Icons.school_outlined,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              member.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (member.primary) ...[
                            const SizedBox(width: 7),
                            const _SmallPill(
                              label: 'Primary',
                              color: AppColors.green,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${member.relationship} · ${member.subtitle}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentStudent)
                  const Text(
                    'Current student',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else if (onTap != null) ...[
                  Text(
                    guardian ? 'Open household' : 'View profile',
                    style: TextStyle(
                      color: guardian ? AppColors.green : AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: guardian ? AppColors.green : AppColors.blue,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicalTab extends StatelessWidget {
  const _MedicalTab({required this.student});

  final EnrolledStudent student;

  @override
  Widget build(BuildContext context) {
    final receivedVaccinations = student.vaccinations
        .where((item) => item.status == StudentVaccinationStatus.received)
        .length;
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 245,
              child: _MiniMetric(
                label: 'Blood group',
                value: student.bloodGroup,
                color: AppColors.red,
              ),
            ),
            SizedBox(
              width: 245,
              child: _MiniMetric(
                label: 'Active alerts',
                value: '${student.medicalAlerts.length}',
                color: student.medicalAlerts.isEmpty
                    ? AppColors.green
                    : AppColors.amber,
              ),
            ),
            SizedBox(
              width: 245,
              child: _MiniMetric(
                label: 'Vaccinations recorded',
                value: '$receivedVaccinations/${student.vaccinations.length}',
                color: AppColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Medical conditions',
          icon: Icons.medical_information_outlined,
          child: Column(
            children: student.medicalConditions.map((condition) {
              return _DetailListRow(
                title: condition.name,
                subtitle: condition.notes,
                trailing: condition.hasCondition ? 'Yes' : 'No',
                color: condition.hasCondition ? AppColors.red : AppColors.green,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Allergies',
          icon: Icons.health_and_safety_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AllergyGroup(label: 'Food', items: student.allergies.food),
              const SizedBox(height: 14),
              _AllergyGroup(
                label: 'Medication',
                items: student.allergies.medication,
              ),
              const SizedBox(height: 14),
              _AllergyGroup(
                label: 'Environmental',
                items: student.allergies.environmental,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Vaccination records',
          icon: Icons.vaccines_outlined,
          child: Column(
            children: student.vaccinations
                .map((item) => _VaccinationRow(vaccination: item))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _AllergyGroup extends StatelessWidget {
  const _AllergyGroup({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('None recorded', style: TextStyle(color: AppColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    avatar: const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.amber,
                    ),
                    side: BorderSide.none,
                    backgroundColor: AppColors.amber.withValues(alpha: 0.1),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _VaccinationRow extends StatelessWidget {
  const _VaccinationRow({required this.vaccination});

  final StudentVaccination vaccination;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (vaccination.status) {
      StudentVaccinationStatus.received => ('Received', AppColors.green),
      StudentVaccinationStatus.pending => ('Pending', AppColors.amber),
      StudentVaccinationStatus.notReceived => ('Not received', AppColors.red),
    };
    final details = <String>[
      if (vaccination.required) 'Required',
      if (vaccination.receivedOn != null)
        'Received ${_formatDate(vaccination.receivedOn!)}',
      if (vaccination.notes.isNotEmpty) vaccination.notes,
    ].join(' · ');
    return _DetailListRow(
      title: vaccination.name,
      subtitle: details,
      trailing: label,
      color: color,
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.student});

  final EnrolledStudent student;

  @override
  Widget build(BuildContext context) {
    final present = student.attendance
        .where((item) => item.status == 'Present')
        .length;
    final absent = student.attendance.length - present;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                label: 'Attendance rate',
                value: '${student.attendanceRate.toStringAsFixed(1)}%',
                color: AppColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniMetric(
                label: 'Present days shown',
                value: '$present',
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniMetric(
                label: 'Absent days shown',
                value: '$absent',
                color: AppColors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Recent attendance',
          icon: Icons.fact_check_outlined,
          child: Column(
            children: student.attendance
                .map(
                  (entry) => _DetailListRow(
                    title: _formatDate(entry.date),
                    subtitle: entry.note,
                    trailing: entry.status,
                    color: entry.status == 'Present'
                        ? AppColors.green
                        : AppColors.red,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FeesTab extends StatefulWidget {
  const _FeesTab({
    required this.student,
    required this.term,
    required this.academicYear,
  });

  final EnrolledStudent student;
  final String term;
  final String academicYear;

  @override
  State<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<_FeesTab> {
  static const _overallFeeAccount = 'Overall fee account';

  late List<StudentFeeAdjustment> _adjustments;

  EnrolledStudent get student => widget.student;

  @override
  void initState() {
    super.initState();
    _adjustments = [...student.feeAdjustments];
  }

  double get _originalFees =>
      student.fees.fold(0, (sum, fee) => sum + fee.amount);

  double get _paid =>
      student.payments.fold(0, (sum, payment) => sum + payment.amount);

  double get _approvedDiscounts => _adjustments
      .where(
        (item) =>
            item.affectsBalance &&
            item.type == StudentFeeAdjustmentType.discount,
      )
      .fold(0, (sum, item) => sum + item.amount.abs());

  double get _approvedSurcharges => _adjustments
      .where(
        (item) =>
            item.affectsBalance &&
            item.type == StudentFeeAdjustmentType.surcharge,
      )
      .fold(0, (sum, item) => sum + item.amount.abs());

  double get _adjustedFees =>
      _originalFees - _approvedDiscounts + _approvedSurcharges;

  double get _balance => (_adjustedFees - _paid).clamp(0, double.infinity);

  Future<void> _openAdjustmentForm([StudentFeeAdjustment? existing]) async {
    final adjustment = await showGeneralDialog<StudentFeeAdjustment>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close fee adjustment form',
      barrierColor: Colors.black.withValues(alpha: .44),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: _FeeAdjustmentSheet(
          student: student,
          term: widget.term,
          academicYear: widget.academicYear,
          currentAdjustments: _adjustments,
          initialAdjustment: existing,
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
    if (adjustment == null || !mounted) return;
    setState(() {
      if (existing == null) {
        _adjustments.insert(0, adjustment);
      } else {
        final index = _adjustments.indexWhere((item) => item.id == existing.id);
        if (index >= 0) _adjustments[index] = adjustment;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (adjustment.status) {
          StudentFeeAdjustmentStatus.draft => 'Fee adjustment draft saved.',
          StudentFeeAdjustmentStatus.pending =>
            'Fee adjustment submitted for approval.',
          _ => 'Fee adjustment applied.',
        }),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Future<void> _openReversalForm(StudentFeeAdjustment original) async {
    final reversal = await showGeneralDialog<StudentFeeAdjustment>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Close reversal form',
      barrierColor: Colors.black.withValues(alpha: .44),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: _FeeAdjustmentSheet(
          student: student,
          term: widget.term,
          academicYear: widget.academicYear,
          currentAdjustments: _adjustments,
          reversingAdjustment: original,
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset =
            Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        return SlideTransition(position: offset, child: child);
      },
    );
    if (reversal == null || !mounted) return;
    setState(() {
      final index = _adjustments.indexWhere((item) => item.id == original.id);
      if (index >= 0) {
        _adjustments[index] = original.copyWith(
          status: StudentFeeAdjustmentStatus.reversed,
        );
      }
      _adjustments.insert(0, reversal);
    });
    _showAdjustmentMessage('Adjustment reversed with an audit entry.');
  }

  Future<void> _handleAdjustmentAction(
    StudentFeeAdjustment adjustment,
    _StudentAdjustmentAction action,
  ) async {
    if (action == _StudentAdjustmentAction.edit) {
      await _openAdjustmentForm(adjustment);
      return;
    }
    if (action == _StudentAdjustmentAction.delete) {
      final confirmed = await _confirmAdjustmentAction(
        title: 'Delete adjustment?',
        message: 'This permanently removes the unapproved adjustment.',
        actionLabel: 'Delete',
      );
      if (!confirmed || !mounted) return;
      setState(
        () => _adjustments.removeWhere((item) => item.id == adjustment.id),
      );
      _showAdjustmentMessage('Adjustment deleted.');
      return;
    }
    if (action == _StudentAdjustmentAction.reverse) {
      await _openReversalForm(adjustment);
      return;
    }
    if (action == _StudentAdjustmentAction.duplicate) {
      setState(() {
        _adjustments.insert(
          0,
          adjustment.copyWith(
            id: 'ADJ-${DateTime.now().millisecondsSinceEpoch}',
            status: StudentFeeAdjustmentStatus.draft,
            createdOn: DateTime.now(),
            createdBy: 'Current administrator',
          ),
        );
      });
      _showAdjustmentMessage('A draft copy was created for revision.');
      return;
    }

    final status = switch (action) {
      _StudentAdjustmentAction.submit ||
      _StudentAdjustmentAction.resubmit => StudentFeeAdjustmentStatus.pending,
      _StudentAdjustmentAction.withdraw => StudentFeeAdjustmentStatus.draft,
      _ => adjustment.status,
    };
    setState(() {
      final index = _adjustments.indexWhere((item) => item.id == adjustment.id);
      if (index >= 0) {
        _adjustments[index] = adjustment.copyWith(status: status);
      }
    });
    _showAdjustmentMessage(
      action == _StudentAdjustmentAction.withdraw
          ? 'Adjustment withdrawn to draft.'
          : 'Adjustment submitted for approval.',
    );
  }

  Future<bool> _confirmAdjustmentAction({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showAdjustmentMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _adjustments
        .where((item) => item.status == StudentFeeAdjustmentStatus.pending)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 5
                : constraints.maxWidth >= 620
                ? 3
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _FeeMetric(
                  width: width,
                  label: 'Original fees',
                  value: _money(_originalFees),
                  color: AppColors.text,
                ),
                _FeeMetric(
                  width: width,
                  label: 'Net adjustments',
                  value: _signedMoney(_approvedSurcharges - _approvedDiscounts),
                  color: AppColors.purple,
                ),
                _FeeMetric(
                  width: width,
                  label: 'Adjusted fees',
                  value: _money(_adjustedFees),
                  color: AppColors.blue,
                ),
                _FeeMetric(
                  width: width,
                  label: 'Paid',
                  value: _money(_paid),
                  color: AppColors.green,
                ),
                _FeeMetric(
                  width: width,
                  label: 'Balance',
                  value: _money(_balance),
                  color: _balance == 0 ? AppColors.green : AppColors.red,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _FeeStatementCard(
          student: student,
          adjustments: _adjustments,
          onAdjust: _openAdjustmentForm,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title:
              'Adjustment history${pending == 0 ? '' : ' · $pending pending'}',
          icon: Icons.tune_rounded,
          child: _adjustments.isEmpty
              ? const _EmptyFeeState(
                  title: 'No fee adjustments',
                  description:
                      'Discounts and surcharges for this student will appear here.',
                )
              : Column(
                  children: _adjustments
                      .map(
                        (item) => _AdjustmentHistoryRow(
                          adjustment: item,
                          onAction: (action) =>
                              _handleAdjustmentAction(item, action),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Financial activity',
          icon: Icons.account_balance_wallet_outlined,
          child: _FinancialLedger(student: student, adjustments: _adjustments),
        ),
      ],
    );
  }
}

class _FeeMetric extends StatelessWidget {
  const _FeeMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeeStatementCard extends StatelessWidget {
  const _FeeStatementCard({
    required this.student,
    required this.adjustments,
    required this.onAdjust,
  });

  final EnrolledStudent student;
  final List<StudentFeeAdjustment> adjustments;
  final VoidCallback onAdjust;

  List<StudentFeeAdjustment> get _approvedAdjustments =>
      adjustments.where((item) => item.affectsBalance).toList(growable: false);

  double get _originalTotal =>
      student.fees.fold(0, (sum, fee) => sum + fee.amount);

  double get _netAdjustment =>
      _approvedAdjustments.fold(0, (sum, item) => sum + item.signedAmount);

  double get _totalFees => _originalTotal + _netAdjustment;

  double get _paid =>
      student.payments.fold(0, (sum, payment) => sum + payment.amount);

  double get _balance => (_totalFees - _paid).clamp(0, double.infinity);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.green,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fee statement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Original fee items and approved adjustments for this term.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  key: const Key('create-fee-adjustment'),
                  onPressed: onAdjust,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Create adjustment'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StatementSectionLabel('Original fee items'),
                const SizedBox(height: 6),
                ...student.fees.map(
                  (fee) => _StatementLine(
                    title: fee.name,
                    amount: _money(fee.amount),
                  ),
                ),
                const SizedBox(height: 18),
                const _StatementSectionLabel('Approved adjustments'),
                const SizedBox(height: 6),
                if (_approvedAdjustments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'No approved adjustments.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  ..._approvedAdjustments.map(
                    (item) => _StatementLine(
                      title:
                          '${item.type == StudentFeeAdjustmentType.discount ? 'Discount' : 'Surcharge'} · ${item.feeName}',
                      subtitle: item.description,
                      amount: _statementAdjustmentMoney(item),
                      amountColor:
                          item.type == StudentFeeAdjustmentType.discount
                          ? AppColors.green
                          : AppColors.red,
                      adjustment: true,
                    ),
                  ),
                const Divider(height: 34),
                _StatementTotalLine(
                  label: 'Original fees',
                  value: _money(_originalTotal),
                ),
                _StatementTotalLine(
                  label: 'Net adjustments',
                  value: _statementSignedMoney(_netAdjustment),
                  valueColor: _netAdjustment <= 0
                      ? AppColors.green
                      : AppColors.red,
                ),
                _StatementTotalLine(
                  label: 'Total fees',
                  value: _money(_totalFees),
                  emphasized: true,
                ),
                const Divider(height: 24),
                _StatementTotalLine(
                  label: 'Amount paid',
                  value: _money(_paid),
                  valueColor: AppColors.green,
                ),
                _StatementTotalLine(
                  label: 'Balance due',
                  value: _money(_balance),
                  valueColor: _balance == 0 ? AppColors.green : AppColors.red,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementSectionLabel extends StatelessWidget {
  const _StatementSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      ),
    );
  }
}

class _StatementLine extends StatelessWidget {
  const _StatementLine({
    required this.title,
    required this.amount,
    this.subtitle,
    this.amountColor = AppColors.text,
    this.adjustment = false,
  });

  final String title;
  final String amount;
  final String? subtitle;
  final Color amountColor;
  final bool adjustment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(adjustment ? 14 : 0, 11, 0, 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (adjustment) ...[
            Container(
              width: 3,
              height: subtitle == null ? 20 : 36,
              decoration: BoxDecoration(
                color: amountColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            amount,
            style: TextStyle(color: amountColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StatementTotalLine extends StatelessWidget {
  const _StatementTotalLine({
    required this.label,
    required this.value,
    this.valueColor = AppColors.text,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              emphasized ? label.toUpperCase() : label,
              style: TextStyle(
                fontSize: emphasized ? 15 : 14,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: emphasized ? 17 : 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

enum _StudentAdjustmentAction {
  edit,
  delete,
  submit,
  withdraw,
  resubmit,
  reverse,
  duplicate,
}

class _AdjustmentHistoryRow extends StatelessWidget {
  const _AdjustmentHistoryRow({
    required this.adjustment,
    required this.onAction,
  });

  final StudentFeeAdjustment adjustment;
  final ValueChanged<_StudentAdjustmentAction> onAction;

  List<_StudentAdjustmentAction> get _actions => switch (adjustment.status) {
    StudentFeeAdjustmentStatus.draft => const [
      _StudentAdjustmentAction.edit,
      _StudentAdjustmentAction.submit,
      _StudentAdjustmentAction.delete,
    ],
    StudentFeeAdjustmentStatus.pending => const [
      _StudentAdjustmentAction.edit,
      _StudentAdjustmentAction.withdraw,
      _StudentAdjustmentAction.delete,
    ],
    StudentFeeAdjustmentStatus.changesRequested => const [
      _StudentAdjustmentAction.edit,
      _StudentAdjustmentAction.resubmit,
      _StudentAdjustmentAction.delete,
    ],
    StudentFeeAdjustmentStatus.approved => const [
      _StudentAdjustmentAction.reverse,
    ],
    StudentFeeAdjustmentStatus.rejected => const [
      _StudentAdjustmentAction.duplicate,
    ],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) {
    final color = _adjustmentStatusColor(adjustment.status);
    final discount = adjustment.type == StudentFeeAdjustmentType.discount;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (discount ? AppColors.green : AppColors.red).withValues(
                alpha: .1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              discount ? Icons.remove_rounded : Icons.add_rounded,
              color: discount ? AppColors.green : AppColors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${adjustment.feeName} · ${discount ? 'Discount' : 'Surcharge'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  adjustment.description,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(adjustment.createdOn)} · ${adjustment.createdBy} · ${adjustment.id}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _signedMoney(adjustment.signedAmount),
                style: TextStyle(
                  color: discount ? AppColors.green : AppColors.red,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              _SmallPill(
                label: _adjustmentStatusLabel(adjustment.status),
                color: color,
              ),
            ],
          ),
          if (_actions.isNotEmpty) ...[
            const SizedBox(width: 5),
            PopupMenuButton<_StudentAdjustmentAction>(
              key: Key('adjustment-menu-${adjustment.id}'),
              tooltip: 'Adjustment actions',
              onSelected: onAction,
              itemBuilder: (context) => _actions
                  .map(
                    (action) => PopupMenuItem(
                      value: action,
                      child: Text(_studentAdjustmentActionLabel(action)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialLedger extends StatelessWidget {
  const _FinancialLedger({required this.student, required this.adjustments});

  final EnrolledStudent student;
  final List<StudentFeeAdjustment> adjustments;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...student.fees.map(
          (fee) => _LedgerRow(
            title: fee.name,
            subtitle: 'Term fee assigned',
            type: 'Charge',
            debit: fee.amount,
          ),
        ),
        ...adjustments.map(
          (item) => _LedgerRow(
            title: item.description,
            subtitle:
                '${item.feeName} · ${_formatDate(item.createdOn)} · ${_adjustmentStatusLabel(item.status)}',
            type: item.type == StudentFeeAdjustmentType.discount
                ? 'Discount'
                : 'Surcharge',
            debit: item.type == StudentFeeAdjustmentType.surcharge
                ? item.amount
                : null,
            credit: item.type == StudentFeeAdjustmentType.discount
                ? item.amount
                : null,
            muted: !item.affectsBalance,
          ),
        ),
        ...student.payments.map(
          (payment) => _LedgerRow(
            title: '${payment.method} payment',
            subtitle: '${_formatDate(payment.date)} · ${payment.receiptNumber}',
            type: 'Payment',
            credit: payment.amount,
          ),
        ),
      ],
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.subtitle,
    required this.type,
    this.debit,
    this.credit,
    this.muted = false,
  });

  final String title;
  final String subtitle;
  final String type;
  final double? debit;
  final double? credit;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: muted ? .58 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 94,
              child: _SmallPill(
                label: muted ? '$type · Pending' : type,
                color: muted ? AppColors.amber : AppColors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
            if (debit != null)
              SizedBox(
                width: 115,
                child: Text(
                  '+ ${_money(debit!)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (credit != null)
              SizedBox(
                width: 115,
                child: Text(
                  '- ${_money(credit!)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFeeState extends StatelessWidget {
  const _EmptyFeeState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          const Icon(Icons.tune_rounded, color: AppColors.muted, size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _FeeAdjustmentSheet extends StatefulWidget {
  const _FeeAdjustmentSheet({
    required this.student,
    required this.term,
    required this.academicYear,
    required this.currentAdjustments,
    this.initialAdjustment,
    this.reversingAdjustment,
  });

  final EnrolledStudent student;
  final String term;
  final String academicYear;
  final List<StudentFeeAdjustment> currentAdjustments;
  final StudentFeeAdjustment? initialAdjustment;
  final StudentFeeAdjustment? reversingAdjustment;

  @override
  State<_FeeAdjustmentSheet> createState() => _FeeAdjustmentSheetState();
}

class _FeeAdjustmentSheetState extends State<_FeeAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _feeName;
  StudentFeeAdjustmentType _type = StudentFeeAdjustmentType.discount;
  StudentFeeAdjustmentStatus _status = StudentFeeAdjustmentStatus.pending;

  @override
  void initState() {
    super.initState();
    final reversing = widget.reversingAdjustment;
    if (reversing != null) {
      _feeName = reversing.feeName;
      _type = reversing.type == StudentFeeAdjustmentType.discount
          ? StudentFeeAdjustmentType.surcharge
          : StudentFeeAdjustmentType.discount;
      _status = StudentFeeAdjustmentStatus.complete;
      _amountController.text = reversing.amount.toStringAsFixed(
        reversing.amount % 1 == 0 ? 0 : 2,
      );
      _reasonController.text = 'Reversal of ${reversing.id}: ';
      return;
    }
    final initial = widget.initialAdjustment;
    if (initial == null) return;
    _feeName = initial.feeName;
    _type = initial.type;
    _status = initial.status == StudentFeeAdjustmentStatus.changesRequested
        ? StudentFeeAdjustmentStatus.draft
        : initial.status;
    _amountController.text = initial.amount.toStringAsFixed(
      initial.amount % 1 == 0 ? 0 : 2,
    );
    _reasonController.text = initial.description;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double _maximumDiscountFor(String feeName) {
    final overall = feeName == _FeesTabState._overallFeeAccount;
    final original = overall
        ? widget.student.fees.fold<double>(0, (sum, fee) => sum + fee.amount)
        : widget.student.fees
              .where((fee) => fee.name == feeName)
              .fold<double>(0, (sum, fee) => sum + fee.amount);
    final existingAdjustments = widget.currentAdjustments
        .where(
          (item) => item.affectsBalance && (overall || item.feeName == feeName),
        )
        .fold<double>(0, (sum, item) => sum + item.signedAmount);
    return (original + existingAdjustments).clamp(0, double.infinity);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amountController.text.trim());
    Navigator.of(context).pop(
      StudentFeeAdjustment(
        id: widget.reversingAdjustment != null
            ? 'REV-${DateTime.now().millisecondsSinceEpoch}'
            : widget.initialAdjustment?.id ??
                  'ADJ-${DateTime.now().millisecondsSinceEpoch}',
        feeName: _feeName!,
        type: _type,
        amount: amount,
        description: _reasonController.text.trim(),
        status: _status,
        createdOn: widget.reversingAdjustment != null
            ? DateTime.now()
            : widget.initialAdjustment?.createdOn ?? DateTime.now(),
        createdBy: widget.reversingAdjustment != null
            ? 'Current administrator'
            : widget.initialAdjustment?.createdBy ?? 'Current administrator',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reversing = widget.reversingAdjustment != null;
    final actionLabel = reversing
        ? 'Record reversal'
        : switch (_status) {
            StudentFeeAdjustmentStatus.pending => 'Submit for approval',
            _ => 'Save adjustment',
          };
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: SizedBox(
          width: 500,
          height: double.infinity,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reversing
                                ? 'Reverse fee adjustment'
                                : widget.initialAdjustment == null
                                ? 'Create fee adjustment'
                                : 'Edit fee adjustment',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            reversing
                                ? 'Create an equal opposite entry while preserving the original record.'
                                : 'Apply a one-off discount or surcharge.',
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
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReadOnlyAdjustmentContext(
                          label: 'Student',
                          value:
                              '${widget.student.name} · ${widget.student.id}',
                        ),
                        const SizedBox(height: 10),
                        _ReadOnlyAdjustmentContext(
                          label: 'Academic period',
                          value: '${widget.term} · ${widget.academicYear}',
                        ),
                        if (reversing) ...[
                          const SizedBox(height: 10),
                          _ReadOnlyAdjustmentContext(
                            key: const Key('reversing-adjustment-context'),
                            label: 'Reversing adjustment',
                            value:
                                '${widget.reversingAdjustment!.id} · ${widget.reversingAdjustment!.description}',
                          ),
                        ],
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          key: const Key('adjustment-fee-item'),
                          value: _feeName,
                          decoration: const InputDecoration(
                            labelText: 'Fee item *',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: _FeesTabState._overallFeeAccount,
                              child: Text('Overall fee account'),
                            ),
                            ...widget.student.fees.map(
                              (fee) => DropdownMenuItem(
                                value: fee.name,
                                child: Text(
                                  '${fee.name} · ${_money(fee.amount)}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: reversing
                              ? null
                              : (value) => setState(() => _feeName = value),
                          validator: (value) => value == null
                              ? 'Select the fee item to adjust'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'ADJUSTMENT TYPE',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AdjustmentTypeButton(
                                label: 'Discount',
                                caption: 'Reduces the fee',
                                icon: Icons.remove_circle_outline_rounded,
                                selected:
                                    _type == StudentFeeAdjustmentType.discount,
                                color: AppColors.green,
                                onTap: reversing
                                    ? null
                                    : () => setState(
                                        () => _type =
                                            StudentFeeAdjustmentType.discount,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _AdjustmentTypeButton(
                                label: 'Surcharge',
                                caption: 'Increases the fee',
                                icon: Icons.add_circle_outline_rounded,
                                selected:
                                    _type == StudentFeeAdjustmentType.surcharge,
                                color: AppColors.red,
                                onTap: reversing
                                    ? null
                                    : () => setState(
                                        () => _type =
                                            StudentFeeAdjustmentType.surcharge,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const Key('adjustment-amount'),
                          controller: _amountController,
                          readOnly: reversing,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (GH\u20b5) *',
                            prefixText: 'GH\u20b5 ',
                            helperText:
                                'Enter a positive amount. The adjustment type controls the sign.',
                          ),
                          validator: (value) {
                            final amount = double.tryParse(value?.trim() ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter an amount greater than zero';
                            }
                            if (_type == StudentFeeAdjustmentType.discount &&
                                _feeName != null) {
                              final maximum = _maximumDiscountFor(_feeName!);
                              if (amount > maximum) {
                                return 'Discount cannot exceed ${_money(maximum)}';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const Key('adjustment-reason'),
                          controller: _reasonController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Reason *',
                            hintText:
                                'Explain why this adjustment is being made',
                          ),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Enter a reason for the adjustment'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        if (!reversing)
                          DropdownButtonFormField<StudentFeeAdjustmentStatus>(
                            key: const Key('adjustment-processing'),
                            value: _status,
                            decoration: const InputDecoration(
                              labelText: 'Processing option *',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: StudentFeeAdjustmentStatus.draft,
                                child: Text('Save as draft'),
                              ),
                              DropdownMenuItem(
                                value: StudentFeeAdjustmentStatus.pending,
                                child: Text('Submit for approval'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _status = value!),
                          ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.blue,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  reversing
                                      ? 'The original adjustment remains in history. This equal opposite entry restores its financial effect.'
                                      : _status ==
                                            StudentFeeAdjustmentStatus.pending
                                      ? 'Pending adjustments are visible in history but do not change the official balance.'
                                      : 'Draft adjustments do not change the student\'s official fee balance.',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('save-fee-adjustment'),
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(actionLabel),
                      ),
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
}

class _ReadOnlyAdjustmentContext extends StatelessWidget {
  const _ReadOnlyAdjustmentContext({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _AdjustmentTypeButton extends StatelessWidget {
  const _AdjustmentTypeButton({
    required this.label,
    required this.caption,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : AppColors.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    style: const TextStyle(
                      color: AppColors.muted,
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
}

class _RequirementsTab extends StatelessWidget {
  const _RequirementsTab({required this.student});

  final EnrolledStudent student;

  @override
  Widget build(BuildContext context) {
    final progress = student.requirementsTotal == 0
        ? 0.0
        : student.requirementsCompleted / student.requirementsTotal;
    return _SectionCard(
      title: 'Items & supplies progress',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: AppColors.border,
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${student.requirementsCompleted}/${student.requirementsTotal} complete',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...student.requirements.map((item) {
            final color = switch (item.status) {
              StudentRequirementStatus.complete => AppColors.green,
              StudentRequirementStatus.partial => AppColors.amber,
              StudentRequirementStatus.outstanding => AppColors.red,
              StudentRequirementStatus.waived => AppColors.blue,
            };
            final quantity =
                '${item.receivedQuantity} of ${item.requiredQuantity} ${item.unit} received';
            final source = item.isFromPreviousTerm && item.sourceTerm.isNotEmpty
                ? 'From ${item.sourceTerm} · '
                : '';
            return _DetailListRow(
              title: item.name,
              subtitle:
                  '$source$quantity${item.note.isEmpty ? '' : ' · ${item.note}'}',
              trailing: _requirementStatusLabel(item.status),
              color: color,
              badge: item.isFromPreviousTerm ? 'Previous term' : null,
              badgeColor: AppColors.amber,
            );
          }),
        ],
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.student});

  final EnrolledStudent student;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Student documents',
      icon: Icons.folder_copy_outlined,
      child: Column(
        children: student.documents
            .map(
              (document) => _DetailListRow(
                title: document.name,
                subtitle:
                    '${document.fileName} · Updated ${_formatDate(document.updatedOn)}',
                trailing: document.status,
                color: AppColors.green,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.green),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.values});

  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 18)) / columns;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: values.entries
              .map(
                (entry) => SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
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
      ),
    );
  }
}

class _DetailListRow extends StatelessWidget {
  const _DetailListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.color,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color color;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      _SmallPill(
                        label: badge!,
                        color: badgeColor ?? AppColors.amber,
                      ),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentsLoadingView extends StatelessWidget {
  const _StudentsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _StudentProfileLoadingView extends StatelessWidget {
  const _StudentProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text(
            'Loading the student profile...',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StudentProfileErrorView extends StatelessWidget {
  const _StudentProfileErrorView({required this.onBack, required this.onRetry});

  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load this student profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: onBack,
                    child: const Text('Back to students'),
                  ),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
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

class _StudentsErrorView extends StatelessWidget {
  const _StudentsErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: AppColors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Unable to load enrolled students',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _statusLabel(EnrolledStudentStatus status) => switch (status) {
  EnrolledStudentStatus.active => 'Active',
  EnrolledStudentStatus.inactive => 'Inactive',
  EnrolledStudentStatus.transferred => 'Transferred',
};

String _requirementStatusLabel(StudentRequirementStatus status) =>
    switch (status) {
      StudentRequirementStatus.complete => 'Complete',
      StudentRequirementStatus.partial => 'Partial',
      StudentRequirementStatus.outstanding => 'Outstanding',
      StudentRequirementStatus.waived => 'Waived',
    };

String _formatDate(DateTime? value) {
  if (value == null) return 'Not provided';
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
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _money(double value) => 'GH\u20b5 ${value.abs().toStringAsFixed(0)}';

String _signedMoney(double value) {
  if (value == 0) return _money(0);
  return '${value < 0 ? '-' : '+'}${_money(value)}';
}

String _statementSignedMoney(double value) {
  if (value == 0) return _money(0);
  return value < 0 ? '(${_money(value)})' : _money(value);
}

String _statementAdjustmentMoney(StudentFeeAdjustment adjustment) {
  return adjustment.type == StudentFeeAdjustmentType.discount
      ? '(${_money(adjustment.amount)})'
      : _money(adjustment.amount);
}

String _adjustmentStatusLabel(StudentFeeAdjustmentStatus status) =>
    switch (status) {
      StudentFeeAdjustmentStatus.draft => 'Draft',
      StudentFeeAdjustmentStatus.pending => 'Pending',
      StudentFeeAdjustmentStatus.changesRequested => 'Changes requested',
      StudentFeeAdjustmentStatus.approved => 'Approved',
      StudentFeeAdjustmentStatus.complete => 'Complete',
      StudentFeeAdjustmentStatus.rejected => 'Rejected',
      StudentFeeAdjustmentStatus.reversed => 'Reversed',
      StudentFeeAdjustmentStatus.cancelled => 'Cancelled',
    };

Color _adjustmentStatusColor(StudentFeeAdjustmentStatus status) =>
    switch (status) {
      StudentFeeAdjustmentStatus.draft => AppColors.muted,
      StudentFeeAdjustmentStatus.pending => AppColors.amber,
      StudentFeeAdjustmentStatus.changesRequested => AppColors.purple,
      StudentFeeAdjustmentStatus.approved => AppColors.blue,
      StudentFeeAdjustmentStatus.complete => AppColors.green,
      StudentFeeAdjustmentStatus.rejected => AppColors.red,
      StudentFeeAdjustmentStatus.reversed => AppColors.red,
      StudentFeeAdjustmentStatus.cancelled => AppColors.muted,
    };

String _studentAdjustmentActionLabel(_StudentAdjustmentAction action) =>
    switch (action) {
      _StudentAdjustmentAction.edit => 'Edit',
      _StudentAdjustmentAction.delete => 'Delete',
      _StudentAdjustmentAction.submit => 'Submit for approval',
      _StudentAdjustmentAction.withdraw => 'Move to draft',
      _StudentAdjustmentAction.resubmit => 'Resubmit for approval',
      _StudentAdjustmentAction.reverse => 'Reverse adjustment',
      _StudentAdjustmentAction.duplicate => 'Duplicate and revise',
    };
