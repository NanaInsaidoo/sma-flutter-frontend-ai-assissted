import 'package:flutter/material.dart';

import '../data/assessment_api_client.dart';

class KgObservationScreen extends StatefulWidget {
  const KgObservationScreen({
    super.key,
    required this.api,
    required this.schoolId,
  });
  final AssessmentApiClient api;
  final String schoolId;

  @override
  State<KgObservationScreen> createState() => _KgObservationScreenState();
}

class _KgObservationScreenState extends State<KgObservationScreen> {
  AssessmentFormSetup? _setup;
  List<Map<String, dynamic>> _options = [];
  List<Map<String, dynamic>> _rows = [];
  final _ratings = <String, String?>{};
  final _notes = <String, TextEditingController>{};
  int? _stream;
  int? _subject;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  final _overrideReason = TextEditingController();
  bool get _beforeTeaching =>
      _setup?.teachingStartDate?.isAfter(DateTime.now()) ?? false;

  List<AssessmentStreamOption> get _classes => (_setup?.streams ?? [])
      .where((item) => item.gradeLevelId == 1 || item.gradeLevelId == 2)
      .toList();
  List<AssessmentSubjectOption> get _areas {
    final stream = _classes.where((item) => item.id == _stream).firstOrNull;
    return (_setup?.subjects ?? [])
        .where(
          (item) =>
              item.gradeLevelId == stream?.gradeLevelId &&
              item.isAvailableIn(_stream),
        )
        .toList();
  }

  bool get _dirty => _rows.any((row) {
    final id = row['studentId'].toString();
    return _ratings[id] != row['rating'] ||
        (_notes[id]?.text ?? '').trim() != (row['observation'] ?? '');
  });

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final setup = await widget.api.getFormSetup(widget.schoolId);
      final reference = await widget.api.getHandbookReference();
      if (!mounted) return;
      _setup = setup;
      _options = (reference['kgRatings'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      _stream = _classes.firstOrNull?.id;
      _subject = _areas.firstOrNull?.id;
      await _load();
    } on AssessmentApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = _stream == null || _subject == null
          ? <Map<String, dynamic>>[]
          : await widget.api.getKgObservations(
              schoolId: widget.schoolId,
              streamId: _stream!,
              subjectId: _subject!,
              term: _setup!.termSequence,
              academicYearId: _setup!.academicYearId,
            );
      if (!mounted) return;
      for (final note in _notes.values) {
        note.dispose();
      }
      _notes.clear();
      _ratings.clear();
      _rows = rows;
      for (final row in rows) {
        final id = row['studentId'].toString();
        _ratings[id] = row['rating'] as String?;
        _notes[id] = TextEditingController(
          text: row['observation']?.toString() ?? '',
        );
      }
      setState(() => _loading = false);
    } on AssessmentApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_beforeTeaching && _overrideReason.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a reason of at least 5 characters for recording before teaching begins.',
          ),
        ),
      );
      return;
    }
    final entries = <Map<String, dynamic>>[];
    for (final row in _rows.where((row) => row['reportGenerated'] != true)) {
      final id = row['studentId'].toString();
      final rating = _ratings[id];
      final observation = _notes[id]!.text.trim();
      if (rating == row['rating'] && observation == (row['observation'] ?? '')) {
        continue;
      }
      if (rating == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Choose a rating for each observation you changed.'),
          ),
        );
        return;
      }
      entries.add({
        'studentId': id,
        'rating': rating,
        'observation': observation,
      });
    }
    if (entries.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.api.saveKgObservations(
        schoolId: widget.schoolId,
        streamId: _stream!,
        subjectId: _subject!,
        term: _setup!.termSequence,
        academicYearId: _setup!.academicYearId,
        entries: entries,
        vacationOverrideReason: _overrideReason.text.trim().isEmpty
            ? null
            : _overrideReason.text.trim(),
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('KG observations saved.')));
      }
    } on AssessmentApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _overrideReason.dispose();
    for (final note in _notes.values) {
      note.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('KG learning observations')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(
                  onPressed: _setup == null ? _start : _load,
                  child: const Text('Try again'),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${_setup?.termName ?? ''} • ${_setup?.academicYearName ?? ''}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose Gold, Silver or Bronze from your observations of each child’s learning. These ratings do not use percentage cutoffs.',
              ),
              const SizedBox(height: 16),
              for (final option in _options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '${option['label']} (${option['code']}): ${option['description']}',
                  ),
                ),
              const SizedBox(height: 16),
              if (_classes.isEmpty)
                const Text(
                  'No KG1 or KG2 classes are available in this school.',
                ),
              DropdownButtonFormField<int>(
                value: _stream,
                decoration: const InputDecoration(labelText: 'KG class'),
                items: _classes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: _dirty || _saving
                    ? null
                    : (value) {
                        _stream = value;
                        _subject = _areas.firstOrNull?.id;
                        _load();
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _subject,
                decoration: const InputDecoration(labelText: 'Learning area'),
                items: _areas
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: _dirty || _saving
                    ? null
                    : (value) {
                        _subject = value;
                        _load();
                      },
              ),
              const SizedBox(height: 16),
              if (_beforeTeaching) ...[
                Text(
                  'Teaching begins on ${_setup!.teachingStartDate!.toIso8601String().split('T').first}. Explain why these observations are being recorded early.',
                ),
                TextField(
                  controller: _overrideReason,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Reason for early recording',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_setup?.termClosed == true)
                const Text('This term is closed. Observations are read only.'),
              if (_rows.isEmpty && _subject != null)
                const Text('No students are enrolled in this class.'),
              for (final row in _rows) _student(row),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(
                    onPressed: _saving || !_dirty || _setup?.termClosed == true
                        ? null
                        : _save,
                    child: Text(_saving ? 'Saving…' : 'Save observations'),
                  ),
                  if (_dirty)
                    TextButton(
                      onPressed: _saving ? null : _load,
                      child: const Text('Discard changes'),
                    ),
                ],
              ),
            ],
          ),
  );

  Widget _student(Map<String, dynamic> row) {
    final id = row['studentId'].toString();
    final locked =
        row['reportGenerated'] == true || _setup?.termClosed == true || _saving;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              row['studentName']?.toString() ?? id,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(id),
            if (row['reportGenerated'] == true)
              const Text('Locked because a report has been generated.'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('kg-rating-$id'),
              value: _ratings[id],
              decoration: const InputDecoration(labelText: 'Learning rating'),
              items: _options
                  .map(
                    (item) => DropdownMenuItem(
                      value: item['code'].toString(),
                      child: Text(item['label'].toString()),
                    ),
                  )
                  .toList(),
              onChanged: locked
                  ? null
                  : (value) => setState(() => _ratings[id] = value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('kg-note-$id'),
              controller: _notes[id],
              readOnly: locked,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Teacher observation',
                hintText: 'Describe what the child can do and any help needed.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
