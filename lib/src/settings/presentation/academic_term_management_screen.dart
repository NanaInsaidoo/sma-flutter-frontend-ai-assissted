import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_theme.dart';

Future<bool> showPreparedTermDateEditor({
  required BuildContext context,
  required String schoolId,
  required String? accessToken,
  Future<String?> Function()? onRefreshAccessToken,
}) async {
  final api = _AcademicTermManagementApi(
    accessToken: accessToken,
    onRefreshAccessToken: onRefreshAccessToken,
  );
  try {
    final terms = await api.terms(schoolId);
    if (!context.mounted) return false;
    final prepared = terms
        .where((term) => term.status == 'PREPARED' && !term.isCurrent)
        .firstOrNull;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreatePreparedTermDialog(
        schoolId: schoolId,
        api: api,
        existing: prepared,
      ),
    );
    return saved == true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open term dates: $error')),
      );
    }
    return false;
  }
}

Future<bool> showNextTermSetupEditor({
  required BuildContext context,
  required String schoolId,
  required int closedTermId,
  required String? accessToken,
  Future<String?> Function()? onRefreshAccessToken,
}) async {
  final api = _AcademicTermManagementApi(
    accessToken: accessToken,
    onRefreshAccessToken: onRefreshAccessToken,
  );
  try {
    final terms = await api.terms(schoolId);
    final closed = terms.where((term) => term.id == closedTermId).firstOrNull;
    if (closed == null || !closed.isCurrent || closed.status != 'CLOSED') {
      throw Exception(
        'Refresh Term Closure to continue with the current setup.',
      );
    }
    final operationalEnd = _jsonDate(closed.raw['endDate']);
    final boundary = operationalEnd.isAfter(closed.closingDate)
        ? operationalEnd
        : closed.closingDate;
    final prepared = terms.reversed
        .where(
          (term) =>
              term.status == 'PREPARED' &&
              !term.isCurrent &&
              term.operationalStart.isAfter(boundary),
        )
        .firstOrNull;
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _CreatePreparedTermDialog(
            schoolId: schoolId,
            api: api,
            existing: prepared,
            followsClosedTerm: closed,
            earliestStart: DateTime(
              boundary.year,
              boundary.month,
              boundary.day + 1,
            ),
          ),
        ) ==
        true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
    return false;
  }
}

Future<bool> showCurrentTermDateEditor({
  required BuildContext context,
  required String schoolId,
  required int termId,
  required String? accessToken,
  Future<String?> Function()? onRefreshAccessToken,
}) async {
  final api = _AcademicTermManagementApi(
    accessToken: accessToken,
    onRefreshAccessToken: onRefreshAccessToken,
  );
  try {
    final (term, limitDate, limitReason) = await api.currentTermDates(
      schoolId,
      termId,
    );
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _CurrentTermDatesDialog(
            schoolId: schoolId,
            term: term,
            limitDate: limitDate,
            limitReason: limitReason,
            api: api,
          ),
        ) ==
        true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
    return false;
  }
}

class AcademicTermManagementScreen extends StatefulWidget {
  const AcademicTermManagementScreen({
    super.key,
    required this.customSchoolId,
    required this.accessToken,
    required this.onBack,
    this.onRefreshAccessToken,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback onBack;

  @override
  State<AcademicTermManagementScreen> createState() =>
      _AcademicTermManagementScreenState();
}

class _AcademicTermManagementScreenState
    extends State<AcademicTermManagementScreen> {
  late final _AcademicTermManagementApi _api = _AcademicTermManagementApi(
    accessToken: widget.accessToken,
    onRefreshAccessToken: widget.onRefreshAccessToken,
  );
  late Future<List<_ManagedTerm>> _terms;

  @override
  void initState() {
    super.initState();
    _terms = _api.terms(widget.customSchoolId);
  }

  Future<void> _reload() async {
    setState(() => _terms = _api.terms(widget.customSchoolId));
    await _terms;
  }

  Future<void> _createTerm() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _CreatePreparedTermDialog(schoolId: widget.customSchoolId, api: _api),
    );
    if (created == true && mounted) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The next term has been prepared.'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to settings',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academic Term Settings',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Review the term history and prepare the next operational term before closing the current one.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _createTerm,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Prepare next term'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.blue.withValues(alpha: .25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The operational start is when the office may reopen and admissions for the next term can begin, even during vacation. Fee collection may also start then; teaching begins separately.',
                    style: TextStyle(color: AppColors.text, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FutureBuilder<List<_ManagedTerm>>(
            future: _terms,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return _TermError(message: '${snapshot.error}', retry: _reload);
              }
              final terms = snapshot.data ?? const <_ManagedTerm>[];
              if (terms.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: Text('No academic terms found.')),
                  ),
                );
              }
              return Column(
                children: terms
                    .map(
                      (term) => _TermCard(
                        term: term,
                        onEdit: term.status == 'PREPARED'
                            ? () => _editTerm(term)
                            : null,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editTerm(_ManagedTerm term) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreatePreparedTermDialog(
        schoolId: widget.customSchoolId,
        api: _api,
        existing: term,
      ),
    );
    if (updated == true && mounted) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The next-term dates have been updated.'),
          backgroundColor: AppColors.green,
        ),
      );
    }
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term, this.onEdit});

  final _ManagedTerm term;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final color = switch (term.status) {
      'CLOSED' => AppColors.muted,
      'PREPARED' => AppColors.amber,
      _ => AppColors.green,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_month_rounded, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${term.termName} · ${term.academicYear}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          term.isCurrent
                              ? 'CURRENT · ${term.status}'
                              : term.status,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      _DateSummary(
                        label: 'Office opens',
                        value: term.operationalStart,
                      ),
                      _DateSummary(
                        label: 'Teaching starts',
                        value: term.teachingStart,
                      ),
                      _DateSummary(
                        label: 'Teaching ends',
                        value: term.teachingEnd,
                      ),
                      _DateSummary(
                        label: 'Term closes',
                        value: term.closingDate,
                      ),
                    ],
                  ),
                  if (term.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      term.description,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                  if (onEdit != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text('Modify dates'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSummary extends StatelessWidget {
  const _DateSummary({required this.label, required this.value});

  final String label;
  final DateTime value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
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
          const SizedBox(height: 3),
          Text(
            _friendlyDate(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CurrentTermDatesDialog extends StatefulWidget {
  const _CurrentTermDatesDialog({
    required this.schoolId,
    required this.term,
    required this.limitDate,
    required this.limitReason,
    required this.api,
  });

  final String schoolId;
  final _ManagedTerm term;
  final DateTime limitDate;
  final String limitReason;
  final _AcademicTermManagementApi api;

  @override
  State<_CurrentTermDatesDialog> createState() =>
      _CurrentTermDatesDialogState();
}

class _CurrentTermDatesDialogState extends State<_CurrentTermDatesDialog> {
  late DateTime _teachingEnd = widget.term.teachingEnd;
  late DateTime _closingDate = widget.term.closingDate;
  bool _saving = false;
  String? _error;

  DateTime get _minimumClosingDate =>
      _teachingEnd.isAfter(widget.limitDate) ? _teachingEnd : widget.limitDate;

  String get _closingDateHelp {
    final reason = _teachingEnd.isAfter(widget.limitDate)
        ? 'The last teaching day'
        : widget.limitReason;
    return 'Choose ${_friendlyDate(_minimumClosingDate)} or later. '
        '$reason sets this limit.';
  }

  String? get _dateError {
    if (_closingDate.isBefore(_teachingEnd)) {
      return 'The earliest closing date must be on or after the last teaching day.';
    }
    if (_closingDate != widget.term.closingDate &&
        _closingDate.isBefore(widget.limitDate)) {
      return 'Select a new closing date within the allowed range.';
    }
    return null;
  }

  Future<void> _pickDate({required bool closing}) async {
    final initial = closing ? _closingDate : _teachingEnd;
    final firstDate = closing ? _minimumClosingDate : widget.term.teachingStart;
    final lastDate = DateTime(widget.term.closingDate.year + 1, 12, 31);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: firstDate.isAfter(lastDate) ? firstDate : lastDate,
    );
    if (!mounted || date == null) return;
    setState(() {
      _error = null;
      if (closing) {
        _closingDate = date;
      } else {
        _teachingEnd = date;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.saveCurrentTermDates(
        schoolId: widget.schoolId,
        termId: widget.term.id,
        teachingEnd: _teachingEnd,
        closingDate: _closingDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final changed =
        _teachingEnd != widget.term.teachingEnd ||
        _closingDate != widget.term.closingDate;
    final error = _dateError ?? _error;
    return AlertDialog(
      title: const Text('Edit current term dates'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.term.termName} · ${widget.term.academicYear}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _DialogDate(
                label: 'Teaching ends',
                value: _teachingEnd,
                onTap: _saving ? null : () => _pickDate(closing: false),
              ),
              const SizedBox(height: 6),
              const Text('The last day of lessons.'),
              const SizedBox(height: 16),
              _DialogDate(
                label: 'Earliest closing date',
                value: _closingDate,
                onTap: _saving ? null : () => _pickDate(closing: true),
              ),
              const SizedBox(height: 6),
              Text(_closingDateHelp),
              const SizedBox(height: 16),
              const Text(
                'After changing dates, check whether any published report cards need to be regenerated.',
                style: TextStyle(color: AppColors.muted),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: const TextStyle(color: AppColors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || !changed || _dateError != null ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save changes'),
        ),
      ],
    );
  }
}

class _CreatePreparedTermDialog extends StatefulWidget {
  const _CreatePreparedTermDialog({
    required this.schoolId,
    required this.api,
    this.existing,
    this.followsClosedTerm,
    this.earliestStart,
  });

  final String schoolId;
  final _AcademicTermManagementApi api;
  final _ManagedTerm? existing;
  final _ManagedTerm? followsClosedTerm;
  final DateTime? earliestStart;

  @override
  State<_CreatePreparedTermDialog> createState() =>
      _CreatePreparedTermDialogState();
}

class _CreatePreparedTermDialogState extends State<_CreatePreparedTermDialog> {
  late final Future<List<List<_LookupOption>>> _lookups;
  late final TextEditingController _description;
  int? _academicYearId;
  int? _termTypeId;
  DateTime? _operationalStart;
  DateTime? _teachingStart;
  DateTime? _teachingEnd;
  DateTime? _closingDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _lookups = _loadLookups();
    _description = TextEditingController(text: existing?.description ?? '');
    _academicYearId = existing?.academicYearId;
    _termTypeId = existing?.termTypeId;
    _operationalStart = existing?.operationalStart ?? widget.earliestStart;
    _teachingStart = existing?.teachingStart;
    _teachingEnd = existing?.teachingEnd;
    _closingDate = existing?.closingDate;
  }

  Future<List<List<_LookupOption>>> _loadLookups() async {
    final lookups = await Future.wait([
      widget.api.academicYears(),
      widget.api.termTypes(),
    ]);
    final closed = widget.followsClosedTerm;
    if (closed != null && widget.existing == null) {
      final years = lookups[0];
      final types = lookups[1];
      final sequence = types
          .where((type) => type.id == closed.termTypeId)
          .firstOrNull
          ?.sequence;
      final nextSequence = sequence == 3 ? 1 : (sequence ?? 0) + 1;
      _termTypeId = types
          .where((type) => type.sequence == nextSequence)
          .firstOrNull
          ?.id;
      if (sequence != 3) {
        _academicYearId = closed.academicYearId;
      } else {
        final startYear = int.tryParse(
          closed.academicYear.split(RegExp(r'[-–—]')).first.trim(),
        );
        if (startYear != null) {
          _academicYearId = years
              .where((year) => year.name.startsWith('${startYear + 1}'))
              .firstOrNull
              ?.id;
        }
      }
    }
    return lookups;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  (int, int)? _academicYearRange(List<_LookupOption> years) {
    final name = years
        .where((year) => year.id == _academicYearId)
        .firstOrNull
        ?.name;
    final match = RegExp(
      r'^(\d{4})\s*[-–—]\s*(\d{4})$',
    ).firstMatch(name?.trim() ?? '');
    return match == null ? null : (int.parse(match[1]!), int.parse(match[2]!));
  }

  Future<void> _pick(String field, List<_LookupOption> years) async {
    if (_saving) return;
    final fallback = switch (field) {
      'operational' => _operationalStart,
      'teachingStart' => _teachingStart ?? _operationalStart,
      'teachingEnd' => _teachingEnd ?? _teachingStart,
      _ => _closingDate ?? _teachingEnd,
    };
    final range = _academicYearRange(years);
    final yearStart = DateTime(range?.$1 ?? 2020);
    final yearEnd = DateTime(range?.$2 ?? 2040, 12, 31);
    final (previous, next) = switch (field) {
      'operational' => (null, _teachingStart),
      'teachingStart' => (_operationalStart, _teachingEnd),
      'teachingEnd' => (_teachingStart, _closingDate),
      _ => (_teachingEnd, null),
    };
    final earliest = previous != null && previous.isAfter(yearStart)
        ? previous
        : yearStart;
    final latest = next != null && next.isBefore(yearEnd) ? next : yearEnd;
    final hasValidRange = !earliest.isAfter(latest);
    final firstDate = hasValidRange ? earliest : yearStart;
    final lastDate = hasValidRange ? latest : yearEnd;
    final initial = fallback ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : initial.isAfter(lastDate)
          ? lastDate
          : initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      switch (field) {
        case 'operational':
          _operationalStart = picked;
        case 'teachingStart':
          _teachingStart = picked;
        case 'teachingEnd':
          _teachingEnd = picked;
        default:
          _closingDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_academicYearId == null ||
        _termTypeId == null ||
        _operationalStart == null ||
        _teachingStart == null ||
        _teachingEnd == null ||
        _closingDate == null) {
      setState(() => _error = 'Complete the academic year, term and dates.');
      return;
    }
    if (_teachingStart!.isBefore(_operationalStart!) ||
        _teachingEnd!.isBefore(_teachingStart!) ||
        _closingDate!.isBefore(_teachingEnd!)) {
      setState(() {
        _error = widget.followsClosedTerm == null
            ? 'Choose the office opening, teaching dates and closing date in order.'
            : 'Teaching must start after the previous term and end on or before the closing date.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final years = (await _lookups).first;
      final yearRange = _academicYearRange(years);
      if (yearRange != null &&
          (_operationalStart!.year < yearRange.$1 ||
              _closingDate!.year > yearRange.$2)) {
        final name = years
            .firstWhere((year) => year.id == _academicYearId)
            .name;
        if (mounted) {
          setState(
            () => _error = 'Term dates must fall within academic year $name.',
          );
        }
        return;
      }
      final terms = await widget.api.terms(widget.schoolId);
      final otherTerms = terms.where((term) => term.id != widget.existing?.id);
      final duplicate = otherTerms.any(
        (term) =>
            term.academicYearId == _academicYearId &&
            term.termTypeId == _termTypeId,
      );
      if (duplicate) {
        if (mounted) {
          setState(() {
            _error =
                'This academic year and term already exist. Choose a different term.';
          });
        }
        return;
      }
      if (otherTerms.any(
        (term) =>
            term.isCurrent && !_operationalStart!.isAfter(term.closingDate),
      )) {
        if (mounted) {
          setState(
            () => _error =
                'The next term must open after the current term closes.',
          );
        }
        return;
      }
      if (otherTerms.any(
        (term) =>
            !_operationalStart!.isAfter(term.closingDate) &&
            !_closingDate!.isBefore(term.operationalStart),
      )) {
        if (mounted) {
          setState(
            () => _error = 'These dates overlap another term for this school.',
          );
        }
        return;
      }
      await widget.api.savePreparedTerm(
        schoolId: widget.schoolId,
        existing: widget.existing,
        academicYearId: _academicYearId!,
        termTypeId: _termTypeId!,
        operationalStart: _operationalStart!,
        teachingStart: _teachingStart!,
        teachingEnd: _teachingEnd!,
        closingDate: _closingDate!,
        description: _description.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDateHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline_rounded, color: AppColors.green),
          SizedBox(width: 10),
          Text('Understanding the term dates'),
        ],
      ),
      content: const SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use the dates in this order. They describe when the school begins operating, when lessons run and when closing work is complete.',
                style: TextStyle(color: AppColors.muted),
              ),
              SizedBox(height: 18),
              _TermDateExplanation(
                number: '1',
                title: 'Office opens / vacation begins',
                description:
                    'The school may be on vacation, but the office can reopen and admissions for the next term can begin from this date. Fee collection and payments may also start before teaching begins.',
              ),
              _TermDateExplanation(
                number: '2',
                title: 'Teaching starts',
                description:
                    'The first instructional day for students. Normal attendance, lessons and academic records begin from this date.',
              ),
              _TermDateExplanation(
                number: '3',
                title: 'Teaching ends',
                description:
                    'The final day of normal lessons. Assessments, reports, reviews and other closing work may continue afterward.',
              ),
              _TermDateExplanation(
                number: '4',
                title: 'Term closes',
                description:
                    'The earliest date the term can be formally closed. All readiness blockers must also be resolved before closure.',
                last: true,
              ),
              SizedBox(height: 14),
              _TermDateOrderNotice(),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.followsClosedTerm != null
                  ? 'Set up the next term'
                  : widget.existing == null
                  ? 'Prepare the next term'
                  : 'Modify the next term',
            ),
          ),
          if (widget.followsClosedTerm == null)
            TextButton.icon(
              onPressed: _showDateHelp,
              icon: const Icon(Icons.help_outline_rounded),
              label: const Text('Date help'),
            ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: FutureBuilder<List<List<_LookupOption>>>(
          future: _lookups,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final years = snapshot.requireData[0];
            final types = snapshot.requireData[1];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.followsClosedTerm == null
                        ? 'Choose the next academic period and set when the office reopens, teaching runs and the term may close.'
                        : 'Confirm the academic period, teaching dates and earliest closing date.',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _academicYearId,
                          decoration: const InputDecoration(
                            labelText: 'Academic year',
                          ),
                          items: years
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  _academicYearId = value;
                                  _error = null;
                                }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _termTypeId,
                          decoration: const InputDecoration(labelText: 'Term'),
                          items: types
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  _termTypeId = value;
                                  _error = null;
                                }),
                        ),
                      ),
                    ],
                  ),
                  if (widget.followsClosedTerm == null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: _DialogDate(
                        label: 'Office opens / vacation begins',
                        value: _operationalStart,
                        onTap: () => _pick('operational', years),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogDate(
                          label: 'Teaching starts',
                          value: _teachingStart,
                          onTap: () => _pick('teachingStart', years),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DialogDate(
                          label: 'Teaching ends',
                          value: _teachingEnd,
                          onTap: () => _pick('teachingEnd', years),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: _DialogDate(
                      label: 'Earliest closing date',
                      value: _closingDate,
                      onTap: () => _pick('closing', years),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _description,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: widget.followsClosedTerm == null
                          ? 'For example: office opens during vacation for admissions and fee collection.'
                          : null,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(
            _saving
                ? 'Saving...'
                : widget.followsClosedTerm != null
                ? 'Save and review'
                : widget.existing == null
                ? 'Prepare term'
                : 'Save changes',
          ),
        ),
      ],
    );
  }
}

class _TermDateExplanation extends StatelessWidget {
  const _TermDateExplanation({
    required this.number,
    required this.title,
    required this.description,
    this.last = false,
  });

  final String number;
  final String title;
  final String description;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!last)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  color: AppColors.border,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _TermDateOrderNotice extends StatelessWidget {
  const _TermDateOrderNotice();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.blue.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.blue.withValues(alpha: .2)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: AppColors.blue),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Required order: Office opens → Teaching starts → Teaching ends → Term closes. Dates may be the same day, but they cannot move backward.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _DialogDate extends StatelessWidget {
  const _DialogDate({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(value == null ? 'Select date' : _friendlyDate(value!)),
      ),
    );
  }
}

class _TermError extends StatelessWidget {
  const _TermError({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            OutlinedButton(onPressed: retry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ManagedTerm {
  const _ManagedTerm({
    required this.id,
    required this.academicYearId,
    required this.termTypeId,
    required this.academicYear,
    required this.termName,
    required this.status,
    required this.isCurrent,
    required this.operationalStart,
    required this.teachingStart,
    required this.teachingEnd,
    required this.closingDate,
    required this.description,
    required this.raw,
  });

  final int id;
  final int academicYearId;
  final int termTypeId;
  final String academicYear;
  final String termName;
  final String status;
  final bool isCurrent;
  final DateTime operationalStart;
  final DateTime teachingStart;
  final DateTime teachingEnd;
  final DateTime closingDate;
  final String description;
  final Map<String, dynamic> raw;

  factory _ManagedTerm.fromJson(Map<String, dynamic> json) {
    return _ManagedTerm(
      id: (json['id'] as num).toInt(),
      academicYearId: _nestedId(json['academicYear']),
      termTypeId: _nestedId(json['termType']),
      academicYear: _nestedName(json['academicYear']),
      termName: _nestedName(json['termType']),
      status:
          '${json['lifecycleStatus'] ?? (json['isClosed'] == true ? 'CLOSED' : 'ACTIVE')}'
              .toUpperCase(),
      isCurrent: json['isCurrentTerm'] == true,
      operationalStart: _jsonDate(
        json['operationalStartDate'] ?? json['startDate'],
      ),
      teachingStart: _jsonDate(json['teachingStartDate'] ?? json['startDate']),
      teachingEnd: _jsonDate(json['teachingEndDate'] ?? json['endDate']),
      closingDate: _jsonDate(json['closingDate'] ?? json['endDate']),
      description: '${json['description'] ?? ''}'.trim(),
      raw: Map<String, dynamic>.from(json),
    );
  }
}

class _LookupOption {
  const _LookupOption(this.id, this.name, {this.sequence});
  final int id;
  final String name;
  final int? sequence;
}

class _AcademicTermManagementApi {
  _AcademicTermManagementApi({
    required this.accessToken,
    this.onRefreshAccessToken,
  });

  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  Future<List<_ManagedTerm>> terms(String schoolId) async {
    final response = await _send(
      'GET',
      '/api/academic-terms?customSchoolId=${Uri.encodeQueryComponent(schoolId)}',
    );
    final decoded = jsonDecode(response.body);
    return (decoded as List? ?? const [])
        .whereType<Map>()
        .map((item) => _ManagedTerm.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<(_ManagedTerm, DateTime, String)> currentTermDates(
    String schoolId,
    int termId,
  ) async {
    final response = await _send(
      'GET',
      _termPath(schoolId, termId, action: '/current-dates'),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final limit = data['closingDateLimit'] as Map<String, dynamic>;
    return (
      _ManagedTerm.fromJson(data['term'] as Map<String, dynamic>),
      _jsonDate(limit['earliestDate']),
      limit['reason'] as String,
    );
  }

  Future<void> saveCurrentTermDates({
    required String schoolId,
    required int termId,
    required DateTime teachingEnd,
    required DateTime closingDate,
  }) async {
    await _send(
      'PUT',
      _termPath(schoolId, termId, action: '/current-dates'),
      body: jsonEncode({
        'teachingEndDate': _iso(teachingEnd),
        'closingDate': _iso(closingDate),
      }),
    );
  }

  String _termPath(String schoolId, int termId, {String action = ''}) =>
      '/api/academic-terms/$termId$action?customSchoolId=${Uri.encodeQueryComponent(schoolId)}';

  Future<List<_LookupOption>> academicYears() =>
      _lookups('/api/lookup/academic-years');
  Future<List<_LookupOption>> termTypes() => _lookups('/api/lookup/term-types');

  Future<List<_LookupOption>> _lookups(String path) async {
    final response = await _send('GET', path);
    final decoded = jsonDecode(response.body);
    return (decoded as List? ?? const []).whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return _LookupOption(
        (map['id'] as num).toInt(),
        '${map['name']}',
        sequence: (map['termSequence'] as num?)?.toInt(),
      );
    }).toList();
  }

  Future<void> savePreparedTerm({
    required String schoolId,
    required _ManagedTerm? existing,
    required int academicYearId,
    required int termTypeId,
    required DateTime operationalStart,
    required DateTime teachingStart,
    required DateTime teachingEnd,
    required DateTime closingDate,
    required String description,
  }) async {
    final body = <String, dynamic>{
      if (existing != null) ...existing.raw,
      'academicYear': {'id': academicYearId},
      'termType': {'id': termTypeId},
      'startDate': _iso(operationalStart),
      'endDate': _iso(closingDate),
      'operationalStartDate': _iso(operationalStart),
      'teachingStartDate': _iso(teachingStart),
      'teachingEndDate': _iso(teachingEnd),
      'closingDate': _iso(closingDate),
      'lifecycleStatus': 'PREPARED',
      'description': description.trim().isEmpty
          ? 'Prepared from Academic Term Settings'
          : description.trim(),
    };
    await _send(
      existing == null ? 'POST' : 'PUT',
      existing == null
          ? '/api/academic-terms?customSchoolId=${Uri.encodeQueryComponent(schoolId)}'
          : '/api/academic-terms/${existing.id}?customSchoolId=${Uri.encodeQueryComponent(schoolId)}',
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? body,
  }) async {
    Future<http.Response> send() {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${accessToken?.trim() ?? ''}',
      };
      return switch (method) {
        'POST' => http.post(uri, headers: headers, body: body),
        'PUT' => http.put(uri, headers: headers, body: body),
        _ => http.get(uri, headers: headers),
      };
    }

    var response = await send();
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        onRefreshAccessToken != null) {
      final refreshed = await onRefreshAccessToken!();
      if (refreshed?.trim().isNotEmpty == true) {
        accessToken = refreshed!.trim();
        response = await send();
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Academic term request failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && '${decoded['message'] ?? ''}'.trim().isNotEmpty) {
          message = '${decoded['message']}';
        }
      } catch (_) {}
      throw Exception(message);
    }
    return response;
  }
}

String _nestedName(Object? value) {
  if (value is Map) return '${value['name'] ?? ''}'.trim();
  return '${value ?? ''}'.trim();
}

int _nestedId(Object? value) {
  if (value is Map) return int.tryParse('${value['id']}') ?? 0;
  return 0;
}

DateTime _jsonDate(Object? value) {
  if (value is List && value.length >= 3) {
    return DateTime(
      (value[0] as num).toInt(),
      (value[1] as num).toInt(),
      (value[2] as num).toInt(),
    );
  }
  return DateTime.tryParse('${value ?? ''}') ?? DateTime(1970);
}

String _iso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _friendlyDate(DateTime value) {
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
