import 'dart:async';

import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';

// ignore_for_file: unused_field, unused_element_parameter

import '../../theme/app_theme.dart';
import '../data/finance_api_client.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.recordedBy,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final String? recordedBy;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const _green = AppColors.green;
  static const _muted = AppColors.muted;
  static const _border = AppColors.border;
  static const _text = AppColors.text;
  late _SchoolExpenseSettings _settings;
  late _PettyCashFloat _float;
  late List<_ExpenseRecord> _expenses;
  late List<_RequisitionRecord> _requisitions;
  late List<_TopUpRequest> _topUps;
  late List<_PocketTransfer> _pocketTransfers;
  late List<_ReconciliationRecord> _reconciliations;
  late List<_FinancialFollowUp> _financialFollowUps;
  late final FinanceApiClient _financeApi;
  bool _isLoadingFinance = true;
  bool _requiresCycleSetup = false;
  String? _financeLoadError;
  int? _academicTermId;

  _ExpenseTab _tab = _ExpenseTab.overview;
  _FinanceLedgerPage? _financeLedgerPage;
  _TopUpRequest? _selectedTopUp;
  _ReconciliationRecord? _selectedReconciliation;
  String _expenseQuery = '';
  String _expenseFilter = 'All';
  String _requisitionFilter = 'All';
  String _topUpQuery = '';
  String _topUpFilter = 'All';
  String _transferQuery = '';
  String _reconciliationStatusFilter = 'All statuses';
  String _followUpStatusFilter = 'All statuses';
  DateTime? _reconciliationFromDate;
  DateTime? _reconciliationToDate;
  int _topUpPage = 0;
  int _transferPage = 0;

  static const _ledgerPageSize = 8;

  @override
  void initState() {
    super.initState();
    _settings = _SchoolExpenseSettings.empty();
    _float = _PettyCashFloat.empty();
    _expenses = [];
    _requisitions = [];
    _topUps = [];
    _pocketTransfers = [];
    _reconciliations = [];
    _financialFollowUps = [];
    _financeApi = FinanceApiClient(
      accessToken: widget.accessToken,
      onRefreshAccessToken: widget.onRefreshAccessToken,
    );
    unawaited(_loadFinanceWorkspace());
  }

  double get _cashBalance => _float.cashBalance;
  double get _momoBalance => _float.momoBalance;
  double get _totalFloatBalance => _cashBalance + _momoBalance;
  double get _totalSpend =>
      _expenses.fold(0, (total, item) => total + item.netAmount);
  double get _pettySpend => _expenses
      .where((item) => item.source == _ExpenseSource.pettyCash)
      .fold(0, (total, item) => total + item.netAmount);
  double get _directSpend => _expenses
      .where((item) => item.source == _ExpenseSource.direct)
      .fold(0, (total, item) => total + item.netAmount);
  int get _pendingApprovalCount =>
      _requisitions
          .where((item) => item.status == _RequisitionStatus.pending)
          .length +
      _topUps.where((item) => item.status == _TopUpStatus.pending).length +
      _expenses
          .where((item) => item.status == _ExpenseStatus.pendingRatification)
          .length;

  List<_ExpenseRecord> get _visibleExpenses {
    final query = _expenseQuery.trim().toLowerCase();
    return _expenses.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.expenseId.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.payee.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      final matchesFilter =
          _expenseFilter == 'All' ||
          (_expenseFilter == 'Petty Cash' &&
              item.source == _ExpenseSource.pettyCash) ||
          (_expenseFilter == 'Direct' &&
              item.source == _ExpenseSource.direct) ||
          (_expenseFilter == 'Emergency' && item.isEmergency) ||
          (_expenseFilter == 'Refunded' &&
              (item.status == _ExpenseStatus.partiallyRefunded ||
                  item.status == _ExpenseStatus.fullyRefunded));
      return matchesQuery && matchesFilter;
    }).toList();
  }

  List<_RequisitionRecord> get _visibleRequisitions {
    return _requisitions.where((item) {
      if (_requisitionFilter == 'All') return true;
      return item.status.label == _requisitionFilter;
    }).toList();
  }

  List<_TopUpRequest> get _visibleTopUps {
    final query = _topUpQuery.trim().toLowerCase();
    return _topUps.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.requestId.toLowerCase().contains(query) ||
          (item.approvalCode?.toLowerCase().contains(query) ?? false);
      final matchesStatus =
          _topUpFilter == 'All' || item.status.label == _topUpFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  List<_PocketTransfer> get _visibleTransfers {
    final query = _transferQuery.trim().toLowerCase();
    return _pocketTransfers.where((item) {
      return query.isEmpty ||
          item.id.toLowerCase().contains(query) ||
          item.fromPocket.toLowerCase().contains(query) ||
          item.toPocket.toLowerCase().contains(query) ||
          item.reference.toLowerCase().contains(query);
    }).toList();
  }

  List<_ReconciliationRecord> get _visibleReconciliations {
    final records = _reconciliations.where((item) {
      final matchesStatus =
          _reconciliationStatusFilter == 'All statuses' ||
          item.status.label == _reconciliationStatusFilter;
      final matchesFrom =
          _reconciliationFromDate == null ||
          !item.requestedAt.isBefore(_startOfDay(_reconciliationFromDate!));
      final matchesTo =
          _reconciliationToDate == null ||
          !item.requestedAt.isAfter(_endOfDay(_reconciliationToDate!));
      return matchesStatus && matchesFrom && matchesTo;
    }).toList()..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return records;
  }

  List<_FinancialFollowUp> get _visibleFinancialFollowUps {
    final records = _financialFollowUps.where((item) {
      return _followUpStatusFilter == 'All statuses' ||
          item.status.label == _followUpStatusFilter;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  _ReconciliationRecord? get _activeReconciliation {
    for (final record in _reconciliations) {
      if (record.status == _ReconciliationStatus.inProgress) {
        return record;
      }
    }
    return null;
  }

  Future<void> _loadFinanceWorkspace({bool showLoading = true}) async {
    int? resolvedTermId;
    if (showLoading && mounted) {
      setState(() {
        _isLoadingFinance = true;
        _financeLoadError = null;
      });
    }

    try {
      final context = _asMap(
        await _financeApi.get(
          '/api/schools/${widget.customSchoolId}/academic-context/current',
        ),
      );
      final termId = _termIdFromContext(context);
      if (termId == null) {
        throw const FinanceApiException(
          'No current academic term is configured for this school.',
        );
      }
      resolvedTermId = termId;

      final termQuery = <String, String>{
        'academicTermId': '$termId',
        'page': '0',
        'size': '200',
      };
      final results = await Future.wait<dynamic>([
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/overview',
          query: {'academicTermId': '$termId'},
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/requisitions',
          query: termQuery,
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/transactions',
          query: termQuery,
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/reconciliations',
          query: termQuery,
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/follow-ups',
          query: termQuery,
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/top-ups',
          query: termQuery,
        ),
      ]);

      if (!mounted) return;
      final overview = _asMap(results[0]);
      final cycle = _asMap(overview['cycle']);
      final pockets = _asMap(overview['pockets']);
      final transactions = _transactionRecords(results[2]);
      setState(() {
        _academicTermId = termId;
        _settings = _settingsFromCycle(cycle);
        _float = _PettyCashFloat(
          cashBalance: _asDouble(pockets['cash'] ?? cycle['cashBalance']),
          momoBalance: _asDouble(pockets['momo'] ?? cycle['momoBalance']),
          status: _floatStatus(cycle['status']),
        );
        _requisitions = _requisitionRecords(results[1]);
        _expenses = transactions;
        _pocketTransfers = _transferRecords(results[2]);
        _topUps = _topUpRecords(results[5]);
        _reconciliations = _reconciliationRecords(results[3]);
        _financialFollowUps = _followUpRecords(results[4]);
        _isLoadingFinance = false;
        _requiresCycleSetup = false;
        _financeLoadError = null;
      });
    } on FinanceApiException catch (error) {
      if (!mounted) return;
      final requiresCycleSetup = error.message.toLowerCase().contains(
        'set up the petty-cash cycle',
      );
      setState(() {
        _isLoadingFinance = false;
        _academicTermId = resolvedTermId ?? _academicTermId;
        _requiresCycleSetup = requiresCycleSetup;
        _financeLoadError = requiresCycleSetup ? null : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingFinance = false;
        _financeLoadError =
            'Unable to load expenses and petty cash data from the server.';
      });
    }
  }

  Widget _buildCycleSetupState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 46,
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Set up petty cash for this term',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This academic term does not yet have a petty-cash cycle. '
                    'Configure the float controls before recording expenses, '
                    'transfers, top-ups, or reconciliations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _openCycleSetupDialog,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Set up cycle'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openCycleSetupDialog() async {
    final approvedController = TextEditingController();
    final ceilingController = TextEditingController();
    final thresholdController = TextEditingController();
    final momoController = TextEditingController();
    final toleranceController = TextEditingController(text: '5');
    final expiryController = TextEditingController(text: '7');
    var captureTransactionFees = true;
    var selfDisburse = false;
    var isSaving = false;
    String? errorMessage;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !isSaving,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Set up petty-cash cycle'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'These controls apply only to the current academic term.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _cycleAmountField(
                            controller: approvedController,
                            label: 'Approved float (GH¢)',
                            hint: 'e.g. 1000',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _cycleAmountField(
                            controller: ceilingController,
                            label: 'Float ceiling (GH¢)',
                            hint: 'e.g. 1500',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _cycleAmountField(
                            controller: thresholdController,
                            label: 'Refill threshold (GH¢)',
                            hint: 'e.g. 400',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _cycleAmountField(
                            controller: toleranceController,
                            label: 'Variance tolerance (%)',
                            hint: 'e.g. 5',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _cycleTextField(
                      controller: momoController,
                      label: 'MoMo wallet number (optional)',
                      hint: 'e.g. 024 000 0000',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    _cycleTextField(
                      controller: expiryController,
                      label: 'Requisition expiry (days)',
                      hint: 'e.g. 7',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Capture transaction fees'),
                      subtitle: const Text(
                        'Record MoMo and bank charges separately from expenses.',
                      ),
                      value: captureTransactionFees,
                      onChanged: isSaving
                          ? null
                          : (value) => setDialogState(
                              () => captureTransactionFees = value,
                            ),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow self-disbursement'),
                      subtitle: const Text(
                        'Permit an approved requester to disburse funds.',
                      ),
                      value: selfDisburse,
                      onChanged: isSaving
                          ? null
                          : (value) =>
                                setDialogState(() => selfDisburse = value),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final approved = _strictAmount(approvedController.text);
                        final ceiling = _strictAmount(ceilingController.text);
                        final threshold = _strictAmount(
                          thresholdController.text,
                        );
                        final tolerance = _strictAmount(
                          toleranceController.text,
                        );
                        final expiry = int.tryParse(
                          expiryController.text.trim(),
                        );
                        final validationError =
                            approved == null ||
                                ceiling == null ||
                                threshold == null ||
                                tolerance == null ||
                                expiry == null
                            ? 'Enter valid non-negative amounts and an expiry period.'
                            : threshold > ceiling
                            ? 'The refill threshold cannot exceed the float ceiling.'
                            : expiry < 1
                            ? 'Requisition expiry must be at least one day.'
                            : null;
                        if (validationError != null) {
                          setDialogState(() => errorMessage = validationError);
                          return;
                        }

                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });
                        try {
                          await _financeApi.put(
                            '/api/schools/${widget.customSchoolId}/finance/cycles/${_academicTermId!}',
                            body: {
                              'floatApprovedAmount': approved,
                              'floatCeiling': ceiling,
                              'floatThreshold': threshold,
                              'momoWalletNumber': momoController.text.trim(),
                              'captureTransactionFees': captureTransactionFees,
                              'selfDisburse': selfDisburse,
                              'varianceTolerancePercent': tolerance,
                              'requisitionExpiryDays': expiry,
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (!mounted) return;
                          await _loadFinanceWorkspace();
                          if (mounted) {
                            _snack('Petty-cash cycle set up for this term.');
                          }
                        } on FinanceApiException catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = error.message;
                            });
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage =
                                  'The petty-cash cycle could not be saved.';
                            });
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save cycle'),
              ),
            ],
          ),
        ),
      );
    } finally {
      approvedController.dispose();
      ceilingController.dispose();
      thresholdController.dispose();
      momoController.dispose();
      toleranceController.dispose();
      expiryController.dispose();
    }
  }

  Widget _cycleAmountField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) => _cycleTextField(
    controller: controller,
    label: label,
    hint: hint,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
  );

  Widget _cycleTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );

  double? _strictAmount(String value) {
    final parsed = double.tryParse(
      value.replaceAll(',', '').replaceAll('GH¢', '').trim(),
    );
    return parsed == null || parsed < 0 ? null : parsed;
  }

  Future<bool> _runFinanceMutation({
    required Future<dynamic> Function() request,
    required String successMessage,
  }) async {
    try {
      await request();
      await _loadFinanceWorkspace(showLoading: false);
      if (mounted) _snack(successMessage);
      return true;
    } on FinanceApiException catch (error) {
      if (mounted) _snack(error.message);
      return false;
    } catch (_) {
      if (mounted) _snack('The finance action could not be completed.');
      return false;
    }
  }

  int? _termIdFromContext(Map<String, dynamic> context) {
    for (final candidate in [
      context,
      _asMap(context['academicTerm']),
      _asMap(context['currentAcademicTerm']),
      _asMap(context['term']),
    ]) {
      final id = _asInt(candidate['id'] ?? candidate['academicTermId']);
      if (id > 0) return id;
    }
    return null;
  }

  _SchoolExpenseSettings _settingsFromCycle(Map<String, dynamic> cycle) {
    return _SchoolExpenseSettings(
      floatApprovedAmount: _asDouble(cycle['floatApprovedAmount']),
      floatCeiling: _asDouble(cycle['floatCeiling']),
      floatThreshold: _asDouble(cycle['floatThreshold']),
      captureTransactionFees: _asBool(cycle['captureTransactionFees']),
      selfDisburse: _asBool(cycle['selfDisburse']),
      varianceTolerancePercent: _asInt(cycle['varianceTolerancePercent']),
      requisitionExpiryDays: _asInt(cycle['requisitionExpiryDays']),
      momoWalletNumber: _asText(cycle['momoWalletNumber']),
    );
  }

  List<_ExpenseRecord> _transactionRecords(dynamic response) {
    final records = _pageContent(response)
        .where((value) => _isExpenseTransaction(_asMap(value)))
        .map((value) => _expenseFromMap(_asMap(value)))
        .toList();
    final byServerId = <int, _ExpenseRecord>{
      for (final record in records)
        if (record.serverId != null) record.serverId!: record,
    };
    for (final refund in records.where((item) => item.amount < 0)) {
      final parentId = int.tryParse(refund.linkedExpenseId ?? '');
      final original = parentId == null ? null : byServerId[parentId];
      if (original != null) {
        original.refundedAmount += refund.amount.abs();
        original.status = original.refundableAmount == 0
            ? _ExpenseStatus.fullyRefunded
            : _ExpenseStatus.partiallyRefunded;
      }
    }
    return records;
  }

  bool _isExpenseTransaction(Map<String, dynamic> value) {
    final type = _asText(value['transactionType']).toUpperCase();
    return type.contains('EXPENSE') ||
        type.contains('SPEND') ||
        type.contains('DIRECT');
  }

  _ExpenseRecord _expenseFromMap(Map<String, dynamic> value) {
    final status = _expenseStatus(value['status']);
    final channel = _paymentChannel(value['paymentChannel']);
    final sourcePocket = _asText(value['sourcePocket']).toUpperCase();
    return _ExpenseRecord(
      serverId: _nullableServerId(value['id']),
      expenseId: _asText(value['transactionCode'] ?? value['id']),
      requisitionId: _nullableText(value['requisitionId']),
      description: _asText(value['description']),
      category: _asText(value['category'], fallback: 'Uncategorised'),
      payee: _asText(value['vendor'], fallback: 'Not provided'),
      amount: _asDouble(
        value['actualAmount'] ??
            value['approvedAmount'] ??
            value['requestedAmount'],
      ),
      approvedAmount: _nullableDouble(value['approvedAmount']),
      transactionDate: _asDate(value['transactionDate'] ?? value['createdAt']),
      source: sourcePocket.contains('CASH') || sourcePocket.contains('MOMO')
          ? _ExpenseSource.pettyCash
          : _ExpenseSource.direct,
      channel: channel,
      status: status,
      receiptNumber: _asText(value['receiptNumber']),
      notes: _asText(value['notes']),
      linkedExpenseId: _nullableText(value['parentTransactionId']),
      momoFee: _asDouble(value['feeAmount']),
      isEmergency: _asBool(value['emergency']),
      approvalStatus: _asBool(value['requiresRatification'])
          ? _ExpenseApprovalStatus.pendingRatification
          : status == _ExpenseStatus.ratified
          ? _ExpenseApprovalStatus.ratified
          : _ExpenseApprovalStatus.approved,
      varianceStatus:
          _asBool(value['varianceWarning']) ||
              status == _ExpenseStatus.pendingVarianceReview
          ? _VarianceStatus.pendingReview
          : _VarianceStatus.none,
    );
  }

  List<_RequisitionRecord> _requisitionRecords(dynamic response) {
    return _pageContent(response).map((value) {
      final item = _asMap(value);
      return _RequisitionRecord(
        serverId: _nullableServerId(item['id']),
        id: _asText(item['requisitionCode'] ?? item['id']),
        title: _asText(item['description']),
        category: _asText(item['category'], fallback: 'Uncategorised'),
        payee: _asText(item['vendor'], fallback: 'Not provided'),
        requestedBy: _asText(item['requestedBy'], fallback: 'Not provided'),
        approvedAmount: _asDouble(
          item['approvedAmount'] ?? item['requestedAmount'],
        ),
        requestedAt: _asDate(item['requestedAt'] ?? item['createdAt']),
        expiresAt: _asDate(item['expiresAt']),
        status: _requisitionStatus(item['status']),
        notes: _asText(item['notes'] ?? item['reason']),
        isEmergency: _asBool(item['emergency']),
        verbalApprover: _nullableText(item['verbalApprover']),
      );
    }).toList();
  }

  List<_TopUpRequest> _topUpRecords(dynamic response) {
    return _pageContent(response).map((value) {
      final item = _asMap(value);
      final status = _topUpStatus(item['status']);
      return _TopUpRequest(
        serverId: _nullableServerId(item['id']),
        requestId: _asText(
          item['transactionCode'] ??
              item['topUpCode'] ??
              item['requestCode'] ??
              item['id'],
        ),
        requestedAmount: _asDouble(item['requestedAmount']),
        approvedAmount:
            status == _TopUpStatus.pending ||
                status == _TopUpStatus.queried ||
                status == _TopUpStatus.declined
            ? null
            : _nullableDouble(item['approvedAmount']),
        requestedAt: _asDate(item['requestedAt'] ?? item['createdAt']),
        expensesCount: _asInt(item['expensesCount']),
        status: status,
        approvalCode: _nullableText(item['approvalCode']),
        approvedAt: _nullableDate(item['approvedAt']),
        confirmedAt: _nullableDate(item['confirmedAt']),
        actualReceived: _nullableDouble(
          item['actualAmount'] ?? item['actualReceived'],
        ),
      );
    }).toList();
  }

  List<_PocketTransfer> _transferRecords(dynamic response) {
    return _pageContent(response)
        .where(
          (value) => _asText(
            _asMap(value)['transactionType'],
          ).toUpperCase().contains('TRANSFER'),
        )
        .map((value) {
          final item = _asMap(value);
          return _PocketTransfer(
            id: _asText(item['transactionCode'] ?? item['id']),
            fromPocket: _asText(item['sourcePocket']),
            toPocket: _asText(item['destinationPocket']),
            amount: _asDouble(item['actualAmount'] ?? item['requestedAmount']),
            fee: _asDouble(item['feeAmount']),
            reference: _asText(item['receiptNumber'] ?? item['notes']),
            date: _asDate(item['transactionDate'] ?? item['createdAt']),
          );
        })
        .toList();
  }

  List<_ReconciliationRecord> _reconciliationRecords(dynamic response) {
    return _pageContent(response).map((value) {
      final item = _asMap(value);
      return _ReconciliationRecord(
        serverId: _nullableServerId(item['id']),
        reference: _asText(item['reconciliationCode'] ?? item['id']),
        requestedAt: _asDate(item['requestedAt'] ?? item['createdAt']),
        requestedBy: _asText(item['requestedBy'], fallback: 'Not provided'),
        assignedTo: _asText(item['assignedTo'], fallback: 'Not assigned'),
        reason: _asText(item['reason']),
        status: _reconciliationStatus(item['status']),
        expectedCash: _nullableDouble(item['expectedCash']),
        expectedMomo: _nullableDouble(item['expectedMomo']),
        startedAt: _nullableDate(item['startedAt']),
        startedBy: _nullableText(item['startedBy']),
        actualCash: _nullableDouble(item['actualCash']),
        actualMomo: _nullableDouble(item['actualMomo']),
        confirmedAt: _nullableDate(item['confirmedAt']),
        confirmedBy: _nullableText(item['confirmedBy']),
        notes: _asText(item['resolutionNotes']),
        varianceResolution: _asText(item['resolutionType']),
        varianceResolvedAt: _nullableDate(item['closedAt']),
        varianceResolvedBy: _nullableText(item['closedBy']),
      );
    }).toList();
  }

  List<_FinancialFollowUp> _followUpRecords(dynamic response) {
    return _pageContent(response).map((value) {
      final item = _asMap(value);
      return _FinancialFollowUp(
        reference: _asText(item['followUpCode'] ?? item['id']),
        type: _followUpType(item['type']),
        relatedReference: _asText(
          item['reconciliationId'] ?? item['transactionId'],
          fallback: 'Not linked',
        ),
        owner: _asText(item['responsibleParty'], fallback: 'Not assigned'),
        amount: _asDouble(item['amount']),
        createdAt: _asDate(item['createdAt']),
        summary: _asText(item['description']),
        status: _followUpStatus(item['status']),
        notes: _asText(item['resolutionNotes']).isEmpty
            ? []
            : [
                _FollowUpNote(
                  author: _asText(item['closedBy'], fallback: 'System'),
                  createdAt: _asDate(item['closedAt'] ?? item['createdAt']),
                  text: _asText(item['resolutionNotes']),
                  isResolution: true,
                ),
              ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFinance) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_requiresCycleSetup && _academicTermId != null) {
      return _buildCycleSetupState();
    }
    if (_financeLoadError != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 42,
                      color: AppColors.red,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Unable to load expenses and petty cash',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _financeLoadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _loadFinanceWorkspace,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final activeReconciliation = _activeReconciliation;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_financeLedgerPage == null) ...[
            const SizedBox(height: 18),
            _buildPolicyBanner(),
            const SizedBox(height: 18),
            _buildTabs(),
            if (activeReconciliation != null) ...[
              const SizedBox(height: 16),
              _InlineNotice(
                icon: Icons.info_outline,
                color: AppColors.blue,
                text:
                    'A reconciliation count is in progress (${activeReconciliation.reference}). Record any new Cash or MoMo movement carefully. Restart the count if the system balance changes before it is confirmed.',
              ),
            ],
            const SizedBox(height: 22),
            _buildCurrentTab(),
          ] else ...[
            const SizedBox(height: 26),
            _buildFinanceLedgerPage(),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceLedgerPage() {
    switch (_financeLedgerPage!) {
      case _FinanceLedgerPage.topUps:
        return _buildTopUpLedgerPage();
      case _FinanceLedgerPage.topUpDetail:
        final topUp = _selectedTopUp;
        return topUp == null
            ? _buildTopUpLedgerPage()
            : _buildTopUpDetailPage(topUp);
      case _FinanceLedgerPage.transfers:
        return _buildTransferLedgerPage();
      case _FinanceLedgerPage.reconciliationDetail:
        final reconciliation = _selectedReconciliation;
        return reconciliation == null
            ? _buildReconciliationsTab()
            : _buildReconciliationDetailPage(reconciliation);
    }
  }

  Widget _buildLedgerBackButton(String label, {VoidCallback? onPressed}) {
    return TextButton.icon(
      onPressed: onPressed ?? () => setState(() => _financeLedgerPage = null),
      icon: const Icon(Icons.arrow_back_rounded),
      label: Text(label),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Expenses & Petty Cash',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Requisitions, petty cash, approvals, refunds, and audit-ready spending for ${widget.customSchoolId}.',
                style: const TextStyle(fontSize: 15, color: _muted),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _openReconciliationRequestDialog,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Request reconciliation'),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _openCreateRequisitionDialog,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('New requisition'),
          style: _primaryButtonStyle(),
        ),
      ],
    );
  }

  Widget _buildPolicyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        border: Border.all(color: const Color(0xFFFFDCA3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.rule_folder_outlined, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rule in use: petty cash is auto-approved only when the selected pocket has balance, amount is within ${_money(_settings.floatCeiling)}, and the float cycle is active. Direct spending must start as a requisition.',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tab in _ExpenseTab.values)
            _TabPill(
              label: tab.label,
              active: _tab == tab,
              onTap: () => setState(() => _tab = tab),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_tab) {
      case _ExpenseTab.overview:
        return _buildOverviewTab();
      case _ExpenseTab.expenses:
        return _buildExpensesTab();
      case _ExpenseTab.requisitions:
        return _buildRequisitionsTab();
      case _ExpenseTab.pettyCash:
        return _buildPettyCashTab();
      case _ExpenseTab.approvals:
        return _buildApprovalsTab();
      case _ExpenseTab.reconciliations:
        return _buildReconciliationsTab();
      case _ExpenseTab.followUps:
        return _buildFinancialFollowUpsTab();
      case _ExpenseTab.reports:
        return _buildReportsTab();
    }
  }

  Widget _buildOverviewTab() {
    final alerts = _buildAttentionItems();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 48) / 4;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  width: cardWidth.clamp(220, 420).toDouble(),
                  title: 'Float balance',
                  value: _money(_totalFloatBalance),
                  subtitle:
                      'Cash ${_money(_cashBalance)} · MoMo ${_money(_momoBalance)}',
                  icon: Icons.account_balance_wallet_outlined,
                  color: _green,
                ),
                _MetricCard(
                  width: cardWidth.clamp(220, 420).toDouble(),
                  title: 'Term spend',
                  value: _money(_totalSpend),
                  subtitle:
                      'Petty ${_money(_pettySpend)} · Direct ${_money(_directSpend)}',
                  icon: Icons.payments_outlined,
                  color: AppColors.blue,
                ),
                _MetricCard(
                  width: cardWidth.clamp(220, 420).toDouble(),
                  title: 'Pending approvals',
                  value: '$_pendingApprovalCount',
                  subtitle: 'Requisitions, top-ups, ratifications',
                  icon: Icons.approval_outlined,
                  color: AppColors.amber,
                ),
                _MetricCard(
                  width: cardWidth.clamp(220, 420).toDouble(),
                  title: 'Direct spend',
                  value: _money(_directSpend),
                  subtitle:
                      '${_settings.varianceTolerancePercent}% variance tolerance',
                  icon: Icons.account_balance_outlined,
                  color: AppColors.purple,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _SectionCard(
                title: 'Recent expense register',
                trailing: TextButton(
                  onPressed: () => setState(() => _tab = _ExpenseTab.expenses),
                  child: const Text('View all'),
                ),
                child: Column(
                  children: _expenses.take(5).map(_expenseListTile).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 5,
              child: _SectionCard(
                title: 'Attention required',
                child: Column(
                  children: alerts
                      .map(
                        (alert) => _ActionTile(
                          icon: alert.icon,
                          iconColor: alert.color,
                          title: alert.title,
                          subtitle: alert.description,
                          onTap: () => setState(() => _tab = alert.targetTab),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<_AttentionItem> _buildAttentionItems() {
    final items = <_AttentionItem>[];
    if (_float.status == _FloatStatus.active &&
        _totalFloatBalance <= _settings.floatThreshold) {
      items.add(
        _AttentionItem(
          icon: Icons.warning_amber_rounded,
          color: AppColors.amber,
          title: 'Float is close to threshold',
          description:
              'Current balance is ${_money(_totalFloatBalance)}. Threshold is ${_money(_settings.floatThreshold)}.',
          targetTab: _ExpenseTab.pettyCash,
        ),
      );
    }
    final pendingRatifications = _expenses
        .where((item) => item.status == _ExpenseStatus.pendingRatification)
        .length;
    if (pendingRatifications > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.gavel_outlined,
          color: AppColors.red,
          title:
              '$pendingRatifications spend variance waiting for ratification',
          description:
              'Actual spend exceeded the approved amount within tolerance.',
          targetTab: _ExpenseTab.approvals,
        ),
      );
    }
    final pendingTopUps = _topUps
        .where((item) => item.status == _TopUpStatus.pending)
        .length;
    if (pendingTopUps > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.sync_alt_outlined,
          color: AppColors.blue,
          title: '$pendingTopUps replenishment request pending',
          description: 'Review top-up request before the next disbursement.',
          targetTab: _ExpenseTab.approvals,
        ),
      );
    }
    final pendingReconciliations = _reconciliations
        .where((item) => item.status == _ReconciliationStatus.requested)
        .length;
    if (pendingReconciliations > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.fact_check_outlined,
          color: AppColors.amber,
          title:
              '$pendingReconciliations reconciliation request awaiting start',
          description:
              'An assigned staff member needs to begin the cash and MoMo count.',
          targetTab: _ExpenseTab.reconciliations,
        ),
      );
    }
    final emergency = _expenses.where((item) => item.isEmergency).length;
    if (emergency > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.emergency_outlined,
          color: AppColors.red,
          title: '$emergency emergency expense recorded',
          description: 'Emergency spending requires written ratification.',
          targetTab: _ExpenseTab.approvals,
        ),
      );
    }
    if (items.isEmpty) {
      items.add(
        const _AttentionItem(
          icon: Icons.check_circle_outline,
          color: _green,
          title: 'No urgent finance action',
          description:
              'Float, requisitions, and expense approvals are up to date.',
          targetTab: _ExpenseTab.overview,
        ),
      );
    }
    return items;
  }

  Widget _buildExpensesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Expense register',
          subtitle:
              'Read-only history of recorded spending. Open an entry to review its linked requisition, receipt, approval trail, or refund.',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _expenseQuery = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search expense, payee, category, or receipt',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Dropdown<String>(
                    width: 180,
                    value: _expenseFilter,
                    items: const [
                      'All',
                      'Petty Cash',
                      'Direct',
                      'Emergency',
                      'Refunded',
                    ],
                    onChanged: (value) =>
                        setState(() => _expenseFilter = value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ExpenseTable(
                expenses: _visibleExpenses,
                onRefund: _openRefundDialog,
                onView: _openExpenseDetailDialog,
                onPrint: _printExpenseRecord,
                onDownload: _downloadExpenseCopy,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequisitionsTab() {
    return _SectionCard(
      title: 'Requisitions',
      subtitle:
          'Requests made before direct spending. Approved requests can later be fulfilled with the actual payment amount.',
      trailing: FilledButton.icon(
        onPressed: _openCreateRequisitionDialog,
        icon: const Icon(Icons.add),
        label: const Text('New requisition'),
        style: _primaryButtonStyle(),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Direct cash, bank, cheque, and MoMo spending should begin here before money leaves the school.',
                  style: TextStyle(color: _muted),
                ),
              ),
              _Dropdown<String>(
                width: 190,
                value: _requisitionFilter,
                items: const [
                  'All',
                  'Pending',
                  'Approved',
                  'Rejected',
                  'Cancelled',
                  'Revised',
                  'Expired',
                  'Fulfilled',
                ],
                onChanged: (value) =>
                    setState(() => _requisitionFilter = value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _RequisitionTable(
            requisitions: _visibleRequisitions,
            onOpen: _openRequisitionWorkspace,
          ),
        ],
      ),
    );
  }

  Widget _buildPettyCashTab() {
    final activeTopUps = _topUps
        .where((item) => !item.status.isHistorical)
        .take(2)
        .toList();
    final recentTopUps = _topUps
        .where((item) => item.status.isHistorical)
        .take(2)
        .toList();
    final approvedAmount = _settings.floatApprovedAmount;
    final double balanceRatio = approvedAmount <= 0
        ? 0.0
        : (_totalFloatBalance / approvedAmount).clamp(0.0, 1.0).toDouble();
    final remainingPercent = (balanceRatio * 100).round();
    final isCritical = _totalFloatBalance <= _settings.floatThreshold;
    final isLow =
        !isCritical && _totalFloatBalance <= _settings.floatThreshold * 1.5;
    final balanceColor = isCritical
        ? AppColors.red
        : isLow
        ? AppColors.amber
        : AppColors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total pocket balance',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _money(_totalFloatBalance),
                            style: TextStyle(
                              color: balanceColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 34,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'of ${_money(approvedAmount)} approved float · $remainingPercent% remaining',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openPocketTransferDialog,
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Transfer pocket'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openReconciliationRequestDialog,
                          icon: const Icon(Icons.fact_check_outlined),
                          label: const Text('Request reconciliation'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: balanceRatio,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(balanceColor),
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final pocketWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 14) / 2;
                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: pocketWidth,
                          child: _FloatPocketCard(
                            title: 'Cash pocket',
                            amount: _cashBalance,
                            subtitle: 'Physical cash box held by the bursar',
                            icon: Icons.payments_outlined,
                            accent: const Color(0xFFB7791F),
                            background: const Color(0xFFFFFDF5),
                            borderColor: const Color(0xFFF4E2B0),
                          ),
                        ),
                        SizedBox(
                          width: pocketWidth,
                          child: _FloatPocketCard(
                            title: 'MoMo pocket',
                            amount: _momoBalance,
                            subtitle: _settings.momoWalletNumber,
                            icon: Icons.phone_android_outlined,
                            accent: const Color(0xFF008B7A),
                            background: const Color(0xFFF0FBF8),
                            borderColor: const Color(0xFFBCE6DF),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    border: Border.all(color: const Color(0xFFBCE6DF)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 660;
                      final limits = [
                        _FloatLimit(
                          label: 'Status',
                          value: _float.status.label,
                        ),
                        _FloatLimit(
                          label: 'Single expense ceiling',
                          value: _money(_settings.floatCeiling),
                        ),
                        _FloatLimit(
                          label: 'Top-up threshold',
                          value: _money(_settings.floatThreshold),
                        ),
                      ];
                      return isCompact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final limit in limits) ...[
                                  _FloatLimitView(limit: limit),
                                  if (limit != limits.last)
                                    const SizedBox(height: 10),
                                ],
                              ],
                            )
                          : Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < limits.length;
                                  index++
                                ) ...[
                                  Expanded(
                                    child: _FloatLimitView(
                                      limit: limits[index],
                                    ),
                                  ),
                                  if (index < limits.length - 1)
                                    Container(
                                      height: 34,
                                      width: 1,
                                      color: const Color(0xFFBCE6DF),
                                    ),
                                ],
                              ],
                            );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildReconciliationControl(),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Top-up requests',
          subtitle:
              'A short view of active replenishment requests. Full history is kept in its own ledger.',
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => setState(
                  () => _financeLedgerPage = _FinanceLedgerPage.topUps,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('View all'),
              ),
              FilledButton.icon(
                onPressed: _requestTopUp,
                icon: const Icon(Icons.add_card_outlined),
                label: const Text('Request top-up'),
                style: _primaryButtonStyle(),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activeTopUps.isNotEmpty) ...[
                const _SectionLabel('Current requests'),
                const SizedBox(height: 8),
                for (final topUp in activeTopUps) _topUpTile(topUp),
              ],
              if (recentTopUps.isNotEmpty) ...[
                if (activeTopUps.isNotEmpty) const SizedBox(height: 18),
                const _SectionLabel('Most recent completed'),
                const SizedBox(height: 8),
                for (final topUp in recentTopUps) _topUpTile(topUp),
              ],
              if (_topUps.isEmpty)
                const _EmptyState(
                  icon: Icons.add_card_outlined,
                  title: 'No top-up requests yet',
                  subtitle:
                      'When float needs replenishment, requests will appear here.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Recent pocket transfers',
          subtitle:
              'Cash and MoMo movements. Transfers do not change the total float except for any recorded fee.',
          trailing: TextButton.icon(
            onPressed: () => setState(
              () => _financeLedgerPage = _FinanceLedgerPage.transfers,
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('View all'),
          ),
          child: Column(
            children: _pocketTransfers
                .take(3)
                .map(_pocketTransferTile)
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReconciliationControl() {
    final open = _reconciliations
        .where(
          (item) =>
              item.status == _ReconciliationStatus.requested ||
              item.status == _ReconciliationStatus.inProgress,
        )
        .toList();
    final recent = _reconciliations
        .where(
          (item) =>
              item.status != _ReconciliationStatus.requested &&
              item.status != _ReconciliationStatus.inProgress,
        )
        .take(2)
        .toList();

    return _SectionCard(
      title: 'Reconciliation control',
      subtitle:
          'A reconciliation records the system balance against the cash and MoMo actually counted. It never changes a balance automatically.',
      trailing: FilledButton.icon(
        onPressed: () => setState(() => _tab = _ExpenseTab.reconciliations),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Open workspace'),
        style: _primaryButtonStyle(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (open.isNotEmpty) ...[
            const _SectionLabel('OPEN RECONCILIATION REQUESTS'),
            const SizedBox(height: 8),
            for (final item in open)
              _reconciliationTile(item, canConfirm: true),
          ] else
            const _InlineNotice(
              icon: Icons.check_circle_outline,
              color: AppColors.green,
              text: 'No reconciliation is currently open for staff action.',
            ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionLabel('RECENT RECONCILIATIONS'),
            const SizedBox(height: 8),
            for (final item in recent) _reconciliationTile(item),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialFollowUpsTab() {
    final records = _visibleFinancialFollowUps;
    final open = _financialFollowUps
        .where((item) => item.status == _FollowUpStatus.open)
        .length;
    final awaitingEvidence = _financialFollowUps
        .where((item) => item.status == _FollowUpStatus.awaitingEvidence)
        .length;
    final recoveries = _financialFollowUps
        .where(
          (item) => item.type == _FollowUpType.staffRecovery && !item.isClosed,
        )
        .length;
    final overdue = _financialFollowUps.where((item) => item.isOverdue).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Financial follow-ups',
          subtitle:
              'Operational exceptions that need evidence, recovery, correction, or an administrator decision. These are not ordinary expense entries.',
          trailing: FilledButton.icon(
            onPressed: _openNewFollowUpDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Record follow-up'),
            style: _primaryButtonStyle(),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final cardWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Open',
                      value: '$open',
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.amber,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Awaiting evidence',
                      value: '$awaitingEvidence',
                      icon: Icons.attach_file_outlined,
                      color: AppColors.blue,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Staff recoveries',
                      value: '$recoveries',
                      icon: Icons.person_search_outlined,
                      color: AppColors.red,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Overdue',
                      value: '$overdue',
                      icon: Icons.event_busy_outlined,
                      color: AppColors.red,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Follow-up register',
          subtitle:
              'Open a record to review its linked transaction, append notes, and close it with an administrator resolution.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  value: _followUpStatusFilter,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      const [
                            'All statuses',
                            'Open',
                            'Awaiting evidence',
                            'Under investigation',
                            'Partially recovered',
                            'Closed',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(
                    () => _followUpStatusFilter = value ?? 'All statuses',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const _EmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'No financial follow-ups found',
                  subtitle:
                      'Change the filter or record a new operational exception.',
                )
              else
                _TableShell(
                  columns: const [
                    'Reference',
                    'Type',
                    'Related to',
                    'Owner',
                    'Amount',
                    'Due date',
                    'Status',
                  ],
                  rows: records
                      .map(
                        (item) => [
                          _MainCell(
                            title: item.reference,
                            subtitle: item.summary,
                            onTap: () => _openFollowUpDetailDialog(item),
                          ),
                          Text(item.type.label),
                          Text(item.relatedReference),
                          Text(item.owner),
                          Text(_money(item.amount)),
                          Text(
                            item.dueDate == null
                                ? 'No due date'
                                : _date(item.dueDate!),
                          ),
                          _StatusPill(
                            label: item.status.label,
                            color: item.status.color,
                          ),
                        ],
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReconciliationsTab() {
    final records = _visibleReconciliations;
    final awaiting = _reconciliations
        .where((item) => item.status == _ReconciliationStatus.requested)
        .length;
    final inProgress = _reconciliations
        .where((item) => item.status == _ReconciliationStatus.inProgress)
        .length;
    final varianceOpen = _reconciliations
        .where((item) => item.status == _ReconciliationStatus.varianceOpen)
        .length;
    final closed = _reconciliations
        .where(
          (item) =>
              item.status == _ReconciliationStatus.confirmed ||
              item.status == _ReconciliationStatus.varianceClosed,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Reconciliations',
          subtitle:
              'Compare system pockets with counted cash and the MoMo wallet. Variances stay open until an administrator records a resolution.',
          trailing: FilledButton.icon(
            onPressed: _openReconciliationRequestDialog,
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Request reconciliation'),
            style: _primaryButtonStyle(),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final cardWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 36) / 4;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Awaiting start',
                      value: '$awaiting',
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.amber,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Count in progress',
                      value: '$inProgress',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.blue,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Variance needs closure',
                      value: '$varianceOpen',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.red,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _ReconciliationMetric(
                      label: 'Completed records',
                      value: '$closed',
                      icon: Icons.task_alt_outlined,
                      color: AppColors.green,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Reconciliation register',
          subtitle:
              'Filter records by status or request date. Newest requests appear first.',
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 780;
                  final filterWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: filterWidth,
                        child: DropdownButtonFormField<String>(
                          value: _reconciliationStatusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items:
                              const [
                                    'All statuses',
                                    'Requested',
                                    'In progress',
                                    'Confirmed',
                                    'Variance needs review',
                                    'Variance closed',
                                  ]
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => setState(
                            () => _reconciliationStatusFilter =
                                value ?? 'All statuses',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: filterWidth,
                        child: _DateFilterButton(
                          label: 'From date',
                          date: _reconciliationFromDate,
                          onPressed: () => _pickReconciliationDate(from: true),
                        ),
                      ),
                      SizedBox(
                        width: filterWidth,
                        child: _DateFilterButton(
                          label: 'To date',
                          date: _reconciliationToDate,
                          onPressed: () => _pickReconciliationDate(from: false),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_reconciliationFromDate != null ||
                  _reconciliationToDate != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _reconciliationFromDate = null;
                      _reconciliationToDate = null;
                    }),
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear date range'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (records.isEmpty)
                const _EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No reconciliations found',
                  subtitle: 'Change the filters or request a reconciliation.',
                )
              else
                _TableShell(
                  columns: const [
                    'Reference',
                    'Requested',
                    'Expected',
                    'Counted',
                    'Variance',
                    'Status',
                    'Actions',
                  ],
                  rows: records
                      .map(
                        (item) => [
                          _MainCell(
                            title: item.reference,
                            subtitle: item.reason.isEmpty
                                ? 'No reason supplied'
                                : item.reason,
                            onTap: () => _openReconciliationDetail(item),
                          ),
                          Text(
                            '${_date(item.requestedAt)}\n${item.requestedBy}',
                          ),
                          Text(
                            item.hasSnapshot
                                ? _money(item.expectedTotal)
                                : 'Not started',
                          ),
                          Text(
                            item.status == _ReconciliationStatus.requested ||
                                    item.status ==
                                        _ReconciliationStatus.inProgress
                                ? 'Awaiting count'
                                : _money(item.actualTotal),
                          ),
                          _reconciliationVarianceCell(item),
                          _StatusPill(
                            label: item.status.label,
                            color: item.status.color,
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openReconciliationDetail(item),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open'),
                          ),
                        ],
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reconciliationVarianceCell(_ReconciliationRecord item) {
    if (item.status == _ReconciliationStatus.requested ||
        item.status == _ReconciliationStatus.inProgress) {
      return const Text('Not counted', style: TextStyle(color: _muted));
    }
    final variance = item.totalVariance;
    if (variance == 0) {
      return const Text(
        'Matched',
        style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w800),
      );
    }
    return Text(
      '${variance > 0 ? 'Over' : 'Short'} ${_money(variance.abs())}',
      style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800),
    );
  }

  void _openReconciliationDetail(_ReconciliationRecord item) {
    setState(() {
      _selectedReconciliation = item;
      _financeLedgerPage = _FinanceLedgerPage.reconciliationDetail;
    });
  }

  Widget _buildReconciliationDetailPage(_ReconciliationRecord item) {
    final hasCount =
        item.status != _ReconciliationStatus.requested &&
        item.status != _ReconciliationStatus.inProgress;
    final hasVariance = hasCount && item.totalVariance != 0;
    final matchingFollowUps = _financialFollowUps
        .where((followUp) => followUp.relatedReference == item.reference)
        .toList();
    final linkedFollowUp = matchingFollowUps.isEmpty
        ? null
        : matchingFollowUps.first;

    Widget metric(
      String label,
      String value, {
      Color? valueColor,
      IconData? icon,
    }) {
      return Container(
        width: 214,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: valueColor ?? _green, size: 20),
              const SizedBox(height: 10),
            ],
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .35,
                color: _muted,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor ?? _text,
              ),
            ),
          ],
        ),
      );
    }

    Widget timelineItem(
      IconData icon,
      String title,
      String detail, {
      Color color = _muted,
      bool isLast = false,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
              if (!isLast) Container(width: 2, height: 36, color: _border),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(color: _muted)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLedgerBackButton(
          'Back to reconciliations',
          onPressed: () => setState(() {
            _selectedReconciliation = null;
            _financeLedgerPage = null;
            _tab = _ExpenseTab.reconciliations;
          }),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Reconciliation ${item.reference}',
          subtitle:
              'Requested by ${item.requestedBy} for ${item.assignedTo} on ${_date(item.requestedAt)}.',
          trailing: _StatusPill(
            label: item.status.label,
            color: item.status.color,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  metric(
                    'Expected total',
                    item.hasSnapshot
                        ? _money(item.expectedTotal)
                        : 'Not captured',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  metric(
                    'Counted total',
                    hasCount ? _money(item.actualTotal) : 'Awaiting count',
                    icon: Icons.fact_check_outlined,
                    valueColor: hasCount ? _green : _muted,
                  ),
                  metric(
                    'Variance',
                    hasCount
                        ? item.totalVariance == 0
                              ? 'Matched'
                              : '${item.totalVariance > 0 ? 'Over' : 'Short'} ${_money(item.totalVariance.abs())}'
                        : 'Not available',
                    icon: Icons.balance_outlined,
                    valueColor: !hasCount || item.totalVariance == 0
                        ? _muted
                        : AppColors.red,
                  ),
                  metric(
                    'Assigned custodian',
                    item.assignedTo,
                    icon: Icons.person_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'RECONCILIATION RECORD',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 4),
              _ReadOnlyRow(
                'Request reason',
                item.reason.isEmpty ? 'Not provided' : item.reason,
              ),
              _ReadOnlyRow(
                'System balance at count start',
                item.hasSnapshot
                    ? 'Cash ${_money(item.expectedCash!)} · MoMo ${_money(item.expectedMomo!)}'
                    : 'Captured only when the custodian starts the count.',
              ),
              _ReadOnlyRow(
                'Physical count',
                hasCount
                    ? 'Cash ${_money(item.actualCash!)} · MoMo ${_money(item.actualMomo!)}'
                    : 'Not yet confirmed',
              ),
              _ReadOnlyRow(
                'Evidence reference',
                item.evidenceReference.trim().isEmpty
                    ? 'No evidence reference attached'
                    : item.evidenceReference,
              ),
              _ReadOnlyRow(
                'Confirmation notes',
                item.notes.trim().isEmpty
                    ? 'No confirmation notes added'
                    : item.notes,
              ),
              if (item.varianceResolution.isNotEmpty)
                _ReadOnlyRow('Variance resolution', item.varianceResolution),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Timeline',
          subtitle: 'A retained audit trail for this reconciliation record.',
          child: Column(
            children: [
              timelineItem(
                Icons.add_task_outlined,
                'Reconciliation requested',
                '${item.requestedBy} · ${_date(item.requestedAt)}',
                color: AppColors.amber,
                isLast: item.startedAt == null,
              ),
              if (item.startedAt != null)
                timelineItem(
                  Icons.play_circle_outline_rounded,
                  'Count started',
                  '${item.startedBy ?? item.assignedTo} · ${_date(item.startedAt!)}',
                  color: AppColors.blue,
                  isLast: item.confirmedAt == null,
                ),
              if (item.confirmedAt != null)
                timelineItem(
                  Icons.fact_check_outlined,
                  'Balances confirmed',
                  '${item.confirmedBy ?? item.assignedTo} · ${_date(item.confirmedAt!)}',
                  color: hasVariance ? AppColors.red : AppColors.green,
                  isLast: item.varianceResolvedAt == null,
                ),
              if (item.varianceResolvedAt != null)
                timelineItem(
                  Icons.task_alt_outlined,
                  'Variance resolved',
                  '${item.varianceResolvedBy ?? 'Administrator'} · ${_date(item.varianceResolvedAt!)}',
                  color: AppColors.green,
                  isLast: true,
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: item.status == _ReconciliationStatus.varianceOpen
              ? 'Variance action required'
              : 'Next action',
          subtitle: item.status == _ReconciliationStatus.requested
              ? 'The assigned custodian should start the physical count when ready.'
              : item.status == _ReconciliationStatus.inProgress
              ? 'Record the counted Cash and MoMo amounts with supporting evidence.'
              : item.status == _ReconciliationStatus.varianceOpen
              ? 'An administrator must document how the variance will be handled.'
              : item.status == _ReconciliationStatus.varianceClosed
              ? 'The reconciliation is closed. Its linked financial follow-up remains available for tracking.'
              : 'The counted balance matches the system balance. No further action is needed.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (item.status == _ReconciliationStatus.requested)
                FilledButton.icon(
                  onPressed: () => _startReconciliation(item),
                  style: _primaryButtonStyle(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start count'),
                ),
              if (item.status == _ReconciliationStatus.inProgress)
                FilledButton.icon(
                  onPressed: () => _openReconciliationConfirmationDialog(item),
                  style: _primaryButtonStyle(),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Confirm balances'),
                ),
              if (item.status == _ReconciliationStatus.varianceOpen)
                FilledButton.icon(
                  onPressed: () => _openVarianceClosureDialog(item),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: const Text('Close variance'),
                ),
              if (linkedFollowUp != null)
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _selectedReconciliation = null;
                    _financeLedgerPage = null;
                    _tab = _ExpenseTab.followUps;
                  }),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text('Open ${linkedFollowUp.reference}'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reconciliationTile(
    _ReconciliationRecord item, {
    bool canConfirm = false,
  }) {
    final variance = item.totalVariance;
    final varianceLabel = item.status == _ReconciliationStatus.requested
        ? 'Not started'
        : item.status == _ReconciliationStatus.inProgress
        ? 'Count in progress'
        : item.status == _ReconciliationStatus.varianceClosed
        ? 'Variance closed'
        : variance == 0
        ? 'Balances match'
        : '${variance > 0 ? 'Over' : 'Short'} ${_money(variance.abs())}';
    final varianceColor = item.status == _ReconciliationStatus.requested
        ? AppColors.muted
        : item.status == _ReconciliationStatus.inProgress
        ? AppColors.blue
        : item.status == _ReconciliationStatus.varianceClosed || variance == 0
        ? AppColors.green
        : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: item.status == _ReconciliationStatus.requested
            ? const Color(0xFFFFF8E8)
            : item.status == _ReconciliationStatus.inProgress
            ? const Color(0xFFF0F6FF)
            : const Color(0xFFF8FAFA),
        border: Border.all(
          color: item.status == _ReconciliationStatus.requested
              ? const Color(0xFFFFDCA3)
              : item.status == _ReconciliationStatus.inProgress
              ? const Color(0xFFB9D6FF)
              : _border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: item.status.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.reference,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _StatusPill(
                      label: item.status.label,
                      color: item.status.color,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.status == _ReconciliationStatus.requested
                      ? 'Requested by ${item.requestedBy} for ${item.assignedTo} · ${_date(item.requestedAt)}'
                      : item.status == _ReconciliationStatus.inProgress
                      ? 'Count started by ${item.startedBy} · ${_date(item.startedAt!)}'
                      : 'Confirmed by ${item.confirmedBy} · ${_date(item.confirmedAt!)}',
                  style: const TextStyle(color: _muted),
                ),
                if (item.reason.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(item.reason, style: const TextStyle(color: _muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                varianceLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: varianceColor,
                ),
              ),
              if (canConfirm &&
                  item.status == _ReconciliationStatus.requested) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _startReconciliation(item),
                  child: const Text('Start count'),
                ),
              ],
              if (canConfirm &&
                  item.status == _ReconciliationStatus.inProgress) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _openReconciliationConfirmationDialog(item),
                  child: const Text('Confirm balances'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopUpLedgerPage() {
    final topUps = _visibleTopUps;
    final maxPage = topUps.isEmpty ? 0 : (topUps.length - 1) ~/ _ledgerPageSize;
    final page = _topUpPage.clamp(0, maxPage);
    final pageItems = topUps
        .skip(page * _ledgerPageSize)
        .take(_ledgerPageSize)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLedgerBackButton('Back to petty cash'),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Top-up history',
          subtitle:
              'Every replenishment request and its approval, disbursement, or confirmation record.',
          trailing: FilledButton.icon(
            onPressed: _requestTopUp,
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Request top-up'),
            style: _primaryButtonStyle(),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() {
                        _topUpQuery = value;
                        _topUpPage = 0;
                      }),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search request ID or approval code',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _Dropdown<String>(
                    width: 220,
                    value: _topUpFilter,
                    items: const [
                      'All',
                      'Pending',
                      'Queried',
                      'Approved',
                      'Disbursed',
                      'Confirmed',
                      'Confirmed with discrepancy',
                      'Declined',
                    ],
                    onChanged: (value) => setState(() {
                      _topUpFilter = value;
                      _topUpPage = 0;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (pageItems.isEmpty)
                const _EmptyState(
                  icon: Icons.add_card_outlined,
                  title: 'No top-up records found',
                  subtitle: 'Try another search or status filter.',
                )
              else
                _TableShell(
                  columns: const [
                    'Request',
                    'Requested',
                    'Approved',
                    'Status',
                    'Date',
                  ],
                  rows: pageItems
                      .map(
                        (item) => [
                          _MainCell(
                            title: item.requestId,
                            subtitle:
                                '${item.expensesCount} expenses in cycle${item.approvalCode == null ? '' : ' · ${item.approvalCode}'}',
                            onTap: () => _openTopUpDetailPage(item),
                          ),
                          Text(_money(item.requestedAmount)),
                          Text(
                            item.approvedAmount == null
                                ? 'Not approved'
                                : _money(item.approvedAmount!),
                          ),
                          _StatusPill(
                            label: item.status.label,
                            color: item.status.color,
                          ),
                          Text(_date(item.confirmedAt ?? item.requestedAt)),
                        ],
                      )
                      .toList(),
                ),
              const SizedBox(height: 14),
              _LedgerPagination(
                page: page,
                totalItems: topUps.length,
                pageSize: _ledgerPageSize,
                onPrevious: page == 0
                    ? null
                    : () => setState(() => _topUpPage = page - 1),
                onNext: page >= maxPage
                    ? null
                    : () => setState(() => _topUpPage = page + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferLedgerPage() {
    final transfers = _visibleTransfers;
    final maxPage = transfers.isEmpty
        ? 0
        : (transfers.length - 1) ~/ _ledgerPageSize;
    final page = _transferPage.clamp(0, maxPage);
    final pageItems = transfers
        .skip(page * _ledgerPageSize)
        .take(_ledgerPageSize)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLedgerBackButton('Back to petty cash'),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Pocket transfer history',
          subtitle:
              'Cash and MoMo movements are recorded independently from expenses for clean reconciliation.',
          trailing: FilledButton.icon(
            onPressed: _openPocketTransferDialog,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Transfer pocket'),
            style: _primaryButtonStyle(),
          ),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() {
                  _transferQuery = value;
                  _transferPage = 0;
                }),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search transfer ID, pocket, or reference',
                ),
              ),
              const SizedBox(height: 18),
              if (pageItems.isEmpty)
                const _EmptyState(
                  icon: Icons.swap_horiz,
                  title: 'No pocket transfers found',
                  subtitle: 'Try another search term.',
                )
              else
                _TableShell(
                  columns: const [
                    'Transfer',
                    'Amount',
                    'Fee',
                    'Reference',
                    'Date',
                    'Actions',
                  ],
                  rows: pageItems
                      .map(
                        (item) => [
                          _MainCell(
                            title: '${item.fromPocket} to ${item.toPocket}',
                            subtitle: item.id,
                            onTap: () => _openTransferDetailDialog(item),
                          ),
                          Text(_money(item.amount)),
                          Text(_money(item.fee)),
                          Text(item.reference),
                          Text(_date(item.date)),
                          PopupMenuButton<_TransferAction>(
                            tooltip: 'Transfer actions',
                            onSelected: (action) {
                              switch (action) {
                                case _TransferAction.view:
                                  _openTransferDetailDialog(item);
                                case _TransferAction.print:
                                  _snack(
                                    'Print copy for ${item.id} is ready to connect to the receipt service.',
                                  );
                                case _TransferAction.download:
                                  _snack(
                                    'Download copy for ${item.id} is ready to connect to the document service.',
                                  );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _TransferAction.view,
                                child: ListTile(
                                  leading: Icon(Icons.visibility_outlined),
                                  title: Text('View transfer'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _TransferAction.print,
                                child: ListTile(
                                  leading: Icon(Icons.print_outlined),
                                  title: Text('Print copy'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _TransferAction.download,
                                child: ListTile(
                                  leading: Icon(Icons.download_outlined),
                                  title: Text('Download copy'),
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ],
                      )
                      .toList(),
                ),
              const SizedBox(height: 14),
              _LedgerPagination(
                page: page,
                totalItems: transfers.length,
                pageSize: _ledgerPageSize,
                onPrevious: page == 0
                    ? null
                    : () => setState(() => _transferPage = page - 1),
                onNext: page >= maxPage
                    ? null
                    : () => setState(() => _transferPage = page + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalsTab() {
    final pendingRequisitions = _requisitions.where(
      (item) => item.status == _RequisitionStatus.pending,
    );
    final pendingTopUps = _topUps.where(
      (item) => item.status == _TopUpStatus.pending,
    );
    final pendingRatifications = _expenses.where(
      (item) =>
          item.approvalStatus == _ExpenseApprovalStatus.pendingRatification,
    );
    final pendingVarianceReviews = _expenses.where(
      (item) => item.varianceStatus == _VarianceStatus.pendingReview,
    );

    return Column(
      children: [
        _SectionCard(
          title: 'Approval queue',
          subtitle:
              'Headmaster or delegated approver actions. No balance-changing operation should happen offline.',
          child: Column(
            children: [
              for (final item in pendingRequisitions)
                _ActionTile(
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.amber,
                  title: '${item.title} · ${_money(item.approvedAmount ?? 0)}',
                  subtitle:
                      'Requested by ${item.requestedBy} for ${item.category}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _rejectRequisition(item),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _approveRequisition(item),
                        style: _primaryButtonStyle(),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ),
              for (final item in pendingTopUps)
                _ActionTile(
                  icon: Icons.add_card_outlined,
                  iconColor: AppColors.blue,
                  title: 'Top-up request ${item.requestId}',
                  subtitle:
                      'Requested ${_date(item.requestedAt)} · estimated ${_money(item.requestedAmount)}',
                  trailing: FilledButton(
                    onPressed: () => _approveTopUp(item),
                    style: _primaryButtonStyle(),
                    child: const Text('Approve'),
                  ),
                ),
              for (final item in pendingRatifications)
                _ActionTile(
                  icon: Icons.gavel_outlined,
                  iconColor: AppColors.red,
                  title: '${item.description} requires ratification',
                  subtitle:
                      'Emergency expense · ${_money(item.amount)} recorded without prior approval',
                  trailing: FilledButton(
                    onPressed: () => _ratifyExpense(item),
                    style: _primaryButtonStyle(),
                    child: const Text('Ratify'),
                  ),
                ),
              for (final item in pendingVarianceReviews)
                _ActionTile(
                  icon: Icons.rule_folder_outlined,
                  iconColor: AppColors.amber,
                  title: '${item.description} requires variance review',
                  subtitle:
                      'Approved ${_money(item.approvedAmount ?? 0)} · actual ${_money(item.amount)} · ${item.varianceLabel}',
                  trailing: FilledButton(
                    onPressed: () => _openVarianceReviewDialog(item),
                    style: _primaryButtonStyle(),
                    child: const Text('Review variance'),
                  ),
                ),
              if (pendingRequisitions.isEmpty &&
                  pendingTopUps.isEmpty &&
                  pendingRatifications.isEmpty &&
                  pendingVarianceReviews.isEmpty)
                const _EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No approvals waiting',
                  subtitle:
                      'Requisitions, top-ups, ratification, and variance items are clear.',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    final reportCards = [
      _ReportCardData(
        icon: Icons.picture_as_pdf_outlined,
        title: 'Audit export',
        subtitle:
            'Export PDF or Excel with requisitions, expenses, receipts, and approval trail.',
        action: 'Prepare export',
      ),
      _ReportCardData(
        icon: Icons.balance_outlined,
        title: 'Float reconciliation',
        subtitle:
            'Compare cash box count and MoMo statement against system pockets.',
        action: 'Request reconciliation',
        onPressed: _openReconciliationRequestDialog,
      ),
      _ReportCardData(
        icon: Icons.history_outlined,
        title: 'Date exceptions',
        subtitle:
            'Backdated expenses, late ratifications, and receipt-date tolerance warnings.',
        action: 'Review exceptions',
      ),
      _ReportCardData(
        icon: Icons.receipt_long_outlined,
        title: 'Refund register',
        subtitle: 'Linked refund entries without modifying original expenses.',
        action: 'Open register',
      ),
    ];

    return _SectionCard(
      title: 'Reports & controls',
      subtitle:
          'These are placeholders for the backend reporting APIs. They show the final control surface we should build toward.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > 900
              ? (constraints.maxWidth - 16) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final card in reportCards)
                SizedBox(
                  width: width,
                  child: _ReportCard(data: card),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _expenseListTile(_ExpenseRecord item) {
    return _ActionTile(
      icon: item.source == _ExpenseSource.pettyCash
          ? Icons.account_balance_wallet_outlined
          : Icons.account_balance_outlined,
      iconColor: item.source == _ExpenseSource.pettyCash
          ? _green
          : AppColors.blue,
      title: item.description,
      subtitle:
          '${item.category} · ${item.payee} · ${_date(item.transactionDate)}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _money(item.netAmount),
            style: const TextStyle(fontWeight: FontWeight.w800, color: _text),
          ),
          const SizedBox(height: 4),
          _StatusPill(label: item.status.label, color: item.status.color),
        ],
      ),
      onTap: () => _openExpenseDetailDialog(item),
    );
  }

  Widget _topUpTile(_TopUpRequest item) {
    return _ActionTile(
      icon: Icons.add_card_outlined,
      iconColor: item.status.color,
      title: '${item.requestId} · ${_money(item.requestedAmount)}',
      subtitle:
          '${item.status.label} · requested ${_date(item.requestedAt)} · ${item.expensesCount} expenses in cycle',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(label: item.status.label, color: item.status.color),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ],
      ),
      onTap: () => _openTopUpDetailPage(item),
    );
  }

  void _openTopUpDetailPage(_TopUpRequest item) {
    setState(() {
      _selectedTopUp = item;
      _financeLedgerPage = _FinanceLedgerPage.topUpDetail;
    });
  }

  Widget _buildTopUpDetailPage(_TopUpRequest item) {
    final needsAction =
        item.status == _TopUpStatus.pending ||
        item.status == _TopUpStatus.approved ||
        item.status == _TopUpStatus.disbursed;

    Widget metric(String label, String value, {Color? valueColor}) {
      return Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: .3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor ?? _text,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLedgerBackButton(
          'Back to top-up history',
          onPressed: () => setState(() {
            _selectedTopUp = null;
            _financeLedgerPage = _FinanceLedgerPage.topUps;
          }),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Top-up request ${item.requestId}',
          subtitle:
              'Review the request and complete the next financial control step.',
          trailing: _StatusPill(
            label: item.status.label,
            color: item.status.color,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  metric('Requested', _money(item.requestedAmount)),
                  metric(
                    'Approved',
                    item.approvedAmount == null
                        ? 'Not approved'
                        : _money(item.approvedAmount!),
                    valueColor: item.approvedAmount == null ? _muted : null,
                  ),
                  metric(
                    'Actual received',
                    item.actualReceived == null
                        ? 'Not recorded'
                        : _money(item.actualReceived!),
                    valueColor: item.actualReceived == null ? _muted : _green,
                  ),
                  metric('Expenses in cycle', '${item.expensesCount}'),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'REQUEST RECORD',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 4),
              _ReadOnlyRow('Status', item.status.label),
              _ReadOnlyRow('Requested on', _date(item.requestedAt)),
              _ReadOnlyRow(
                'Approved amount',
                item.approvedAmount == null
                    ? 'Not approved'
                    : _money(item.approvedAmount!),
              ),
              if (item.approvalCode != null)
                _ReadOnlyRow('Approval code', item.approvalCode!),
              if (item.approvedAt != null)
                _ReadOnlyRow('Approved on', _date(item.approvedAt!)),
              if (item.actualReceived != null)
                _ReadOnlyRow('Actual received', _money(item.actualReceived!)),
              if (item.confirmedAt != null)
                _ReadOnlyRow('Confirmed on', _date(item.confirmedAt!)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Cycle transactions',
          subtitle:
              'Expenses included when this replenishment request was prepared.',
          child: item.transactions.isEmpty
              ? const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No cycle transactions attached',
                  subtitle:
                      'Expenses added after a top-up request remain in the next cycle.',
                )
              : _TableShell(
                  columns: const ['Transaction', 'Category', 'Date', 'Amount'],
                  rows: item.transactions
                      .map(
                        (transaction) => [
                          _MainCell(
                            title: transaction.description,
                            subtitle: transaction.transactionId,
                          ),
                          Text(transaction.category),
                          Text(_date(transaction.date)),
                          Text(
                            _money(transaction.amount),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: needsAction ? 'Next action' : 'Workflow complete',
          subtitle: needsAction
              ? 'Use the actions below to move this request to its next controlled state.'
              : 'This top-up request is retained as a read-only financial record.',
          child: needsAction
              ? Wrap(spacing: 10, runSpacing: 10, children: _topUpActions(item))
              : const Text(
                  'No further action is required for this top-up request.',
                  style: TextStyle(color: _muted),
                ),
        ),
      ],
    );
  }

  List<Widget> _topUpActions(_TopUpRequest item) {
    switch (item.status) {
      case _TopUpStatus.pending:
        return [
          OutlinedButton(
            onPressed: () => _queryTopUp(item),
            child: const Text('Query'),
          ),
          FilledButton(
            onPressed: () => _approveTopUp(item),
            style: _primaryButtonStyle(),
            child: const Text('Approve'),
          ),
        ];
      case _TopUpStatus.approved:
        return [
          FilledButton(
            onPressed: () => _openDisburseTopUpDialog(item),
            style: _primaryButtonStyle(),
            child: const Text('Disburse'),
          ),
        ];
      case _TopUpStatus.disbursed:
        return [
          FilledButton(
            onPressed: () => _openConfirmTopUpDialog(item),
            style: _primaryButtonStyle(),
            child: const Text('Confirm received'),
          ),
        ];
      case _TopUpStatus.queried:
      case _TopUpStatus.declined:
      case _TopUpStatus.confirmed:
      case _TopUpStatus.confirmedWithDiscrepancy:
        return [
          _StatusPill(label: item.status.label, color: item.status.color),
        ];
    }
  }

  Widget _pocketTransferTile(_PocketTransfer item) {
    return _ActionTile(
      icon: Icons.swap_horiz,
      iconColor: _green,
      title: '${item.fromPocket} to ${item.toPocket} · ${_money(item.amount)}',
      subtitle:
          '${_date(item.date)} · fee ${_money(item.fee)} · reference ${item.reference}',
      onTap: () => _openTransferDetailDialog(item),
    );
  }

  void _openRecordExpenseDialog({_RequisitionRecord? requisition}) {
    if (requisition == null) {
      _snack('Create and approve a requisition before recording an expense.');
      return;
    }
    final approvedAmount = requisition.approvedAmount;
    if (approvedAmount == null) {
      _snack('Approve this requisition before recording actual spend.');
      return;
    }
    final description = TextEditingController(text: requisition.title);
    final payee = TextEditingController(text: requisition.payee);
    final amount = TextEditingController(
      text: approvedAmount.toStringAsFixed(0),
    );
    final receipt = TextEditingController();
    final notes = TextEditingController();
    _PaymentChannel channel = _PaymentChannel.bankTransfer;
    picker.PlatformFile? receiptAttachment;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final amountValue = _parseAmount(amount.text);
            final helper = _varianceMessage(requisition, amountValue);

            return _ExpenseDialogShell(
              title: 'Record actual spend',
              subtitle: 'Enter the final paid amount and receipt details.',
              primaryLabel: 'Record spend',
              onPrimary: () async {
                final actual = _parseAmount(amount.text);
                if (description.text.trim().isEmpty || actual <= 0) {
                  _snack('Enter a description and valid amount.');
                  return;
                }
                final saved = await _fulfilRequisition(
                  requisition,
                  actualAmount: actual,
                  payee: payee.text.trim(),
                  description: description.text.trim(),
                  receiptNumber: receipt.text.trim(),
                  notes: notes.text.trim(),
                  channel: channel,
                  receiptAttachment: receiptAttachment,
                );
                if (saved && context.mounted) Navigator.pop(context);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogSummary(
                    title: 'Approved amount',
                    value: _money(approvedAmount),
                    subtitle: '${requisition.id} · ${requisition.payee}',
                    color: AppColors.blue,
                  ),
                  const SizedBox(height: 14),
                  _FormSection(
                    title: 'Expense details',
                    child: Column(
                      children: [
                        TextField(
                          controller: description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _TwoFields(
                          left: TextField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Actual amount',
                              prefixText: 'GH¢ ',
                            ),
                          ),
                          right: TextField(
                            controller: payee,
                            decoration: const InputDecoration(
                              labelText: 'Vendor / payee',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<_PaymentChannel>(
                          value: channel,
                          decoration: const InputDecoration(
                            labelText: 'Payment source',
                          ),
                          items: _PaymentChannel.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => channel = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormSection(
                    title: 'Receipt',
                    child: Column(
                      children: [
                        TextField(
                          controller: receipt,
                          decoration: const InputDecoration(
                            labelText: 'Physical receipt number',
                            hintText: 'Optional, but recommended',
                            helperText:
                                'Use the paper receipt book number or supplier invoice reference.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: _border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: receiptAttachment == null
                              ? Row(
                                  children: [
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Receipt photo or PDF',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Optional · JPG, PNG or PDF · up to 10 MB',
                                            style: TextStyle(
                                              color: _muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final result =
                                            await picker.FilePicker.pickFiles(
                                              type: picker.FileType.custom,
                                              allowedExtensions: const [
                                                'jpg',
                                                'jpeg',
                                                'png',
                                                'pdf',
                                              ],
                                              withData: true,
                                            );
                                        if (result == null ||
                                            result.files.isEmpty) {
                                          return;
                                        }
                                        final file = result.files.single;
                                        if (file.size > 10 * 1024 * 1024) {
                                          _snack(
                                            'Receipt files must be 10 MB or smaller.',
                                          );
                                          return;
                                        }
                                        if (file.bytes == null) {
                                          _snack(
                                            'The selected receipt could not be read.',
                                          );
                                          return;
                                        }
                                        setDialogState(
                                          () => receiptAttachment = file,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.attach_file_rounded,
                                      ),
                                      label: const Text('Attach file'),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      color: _green,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            receiptAttachment!.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            _fileSizeLabel(
                                              receiptAttachment!.size,
                                            ),
                                            style: const TextStyle(
                                              color: _muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove attachment',
                                      onPressed: () => setDialogState(
                                        () => receiptAttachment = null,
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notes,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Optional context for audit review',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DialogSummary(
                    title: 'Variance check',
                    value: amountValue <= 0 ? 'GH¢0' : _money(amountValue),
                    subtitle: helper,
                    color: _green,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateRequisitionDialog() {
    final title = TextEditingController();
    final payee = TextEditingController();
    final amount = TextEditingController();
    final category = TextEditingController(text: 'Supplies');
    final reason = TextEditingController();
    final verbalApprover = TextEditingController();
    bool emergencyApproval = false;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final value = _parseAmount(amount.text);
          return _ExpenseDialogShell(
            title: 'New requisition',
            subtitle: 'Request approval before spending.',
            primaryLabel: 'Submit request',
            onPrimary: () async {
              final value = _parseAmount(amount.text);
              if (title.text.trim().isEmpty || value <= 0) {
                _snack('Enter description and a valid estimated amount.');
                return;
              }
              if (emergencyApproval && verbalApprover.text.trim().isEmpty) {
                _snack('Enter who gave verbal approval.');
                return;
              }
              final termId = _academicTermId;
              if (termId == null) {
                _snack('The current academic term is not available.');
                return;
              }
              try {
                final created = await _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/requisitions',
                  body: {
                    'academicTermId': termId,
                    'description': title.text.trim(),
                    'category': category.text.trim().isEmpty
                        ? 'General'
                        : category.text.trim(),
                    'vendor': payee.text.trim().isEmpty
                        ? 'Vendor not confirmed'
                        : payee.text.trim(),
                    'requestedAmount': value,
                    'expenseDate': DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first,
                    'reason': reason.text.trim(),
                    'notes': reason.text.trim(),
                    'emergency': emergencyApproval,
                    'verbalApprover':
                        emergencyApproval &&
                            verbalApprover.text.trim().isNotEmpty
                        ? verbalApprover.text.trim()
                        : null,
                  },
                );
                final requisitionId = _nullableServerId(_asMap(created)['id']);
                if (requisitionId == null) {
                  throw const FinanceApiException(
                    'The requisition was created without a server ID.',
                  );
                }
                await _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/requisitions/$requisitionId/submit',
                );
                await _loadFinanceWorkspace(showLoading: false);
                if (!mounted) return;
                _snack(
                  emergencyApproval
                      ? 'Emergency requisition submitted for approval.'
                      : 'Requisition submitted for approval.',
                );
                if (context.mounted) Navigator.pop(context);
              } on FinanceApiException catch (error) {
                if (mounted) _snack(error.message);
              } catch (_) {
                if (mounted) {
                  _snack('The requisition could not be submitted.');
                }
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FormSection(
                  title: 'Request details',
                  child: Column(
                    children: [
                      TextField(
                        controller: title,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'e.g. Repair leaking KG washroom tap',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TwoFields(
                        left: TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Estimated amount',
                            prefixText: 'GH¢ ',
                          ),
                        ),
                        right: TextField(
                          controller: payee,
                          decoration: const InputDecoration(
                            labelText: 'Vendor',
                            hintText: 'Optional',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Reason',
                  child: TextField(
                    controller: reason,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Why is this needed?',
                      hintText: 'Add enough detail for approval and audit.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Approval route',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SegmentedChoice<bool>(
                        value: emergencyApproval,
                        options: const [false, true],
                        labelOf: (value) => value
                            ? 'Verbal approval (emergency)'
                            : 'Not yet - submit for approval',
                        onChanged: (value) =>
                            setDialogState(() => emergencyApproval = value),
                      ),
                      if (emergencyApproval) ...[
                        const SizedBox(height: 12),
                        _InlineNotice(
                          icon: Icons.emergency_outlined,
                          color: AppColors.amber,
                          text:
                              'Emergency route: pay now, then Head Teacher ratifies within 24 hours.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: verbalApprover,
                          decoration: const InputDecoration(
                            labelText: 'Who approved verbally?',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DialogSummary(
                  title: 'Estimated spend',
                  value: value <= 0 ? 'GH¢0' : _money(value),
                  subtitle: emergencyApproval
                      ? 'Formal ratification must follow within 24 hours.'
                      : 'This request will wait for approval before spending.',
                  color: emergencyApproval ? AppColors.amber : _green,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openRequisitionWorkspace(_RequisitionRecord requisition) {
    _ExpenseRecord? linkedExpense;
    for (final candidate in _expenses) {
      if (candidate.requisitionId == requisition.id) {
        linkedExpense = candidate;
        break;
      }
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ExpenseDialogShell(
        title: 'Requisition ${requisition.id}',
        subtitle: 'Manage approval, actual spend, and any follow-up here.',
        primaryLabel: 'Close',
        width: 820,
        onPrimary: () => Navigator.pop(dialogContext),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatusPill(
                  label: requisition.status.label,
                  color: requisition.status.color,
                ),
                if (requisition.isEmergency)
                  const _StatusPill(
                    label: 'Emergency route',
                    color: AppColors.amber,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _FormSection(
              title: 'Request',
              child: Column(
                children: [
                  _InfoRow('Description', requisition.title),
                  _InfoRow('Vendor / payee', requisition.payee),
                  _InfoRow('Category', requisition.category),
                  _InfoRow(
                    'Approved amount',
                    requisition.approvedAmount == null
                        ? 'Not approved'
                        : _money(requisition.approvedAmount!),
                  ),
                  _InfoRow('Requested by', requisition.requestedBy),
                  _InfoRow('Requested on', _date(requisition.requestedAt)),
                  _InfoRow('Expires on', _date(requisition.expiresAt)),
                  _InfoRow(
                    'Reason',
                    requisition.notes.isEmpty
                        ? 'Not provided'
                        : requisition.notes,
                  ),
                  if (requisition.isEmergency)
                    _InfoRow(
                      'Verbal approver',
                      requisition.verbalApprover ?? 'Not provided',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (linkedExpense == null &&
                requisition.status == _RequisitionStatus.pending)
              _InlineNotice(
                icon: Icons.pending_actions_outlined,
                color: AppColors.amber,
                text:
                    'Approve this requisition before any money is recorded as spent.',
              ),
            if (linkedExpense == null &&
                requisition.status == _RequisitionStatus.approved)
              _InlineNotice(
                icon: Icons.receipt_long_outlined,
                color: AppColors.blue,
                text:
                    'Approval is complete. Record the actual paid amount when spending happens.',
              ),
            if (linkedExpense != null) ...[
              _FormSection(
                title: 'Actual spend',
                child: Column(
                  children: [
                    _InfoRow('Expense reference', linkedExpense.expenseId),
                    _InfoRow('Actual amount', _money(linkedExpense.amount)),
                    _InfoRow('Payment channel', linkedExpense.channel.label),
                    _InfoRow('Expense status', linkedExpense.status.label),
                    if (linkedExpense.approvedAmount != null)
                      _InfoRow('Variance', linkedExpense.varianceLabel),
                    if (linkedExpense.receiptNumber.isNotEmpty)
                      _InfoRow('Receipt', linkedExpense.receiptNumber),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (requisition.status == _RequisitionStatus.pending) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _approveRequisition(requisition);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve'),
                    style: _primaryButtonStyle(),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _rejectRequisition(requisition);
                    },
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Reject'),
                  ),
                ],
                if (linkedExpense == null &&
                    requisition.status == _RequisitionStatus.approved)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openRecordExpenseDialog(requisition: requisition);
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Record actual spend'),
                    style: _primaryButtonStyle(),
                  ),
                if (linkedExpense != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openExpenseDetailDialog(linkedExpense!);
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Open expense'),
                  ),
                if (linkedExpense?.approvalStatus ==
                    _ExpenseApprovalStatus.pendingRatification)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _ratifyExpense(linkedExpense!);
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Ratify emergency'),
                  ),
                if (linkedExpense?.varianceStatus ==
                    _VarianceStatus.pendingReview)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openVarianceReviewDialog(linkedExpense!);
                    },
                    icon: const Icon(Icons.rule_outlined),
                    label: const Text('Review variance'),
                  ),
                if (requisition.status != _RequisitionStatus.fulfilled &&
                    requisition.status != _RequisitionStatus.cancelled &&
                    requisition.status != _RequisitionStatus.rejected)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _cancelRequisition(requisition);
                    },
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel requisition'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _fulfilRequisition(
    _RequisitionRecord requisition, {
    required double actualAmount,
    required String payee,
    required String description,
    required String receiptNumber,
    required String notes,
    required _PaymentChannel channel,
    picker.PlatformFile? receiptAttachment,
  }) async {
    if (requisition.status != _RequisitionStatus.approved) {
      _snack('Only approved requisitions can be fulfilled.');
      return false;
    }
    if (DateTime.now().isAfter(requisition.expiresAt)) {
      _snack('This requisition has expired and must be reactivated.');
      return false;
    }

    final approved = requisition.approvedAmount;
    if (approved == null) {
      _snack('Approve this requisition before recording actual spend.');
      return false;
    }
    if (requisition.serverId == null) {
      _snack('This requisition is missing its server ID.');
      return false;
    }
    final difference = actualAmount - approved;
    final hasVariance = difference.abs() > 0.005;
    final pocket = switch (channel) {
      _PaymentChannel.floatMomo || _PaymentChannel.directMomo => 'MOMO',
      _ => 'CASH',
    };
    final paymentChannel = switch (channel) {
      _PaymentChannel.floatCash => 'CASH',
      _PaymentChannel.floatMomo => 'MOMO',
      _PaymentChannel.directMomo => 'DIRECT_MOMO',
      _PaymentChannel.cheque => 'CHEQUE',
      _PaymentChannel.bankTransfer => 'BANK_TRANSFER',
    };
    try {
      final created = await _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${requisition.serverId}/actual-spend',
        body: {
          'actualAmount': actualAmount,
          'pocket': pocket,
          'paymentChannel': paymentChannel,
          'vendor': payee.isEmpty ? requisition.payee : payee,
          'category': requisition.category,
          'transactionDate': DateTime.now().toIso8601String().split('T').first,
          'receiptNumber': receiptNumber.trim().isEmpty
              ? null
              : receiptNumber.trim(),
          'notes': [
            description.trim(),
            notes.trim(),
          ].where((value) => value.isNotEmpty).join(' · '),
          'confirmDuplicate': false,
        },
      );

      String? attachmentError;
      if (receiptAttachment != null) {
        final transactionId = _financeTransactionId(created);
        if (transactionId == null) {
          attachmentError =
              'The expense was recorded, but its receipt could not be linked.';
        } else {
          try {
            await _uploadExpenseReceipt(
              transactionId: transactionId,
              attachment: receiptAttachment,
            );
          } on FinanceApiException catch (error) {
            attachmentError =
                'The expense was recorded, but the receipt was not attached: ${error.message}';
          }
        }
      }

      await _loadFinanceWorkspace(showLoading: false);
      if (attachmentError != null) {
        _snack('$attachmentError Open the expense to attach it again.');
      } else {
        _snack(
          requisition.isEmergency
              ? 'Emergency expense recorded. Formal ratification is required.'
              : hasVariance
              ? 'Expense recorded. The ${difference > 0 ? 'higher' : 'lower'} actual amount is awaiting variance review.'
              : 'Requisition fulfilled with the approved amount.',
        );
      }
      return true;
    } on FinanceApiException catch (error) {
      _snack(error.message);
      return false;
    }
  }

  Future<void> _uploadExpenseReceipt({
    required int transactionId,
    required picker.PlatformFile attachment,
  }) async {
    final bytes = attachment.bytes;
    if (bytes == null) {
      throw const FinanceApiException(
        'The selected receipt could not be read.',
      );
    }
    final contentType = _receiptContentType(attachment.name);
    final upload = await _financeApi.post(
      '/api/schools/${widget.customSchoolId}/finance/transactions/$transactionId/receipt/upload-url',
      body: {
        'fileName': attachment.name,
        'contentType': contentType,
        'fileSize': attachment.size,
      },
    );
    if (upload is! Map) {
      throw const FinanceApiException(
        'The receipt upload could not be prepared.',
      );
    }
    final uploadUrl = '${upload['uploadUrl'] ?? ''}'.trim();
    final storageKey = '${upload['storageKey'] ?? ''}'.trim();
    if (uploadUrl.isEmpty || storageKey.isEmpty) {
      throw const FinanceApiException(
        'The receipt upload could not be prepared.',
      );
    }
    await _financeApi.uploadToPresignedUrl(
      uploadUrl: uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );
    await _financeApi.post(
      '/api/schools/${widget.customSchoolId}/finance/transactions/$transactionId/receipt/confirm',
      body: {
        'storageKey': storageKey,
        'fileName': attachment.name,
        'contentType': contentType,
      },
    );
  }

  Future<void> _approveRequisition(_RequisitionRecord item) async {
    if (item.serverId == null) {
      _snack(
        'This requisition cannot be approved because its server ID is missing.',
      );
      return;
    }
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${item.serverId}/approve',
        body: {
          'approvedAmount': item.approvedAmount,
          'notes': 'Approved from Expenses & Petty Cash',
        },
      ),
      successMessage: '${item.id} approved.',
    );
  }

  Future<void> _rejectRequisition(_RequisitionRecord item) async {
    if (item.serverId == null) {
      _snack(
        'This requisition cannot be rejected because its server ID is missing.',
      );
      return;
    }
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${item.serverId}/reject',
        body: {'note': 'Rejected from Expenses & Petty Cash'},
      ),
      successMessage: '${item.id} rejected.',
    );
  }

  Future<void> _cancelRequisition(_RequisitionRecord item) async {
    if (item.status == _RequisitionStatus.fulfilled) {
      _snack('Fulfilled requisitions cannot be cancelled.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This requisition cannot be cancelled because its server ID is missing.',
      );
      return;
    }
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${item.serverId}/revoke',
        body: {'note': 'Cancelled from Expenses & Petty Cash'},
      ),
      successMessage: '${item.id} cancelled.',
    );
  }

  Future<void> _requestTopUp() async {
    if (_academicTermId == null) {
      _snack('The current academic term is still loading. Please try again.');
      return;
    }
    final hasPending = _topUps.any(
      (item) =>
          item.status == _TopUpStatus.pending ||
          item.status == _TopUpStatus.approved ||
          item.status == _TopUpStatus.disbursed,
    );
    if (hasPending) {
      _snack('There is already an open top-up cycle.');
      return;
    }
    if (_totalFloatBalance >= _settings.floatApprovedAmount) {
      _snack('Float is already full. Top-up request blocked.');
      return;
    }

    final amount = _settings.floatApprovedAmount - _totalFloatBalance;
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups',
        body: {
          'academicTermId': _academicTermId,
          'destinationPocket': 'CASH',
          'requestedAmount': amount,
          'notes': 'Top-up requested from Expenses & Petty Cash',
        },
      ),
      successMessage: 'Top-up request created for ${_money(amount)}.',
    );
  }

  Future<void> _approveTopUp(_TopUpRequest item) async {
    if (item.serverId == null) {
      _snack(
        'This top-up cannot be approved because its server ID is missing.',
      );
      return;
    }
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/approve',
        body: {
          'approvedAmount': item.requestedAmount,
          'notes': 'Approved from Expenses & Petty Cash',
        },
      ),
      successMessage: '${item.requestId} approved.',
    );
  }

  Future<void> _queryTopUp(_TopUpRequest item) async {
    if (item.serverId == null) {
      _snack('This top-up cannot be queried because its server ID is missing.');
      return;
    }
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/query',
        body: {'note': 'Returned for review from Expenses & Petty Cash'},
      ),
      successMessage: '${item.requestId} returned for review.',
    );
  }

  void _openDisburseTopUpDialog(_TopUpRequest item) {
    _openConfirmTopUpDialog(item);
  }

  void _openConfirmTopUpDialog(_TopUpRequest item) {
    final approvedAmount = item.approvedAmount;
    if (approvedAmount == null) {
      _snack('This top-up does not have an approved amount.');
      return;
    }
    final code = TextEditingController(text: item.approvalCode ?? '');
    final actual = TextEditingController(
      text: approvedAmount.toStringAsFixed(0),
    );
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final value = _parseAmount(actual.text);
          final difference = value - approvedAmount;
          return _ExpenseDialogShell(
            title: 'Confirm amount received',
            subtitle: 'Confirm the cash actually received into the float.',
            primaryLabel: 'Confirm received',
            width: 500,
            onPrimary: () {
              final value = _parseAmount(actual.text);
              if (code.text.trim() != item.approvalCode || value <= 0) {
                _snack('Enter valid approval code and amount.');
                return;
              }
              Navigator.pop(context);
              _runFinanceMutation(
                request: () => _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/confirm',
                  body: {
                    'approvalCode': code.text.trim(),
                    'actualAmount': value,
                    'reference': 'Confirmed in Expenses & Petty Cash',
                    'notes': 'Physical receipt confirmed in the application',
                  },
                ),
                successMessage: value == approvedAmount
                    ? 'Top-up confirmed and float restored.'
                    : 'Top-up confirmed with discrepancy for review.',
              );
            },
            child: Column(
              children: [
                _DialogSummary(
                  title: 'Approved amount',
                  value: _money(approvedAmount),
                  subtitle: '${item.requestId} · confirm physical receipt',
                  color: AppColors.blue,
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Receipt confirmation',
                  child: Column(
                    children: [
                      TextField(
                        controller: code,
                        decoration: const InputDecoration(
                          labelText: 'Approval code',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: actual,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Actual amount received',
                          prefixText: 'GH¢ ',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DialogSummary(
                  title: difference == 0 ? 'No discrepancy' : 'Difference',
                  value: _money(difference.abs()),
                  subtitle: difference == 0
                      ? 'The received amount matches the approval.'
                      : 'A mismatch will be flagged for review.',
                  color: difference == 0 ? _green : AppColors.amber,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openTransferDetailDialog(_PocketTransfer item) {
    showDialog<void>(
      context: context,
      builder: (context) => _ExpenseDialogShell(
        title: 'Pocket transfer ${item.id}',
        subtitle: 'This movement is separate from expenses and income.',
        primaryLabel: 'Close',
        width: 520,
        onPrimary: () => Navigator.pop(context),
        child: Column(
          children: [
            _DialogSummary(
              title: '${item.fromPocket} to ${item.toPocket}',
              value: _money(item.amount),
              subtitle: _date(item.date),
              color: _green,
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Transfer details',
              child: Column(
                children: [
                  _ReadOnlyRow('Reference', item.reference),
                  _ReadOnlyRow('Transfer fee', _money(item.fee)),
                  _ReadOnlyRow(
                    'Float impact',
                    item.fee == 0
                        ? 'No change to the total float'
                        : '${_money(item.fee)} deducted as a transfer fee',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPocketTransferDialog() {
    final amount = TextEditingController();
    final fee = TextEditingController(text: '0');
    final reference = TextEditingController();
    bool momoToCash = true;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final charge = _parseAmount(fee.text);
          final fromPocket = momoToCash ? 'MoMo' : 'Cash';
          final toPocket = momoToCash ? 'Cash' : 'MoMo';
          final totalAfter = _totalFloatBalance - charge;
          return _ExpenseDialogShell(
            title: 'Pocket transfer',
            subtitle:
                'Move money between float pockets without recording income.',
            primaryLabel: 'Record transfer',
            onPrimary: () async {
              final moved = _parseAmount(amount.text);
              final charge = _parseAmount(fee.text);
              if (moved <= 0) {
                _snack('Enter a valid transfer amount.');
                return;
              }
              if (momoToCash && moved + charge > _momoBalance) {
                _snack('MoMo pocket has insufficient balance.');
                return;
              }
              if (!momoToCash && moved + charge > _cashBalance) {
                _snack('Cash pocket has insufficient balance.');
                return;
              }
              final termId = _academicTermId;
              if (termId == null) {
                _snack('The current academic term is not available.');
                return;
              }
              final saved = await _runFinanceMutation(
                request: () => _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/pocket-transfers',
                  body: {
                    'academicTermId': termId,
                    'sourcePocket': momoToCash ? 'MOMO' : 'CASH',
                    'destinationPocket': momoToCash ? 'CASH' : 'MOMO',
                    'amount': moved,
                    'feeAmount': charge,
                    'reference': reference.text.trim().isEmpty
                        ? 'Manual transfer'
                        : reference.text.trim(),
                    'notes': '',
                    'transactionDate': DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first,
                  },
                ),
                successMessage: 'Pocket transfer recorded.',
              );
              if (saved && context.mounted) Navigator.pop(context);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Direction',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    return compact
                        ? Column(
                            children: [
                              _TransferDirectionChoice(
                                selected: momoToCash,
                                title: 'Cash-Out',
                                subtitle: 'MoMo to cash',
                                icon: Icons.south_west_rounded,
                                onTap: () =>
                                    setDialogState(() => momoToCash = true),
                              ),
                              const SizedBox(height: 10),
                              _TransferDirectionChoice(
                                selected: !momoToCash,
                                title: 'Cash-In',
                                subtitle: 'Cash to MoMo',
                                icon: Icons.north_east_rounded,
                                onTap: () =>
                                    setDialogState(() => momoToCash = false),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: _TransferDirectionChoice(
                                  selected: momoToCash,
                                  title: 'Cash-Out',
                                  subtitle: 'MoMo to cash',
                                  icon: Icons.south_west_rounded,
                                  onTap: () =>
                                      setDialogState(() => momoToCash = true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TransferDirectionChoice(
                                  selected: !momoToCash,
                                  title: 'Cash-In',
                                  subtitle: 'Cash to MoMo',
                                  icon: Icons.north_east_rounded,
                                  onTap: () =>
                                      setDialogState(() => momoToCash = false),
                                ),
                              ),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Amount (GHS)',
                    prefixText: 'GH¢ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference',
                    hintText: 'Agent receipt or deposit slip',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Transfer fee (GHS)',
                    helperText:
                        'Enter the agent or wallet charge. Keep GH¢0 when there is no fee.',
                    prefixText: 'GH¢ ',
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFA),
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _TransferSummaryRow(
                        label: 'Transfer route',
                        value: '$fromPocket to $toPocket',
                      ),
                      const Divider(height: 20),
                      _TransferSummaryRow(
                        label: 'Fee to record',
                        value: _money(charge),
                      ),
                      const Divider(height: 20),
                      _TransferSummaryRow(
                        label: 'Total float after',
                        value: _money(totalAfter < 0 ? 0 : totalAfter),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openRefundDialog(_ExpenseRecord item) {
    final amount = TextEditingController(
      text: item.refundableAmount.toStringAsFixed(0),
    );
    final reason = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record refund'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InlineNotice(
                icon: Icons.info_outline,
                color: _green,
                text:
                    'The original expense will not be edited. A linked refund entry will be created.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Refund amount',
                  prefixText: 'GH¢ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final value = _parseAmount(amount.text);
              if (value <= 0 || value > item.refundableAmount) {
                _snack('Refund cannot exceed original unrefunded amount.');
                return;
              }
              if (reason.text.trim().isEmpty) {
                _snack('Enter a reason for the refund.');
                return;
              }
              if (item.serverId == null) {
                _snack('This expense is missing its server ID.');
                return;
              }
              final saved = await _runFinanceMutation(
                request: () => _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/transactions/${item.serverId}/refunds',
                  body: {
                    'amount': value,
                    'reason': reason.text.trim(),
                    'transactionDate': DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first,
                    'reference': item.receiptNumber,
                  },
                ),
                successMessage:
                    'Refund recorded and linked to original expense.',
              );
              if (saved && context.mounted) Navigator.pop(context);
            },
            style: _primaryButtonStyle(),
            child: const Text('Save refund'),
          ),
        ],
      ),
    );
  }

  void _openExpenseDetailDialog(_ExpenseRecord item) {
    _RequisitionRecord? linkedRequisition;
    if (item.requisitionId != null) {
      for (final requisition in _requisitions) {
        if (requisition.id == item.requisitionId) {
          linkedRequisition = requisition;
          break;
        }
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.description),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InfoRow('Expense ID', item.expenseId),
              _InfoRow('Status', item.status.label),
              _InfoRow('Source', item.source.label),
              _InfoRow('Payment channel', item.channel.label),
              _InfoRow('Amount', _money(item.amount)),
              if (item.approvedAmount != null) ...[
                _InfoRow('Approved amount', _money(item.approvedAmount!)),
                _InfoRow('Variance', item.varianceLabel),
                _InfoRow('Variance review', item.varianceStatus.label),
              ],
              if (item.approvalStatus ==
                  _ExpenseApprovalStatus.pendingRatification)
                _InfoRow('Emergency approval', item.approvalStatus.label),
              if (item.momoFee > 0) _InfoRow('MoMo fee', _money(item.momoFee)),
              if (item.requisitionId != null)
                _InfoRow('Requisition', item.requisitionId!),
              if (item.linkedExpenseId != null)
                _InfoRow('Linked expense', item.linkedExpenseId!),
              _InfoRow(
                'Receipt',
                item.receiptNumber.isEmpty
                    ? 'Not provided'
                    : item.receiptNumber,
              ),
              _InfoRow('Date', _date(item.transactionDate)),
              _InfoRow('Notes', item.notes.isEmpty ? 'None' : item.notes),
              if (item.varianceExplanation.isNotEmpty)
                _InfoRow('Variance explanation', item.varianceExplanation),
              if (item.varianceReviewNotes.isNotEmpty)
                _InfoRow('Review notes', item.varianceReviewNotes),
            ],
          ),
        ),
        actions: [
          if (linkedRequisition != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openRequisitionWorkspace(linkedRequisition!);
              },
              icon: const Icon(Icons.assignment_outlined),
              label: const Text('Open requisition'),
            ),
          TextButton.icon(
            onPressed: () => _printExpenseRecord(item),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
          TextButton.icon(
            onPressed: () => _downloadExpenseCopy(item),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download copy'),
          ),
          if (item.amount > 0 && item.refundableAmount > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openRefundDialog(item);
              },
              child: const Text('Record refund'),
            ),
          if (item.approvalStatus == _ExpenseApprovalStatus.pendingRatification)
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(context);
                _ratifyExpense(item);
              },
              child: const Text('Ratify emergency'),
            ),
          if (item.varianceStatus == _VarianceStatus.pendingReview)
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(context);
                _openVarianceReviewDialog(item);
              },
              child: const Text('Review variance'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: _primaryButtonStyle(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _printExpenseRecord(_ExpenseRecord item) {
    _snack(
      'Print record for ${item.expenseId} is ready to connect to the receipt service.',
    );
  }

  void _downloadExpenseCopy(_ExpenseRecord item) {
    _snack(
      'Download copy for ${item.expenseId} is ready to connect to the document service.',
    );
  }

  void _openReconciliationRequestDialog() {
    final assignee = TextEditingController(text: 'Bursar / Accounts officer');
    final reason = TextEditingController(text: 'Weekly petty cash close');
    showDialog<void>(
      context: context,
      builder: (context) => _ExpenseDialogShell(
        title: 'Request reconciliation',
        subtitle: 'Ask staff to count cash and confirm the MoMo wallet.',
        primaryLabel: 'Send request',
        width: 560,
        onPrimary: () {
          final assignedTo = assignee.text.trim();
          if (assignedTo.isEmpty) {
            _snack('Choose the staff member responsible for the count.');
            return;
          }
          setState(() {
            _reconciliations.insert(
              0,
              _ReconciliationRecord(
                reference: _nextId('REC'),
                requestedAt: DateTime.now(),
                requestedBy: widget.recordedBy?.trim().isNotEmpty == true
                    ? widget.recordedBy!.trim()
                    : 'Administrator',
                assignedTo: assignedTo,
                reason: reason.text.trim(),
                status: _ReconciliationStatus.requested,
              ),
            );
          });
          Navigator.pop(context);
          _snack('Reconciliation request sent to $assignedTo.');
        },
        child: Column(
          children: [
            _FormSection(
              title: 'Assignment',
              child: Column(
                children: [
                  TextField(
                    controller: assignee,
                    decoration: const InputDecoration(
                      labelText: 'Staff responsible for confirmation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason or cycle note (optional)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _InlineNotice(
              icon: Icons.lock_outline,
              color: AppColors.amber,
              text:
                  'This only creates a task. The system balance is captured when the responsible staff member starts the count, not when this request is sent.',
            ),
          ],
        ),
      ),
    );
  }

  void _startReconciliation(_ReconciliationRecord item) {
    setState(() {
      item.expectedCash = _cashBalance;
      item.expectedMomo = _momoBalance;
      item.startedAt = DateTime.now();
      item.startedBy = widget.recordedBy?.trim().isNotEmpty == true
          ? widget.recordedBy!.trim()
          : item.assignedTo;
      item.status = _ReconciliationStatus.inProgress;
    });
    _snack(
      'Count started. The current Cash and MoMo balances have been captured for ${item.reference}.',
    );
  }

  void _openReconciliationConfirmationDialog(_ReconciliationRecord item) {
    if (!item.hasSnapshot) {
      _snack('Start the reconciliation before recording the physical count.');
      return;
    }
    final cash = TextEditingController(
      text: item.expectedCash!.toStringAsFixed(2),
    );
    final momo = TextEditingController(
      text: item.expectedMomo!.toStringAsFixed(2),
    );
    final notes = TextEditingController(text: item.notes);
    final evidence = TextEditingController(text: item.evidenceReference);
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final actualCash = _parseAmount(cash.text);
          final actualMomo = _parseAmount(momo.text);
          final variance = actualCash + actualMomo - item.expectedTotal;
          return _ExpenseDialogShell(
            title: 'Confirm reconciliation',
            subtitle: '${item.reference} · requested by ${item.requestedBy}',
            primaryLabel: 'Record confirmation',
            width: 560,
            onPrimary: () {
              if (actualCash < 0 || actualMomo < 0) {
                _snack('Enter valid non-negative pocket balances.');
                return;
              }
              setState(() {
                item.actualCash = actualCash;
                item.actualMomo = actualMomo;
                item.notes = notes.text.trim();
                item.evidenceReference = evidence.text.trim();
                item.confirmedAt = DateTime.now();
                item.confirmedBy = widget.recordedBy?.trim().isNotEmpty == true
                    ? widget.recordedBy!.trim()
                    : item.assignedTo;
                item.status = variance == 0
                    ? _ReconciliationStatus.confirmed
                    : _ReconciliationStatus.varianceOpen;
              });
              Navigator.pop(context);
              _snack(
                variance == 0
                    ? 'Reconciliation confirmed. The system and physical balances match.'
                    : 'Reconciliation recorded with a ${variance > 0 ? 'surplus' : 'shortfall'} of ${_money(variance.abs())}.',
              );
            },
            child: Column(
              children: [
                _DialogSummary(
                  title: 'System expected total',
                  value: _money(item.expectedTotal),
                  subtitle:
                      'Cash ${_money(item.expectedCash!)} · MoMo ${_money(item.expectedMomo!)}',
                  color: AppColors.blue,
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Counted balances',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cash,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Physical cash counted',
                            prefixText: 'GH¢ ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: momo,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'MoMo wallet balance',
                            prefixText: 'GH¢ ',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DialogSummary(
                  title: variance == 0
                      ? 'Balances match'
                      : 'Variance to review',
                  value: _money(variance.abs()),
                  subtitle: variance == 0
                      ? 'No balance adjustment will be made.'
                      : '${variance > 0 ? 'Surplus' : 'Shortfall'} recorded for review. Record any correction separately.',
                  color: variance == 0 ? AppColors.green : AppColors.red,
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Evidence and notes',
                  child: Column(
                    children: [
                      TextField(
                        controller: evidence,
                        decoration: const InputDecoration(
                          labelText:
                              'Cash count sheet or statement reference (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notes,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickReconciliationDate({required bool from}) async {
    final current = from ? _reconciliationFromDate : _reconciliationToDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _reconciliationFromDate = picked;
        if (_reconciliationToDate != null &&
            _reconciliationToDate!.isBefore(picked)) {
          _reconciliationToDate = picked;
        }
      } else {
        _reconciliationToDate = picked;
        if (_reconciliationFromDate != null &&
            picked.isBefore(_reconciliationFromDate!)) {
          _reconciliationFromDate = picked;
        }
      }
    });
  }

  Widget _noteDetail(String label, String value, {String? fallback}) {
    final text = value.trim().isEmpty ? fallback ?? 'Not provided' : value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            letterSpacing: .5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(text, style: const TextStyle(color: _text, height: 1.35)),
      ],
    );
  }

  void _openVarianceClosureDialog(_ReconciliationRecord item) {
    final resolution = TextEditingController(text: item.varianceResolution);
    var followUpType = item.totalVariance < 0
        ? _FollowUpType.staffRecovery
        : _FollowUpType.cashSurplus;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: 'Close reconciliation variance',
          subtitle:
              '${item.reference} has a ${item.totalVariance > 0 ? 'surplus' : 'shortfall'} of ${_money(item.totalVariance.abs())}.',
          primaryLabel: 'Close variance',
          width: 560,
          onPrimary: () {
            final note = resolution.text.trim();
            if (note.isEmpty) {
              _snack('Add a resolution note before closing the variance.');
              return;
            }
            final resolvedBy = widget.recordedBy?.trim().isNotEmpty == true
                ? widget.recordedBy!.trim()
                : 'Administrator';
            setState(() {
              item.varianceResolution = note;
              item.varianceResolvedAt = DateTime.now();
              item.varianceResolvedBy = resolvedBy;
              item.status = _ReconciliationStatus.varianceClosed;
              if (!_financialFollowUps.any(
                (followUp) => followUp.relatedReference == item.reference,
              )) {
                _financialFollowUps.add(
                  _FinancialFollowUp(
                    reference: _nextId('FF'),
                    type: followUpType,
                    relatedReference: item.reference,
                    owner: item.assignedTo,
                    amount: item.totalVariance.abs(),
                    createdAt: DateTime.now(),
                    dueDate: DateTime.now().add(const Duration(days: 7)),
                    summary:
                        'Created from ${item.reference}: ${item.totalVariance > 0 ? 'cash surplus' : 'cash shortfall'} requires follow-up.',
                    status: _FollowUpStatus.open,
                    notes: [
                      _FollowUpNote(
                        author: resolvedBy,
                        createdAt: DateTime.now(),
                        text: note,
                        isResolution: true,
                      ),
                    ],
                  ),
                );
              }
            });
            Navigator.pop(context);
            _snack(
              'Variance closed and a linked financial follow-up was created.',
            );
          },
          child: Column(
            children: [
              _DialogSummary(
                title: 'Recorded variance',
                value: _money(item.totalVariance.abs()),
                subtitle:
                    '${item.totalVariance > 0 ? 'Surplus' : 'Shortfall'} · expected ${_money(item.expectedTotal)} · counted ${_money(item.actualTotal)}',
                color: AppColors.red,
              ),
              const SizedBox(height: 14),
              const _InlineNotice(
                icon: Icons.account_tree_outlined,
                color: AppColors.amber,
                text:
                    'Closing documents the reconciliation decision and creates a separate financial follow-up. The follow-up keeps the recovery, evidence, or write-off trail visible without treating it as an ordinary expense.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<_FollowUpType>(
                value: followUpType,
                decoration: const InputDecoration(labelText: 'Follow-up route'),
                items:
                    const [
                          _FollowUpType.staffRecovery,
                          _FollowUpType.cashShortage,
                          _FollowUpType.cashSurplus,
                          _FollowUpType.unconfirmedTransfer,
                        ]
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(),
                onChanged: (value) =>
                    setDialogState(() => followUpType = value ?? followUpType),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resolution,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Resolution note',
                  hintText:
                      'Explain the investigation, decision, and any separate correction to be made.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openNewFollowUpDialog() {
    final related = TextEditingController();
    final owner = TextEditingController();
    final amount = TextEditingController();
    final summary = TextEditingController();
    var type = _FollowUpType.missingReceipt;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: 'Record financial follow-up',
          subtitle:
              'Create an exception record for accountant review and closure.',
          primaryLabel: 'Create follow-up',
          onPrimary: () {
            final relatedReference = related.text.trim();
            final assignedOwner = owner.text.trim();
            final value = _parseAmount(amount.text);
            final description = summary.text.trim();
            if (relatedReference.isEmpty ||
                assignedOwner.isEmpty ||
                value <= 0) {
              _snack('Add the related record, owner, and amount.');
              return;
            }
            setState(() {
              _financialFollowUps.add(
                _FinancialFollowUp(
                  reference: _nextId('FF'),
                  type: type,
                  relatedReference: relatedReference,
                  owner: assignedOwner,
                  amount: value,
                  createdAt: DateTime.now(),
                  dueDate: DateTime.now().add(const Duration(days: 7)),
                  summary: description.isEmpty
                      ? 'Manual follow-up recorded for $relatedReference.'
                      : description,
                  status: _FollowUpStatus.open,
                  notes: [
                    _FollowUpNote(
                      author: widget.recordedBy?.trim().isNotEmpty == true
                          ? widget.recordedBy!.trim()
                          : 'Administrator',
                      createdAt: DateTime.now(),
                      text: 'Follow-up opened manually.',
                    ),
                  ],
                ),
              );
            });
            Navigator.pop(context);
            _snack('Financial follow-up created.');
          },
          child: Column(
            children: [
              DropdownButtonFormField<_FollowUpType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _FollowUpType.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => type = value ?? type),
              ),
              const SizedBox(height: 14),
              _TwoFields(
                left: TextField(
                  controller: related,
                  decoration: const InputDecoration(
                    labelText: 'Related record',
                    hintText: 'Expense, top-up, or reconciliation reference',
                  ),
                ),
                right: TextField(
                  controller: owner,
                  decoration: const InputDecoration(
                    labelText: 'Owner',
                    hintText: 'Staff member or supplier',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (GH¢)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: summary,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText:
                      'What needs to be investigated, collected, or resolved?',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFollowUpDetailDialog(_FinancialFollowUp item) {
    final note = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => _ExpenseDialogShell(
        title: item.reference,
        subtitle: '${item.type.label} · linked to ${item.relatedReference}',
        primaryLabel: item.isClosed ? 'Done' : 'Close follow-up',
        onPrimary: () {
          if (item.isClosed) {
            Navigator.pop(context);
            return;
          }
          _openFollowUpClosureDialog(item, parentContext: context);
        },
        width: 680,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogSummary(
              title: item.type.label,
              value: _money(item.amount),
              subtitle: '${item.owner} · ${item.summary}',
              color: item.status.color,
            ),
            const SizedBox(height: 14),
            _TwoFields(
              left: _noteDetail(
                'Due date',
                item.dueDate == null ? 'Not set' : _date(item.dueDate!),
              ),
              right: _noteDetail('Status', item.status.label),
            ),
            const SizedBox(height: 18),
            const Text(
              'NOTES & EVIDENCE',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                letterSpacing: .6,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            for (final entry in item.notes) ...[
              _FollowUpNoteTile(note: entry),
              const SizedBox(height: 8),
            ],
            if (!item.isClosed) ...[
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Add note or evidence reference',
                  hintText: 'Record the investigation or attach a reference.',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  final text = note.text.trim();
                  if (text.isEmpty) {
                    _snack('Add a note before saving.');
                    return;
                  }
                  setState(() {
                    item.notes.add(
                      _FollowUpNote(
                        author: widget.recordedBy?.trim().isNotEmpty == true
                            ? widget.recordedBy!.trim()
                            : 'Administrator',
                        createdAt: DateTime.now(),
                        text: text,
                      ),
                    );
                  });
                  Navigator.pop(context);
                  _snack('Follow-up note added.');
                },
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Add note'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openFollowUpClosureDialog(
    _FinancialFollowUp item, {
    required BuildContext parentContext,
  }) {
    final resolution = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => _ExpenseDialogShell(
        title: 'Close ${item.reference}',
        subtitle: 'Administrator resolution is required to close this record.',
        primaryLabel: 'Close follow-up',
        onPrimary: () {
          final text = resolution.text.trim();
          if (text.isEmpty) {
            _snack('Add a resolution note before closing this follow-up.');
            return;
          }
          setState(() {
            item.status = _FollowUpStatus.closed;
            item.notes.add(
              _FollowUpNote(
                author: widget.recordedBy?.trim().isNotEmpty == true
                    ? widget.recordedBy!.trim()
                    : 'Administrator',
                createdAt: DateTime.now(),
                text: text,
                isResolution: true,
              ),
            );
          });
          Navigator.pop(context);
          Navigator.pop(parentContext);
          _snack('${item.reference} closed with an administrator resolution.');
        },
        child: Column(
          children: [
            const _InlineNotice(
              icon: Icons.admin_panel_settings_outlined,
              color: AppColors.amber,
              text:
                  'Closing preserves the case and its evidence trail. It does not remove the underlying expense, transfer, or reconciliation record.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resolution,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Resolution note',
                hintText:
                    'State the final decision, recovery, write-off, or correction.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ratifyExpense(_ExpenseRecord item) {
    setState(() {
      item.approvalStatus = _ExpenseApprovalStatus.ratified;
      item.status = item.varianceStatus == _VarianceStatus.pendingReview
          ? _ExpenseStatus.pendingVarianceReview
          : _ExpenseStatus.ratified;
    });
    _snack('${item.expenseId} ratified.');
  }

  void _openVarianceReviewDialog(_ExpenseRecord item) {
    final reviewNotes = TextEditingController(text: item.varianceReviewNotes);
    var outcome = _VarianceOutcome.accept;
    final approved = item.approvedAmount ?? 0;
    final difference = item.amount - approved;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: 'Review variance',
          subtitle:
              'Approved ${_money(approved)} · actual ${_money(item.amount)} · ${item.varianceLabel}',
          primaryLabel: 'Save review',
          width: 600,
          onPrimary: () {
            final note = reviewNotes.text.trim();
            if (note.isEmpty) {
              _snack('Add a review note to keep the decision auditable.');
              return;
            }
            setState(() {
              item.varianceStatus = outcome == _VarianceOutcome.accept
                  ? _VarianceStatus.resolved
                  : outcome == _VarianceOutcome.requestCorrection
                  ? _VarianceStatus.correctionRequested
                  : _VarianceStatus.escalated;
              item.varianceOutcome = outcome.label;
              item.varianceReviewNotes = note;
              item.varianceReviewedAt = DateTime.now();
              item.status = item.varianceStatus == _VarianceStatus.resolved
                  ? (item.approvalStatus ==
                            _ExpenseApprovalStatus.pendingRatification
                        ? _ExpenseStatus.pendingRatification
                        : _ExpenseStatus.complete)
                  : _ExpenseStatus.pendingVarianceReview;
              if (outcome == _VarianceOutcome.escalate) {
                _financialFollowUps.insert(
                  0,
                  _FinancialFollowUp(
                    reference: _nextId('FF'),
                    type: _FollowUpType.expenseVariance,
                    relatedReference: item.expenseId,
                    owner: 'Administrator / Accounts',
                    amount: difference.abs(),
                    createdAt: DateTime.now(),
                    status: _FollowUpStatus.open,
                    summary: 'Expense variance escalated for follow-up.',
                    notes: [
                      _FollowUpNote(
                        author: 'Administrator',
                        createdAt: DateTime.now(),
                        text: note,
                      ),
                    ],
                  ),
                );
              }
            });
            Navigator.pop(context);
            _snack(
              outcome == _VarianceOutcome.accept
                  ? '${item.expenseId} variance accepted.'
                  : outcome == _VarianceOutcome.requestCorrection
                  ? 'Correction requested for ${item.expenseId}.'
                  : '${item.expenseId} escalated to Financial Follow-ups.',
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormSection(
                title: 'Recorded difference',
                child: Column(
                  children: [
                    _InfoRow('Approved', _money(approved)),
                    _InfoRow('Actual', _money(item.amount)),
                    _InfoRow('Difference', item.varianceLabel),
                    if (item.varianceExplanation.isNotEmpty)
                      _InfoRow(
                        'Recorded explanation',
                        item.varianceExplanation,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Administrator outcome',
                style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final value in _VarianceOutcome.values)
                RadioListTile<_VarianceOutcome>(
                  value: value,
                  groupValue: outcome,
                  contentPadding: EdgeInsets.zero,
                  title: Text(value.label),
                  subtitle: Text(value.description),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => outcome = value);
                    }
                  },
                ),
              const SizedBox(height: 8),
              TextField(
                controller: reviewNotes,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Review note *',
                  hintText: 'State why this outcome is appropriate.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _varianceMessage(_RequisitionRecord requisition, double actual) {
    if (actual <= 0) return 'Enter actual spend to see variance handling.';
    final approvedAmount = requisition.approvedAmount;
    if (approvedAmount == null) {
      return 'Approve this requisition before recording actual spend.';
    }
    final difference = actual - approvedAmount;
    if (difference.abs() <= 0.005) {
      return 'Actual matches the approved amount. It will be recorded normally.';
    }
    return 'Difference of ${_money(difference.abs())} ${difference > 0 ? 'above' : 'below'} approval. It will be recorded and sent for variance review.';
  }

  String _nextId(String prefix) {
    final value = DateTime.now().millisecondsSinceEpoch.toString();
    return '$prefix-${value.substring(value.length - 6)}';
  }

  double _parseAmount(String value) =>
      double.tryParse(value.replaceAll(',', '').replaceAll('GH¢', '').trim()) ??
      0;

  DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  ButtonStyle _primaryButtonStyle() {
    return FilledButton.styleFrom(
      backgroundColor: _green,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ExpenseTable extends StatelessWidget {
  const _ExpenseTable({
    required this.expenses,
    required this.onRefund,
    required this.onView,
    required this.onPrint,
    required this.onDownload,
  });

  final List<_ExpenseRecord> expenses;
  final ValueChanged<_ExpenseRecord> onRefund;
  final ValueChanged<_ExpenseRecord> onView;
  final ValueChanged<_ExpenseRecord> onPrint;
  final ValueChanged<_ExpenseRecord> onDownload;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const _EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses found',
        subtitle: 'Try changing the filter or record a new expense.',
      );
    }
    return _TableShell(
      columns: const [
        'Expense',
        'Source',
        'Amount',
        'Status',
        'Receipt',
        'Date',
        'Actions',
      ],
      rows: expenses
          .map(
            (item) => [
              _MainCell(
                title: item.description,
                subtitle: '${item.expenseId} · ${item.payee}',
                onTap: () => onView(item),
              ),
              Text(item.source.label),
              Text(
                _money(item.netAmount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              _StatusPill(label: item.status.label, color: item.status.color),
              Text(
                item.receiptNumber.isEmpty
                    ? 'Not provided'
                    : item.receiptNumber,
              ),
              Text(_date(item.transactionDate)),
              PopupMenuButton<_ExpenseAction>(
                tooltip: 'Expense actions',
                onSelected: (action) {
                  switch (action) {
                    case _ExpenseAction.print:
                      onPrint(item);
                    case _ExpenseAction.download:
                      onDownload(item);
                    case _ExpenseAction.refund:
                      onRefund(item);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _ExpenseAction.print,
                    child: ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('Print record'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: _ExpenseAction.download,
                    child: ListTile(
                      leading: Icon(Icons.download_outlined),
                      title: Text('Download copy'),
                    ),
                  ),
                  if (item.amount > 0 && item.refundableAmount > 0)
                    const PopupMenuItem(
                      value: _ExpenseAction.refund,
                      child: ListTile(
                        leading: Icon(Icons.undo_rounded),
                        title: Text('Record refund'),
                      ),
                    ),
                ],
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          )
          .toList(),
    );
  }
}

class _RequisitionTable extends StatelessWidget {
  const _RequisitionTable({required this.requisitions, required this.onOpen});

  final List<_RequisitionRecord> requisitions;
  final ValueChanged<_RequisitionRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    if (requisitions.isEmpty) {
      return const _EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No requisitions found',
        subtitle: 'Create a requisition before recording school spending.',
      );
    }
    return _TableShell(
      columns: const [
        'Request',
        'Amount',
        'Status',
        'Requested',
        'Expires',
        'Actions',
      ],
      rows: requisitions
          .map(
            (item) => [
              _MainCell(
                title: item.title,
                subtitle: [
                  item.id,
                  item.payee,
                  if (item.isEmergency) 'Emergency verbal approval',
                  if (item.verbalApprover != null)
                    'Approved by ${item.verbalApprover}',
                ].join(' · '),
              ),
              Text(
                item.approvedAmount == null
                    ? 'Not approved'
                    : _money(item.approvedAmount!),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusPill(
                    label: item.status.label,
                    color: item.status.color,
                  ),
                  if (item.isEmergency)
                    const _StatusPill(
                      label: 'Emergency',
                      color: AppColors.amber,
                    ),
                ],
              ),
              Text(_date(item.requestedAt)),
              Text(_date(item.expiresAt)),
              OutlinedButton.icon(
                onPressed: () => onOpen(item),
                icon: const Icon(Icons.open_in_new_outlined, size: 16),
                label: const Text('Open'),
              ),
            ],
          )
          .toList(),
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Widget>> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: {
          for (var i = 0; i < columns.length; i++)
            i: i == 0 ? const FlexColumnWidth(2.4) : const FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFA)),
            children: columns
                .map(
                  (column) => Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      column.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          for (final row in rows)
            TableRow(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              children: row
                  .map(
                    (cell) =>
                        Padding(padding: const EdgeInsets.all(14), child: cell),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 14),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(value: item, child: Text('$item')),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _MainCell extends StatelessWidget {
  const _MainCell({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: onTap == null ? AppColors.text : AppColors.green,
            decoration: onTap == null ? null : TextDecoration.underline,
            decorationColor: onTap == null
                ? null
                : AppColors.green.withValues(alpha: .45),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .4,
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerPagination extends StatelessWidget {
  const _LedgerPagination({
    required this.page,
    required this.totalItems,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final first = totalItems == 0 ? 0 : page * pageSize + 1;
    final last = (page + 1) * pageSize > totalItems
        ? totalItems
        : (page + 1) * pageSize;
    return Row(
      children: [
        Text(
          totalItems == 0
              ? 'No records'
              : 'Showing $first-$last of $totalItems',
          style: const TextStyle(color: AppColors.muted),
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatPocketCard extends StatelessWidget {
  const _FloatPocketCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.background,
    required this.borderColor,
  });

  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              letterSpacing: .6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _money(amount),
            style: TextStyle(
              color: accent,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FloatLimit {
  const _FloatLimit({required this.label, required this.value});

  final String label;
  final String value;
}

class _FloatLimitView extends StatelessWidget {
  const _FloatLimitView({required this.limit});

  final _FloatLimit limit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            limit.label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            limit.value,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferDirectionChoice extends StatelessWidget {
  const _TransferDirectionChoice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.green : AppColors.muted;
    return Material(
      color: selected ? AppColors.greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.green : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
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
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferSummaryRow extends StatelessWidget {
  const _TransferSummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: emphasize ? AppColors.text : AppColors.text,
      fontSize: emphasize ? 20 : 16,
      fontWeight: FontWeight.w900,
    );
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? AppColors.text : AppColors.muted,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: style.copyWith(
            color: emphasize ? AppColors.green : AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _ReconciliationMetric extends StatelessWidget {
  const _ReconciliationMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(date == null ? 'Any date' : _date(date!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.data});

  final _ReportCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: AppColors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          TextButton(onPressed: data.onPressed, child: Text(data.action)),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDialogShell extends StatelessWidget {
  const _ExpenseDialogShell({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.width = 560,
    this.secondaryLabel = 'Cancel',
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: child,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(secondaryLabel),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(primaryLabel),
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

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TwoFields extends StatelessWidget {
  const _TwoFields({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _SegmentedChoice<T> extends StatelessWidget {
  const _SegmentedChoice({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> options;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            selected: option == value,
            label: Text(labelOf(option)),
            onSelected: (_) => onChanged(option),
            selectedColor: AppColors.greenSoft,
            side: BorderSide(
              color: option == value ? AppColors.green : AppColors.border,
            ),
            labelStyle: TextStyle(
              color: option == value ? AppColors.green : AppColors.muted,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _DialogSummary extends StatelessWidget {
  const _DialogSummary({
    required this.title,
    required this.value,
    this.subtitle,
    this.color = AppColors.green,
  });

  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        border: Border.all(color: color.withValues(alpha: .28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowUpNoteTile extends StatelessWidget {
  const _FollowUpNoteTile({required this.note});

  final _FollowUpNote note;

  @override
  Widget build(BuildContext context) {
    final color = note.isResolution ? AppColors.green : AppColors.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        border: Border.all(color: color.withValues(alpha: .22)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            note.isResolution
                ? Icons.task_alt_outlined
                : Icons.chat_bubble_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.isResolution ? 'Administrator resolution' : note.author,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_date(note.createdAt)} · ${note.text}',
                  style: const TextStyle(color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.muted, size: 34),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _SchoolExpenseSettings {
  const _SchoolExpenseSettings({
    required this.floatApprovedAmount,
    required this.floatCeiling,
    required this.floatThreshold,
    required this.captureTransactionFees,
    required this.selfDisburse,
    required this.varianceTolerancePercent,
    required this.requisitionExpiryDays,
    required this.momoWalletNumber,
  });

  final double floatApprovedAmount;
  final double floatCeiling;
  final double floatThreshold;
  final bool captureTransactionFees;
  final bool selfDisburse;
  final int varianceTolerancePercent;
  final int requisitionExpiryDays;
  final String momoWalletNumber;

  factory _SchoolExpenseSettings.empty() => const _SchoolExpenseSettings(
    floatApprovedAmount: 0,
    floatCeiling: 0,
    floatThreshold: 0,
    captureTransactionFees: false,
    selfDisburse: false,
    varianceTolerancePercent: 0,
    requisitionExpiryDays: 0,
    momoWalletNumber: '',
  );
}

class _PettyCashFloat {
  _PettyCashFloat({
    required this.cashBalance,
    required this.momoBalance,
    required this.status,
  });

  double cashBalance;
  double momoBalance;
  _FloatStatus status;

  factory _PettyCashFloat.empty() => _PettyCashFloat(
    cashBalance: 0,
    momoBalance: 0,
    status: _FloatStatus.inactive,
  );
}

class _ExpenseRecord {
  _ExpenseRecord({
    this.serverId,
    required this.expenseId,
    required this.description,
    required this.category,
    required this.payee,
    required this.amount,
    required this.transactionDate,
    required this.source,
    required this.channel,
    required this.status,
    this.receiptNumber = '',
    this.notes = '',
    this.requisitionId,
    this.linkedExpenseId,
    this.approvedAmount,
    this.momoFee = 0,
    this.refundedAmount = 0,
    this.isEmergency = false,
    _ExpenseApprovalStatus? approvalStatus,
    _VarianceStatus? varianceStatus,
    this.varianceExplanation = '',
    this.varianceReviewNotes = '',
    this.varianceOutcome,
    this.varianceReviewedAt,
  }) : approvalStatus =
           approvalStatus ??
           (status == _ExpenseStatus.pendingRatification
               ? _ExpenseApprovalStatus.pendingRatification
               : _ExpenseApprovalStatus.approved),
       varianceStatus =
           varianceStatus ??
           (status == _ExpenseStatus.pendingVarianceReview
               ? _VarianceStatus.pendingReview
               : _VarianceStatus.none);

  final int? serverId;
  final String expenseId;
  final String description;
  final String category;
  final String payee;
  final double amount;
  final DateTime transactionDate;
  final _ExpenseSource source;
  final _PaymentChannel channel;
  _ExpenseStatus status;
  final String receiptNumber;
  final String notes;
  final String? requisitionId;
  final String? linkedExpenseId;
  final double? approvedAmount;
  final double momoFee;
  double refundedAmount;
  final bool isEmergency;
  _ExpenseApprovalStatus approvalStatus;
  _VarianceStatus varianceStatus;
  final String varianceExplanation;
  String varianceReviewNotes;
  String? varianceOutcome;
  DateTime? varianceReviewedAt;

  double get netAmount => amount + momoFee;
  double get varianceAmount =>
      (approvedAmount == null ? 0 : amount - approvedAmount!);
  String get varianceLabel {
    if (approvedAmount == null) return 'Not applicable';
    if (varianceAmount.abs() <= 0.005) return 'No difference';
    return '${varianceAmount > 0 ? '+' : '-'}${_money(varianceAmount.abs())}';
  }

  double get refundableAmount =>
      amount <= 0 ? 0 : (amount - refundedAmount).clamp(0, amount);
}

class _RequisitionRecord {
  _RequisitionRecord({
    this.serverId,
    required this.id,
    required this.title,
    required this.category,
    required this.payee,
    required this.requestedBy,
    this.approvedAmount,
    required this.requestedAt,
    required this.expiresAt,
    required this.status,
    this.notes = '',
    this.isEmergency = false,
    this.verbalApprover,
  });

  final int? serverId;
  final String id;
  final String title;
  final String category;
  final String payee;
  final String requestedBy;
  double? approvedAmount;
  final DateTime requestedAt;
  final DateTime expiresAt;
  _RequisitionStatus status;
  final String notes;
  final bool isEmergency;
  final String? verbalApprover;
}

class _TopUpRequest {
  _TopUpRequest({
    this.serverId,
    required this.requestId,
    required this.requestedAmount,
    this.approvedAmount,
    required this.requestedAt,
    required this.expensesCount,
    required this.status,
    this.approvalCode,
    this.approvedAt,
    this.confirmedAt,
    this.actualReceived,
    this.transactions = const [],
  });

  final int? serverId;
  final String requestId;
  final double requestedAmount;
  double? approvedAmount;
  final DateTime requestedAt;
  final int expensesCount;
  _TopUpStatus status;
  String? approvalCode;
  DateTime? approvedAt;
  DateTime? confirmedAt;
  double? actualReceived;
  final List<_TopUpTransaction> transactions;
}

class _TopUpTransaction {
  const _TopUpTransaction({
    required this.transactionId,
    required this.description,
    required this.category,
    required this.amount,
    required this.date,
  });

  final String transactionId;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
}

class _PocketTransfer {
  const _PocketTransfer({
    required this.id,
    required this.fromPocket,
    required this.toPocket,
    required this.amount,
    required this.fee,
    required this.reference,
    required this.date,
  });

  final String id;
  final String fromPocket;
  final String toPocket;
  final double amount;
  final double fee;
  final String reference;
  final DateTime date;
}

class _ReconciliationRecord {
  _ReconciliationRecord({
    this.serverId,
    required this.reference,
    required this.requestedAt,
    required this.requestedBy,
    required this.assignedTo,
    required this.reason,
    required this.status,
    this.expectedCash,
    this.expectedMomo,
    this.startedAt,
    this.startedBy,
    this.actualCash,
    this.actualMomo,
    this.confirmedAt,
    this.confirmedBy,
    this.notes = '',
    this.evidenceReference = '',
    this.varianceResolution = '',
    this.varianceResolvedAt,
    this.varianceResolvedBy,
  });

  final int? serverId;
  final String reference;
  final DateTime requestedAt;
  final String requestedBy;
  final String assignedTo;
  double? expectedCash;
  double? expectedMomo;
  final String reason;
  _ReconciliationStatus status;
  DateTime? startedAt;
  String? startedBy;
  double? actualCash;
  double? actualMomo;
  DateTime? confirmedAt;
  String? confirmedBy;
  String notes;
  String evidenceReference;
  String varianceResolution;
  DateTime? varianceResolvedAt;
  String? varianceResolvedBy;

  bool get hasSnapshot => expectedCash != null && expectedMomo != null;

  double get expectedTotal => (expectedCash ?? 0) + (expectedMomo ?? 0);

  double get actualTotal => (actualCash ?? 0) + (actualMomo ?? 0);

  double get totalVariance =>
      status == _ReconciliationStatus.requested ||
          status == _ReconciliationStatus.inProgress
      ? 0
      : actualTotal - expectedTotal;
}

class _FinancialFollowUp {
  _FinancialFollowUp({
    required this.reference,
    required this.type,
    required this.relatedReference,
    required this.owner,
    required this.amount,
    required this.createdAt,
    required this.summary,
    required this.status,
    this.dueDate,
    List<_FollowUpNote>? notes,
  }) : notes = notes ?? [];

  final String reference;
  final _FollowUpType type;
  final String relatedReference;
  final String owner;
  final double amount;
  final DateTime createdAt;
  final String summary;
  DateTime? dueDate;
  _FollowUpStatus status;
  final List<_FollowUpNote> notes;

  bool get isClosed => status == _FollowUpStatus.closed;

  bool get isOverdue =>
      !isClosed && dueDate != null && dueDate!.isBefore(DateTime.now());
}

class _FollowUpNote {
  const _FollowUpNote({
    required this.author,
    required this.createdAt,
    required this.text,
    this.isResolution = false,
  });

  final String author;
  final DateTime createdAt;
  final String text;
  final bool isResolution;
}

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.targetTab,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final _ExpenseTab targetTab;
}

class _ReportCardData {
  const _ReportCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback? onPressed;
}

enum _ExpenseTab {
  overview('Overview'),
  expenses('Expense register'),
  requisitions('Requisitions'),
  pettyCash('Petty Cash'),
  reconciliations('Reconciliations'),
  followUps('Financial follow-ups'),
  approvals('Approvals'),
  reports('Reports');

  const _ExpenseTab(this.label);
  final String label;
}

enum _FinanceLedgerPage { topUps, topUpDetail, transfers, reconciliationDetail }

enum _ExpenseSource {
  pettyCash('Petty cash'),
  direct('Direct');

  const _ExpenseSource(this.label);
  final String label;
}

enum _PaymentChannel {
  floatCash('Float - Cash'),
  floatMomo('Float - MoMo'),
  directMomo('Direct MoMo'),
  cheque('Cheque'),
  bankTransfer('Bank transfer');

  const _PaymentChannel(this.label);
  final String label;

  bool get isFloatPocket =>
      this == _PaymentChannel.floatCash || this == _PaymentChannel.floatMomo;
}

enum _ExpenseStatus {
  draft('Draft', AppColors.muted),
  approved('Approved', AppColors.green),
  pendingRatification('Pending ratification', AppColors.amber),
  pendingVarianceReview('Pending variance review', AppColors.amber),
  ratified('Ratified', AppColors.green),
  complete('Complete', AppColors.green),
  rejected('Rejected', AppColors.red),
  revoked('Revoked', AppColors.red),
  conflicted('Conflicted', AppColors.red),
  disputed('Disputed', AppColors.amber),
  pendingRefund('Pending refund', AppColors.amber),
  partiallyRefunded('Partially refunded', AppColors.blue),
  fullyRefunded('Fully refunded', AppColors.blue),
  cancelled('Cancelled', AppColors.muted),
  blocked('Blocked', AppColors.red);

  const _ExpenseStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum _ExpenseApprovalStatus {
  approved('Approved'),
  pendingRatification('Pending ratification'),
  ratified('Ratified');

  const _ExpenseApprovalStatus(this.label);
  final String label;
}

enum _VarianceStatus {
  none('No variance'),
  pendingReview('Pending variance review'),
  correctionRequested('Correction requested'),
  escalated('Escalated for follow-up'),
  resolved('Resolved');

  const _VarianceStatus(this.label);
  final String label;
}

enum _VarianceOutcome {
  accept(
    'Accept variance',
    'Keep the actual expense and close the variance review.',
  ),
  requestCorrection(
    'Request correction',
    'Keep the review open while the original record is corrected or explained.',
  ),
  escalate(
    'Escalate to follow-up',
    'Create a Financial Follow-up for Accounts or school leadership.',
  );

  const _VarianceOutcome(this.label, this.description);
  final String label;
  final String description;
}

enum _ExpenseAction { print, download, refund }

enum _TransferAction { view, print, download }

enum _RequisitionStatus {
  pending('Pending', AppColors.amber),
  approved('Approved', AppColors.green),
  rejected('Rejected', AppColors.red),
  cancelled('Cancelled', AppColors.muted),
  revised('Revised', AppColors.blue),
  expired('Expired', AppColors.red),
  fulfilled('Fulfilled', AppColors.green);

  const _RequisitionStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum _TopUpStatus {
  pending('Pending', AppColors.amber),
  queried('Queried', AppColors.blue),
  declined('Declined', AppColors.red),
  approved('Approved', AppColors.green),
  disbursed('Disbursed', AppColors.purple),
  confirmed('Confirmed', AppColors.green),
  confirmedWithDiscrepancy('Confirmed with discrepancy', AppColors.red);

  const _TopUpStatus(this.label, this.color);
  final String label;
  final Color color;

  bool get isHistorical =>
      this == confirmed || this == confirmedWithDiscrepancy || this == declined;
}

enum _ReconciliationStatus {
  requested('Requested', AppColors.amber),
  inProgress('In progress', AppColors.blue),
  confirmed('Confirmed', AppColors.green),
  varianceOpen('Variance needs review', AppColors.red),
  varianceClosed('Variance closed', AppColors.green);

  const _ReconciliationStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum _FollowUpType {
  staffRecovery('Staff recovery'),
  missingReceipt('Missing receipt'),
  vendorRefund('Supplier refund due'),
  cashShortage('Cash shortage / loss'),
  unconfirmedTransfer('Unconfirmed MoMo'),
  cashSurplus('Cash surplus'),
  expenseVariance('Expense variance');

  const _FollowUpType(this.label);
  final String label;
}

enum _FollowUpStatus {
  open('Open', AppColors.amber),
  awaitingEvidence('Awaiting evidence', AppColors.blue),
  investigating('Under investigation', AppColors.purple),
  partiallyRecovered('Partially recovered', AppColors.amber),
  closed('Closed', AppColors.green);

  const _FollowUpStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum _FloatStatus {
  inactive('Inactive'),
  active('Active'),
  pendingExcessReturn('Pending excess return'),
  closedForTerm('Closed for term');

  const _FloatStatus(this.label);
  final String label;
}

String _money(num value) {
  final sign = value < 0 ? '-' : '';
  final absolute = value.abs();
  final whole = absolute == absolute.roundToDouble();
  return '${sign}GH¢${absolute.toStringAsFixed(whole ? 0 : 2)}';
}

String _date(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
}

String _receiptContentType(String fileName) {
  final normalized = fileName.toLowerCase();
  if (normalized.endsWith('.pdf')) return 'application/pdf';
  if (normalized.endsWith('.png')) return 'image/png';
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  return 'application/octet-stream';
}

int? _financeTransactionId(dynamic value) {
  if (value is num) return value.toInt();

  final map = _asMap(value);
  for (final key in const ['id', 'transactionId', 'expenseTransactionId']) {
    final id = _nullableServerId(map[key]);
    if (id != null) return id;
  }

  for (final key in const ['transaction', 'expense', 'data']) {
    final nested = map[key];
    if (nested is Map || nested is num) {
      final id = _financeTransactionId(nested);
      if (id != null) return id;
    }
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  return const {};
}

List<dynamic> _pageContent(dynamic value) {
  if (value is List) return value;
  final map = _asMap(value);
  for (final key in const ['content', 'items', 'results', 'data']) {
    final candidate = map[key];
    if (candidate is List) return candidate;
  }
  return const [];
}

String _asText(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = '$value'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = _asText(value);
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_asText(value)) ?? 0;
}

int? _nullableServerId(dynamic value) {
  final id = _asInt(value);
  return id > 0 ? id : null;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_asText(value).replaceAll(',', '')) ?? 0;
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  final text = _asText(value);
  if (text.isEmpty) return null;
  return _asDouble(value);
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  final text = _asText(value).toLowerCase();
  return text == 'true' || text == 'yes' || text == '1';
}

DateTime _asDate(dynamic value) =>
    _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _nullableDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is List && value.length >= 3) {
    final year = _asInt(value[0]);
    final month = _asInt(value[1]);
    final day = _asInt(value[2]);
    if (year > 0 && month > 0 && day > 0) {
      return DateTime(
        year,
        month,
        day,
        value.length > 3 ? _asInt(value[3]) : 0,
        value.length > 4 ? _asInt(value[4]) : 0,
        value.length > 5 ? _asInt(value[5]) : 0,
        value.length > 6 ? _asInt(value[6]) ~/ 1000 : 0,
      );
    }
  }
  final text = _asText(value);
  return text.isEmpty ? null : DateTime.tryParse(text);
}

_FloatStatus _floatStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('EXCESS')) return _FloatStatus.pendingExcessReturn;
  if (status.contains('CLOSED')) return _FloatStatus.closedForTerm;
  if (status.contains('ACTIVE') || status.contains('OPEN')) {
    return _FloatStatus.active;
  }
  return _FloatStatus.inactive;
}

_ExpenseStatus _expenseStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('RATIFICATION')) {
    return _ExpenseStatus.pendingRatification;
  }
  if (status.contains('RATIFIED')) return _ExpenseStatus.ratified;
  if (status.contains('VARIANCE')) return _ExpenseStatus.pendingVarianceReview;
  if (status.contains('REJECT')) return _ExpenseStatus.rejected;
  if (status.contains('REVOK')) return _ExpenseStatus.revoked;
  if (status.contains('REFUND')) return _ExpenseStatus.pendingRefund;
  if (status.contains('CANCEL')) return _ExpenseStatus.cancelled;
  if (status.contains('BLOCK')) return _ExpenseStatus.blocked;
  if (status.contains('DRAFT')) return _ExpenseStatus.draft;
  if (status.contains('COMPLETE') || status.contains('RECORDED')) {
    return _ExpenseStatus.complete;
  }
  return _ExpenseStatus.approved;
}

_PaymentChannel _paymentChannel(dynamic value) {
  final channel = _asText(value).toUpperCase();
  if (channel.contains('CASH')) return _PaymentChannel.floatCash;
  if (channel.contains('FLOAT') && channel.contains('MOMO')) {
    return _PaymentChannel.floatMomo;
  }
  if (channel.contains('MOMO')) return _PaymentChannel.directMomo;
  if (channel.contains('CHEQUE')) return _PaymentChannel.cheque;
  return _PaymentChannel.bankTransfer;
}

_RequisitionStatus _requisitionStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('REJECT')) return _RequisitionStatus.rejected;
  if (status.contains('CANCEL') || status.contains('REVOK')) {
    return _RequisitionStatus.cancelled;
  }
  if (status.contains('EXPIRE')) return _RequisitionStatus.expired;
  if (status.contains('FULFIL') || status.contains('SPEND')) {
    return _RequisitionStatus.fulfilled;
  }
  if (status.contains('REVIS')) return _RequisitionStatus.revised;
  if (status.contains('APPROV')) return _RequisitionStatus.approved;
  return _RequisitionStatus.pending;
}

_TopUpStatus _topUpStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('DISCREP')) return _TopUpStatus.confirmedWithDiscrepancy;
  if (status.contains('CONFIRM')) return _TopUpStatus.confirmed;
  if (status.contains('DISBURS')) return _TopUpStatus.disbursed;
  if (status.contains('DECLIN') || status.contains('REJECT')) {
    return _TopUpStatus.declined;
  }
  if (status.contains('QUERY')) return _TopUpStatus.queried;
  if (status.contains('APPROV')) return _TopUpStatus.approved;
  return _TopUpStatus.pending;
}

_ReconciliationStatus _reconciliationStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('VARIANCE') && status.contains('CLOSED')) {
    return _ReconciliationStatus.varianceClosed;
  }
  if (status.contains('VARIANCE')) return _ReconciliationStatus.varianceOpen;
  if (status.contains('CONFIRM') || status.contains('CLOSED')) {
    return _ReconciliationStatus.confirmed;
  }
  if (status.contains('PROGRESS') || status.contains('START')) {
    return _ReconciliationStatus.inProgress;
  }
  return _ReconciliationStatus.requested;
}

_FollowUpType _followUpType(dynamic value) {
  final type = _asText(value).toUpperCase();
  if (type.contains('RECEIPT')) return _FollowUpType.missingReceipt;
  if (type.contains('REFUND')) return _FollowUpType.vendorRefund;
  if (type.contains('SHORT') || type.contains('LOSS')) {
    return _FollowUpType.cashShortage;
  }
  if (type.contains('TRANSFER')) return _FollowUpType.unconfirmedTransfer;
  if (type.contains('SURPLUS')) return _FollowUpType.cashSurplus;
  if (type.contains('VARIANCE')) return _FollowUpType.expenseVariance;
  return _FollowUpType.staffRecovery;
}

_FollowUpStatus _followUpStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('CLOSED')) return _FollowUpStatus.closed;
  if (status.contains('PARTIAL')) return _FollowUpStatus.partiallyRecovered;
  if (status.contains('INVEST')) return _FollowUpStatus.investigating;
  if (status.contains('EVIDENCE')) return _FollowUpStatus.awaitingEvidence;
  return _FollowUpStatus.open;
}
