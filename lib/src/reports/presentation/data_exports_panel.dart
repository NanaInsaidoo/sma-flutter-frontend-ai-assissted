import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../domain/data_export_models.dart';
import 'data_export_download.dart';

enum _ExportPeriod { current, previous, lastThree, selected, custom, all }

class DataExportsPanel extends StatefulWidget {
  const DataExportsPanel({
    super.key,
    required this.schoolId,
    required this.repository,
  });

  final String schoolId;
  final DataExportRepository repository;

  @override
  State<DataExportsPanel> createState() => _DataExportsPanelState();
}

class _DataExportsPanelState extends State<DataExportsPanel> {
  final _minimumController = TextEditingController();
  final _maximumController = TextEditingController();
  DataExportOptions? _options;
  List<DataExportHistoryItem> _history = const [];
  final Set<String> _datasets = {};
  final Set<int> _terms = {};
  final Set<int> _classes = {};
  final Set<int> _paymentMethods = {};
  final Set<String> _statuses = {};
  _ExportPeriod _period = _ExportPeriod.current;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _anonymized = true;
  bool _includeAnalysisColumns = true;
  bool _includeDictionary = true;
  bool _showBuilder = false;
  bool _showFilters = false;
  bool _loading = true;
  bool _reviewing = false;
  bool _generating = false;
  int? _downloadingHistoryId;
  String? _error;
  DataExportPreview? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _minimumController.dispose();
    _maximumController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.dataExportOptions(widget.schoolId),
        widget.repository.dataExportHistory(widget.schoolId),
      ]);
      if (!mounted) return;
      setState(() {
        _options = results[0] as DataExportOptions;
        _history = results[1] as List<DataExportHistoryItem>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _MessageCard(
        icon: Icons.error_outline,
        title: 'Data exports could not be loaded',
        text: _error!,
        action: TextButton(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _load();
          },
          child: const Text('Try again'),
        ),
      );
    }
    final options = _options!;
    return Column(
      key: const ValueKey('data-exports-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _intro(),
        const SizedBox(height: 20),
        if (!_showBuilder)
          FilledButton.icon(
            key: const ValueKey('create-data-export'),
            onPressed: () => setState(() => _showBuilder = true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create data export'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          )
        else
          _builder(options),
        const SizedBox(height: 32),
        _historySection(),
      ],
    );
  }

  Widget _intro() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7F6),
      border: Border.all(color: const Color(0xFFCFE6E2)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.dataset_outlined, color: AppColors.green),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Raw data for further analysis',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Choose a period and data areas. The download contains connected row-level CSV files for Excel, Power BI or another analysis tool—not copies of the PDF tables.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _builder(DataExportOptions options) => Card(
    key: const ValueKey('data-export-builder'),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Create data export',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _reset,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _step(
            1,
            'Choose the period',
            'Select terms, a date range, or all available records.',
            _periodStep(options),
          ),
          _step(
            2,
            'Choose the data',
            'Each area creates one or more connected CSV files.',
            _datasetStep(options),
          ),
          _step(
            3,
            'Limit the records',
            'The default includes all records matching the selected period.',
            _filterStep(options),
          ),
          _step(
            4,
            'Privacy and export contents',
            'Identifiable data is available only when your workspace role permits it.',
            _privacyStep(options),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 18),
            _reviewCard(_preview!),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(onPressed: _reset, child: const Text('Cancel')),
              OutlinedButton.icon(
                key: const ValueKey('review-data-export'),
                onPressed: _reviewing || _generating ? null : _review,
                icon: _reviewing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(_reviewing ? 'Reviewing…' : 'Review export'),
              ),
              FilledButton.icon(
                key: const ValueKey('generate-data-export'),
                onPressed:
                    _preview == null || _preview!.overLimit || _generating
                    ? null
                    : _generate,
                icon: _generating
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(
                  _generating ? 'Preparing…' : 'Generate data export',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _step(int number, String title, String subtitle, Widget child) =>
      Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.greenSoft,
                    foregroundColor: AppColors.green,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
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
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );

  Widget _periodStep(DataExportOptions options) {
    final labels = <_ExportPeriod, String>{
      _ExportPeriod.current: 'Current term',
      _ExportPeriod.previous: 'Previous term',
      _ExportPeriod.lastThree: 'Last three terms',
      _ExportPeriod.selected: 'Select terms',
      _ExportPeriod.custom: 'Custom date range',
      _ExportPeriod.all: 'All available data',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.entries
              .map(
                (entry) => ChoiceChip(
                  key: ValueKey('data-export-period-${entry.key.name}'),
                  label: Text(entry.value),
                  selected: _period == entry.key,
                  onSelected: (_) => _changed(() => _period = entry.key),
                  selectedColor: AppColors.greenSoft,
                ),
              )
              .toList(),
        ),
        if (_period == _ExportPeriod.selected) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.terms
                .map(
                  (term) => FilterChip(
                    label: Text(term.label),
                    selected: _terms.contains(term.id),
                    onSelected: (selected) => _changed(
                      () => selected
                          ? _terms.add(term.id)
                          : _terms.remove(term.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (_period == _ExportPeriod.custom) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DateButton(
                label: 'Start date',
                value: _startDate,
                onTap: () => _pickDate(true),
              ),
              _DateButton(
                label: 'End date',
                value: _endDate,
                onTap: () => _pickDate(false),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _datasetStep(DataExportOptions options) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.datasets.map((dataset) {
        final selected = _datasets.contains(dataset.code);
        return SizedBox(
          width: constraints.maxWidth < 310 ? constraints.maxWidth : 310,
          child: InkWell(
            key: ValueKey('data-export-dataset-${dataset.code}'),
            onTap: () => _changed(
              () => selected
                  ? _datasets.remove(dataset.code)
                  : _datasets.add(dataset.code),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppColors.greenSoft : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.green : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _changed(
                      () => selected
                          ? _datasets.remove(dataset.code)
                          : _datasets.add(dataset.code),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dataset.label,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dataset.description,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.3,
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
      }).toList(),
    ),
  );

  Widget _filterStep(DataExportOptions options) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'All records matching the selected period',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('data-export-more-filters'),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Icon(_showFilters ? Icons.expand_less : Icons.tune_rounded),
            label: Text(_showFilters ? 'Hide filters' : 'More filters'),
          ),
        ],
      ),
      if (_showFilters) ...[
        const Divider(height: 24),
        const Text('Classes', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.classes
              .map(
                (item) => FilterChip(
                  label: Text(item.name),
                  selected: _classes.contains(item.id),
                  onSelected: (selected) => _changed(
                    () => selected
                        ? _classes.add(item.id)
                        : _classes.remove(item.id),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Record status',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.statusOptions
              .map(
                (status) => FilterChip(
                  label: Text(_readable(status)),
                  selected: _statuses.contains(status),
                  onSelected: (selected) => _changed(
                    () => selected
                        ? _statuses.add(status)
                        : _statuses.remove(status),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment methods',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: options.paymentMethods
              .map(
                (item) => FilterChip(
                  label: Text(item.name),
                  selected: _paymentMethods.contains(item.id),
                  onSelected: (selected) => _changed(
                    () => selected
                        ? _paymentMethods.add(item.id)
                        : _paymentMethods.remove(item.id),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final fields = [
              TextField(
                controller: _minimumController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _changed(() {}),
                decoration: const InputDecoration(
                  labelText: 'Minimum amount',
                  prefixText: 'GHS ',
                ),
              ),
              TextField(
                controller: _maximumController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _changed(() {}),
                decoration: const InputDecoration(
                  labelText: 'Maximum amount',
                  prefixText: 'GHS ',
                ),
              ),
            ];
            if (constraints.maxWidth < 560) {
              return Column(
                children: [fields[0], const SizedBox(height: 10), fields[1]],
              );
            }
            return Row(
              children: [
                Expanded(child: fields[0]),
                const SizedBox(width: 12),
                Expanded(child: fields[1]),
              ],
            );
          },
        ),
      ],
    ],
  );

  Widget _privacyStep(DataExportOptions options) => Column(
    children: [
      RadioListTile<bool>(
        key: const ValueKey('data-export-anonymized'),
        value: true,
        groupValue: _anonymized,
        onChanged: (value) => _changed(() => _anonymized = value ?? true),
        title: const Text(
          'Anonymised data',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Names, personal identifiers and free-text narratives are protected. Recommended for general analysis.',
        ),
      ),
      if (options.canIncludeIdentities)
        RadioListTile<bool>(
          key: const ValueKey('data-export-identifiable'),
          value: false,
          groupValue: _anonymized,
          onChanged: (value) => _changed(() => _anonymized = value ?? true),
          title: const Text(
            'Include names and recorded identifiers',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Use only when identifiable records are required for authorised operational work.',
          ),
        ),
      const Divider(height: 24),
      SwitchListTile(
        value: _includeAnalysisColumns,
        onChanged: (value) => _changed(() => _includeAnalysisColumns = value),
        title: const Text(
          'Include analysis-friendly columns',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Adds week, quarter, day of week and time-of-day fields without replacing the recorded values.',
        ),
      ),
      SwitchListTile(
        value: _includeDictionary,
        onChanged: (value) => _changed(() => _includeDictionary = value),
        title: const Text(
          'Include data dictionary',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text(
          'Adds a file explaining every exported field and its source.',
        ),
      ),
    ],
  );

  Widget _reviewCard(DataExportPreview preview) => Container(
    key: const ValueKey('data-export-review-summary'),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: preview.overLimit
          ? const Color(0xFFFFF4E5)
          : const Color(0xFFEAF1FF),
      border: Border.all(
        color: preview.overLimit ? AppColors.amber : const Color(0xFFC9D8F5),
      ),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          preview.overLimit ? 'Narrow the export' : 'Export ready to generate',
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_formatNumber(preview.totalRecords)} estimated records · ${preview.files.length} CSV files · ${_anonymized ? 'Anonymised' : 'Identifiable'}',
          style: const TextStyle(color: AppColors.text),
        ),
        const SizedBox(height: 4),
        Text(preview.period, style: const TextStyle(color: AppColors.muted)),
        if (preview.overLimit) ...[
          const SizedBox(height: 8),
          Text(
            'The maximum is ${_formatNumber(_options!.maximumRows)} records. Select fewer terms, dates or data areas.',
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _historySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Recent data exports',
        style: TextStyle(
          color: AppColors.text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Every export is recorded. Downloading an earlier entry regenerates the package from its saved criteria.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 14),
      if (_history.isEmpty)
        const _MessageCard(
          icon: Icons.history_rounded,
          title: 'No data exports yet',
          text:
              'Completed exports will appear here with their criteria, privacy level and record count.',
        )
      else
        Card(
          child: Column(
            children: _history.indexed.map((entry) {
              final item = entry.$2;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _historyItem(item),
                  ),
                  if (entry.$1 != _history.length - 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
    ],
  );

  Widget _historyItem(DataExportHistoryItem item) => LayoutBuilder(
    builder: (context, constraints) {
      final summary = Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.folder_zip_outlined,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNumber(item.rowCount)} records · ${item.anonymized ? 'Anonymised' : 'Identifiable'} · ${item.generatedBy}${item.generatedAt == null ? '' : ' · ${_dateTime(item.generatedAt!)}'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  item.datasets.map(_readable).join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
      final download = OutlinedButton.icon(
        key: ValueKey('download-data-export-${item.id}'),
        onPressed: _downloadingHistoryId == null
            ? () => _downloadHistory(item)
            : null,
        icon: _downloadingHistoryId == item.id
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        label: const Text('Download again'),
      );
      if (constraints.maxWidth < 620) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [summary, const SizedBox(height: 12), download],
        );
      }
      return Row(
        children: [
          Expanded(child: summary),
          const SizedBox(width: 10),
          download,
        ],
      );
    },
  );

  Future<void> _review() async {
    final request = _request(showErrors: true);
    if (request == null) return;
    setState(() => _reviewing = true);
    try {
      final preview = await widget.repository.previewDataExport(
        widget.schoolId,
        request,
      );
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _generate() async {
    final request = _request(showErrors: true);
    if (request == null) return;
    setState(() => _generating = true);
    try {
      final export = await widget.repository.createDataExport(
        widget.schoolId,
        request,
      );
      final downloaded = await downloadDataExportFile(
        export.fileName,
        export.bytes,
      );
      final history = await widget.repository.dataExportHistory(
        widget.schoolId,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _generating = false;
      });
      _message(
        downloaded
            ? 'Data export downloaded.'
            : 'The export was prepared, but downloads are not available on this device.',
      );
    } catch (error) {
      if (mounted) setState(() => _generating = false);
      _message(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _downloadHistory(DataExportHistoryItem item) async {
    setState(() => _downloadingHistoryId = item.id);
    try {
      final export = await widget.repository.downloadDataExport(
        widget.schoolId,
        item.id,
        item.fileName,
      );
      final downloaded = await downloadDataExportFile(
        export.fileName,
        export.bytes,
      );
      _message(
        downloaded
            ? 'Data export downloaded.'
            : 'Downloads are not available on this device.',
      );
    } catch (error) {
      _message(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _downloadingHistoryId = null);
    }
  }

  DataExportRequest? _request({required bool showErrors}) {
    if (_datasets.isEmpty) {
      if (showErrors) _message('Select at least one data area.');
      return null;
    }
    final termIds = _periodTerms();
    if ((_period == _ExportPeriod.current ||
            _period == _ExportPeriod.previous ||
            _period == _ExportPeriod.lastThree) &&
        termIds.isEmpty) {
      if (showErrors) {
        _message(
          _period == _ExportPeriod.previous
              ? 'No previous term is available.'
              : 'No term is available for this selection.',
        );
      }
      return null;
    }
    if (_period == _ExportPeriod.selected && termIds.isEmpty) {
      if (showErrors) _message('Select at least one term.');
      return null;
    }
    if (_period == _ExportPeriod.custom &&
        (_startDate == null || _endDate == null)) {
      if (showErrors) _message('Select both the start and end dates.');
      return null;
    }
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      if (showErrors) _message('The start date must be before the end date.');
      return null;
    }
    final minimumText = _minimumController.text.trim();
    final maximumText = _maximumController.text.trim();
    final minimum = double.tryParse(minimumText);
    final maximum = double.tryParse(maximumText);
    if ((minimumText.isNotEmpty && minimum == null) ||
        (maximumText.isNotEmpty && maximum == null)) {
      if (showErrors) {
        _message('Enter valid amounts or leave both fields blank.');
      }
      return null;
    }
    if ((minimum != null && minimum < 0) || (maximum != null && maximum < 0)) {
      if (showErrors) _message('Amounts cannot be negative.');
      return null;
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      if (showErrors) {
        _message('The minimum amount cannot exceed the maximum amount.');
      }
      return null;
    }
    return DataExportRequest(
      datasets: _datasets.toList(),
      termIds: termIds,
      startDate: _period == _ExportPeriod.custom ? _startDate : null,
      endDate: _period == _ExportPeriod.custom ? _endDate : null,
      classIds: _classes.toList(),
      statuses: _statuses.toList(),
      paymentMethodIds: _paymentMethods.toList(),
      minimumAmount: minimum,
      maximumAmount: maximum,
      allAvailable: _period == _ExportPeriod.all,
      anonymized: _anonymized,
      includeAnalysisColumns: _includeAnalysisColumns,
      includeDataDictionary: _includeDictionary,
    );
  }

  List<int> _periodTerms() {
    final terms = _options!.terms;
    if (_period == _ExportPeriod.current) {
      final current =
          terms.where((term) => term.current).firstOrNull ?? terms.firstOrNull;
      return current == null ? [] : [current.id];
    }
    if (_period == _ExportPeriod.previous) {
      final currentIndex = terms.indexWhere((term) => term.current);
      final index = currentIndex >= 0 ? currentIndex + 1 : 1;
      return index < terms.length ? [terms[index].id] : [];
    }
    if (_period == _ExportPeriod.lastThree) {
      return terms.take(3).map((term) => term.id).toList();
    }
    if (_period == _ExportPeriod.selected) return _terms.toList();
    return [];
  }

  Future<void> _pickDate(bool start) async {
    final initial = start
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) {
      _changed(() => start ? _startDate = value : _endDate = value);
    }
  }

  void _changed(VoidCallback update) => setState(() {
    update();
    _preview = null;
  });
  void _reset() => setState(() {
    _showBuilder = false;
    _showFilters = false;
    _preview = null;
    _datasets.clear();
    _terms.clear();
    _classes.clear();
    _paymentMethods.clear();
    _statuses.clear();
    _period = _ExportPeriod.current;
    _startDate = null;
    _endDate = null;
    _anonymized = true;
    _includeAnalysisColumns = true;
    _includeDictionary = true;
    _minimumController.clear();
    _maximumController.clear();
  });
  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _readable(String value) => value
      .toLowerCase()
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
  String _formatNumber(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')} ${_DateButton._month(local.month)} ${local.year}, $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.calendar_today_outlined),
    label: Text(
      value == null
          ? label
          : '$label: ${value!.day.toString().padLeft(2, '0')} ${_month(value!.month)} ${value!.year}',
    ),
  );
  static String _month(int month) => const [
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
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.muted, size: 34),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(text, style: const TextStyle(color: AppColors.muted)),
                if (action != null) action!,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
