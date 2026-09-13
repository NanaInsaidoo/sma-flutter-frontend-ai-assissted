import 'dart:async';

import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';

// ignore_for_file: unused_field, unused_element_parameter

import '../../approvals/data/approval_api_client.dart';
import '../../approvals/domain/approval_models.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../theme/app_theme.dart';
import '../data/finance_api_client.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
    this.recordedBy,
    this.currentUserId,
    this.role,
    this.openNewRequisitionOnLoad = false,
    this.onNewRequisitionRequestConsumed,
    this.financeApi,
    this.approvalApi,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final String? recordedBy;
  final int? currentUserId;
  final String? role;
  final bool openNewRequisitionOnLoad;
  final VoidCallback? onNewRequisitionRequestConsumed;
  final FinanceApiClient? financeApi;
  final ApprovalApiClient? approvalApi;

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
  late List<_ExpenseReversal> _expenseReversals;
  late List<_RequisitionRecord> _requisitions;
  late List<_TopUpRequest> _topUps;
  List<_FinanceActor> _topUpApprovers = [];
  List<_FinanceActor> _topUpDisbursers = [];
  late List<_PocketTransfer> _pocketTransfers;
  late List<_ReconciliationRecord> _reconciliations;
  late List<_FinancialFollowUp> _financialFollowUps;
  late final FinanceApiClient _financeApi;
  late final ApprovalApiClient _approvalApi;
  bool _isLoadingFinance = true;
  bool _requiresCycleSetup = false;
  String? _financeLoadError;
  int? _academicTermId;
  bool _newRequisitionRequestHandled = false;
  Timer? _receiptReminderTimer;
  bool _isRefreshingReceiptReminders = false;

  _ExpenseTab _tab = _ExpenseTab.overview;
  _FinanceLedgerPage? _financeLedgerPage;
  _TopUpRequest? _selectedTopUp;
  List<_TopUpEvent> _selectedTopUpEvents = [];
  _ReconciliationRecord? _selectedReconciliation;
  String _expenseQuery = '';
  String _expenseFilter = 'All';
  String _requisitionFilter = 'All';
  String _requisitionFundingFilter = 'All funding';
  _PettyCashSection _pettyCashSection = _PettyCashSection.workspace;
  String _topUpQuery = '';
  String _topUpFilter = 'All';
  String _transferQuery = '';
  String _reconciliationStatusFilter = 'All statuses';
  String _followUpStatusFilter = 'All statuses';
  DateTime? _reconciliationFromDate;
  DateTime? _reconciliationToDate;
  _ExpenseSortField _expenseSortField = _ExpenseSortField.date;
  bool _expenseSortAscending = false;
  int _schoolExpensePage = 0;
  int _pettyCashExpensePage = 0;
  int _myExpensePage = 0;
  int _topUpPage = 0;
  int _transferPage = 0;

  static const _expensePageSize = 8;
  static const _ledgerPageSize = 8;

  @override
  void initState() {
    super.initState();
    _settings = _SchoolExpenseSettings.empty();
    _float = _PettyCashFloat.empty();
    _expenses = [];
    _expenseReversals = [];
    _requisitions = [];
    _topUps = [];
    _pocketTransfers = [];
    _reconciliations = [];
    _financialFollowUps = [];
    _tab = _canViewAllFinance ? _ExpenseTab.overview : _ExpenseTab.requisitions;
    _financeApi =
        widget.financeApi ??
        FinanceApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    _approvalApi =
        widget.approvalApi ??
        ApprovalApiClient(
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    unawaited(_loadFinanceWorkspace());
  }

  @override
  void dispose() {
    _receiptReminderTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.role != oldWidget.role) {
      _tab = _canViewAllFinance
          ? _ExpenseTab.overview
          : _ExpenseTab.requisitions;
    }
    if (widget.openNewRequisitionOnLoad &&
        !oldWidget.openNewRequisitionOnLoad) {
      _newRequisitionRequestHandled = false;
      _maybeOpenRequestedRequisition();
    }
  }

  double get _cashBalance => _float.cashBalance;
  double get _momoBalance => _float.momoBalance;
  double get _totalFloatBalance => _cashBalance + _momoBalance;
  bool get _canApproveFinance {
    final role = widget.role?.trim().toUpperCase();
    return role == 'ADMINISTRATOR' ||
        role == 'ADMIN' ||
        role == 'HEADMASTER' ||
        role == 'HEAD_TEACHER' ||
        role == 'SUPER_ADMIN';
  }

  bool get _canViewAllFinance {
    final role = widget.role?.trim().toUpperCase();
    return role == 'ADMINISTRATOR' ||
        role == 'ADMIN' ||
        role == 'HEADMASTER' ||
        role == 'HEAD_TEACHER' ||
        role == 'BURSAR' ||
        role == 'SUPER_ADMIN';
  }

  List<_ExpenseTab> get _visibleTabs => _canViewAllFinance
      ? _ExpenseTab.values
            .where((tab) => tab != _ExpenseTab.myExpenses)
            .toList()
      : const [_ExpenseTab.requisitions, _ExpenseTab.myExpenses];

  List<_ExpenseRecord> get _recentExpenses {
    final records = List<_ExpenseRecord>.from(_expenses)
      ..sort((left, right) {
        final dateOrder = right.transactionDate.compareTo(left.transactionDate);
        if (dateOrder != 0) return dateOrder;
        return (right.serverId ?? 0).compareTo(left.serverId ?? 0);
      });
    return records.take(5).toList();
  }

  double get _totalSpend =>
      _expenses.fold(0, (total, item) => total + item.accountingAmount);
  double get _pettySpend => _expenses
      .where((item) => item.source == _ExpenseSource.pettyCash)
      .fold(0, (total, item) => total + item.accountingAmount);
  double get _directSpend => _expenses
      .where((item) => item.source == _ExpenseSource.direct)
      .fold(0, (total, item) => total + item.accountingAmount);
  bool _isCurrentUser(int? userId) =>
      userId != null && widget.currentUserId == userId;

  bool _isAssignedRequisitionApprover(_RequisitionRecord item) =>
      _isCurrentUser(item.approverUserId) ||
      (item.approverUserId == null && _canApproveFinance);

  int get _pendingApprovalCount {
    final requisitions = _requisitions.where(
      (item) =>
          item.status == _RequisitionStatus.pending &&
          _isAssignedRequisitionApprover(item),
    );
    final topUpApprovals = _topUps.where(
      (item) =>
          item.status == _TopUpStatus.pending &&
          _isCurrentUser(item.approverUserId),
    );
    final disbursements = _topUps.where(
      (item) =>
          (item.status == _TopUpStatus.approved ||
              item.status == _TopUpStatus.disputed) &&
          _isCurrentUser(item.disburserUserId),
    );
    final confirmations = _topUps.where(
      (item) =>
          (item.status == _TopUpStatus.disbursed ||
              item.status == _TopUpStatus.corrected) &&
          _isCurrentUser(item.requesterUserId),
    );
    final financeReviews = _canApproveFinance
        ? _expenses.where(
            (item) =>
                item.status == _ExpenseStatus.pendingRatification ||
                item.varianceStatus == _VarianceStatus.pendingReview,
          )
        : const <_ExpenseRecord>[];
    final reversalApprovals = _expenseReversals.where(
      (item) =>
          item.status == _ExpenseReversalStatus.pending &&
          _isCurrentUser(item.approverUserId),
    );
    return requisitions.length +
        topUpApprovals.length +
        disbursements.length +
        confirmations.length +
        financeReviews.length +
        reversalApprovals.length;
  }

  int get _activeTopUpCount =>
      _topUps.where((item) => !item.status.isHistorical).length;

  int get _openReconciliationCount => _reconciliations
      .where(
        (item) =>
            item.status == _ReconciliationStatus.requested ||
            item.status == _ReconciliationStatus.inProgress ||
            item.status == _ReconciliationStatus.varianceOpen,
      )
      .length;

  int get _openFollowUpCount =>
      _financialFollowUps.where((item) => !item.isClosed).length;

  int get _pettyCashPendingCount =>
      _activeTopUpCount + _openReconciliationCount + _openFollowUpCount;

  List<_TopUpRequest> get _overdueFundsConfirmations {
    final now = DateTime.now();
    final records = _topUps.where((item) {
      final disbursedAt = item.disbursedAt;
      final awaitingConfirmation =
          item.status == _TopUpStatus.disbursed ||
          item.status == _TopUpStatus.disputed ||
          item.status == _TopUpStatus.corrected;
      return awaitingConfirmation &&
          disbursedAt != null &&
          now.difference(disbursedAt).inMinutes >= 15;
    }).toList();
    records.sort(
      (left, right) => left.disbursedAt!.compareTo(right.disbursedAt!),
    );
    return records;
  }

  int _confirmationLateByMinutes(_TopUpRequest item) =>
      (DateTime.now().difference(item.disbursedAt!).inMinutes - 15).clamp(
        0,
        999999,
      );

  void _syncReceiptReminderTimer() {
    final hasAwaitingConfirmation = _topUps.any(
      (item) =>
          item.disbursedAt != null &&
          (item.status == _TopUpStatus.disbursed ||
              item.status == _TopUpStatus.disputed ||
              item.status == _TopUpStatus.corrected),
    );
    if (!hasAwaitingConfirmation) {
      _receiptReminderTimer?.cancel();
      _receiptReminderTimer = null;
      return;
    }
    _receiptReminderTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
      unawaited(_refreshTopUpsForReminders());
    });
  }

  Future<void> _refreshTopUpsForReminders() async {
    final termId = _academicTermId;
    if (!_canViewAllFinance ||
        termId == null ||
        _isRefreshingReceiptReminders) {
      return;
    }
    _isRefreshingReceiptReminders = true;
    try {
      final response = await _financeApi.get(
        '/api/schools/${widget.customSchoolId}/finance/top-ups',
        query: {'academicTermId': '$termId', 'page': '0', 'size': '200'},
      );
      if (!mounted) return;
      setState(() => _topUps = _topUpRecords(response));
      _syncReceiptReminderTimer();
    } on FinanceApiException {
      // Keep the current reminder visible and retry on the next minute tick.
    } finally {
      _isRefreshingReceiptReminders = false;
    }
  }

  List<_ExpenseRecord> _visibleExpensesFor(_ExpenseSource? source) {
    final query = _expenseQuery.trim().toLowerCase();
    final records = _expenses.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.expenseId.toLowerCase().contains(query) ||
          item.description.toLowerCase().contains(query) ||
          item.payee.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      final matchesFilter =
          _expenseFilter == 'All' ||
          (_expenseFilter == 'Emergency' && item.isEmergency) ||
          (_expenseFilter == 'Refunded' &&
              (item.status == _ExpenseStatus.partiallyRefunded ||
                  item.status == _ExpenseStatus.fullyRefunded));
      return (source == null || item.source == source) &&
          matchesQuery &&
          matchesFilter;
    }).toList();
    records.sort((left, right) {
      final comparison = switch (_expenseSortField) {
        _ExpenseSortField.expense => left.description.toLowerCase().compareTo(
          right.description.toLowerCase(),
        ),
        _ExpenseSortField.amount => left.netAmount.compareTo(right.netAmount),
        _ExpenseSortField.status => left.status.label.compareTo(
          right.status.label,
        ),
        _ExpenseSortField.date => left.transactionDate.compareTo(
          right.transactionDate,
        ),
      };
      if (comparison != 0) {
        return _expenseSortAscending ? comparison : -comparison;
      }
      final idComparison = (left.serverId ?? 0).compareTo(right.serverId ?? 0);
      return _expenseSortAscending ? idComparison : -idComparison;
    });
    return records;
  }

  int _expensePageFor(_ExpenseSource? source) => switch (source) {
    _ExpenseSource.direct => _schoolExpensePage,
    _ExpenseSource.pettyCash => _pettyCashExpensePage,
    null => _myExpensePage,
  };

  void _setExpensePage(_ExpenseSource? source, int page) {
    setState(() {
      if (source == _ExpenseSource.direct) {
        _schoolExpensePage = page;
      } else if (source == _ExpenseSource.pettyCash) {
        _pettyCashExpensePage = page;
      } else {
        _myExpensePage = page;
      }
    });
  }

  void _resetExpensePages() {
    _schoolExpensePage = 0;
    _pettyCashExpensePage = 0;
    _myExpensePage = 0;
  }

  void _sortExpenses(_ExpenseSortField field) {
    setState(() {
      if (_expenseSortField == field) {
        _expenseSortAscending = !_expenseSortAscending;
      } else {
        _expenseSortField = field;
        _expenseSortAscending = field != _ExpenseSortField.date;
      }
      _resetExpensePages();
    });
  }

  List<_RequisitionRecord> get _visibleRequisitions {
    return _requisitions.where((item) {
      final matchesStatus =
          _requisitionFilter == 'All' ||
          item.status.label == _requisitionFilter;
      final matchesFunding =
          _requisitionFundingFilter == 'All funding' ||
          item.fundingSource.label == _requisitionFundingFilter;
      return matchesStatus && matchesFunding;
    }).toList();
  }

  List<_TopUpRequest> get _visibleTopUps {
    final query = _topUpQuery.trim().toLowerCase();
    return _topUps.where((item) {
      final matchesQuery =
          query.isEmpty || item.requestId.toLowerCase().contains(query);
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
      final baseResults = await Future.wait<dynamic>([
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/${_canViewAllFinance ? 'overview' : 'policy'}',
          query: {'academicTermId': '$termId'},
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/requisitions',
          query: termQuery,
        ),
        _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/top-up-actors',
        ),
      ]);
      final managerResults = _canViewAllFinance
          ? await Future.wait<dynamic>([
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
            ])
          : const <dynamic>[];
      final requesterTransactions = _canViewAllFinance
          ? null
          : await _financeApi.get(
              '/api/schools/${widget.customSchoolId}/finance/transactions/mine',
              query: termQuery,
            );

      if (!mounted) return;
      final overview = _asMap(baseResults[0]);
      final cycle = _canViewAllFinance ? _asMap(overview['cycle']) : overview;
      final pockets = _asMap(overview['pockets']);
      final transactions = _canViewAllFinance
          ? _transactionRecords(managerResults[0])
          : _transactionRecords(requesterTransactions);
      final topUps = _canViewAllFinance
          ? _topUpRecords(managerResults[3])
          : <_TopUpRequest>[];
      final actors = _asMap(baseResults[2]);
      final reconciliations = _canViewAllFinance
          ? _reconciliationRecords(managerResults[1])
          : <_ReconciliationRecord>[];
      final selectedTopUpId = _selectedTopUp?.serverId;
      final selectedReconciliationId = _selectedReconciliation?.serverId;
      _TopUpRequest? refreshedTopUp;
      _ReconciliationRecord? refreshedReconciliation;
      if (selectedTopUpId != null) {
        for (final item in topUps) {
          if (item.serverId == selectedTopUpId) {
            refreshedTopUp = item;
            break;
          }
        }
      }
      if (selectedReconciliationId != null) {
        for (final item in reconciliations) {
          if (item.serverId == selectedReconciliationId) {
            refreshedReconciliation = item;
            break;
          }
        }
      }
      setState(() {
        _academicTermId = termId;
        _settings = _settingsFromCycle(cycle);
        _float = _PettyCashFloat(
          cashBalance: _asDouble(pockets['cash'] ?? cycle['cashBalance']),
          momoBalance: _asDouble(pockets['momo'] ?? cycle['momoBalance']),
          status: _floatStatus(cycle['status']),
        );
        _requisitions = _requisitionRecords(baseResults[1]);
        _expenses = transactions;
        _pocketTransfers = _canViewAllFinance
            ? _transferRecords(managerResults[0])
            : <_PocketTransfer>[];
        _topUps = topUps;
        _topUpApprovers = _financeActors(actors['approvers']);
        _topUpDisbursers = _financeActors(actors['disbursers']);
        _reconciliations = reconciliations;
        if (selectedTopUpId != null) {
          _selectedTopUp = refreshedTopUp;
        }
        if (selectedReconciliationId != null) {
          _selectedReconciliation = refreshedReconciliation;
        }
        _financialFollowUps = _canViewAllFinance
            ? _followUpRecords(managerResults[2])
            : <_FinancialFollowUp>[];
        _isLoadingFinance = false;
        _requiresCycleSetup = false;
        _financeLoadError = null;
      });
      _syncReceiptReminderTimer();
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
    _maybeOpenRequestedRequisition();
  }

  void _maybeOpenRequestedRequisition() {
    if (!mounted ||
        !widget.openNewRequisitionOnLoad ||
        _newRequisitionRequestHandled ||
        _isLoadingFinance ||
        _financeLoadError != null ||
        _requiresCycleSetup ||
        _academicTermId == null) {
      return;
    }
    _newRequisitionRequestHandled = true;
    widget.onNewRequisitionRequestConsumed?.call();
    setState(() => _tab = _ExpenseTab.requisitions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openCreateRequisitionDialog();
    });
  }

  Widget _buildCycleSetupState() {
    final canSetUpCycle = _canApproveFinance;
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
                  Text(
                    canSetUpCycle
                        ? 'Set up petty cash for this term'
                        : 'Petty cash setup is pending',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    canSetUpCycle
                        ? 'This academic term does not yet have a petty-cash cycle. '
                              'Configure the float controls before recording expenses, '
                              'transfers, top-ups, or reconciliations.'
                        : 'An administrator or head teacher must configure the term’s '
                              'float controls before the bursar can record expenses, '
                              'transfers, top-ups, or reconciliations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  if (canSetUpCycle)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openPettyCashSetupHelp,
                          icon: const Icon(Icons.help_outline_rounded),
                          label: const Text('Setup help'),
                        ),
                        FilledButton.icon(
                          onPressed: _openCycleSetupDialog,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Set up cycle'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPettyCashSetupHelp() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.green),
            SizedBox(width: 10),
            Text('Petty-cash setup help'),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These settings control how much the school keeps as petty cash and when replenishment is recommended.',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 18),
                _setupHelpItem(
                  title: 'Approved float',
                  description:
                      'The total petty-cash amount authorised for the term. Cash and MoMo together should normally not exceed this amount.',
                  example: 'Example: GH¢1,000',
                ),
                _setupHelpItem(
                  title: 'Single petty-cash expense limit',
                  description:
                      'The maximum allowed for one petty-cash transaction. Larger payments should use another payment route or receive additional authorisation.',
                  example: 'Example: GH¢300',
                ),
                _setupHelpItem(
                  title: 'Refill threshold',
                  description:
                      'The remaining Cash and MoMo balance at which the system warns that petty cash is running low. It recommends a top-up but does not add money automatically.',
                  example: 'Example: GH¢250',
                ),
                _setupHelpItem(
                  title: 'Variance tolerance',
                  description:
                      'The percentage used to classify the difference between the approved amount and actual spending. Every difference remains visible and must be reviewed.',
                  example:
                      'Example: approved GH¢200, actual GH¢205 = 2.5% variance',
                ),
                _setupHelpItem(
                  title: 'Requisition expiry',
                  description:
                      'How long a submitted requisition remains valid. Once it expires, it can no longer be approved or used to record spending.',
                  example: 'Recommended: 7 days',
                ),
                _setupHelpItem(
                  title: 'Automatic approval',
                  description:
                      'Administrators may allow standard petty-cash requests up to a smaller limit to approve automatically. The single expense limit still applies, and every automatic approval is recorded in history. Cash or MoMo balance is checked when actual spending is recorded.',
                  example: 'Recommended: Off until the school adopts a policy',
                ),
                _setupHelpItem(
                  title: 'MoMo wallet number',
                  description:
                      'The school wallet used for the MoMo portion of petty cash. Leave it empty when the school operates with cash only.',
                  example: 'Optional',
                ),
                _setupHelpItem(
                  title: 'Capture transaction fees',
                  description:
                      'Records MoMo and bank charges separately so the true cost and pocket balance remain accurate.',
                  example: 'Recommended: On',
                ),
                _setupHelpItem(
                  title: 'Allow self-disbursement',
                  description:
                      'Allows an approved requester to release the funds themselves. Leave this off when a separate bursar or custodian controls payments.',
                  example: 'Recommended: Off',
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: .25),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended starting configuration',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Approved float: GH¢1,000\n'
                        'Single petty-cash expense limit: GH¢300\n'
                        'Refill threshold: GH¢250\n'
                        'Variance tolerance: 5%\n'
                        'Requisition expiry: 7 days',
                        style: TextStyle(height: 1.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'After saving the cycle, record the initial funding through the first top-up so the Cash and MoMo pocket balances have a complete audit trail.',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _openCycleSettingsHistory() {
    final cycleId = _settings.cycleId;
    if (cycleId == null) {
      _snack('Save the petty-cash settings before viewing their history.');
      return;
    }
    final history = _financeApi.get(
      '/api/schools/${widget.customSchoolId}/finance/notes',
      query: {'parentType': 'CYCLE', 'parentId': '$cycleId'},
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Petty-cash settings history'),
        content: SizedBox(
          width: 640,
          child: FutureBuilder<dynamic>(
            future: history,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const _InlineNotice(
                  icon: Icons.sync_problem_outlined,
                  color: AppColors.amber,
                  text: 'Settings history could not be loaded.',
                );
              }
              final entries = _financeHistoryEntries(snapshot.data);
              if (entries.isEmpty) {
                return const Text(
                  'No settings changes have been recorded yet.',
                  style: TextStyle(color: AppColors.muted),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  children: [
                    for (final entry in entries)
                      _ActionTile(
                        icon: entry.icon,
                        iconColor: entry.color,
                        title: entry.label,
                        subtitle:
                            '${entry.author} · ${_dateTime(entry.createdAt)}${entry.note.isEmpty ? '' : '\n${entry.note}'}',
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _setupHelpItem({
    required String title,
    required String description,
    required String example,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 4),
          Text(
            example,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCycleSetupDialog() async {
    final isExistingCycle = _settings.cycleId != null;
    final approvedController = TextEditingController(
      text: _amountInput(_settings.floatApprovedAmount),
    );
    final ceilingController = TextEditingController(
      text: _amountInput(_settings.floatCeiling),
    );
    final thresholdController = TextEditingController(
      text: _amountInput(_settings.floatThreshold),
    );
    final momoController = TextEditingController(
      text: _settings.momoWalletNumber,
    );
    final toleranceController = TextEditingController(
      text: isExistingCycle ? '${_settings.varianceTolerancePercent}' : '5',
    );
    final expiryController = TextEditingController(
      text: isExistingCycle ? '${_settings.requisitionExpiryDays}' : '7',
    );
    final autoApprovalController = TextEditingController(
      text: _amountInput(_settings.autoApprovalLimit),
    );
    var captureTransactionFees = isExistingCycle
        ? _settings.captureTransactionFees
        : true;
    var selfDisburse = _settings.selfDisburse;
    var autoApprovePettyCash = _settings.autoApprovePettyCash;
    var isSaving = false;
    String? errorMessage;
    final formKey = GlobalKey<FormState>();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !isSaving,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isExistingCycle
                        ? 'Petty-cash settings'
                        : 'Set up petty-cash cycle',
                  ),
                ),
                if (isExistingCycle)
                  TextButton.icon(
                    onPressed: _openCycleSettingsHistory,
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('History'),
                  ),
                TextButton.icon(
                  onPressed: _openPettyCashSetupHelp,
                  icon: const Icon(Icons.help_outline_rounded, size: 18),
                  label: const Text('Help'),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
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
                              validator: (text) {
                                final value = _strictAmount(text ?? '');
                                return value == null || value <= 0
                                    ? 'Enter an amount greater than zero.'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _cycleAmountField(
                              controller: ceilingController,
                              label: 'Single petty-cash expense limit (GH¢)',
                              hint: 'e.g. 300',
                              validator: (text) {
                                final value = _strictAmount(text ?? '');
                                final approved = _strictAmount(
                                  approvedController.text,
                                );
                                if (value == null || value <= 0) {
                                  return 'Enter an amount greater than zero.';
                                }
                                return approved != null && value > approved
                                    ? 'Cannot exceed the approved float.'
                                    : null;
                              },
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
                              hint: 'e.g. 250',
                              validator: (text) {
                                final value = _strictAmount(text ?? '');
                                final approved = _strictAmount(
                                  approvedController.text,
                                );
                                if (value == null || value < 0) {
                                  return 'Enter zero or a valid amount.';
                                }
                                return approved != null && value > approved
                                    ? 'Cannot exceed the approved float.'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _cycleAmountField(
                              controller: toleranceController,
                              label: 'Variance tolerance (%)',
                              hint: 'e.g. 5',
                              validator: (text) {
                                final value = _strictAmount(text ?? '');
                                return value == null || value < 0 || value > 100
                                    ? 'Enter a percentage from 0 to 100.'
                                    : null;
                              },
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
                        validator: (text) {
                          final value = int.tryParse(text?.trim() ?? '');
                          return value == null || value < 1 || value > 90
                              ? 'Enter a validity period from 1 to 90 days.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Automatically approve small requests',
                        ),
                        subtitle: const Text(
                          'Only standard petty-cash requests within the administrator-set limit qualify. Pocket balance is checked when actual spending is recorded.',
                        ),
                        value: autoApprovePettyCash,
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(
                                () => autoApprovePettyCash = value,
                              ),
                      ),
                      if (autoApprovePettyCash) ...[
                        const SizedBox(height: 6),
                        _cycleAmountField(
                          controller: autoApprovalController,
                          label: 'Automatic approval limit (GH¢)',
                          hint: 'e.g. 100',
                          validator: (text) {
                            final value = _strictAmount(text ?? '');
                            final ceiling = _strictAmount(
                              ceilingController.text,
                            );
                            if (value == null || value <= 0) {
                              return 'Enter an amount greater than zero.';
                            }
                            return ceiling != null && value > ceiling
                                ? 'Cannot exceed the single expense limit.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
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
                        if (!(formKey.currentState?.validate() ?? false)) {
                          return;
                        }
                        final approved = _strictAmount(
                          approvedController.text,
                        )!;
                        final ceiling = _strictAmount(ceilingController.text)!;
                        final threshold = _strictAmount(
                          thresholdController.text,
                        )!;
                        final tolerance = _strictAmount(
                          toleranceController.text,
                        )!;
                        final expiry = int.parse(expiryController.text.trim());
                        final autoApprovalLimit = autoApprovePettyCash
                            ? _strictAmount(autoApprovalController.text)!
                            : 0.0;
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
                              'autoApprovePettyCash': autoApprovePettyCash,
                              'autoApprovalLimit': autoApprovalLimit,
                            },
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                          if (!mounted) return;
                          await _loadFinanceWorkspace();
                          if (mounted) {
                            _snack(
                              isExistingCycle
                                  ? 'Petty-cash settings updated.'
                                  : 'Petty-cash cycle set up for this term.',
                            );
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
                    : Text(isExistingCycle ? 'Save settings' : 'Save cycle'),
              ),
            ],
          ),
        ),
      );
    } finally {
      // Keep the controllers alive until the dialog's closing transition has
      // finished painting. Disposing them immediately after Navigator.pop can
      // leave the outgoing route trying to render a disposed controller.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      approvedController.dispose();
      ceilingController.dispose();
      thresholdController.dispose();
      momoController.dispose();
      toleranceController.dispose();
      expiryController.dispose();
      autoApprovalController.dispose();
    }
  }

  Widget _cycleAmountField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) => _cycleTextField(
    controller: controller,
    label: label,
    hint: hint,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    validator: validator,
  );

  Widget _cycleTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
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
      final selectedTopUp = _selectedTopUp;
      if (selectedTopUp != null) {
        await _loadTopUpEvents(selectedTopUp);
      }
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
      cycleId: _nullableServerId(cycle['id']),
      floatApprovedAmount: _asDouble(cycle['floatApprovedAmount']),
      floatCeiling: _asDouble(cycle['floatCeiling']),
      floatThreshold: _asDouble(cycle['floatThreshold']),
      autoApprovePettyCash: _asBool(cycle['autoApprovePettyCash']),
      autoApprovalLimit: _asDouble(cycle['autoApprovalLimit']),
      captureTransactionFees: _asBool(cycle['captureTransactionFees']),
      selfDisburse: _asBool(cycle['selfDisburse']),
      varianceTolerancePercent: _asInt(cycle['varianceTolerancePercent']),
      requisitionExpiryDays: _asInt(cycle['requisitionExpiryDays']),
      momoWalletNumber: _asText(cycle['momoWalletNumber']),
    );
  }

  List<_ExpenseRecord> _transactionRecords(dynamic response) {
    final transactions = _pageContent(response).map(_asMap).toList();
    _expenseReversals = transactions
        .where(
          (value) =>
              _asText(value['transactionType']).toUpperCase() ==
              'EXPENSE_REVERSAL',
        )
        .map(_expenseReversalFromMap)
        .toList();
    final records = transactions
        .where(
          (value) =>
              _isExpenseTransaction(value) &&
              _asText(value['transactionType']).toUpperCase() !=
                  'EXPENSE_REVERSAL',
        )
        .map(_expenseFromMap)
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
    for (final reversal in _expenseReversals) {
      final original = byServerId[reversal.parentTransactionId];
      if (original == null) continue;
      if (reversal.status == _ExpenseReversalStatus.pending ||
          reversal.status == _ExpenseReversalStatus.approved) {
        original.reversal = reversal;
      }
      if (reversal.status == _ExpenseReversalStatus.approved) {
        original.status = _ExpenseStatus.reversed;
      } else if (reversal.status == _ExpenseReversalStatus.pending) {
        original.status = _ExpenseStatus.pendingReversal;
      }
    }
    return records;
  }

  _ExpenseReversal _expenseReversalFromMap(Map<String, dynamic> value) {
    return _ExpenseReversal(
      serverId: _nullableServerId(value['id']),
      reference: _asText(value['transactionCode'] ?? value['id']),
      parentTransactionId: _asInt(value['parentTransactionId']),
      amount: _asDouble(
        value['requestedAmount'] ??
            value['approvedAmount'] ??
            value['actualAmount'],
      ).abs(),
      reasonCode: _asText(value['category'], fallback: 'OTHER_RECORDING_ERROR'),
      notes: _asText(value['notes']),
      status: _expenseReversalStatus(value['status']),
      requester: _asText(value['requesterName'] ?? value['createdBy']),
      requesterUserId: _nullableServerId(value['requesterUserId']),
      approver: _asText(value['approverName'], fallback: 'Not assigned'),
      approverUserId: _nullableServerId(value['approverUserId']),
      decidedBy: _nullableText(value['confirmedBy'] ?? value['approvedBy']),
      requestedAt: _asDate(value['createdAt'] ?? value['transactionDate']),
      decidedAt: _nullableDate(value['confirmedAt']),
    );
  }

  bool _isExpenseTransaction(Map<String, dynamic> value) {
    final type = _asText(value['transactionType']).toUpperCase();
    return type.contains('EXPENSE') ||
        type.contains('SPEND') ||
        type.contains('DIRECT');
  }

  _ExpenseRecord _expenseFromMap(Map<String, dynamic> value) {
    final status = _expenseStatus(value['status']);
    final sourcePocket = _asText(value['sourcePocket']).toUpperCase();
    final channel = _paymentChannel(
      value['paymentChannel'],
      sourcePocket: sourcePocket,
    );
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
      approvedAmount: _nullableDouble(
        value['approvedAmount'] ??
            (_asBool(value['requiresRatification'])
                ? value['requestedAmount']
                : null),
      ),
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
      isEmergency:
          _asBool(value['emergency']) ||
          _asBool(value['requiresRatification']) ||
          status == _ExpenseStatus.pendingRatification ||
          status == _ExpenseStatus.ratified,
      approvalStatus: status == _ExpenseStatus.ratified
          ? _ExpenseApprovalStatus.ratified
          : status == _ExpenseStatus.pendingRatification
          ? _ExpenseApprovalStatus.pendingRatification
          : _asBool(value['requiresRatification'])
          ? _ExpenseApprovalStatus.ratified
          : _ExpenseApprovalStatus.approved,
      varianceStatus: status == _ExpenseStatus.pendingVarianceReview
          ? _VarianceStatus.pendingReview
          : _VarianceStatus.none,
    );
  }

  List<_RequisitionRecord> _requisitionRecords(dynamic response) {
    return _pageContent(response).map((value) {
      final item = _asMap(value);
      final expiresAt = _asDate(item['expiresAt']);
      var status = _requisitionStatus(item['status']);
      if (_hasUsableDate(expiresAt) &&
          DateTime.now().isAfter(expiresAt) &&
          (status == _RequisitionStatus.pending ||
              status == _RequisitionStatus.approved)) {
        status = _RequisitionStatus.expired;
      }
      return _RequisitionRecord(
        serverId: _nullableServerId(item['id']),
        id: _asText(item['requisitionCode'] ?? item['id']),
        title: _asText(item['description']),
        category: _asText(item['category'], fallback: 'Uncategorised'),
        payee: _asText(item['vendor'], fallback: 'Not provided'),
        requestedBy: _asText(item['requestedBy'], fallback: 'Not provided'),
        requesterUserId: _nullableServerId(item['requesterUserId']),
        approver: _nullableText(item['approverName']),
        approverUserId: _nullableServerId(item['approverUserId']),
        requestedAmount: _asDouble(item['requestedAmount']),
        approvedAmount: _nullableDouble(item['approvedAmount']),
        requestedAt: _asDate(item['requestedAt'] ?? item['createdAt']),
        approvedAt: _nullableDate(item['approvedAt']),
        updatedAt: _asDate(item['updatedAt'] ?? item['createdAt']),
        expiresAt: expiresAt,
        status: status,
        fundingSource: _fundingSource(item['fundingSource']),
        notes: _asText(item['notes'] ?? item['reason']),
        isEmergency: _asBool(item['emergency']),
        verbalApprover: _nullableText(item['verbalApprover']),
      );
    }).toList();
  }

  List<_TopUpRequest> _topUpRecords(dynamic response) {
    final records = _pageContent(response).map((value) {
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
        approvedAt: _nullableDate(item['approvedAt']),
        updatedAt: _asDate(item['updatedAt'] ?? item['createdAt']),
        confirmedAt: _nullableDate(item['confirmedAt']),
        disbursedAt: _nullableDate(item['disbursedAt']),
        actualReceived:
            status == _TopUpStatus.confirmed ||
                status == _TopUpStatus.confirmedWithDiscrepancy
            ? _nullableDouble(item['actualAmount'] ?? item['actualReceived'])
            : null,
        requester: _asText(
          item['requesterName'] ?? item['createdBy'],
          fallback: 'Not recorded',
        ),
        requesterUserId: _nullableServerId(item['requesterUserId']),
        approver: _nullableText(item['approverName']),
        approverUserId: _nullableServerId(item['approverUserId']),
        disburser: _nullableText(item['disburserName']),
        disburserUserId: _nullableServerId(item['disburserUserId']),
        receiver: _nullableText(item['receiverName']),
        receiverUserId: _nullableServerId(item['receiverUserId']),
        cashAmount: _nullableDouble(item['cashAmount']),
        momoAmount: _nullableDouble(item['momoAmount']),
        momoWalletNumber: _nullableText(item['momoWalletNumber']),
      );
    }).toList();
    records.sort((a, b) {
      final byDate = b.requestedAt.compareTo(a.requestedAt);
      if (byDate != 0) return byDate;
      return (b.serverId ?? 0).compareTo(a.serverId ?? 0);
    });
    return records;
  }

  List<_FinanceActor> _financeActors(dynamic value) =>
      (value is List ? value : const [])
          .map((entry) => _asMap(entry))
          .map(
            (entry) => _FinanceActor(
              id: _asInt(entry['id']),
              name: _asText(entry['name'], fallback: 'Unnamed user'),
              username: _asText(entry['username']),
              role: _asText(entry['role']),
            ),
          )
          .where((entry) => entry.id > 0)
          .toList();

  List<_FinanceHistoryEntry> _financeHistoryEntries(dynamic value) =>
      (value is List ? value : const [])
          .map((entry) => _asMap(entry))
          .map(
            (entry) => _FinanceHistoryEntry(
              eventType: _asText(entry['eventType'], fallback: 'NOTE'),
              author: _asText(entry['author'], fallback: 'System'),
              note: _asText(entry['note']),
              amount: _nullableDouble(entry['eventAmount']),
              createdAt: _asDate(entry['createdAt']),
            ),
          )
          .toList();

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
        notes: _asText(item['confirmationNotes']),
        evidenceReference: _asText(item['evidenceReference']),
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
        serverId: _nullableServerId(item['id']),
        reference: _asText(item['followUpCode'] ?? item['id']),
        type: _followUpType(item['type']),
        relatedReference: _followUpRelatedReference(item),
        relatedTransactionId: _nullableServerId(item['transactionId']),
        owner: _asText(item['responsibleParty'], fallback: 'Not assigned'),
        amount: _asDouble(item['amount']),
        createdAt: _asDate(item['createdAt']),
        dueDate: _nullableDate(item['dueDate']),
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

  String _followUpRelatedReference(Map<String, dynamic> item) {
    final reconciliationId = _nullableServerId(item['reconciliationId']);
    if (reconciliationId != null) {
      for (final reconciliation in _reconciliations) {
        if (reconciliation.serverId == reconciliationId) {
          return reconciliation.reference;
        }
      }
    }

    final transactionId = _nullableServerId(item['transactionId']);
    if (transactionId != null) {
      for (final expense in _expenses) {
        if (expense.serverId == transactionId) return expense.expenseId;
      }
      for (final topUp in _topUps) {
        if (topUp.serverId == transactionId) return topUp.requestId;
      }
    }

    return _asText(
      item['reconciliationId'] ?? item['transactionId'],
      fallback: 'Not linked',
    );
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
          if (_overdueFundsConfirmations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildFundsConfirmationReminder(),
          ],
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
        if (_canViewAllFinance) ...[
          OutlinedButton.icon(
            onPressed: _openReconciliationRequestDialog,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Request reconciliation'),
          ),
          const SizedBox(width: 10),
        ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rule_folder_outlined, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Rule in use: every normal expense requires an approved requisition before payment. Emergency spending may proceed with recorded verbal authorisation and must be ratified afterward.',
              style: const TextStyle(color: _text, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundsConfirmationReminder() {
    final records = _overdueFundsConfirmations;
    final oldest = records.first;
    final lateBy = _confirmationLateByMinutes(oldest);
    final multiple = records.length > 1;
    return Container(
      key: const ValueKey('overdue-funds-confirmation-banner'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        border: Border.all(color: const Color(0xFFFFB7B7)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.notification_important_outlined,
            color: AppColors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  multiple
                      ? '${records.length} funds-received confirmations are overdue'
                      : 'Funds-received confirmation overdue',
                  style: const TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${oldest.requestId} has not been confirmed by the receiver. Late by $lateBy ${lateBy == 1 ? 'minute' : 'minutes'}.',
                  style: const TextStyle(color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _openTopUpDetailPage(oldest),
            child: Text(multiple ? 'Review oldest' : 'Review now'),
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
          for (final tab in _visibleTabs)
            _TabPill(
              label: tab.label,
              active: _tab == tab,
              badgeCount: tab == _ExpenseTab.approvals
                  ? _pendingApprovalCount
                  : tab == _ExpenseTab.pettyCash
                  ? _pettyCashPendingCount
                  : 0,
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
      case _ExpenseTab.requisitions:
        return _buildRequisitionsTab();
      case _ExpenseTab.myExpenses:
        return _buildExpenseRegister(
          title: 'My expenses',
          subtitle:
              'Expenses recorded from your approved requisitions. Open a record to view its full audit trail.',
          source: null,
          allowFinancialActions: false,
        );
      case _ExpenseTab.schoolExpenses:
        return _buildSchoolExpensesTab();
      case _ExpenseTab.pettyCash:
        return _buildPettyCashTab();
      case _ExpenseTab.approvals:
        return _buildApprovalsTab();
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
                      'Petty cash ${_money(_pettySpend)} · School funds ${_money(_directSpend)}',
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
                  title: 'School expenses',
                  value: _money(_directSpend),
                  subtitle: 'Bank, cheque and direct MoMo payments',
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
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () =>
                          setState(() => _tab = _ExpenseTab.schoolExpenses),
                      child: const Text('School Expenses'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _tab = _ExpenseTab.pettyCash;
                        _pettyCashSection = _PettyCashSection.workspace;
                      }),
                      child: const Text('Petty Cash Expenses'),
                    ),
                  ],
                ),
                child: Column(
                  children: _recentExpenses.isEmpty
                      ? const [
                          _InlineNotice(
                            icon: Icons.receipt_long_outlined,
                            color: AppColors.muted,
                            text: 'No expenses have been recorded yet.',
                          ),
                        ]
                      : _recentExpenses.map(_expenseListTile).toList(),
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
              '$pendingRatifications emergency expense awaiting ratification',
          description: 'A head teacher must formally ratify the payment.',
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
          targetTab: _ExpenseTab.pettyCash,
        ),
      );
    }
    final pendingVariances = _expenses
        .where((item) => item.varianceStatus == _VarianceStatus.pendingReview)
        .length;
    if (pendingVariances > 0) {
      items.add(
        _AttentionItem(
          icon: Icons.difference_outlined,
          color: AppColors.red,
          title: '$pendingVariances expense variance awaiting review',
          description: 'The actual amount differs from the approved amount.',
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

  Widget _buildSchoolExpensesTab() {
    return _buildExpenseRegister(
      title: 'School expenses',
      subtitle:
          'Payments made from school bank accounts, cheques, or the main school MoMo account.',
      source: _ExpenseSource.direct,
    );
  }

  Widget _buildExpenseRegister({
    required String title,
    required String subtitle,
    required _ExpenseSource? source,
    bool allowFinancialActions = true,
  }) {
    final records = _visibleExpensesFor(source);
    final requestedPage = _expensePageFor(source);
    final maxPage = records.isEmpty
        ? 0
        : (records.length - 1) ~/ _expensePageSize;
    final page = requestedPage > maxPage ? maxPage : requestedPage;
    final firstIndex = page * _expensePageSize;
    final lastIndex = (firstIndex + _expensePageSize) > records.length
        ? records.length
        : firstIndex + _expensePageSize;
    final pageRecords = records.sublist(firstIndex, lastIndex);
    final pageKey = switch (source) {
      _ExpenseSource.direct => 'school-expenses',
      _ExpenseSource.pettyCash => 'petty-cash-expenses',
      null => 'my-expenses',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: title,
          subtitle: subtitle,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() {
                        _expenseQuery = value;
                        _resetExpensePages();
                      }),
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
                    items: const ['All', 'Emergency', 'Refunded'],
                    onChanged: (value) => setState(() {
                      _expenseFilter = value;
                      _resetExpensePages();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ExpenseTable(
                expenses: pageRecords,
                requisitionReference: _requisitionReference,
                onRefund: _openRefundDialog,
                onReverse: _openExpenseReversalDialog,
                canReverse: _canRequestExpenseReversal,
                onView: _openExpenseDetailDialog,
                onPrint: _printExpenseRecord,
                onDownload: _downloadExpenseCopy,
                allowFinancialActions: allowFinancialActions,
                sortField: _expenseSortField,
                sortAscending: _expenseSortAscending,
                onSort: _sortExpenses,
              ),
              const SizedBox(height: 14),
              _LedgerPagination(
                keyPrefix: pageKey,
                page: page,
                totalItems: records.length,
                pageSize: _expensePageSize,
                onPrevious: page == 0
                    ? null
                    : () => _setExpensePage(source, page - 1),
                onNext: page >= maxPage
                    ? null
                    : () => _setExpensePage(source, page + 1),
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
          'All spending requests in one place. Filter by funding source or status.',
      trailing: FilledButton.icon(
        onPressed: _openCreateRequisitionDialog,
        icon: const Icon(Icons.add),
        label: const Text('New requisition'),
        style: _primaryButtonStyle(),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fundingFilter = _Dropdown<String>(
                width: constraints.maxWidth < 720 ? constraints.maxWidth : 170,
                value: _requisitionFundingFilter,
                items: const ['All funding', 'School funds', 'Petty cash'],
                onChanged: (value) =>
                    setState(() => _requisitionFundingFilter = value),
              );
              final statusFilter = _Dropdown<String>(
                width: constraints.maxWidth < 720 ? constraints.maxWidth : 190,
                value: _requisitionFilter,
                items: const [
                  'All',
                  'Draft',
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
              );
              const guidance = Text(
                'Choose School funds or Petty cash when creating a request. The selected rules follow it through approval and payment.',
                style: TextStyle(color: _muted),
              );
              if (constraints.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    guidance,
                    const SizedBox(height: 12),
                    fundingFilter,
                    const SizedBox(height: 10),
                    statusFilter,
                  ],
                );
              }
              return Row(
                children: [
                  const Expanded(child: guidance),
                  fundingFilter,
                  const SizedBox(width: 10),
                  statusFilter,
                ],
              );
            },
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final section in _PettyCashSection.values)
              _TabPill(
                label: section.label,
                active: _pettyCashSection == section,
                badgeCount: switch (section) {
                  _PettyCashSection.workspace => _activeTopUpCount,
                  _PettyCashSection.reconciliations => _openReconciliationCount,
                  _PettyCashSection.followUps => _openFollowUpCount,
                },
                onTap: () => setState(() => _pettyCashSection = section),
              ),
          ],
        ),
        const SizedBox(height: 16),
        switch (_pettyCashSection) {
          _PettyCashSection.workspace => _buildPettyCashWorkspace(),
          _PettyCashSection.reconciliations => _buildReconciliationsTab(),
          _PettyCashSection.followUps => _buildFinancialFollowUpsTab(),
        },
      ],
    );
  }

  Widget _buildPettyCashWorkspace() {
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
            padding: const EdgeInsets.all(16),
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
                              fontSize: 28,
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
                        FilledButton.icon(
                          onPressed: _requestTopUp,
                          icon: const Icon(Icons.add_card_outlined),
                          label: const Text('Request top-up'),
                          style: _primaryButtonStyle(),
                        ),
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
                        if (_canApproveFinance)
                          OutlinedButton.icon(
                            onPressed: _openCycleSetupDialog,
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Settings'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: balanceRatio,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(balanceColor),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final pocketWidth = compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
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
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
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
                          label: 'Single expense limit',
                          value: _money(_settings.floatCeiling),
                        ),
                        _FloatLimit(
                          label: 'Top-up threshold',
                          value: _money(_settings.floatThreshold),
                        ),
                        _FloatLimit(
                          label: 'Automatic approval',
                          value: _settings.autoApprovePettyCash
                              ? 'Up to ${_money(_settings.autoApprovalLimit)}'
                              : 'Off',
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
        const SizedBox(height: 12),
        _buildPettyCashControlStrip(),
        const SizedBox(height: 12),
        _buildExpenseRegister(
          title: 'Petty cash expenses',
          subtitle:
              'Recorded spending paid from the controlled Cash or MoMo pocket.',
          source: _ExpenseSource.pettyCash,
        ),
      ],
    );
  }

  Widget _buildPettyCashControlStrip() {
    _TopUpRequest? currentTopUp;
    for (final item in _topUps) {
      if (!item.status.isHistorical) {
        currentTopUp = item;
        break;
      }
    }
    _ReconciliationRecord? openReconciliation;
    for (final item in _reconciliations) {
      if (item.status == _ReconciliationStatus.requested ||
          item.status == _ReconciliationStatus.inProgress) {
        openReconciliation = item;
        break;
      }
    }
    final latestTransfer = _pocketTransfers.isEmpty
        ? null
        : _pocketTransfers.first;

    return _SectionCard(
      title: 'Petty cash controls',
      subtitle: 'Open each workspace without scrolling past the expense list.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: width,
                child: _PettyCashControlCard(
                  icon: Icons.add_card_outlined,
                  title: 'Top-up requests',
                  status: currentTopUp?.status.label ?? 'No active request',
                  detail: currentTopUp == null
                      ? '${_topUps.length} requests recorded'
                      : '${currentTopUp.requestId} · ${_money(currentTopUp.requestedAmount)}',
                  color: currentTopUp?.status.color ?? AppColors.green,
                  actionLabel: 'Open history',
                  onTap: () => setState(
                    () => _financeLedgerPage = _FinanceLedgerPage.topUps,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _PettyCashControlCard(
                  icon: Icons.fact_check_outlined,
                  title: 'Reconciliations',
                  status: openReconciliation?.status.label ?? 'No open request',
                  detail:
                      openReconciliation?.reference ??
                      '${_reconciliations.length} records available',
                  color: openReconciliation?.status.color ?? AppColors.green,
                  actionLabel: 'Open workspace',
                  onTap: () => setState(
                    () => _pettyCashSection = _PettyCashSection.reconciliations,
                  ),
                ),
              ),
              SizedBox(
                width: width,
                child: _PettyCashControlCard(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Pocket transfers',
                  status: '${_pocketTransfers.length} recorded',
                  detail: latestTransfer == null
                      ? 'No transfers yet'
                      : '${latestTransfer.fromPocket} to ${latestTransfer.toPocket} · ${_money(latestTransfer.amount)}',
                  color: AppColors.blue,
                  actionLabel: 'Open history',
                  onTap: () => setState(
                    () => _financeLedgerPage = _FinanceLedgerPage.transfers,
                  ),
                ),
              ),
            ],
          );
        },
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
          trailing: _canApproveFinance
              ? FilledButton.icon(
                  onPressed: _openNewFollowUpDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Record follow-up'),
                  style: _primaryButtonStyle(),
                )
              : null,
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
                  isExpanded: true,
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
                            key: ValueKey('follow-up-${item.reference}'),
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
            _tab = _ExpenseTab.pettyCash;
            _pettyCashSection = _PettyCashSection.reconciliations;
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
                _ReadOnlyRow(
                  'Variance resolution',
                  _reconciliationResolutionLabel(item.varianceResolution),
                ),
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
                    _tab = _ExpenseTab.pettyCash;
                    _pettyCashSection = _PettyCashSection.followUps;
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
                            subtitle: '${item.expensesCount} expenses in cycle',
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
      (item) =>
          item.status == _RequisitionStatus.pending &&
          _isAssignedRequisitionApprover(item),
    );
    final pendingTopUps = _topUps.where(
      (item) =>
          item.status == _TopUpStatus.pending &&
          _isCurrentUser(item.approverUserId),
    );
    final pendingDisbursements = _topUps.where(
      (item) =>
          item.status == _TopUpStatus.approved &&
          _isCurrentUser(item.disburserUserId),
    );
    final pendingCorrections = _topUps.where(
      (item) =>
          item.status == _TopUpStatus.disputed &&
          _isCurrentUser(item.disburserUserId),
    );
    final pendingConfirmations = _topUps.where(
      (item) =>
          (item.status == _TopUpStatus.disbursed ||
              item.status == _TopUpStatus.corrected) &&
          _isCurrentUser(item.requesterUserId),
    );
    final pendingExpenseReversals = _expenseReversals.where(
      (item) =>
          item.status == _ExpenseReversalStatus.pending &&
          _isCurrentUser(item.approverUserId),
    );
    final hasAssignedTopUpAction =
        pendingTopUps.isNotEmpty ||
        pendingDisbursements.isNotEmpty ||
        pendingCorrections.isNotEmpty ||
        pendingConfirmations.isNotEmpty ||
        pendingExpenseReversals.isNotEmpty;
    if (!_canApproveFinance &&
        pendingRequisitions.isEmpty &&
        !hasAssignedTopUpAction) {
      return const _SectionCard(
        title: 'Action queue',
        subtitle: 'Finance actions appear here when they are assigned to you.',
        child: _InlineNotice(
          icon: Icons.lock_outline,
          color: AppColors.amber,
          text:
              'There is no finance approval, disbursement, or receipt confirmation assigned to you.',
        ),
      );
    }
    final pendingRatifications = _canApproveFinance
        ? _expenses.where(
            (item) =>
                item.approvalStatus ==
                _ExpenseApprovalStatus.pendingRatification,
          )
        : const <_ExpenseRecord>[];
    final pendingVarianceReviews = _canApproveFinance
        ? _expenses.where(
            (item) => item.varianceStatus == _VarianceStatus.pendingReview,
          )
        : const <_ExpenseRecord>[];
    final requisitionHistory =
        _requisitions
            .where(
              (item) =>
                  item.approvedAmount != null ||
                  item.status == _RequisitionStatus.rejected,
            )
            .toList()
          ..sort((a, b) => b.decisionDate.compareTo(a.decisionDate));
    final topUpHistory =
        _topUps
            .where(
              (item) =>
                  item.approvedAmount != null ||
                  item.status == _TopUpStatus.declined,
            )
            .toList()
          ..sort((a, b) => b.decisionDate.compareTo(a.decisionDate));
    final reversalHistory =
        _expenseReversals
            .where((item) => item.status != _ExpenseReversalStatus.pending)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

    return Column(
      children: [
        _SectionCard(
          title: 'Action queue',
          subtitle:
              'Only work assigned to you appears here: approvals, disbursements, receipt confirmations, and finance reviews.',
          child: Column(
            children: [
              for (final item in pendingRequisitions)
                _ActionTile(
                  icon: Icons.assignment_outlined,
                  iconColor: AppColors.amber,
                  title: '${item.title} · ${_money(item.requestedAmount)}',
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
              for (final item in pendingDisbursements)
                _ActionTile(
                  icon: Icons.payments_outlined,
                  iconColor: AppColors.purple,
                  title: 'Disburse ${item.requestId}',
                  subtitle:
                      '${_money(item.approvedAmount ?? item.requestedAmount)} approved · receiver ${item.receiver ?? item.requester}',
                  trailing: FilledButton(
                    onPressed: () => _openDisburseTopUpDialog(item),
                    style: _primaryButtonStyle(),
                    child: const Text('Disburse'),
                  ),
                ),
              for (final item in pendingCorrections)
                _ActionTile(
                  icon: Icons.build_circle_outlined,
                  iconColor: AppColors.red,
                  title: 'Resolve ${item.requestId}',
                  subtitle:
                      'The recipient reported a problem with this disbursement.',
                  trailing: FilledButton(
                    onPressed: () =>
                        _openDisburseTopUpDialog(item, correction: true),
                    style: _primaryButtonStyle(),
                    child: const Text('Record correction'),
                  ),
                ),
              for (final item in pendingConfirmations)
                _ActionTile(
                  icon: Icons.how_to_reg_outlined,
                  iconColor: AppColors.amber,
                  title: 'Confirm funds for ${item.requestId}',
                  subtitle:
                      '${_money((item.cashAmount ?? 0) + (item.momoAmount ?? 0))} recorded by ${item.disburser ?? 'the disburser'}',
                  trailing: FilledButton(
                    onPressed: () => _openConfirmTopUpDialog(item),
                    style: _primaryButtonStyle(),
                    child: const Text('Confirm received'),
                  ),
                ),
              for (final reversal in pendingExpenseReversals)
                _ActionTile(
                  icon: Icons.cancel_presentation_outlined,
                  iconColor: AppColors.red,
                  title: 'Reverse expense · ${_money(reversal.amount)}',
                  subtitle:
                      '${reversal.reference} · ${reversal.reasonLabel} · requested by ${reversal.requester}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            _decideExpenseReversal(reversal, 'decline'),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: ValueKey(
                          'approve-expense-reversal-${reversal.serverId}',
                        ),
                        onPressed: () => _reviewExpenseReversal(reversal),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.red,
                        ),
                        child: const Text('Review reversal'),
                      ),
                    ],
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
                  pendingDisbursements.isEmpty &&
                  pendingCorrections.isEmpty &&
                  pendingConfirmations.isEmpty &&
                  pendingExpenseReversals.isEmpty &&
                  pendingRatifications.isEmpty &&
                  pendingVarianceReviews.isEmpty)
                const _EmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No finance actions waiting',
                  subtitle:
                      'Approvals, disbursements, confirmations, and reviews are clear.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Approval history',
          subtitle:
              'Completed finance decisions remain here for review and audit.',
          child:
              requisitionHistory.isEmpty &&
                  topUpHistory.isEmpty &&
                  reversalHistory.isEmpty
              ? const _EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No approval history yet',
                  subtitle:
                      'Requisition, top-up, and expense-reversal decisions will appear here.',
                )
              : Column(
                  children: [
                    for (final item in requisitionHistory)
                      _ActionTile(
                        icon: Icons.assignment_turned_in_outlined,
                        iconColor: item.status.color,
                        title: '${item.id} · ${item.title}',
                        subtitle:
                            '${item.approvalDecisionLabel} by ${item.approver ?? 'Not recorded'} · ${_dateTime(item.decisionDate)} · ${_money(item.approvedAmount ?? item.requestedAmount)}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusPill(
                              label: item.status.label,
                              color: item.status.color,
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _muted,
                            ),
                          ],
                        ),
                        onTap: () => _openRequisitionWorkspace(item),
                      ),
                    for (final item in topUpHistory)
                      _ActionTile(
                        icon: Icons.add_card_outlined,
                        iconColor: item.status.color,
                        title: '${item.requestId} · Petty-cash top-up',
                        subtitle:
                            '${item.approvalDecisionLabel} by ${item.approver ?? 'Not recorded'} · ${_dateTime(item.decisionDate)} · ${_money(item.approvedAmount ?? item.requestedAmount)}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusPill(
                              label: item.status.label,
                              color: item.status.color,
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _muted,
                            ),
                          ],
                        ),
                        onTap: () => _openTopUpDetailPage(item),
                      ),
                    for (final reversal in reversalHistory)
                      _ActionTile(
                        icon: Icons.cancel_presentation_outlined,
                        iconColor: reversal.status.color,
                        title: '${reversal.reference} · Expense reversal',
                        subtitle:
                            '${reversal.status.label} · ${reversal.reasonLabel} · ${_money(reversal.amount)} · approver ${reversal.approver}',
                        trailing: _StatusPill(
                          label: reversal.status.label,
                          color: reversal.status.color,
                        ),
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
    final requisitionReference = _requisitionReference(item.requisitionId);
    final sourceLabel = switch (item.source) {
      _ExpenseSource.direct => 'School funds',
      _ExpenseSource.pettyCash =>
        item.channel == _PaymentChannel.floatMomo
            ? 'Petty cash · MoMo pocket'
            : 'Petty cash · Cash pocket',
    };
    return _ActionTile(
      icon: item.source == _ExpenseSource.pettyCash
          ? Icons.account_balance_wallet_outlined
          : Icons.account_balance_outlined,
      iconColor: item.source == _ExpenseSource.pettyCash
          ? _green
          : AppColors.blue,
      title: item.description,
      subtitle:
          '$sourceLabel · ${item.category} · ${item.payee}${requisitionReference == null ? '' : ' · $requisitionReference'} · ${_date(item.transactionDate)}',
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

  String? _requisitionReference(String? value) {
    if (value == null) return null;
    for (final requisition in _requisitions) {
      if (requisition.id == value ||
          requisition.serverId?.toString() == value) {
        return requisition.id;
      }
    }
    return value;
  }

  void _openTopUpDetailPage(_TopUpRequest item) {
    setState(() {
      _selectedTopUp = item;
      _financeLedgerPage = _FinanceLedgerPage.topUpDetail;
      _selectedTopUpEvents = [];
    });
    unawaited(_loadTopUpEvents(item));
  }

  Future<void> _loadTopUpEvents(_TopUpRequest item) async {
    if (item.serverId == null) return;
    try {
      final response = await _financeApi.get(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/events',
      );
      final events = (response is List ? response : _pageContent(response)).map(
        (value) {
          final map = _asMap(value);
          return _TopUpEvent(
            type: _asText(map['eventType']),
            actor: _asText(map['actor']),
            note: _nullableText(map['note']),
            cash: _nullableDouble(map['cashAmount']),
            momo: _nullableDouble(map['momoAmount']),
            wallet: _nullableText(map['momoWalletNumber']),
            reference: _nullableText(map['reference']),
            at: _asDate(map['createdAt']),
          );
        },
      ).toList();
      if (mounted && _selectedTopUp?.serverId == item.serverId) {
        setState(() => _selectedTopUpEvents = events);
      }
    } catch (_) {}
  }

  Widget _buildTopUpDetailPage(_TopUpRequest item) {
    final needsAction =
        item.status == _TopUpStatus.pending ||
        item.status == _TopUpStatus.approved ||
        item.status == _TopUpStatus.disbursed ||
        item.status == _TopUpStatus.disputed ||
        item.status == _TopUpStatus.corrected;

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
              _ReadOnlyRow('Requester', item.requester),
              _ReadOnlyRow('Approver', item.approver ?? 'Not selected'),
              _ReadOnlyRow('Disburser', item.disburser ?? 'Not selected'),
              _ReadOnlyRow(
                'Approved amount',
                item.approvedAmount == null
                    ? 'Not approved'
                    : _money(item.approvedAmount!),
              ),
              if (item.approvedAt != null)
                _ReadOnlyRow('Approved on', _date(item.approvedAt!)),
              if (item.actualReceived != null)
                _ReadOnlyRow('Actual received', _money(item.actualReceived!)),
              if (item.cashAmount != null)
                _ReadOnlyRow('Cash allocation', _money(item.cashAmount!)),
              if (item.momoAmount != null)
                _ReadOnlyRow('MoMo allocation', _money(item.momoAmount!)),
              if (item.momoWalletNumber != null)
                _ReadOnlyRow('MoMo wallet', item.momoWalletNumber!),
              if (item.confirmedAt != null)
                _ReadOnlyRow('Confirmed on', _date(item.confirmedAt!)),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Approval & disbursement history',
          subtitle:
              'Permanent record of approvals, handoffs, notes, and fund allocations.',
          child: _selectedTopUpEvents.isEmpty
              ? const Text(
                  'Timeline is loading or no events have been recorded.',
                  style: TextStyle(color: _muted),
                )
              : Column(
                  children: _selectedTopUpEvents
                      .map(
                        (event) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: _green,
                          ),
                          title: Text(
                            event.type.replaceAll('_', ' '),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            [
                              event.actor,
                              if (event.type.toUpperCase() == 'REQUESTED')
                                'Requested ${_money(item.requestedAmount)}',
                              if (event.type.toUpperCase() == 'APPROVED' &&
                                  item.approvedAmount != null)
                                'Approved ${_money(item.approvedAmount!)}',
                              if (event.note != null) event.note!,
                              if (event.cash != null)
                                'Cash ${_money(event.cash!)}',
                              if (event.momo != null)
                                'MoMo ${_money(event.momo!)}',
                              if (event.wallet != null) event.wallet!,
                              if (event.reference != null) event.reference!,
                            ].join(' · '),
                          ),
                          trailing: Text(
                            _dateTime(event.at),
                            style: const TextStyle(color: _muted),
                          ),
                        ),
                      )
                      .toList(),
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
    final isRequester = widget.currentUserId == item.requesterUserId;
    final isApprover = widget.currentUserId == item.approverUserId;
    final isDisburser = widget.currentUserId == item.disburserUserId;
    final canManageDisburser = _canApproveFinance;
    switch (item.status) {
      case _TopUpStatus.pending:
        return [
          if (isRequester)
            OutlinedButton(
              onPressed: () => _topUpNoteAction(
                item,
                'cancel',
                'Cancel request',
                'Why is this request being cancelled?',
              ),
              child: const Text('Cancel request'),
            ),
          if (isApprover) ...[
            OutlinedButton(
              onPressed: () => _declineTopUp(item),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => _approveTopUp(item),
              style: _primaryButtonStyle(),
              child: const Text('Approve'),
            ),
          ],
          if (!isRequester && !isApprover)
            const _InlineNotice(
              icon: Icons.lock_outline,
              color: AppColors.amber,
              text:
                  'This request is awaiting action from its assigned approver.',
            ),
        ];
      case _TopUpStatus.approved:
        return [
          if (isApprover)
            OutlinedButton(
              onPressed: () => _topUpNoteAction(
                item,
                'revoke-approval',
                'Revoke approval',
                'Why is this approval being revoked?',
              ),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Revoke approval'),
            ),
          if (canManageDisburser)
            OutlinedButton(
              onPressed: () => _reassignTopUpDisburser(item),
              child: const Text('Reassign disburser'),
            ),
          if (isDisburser)
            FilledButton(
              onPressed: () => _openDisburseTopUpDialog(item),
              style: _primaryButtonStyle(),
              child: const Text('Disburse'),
            ),
        ];
      case _TopUpStatus.disbursed:
        return [
          if (isRequester)
            OutlinedButton(
              onPressed: () => _topUpNoteAction(
                item,
                'report-problem',
                'Report a problem',
                'Describe what was wrong with the cash, MoMo amount, or wallet.',
              ),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Report a problem'),
            ),
          if (isRequester)
            FilledButton(
              onPressed: () => _openConfirmTopUpDialog(item),
              style: _primaryButtonStyle(),
              child: const Text('Confirm received'),
            ),
          if (!isRequester)
            const _InlineNotice(
              icon: Icons.hourglass_top,
              color: AppColors.amber,
              text:
                  'Waiting for the named receiver to confirm or report a problem.',
            ),
        ];
      case _TopUpStatus.disputed:
        return [
          if (isRequester)
            FilledButton(
              onPressed: () => _openConfirmTopUpDialog(item),
              style: _primaryButtonStyle(),
              child: const Text('Confirm receipt now'),
            ),
          if (canManageDisburser)
            OutlinedButton(
              onPressed: () => _reassignTopUpDisburser(item),
              child: const Text('Reassign disburser'),
            ),
          if (isDisburser || canManageDisburser)
            FilledButton(
              onPressed: () => _openDisburseTopUpDialog(item, correction: true),
              style: _primaryButtonStyle(),
              child: const Text('Record correction'),
            ),
        ];
      case _TopUpStatus.corrected:
        return [
          if (isRequester)
            OutlinedButton(
              onPressed: () => _topUpNoteAction(
                item,
                'report-problem',
                'Report another problem',
                'Describe what is still incorrect.',
              ),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('Report a problem'),
            ),
          if (isRequester)
            FilledButton(
              onPressed: () => _openConfirmTopUpDialog(item),
              style: _primaryButtonStyle(),
              child: const Text('Confirm corrected funds'),
            ),
          if (!isRequester)
            const _InlineNotice(
              icon: Icons.hourglass_top,
              color: AppColors.amber,
              text: 'Correction recorded. Waiting for the named receiver.',
            ),
        ];
      case _TopUpStatus.queried:
      case _TopUpStatus.declined:
      case _TopUpStatus.cancelled:
      case _TopUpStatus.approvalRevoked:
      case _TopUpStatus.confirmed:
      case _TopUpStatus.confirmedWithDiscrepancy:
        return [
          _StatusPill(label: item.status.label, color: item.status.color),
        ];
    }
  }

  void _openRecordExpenseDialog({_RequisitionRecord? requisition}) {
    if (requisition == null) {
      _snack('Create and approve a requisition before recording an expense.');
      return;
    }
    final approvedAmount =
        requisition.approvedAmount ??
        (requisition.isEmergency ? requisition.requestedAmount : null);
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
    final availableChannels = requisition.fundingSource.allowedChannels;
    _PaymentChannel channel = availableChannels.first;
    picker.PlatformFile? receiptAttachment;
    final formKey = GlobalKey<FormState>();
    String? attachmentError;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final amountValue = _parseAmount(amount.text);
            final helper = _varianceMessage(requisition, amountValue);
            final selectedPocketBalance = switch (channel) {
              _PaymentChannel.floatCash => _cashBalance,
              _PaymentChannel.floatMomo => _momoBalance,
              _ => 0.0,
            };

            return _ExpenseDialogShell(
              title: 'Record actual spend',
              subtitle: 'Enter the final paid amount and receipt details.',
              primaryLabel: 'Record spend',
              onPrimary: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final actual = _parseAmount(amount.text);
                final difference = actual - approvedAmount;
                final hasVariance = difference.abs() > 0.005;
                final variancePercent = approvedAmount <= 0
                    ? 0.0
                    : difference.abs() * 100 / approvedAmount;
                final exceedsTolerance =
                    hasVariance &&
                    variancePercent > _settings.varianceTolerancePercent;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmationContext) => _ExpenseDialogShell(
                    title: 'Confirm actual spend',
                    subtitle:
                        'Affirm the final amount before the expense is recorded.',
                    primaryLabel: hasVariance
                        ? 'Affirm and record'
                        : 'Confirm and record',
                    secondaryLabel: 'Back',
                    width: 560,
                    onPrimary: () => Navigator.pop(confirmationContext, true),
                    child: Column(
                      children: [
                        _DialogSummary(
                          title: hasVariance
                              ? 'Actual is ${difference > 0 ? 'higher' : 'lower'}'
                              : 'Actual matches approval',
                          value: hasVariance
                              ? _money(difference.abs())
                              : 'No variance',
                          subtitle: hasVariance
                              ? '${variancePercent.toStringAsFixed(1)}% difference from the approved amount'
                              : 'The approved and actual amounts are the same.',
                          color: hasVariance
                              ? AppColors.amber
                              : AppColors.green,
                        ),
                        const SizedBox(height: 14),
                        _FormSection(
                          title: 'Spend summary',
                          child: Column(
                            children: [
                              _InfoRow('Description', requisition.title),
                              _InfoRow(
                                'Approved amount',
                                _money(approvedAmount),
                              ),
                              _InfoRow('Actual amount', _money(actual)),
                              _InfoRow('Payment method', channel.label),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InlineNotice(
                          icon: hasVariance
                              ? Icons.rule_outlined
                              : Icons.verified_outlined,
                          color: exceedsTolerance
                              ? AppColors.red
                              : hasVariance
                              ? AppColors.amber
                              : AppColors.blue,
                          text: hasVariance
                              ? 'I affirm that the actual amount is ${_money(difference.abs())} ${difference > 0 ? 'higher' : 'lower'} than approved.${exceedsTolerance ? ' This expense will be flagged for variance review.' : ' This difference is within the configured ${_settings.varianceTolerancePercent}% tolerance.'}'
                              : 'I confirm that the actual spend matches the approved amount.',
                        ),
                      ],
                    ),
                  ),
                );
                if (confirmed != true || !context.mounted) return;
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
              child: Form(
                key: formKey,
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
                          TextFormField(
                            controller: description,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              suffixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TwoFields(
                            left: TextFormField(
                              controller: amount,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setDialogState(() {}),
                              validator: (text) {
                                final actual = _strictAmount(text ?? '');
                                if (actual == null || actual <= 0) {
                                  return 'Enter an amount greater than zero.';
                                }
                                if (requisition.fundingSource ==
                                        _FundingSource.pettyCash &&
                                    actual > _settings.floatCeiling) {
                                  return 'Maximum petty-cash spend is ${_money(_settings.floatCeiling)}.';
                                }
                                if (requisition.fundingSource ==
                                        _FundingSource.pettyCash &&
                                    actual > selectedPocketBalance) {
                                  return '${channel == _PaymentChannel.floatCash ? 'Cash' : 'MoMo'} has only ${_money(selectedPocketBalance)} available.';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Actual amount',
                                prefixText: 'GH¢ ',
                              ),
                            ),
                            right: TextFormField(
                              controller: payee,
                              decoration: const InputDecoration(
                                labelText: 'Vendor / payee',
                                suffixIcon: Icon(Icons.lock_outline),
                              ),
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<_PaymentChannel>(
                            value: channel,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Payment method',
                            ),
                            items: availableChannels
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(
                                      switch (item) {
                                        _PaymentChannel.floatCash =>
                                          '${item.label} · ${_money(_cashBalance)} available',
                                        _PaymentChannel.floatMomo =>
                                          '${item.label} · ${_money(_momoBalance)} available',
                                        _ => item.label,
                                      },
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() => channel = value);
                            },
                          ),
                          if (requisition.fundingSource ==
                              _FundingSource.pettyCash) ...[
                            const SizedBox(height: 12),
                            _InlineNotice(
                              icon: Icons.account_balance_wallet_outlined,
                              color: amountValue > selectedPocketBalance
                                  ? AppColors.red
                                  : AppColors.green,
                              text:
                                  'The selected ${channel == _PaymentChannel.floatCash ? 'Cash' : 'MoMo'} pocket has ${_money(selectedPocketBalance)}. The actual spend cannot make it negative.',
                            ),
                          ],
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
                                            setDialogState(
                                              () => attachmentError =
                                                  'Receipt files must be 10 MB or smaller.',
                                            );
                                            return;
                                          }
                                          if (file.bytes == null) {
                                            setDialogState(
                                              () => attachmentError =
                                                  'The selected receipt could not be read.',
                                            );
                                            return;
                                          }
                                          setDialogState(() {
                                            receiptAttachment = file;
                                            attachmentError = null;
                                          });
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
                          if (attachmentError != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                attachmentError!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
                      color: _varianceColor(requisition, amountValue),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateRequisitionDialog({_RequisitionRecord? existing}) {
    const standardCategories = [
      'Supplies',
      'Teaching Materials',
      'Repairs & Maintenance',
      'Utilities',
      'Transport',
      'Food & Refreshments',
      'Medical / Emergency',
      'Administration',
      'Other',
    ];
    final categories = <String>[
      ...standardCategories,
      if (existing != null &&
          existing.category.isNotEmpty &&
          !standardCategories.contains(existing.category))
        existing.category,
    ];
    final title = TextEditingController(text: existing?.title ?? '');
    final payee = TextEditingController(
      text: existing == null || existing.payee == 'Not provided'
          ? ''
          : existing.payee,
    );
    final amount = TextEditingController(
      text: existing == null ? '' : _amountInput(existing.requestedAmount),
    );
    _FundingSource? fundingSource = existing?.fundingSource;
    String? category = existing?.category;
    final reason = TextEditingController(text: existing?.notes ?? '');
    final verbalApprover = TextEditingController(
      text: existing?.verbalApprover ?? '',
    );
    bool emergencyApproval = existing?.isEmergency ?? false;
    int? approverId = existing?.approverUserId;
    final formKey = GlobalKey<FormState>();
    String? formError;
    var validationAttempted = false;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final value = _parseAmount(amount.text);
          return _ExpenseDialogShell(
            title: existing == null ? 'New requisition' : 'Edit requisition',
            subtitle: existing == null
                ? 'Request approval before spending.'
                : '${existing.id} is now a draft. Save and resubmit it for approval.',
            primaryLabel: existing == null
                ? 'Submit request'
                : 'Save and resubmit',
            onPrimary: () async {
              setDialogState(() {
                validationAttempted = true;
                formError = null;
              });
              if (!(formKey.currentState?.validate() ?? false)) return;
              final value = _parseAmount(amount.text);
              final termId = _academicTermId;
              if (termId == null) {
                setDialogState(
                  () => formError =
                      'The current academic term is not available. Refresh the page and try again.',
                );
                return;
              }
              try {
                final payload = <String, dynamic>{
                  'academicTermId': termId,
                  'fundingSource': fundingSource!.apiValue,
                  'description': title.text.trim(),
                  'category': category,
                  'vendor': payee.text.trim().isEmpty
                      ? null
                      : payee.text.trim(),
                  'requestedAmount': value,
                  if (existing == null)
                    'expenseDate': DateTime.now()
                        .toIso8601String()
                        .split('T')
                        .first,
                  'reason': reason.text.trim(),
                  'notes': reason.text.trim(),
                  'emergency': emergencyApproval,
                  'approverUserId': approverId,
                  'verbalApprover':
                      emergencyApproval && verbalApprover.text.trim().isNotEmpty
                      ? verbalApprover.text.trim()
                      : null,
                };
                final requisitionId =
                    existing?.serverId ??
                    _nullableServerId(
                      _asMap(
                        await _financeApi.post(
                          '/api/schools/${widget.customSchoolId}/finance/requisitions',
                          body: payload,
                        ),
                      )['id'],
                    );
                if (requisitionId == null) {
                  throw const FinanceApiException(
                    'The requisition was created without a server ID.',
                  );
                }
                if (existing != null) {
                  await _financeApi.put(
                    '/api/schools/${widget.customSchoolId}/finance/requisitions/$requisitionId',
                    body: payload,
                  );
                }
                final submitted = await _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/requisitions/$requisitionId/submit',
                );
                final submittedStatus = _requisitionStatus(
                  _asMap(submitted)['status'],
                );
                await _loadFinanceWorkspace(showLoading: false);
                if (!mounted) return;
                _snack(
                  submittedStatus == _RequisitionStatus.approved
                      ? 'Requisition automatically approved under the school petty-cash policy.'
                      : emergencyApproval
                      ? 'Emergency requisition submitted for approval.'
                      : existing == null
                      ? 'Requisition submitted for approval.'
                      : 'Requisition updated and resubmitted for approval.',
                );
                if (context.mounted) Navigator.pop(context);
              } on FinanceApiException catch (error) {
                if (context.mounted) {
                  setDialogState(() => formError = error.message);
                }
              } catch (_) {
                if (context.mounted) {
                  setDialogState(
                    () => formError = existing == null
                        ? 'The requisition could not be submitted.'
                        : 'The requisition changes could not be resubmitted.',
                  );
                }
              }
            },
            child: Form(
              key: formKey,
              autovalidateMode: validationAttempted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (formError != null) ...[
                    _InlineNotice(
                      icon: Icons.error_outline,
                      color: AppColors.red,
                      text: formError!,
                    ),
                    const SizedBox(height: 14),
                  ],
                  _FormSection(
                    title: 'Funding source',
                    child: FormField<_FundingSource>(
                      initialValue: fundingSource,
                      validator: (_) {
                        if (fundingSource == null) {
                          return 'Select how this purchase will be funded.';
                        }
                        if (fundingSource == _FundingSource.pettyCash &&
                            _float.status != _FloatStatus.active) {
                          return 'The petty-cash cycle must be active before requesting from the float.';
                        }
                        return null;
                      },
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How will this purchase be funded?',
                            style: TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<_FundingSource>(
                            value: _FundingSource.schoolFunds,
                            groupValue: fundingSource,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('School funds'),
                            subtitle: const Text(
                              'Cash, bank transfer, cheque, or the main school MoMo account.',
                            ),
                            onChanged: (value) {
                              field.didChange(value);
                              setDialogState(() => fundingSource = value);
                            },
                          ),
                          RadioListTile<_FundingSource>(
                            value: _FundingSource.pettyCash,
                            groupValue: fundingSource,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Petty cash'),
                            subtitle: const Text(
                              'The controlled Cash or MoMo float pocket.',
                            ),
                            onChanged: (value) {
                              field.didChange(value);
                              setDialogState(() => fundingSource = value);
                            },
                          ),
                          if (existing != null) ...[
                            const SizedBox(height: 8),
                            const _InlineNotice(
                              icon: Icons.info_outline,
                              color: AppColors.blue,
                              text:
                                  'Changing the funding source applies the new route\'s rules and requires fresh approval when you resubmit.',
                            ),
                          ],
                          if (field.hasError) ...[
                            const SizedBox(height: 6),
                            Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (fundingSource == _FundingSource.pettyCash) ...[
                    const SizedBox(height: 14),
                    _InlineNotice(
                      icon: Icons.account_balance_wallet_outlined,
                      color: value > _settings.floatCeiling
                          ? AppColors.red
                          : AppColors.green,
                      text:
                          'Petty-cash requests cannot exceed the ${_money(_settings.floatCeiling)} single expense limit. '
                          'The selected Cash or MoMo pocket balance is checked when actual spending is recorded. '
                          'This request will expire ${_settings.requisitionExpiryDays} days after submission.${_settings.autoApprovePettyCash ? ' Standard requests up to ${_money(_settings.autoApprovalLimit)} may be approved automatically.' : ''}',
                    ),
                  ],
                  const SizedBox(height: 14),
                  _FormSection(
                    title: 'Request details',
                    child: Column(
                      children: [
                        TextFormField(
                          controller: title,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter a description.'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'e.g. Repair leaking KG washroom tap',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _TwoFields(
                          left: TextFormField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            validator: (text) {
                              final amountValue = _strictAmount(text ?? '');
                              if (amountValue == null || amountValue <= 0) {
                                return 'Enter an amount greater than zero.';
                              }
                              if (fundingSource == _FundingSource.pettyCash &&
                                  amountValue > _settings.floatCeiling) {
                                return 'Maximum petty-cash request is ${_money(_settings.floatCeiling)}. Select School funds for a larger request.';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Estimated amount',
                              prefixText: 'GH¢ ',
                            ),
                          ),
                          right: TextFormField(
                            controller: payee,
                            decoration: const InputDecoration(
                              labelText: 'Vendor',
                              hintText: 'Optional',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          hint: const Text('Select category'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Select a category.'
                              : null,
                          items: categories
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => category = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FormSection(
                    title: 'Reason',
                    child: TextFormField(
                      controller: reason,
                      minLines: 3,
                      maxLines: 5,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Explain why this request is needed.'
                          : null,
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
                              ? 'Emergency purchase'
                              : 'Standard approval',
                          onChanged: (value) =>
                              setDialogState(() => emergencyApproval = value),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emergencyApproval
                              ? 'Purchase already made or cannot wait for prior approval.'
                              : 'Submit for approval before purchasing.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: approverId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: emergencyApproval
                                ? 'Select ratifying approver'
                                : 'Select approver',
                          ),
                          hint: const Text(
                            'Choose who will decide this request',
                          ),
                          validator: (value) => value == null
                              ? emergencyApproval
                                    ? 'Select the ratifying approver.'
                                    : 'Select an approver.'
                              : null,
                          items: _topUpApprovers
                              .where(
                                (actor) => actor.id != widget.currentUserId,
                              )
                              .map(
                                (actor) => DropdownMenuItem<int>(
                                  value: actor.id,
                                  child: Text('${actor.name} · ${actor.role}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setDialogState(() => approverId = value),
                        ),
                        if (emergencyApproval) ...[
                          const SizedBox(height: 12),
                          _InlineNotice(
                            icon: Icons.emergency_outlined,
                            color: AppColors.amber,
                            text:
                                'Use only when urgent circumstances prevented prior approval. The expense must still be reviewed and ratified afterward.',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: verbalApprover,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter who gave verbal approval.'
                                : null,
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
                        : fundingSource == _FundingSource.pettyCash &&
                              !emergencyApproval &&
                              _settings.autoApprovePettyCash &&
                              value > 0 &&
                              value <= _settings.autoApprovalLimit
                        ? 'Eligible for automatic approval under the school policy.'
                        : 'This request will wait for approval before spending.',
                    color: emergencyApproval ? AppColors.amber : _green,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editRequisition(_RequisitionRecord item) async {
    if (!_isCurrentUser(item.requesterUserId)) {
      _snack('Only the requester can edit this requisition.');
      return;
    }
    if (item.fundingSource != _FundingSource.pettyCash &&
        item.status != _RequisitionStatus.draft) {
      _snack('Only petty-cash requisitions can be edited here.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This requisition cannot be edited because its server ID is missing.',
      );
      return;
    }
    try {
      var draft = item;
      if (item.status != _RequisitionStatus.draft) {
        final response = await _financeApi.post(
          '/api/schools/${widget.customSchoolId}/finance/requisitions/${item.serverId}/edit',
        );
        final records = _requisitionRecords([response]);
        if (records.isEmpty) {
          throw const FinanceApiException(
            'The requisition was returned without its draft details.',
          );
        }
        draft = records.first;
      }
      await _loadFinanceWorkspace(showLoading: false);
      if (!mounted) return;
      _snack('${item.id} is now a draft.');
      _openCreateRequisitionDialog(existing: draft);
    } on FinanceApiException catch (error) {
      if (mounted) _snack(error.message);
    } catch (_) {
      if (mounted) _snack('The requisition could not be opened for editing.');
    }
  }

  void _openRequisitionWorkspace(_RequisitionRecord requisition) {
    _ExpenseRecord? linkedExpense;
    for (final candidate in _expenses) {
      if (candidate.requisitionId == requisition.id ||
          candidate.requisitionId == requisition.serverId?.toString()) {
        linkedExpense = candidate;
        break;
      }
    }
    final history = requisition.serverId == null
        ? Future<dynamic>.value(const <dynamic>[])
        : _financeApi.get(
            '/api/schools/${widget.customSchoolId}/finance/notes',
            query: {
              'parentType': 'REQUISITION',
              'parentId': '${requisition.serverId}',
            },
          );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ExpenseDialogShell(
        title: 'Requisition ${requisition.id}',
        subtitle: 'Manage approval, actual spend, and any follow-up here.',
        primaryLabel: 'Close',
        width: 820,
        showSecondaryAction: false,
        persistentActions: [
          if (linkedExpense == null &&
              _isCurrentUser(requisition.requesterUserId) &&
              (requisition.fundingSource == _FundingSource.pettyCash ||
                  requisition.status == _RequisitionStatus.draft) &&
              requisition.status != _RequisitionStatus.cancelled &&
              requisition.status != _RequisitionStatus.fulfilled)
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Future<void>.delayed(const Duration(milliseconds: 250));
                if (mounted) await _editRequisition(requisition);
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                requisition.status == _RequisitionStatus.draft
                    ? 'Continue editing'
                    : 'Edit requisition',
              ),
            ),
          if (_isCurrentUser(requisition.requesterUserId) &&
              requisition.status != _RequisitionStatus.fulfilled &&
              requisition.status != _RequisitionStatus.cancelled &&
              requisition.status != _RequisitionStatus.rejected)
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await Future<void>.delayed(const Duration(milliseconds: 250));
                if (mounted) await _cancelRequisition(requisition);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel requisition'),
            ),
        ],
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
                  _InfoRow('Funding source', requisition.fundingSource.label),
                  _InfoRow(
                    'Approved amount',
                    requisition.approvedAmount == null
                        ? 'Not approved'
                        : _money(requisition.approvedAmount!),
                  ),
                  _InfoRow('Requested by', requisition.requestedBy),
                  _InfoRow(
                    'Approver',
                    requisition.approver ?? 'Legacy request · not assigned',
                  ),
                  _InfoRow('Requested on', _date(requisition.requestedAt)),
                  _InfoRow(
                    'Validity',
                    _requisitionExpiryLabel(requisition.expiresAt),
                  ),
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
                requisition.status == _RequisitionStatus.draft)
              const _InlineNotice(
                icon: Icons.edit_note_outlined,
                color: AppColors.blue,
                text:
                    'This requisition is a draft. Edit and resubmit it before approval can continue.',
              ),
            if (linkedExpense == null &&
                requisition.status == _RequisitionStatus.pending &&
                !requisition.isEmergency)
              _InlineNotice(
                icon: Icons.pending_actions_outlined,
                color: AppColors.amber,
                text:
                    'Approve this requisition before any money is recorded as spent.',
              ),
            if (linkedExpense == null &&
                requisition.isEmergency &&
                requisition.status == _RequisitionStatus.pending)
              const _InlineNotice(
                icon: Icons.emergency_outlined,
                color: AppColors.amber,
                text:
                    'Verbal authorisation is recorded. Record the payment now; a head teacher must ratify it afterward.',
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
            _FormSection(
              title: 'Approval history',
              child: FutureBuilder<dynamic>(
                future: history,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const _InlineNotice(
                      icon: Icons.sync_problem_outlined,
                      color: AppColors.amber,
                      text: 'Approval history could not be loaded.',
                    );
                  }
                  final entries = _financeHistoryEntries(snapshot.data);
                  if (entries.isEmpty) {
                    return const Text(
                      'No approval events have been recorded yet.',
                      style: TextStyle(color: AppColors.muted),
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in entries)
                        _ActionTile(
                          icon: entry.icon,
                          iconColor: entry.color,
                          title: entry.label,
                          subtitle:
                              '${entry.author} · ${_dateTime(entry.createdAt)}${entry.amount == null ? '' : ' · ${_money(entry.amount!)}'}${entry.note.isEmpty ? '' : '\n${entry.note}'}',
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_canApproveFinance &&
                    _isAssignedRequisitionApprover(requisition) &&
                    requisition.status == _RequisitionStatus.pending &&
                    !requisition.isEmergency) ...[
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
                    (requisition.status == _RequisitionStatus.approved ||
                        (requisition.isEmergency &&
                            requisition.status == _RequisitionStatus.pending)))
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
                if (_canApproveFinance &&
                    linkedExpense?.approvalStatus ==
                        _ExpenseApprovalStatus.pendingRatification)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _ratifyExpense(linkedExpense!);
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Ratify emergency'),
                  ),
                if (_canApproveFinance &&
                    linkedExpense?.varianceStatus ==
                        _VarianceStatus.pendingReview)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _openVarianceReviewDialog(linkedExpense!);
                    },
                    icon: const Icon(Icons.rule_outlined),
                    label: const Text('Review variance'),
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
    if (requisition.status != _RequisitionStatus.approved &&
        !(requisition.isEmergency &&
            requisition.status == _RequisitionStatus.pending)) {
      _snack('Only approved requisitions can be fulfilled.');
      return false;
    }
    if (_hasUsableDate(requisition.expiresAt) &&
        DateTime.now().isAfter(requisition.expiresAt)) {
      _snack('This requisition has expired and must be reactivated.');
      return false;
    }

    final approved =
        requisition.approvedAmount ??
        (requisition.isEmergency ? requisition.requestedAmount : null);
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
      _PaymentChannel.floatCash => 'CASH',
      _PaymentChannel.floatMomo => 'MOMO',
      _ => null,
    };
    final paymentChannel = switch (channel) {
      _PaymentChannel.floatCash => 'CASH',
      _PaymentChannel.floatMomo => 'MOMO',
      _PaymentChannel.schoolCash => 'SCHOOL_CASH',
      _PaymentChannel.directMomo => 'DIRECT_MOMO',
      _PaymentChannel.cheque => 'CHEQUE',
      _PaymentChannel.bankTransfer => 'BANK_TRANSFER',
    };
    try {
      final created = await _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${requisition.serverId}/actual-spend',
        body: {
          'actualAmount': actualAmount,
          if (pocket != null) 'pocket': pocket,
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
    if (!_canApproveFinance) {
      _snack('Your role cannot approve finance requests.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This requisition cannot be approved because its server ID is missing.',
      );
      return;
    }
    if (!_isAssignedRequisitionApprover(item)) {
      _snack('Only the selected approver can approve this request.');
      return;
    }
    var approvalNote = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ExpenseDialogShell(
        title: 'Confirm requisition approval',
        subtitle: 'Review the request before recording your decision.',
        primaryLabel: 'Confirm approval',
        secondaryLabel: 'Cancel',
        width: 560,
        onPrimary: () {
          if (!(formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(dialogContext, true);
        },
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _DialogSummary(
                title: 'Amount requested',
                value: _money(item.requestedAmount),
                subtitle: item.id,
                color: AppColors.green,
              ),
              const SizedBox(height: 14),
              _FormSection(
                title: 'Approval confirmation',
                child: Column(
                  children: [
                    _InfoRow('Description', item.title),
                    _InfoRow('Requested by', item.requestedBy),
                    _InfoRow('Funding source', item.fundingSource.label),
                    _InfoRow('Vendor / payee', item.payee),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                minLines: 2,
                maxLines: 4,
                onChanged: (value) => approvalNote = value,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add an approval note.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Approval note *',
                  hintText: 'State why this request is approved.',
                ),
              ),
              const SizedBox(height: 14),
              const _InlineNotice(
                icon: Icons.verified_user_outlined,
                color: AppColors.blue,
                text:
                    'Confirming will record you as the approver and add this decision to the audit history.',
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${item.serverId}/approve',
        body: {
          'approvedAmount': item.approvedAmount,
          'notes': approvalNote.trim(),
        },
      ),
      successMessage: '${item.id} approved.',
    );
  }

  Future<void> _rejectRequisition(_RequisitionRecord item) async {
    if (!_canApproveFinance) {
      _snack('Your role cannot reject finance requests.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This requisition cannot be rejected because its server ID is missing.',
      );
      return;
    }
    if (!_isAssignedRequisitionApprover(item)) {
      _snack('Only the selected approver can decline this request.');
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
    var note = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel requisition'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: TextFormField(
                minLines: 3,
                maxLines: 5,
                onChanged: (value) => note = value,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'A cancellation note is required.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Required note',
                  hintText: 'Why is this request being cancelled?',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Cancel requisition'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/requisitions/${item.serverId}/cancel',
        body: {'note': note.trim()},
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
          item.status == _TopUpStatus.disbursed ||
          item.status == _TopUpStatus.disputed ||
          item.status == _TopUpStatus.corrected,
    );
    if (hasPending) {
      _snack('There is already an open top-up cycle.');
      return;
    }
    if (_totalFloatBalance >= _settings.floatApprovedAmount) {
      _snack('Float is already full. Top-up request blocked.');
      return;
    }

    if (_topUpApprovers.isEmpty) {
      _snack('No eligible approver is available for this school.');
      return;
    }
    final maximum = _settings.floatApprovedAmount - _totalFloatBalance;
    var amountText = maximum.toStringAsFixed(2);
    var note = '';
    int? approverId;
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request petty-cash top-up'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: amountText,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => amountText = v,
                    validator: (text) {
                      final amount = _strictAmount(text ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter an amount greater than zero.';
                      }
                      return amount > maximum
                          ? 'Maximum available top-up is ${_money(maximum)}.'
                          : null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Amount requested',
                      prefixText: 'GH¢ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: approverId,
                    decoration: const InputDecoration(labelText: 'Approver'),
                    items: _topUpApprovers
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} · ${a.role}'),
                          ),
                        )
                        .toList(),
                    validator: (value) => value == null
                        ? 'Select the approver for this top-up.'
                        : null,
                    onChanged: (v) => setDialogState(() => approverId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    minLines: 2,
                    maxLines: 3,
                    onChanged: (v) => note = v,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a request note.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Request note',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'The selected approver will be notified. Money is added only after disbursement and requester confirmation.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _primaryButtonStyle(),
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, true);
              },
              child: const Text('Review request'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final amount = _parseAmount(amountText);
    final approver = _topUpApprovers.firstWhere((a) => a.id == approverId);
    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm top-up request'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReadOnlyRow('Requested amount', _money(amount)),
              _ReadOnlyRow('Approver', approver.name),
              _ReadOnlyRow('Requester', widget.recordedBy ?? 'Current user'),
              _ReadOnlyRow('Note', note.trim()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: _primaryButtonStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (finalConfirmation != true || !mounted) return;

    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups',
        body: {
          'academicTermId': _academicTermId,
          'destinationPocket': 'CASH',
          'requestedAmount': amount,
          'approverUserId': approverId,
          'notes': note.trim(),
        },
      ),
      successMessage: 'Top-up request created for ${_money(amount)}.',
    );
  }

  Future<void> _approveTopUp(_TopUpRequest item) async {
    if (!_canApproveFinance) {
      _snack('Your role cannot approve top-up requests.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This top-up cannot be approved because its server ID is missing.',
      );
      return;
    }
    if (_topUpDisbursers.isEmpty) {
      _snack('No eligible disburser is available.');
      return;
    }
    int? disburserId;
    var note = '';
    final formKey = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Approve top-up request'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ReadOnlyRow(
                    'Requested amount',
                    _money(item.requestedAmount),
                  ),
                  DropdownButtonFormField<int>(
                    value: disburserId,
                    decoration: const InputDecoration(labelText: 'Disburser'),
                    items: _topUpDisbursers
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text('${a.name} · ${a.role}'),
                          ),
                        )
                        .toList(),
                    validator: (value) => value == null
                        ? 'Select the person who will disburse the funds.'
                        : null,
                    onChanged: (v) => setDialogState(() => disburserId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    minLines: 2,
                    maxLines: 3,
                    onChanged: (v) => note = v,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add an approval note.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Approval note',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _primaryButtonStyle(),
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(context, true);
              },
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/approve',
        body: {'disburserUserId': disburserId, 'notes': note.trim()},
      ),
      successMessage: '${item.requestId} approved.',
    );
  }

  Future<void> _declineTopUp(_TopUpRequest item) async {
    if (item.serverId == null) {
      _snack(
        'This top-up cannot be declined because its server ID is missing.',
      );
      return;
    }

    var reason = '';
    String? errorMessage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Decline top-up request?'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.requestId} requests ${_money(item.requestedAmount)}.',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Declining closes this request without changing the petty-cash balance.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  minLines: 3,
                  maxLines: 4,
                  onChanged: (value) => reason = value,
                  decoration: InputDecoration(
                    labelText: 'Reason for declining',
                    hintText: 'Explain why this top-up cannot be approved',
                    errorText: errorMessage,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (reason.trim().isEmpty) {
                  setDialogState(
                    () => errorMessage = 'Enter a reason for declining.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              child: const Text('Decline request'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/decline',
        body: {'note': reason.trim()},
      ),
      successMessage: '${item.requestId} declined.',
    );
  }

  Future<void> _reassignTopUpDisburser(_TopUpRequest item) async {
    if (item.serverId == null || _topUpDisbursers.isEmpty) return;
    int? disburserId;
    var note = '';
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reassign disburser'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: disburserId,
                  decoration: const InputDecoration(labelText: 'New disburser'),
                  items: _topUpDisbursers
                      .map(
                        (actor) => DropdownMenuItem(
                          value: actor.id,
                          child: Text('${actor.name} · ${actor.role}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => disburserId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  minLines: 3,
                  maxLines: 4,
                  onChanged: (value) => note = value,
                  decoration: InputDecoration(
                    labelText: 'Reason for reassignment',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _primaryButtonStyle(),
              onPressed: () {
                if (disburserId == null || note.trim().isEmpty) {
                  setDialogState(
                    () => error = 'Select a disburser and enter a reason.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/reassign-disburser',
        body: {'disburserUserId': disburserId, 'note': note.trim()},
      ),
      successMessage: '${item.requestId} reassigned.',
    );
  }

  void _openDisburseTopUpDialog(_TopUpRequest item, {bool correction = false}) {
    final approvedAmount = item.approvedAmount;
    if (approvedAmount == null || item.serverId == null) {
      _snack('This top-up is not ready for disbursement.');
      return;
    }
    final requestDate = DateTime(
      item.requestedAt.year,
      item.requestedAt.month,
      item.requestedAt.day,
    );
    var selectedDate = DateTime.now();
    var reference = '';
    var notes = '';
    final cashController = TextEditingController(
      text: approvedAmount.toStringAsFixed(2),
    );
    final momoController = TextEditingController(text: '0');
    var wallet = _settings.momoWalletNumber;
    int? selectedReceiverId;
    final formKey = GlobalKey<FormState>();
    final dialog = showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => _ExpenseDialogShell(
          title: correction
              ? 'Record corrected disbursement'
              : 'Record disbursement',
          subtitle: correction
              ? 'Record the allocation after the problem was corrected.'
              : 'Issue the exact amount approved for this top-up.',
          primaryLabel: correction ? 'Save correction' : 'Confirm disbursement',
          width: 620,
          onPrimary: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final cash = _parseAmount(cashController.text);
            final momo = _parseAmount(momoController.text);
            Navigator.pop(dialogContext);
            await _runFinanceMutation(
              request: () => _financeApi.post(
                '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/${correction ? 'correct' : 'disburse'}',
                body: {
                  'cashAmount': cash,
                  'momoAmount': momo,
                  'receiverUserId': selectedReceiverId,
                  'momoWalletNumber': wallet.trim(),
                  'disbursementDate': selectedDate
                      .toIso8601String()
                      .split('T')
                      .first,
                  'reference': reference.trim(),
                  'notes': notes.trim(),
                },
              ),
              successMessage:
                  '${_money(approvedAmount)} disbursed. Awaiting recipient confirmation.',
            );
          },
          child: Form(
            key: formKey,
            child: Column(
              children: [
                _DialogSummary(
                  title: 'Amount to disburse',
                  value: _money(approvedAmount),
                  subtitle: item.requestId,
                  color: AppColors.blue,
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Disbursement record',
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedReceiverId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select receiver of funds',
                        ),
                        items: item.requesterUserId == null
                            ? const []
                            : [
                                DropdownMenuItem(
                                  value: item.requesterUserId,
                                  child: Text(
                                    '${item.receiver ?? item.requester} · Requester',
                                  ),
                                ),
                              ],
                        validator: (value) => value != item.requesterUserId
                            ? 'Confirm the requester as the receiver of funds.'
                            : null,
                        onChanged: (value) =>
                            setDialogState(() => selectedReceiverId = value),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: requestDate,
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Disbursement date',
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(_date(selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TwoFields(
                        left: TextFormField(
                          key: const ValueKey('disbursement-cash-amount'),
                          controller: cashController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          validator: (text) {
                            final value = _strictAmount(text ?? '');
                            return value == null || value < 0
                                ? 'Enter zero or a valid amount.'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Cash amount',
                            prefixText: 'GH¢ ',
                          ),
                        ),
                        right: TextFormField(
                          key: const ValueKey('disbursement-momo-amount'),
                          controller: momoController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          validator: (text) {
                            final momo = _strictAmount(text ?? '');
                            final cash = _strictAmount(cashController.text);
                            if (momo == null || momo < 0) {
                              return 'Enter zero or a valid amount.';
                            }
                            if (cash != null &&
                                (cash + momo - approvedAmount).abs() > .009) {
                              return 'Cash and MoMo must total ${_money(approvedAmount)}.';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'MoMo amount',
                            prefixText: 'GH¢ ',
                          ),
                        ),
                      ),
                      if (_parseAmount(momoController.text) > 0) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: wallet,
                          onChanged: (v) => wallet = v,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter the MoMo wallet number.'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'MoMo wallet number',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        onChanged: (value) => reference = value,
                        decoration: const InputDecoration(
                          labelText: 'Payment reference (optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        onChanged: (value) => notes = value,
                        minLines: 2,
                        maxLines: 3,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Add a disbursement note.'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Disbursement note',
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
    );
    unawaited(
      dialog.whenComplete(() {
        // The dialog future can complete while its exit frame is still using
        // the text fields. Dispose after that frame has been removed.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          cashController.dispose();
          momoController.dispose();
        });
      }),
    );
  }

  void _openConfirmTopUpDialog(_TopUpRequest item) {
    final approvedAmount = item.approvedAmount;
    if (approvedAmount == null) {
      _snack('This top-up does not have an approved amount.');
      return;
    }
    var note = '';
    String? error;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _ExpenseDialogShell(
            title: 'Confirm amount received',
            subtitle: 'Confirm the exact allocation recorded by the disburser.',
            primaryLabel: 'Confirm received',
            width: 500,
            onPrimary: () async {
              if (note.trim().isEmpty) {
                setDialogState(() => error = 'Add a confirmation note.');
                return;
              }
              Navigator.pop(context);
              final saved = await _runFinanceMutation(
                request: () => _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/confirm',
                  body: {
                    'cashAmount': item.cashAmount ?? 0,
                    'momoAmount': item.momoAmount ?? 0,
                    'momoWalletNumber': item.momoWalletNumber,
                    'notes': note.trim(),
                  },
                ),
                successMessage: 'Top-up confirmed and float restored.',
              );
              if (saved && mounted) {
                setState(() {
                  _selectedTopUp = null;
                  _financeLedgerPage = _FinanceLedgerPage.topUps;
                });
              }
            },
            child: Column(
              children: [
                _DialogSummary(
                  title: 'Approved amount',
                  value: _money(approvedAmount),
                  subtitle: '${item.requestId} · confirm funds received',
                  color: AppColors.blue,
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Recipient confirmation',
                  child: Column(
                    children: [
                      _ReadOnlyRow(
                        'Cash received',
                        _money(item.cashAmount ?? 0),
                      ),
                      _ReadOnlyRow(
                        'MoMo received',
                        _money(item.momoAmount ?? 0),
                      ),
                      if (item.momoWalletNumber != null)
                        _ReadOnlyRow('MoMo wallet', item.momoWalletNumber!),
                      const SizedBox(height: 12),
                      TextField(
                        minLines: 2,
                        maxLines: 3,
                        onChanged: (value) => note = value,
                        decoration: InputDecoration(
                          labelText: 'Confirmation note',
                          errorText: error,
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

  Future<void> _topUpNoteAction(
    _TopUpRequest item,
    String action,
    String title,
    String prompt,
  ) async {
    if (item.serverId == null) return;
    var note = '';
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 440,
            child: TextField(
              minLines: 3,
              maxLines: 5,
              onChanged: (v) => note = v,
              decoration: InputDecoration(
                labelText: 'Required note',
                hintText: prompt,
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              style: action == 'report-problem'
                  ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                  : _primaryButtonStyle(),
              onPressed: () {
                if (note.trim().isEmpty) {
                  setDialogState(() => error = 'A note is required.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(title),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/top-ups/${item.serverId}/$action',
        body: {'note': note.trim()},
      ),
      successMessage: '$title recorded.',
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
    final formKey = GlobalKey<FormState>();
    String? formError;
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
              setDialogState(() => formError = null);
              if (!(formKey.currentState?.validate() ?? false)) return;
              final moved = _parseAmount(amount.text);
              final charge = _parseAmount(fee.text);
              final termId = _academicTermId;
              if (termId == null) {
                setDialogState(
                  () => formError =
                      'The current academic term is not available. Refresh and try again.',
                );
                return;
              }
              final cashAfter = momoToCash
                  ? _cashBalance + moved
                  : _cashBalance - moved - charge;
              final momoAfter = momoToCash
                  ? _momoBalance - moved - charge
                  : _momoBalance + moved;
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (confirmationContext) => _ExpenseDialogShell(
                  title: 'Confirm pocket transfer',
                  subtitle: 'Confirm the movement before it is recorded.',
                  primaryLabel: 'Confirm transfer',
                  secondaryLabel: 'Back',
                  width: 520,
                  onPrimary: () => Navigator.pop(confirmationContext, true),
                  child: Column(
                    children: [
                      _DialogSummary(
                        title: '$fromPocket to $toPocket',
                        value: _money(moved),
                        subtitle: charge == 0
                            ? 'No transfer fee'
                            : '${_money(charge)} transfer fee',
                        color: AppColors.green,
                      ),
                      const SizedBox(height: 14),
                      _FormSection(
                        title: 'Balances after transfer',
                        child: Column(
                          children: [
                            _InfoRow('Cash pocket', _money(cashAfter)),
                            _InfoRow('MoMo pocket', _money(momoAfter)),
                            _InfoRow(
                              'Total float',
                              _money(cashAfter + momoAfter),
                            ),
                            if (reference.text.trim().isNotEmpty)
                              _InfoRow('Reference', reference.text.trim()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _InlineNotice(
                        icon: Icons.verified_outlined,
                        color: AppColors.blue,
                        text:
                            'I confirm that this transfer direction and amount are correct.',
                      ),
                    ],
                  ),
                ),
              );
              if (confirmed != true || !context.mounted) return;
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
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (formError != null) ...[
                    _InlineNotice(
                      icon: Icons.error_outline,
                      color: AppColors.red,
                      text: formError!,
                    ),
                    const SizedBox(height: 14),
                  ],
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
                                    onTap: () => setDialogState(
                                      () => momoToCash = false,
                                    ),
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    validator: (text) {
                      final moved = _strictAmount(text ?? '');
                      final charge = _strictAmount(fee.text);
                      if (moved == null || moved <= 0) {
                        return 'Enter an amount greater than zero.';
                      }
                      if (charge == null || charge < 0) return null;
                      final available = momoToCash
                          ? _momoBalance
                          : _cashBalance;
                      if (moved + charge > available) {
                        return '${momoToCash ? 'MoMo' : 'Cash'} has only ${_money(available)} available, including the fee.';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Amount (GHS)',
                      prefixText: 'GH¢ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: reference,
                    decoration: const InputDecoration(
                      labelText: 'Reference',
                      hintText: 'Agent receipt or deposit slip',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: fee,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setDialogState(() {}),
                    validator: (text) {
                      final charge = _strictAmount(text ?? '');
                      if (charge == null || charge < 0) {
                        return 'Enter zero or a valid fee amount.';
                      }
                      return null;
                    },
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
    final formKey = GlobalKey<FormState>();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record refund'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
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
                TextFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  validator: (text) {
                    final value = _strictAmount(text ?? '');
                    if (value == null || value <= 0) {
                      return 'Enter an amount greater than zero.';
                    }
                    if (value > item.refundableAmount) {
                      return 'Maximum available refund is ${_money(item.refundableAmount)}.';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Refund amount',
                    prefixText: 'GH¢ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reason,
                  minLines: 2,
                  maxLines: 4,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a reason for the refund.'
                      : null,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final value = _parseAmount(amount.text);
              if (item.serverId == null) {
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

  Future<void> _openExpenseReversalDialog(_ExpenseRecord item) async {
    if (!_canRequestExpenseReversal(item)) return;
    final approvers = _topUpApprovers
        .where((actor) => actor.id != widget.currentUserId)
        .toList();
    if (approvers.isEmpty) {
      _snack('No independent expense-reversal approver is available.');
      return;
    }
    var reasonType = _ExpenseReversalReason.duplicate;
    var reason = '';
    int? approverId;
    var affirmed = false;
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request expense reversal'),
          content: SizedBox(
            width: 540,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSummary(
                      title: item.expenseId,
                      value: _money(item.amount),
                      subtitle:
                          '${item.description} · ${item.source.label} · ${item.channel.label}',
                      color: AppColors.red,
                    ),
                    const SizedBox(height: 14),
                    const _InlineNotice(
                      icon: Icons.info_outline,
                      color: AppColors.amber,
                      text:
                          'Use reversal only when the expense record itself is wrong. If a valid payment was later returned, record a refund instead. Reversal is always for the full expense.',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<_ExpenseReversalReason>(
                      value: reasonType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Recording error type',
                      ),
                      items: _ExpenseReversalReason.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => reasonType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (value) => reason = value,
                      validator: (value) => (value?.trim().length ?? 0) < 10
                          ? 'Explain the error in at least 10 characters.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Reason and evidence *',
                        hintText:
                            'Explain what was recorded incorrectly and how it was verified.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: const ValueKey('expense-reversal-approver'),
                      value: approverId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Independent approver *',
                      ),
                      hint: const Text('Choose who will decide this reversal'),
                      items: approvers
                          .map(
                            (actor) => DropdownMenuItem(
                              value: actor.id,
                              child: Text('${actor.name} · ${actor.role}'),
                            ),
                          )
                          .toList(),
                      validator: (value) => value == null
                          ? 'Select an independent approver.'
                          : null,
                      onChanged: (value) =>
                          setDialogState(() => approverId = value),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: affirmed,
                      onChanged: (value) =>
                          setDialogState(() => affirmed = value ?? false),
                      title: const Text(
                        'I confirm this expense record is erroneous and the full amount must be reviewed for reversal.',
                      ),
                      subtitle: Text(
                        item.source == _ExpenseSource.pettyCash
                            ? 'If approved, ${_money(item.amount)} returns to the ${item.channel == _PaymentChannel.floatMomo ? 'MoMo' : 'Cash'} pocket.'
                            : 'If approved, ${_money(item.amount)} is removed from school-expense totals. Petty cash is not changed.',
                      ),
                    ),
                    if (!affirmed)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text(
                          'Confirm the statement before submitting.',
                          style: TextStyle(color: AppColors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('submit-expense-reversal'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false) ||
                    !affirmed ||
                    item.serverId == null) {
                  return;
                }
                final saved = await _runFinanceMutation(
                  request: () => _financeApi.post(
                    '/api/schools/${widget.customSchoolId}/finance/transactions/${item.serverId}/reversals',
                    body: {
                      'reasonCode': reasonType.code,
                      'reason': reason.trim(),
                      'approverUserId': approverId,
                    },
                  ),
                  successMessage: 'Expense reversal submitted for approval.',
                );
                if (saved && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: _primaryButtonStyle(),
              child: const Text('Submit reversal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _decideExpenseReversal(
    _ExpenseReversal reversal,
    String action,
  ) async {
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var affirmed = action != 'approve';
    final title = switch (action) {
      'approve' => 'Approve expense reversal',
      'decline' => 'Decline expense reversal',
      _ => 'Cancel expense reversal',
    };
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogSummary(
                    title: reversal.reference,
                    value: _money(reversal.amount),
                    subtitle:
                        '${reversal.reasonLabel} · requested by ${reversal.requester}',
                    color: action == 'approve'
                        ? AppColors.red
                        : AppColors.amber,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: ValueKey('expense-reversal-$action-note'),
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a decision note.'
                        : null,
                    decoration: InputDecoration(
                      labelText: action == 'approve'
                          ? 'Approval note *'
                          : 'Reason *',
                    ),
                  ),
                  if (action == 'approve') ...[
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: affirmed,
                      onChanged: (value) =>
                          setDialogState(() => affirmed = value ?? false),
                      title: Text(
                        'I confirm the original expense is erroneous and approve a full reversal of ${_money(reversal.amount)}.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Back'),
            ),
            FilledButton(
              key: ValueKey('$action-expense-reversal'),
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false) ||
                    !affirmed ||
                    reversal.serverId == null) {
                  return;
                }
                final saved = await _runFinanceMutation(
                  request: () => _financeApi.post(
                    '/api/schools/${widget.customSchoolId}/finance/reversals/${reversal.serverId}/$action',
                    body: {'note': note.text.trim()},
                  ),
                  successMessage: switch (action) {
                    'approve' => 'Expense reversal approved.',
                    'decline' => 'Expense reversal declined.',
                    _ => 'Expense reversal cancelled.',
                  },
                );
                if (saved && dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: action == 'approve' ? AppColors.red : _green,
              ),
              child: Text(action == 'approve' ? 'Approve reversal' : title),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewExpenseReversal(_ExpenseReversal reversal) async {
    final reversalId = reversal.serverId;
    if (reversalId == null) {
      _snack('This reversal cannot be opened right now.');
      return;
    }
    try {
      final inbox = await _approvalApi.getInbox(widget.customSchoolId);
      ApprovalItem? approval;
      for (final item in [...inbox.myApprovals, ...inbox.myRequests]) {
        if (item.type == 'FINANCE_EXPENSE_REVERSAL' &&
            item.entityId == reversalId) {
          approval = item;
          break;
        }
      }
      if (!mounted) return;
      if (approval == null) {
        _snack('This reversal is no longer waiting for your review.');
        await _loadFinanceWorkspace(showLoading: false);
        return;
      }
      final selectedApproval = approval;
      await showApprovalItemPanel(
        context: context,
        item: selectedApproval,
        onAction: (action, reason) async {
          await _approvalApi.performAction(
            schoolId: widget.customSchoolId,
            item: selectedApproval,
            action: action,
            reason: reason,
          );
        },
        onReload: () {
          unawaited(_loadFinanceWorkspace(showLoading: false));
        },
      );
    } on ApprovalApiException catch (error) {
      if (mounted) _snack(error.message);
    }
  }

  bool _canRequestExpenseReversal(_ExpenseRecord item) {
    final hasPostedFinancialEffect =
        item.status == _ExpenseStatus.complete ||
        item.status == _ExpenseStatus.ratified ||
        item.status == _ExpenseStatus.pendingRatification ||
        item.status == _ExpenseStatus.pendingVarianceReview;
    return _canViewAllFinance &&
        item.serverId != null &&
        item.amount > 0 &&
        hasPostedFinancialEffect &&
        item.refundedAmount <= 0 &&
        item.reversal == null &&
        item.status != _ExpenseStatus.reversed &&
        item.status != _ExpenseStatus.pendingReversal;
  }

  Future<void> _openExpenseDetailDialog(_ExpenseRecord item) async {
    _RequisitionRecord? linkedRequisition;
    if (item.requisitionId != null) {
      for (final requisition in _requisitions) {
        if (requisition.id == item.requisitionId ||
            requisition.serverId?.toString() == item.requisitionId) {
          linkedRequisition = requisition;
          break;
        }
      }
    }

    final approvedAmount = item.approvedAmount;
    final difference = approvedAmount == null
        ? 0.0
        : item.amount - approvedAmount;
    final hasVariance = approvedAmount != null && difference.abs() > 0.005;
    final varianceSummary = hasVariance
        ? '${_money(difference.abs())} ${difference > 0 ? 'higher' : 'lower'} than approved'
        : 'No variance';
    final reversalHistory =
        _expenseReversals
            .where((reversal) => reversal.parentTransactionId == item.serverId)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    var history = <_FinanceHistoryEntry>[];
    if (item.serverId != null) {
      try {
        final response = await _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/notes',
          query: {'parentType': 'TRANSACTION', 'parentId': '${item.serverId}'},
        );
        history = _financeHistoryEntries(response);
      } on FinanceApiException {
        // The expense remains usable when its audit notes cannot be loaded.
      }
    }
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) => _ExpenseDialogShell(
        title: item.description,
        subtitle: '${item.expenseId} · ${item.status.label}',
        primaryLabel: 'Close',
        showSecondaryAction: false,
        width: 620,
        onPrimary: () => Navigator.pop(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogSummary(
              title: 'Actual expense',
              value: _money(item.amount),
              subtitle:
                  '${item.source.label} · ${item.channel.label} · ${_date(item.transactionDate)}',
              color: hasVariance ? AppColors.amber : AppColors.green,
            ),
            const SizedBox(height: 14),
            _FormSection(
              title: 'Payment record',
              child: Column(
                children: [
                  _InfoRow('Expense ID', item.expenseId),
                  _InfoRow('Status', item.status.label),
                  _InfoRow('Funding source', item.source.label),
                  _InfoRow('Payment channel', item.channel.label),
                  if (item.momoFee > 0)
                    _InfoRow('MoMo fee', _money(item.momoFee)),
                  if (item.requisitionId != null)
                    _InfoRow(
                      'Requisition',
                      _requisitionReference(item.requisitionId)!,
                    ),
                  if (item.linkedExpenseId != null)
                    _InfoRow('Linked expense', item.linkedExpenseId!),
                  _InfoRow(
                    'Receipt',
                    item.receiptNumber.isEmpty
                        ? 'Not provided'
                        : item.receiptNumber,
                  ),
                ],
              ),
            ),
            if (approvedAmount != null) ...[
              const SizedBox(height: 14),
              _FormSection(
                title: 'Approval and variance',
                child: Column(
                  children: [
                    _InfoRow(
                      item.isEmergency ? 'Verbal estimate' : 'Approved amount',
                      _money(approvedAmount),
                    ),
                    _InfoRow('Actual amount', _money(item.amount)),
                    _InfoRow('Difference', varianceSummary),
                    _InfoRow('Review status', item.varianceStatus.label),
                    if (item.approvalStatus ==
                        _ExpenseApprovalStatus.pendingRatification)
                      _InfoRow('Emergency approval', item.approvalStatus.label),
                  ],
                ),
              ),
            ],
            if (reversalHistory.isNotEmpty) ...[
              const SizedBox(height: 14),
              _FormSection(
                title: 'Reversal history',
                child: Column(
                  children: [
                    for (final reversal in reversalHistory)
                      _ActionTile(
                        icon: Icons.cancel_presentation_outlined,
                        iconColor: reversal.status.color,
                        title:
                            '${reversal.reference} · ${reversal.status.label}',
                        subtitle:
                            '${reversal.reasonLabel} · requested by ${reversal.requester} · approver ${reversal.approver}\n${reversal.notes}',
                        trailing: _StatusPill(
                          label: reversal.status.label,
                          color: reversal.status.color,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (item.notes.isNotEmpty ||
                item.varianceExplanation.isNotEmpty ||
                item.varianceReviewNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              _FormSection(
                title: 'Notes',
                child: Column(
                  children: [
                    if (item.notes.isNotEmpty)
                      _InfoRow('Expense note', item.notes),
                    if (item.varianceExplanation.isNotEmpty)
                      _InfoRow(
                        'Variance explanation',
                        item.varianceExplanation,
                      ),
                    if (item.varianceReviewNotes.isNotEmpty)
                      _InfoRow('Review note', item.varianceReviewNotes),
                  ],
                ),
              ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 14),
              _FormSection(
                title: 'Review history',
                child: Column(
                  children: [
                    for (final entry in history)
                      _ActionTile(
                        icon: entry.icon,
                        iconColor: entry.color,
                        title: entry.label,
                        subtitle:
                            '${entry.author} · ${_dateTime(entry.createdAt)}\n${entry.note}',
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (linkedRequisition != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openRequisitionWorkspace(linkedRequisition!);
                    },
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('Open requisition'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _printExpenseRecord(item),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _downloadExpenseCopy(item),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                ),
                if (item.amount > 0 && item.refundableAmount > 0)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openRefundDialog(item);
                    },
                    icon: const Icon(Icons.currency_exchange_outlined),
                    label: const Text('Record refund'),
                  ),
                if (_canRequestExpenseReversal(item))
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openExpenseReversalDialog(item);
                    },
                    icon: const Icon(Icons.cancel_presentation_outlined),
                    label: const Text('Request reversal'),
                  ),
                if (item.reversal case final reversal?
                    when reversal.status == _ExpenseReversalStatus.pending &&
                        _isCurrentUser(reversal.requesterUserId))
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _decideExpenseReversal(reversal, 'cancel');
                    },
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Cancel reversal'),
                  ),
                if (item.reversal case final reversal?
                    when reversal.status == _ExpenseReversalStatus.pending &&
                        _isCurrentUser(reversal.approverUserId)) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _decideExpenseReversal(reversal, 'decline');
                    },
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Decline reversal'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _decideExpenseReversal(reversal, 'approve');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Approve reversal'),
                  ),
                ],
                if (_canApproveFinance &&
                    item.approvalStatus ==
                        _ExpenseApprovalStatus.pendingRatification)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(context);
                      _ratifyExpense(item);
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Ratify emergency'),
                  ),
                if (_canApproveFinance &&
                    item.varianceStatus == _VarianceStatus.pendingReview)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openVarianceReviewDialog(item);
                    },
                    icon: const Icon(Icons.rule_outlined),
                    label: const Text('Review variance'),
                  ),
              ],
            ),
          ],
        ),
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
    final formKey = GlobalKey<FormState>();
    showDialog<void>(
      context: context,
      builder: (context) => _ExpenseDialogShell(
        title: 'Request reconciliation',
        subtitle: 'Ask staff to count cash and confirm the MoMo wallet.',
        primaryLabel: 'Send request',
        width: 560,
        onPrimary: () async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          final assignedTo = assignee.text.trim();
          final requestReason = reason.text.trim();
          final saved = await _runFinanceMutation(
            request: () => _financeApi.post(
              '/api/schools/${widget.customSchoolId}/finance/reconciliations',
              body: {
                'academicTermId': _academicTermId,
                'assignedTo': assignedTo,
                'reason': requestReason,
              },
            ),
            successMessage: 'Reconciliation request sent to $assignedTo.',
          );
          if (saved && context.mounted) Navigator.pop(context);
        },
        child: Form(
          key: formKey,
          child: Column(
            children: [
              _FormSection(
                title: 'Assignment',
                child: Column(
                  children: [
                    TextFormField(
                      controller: assignee,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Choose the staff member responsible for the count.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Staff responsible for confirmation',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reason,
                      maxLines: 2,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter the reason for this reconciliation.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Reason or cycle note',
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
      ),
    );
  }

  Future<void> _startReconciliation(_ReconciliationRecord item) async {
    if (item.serverId == null) {
      _snack(
        'This reconciliation is missing its server ID. Refresh and retry.',
      );
      return;
    }
    final saved = await _runFinanceMutation(
      request: () => _financeApi.post(
        '/api/schools/${widget.customSchoolId}/finance/reconciliations/${item.serverId}/start',
      ),
      successMessage:
          'Count started. The current Cash and MoMo balances have been captured for ${item.reference}.',
    );
    if (saved && mounted) {
      final refreshed = _reconciliations.where(
        (record) => record.serverId == item.serverId,
      );
      if (refreshed.isNotEmpty) {
        setState(() => _selectedReconciliation = refreshed.first);
      }
    }
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
    final formKey = GlobalKey<FormState>();
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
            onPrimary: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (item.serverId == null) {
                return;
              }
              final evidenceText = evidence.text.trim();
              final noteText = notes.text.trim();
              final saved = await _runFinanceMutation(
                request: () => _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/reconciliations/${item.serverId}/confirm',
                  body: {
                    'actualCash': actualCash,
                    'actualMomo': actualMomo,
                    'evidenceReference': evidenceText,
                    'note': noteText,
                  },
                ),
                successMessage: variance == 0
                    ? 'Reconciliation confirmed. The system and physical balances match.'
                    : 'Reconciliation recorded with a ${variance > 0 ? 'surplus' : 'shortfall'} of ${_money(variance.abs())}.',
              );
              if (saved && context.mounted) {
                final refreshed = _reconciliations.where(
                  (record) => record.serverId == item.serverId,
                );
                if (refreshed.isNotEmpty && mounted) {
                  setState(() => _selectedReconciliation = refreshed.first);
                }
                Navigator.pop(context);
              }
            },
            child: Form(
              key: formKey,
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
                          child: TextFormField(
                            controller: cash,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            validator: (text) {
                              final value = _strictAmount(text ?? '');
                              return value == null || value < 0
                                  ? 'Enter zero or a valid amount.'
                                  : null;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Physical cash counted',
                              prefixText: 'GH¢ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: momo,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                            validator: (text) {
                              final value = _strictAmount(text ?? '');
                              return value == null || value < 0
                                  ? 'Enter zero or a valid amount.'
                                  : null;
                            },
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

  void _openVarianceClosureDialog(_ReconciliationRecord item) {
    final resolution = TextEditingController(text: item.varianceResolution);
    var followUpType = item.totalVariance < 0
        ? _FollowUpType.staffRecovery
        : _FollowUpType.cashSurplus;
    final formKey = GlobalKey<FormState>();
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: 'Close reconciliation variance',
          subtitle:
              '${item.reference} has a ${item.totalVariance > 0 ? 'surplus' : 'shortfall'} of ${_money(item.totalVariance.abs())}.',
          primaryLabel: 'Close variance',
          width: 560,
          onPrimary: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final note = resolution.text.trim();
            if (item.serverId == null) {
              return;
            }
            final resolutionType = switch (followUpType) {
              _FollowUpType.staffRecovery => 'RECOVER_FROM_STAFF',
              _FollowUpType.cashSurplus => 'EXCESS_RETURN',
              _FollowUpType.unconfirmedTransfer => 'CORRECT_ENTRY',
              _ => 'WRITE_OFF',
            };
            final resolved = await _runFinanceMutation(
              request: () async {
                await _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/reconciliations/${item.serverId}/resolve',
                  body: {
                    'resolutionType': resolutionType,
                    'responsibleParty': item.assignedTo,
                    'notes': note,
                  },
                );
                return _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/reconciliations/${item.serverId}/close',
                  body: const {},
                );
              },
              successMessage:
                  'Variance closed and the linked financial follow-up was recorded.',
            );
            if (resolved && context.mounted) Navigator.pop(context);
          },
          child: Form(
            key: formKey,
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
                  decoration: const InputDecoration(
                    labelText: 'Follow-up route',
                  ),
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
                  onChanged: (value) => setDialogState(
                    () => followUpType = value ?? followUpType,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: resolution,
                  maxLines: 4,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Add a resolution note before closing the variance.'
                      : null,
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
      ),
    );
  }

  void _openNewFollowUpDialog() {
    final related = TextEditingController();
    final owner = TextEditingController();
    final amount = TextEditingController();
    final summary = TextEditingController();
    var type = _FollowUpType.missingReceipt;
    final formKey = GlobalKey<FormState>();
    String? formError;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: 'Record financial follow-up',
          subtitle:
              'Create an exception record for accountant review and closure.',
          primaryLabel: 'Create follow-up',
          onPrimary: () async {
            setDialogState(() => formError = null);
            if (!(formKey.currentState?.validate() ?? false)) return;
            final relatedReference = related.text.trim();
            final assignedOwner = owner.text.trim();
            final value = _parseAmount(amount.text);
            final description = summary.text.trim();
            final termId = _academicTermId;
            if (termId == null) {
              setDialogState(
                () => formError =
                    'The current academic term is not available. Refresh and try again.',
              );
              return;
            }
            final apiType = switch (type) {
              _FollowUpType.staffRecovery => 'RECOVER_FROM_STAFF',
              _FollowUpType.missingReceipt => 'MISSING_RECEIPT',
              _FollowUpType.vendorRefund => 'VENDOR_REFUND',
              _FollowUpType.cashShortage => 'CASH_SHORTAGE',
              _FollowUpType.unconfirmedTransfer => 'UNCONFIRMED_TRANSFER',
              _FollowUpType.cashSurplus => 'CASH_SURPLUS',
              _FollowUpType.floatOverage => 'FLOAT_OVERAGE',
              _FollowUpType.expenseVariance => 'EXPENSE_VARIANCE',
            };
            final saved = await _runFinanceMutation(
              request: () => _financeApi.post(
                '/api/schools/${widget.customSchoolId}/finance/follow-ups',
                body: {
                  'academicTermId': termId,
                  'type': apiType,
                  'relatedReference': relatedReference,
                  'responsibleParty': assignedOwner,
                  'amount': value,
                  'description': description.isEmpty
                      ? 'Manual follow-up recorded for $relatedReference.'
                      : description,
                  'dueDate': DateTime.now()
                      .add(const Duration(days: 7))
                      .toIso8601String()
                      .split('T')
                      .first,
                  'note': 'Follow-up opened manually.',
                },
              ),
              successMessage: 'Financial follow-up created.',
            );
            if (saved && context.mounted) Navigator.pop(context);
          },
          child: Form(
            key: formKey,
            child: Column(
              children: [
                if (formError != null) ...[
                  _InlineNotice(
                    icon: Icons.error_outline,
                    color: AppColors.red,
                    text: formError!,
                  ),
                  const SizedBox(height: 14),
                ],
                DropdownButtonFormField<_FollowUpType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _FollowUpType.values
                      .where((value) => value != _FollowUpType.floatOverage)
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
                  left: TextFormField(
                    controller: related,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the related record.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Related record',
                      hintText: 'Expense, top-up, or reconciliation reference',
                    ),
                  ),
                  right: TextFormField(
                    controller: owner,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the responsible party.'
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Owner',
                      hintText: 'Staff member or supplier',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (text) {
                    final value = _strictAmount(text ?? '');
                    return value == null || value <= 0
                        ? 'Enter an amount greater than zero.'
                        : null;
                  },
                  decoration: const InputDecoration(labelText: 'Amount (GH¢)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
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
      ),
    );
  }

  Future<void> _openFollowUpDetailDialog(_FinancialFollowUp item) async {
    final relatedLabel = item.relatedReference.startsWith('EXP-')
        ? 'Related expense'
        : 'Related record';
    _ExpenseRecord? linkedExpense;
    for (final expense in _expenses) {
      if (expense.serverId == item.relatedTransactionId ||
          expense.expenseId == item.relatedReference ||
          expense.serverId?.toString() == item.relatedReference) {
        linkedExpense = expense;
        break;
      }
    }
    if (item.serverId != null) {
      try {
        final response = await _financeApi.get(
          '/api/schools/${widget.customSchoolId}/finance/notes',
          query: {'parentType': 'FOLLOW_UP', 'parentId': '${item.serverId}'},
        );
        item.notes
          ..clear()
          ..addAll(_financeNotes(response));
      } on FinanceApiException catch (error) {
        if (mounted) _snack(error.message);
      }
    }
    if (!mounted) return;
    final note = TextEditingController();
    final noteFormKey = GlobalKey<FormState>();
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: item.reference,
          subtitle: 'Financial follow-up · ${item.status.label}',
          primaryLabel: item.isClosed || !_canApproveFinance
              ? 'Done'
              : 'Close follow-up',
          showSecondaryAction: !item.isClosed && _canApproveFinance,
          onPrimary: () {
            if (item.isClosed || !_canApproveFinance) {
              Navigator.pop(context);
              return;
            }
            _openFollowUpClosureDialog(item, parentContext: context);
          },
          width: 640,
          child: Form(
            key: noteFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DialogSummary(
                  title: item.type.label,
                  value: _money(item.amount),
                  subtitle:
                      '${item.status.label} · Due ${item.dueDate == null ? 'date not set' : _date(item.dueDate!)}',
                  color: item.status.color,
                ),
                const SizedBox(height: 14),
                _FormSection(
                  title: 'Case details',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              relatedLabel,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: linkedExpense == null
                                ? Text(item.relatedReference)
                                : Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await Future<void>.delayed(
                                          const Duration(milliseconds: 250),
                                        );
                                        if (mounted) {
                                          _openExpenseDetailDialog(
                                            linkedExpense!,
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 16,
                                      ),
                                      label: Text(item.relatedReference),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      _InfoRow('Responsible party', item.owner),
                      _InfoRow('Opened', _date(item.createdAt)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _InlineNotice(
                  icon: Icons.priority_high_rounded,
                  color: item.status.color,
                  text: item.summary,
                ),
                const SizedBox(height: 18),
                const _SectionLabel('ACTIVITY & EVIDENCE'),
                const SizedBox(height: 10),
                if (item.notes.isEmpty)
                  const _InlineNotice(
                    icon: Icons.history_outlined,
                    color: AppColors.blue,
                    text: 'No investigation notes or evidence added yet.',
                  )
                else
                  for (final entry in item.notes) ...[
                    _FollowUpNoteTile(note: entry),
                    const SizedBox(height: 8),
                  ],
                if (!item.isClosed) ...[
                  const SizedBox(height: 14),
                  _FormSection(
                    title: 'Add an update',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: note,
                          maxLines: 3,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Add a note before saving.'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Note or evidence reference',
                            hintText:
                                'Record what was checked, found, or attached.',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final text = note.text.trim();
                            if (!(noteFormKey.currentState?.validate() ??
                                false)) {
                              return;
                            }
                            if (item.serverId == null) return;
                            final saved = await _runFinanceMutation(
                              request: () => _financeApi.post(
                                '/api/schools/${widget.customSchoolId}/finance/follow-ups/${item.serverId}/notes',
                                body: {'note': text},
                              ),
                              successMessage: 'Follow-up note added.',
                            );
                            if (!saved || !context.mounted) return;
                            try {
                              final response = await _financeApi.get(
                                '/api/schools/${widget.customSchoolId}/finance/notes',
                                query: {
                                  'parentType': 'FOLLOW_UP',
                                  'parentId': '${item.serverId}',
                                },
                              );
                              if (!context.mounted) return;
                              setDialogState(() {
                                item.notes
                                  ..clear()
                                  ..addAll(_financeNotes(response));
                                note.clear();
                              });
                            } on FinanceApiException catch (error) {
                              if (mounted) _snack(error.message);
                            }
                          },
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Save update'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFollowUpClosureDialog(
    _FinancialFollowUp item, {
    required BuildContext parentContext,
  }) {
    final resolution = TextEditingController();
    final cashReturned = TextEditingController();
    final momoReturned = TextEditingController();
    final reference = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isFloatOverage = item.type == _FollowUpType.floatOverage;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cash = _strictAmount(cashReturned.text) ?? 0;
          final momo = _strictAmount(momoReturned.text) ?? 0;
          final total = cash + momo;
          final difference = item.amount - total;
          return _ExpenseDialogShell(
            title: 'Close ${item.reference}',
            subtitle: isFloatOverage
                ? 'Record the excess moved back to school funds.'
                : 'Administrator resolution is required to close this record.',
            primaryLabel: isFloatOverage
                ? 'Record return & close'
                : 'Close follow-up',
            onPrimary: () async {
              final text = resolution.text.trim();
              if (!(formKey.currentState?.validate() ?? false)) return;
              if (item.serverId == null) return;
              final body = <String, dynamic>{'note': text};
              if (isFloatOverage) {
                body.addAll({
                  'cashAmount': cash,
                  'momoAmount': momo,
                  'reference': reference.text.trim(),
                });
              }
              final closed = await _runFinanceMutation(
                request: () => _financeApi.post(
                  '/api/schools/${widget.customSchoolId}/finance/follow-ups/${item.serverId}/close',
                  body: body,
                ),
                successMessage: isFloatOverage
                    ? '${item.reference} closed. ${_money(total)} was returned to school funds.'
                    : '${item.reference} closed with an administrator resolution.',
              );
              if (closed && context.mounted) {
                Navigator.pop(context);
                if (parentContext.mounted) Navigator.pop(parentContext);
              }
            },
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  _InlineNotice(
                    icon: isFloatOverage
                        ? Icons.account_balance_outlined
                        : Icons.admin_panel_settings_outlined,
                    color: AppColors.amber,
                    text: isFloatOverage
                        ? 'Return exactly ${_money(item.amount)} from the Cash and/or MoMo pockets. The system will reduce the float and keep an auditable return record.'
                        : 'Closing preserves the case and its evidence trail. It does not remove the underlying expense, transfer, or reconciliation record.',
                  ),
                  if (isFloatOverage) ...[
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Return to school funds',
                      child: Column(
                        children: [
                          _TwoFields(
                            left: TextFormField(
                              key: const ValueKey('overage-cash-returned'),
                              controller: cashReturned,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setDialogState(() {}),
                              validator: (value) {
                                final raw = value?.trim() ?? '';
                                final amount = raw.isEmpty
                                    ? 0
                                    : _strictAmount(raw);
                                if (amount == null) {
                                  return 'Enter a valid Cash amount.';
                                }
                                if (amount > _cashBalance) {
                                  return 'Only ${_money(_cashBalance)} is available.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Cash returned',
                                hintText: '0.00',
                                helperText: '${_money(_cashBalance)} available',
                              ),
                            ),
                            right: TextFormField(
                              key: const ValueKey('overage-momo-returned'),
                              controller: momoReturned,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setDialogState(() {}),
                              validator: (value) {
                                final raw = value?.trim() ?? '';
                                final amount = raw.isEmpty
                                    ? 0
                                    : _strictAmount(raw);
                                if (amount == null) {
                                  return 'Enter a valid MoMo amount.';
                                }
                                if (amount > _momoBalance) {
                                  return 'Only ${_money(_momoBalance)} is available.';
                                }
                                if ((cash + momo - item.amount).abs() > .005) {
                                  return 'Cash and MoMo must total ${_money(item.amount)}.';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'MoMo returned',
                                hintText: '0.00',
                                helperText: '${_money(_momoBalance)} available',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('overage-return-reference'),
                            controller: reference,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the bank deposit or transfer reference.'
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Transfer or deposit reference',
                              hintText:
                                  'Bank slip, transfer, or journal reference',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DialogSummary(
                      title: difference.abs() <= .005
                          ? 'Amount ready to return'
                          : 'Amount still to allocate',
                      value: _money(
                        difference.abs() <= .005 ? total : difference,
                      ),
                      subtitle: difference.abs() <= .005
                          ? 'Cash ${_money(cash)} · MoMo ${_money(momo)} · destination School funds'
                          : 'Allocate exactly ${_money(item.amount)} before closing.',
                      color: difference.abs() <= .005
                          ? AppColors.green
                          : AppColors.amber,
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: resolution,
                    maxLines: 4,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a resolution note before closing this follow-up.'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Resolution note',
                      hintText: isFloatOverage
                          ? 'State where the excess was returned and who verified it.'
                          : 'State the final decision, recovery, write-off, or correction.',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _ratifyExpense(_ExpenseRecord item) {
    if (!_canApproveFinance) {
      _snack('Your role cannot ratify expenses.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This expense cannot be ratified because its server ID is missing.',
      );
      return;
    }
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ExpenseDialogShell(
        title: 'Ratify emergency expense',
        subtitle:
            'Confirm that the completed emergency payment is a legitimate school expense.',
        primaryLabel: 'Ratify expense',
        onPrimary: () async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          final value = note.text.trim();
          Navigator.pop(dialogContext);
          await _runFinanceMutation(
            request: () => _financeApi.post(
              '/api/schools/${widget.customSchoolId}/finance/transactions/${item.serverId}/ratify',
              body: {'note': value},
            ),
            successMessage: '${item.expenseId} ratified.',
          );
        },
        child: Form(
          key: formKey,
          child: Column(
            children: [
              const _InlineNotice(
                icon: Icons.gavel_outlined,
                color: AppColors.amber,
                text:
                    'Ratification adds an after-the-fact approval to the permanent audit trail. It does not replace the original verbal authorisation.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: note,
                minLines: 3,
                maxLines: 5,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Add a ratification note before continuing.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Ratification note',
                  hintText: 'Explain why this emergency payment is accepted.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVarianceReviewDialog(_ExpenseRecord item) async {
    if (!_canApproveFinance) {
      _snack('Your role cannot review expense variances.');
      return;
    }
    if (item.serverId == null) {
      _snack(
        'This variance cannot be reviewed because its server ID is missing.',
      );
      return;
    }
    final reviewNotes = TextEditingController(text: item.varianceReviewNotes);
    var outcome = _VarianceOutcome.accept;
    final approved = item.approvedAmount ?? 0;
    final formKey = GlobalKey<FormState>();
    var history = <_FinanceHistoryEntry>[];
    try {
      final response = await _financeApi.get(
        '/api/schools/${widget.customSchoolId}/finance/notes',
        query: {'parentType': 'TRANSACTION', 'parentId': '${item.serverId}'},
      );
      history = _financeHistoryEntries(response);
    } on FinanceApiException {
      // A temporary history failure must not block the review action.
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _ExpenseDialogShell(
          title: 'Review variance',
          subtitle:
              'Approved ${_money(approved)} · actual ${_money(item.amount)} · ${item.varianceLabel}',
          primaryLabel: 'Save review',
          width: 600,
          onPrimary: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final note = reviewNotes.text.trim();
            final apiOutcome = switch (outcome) {
              _VarianceOutcome.accept => 'ACCEPT',
              _VarianceOutcome.escalate => 'ESCALATE',
            };
            final saved = await _runFinanceMutation(
              request: () => _financeApi.post(
                '/api/schools/${widget.customSchoolId}/finance/transactions/${item.serverId}/resolve-variance',
                body: {'outcome': apiOutcome, 'note': note},
              ),
              successMessage: outcome == _VarianceOutcome.accept
                  ? '${item.expenseId} variance accepted.'
                  : '${item.expenseId} escalated to Financial Follow-ups.',
            );
            if (saved && context.mounted) Navigator.pop(context);
          },
          child: Form(
            key: formKey,
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
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _FormSection(
                    title: 'Previous review activity',
                    child: Column(
                      children: [
                        for (final entry in history)
                          _ActionTile(
                            icon: entry.icon,
                            iconColor: entry.color,
                            title: entry.label,
                            subtitle:
                                '${entry.author} · ${_dateTime(entry.createdAt)}\n${entry.note}',
                          ),
                      ],
                    ),
                  ),
                ],
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
                TextFormField(
                  controller: reviewNotes,
                  minLines: 3,
                  maxLines: 5,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Add a review note to keep the decision auditable.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Review note *',
                    hintText: 'State why this outcome is appropriate.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _varianceMessage(_RequisitionRecord requisition, double actual) {
    if (actual <= 0) return 'Enter actual spend to see variance handling.';
    final approvedAmount =
        requisition.approvedAmount ??
        (requisition.isEmergency ? requisition.requestedAmount : null);
    if (approvedAmount == null) {
      return 'Approve this requisition before recording actual spend.';
    }
    final difference = actual - approvedAmount;
    if (difference.abs() <= 0.005) {
      return 'Actual matches the approved amount. It will be recorded normally.';
    }
    final percentage = approvedAmount <= 0
        ? 0.0
        : difference.abs() * 100 / approvedAmount;
    final tolerance = _settings.varianceTolerancePercent;
    if (percentage <= tolerance) {
      return 'Difference of ${_money(difference.abs())} (${percentage.toStringAsFixed(1)}%) is within the $tolerance% tolerance. It will be recorded normally.';
    }
    return 'Difference of ${_money(difference.abs())} (${percentage.toStringAsFixed(1)}%) exceeds the $tolerance% tolerance and will be sent for variance review.';
  }

  Color _varianceColor(_RequisitionRecord requisition, double actual) {
    if (actual <= 0) return AppColors.blue;
    final approvedAmount =
        requisition.approvedAmount ??
        (requisition.isEmergency ? requisition.requestedAmount : null);
    if (approvedAmount == null) return AppColors.amber;
    final difference = (actual - approvedAmount).abs();
    if (difference <= 0.005) return AppColors.green;
    final percentage = approvedAmount <= 0
        ? 0.0
        : difference * 100 / approvedAmount;
    return percentage > _settings.varianceTolerancePercent
        ? AppColors.red
        : AppColors.amber;
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
    required this.requisitionReference,
    required this.onRefund,
    required this.onReverse,
    required this.canReverse,
    required this.onView,
    required this.onPrint,
    required this.onDownload,
    this.allowFinancialActions = true,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
  });

  final List<_ExpenseRecord> expenses;
  final String? Function(String?) requisitionReference;
  final ValueChanged<_ExpenseRecord> onRefund;
  final ValueChanged<_ExpenseRecord> onReverse;
  final bool Function(_ExpenseRecord) canReverse;
  final ValueChanged<_ExpenseRecord> onView;
  final ValueChanged<_ExpenseRecord> onPrint;
  final ValueChanged<_ExpenseRecord> onDownload;
  final bool allowFinancialActions;
  final _ExpenseSortField sortField;
  final bool sortAscending;
  final ValueChanged<_ExpenseSortField> onSort;

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
        'Funding / channel',
        'Requisition',
        'Amount',
        'Status',
        'Receipt',
        'Date',
        'Actions',
      ],
      customHeaders: {
        0: _ExpenseSortHeader(
          label: 'Expense',
          field: _ExpenseSortField.expense,
          activeField: sortField,
          ascending: sortAscending,
          onSort: onSort,
        ),
        3: _ExpenseSortHeader(
          label: 'Amount',
          field: _ExpenseSortField.amount,
          activeField: sortField,
          ascending: sortAscending,
          onSort: onSort,
        ),
        4: _ExpenseSortHeader(
          label: 'Status',
          field: _ExpenseSortField.status,
          activeField: sortField,
          ascending: sortAscending,
          onSort: onSort,
        ),
        6: _ExpenseSortHeader(
          label: 'Date',
          field: _ExpenseSortField.date,
          activeField: sortField,
          ascending: sortAscending,
          onSort: onSort,
        ),
      },
      rows: expenses
          .map(
            (item) => [
              _MainCell(
                title: item.description,
                subtitle: '${item.expenseId} · ${item.payee}',
                onTap: () => onView(item),
              ),
              _MainCell(title: item.source.label, subtitle: item.channel.label),
              Text(requisitionReference(item.requisitionId) ?? 'Not linked'),
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
                    case _ExpenseAction.reverse:
                      onReverse(item);
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
                  if (allowFinancialActions &&
                      item.amount > 0 &&
                      item.refundableAmount > 0)
                    const PopupMenuItem(
                      value: _ExpenseAction.refund,
                      child: ListTile(
                        leading: Icon(Icons.undo_rounded),
                        title: Text('Record refund'),
                      ),
                    ),
                  if (allowFinancialActions && canReverse(item))
                    const PopupMenuItem(
                      value: _ExpenseAction.reverse,
                      child: ListTile(
                        leading: Icon(Icons.cancel_presentation_outlined),
                        title: Text('Request reversal'),
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
        'Funding',
        'Requested / approved',
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
              Text(item.fundingSource.label),
              _MainCell(
                title: _money(item.requestedAmount),
                subtitle: item.approvedAmount == null
                    ? item.status == _RequisitionStatus.draft
                          ? 'Not submitted'
                          : item.isEmergency
                          ? 'Verbal approval recorded'
                          : 'Awaiting approval'
                    : 'Approved ${_money(item.approvedAmount!)}',
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
              Text(_requisitionExpiryLabel(item.expiresAt)),
              SizedBox(
                width: 104,
                child: OutlinedButton.icon(
                  onPressed: () => onOpen(item),
                  icon: const Icon(Icons.open_in_new_outlined, size: 16),
                  label: const Text('Open'),
                ),
              ),
            ],
          )
          .toList(),
    );
  }
}

class _ExpenseSortHeader extends StatelessWidget {
  const _ExpenseSortHeader({
    required this.label,
    required this.field,
    required this.activeField,
    required this.ascending,
    required this.onSort,
  });

  final String label;
  final _ExpenseSortField field;
  final _ExpenseSortField activeField;
  final bool ascending;
  final ValueChanged<_ExpenseSortField> onSort;

  @override
  Widget build(BuildContext context) {
    final active = field == activeField;
    return InkWell(
      key: ValueKey('expense-sort-${field.name}'),
      onTap: () => onSort(field),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: active ? AppColors.green : AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active
                  ? ascending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded
                  : Icons.unfold_more_rounded,
              size: 14,
              color: active ? AppColors.green : AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({
    required this.columns,
    required this.rows,
    this.customHeaders = const {},
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final Map<int, Widget> customHeaders;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 980
            ? 980.0
            : constraints.maxWidth;
        return SingleChildScrollView(
          key: const ValueKey('finance-table-horizontal-scroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                columnWidths: {
                  for (var i = 0; i < columns.length; i++)
                    i: i == 0
                        ? const FlexColumnWidth(2.4)
                        : const FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF8FAFA)),
                    children: columns.indexed
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.all(14),
                            child:
                                customHeaders[entry.$1] ??
                                Text(
                                  entry.$2.toUpperCase(),
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
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      children: row
                          .map(
                            (cell) => Padding(
                              padding: const EdgeInsets.all(14),
                              child: cell,
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
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
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (constraints.maxWidth < 560) ...[
                  heading,
                  if (trailing != null) ...[
                    const SizedBox(height: 12),
                    trailing!,
                  ],
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      if (trailing != null) trailing!,
                    ],
                  ),
                const SizedBox(height: 16),
                child,
              ],
            );
          },
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
    this.badgeCount = 0,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                key: ValueKey('expense-tab-badge-$label'),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
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
        isExpanded: true,
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
  const _MainCell({
    super.key,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

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
    this.keyPrefix,
    required this.page,
    required this.totalItems,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final String? keyPrefix;
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
          key: keyPrefix == null ? null : ValueKey('$keyPrefix-previous'),
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          key: keyPrefix == null ? null : ValueKey('$keyPrefix-next'),
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

class _PettyCashControlCard extends StatelessWidget {
  const _PettyCashControlCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
    required this.color,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;
  final Color color;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .05),
        border: Border.all(color: color.withValues(alpha: .20)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: Text(actionLabel),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: .4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _money(amount),
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
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
    this.showSecondaryAction = true,
    this.persistentActions = const [],
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final bool showSecondaryAction;
  final List<Widget> persistentActions;
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
                children: [
                  for (
                    var index = 0;
                    index < persistentActions.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(width: 8),
                    persistentActions[index],
                  ],
                  const Spacer(),
                  if (showSecondaryAction) ...[
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(secondaryLabel),
                    ),
                    const SizedBox(width: 10),
                  ],
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
          const SizedBox(width: 16),
          Text(
            value,
            textAlign: TextAlign.right,
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
    required this.cycleId,
    required this.floatApprovedAmount,
    required this.floatCeiling,
    required this.floatThreshold,
    required this.autoApprovePettyCash,
    required this.autoApprovalLimit,
    required this.captureTransactionFees,
    required this.selfDisburse,
    required this.varianceTolerancePercent,
    required this.requisitionExpiryDays,
    required this.momoWalletNumber,
  });

  final int? cycleId;
  final double floatApprovedAmount;
  final double floatCeiling;
  final double floatThreshold;
  final bool autoApprovePettyCash;
  final double autoApprovalLimit;
  final bool captureTransactionFees;
  final bool selfDisburse;
  final int varianceTolerancePercent;
  final int requisitionExpiryDays;
  final String momoWalletNumber;

  factory _SchoolExpenseSettings.empty() => const _SchoolExpenseSettings(
    cycleId: null,
    floatApprovedAmount: 0,
    floatCeiling: 0,
    floatThreshold: 0,
    autoApprovePettyCash: false,
    autoApprovalLimit: 0,
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
    this.reversal,
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
  _ExpenseReversal? reversal;

  double get netAmount => amount + momoFee;
  double get accountingAmount =>
      status == _ExpenseStatus.reversed ? 0 : netAmount;
  double get varianceAmount =>
      (approvedAmount == null ? 0 : amount - approvedAmount!);
  String get varianceLabel {
    if (approvedAmount == null) return 'Not applicable';
    if (varianceAmount.abs() <= 0.005) return 'No difference';
    return '${varianceAmount > 0 ? '+' : '-'}${_money(varianceAmount.abs())}';
  }

  double get refundableAmount =>
      amount <= 0 ||
          status == _ExpenseStatus.reversed ||
          status == _ExpenseStatus.pendingReversal
      ? 0
      : (amount - refundedAmount).clamp(0, amount);
}

class _ExpenseReversal {
  const _ExpenseReversal({
    required this.serverId,
    required this.reference,
    required this.parentTransactionId,
    required this.amount,
    required this.reasonCode,
    required this.notes,
    required this.status,
    required this.requester,
    required this.requesterUserId,
    required this.approver,
    required this.approverUserId,
    required this.decidedBy,
    required this.requestedAt,
    required this.decidedAt,
  });

  final int? serverId;
  final String reference;
  final int parentTransactionId;
  final double amount;
  final String reasonCode;
  final String notes;
  final _ExpenseReversalStatus status;
  final String requester;
  final int? requesterUserId;
  final String approver;
  final int? approverUserId;
  final String? decidedBy;
  final DateTime requestedAt;
  final DateTime? decidedAt;

  String get reasonLabel => switch (reasonCode.toUpperCase()) {
    'DUPLICATE_ENTRY' => 'Duplicate entry',
    'NO_PAYMENT_MADE' => 'No payment was made',
    'WRONG_AMOUNT' => 'Wrong amount recorded',
    'WRONG_PAYMENT_SOURCE' => 'Wrong payment source',
    _ => 'Other recording error',
  };
}

class _RequisitionRecord {
  _RequisitionRecord({
    this.serverId,
    required this.id,
    required this.title,
    required this.category,
    required this.payee,
    required this.requestedBy,
    this.requesterUserId,
    this.approver,
    this.approverUserId,
    required this.requestedAmount,
    this.approvedAmount,
    required this.requestedAt,
    this.approvedAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.status,
    required this.fundingSource,
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
  final int? requesterUserId;
  final String? approver;
  final int? approverUserId;
  final double requestedAmount;
  double? approvedAmount;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  _RequisitionStatus status;
  final _FundingSource fundingSource;
  final String notes;
  final bool isEmergency;
  final String? verbalApprover;

  DateTime get decisionDate => approvedAt ?? updatedAt;
  String get approvalDecisionLabel =>
      status == _RequisitionStatus.rejected ? 'Declined' : 'Approved';
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
    this.approvedAt,
    required this.updatedAt,
    this.confirmedAt,
    this.disbursedAt,
    this.actualReceived,
    this.transactions = const [],
    required this.requester,
    this.requesterUserId,
    this.approver,
    this.approverUserId,
    this.disburser,
    this.disburserUserId,
    this.receiver,
    this.receiverUserId,
    this.cashAmount,
    this.momoAmount,
    this.momoWalletNumber,
  });

  final int? serverId;
  final String requestId;
  final double requestedAmount;
  double? approvedAmount;
  final DateTime requestedAt;
  final int expensesCount;
  _TopUpStatus status;
  DateTime? approvedAt;
  final DateTime updatedAt;
  DateTime? confirmedAt;
  final DateTime? disbursedAt;
  double? actualReceived;
  final List<_TopUpTransaction> transactions;
  final String requester;
  final int? requesterUserId;
  final String? approver;
  final int? approverUserId;
  final String? disburser;
  final int? disburserUserId;
  final String? receiver;
  final int? receiverUserId;
  final double? cashAmount;
  final double? momoAmount;
  final String? momoWalletNumber;

  DateTime get decisionDate => approvedAt ?? updatedAt;
  String get approvalDecisionLabel =>
      status == _TopUpStatus.declined ? 'Declined' : 'Approved';
}

class _FinanceActor {
  const _FinanceActor({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
  });
  final int id;
  final String name;
  final String username;
  final String role;
}

class _FinanceHistoryEntry {
  const _FinanceHistoryEntry({
    required this.eventType,
    required this.author,
    required this.note,
    required this.amount,
    required this.createdAt,
  });

  final String eventType;
  final String author;
  final String note;
  final double? amount;
  final DateTime createdAt;

  String get label => switch (eventType.toUpperCase()) {
    'CREATED' => 'Request created',
    'SETTINGS_CREATED' => 'Settings created',
    'SETTINGS_UPDATED' => 'Settings updated',
    'SUBMITTED' => 'Submitted for approval',
    'APPROVED' => 'Approved',
    'AUTO_APPROVED' => 'Automatically approved',
    'CHANGES_REQUESTED' => 'Changes requested',
    'EDIT_STARTED' => 'Returned to draft for editing',
    'DRAFT_UPDATED' => 'Draft updated',
    'VARIANCE_ACCEPTED' => 'Variance accepted',
    'VARIANCE_CORRECTION_REQUESTED' => 'Correction requested',
    'VARIANCE_ESCALATED' => 'Escalated to follow-up',
    'DECLINED' => 'Declined',
    'APPROVAL_REVOKED' => 'Approval revoked',
    'CANCELLED' => 'Cancelled by requester',
    _ => 'Note added',
  };

  IconData get icon => switch (eventType.toUpperCase()) {
    'APPROVED' || 'AUTO_APPROVED' => Icons.check_circle_outline,
    'SETTINGS_CREATED' || 'SETTINGS_UPDATED' => Icons.settings_outlined,
    'VARIANCE_ACCEPTED' => Icons.check_circle_outline,
    'VARIANCE_CORRECTION_REQUESTED' => Icons.edit_note_outlined,
    'VARIANCE_ESCALATED' => Icons.outbound_outlined,
    'DECLINED' || 'APPROVAL_REVOKED' || 'CANCELLED' => Icons.cancel_outlined,
    'CHANGES_REQUESTED' ||
    'EDIT_STARTED' ||
    'DRAFT_UPDATED' => Icons.edit_note_outlined,
    'SUBMITTED' => Icons.outbox_outlined,
    _ => Icons.history_outlined,
  };

  Color get color => switch (eventType.toUpperCase()) {
    'APPROVED' || 'AUTO_APPROVED' || 'VARIANCE_ACCEPTED' => AppColors.green,
    'VARIANCE_CORRECTION_REQUESTED' => AppColors.amber,
    'VARIANCE_ESCALATED' => AppColors.red,
    'SETTINGS_CREATED' || 'SETTINGS_UPDATED' => AppColors.blue,
    'DECLINED' || 'APPROVAL_REVOKED' || 'CANCELLED' => AppColors.red,
    'CHANGES_REQUESTED' => AppColors.amber,
    'EDIT_STARTED' || 'DRAFT_UPDATED' => AppColors.blue,
    _ => AppColors.blue,
  };
}

class _TopUpEvent {
  const _TopUpEvent({
    required this.type,
    required this.actor,
    required this.at,
    this.note,
    this.cash,
    this.momo,
    this.wallet,
    this.reference,
  });
  final String type;
  final String actor;
  final DateTime at;
  final String? note;
  final double? cash;
  final double? momo;
  final String? wallet;
  final String? reference;
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
    this.serverId,
    required this.reference,
    required this.type,
    required this.relatedReference,
    this.relatedTransactionId,
    required this.owner,
    required this.amount,
    required this.createdAt,
    required this.summary,
    required this.status,
    this.dueDate,
    List<_FollowUpNote>? notes,
  }) : notes = notes ?? [];

  final int? serverId;
  final String reference;
  final _FollowUpType type;
  final String relatedReference;
  final int? relatedTransactionId;
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
  requisitions('Requisitions'),
  myExpenses('My Expenses'),
  schoolExpenses('School Expenses'),
  pettyCash('Petty Cash'),
  approvals('Approvals'),
  reports('Reports');

  const _ExpenseTab(this.label);
  final String label;
}

enum _PettyCashSection {
  workspace('Float & expenses'),
  reconciliations('Reconciliations'),
  followUps('Financial follow-ups');

  const _PettyCashSection(this.label);
  final String label;
}

enum _FinanceLedgerPage { topUps, topUpDetail, transfers, reconciliationDetail }

enum _ExpenseSource {
  pettyCash('Petty cash'),
  direct('School funds');

  const _ExpenseSource(this.label);
  final String label;
}

enum _ExpenseSortField { expense, amount, status, date }

enum _FundingSource {
  schoolFunds('School funds', 'SCHOOL_FUNDS'),
  pettyCash('Petty cash', 'PETTY_CASH');

  const _FundingSource(this.label, this.apiValue);
  final String label;
  final String apiValue;

  List<_PaymentChannel> get allowedChannels => switch (this) {
    _FundingSource.schoolFunds => const [
      _PaymentChannel.bankTransfer,
      _PaymentChannel.cheque,
      _PaymentChannel.directMomo,
      _PaymentChannel.schoolCash,
    ],
    _FundingSource.pettyCash => const [
      _PaymentChannel.floatCash,
      _PaymentChannel.floatMomo,
    ],
  };
}

enum _PaymentChannel {
  floatCash('Float - Cash'),
  floatMomo('Float - MoMo'),
  schoolCash('Cash'),
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
  pendingReversal('Pending reversal', AppColors.amber),
  reversed('Reversed', AppColors.red),
  cancelled('Cancelled', AppColors.muted),
  blocked('Blocked', AppColors.red);

  const _ExpenseStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum _ExpenseReversalStatus {
  pending('Pending approval', AppColors.amber),
  approved('Approved', AppColors.green),
  declined('Declined', AppColors.red),
  cancelled('Cancelled', AppColors.muted);

  const _ExpenseReversalStatus(this.label, this.color);
  final String label;
  final Color color;
}

enum _ExpenseReversalReason {
  duplicate('DUPLICATE_ENTRY', 'Duplicate entry'),
  noPayment('NO_PAYMENT_MADE', 'No payment was made'),
  wrongAmount('WRONG_AMOUNT', 'Wrong amount recorded'),
  wrongSource('WRONG_PAYMENT_SOURCE', 'Wrong payment source'),
  other('OTHER_RECORDING_ERROR', 'Other recording error');

  const _ExpenseReversalReason(this.code, this.label);
  final String code;
  final String label;
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
  escalate(
    'Escalate to follow-up',
    'Create a Financial Follow-up for Accounts or school leadership.',
  );

  const _VarianceOutcome(this.label, this.description);
  final String label;
  final String description;
}

enum _ExpenseAction { print, download, refund, reverse }

enum _TransferAction { view, print, download }

enum _RequisitionStatus {
  draft('Draft', AppColors.blue),
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
  disputed('Problem reported', AppColors.red),
  corrected('Correction awaiting confirmation', AppColors.amber),
  cancelled('Cancelled', AppColors.muted),
  approvalRevoked('Approval revoked', AppColors.red),
  confirmed('Confirmed', AppColors.green),
  confirmedWithDiscrepancy('Confirmed with discrepancy', AppColors.red);

  const _TopUpStatus(this.label, this.color);
  final String label;
  final Color color;

  bool get isHistorical =>
      this == confirmed ||
      this == confirmedWithDiscrepancy ||
      this == declined ||
      this == cancelled ||
      this == approvalRevoked;
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
  floatOverage('Float overage'),
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

String _amountInput(double value) {
  if (value <= 0) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
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

String _dateTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'pm' : 'am';
  return '${_date(date)} · $hour:$minute $period';
}

bool _hasUsableDate(DateTime date) => date.millisecondsSinceEpoch > 0;

String _requisitionExpiryLabel(DateTime expiresAt) {
  if (!_hasUsableDate(expiresAt)) return 'Not set';
  final remaining = expiresAt.difference(DateTime.now());
  if (remaining <= Duration.zero) return '${_date(expiresAt)} · Expired';
  final days = (remaining.inMinutes / Duration.minutesPerDay).ceil();
  return '${_date(expiresAt)} · $days ${days == 1 ? 'day' : 'days'} left';
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

List<_FollowUpNote> _financeNotes(dynamic response) {
  return _pageContent(response).map((value) {
    final item = _asMap(value);
    return _FollowUpNote(
      author: _asText(item['author'], fallback: 'System'),
      createdAt: _asDate(item['createdAt']),
      text: _asText(item['note']),
    );
  }).toList();
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
  if (status == 'REVERSED') return _ExpenseStatus.reversed;
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

_ExpenseReversalStatus _expenseReversalStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status == 'COMPLETE' || status == 'APPROVED') {
    return _ExpenseReversalStatus.approved;
  }
  if (status == 'DECLINED' || status == 'REJECTED') {
    return _ExpenseReversalStatus.declined;
  }
  if (status == 'CANCELLED') return _ExpenseReversalStatus.cancelled;
  return _ExpenseReversalStatus.pending;
}

_PaymentChannel _paymentChannel(dynamic value, {String sourcePocket = ''}) {
  final channel = _asText(value).toUpperCase();
  if (channel == 'SCHOOL_CASH') return _PaymentChannel.schoolCash;
  if (channel.contains('CASH')) return _PaymentChannel.floatCash;
  if (channel.contains('MOMO') &&
      (channel.contains('FLOAT') || sourcePocket.contains('MOMO'))) {
    return _PaymentChannel.floatMomo;
  }
  if (channel.contains('MOMO')) return _PaymentChannel.directMomo;
  if (channel.contains('CHEQUE')) return _PaymentChannel.cheque;
  return _PaymentChannel.bankTransfer;
}

_FundingSource _fundingSource(dynamic value) {
  final source = _asText(value).toUpperCase();
  return source.contains('PETTY')
      ? _FundingSource.pettyCash
      : _FundingSource.schoolFunds;
}

_RequisitionStatus _requisitionStatus(dynamic value) {
  final status = _asText(value).toUpperCase();
  if (status.contains('DRAFT')) return _RequisitionStatus.draft;
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
  if (status.contains('DISPUT')) return _TopUpStatus.disputed;
  if (status.contains('CORRECTION')) return _TopUpStatus.corrected;
  if (status.contains('CANCEL')) return _TopUpStatus.cancelled;
  if (status.contains('REVOK')) return _TopUpStatus.approvalRevoked;
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
  if (type.contains('OVERAGE')) return _FollowUpType.floatOverage;
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

String _reconciliationResolutionLabel(String value) {
  return switch (value.trim().toUpperCase()) {
    'RECOVER_FROM_STAFF' => 'Recover from staff / custodian',
    'WRITE_OFF' => 'Approved write-off',
    'CORRECT_ENTRY' => 'Correct the recorded entry',
    'EXCESS_RETURN' => 'Return excess funds',
    _ => value,
  };
}
