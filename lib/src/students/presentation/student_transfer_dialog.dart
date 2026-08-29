import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../domain/student_models.dart';

class StudentTransferDialog extends StatefulWidget {
  const StudentTransferDialog({
    super.key,
    required this.student,
    required this.repository,
    this.actorUserId,
  });
  final EnrolledStudent student;
  final StudentsRepository repository;
  final int? actorUserId;
  @override
  State<StudentTransferDialog> createState() => _StudentTransferDialogState();
}

class _StudentTransferDialogState extends State<StudentTransferDialog> {
  late Future<
    (
      StudentPlacement,
      List<StudentTransferDestination>,
      List<StudentTransferApprover>,
    )
  >
  future;
  StudentPlacement? source;
  List<StudentTransferDestination> destinations = [];
  StudentTransferDestination? destination;
  List<StudentTransferApprover> approvers = [];
  StudentTransferApprover? approver;
  DateTime? date;
  final reason = TextEditingController();
  StudentTransferPreview? preview;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<
    (
      StudentPlacement,
      List<StudentTransferDestination>,
      List<StudentTransferApprover>,
    )
  >
  _load() async {
    final values = await Future.wait([
      widget.repository.getCurrentPlacement(widget.student.id),
      widget.repository.getTransferDestinations(widget.student.id),
      widget.repository.getTransferApprovers(widget.student.id),
    ]);
    source = values[0] as StudentPlacement;
    destinations = values[1] as List<StudentTransferDestination>;
    approvers = values[2] as List<StudentTransferApprover>;
    date = null;
    return (source!, destinations, approvers);
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  List<StudentTransferDestination> get available {
    final choices = destinations
        .where((d) => d.streamId != source!.streamId)
        .toList();
    choices.sort((a, b) {
      final aSameGrade = a.gradeLevelId == source!.gradeLevelId;
      final bSameGrade = b.gradeLevelId == source!.gradeLevelId;
      if (aSameGrade != bSameGrade) return aSameGrade ? -1 : 1;
      return a.label.compareTo(b.label);
    });
    return choices;
  }

  StudentTransferType _transferTypeFor(StudentTransferDestination selected) =>
      selected.gradeLevelId == source!.gradeLevelId
      ? StudentTransferType.sameGradeDifferentStream
      : StudentTransferType.differentGrade;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _earliestSelectableDate {
    final termStart = source!.termStart ?? source!.effectiveFrom;
    return termStart.isAfter(source!.effectiveFrom)
        ? termStart
        : source!.effectiveFrom;
  }

  DateTime get _latestSelectableDate {
    final termEnd = source!.termEnd ?? _today;
    return termEnd.isBefore(_today) ? termEnd : _today;
  }

  bool get _hasSelectableDates =>
      !_earliestSelectableDate.isAfter(_latestSelectableDate);

  Future<void> pickDate() async {
    if (!_hasSelectableDates) {
      setState(() {
        error =
            'Class changes can be dated from '
            '${_date(_earliestSelectableDate)}, when this term begins.';
      });
      return;
    }
    final start = _earliestSelectableDate;
    final last = _latestSelectableDate;
    final current = date;
    final initial = current == null || current.isBefore(start)
        ? start
        : current.isAfter(last)
        ? last
        : current;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: last,
      helpText: 'SELECT EFFECTIVE DATE',
      fieldLabelText: 'Effective date',
    );
    if (selected != null) {
      setState(() {
        date = selected;
        error = null;
      });
    }
  }

  Future<void> review() async {
    if (destination == null) {
      setState(() => error = 'Select a destination class.');
      return;
    }
    if (reason.text.trim().length < 3) {
      setState(() => error = 'Enter a reason for this transfer.');
      return;
    }
    if (_transferTypeFor(destination!) == StudentTransferType.differentGrade &&
        approver == null) {
      setState(() => error = 'Select who should approve this grade change.');
      return;
    }
    if (date == null) {
      setState(() {
        error = _hasSelectableDates
            ? 'Select an effective date.'
            : 'This term has not started. Class changes can be dated from '
                  '${_date(_earliestSelectableDate)}.';
      });
      return;
    }
    setState(() => busy = true);
    try {
      final p = await widget.repository.previewTransfer(
        widget.student.id,
        StudentTransferInput(
          type: _transferTypeFor(destination!),
          destinationGradeLevelId: destination!.gradeLevelId,
          destinationStreamId: destination!.streamId,
          effectiveDate: date!,
          reason: reason.text,
          actorUserId: widget.actorUserId,
          approverId: approver?.id,
        ),
      );
      if (mounted) {
        setState(() {
          preview = p;
          busy = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
        });
      }
    }
  }

  Future<void> confirm() async {
    setState(() => busy = true);
    try {
      final p = preview!;
      final outcome = await widget.repository.confirmTransfer(
        widget.student.id,
        StudentTransferInput(
          type: _transferTypeFor(p.destination),
          destinationGradeLevelId: p.destination.gradeLevelId,
          destinationStreamId: p.destination.streamId,
          effectiveDate: p.effectiveDate,
          reason: p.reason,
          previewToken: p.previewToken,
          actorUserId: widget.actorUserId,
          approverId: approver?.id,
        ),
      );
      if (mounted) {
        Navigator.pop(context, outcome);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650, maxHeight: 760),
      child:
          FutureBuilder<
            (
              StudentPlacement,
              List<StudentTransferDestination>,
              List<StudentTransferApprover>,
            )
          >(
            future: future,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (s.hasError) {
                return _message('Unable to prepare transfer', '$s.error');
              }
              return preview == null ? _form() : _review();
            },
          ),
    ),
  );
  Widget _header(String title, String subtitle) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        IconButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
  Widget _form() => Column(
    children: [
      _header(
        'Change class/grade',
        'Choose where and when this student should move',
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _studentSummary(),
              const SizedBox(height: 16),
              _fromToClasses(),
              if (destination != null &&
                  _transferTypeFor(destination!) ==
                      StudentTransferType.differentGrade) ...[
                const SizedBox(height: 16),
                _approverField(),
              ],
              const SizedBox(height: 16),
              InkWell(
                key: const Key('transfer-date'),
                borderRadius: BorderRadius.circular(12),
                onTap: _hasSelectableDates ? pickDate : null,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Effective date *',
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                    enabled: _hasSelectableDates,
                    helperText: _hasSelectableDates
                        ? 'Required'
                        : 'Available when the term begins on '
                              '${_date(_earliestSelectableDate)}.',
                    helperStyle: TextStyle(
                      color: _hasSelectableDates
                          ? AppColors.muted
                          : AppColors.red,
                    ),
                  ),
                  child: Text(
                    date == null ? 'Select date' : _date(date!),
                    style: TextStyle(
                      color: date == null || !_hasSelectableDates
                          ? AppColors.muted
                          : AppColors.text,
                      fontWeight: date == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('transfer-reason'),
                controller: reason,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reason *',
                  hintText: 'Why is this change required?',
                ),
              ),
              if (error != null) _error(error!),
            ],
          ),
        ),
      ),
      _actions(
        'Cancel',
        () => Navigator.pop(context),
        'Review transfer',
        review,
      ),
    ],
  );
  Widget _studentSummary() => Container(
    key: const Key('transfer-student-summary'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: 0.08),
      border: Border.all(color: AppColors.green.withValues(alpha: 0.22)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline, color: AppColors.green),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'STUDENT',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.student.name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _fromToClasses() => Container(
    key: const Key('transfer-from-to'),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FROM',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.school_outlined, size: 20, color: AppColors.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                source!.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 20,
                  color: AppColors.green,
                ),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        const Text(
          'TO',
          style: TextStyle(
            color: AppColors.green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<StudentTransferDestination>(
          key: const Key('transfer-destination'),
          value: destination,
          isExpanded: true,
          itemHeight: 64,
          decoration: const InputDecoration(
            labelText: 'Select destination class *',
            helperText: 'Blocked classes need active fees.',
          ),
          items: available
              .map(
                (d) => DropdownMenuItem(
                  value: d,
                  enabled: d.feeReady,
                  child: _destinationOption(d),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => available
              .map(
                (d) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    d.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() {
            destination = v;
            approver = null;
            error = null;
          }),
        ),
      ],
    ),
  );

  Widget _approverField() => DropdownButtonFormField<StudentTransferApprover>(
    key: const Key('transfer-approver'),
    value: approver,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: 'Approver *',
      helperText: 'A different administrator or headmaster must approve.',
      prefixIcon: Icon(Icons.verified_user_outlined),
    ),
    items: approvers
        .map(
          (item) => DropdownMenuItem(
            value: item,
            child: Text(item.label, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (value) => setState(() {
      approver = value;
      error = null;
    }),
  );

  Widget _destinationOption(StudentTransferDestination destination) {
    if (destination.feeReady) {
      return Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppColors.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              destination.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    return Container(
      key: Key('blocked-transfer-destination-${destination.streamId}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 18,
              color: Color(0xFF9A6200),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Fees are not active',
                  style: TextStyle(
                    color: Color(0xFF8A5A00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Blocked',
              style: TextStyle(
                color: Color(0xFF8A5A00),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _review() {
    final p = preview!;
    return Column(
      children: [
        _header(
          'Review transfer',
          p.gradeChanged
              ? 'Submit this grade change for approval'
              : 'Confirm the effective-dated stream change',
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _notice('Student', widget.student.name, Icons.person_outline),
                const SizedBox(height: 12),
                _notice(
                  'Placement',
                  '${p.source.label}\n↓\n${p.destination.label}',
                  Icons.swap_vert,
                ),
                const SizedBox(height: 12),
                _notice('Effective date', _date(p.effectiveDate), Icons.event),
                const SizedBox(height: 12),
                _notice('Reason', p.reason, Icons.notes),
                if (p.gradeChanged) ...[
                  const SizedBox(height: 12),
                  _notice(
                    'Approver',
                    approver?.label ?? 'Not selected',
                    Icons.verified_user_outlined,
                  ),
                ],
                const SizedBox(height: 12),
                _notice(
                  'Attendance',
                  p.attendanceMessage,
                  Icons.fact_check_outlined,
                ),
                const SizedBox(height: 12),
                _notice(
                  'Fee impact',
                  p.feeMessage,
                  Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Historical attendance, assessments, reports and payments will not be deleted or rewritten.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (p.gradeChanged) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'The student remains in the current class and fees remain unchanged until this request is approved.',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (error != null) _error(error!),
              ],
            ),
          ),
        ),
        _actions(
          'Back',
          () => setState(() => preview = null),
          p.gradeChanged ? 'Submit for approval' : 'Confirm transfer',
          confirm,
        ),
      ],
    );
  }

  Widget _actions(
    String left,
    VoidCallback back,
    String right,
    VoidCallback next,
  ) => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: busy ? null : back, child: Text(left)),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: busy ? null : next,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(right),
        ),
      ],
    ),
  );
  Widget _notice(String title, String value, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.green),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _error(String value) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      value,
      style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600),
    ),
  );
  Widget _message(String title, String value) => Padding(
    padding: const EdgeInsets.all(30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(value),
        const SizedBox(height: 18),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
