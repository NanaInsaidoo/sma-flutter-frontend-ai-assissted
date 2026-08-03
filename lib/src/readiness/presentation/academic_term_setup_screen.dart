import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../theme/app_theme.dart';

class AcademicTermSetupScreen extends StatefulWidget {
  const AcademicTermSetupScreen({
    super.key,
    required this.customSchoolId,
    required this.accessToken,
    required this.onSaved,
    this.onRefreshAccessToken,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final VoidCallback onSaved;

  @override
  State<AcademicTermSetupScreen> createState() =>
      _AcademicTermSetupScreenState();
}

class _AcademicTermSetupScreenState extends State<AcademicTermSetupScreen> {
  late final _TermSetupApi _api = _TermSetupApi(
    accessToken: widget.accessToken,
    onRefreshAccessToken: widget.onRefreshAccessToken,
  );
  late Future<List<List<_LookupOption>>> _lookups;
  int? _academicYearId;
  int? _termTypeId;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _lookups = Future.wait([_api.academicYears(), _api.termTypes()]);
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _startDate = selected;
        if (_endDate != null && _endDate!.isBefore(selected)) _endDate = null;
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _save() async {
    if (_academicYearId == null ||
        _termTypeId == null ||
        _startDate == null ||
        _endDate == null) {
      setState(
        () => _error = 'Select the academic year, term, and both dates.',
      );
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      setState(
        () => _error = 'The term end date cannot be before its start date.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.createTerm(
        schoolId: widget.customSchoolId,
        academicYearId: _academicYearId!,
        termTypeId: _termTypeId!,
        startDate: _startDate!,
        endDate: _endDate!,
      );
      widget.onSaved();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<List<_LookupOption>>>(
      future: _lookups,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Setup options could not be loaded: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final years = snapshot.requireData[0];
        final terms = snapshot.requireData[1];
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Configure the current academic term',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This term becomes the school’s active operational context immediately after saving.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 22),
                      DropdownButtonFormField<int>(
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
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _termTypeId,
                        decoration: const InputDecoration(labelText: 'Term'),
                        items: terms
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Start date',
                              value: _startDate,
                              onTap: () => _pickDate(start: true),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _DateField(
                              label: 'End date',
                              value: _endDate,
                              onTap: () => _pickDate(start: false),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: const Text('Save current term'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Select date'
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(text),
      ),
    );
  }
}

class _LookupOption {
  const _LookupOption(this.id, this.name);
  final int id;
  final String name;
}

class _TermSetupApi {
  _TermSetupApi({required this.accessToken, this.onRefreshAccessToken});
  String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  Future<List<_LookupOption>> academicYears() =>
      _lookups('/api/lookup/academic-years');
  Future<List<_LookupOption>> termTypes() => _lookups('/api/lookup/term-types');

  Future<List<_LookupOption>> _lookups(String path) async {
    final response = await _send('GET', path);
    final decoded = jsonDecode(response.body);
    return (decoded as List? ?? const []).whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      return _LookupOption((map['id'] as num).toInt(), map['name'].toString());
    }).toList();
  }

  Future<void> createTerm({
    required String schoolId,
    required int academicYearId,
    required int termTypeId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _send(
      'POST',
      '/api/academic-terms?customSchoolId=${Uri.encodeQueryComponent(schoolId)}',
      body: jsonEncode({
        'academicYear': {'id': academicYearId},
        'termType': {'id': termTypeId},
        'startDate': _iso(startDate),
        'endDate': _iso(endDate),
        'description': 'Configured from school readiness setup',
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
      throw Exception('Academic term setup failed (${response.statusCode}).');
    }
    return response;
  }

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
