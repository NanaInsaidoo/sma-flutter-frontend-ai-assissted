import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_theme.dart';

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
                    'The operational start is when the office, admissions and fee collection begin. Teaching may start later. A prepared term becomes current only when the current term is closed.',
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
                children: terms.map((term) => _TermCard(term: term)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TermCard extends StatelessWidget {
  const _TermCard({required this.term});

  final _ManagedTerm term;

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

class _CreatePreparedTermDialog extends StatefulWidget {
  const _CreatePreparedTermDialog({required this.schoolId, required this.api});

  final String schoolId;
  final _AcademicTermManagementApi api;

  @override
  State<_CreatePreparedTermDialog> createState() =>
      _CreatePreparedTermDialogState();
}

class _CreatePreparedTermDialogState extends State<_CreatePreparedTermDialog> {
  late final Future<List<List<_LookupOption>>> _lookups = Future.wait([
    widget.api.academicYears(),
    widget.api.termTypes(),
  ]);
  final _description = TextEditingController();
  int? _academicYearId;
  int? _termTypeId;
  DateTime? _operationalStart;
  DateTime? _teachingStart;
  DateTime? _teachingEnd;
  DateTime? _closingDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick(String field) async {
    final fallback = switch (field) {
      'operational' => _operationalStart,
      'teachingStart' => _teachingStart ?? _operationalStart,
      'teachingEnd' => _teachingEnd ?? _teachingStart,
      _ => _closingDate ?? _teachingEnd,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate: fallback ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
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
      setState(
        () => _error = 'Complete the academic year, term and all four dates.',
      );
      return;
    }
    if (_teachingStart!.isBefore(_operationalStart!) ||
        _teachingEnd!.isBefore(_teachingStart!) ||
        _closingDate!.isBefore(_teachingEnd!)) {
      setState(() {
        _error =
            'Dates must follow this order: office opens, teaching starts, teaching ends, term closes.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createPreparedTerm(
        schoolId: widget.schoolId,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prepare the next term'),
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
                  const Text(
                    'This creates a prepared term. It will not replace the current term until term closure is completed.',
                    style: TextStyle(color: AppColors.muted),
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
                          onChanged: (value) =>
                              setState(() => _academicYearId = value),
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
                          onChanged: (value) =>
                              setState(() => _termTypeId = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogDate(
                          label: 'Office opens / vacation begins',
                          value: _operationalStart,
                          onTap: () => _pick('operational'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DialogDate(
                          label: 'Teaching starts',
                          value: _teachingStart,
                          onTap: () => _pick('teachingStart'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogDate(
                          label: 'Teaching ends',
                          value: _teachingEnd,
                          onTap: () => _pick('teachingEnd'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DialogDate(
                          label: 'Term closes',
                          value: _closingDate,
                          onTap: () => _pick('closing'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _description,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      hintText:
                          'For example: office opens during vacation for admissions and fee collection.',
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
          label: Text(_saving ? 'Preparing...' : 'Prepare term'),
        ),
      ],
    );
  }
}

class _DialogDate extends StatelessWidget {
  const _DialogDate({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

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
    required this.academicYear,
    required this.termName,
    required this.status,
    required this.isCurrent,
    required this.operationalStart,
    required this.teachingStart,
    required this.teachingEnd,
    required this.closingDate,
    required this.description,
  });

  final int id;
  final String academicYear;
  final String termName;
  final String status;
  final bool isCurrent;
  final DateTime operationalStart;
  final DateTime teachingStart;
  final DateTime teachingEnd;
  final DateTime closingDate;
  final String description;

  factory _ManagedTerm.fromJson(Map<String, dynamic> json) {
    return _ManagedTerm(
      id: (json['id'] as num).toInt(),
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
    );
  }
}

class _LookupOption {
  const _LookupOption(this.id, this.name);
  final int id;
  final String name;
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

  Future<List<_LookupOption>> academicYears() =>
      _lookups('/api/lookup/academic-years');
  Future<List<_LookupOption>> termTypes() => _lookups('/api/lookup/term-types');

  Future<List<_LookupOption>> _lookups(String path) async {
    final response = await _send('GET', path);
    final decoded = jsonDecode(response.body);
    return (decoded as List? ?? const []).whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return _LookupOption((map['id'] as num).toInt(), '${map['name']}');
    }).toList();
  }

  Future<void> createPreparedTerm({
    required String schoolId,
    required int academicYearId,
    required int termTypeId,
    required DateTime operationalStart,
    required DateTime teachingStart,
    required DateTime teachingEnd,
    required DateTime closingDate,
    required String description,
  }) async {
    await _send(
      'POST',
      '/api/academic-terms?customSchoolId=${Uri.encodeQueryComponent(schoolId)}',
      body: jsonEncode({
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
      }),
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
      return method == 'POST'
          ? http.post(uri, headers: headers, body: body)
          : http.get(uri, headers: headers);
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
