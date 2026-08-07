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
  late Future<(StudentPlacement, List<StudentTransferDestination>)> future;
  StudentPlacement? source;
  List<StudentTransferDestination> destinations = [];
  StudentTransferType type = StudentTransferType.sameGradeDifferentStream;
  StudentTransferDestination? destination;
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

  Future<(StudentPlacement, List<StudentTransferDestination>)> _load() async {
    final values = await Future.wait([
      widget.repository.getCurrentPlacement(widget.student.id),
      widget.repository.getTransferDestinations(widget.student.id),
    ]);
    source = values[0] as StudentPlacement;
    destinations = values[1] as List<StudentTransferDestination>;
    date = _hasSelectableDates ? _latestSelectableDate : null;
    return (source!, destinations);
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  List<StudentTransferDestination> get available => destinations
      .where(
        (d) => type == StudentTransferType.sameGradeDifferentStream
            ? d.gradeLevelId == source!.gradeLevelId &&
                  d.streamId != source!.streamId
            : d.gradeLevelId != source!.gradeLevelId,
      )
      .toList();

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
          type: type,
          destinationGradeLevelId: destination!.gradeLevelId,
          destinationStreamId: destination!.streamId,
          effectiveDate: date!,
          reason: reason.text,
          actorUserId: widget.actorUserId,
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
      await widget.repository.confirmTransfer(
        widget.student.id,
        StudentTransferInput(
          type: type,
          destinationGradeLevelId: p.destination.gradeLevelId,
          destinationStreamId: p.destination.streamId,
          effectiveDate: p.effectiveDate,
          reason: p.reason,
          previewToken: p.previewToken,
          actorUserId: widget.actorUserId,
        ),
      );
      if (mounted) {
        Navigator.pop(context, true);
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
          FutureBuilder<(StudentPlacement, List<StudentTransferDestination>)>(
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
        'Move ${widget.student.name} during the current term',
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _notice(
                'Current placement',
                source!.label,
                Icons.school_outlined,
              ),
              const SizedBox(height: 18),
              const Text(
                'Transfer type',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              RadioListTile(
                value: StudentTransferType.sameGradeDifferentStream,
                groupValue: type,
                title: const Text('Same grade, different stream'),
                onChanged: (v) => setState(() {
                  type = v!;
                  destination = null;
                  error = null;
                }),
              ),
              RadioListTile(
                value: StudentTransferType.differentGrade,
                groupValue: type,
                title: const Text('Different grade level'),
                onChanged: (v) => setState(() {
                  type = v!;
                  destination = null;
                  error = null;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<StudentTransferDestination>(
                key: const Key('transfer-destination'),
                value: destination,
                decoration: const InputDecoration(
                  labelText: 'Destination class *',
                ),
                items: available
                    .map(
                      (d) => DropdownMenuItem(value: d, child: Text(d.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => destination = v),
              ),
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
                        ? 'Click anywhere in this field to choose a date.'
                        : 'Available when the term begins on '
                              '${_date(_earliestSelectableDate)}.',
                    helperStyle: TextStyle(
                      color: _hasSelectableDates
                          ? AppColors.muted
                          : AppColors.red,
                    ),
                  ),
                  child: Text(
                    date == null ? 'No date available yet' : _date(date!),
                    style: TextStyle(
                      color: _hasSelectableDates
                          ? AppColors.text
                          : AppColors.muted,
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
  Widget _review() {
    final p = preview!;
    return Column(
      children: [
        _header(
          'Review transfer',
          'Confirm the effective-dated placement change',
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
                if (error != null) _error(error!),
              ],
            ),
          ),
        ),
        _actions(
          'Back',
          () => setState(() => preview = null),
          'Confirm transfer',
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
