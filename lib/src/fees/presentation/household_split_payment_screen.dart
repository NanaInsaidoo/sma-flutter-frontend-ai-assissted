import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/fee_api_client.dart';
import '../domain/fee_models.dart';
import '../../assessments/presentation/report_pdf_download_stub.dart'
    if (dart.library.html) '../../assessments/presentation/report_pdf_download_web.dart';

class HouseholdSplitPaymentScreen extends StatefulWidget {
  const HouseholdSplitPaymentScreen({
    super.key,
    required this.householdName,
    required this.studentNames,
    this.customSchoolId,
    this.householdId,
    this.api,
  });

  final String householdName;
  final List<String> studentNames;
  final String? customSchoolId;
  final int? householdId;
  final FeeApiClient? api;

  @override
  State<HouseholdSplitPaymentScreen> createState() =>
      _HouseholdSplitPaymentScreenState();
}

class _HouseholdSplitPaymentScreenState
    extends State<HouseholdSplitPaymentScreen> {
  final _receivedController = TextEditingController(text: '1000');
  final _referenceController = TextEditingController();
  List<_StudentAllocation> _students = [];
  List<FeePaymentMethod> _methods = const [];
  HouseholdPaymentResult? _postedResult;
  int? _termId;
  int? _methodId;
  bool _loading = false;
  bool _posting = false;
  String? _error;
  int _step = 0;
  String _method = 'Cash';

  @override
  void initState() {
    super.initState();
    final names = widget.studentNames.isEmpty
        ? const ['Adwoa PdfGate', 'Kofi Test NurseryFlow']
        : widget.studentNames;
    _students = names.take(3).toList().asMap().entries.map((entry) {
      final first = entry.key == 0;
      return _StudentAllocation(
        name: entry.value,
        customStudentId: first ? 'STU-056C1F-4591' : 'STU-056C1F-2460',
        items: [
          _FeeAllocation(101 + entry.key * 2, 'Tuition fee', first ? 900 : 500),
          _FeeAllocation(
            102 + entry.key * 2,
            first ? 'Transport' : 'Books',
            first ? 250 : 150,
          ),
        ],
      );
    }).toList();
    if (_students.isNotEmpty) {
      _students.first.items.first.controller.text = '500';
      if (_students.first.items.length > 1) {
        _students.first.items[1].controller.text = '150';
      }
    }
    if (_students.length > 1) {
      _students[1].items.first.controller.text = '300';
      if (_students[1].items.length > 1) {
        _students[1].items[1].controller.text = '50';
      }
    }
    for (final student in _students) {
      for (final item in student.items) {
        item.controller.addListener(_refresh);
      }
    }
    _receivedController.addListener(_refresh);
    if (widget.api != null &&
        widget.customSchoolId != null &&
        widget.householdId != null) {
      _loadLiveData();
    }
  }

  Future<void> _loadLiveData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final term = await widget.api!.getCurrentTerm(widget.customSchoolId!);
      final results = await Future.wait([
        widget.api!.getHouseholdPaymentOptions(
          customSchoolId: widget.customSchoolId!,
          householdId: widget.householdId!,
          termId: term.id,
        ),
        widget.api!.getPaymentMethods(),
      ]);
      final options = results[0] as HouseholdPaymentOptions;
      final methods = results[1] as List<FeePaymentMethod>;
      for (final student in _students) {
        for (final item in student.items) {
          item.controller.dispose();
        }
      }
      _receivedController.clear();
      _students = options.students
          .map(
            (student) => _StudentAllocation(
              name: student.studentName,
              customStudentId: student.customStudentId,
              items: student.items
                  .where((item) => item.outstandingAmount > 0)
                  .map(
                    (item) => _FeeAllocation(
                      item.assessmentId,
                      item.feeName,
                      item.outstandingAmount,
                    ),
                  )
                  .toList(),
            ),
          )
          .where((student) => student.items.isNotEmpty)
          .toList();
      for (final student in _students) {
        for (final item in student.items) {
          item.controller.addListener(_refresh);
        }
      }
      setState(() {
        _termId = options.termId;
        _methods = methods;
        _methodId = methods.isEmpty ? null : methods.first.id;
        _method = methods.isEmpty ? 'Cash' : methods.first.method;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double get _received => _value(_receivedController);
  double get _allocated => _students.fold(
    0,
    (total, student) =>
        total +
        student.items.fold(0, (sum, item) => sum + _value(item.controller)),
  );
  double get _remaining => _received - _allocated;
  double get _householdOutstanding => _students.fold(
    0,
    (total, student) =>
        total + student.items.fold(0, (sum, item) => sum + item.outstanding),
  );
  bool get _hasInvalidAllocation => _students.any(
    (student) => student.items.any(
      (item) =>
          _value(item.controller) < 0 ||
          _value(item.controller) > item.outstanding + 0.005,
    ),
  );
  bool get _requiresReference {
    final method = _method.trim().toUpperCase();
    return !method.contains('CASH');
  }

  bool get _canReview =>
      _received > 0 &&
      _allocated > 0 &&
      _remaining.abs() < 0.005 &&
      !_hasInvalidAllocation &&
      (!_requiresReference || _referenceController.text.trim().isNotEmpty);

  void _allocateAutomatically() {
    var remaining = _received;
    for (final student in _students) {
      for (final item in student.items) {
        final amount = remaining <= 0
            ? 0.0
            : remaining.clamp(0, item.outstanding).toDouble();
        item.controller.text = amount == 0 ? '' : amount.toStringAsFixed(2);
        remaining -= amount;
      }
    }
  }

  @override
  void dispose() {
    _receivedController.dispose();
    _referenceController.dispose();
    for (final student in _students) {
      for (final item in student.items) {
        item.controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        title: Text(
          _step == 0
              ? 'Split payment among children'
              : _step == 1
              ? 'Review separate transactions'
              : 'Receipts created',
        ),
        leading: IconButton(
          onPressed: () =>
              _step == 0 ? Navigator.pop(context) : setState(() => _step -= 1),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Column(
        children: [
          _ProgressHeader(step: _step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? _LoadError(message: _error!, onRetry: _loadLiveData)
                      : _step == 0
                      ? _allocationStep()
                      : _step == 1
                      ? _reviewStep()
                      : _receiptsStep(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _allocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.householdName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter the money received, then assign it to each child’s specific fee items.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        Text(
          'Household outstanding: GH₵ ${_householdOutstanding.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _Panel(
          title: 'Payment received',
          icon: Icons.payments_outlined,
          child: Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 230,
                child: TextField(
                  key: const Key('household-payment-received'),
                  controller: _receivedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount received',
                    prefixText: 'GH₵ ',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _method,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                  ),
                  items:
                      (_methods.isEmpty
                              ? const [
                                  FeePaymentMethod(
                                    id: 1,
                                    method: 'Cash',
                                    description: '',
                                  ),
                                ]
                              : _methods)
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.method,
                              child: Text(option.method),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() {
                    _method = value ?? _method;
                    if (_methods.isNotEmpty) {
                      _methodId = _methods
                          .firstWhere((item) => item.method == _method)
                          .id;
                    }
                  }),
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _referenceController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _requiresReference
                        ? 'Reference *'
                        : 'Reference (optional)',
                    hintText: 'MoMo or bank reference',
                    helperText: _requiresReference
                        ? 'Required for non-cash payments'
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._students.map(
          (student) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _StudentAllocationCard(student: student),
          ),
        ),
        if (_students.isEmpty)
          const _Panel(
            title: 'No outstanding fees',
            icon: Icons.check_circle_outline_rounded,
            child: Text(
              'Every child in this household is fully paid for the current term.',
            ),
          ),
        _AllocationSummary(
          received: _received,
          allocated: _allocated,
          remaining: _remaining,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: _received > 0 && _students.isNotEmpty
                  ? _allocateAutomatically
                  : null,
              child: const Text('Allocate automatically'),
            ),
            OutlinedButton(
              onPressed: () {
                for (final student in _students) {
                  for (final item in student.items) {
                    item.controller.clear();
                  }
                }
              },
              child: const Text('Clear allocations'),
            ),
            FilledButton.icon(
              key: const Key('review-household-transactions'),
              onPressed: _canReview ? () => setState(() => _step = 1) : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Review transactions'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final active = _students
        .where((student) => student.total(_value) > 0)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${active.length} independent payment transactions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text(
          'Each child receives a unique receipt. The screen is only helping you split the money.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        ...active.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TransactionPreview(
              number: entry.key + 1,
              student: entry.value,
              value: _value,
            ),
          ),
        ),
        _AllocationSummary(
          received: _received,
          allocated: _allocated,
          remaining: _remaining,
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('Edit allocation'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const Key('post-household-payments'),
              onPressed: _posting ? null : _postPayments,
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(
                _posting ? 'Posting…' : 'Post ${active.length} payments',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _receiptsStep() {
    final active = _students
        .where((student) => student.total(_value) > 0)
        .toList();
    return Column(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.green,
          size: 64,
        ),
        const SizedBox(height: 12),
        Text(
          '${active.length} payments recorded',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text('Every payment has its own transaction and receipt number.'),
        const SizedBox(height: 22),
        ...active.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReceiptResult(
              receipt: _postedResult == null
                  ? 'RCP-2027-${(481 + entry.key).toString().padLeft(5, '0')}'
                  : _postedResult!.transactions[entry.key].receiptNumber,
              transaction: _postedResult == null
                  ? 'TXN-2027-${(9104 + entry.key).toString().padLeft(6, '0')}'
                  : _postedResult!.transactions[entry.key].transactionNumber,
              student: entry.value,
              total: entry.value.total(_value),
              status: _postedResult == null
                  ? 'COMPLETED'
                  : _postedResult!.transactions[entry.key].status,
              onReceipt: _postedResult == null
                  ? null
                  : () => _downloadReceipt(entry.key),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _postedResult == null ? null : _downloadAllReceipts,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print all receipts'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to household'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _postPayments() async {
    if (widget.api == null ||
        widget.customSchoolId == null ||
        widget.householdId == null) {
      setState(() => _step = 2);
      return;
    }
    if (_termId == null || _methodId == null) return;
    setState(() => _posting = true);
    try {
      final result = await widget.api!.createHouseholdSplitPayment(
        customSchoolId: widget.customSchoolId!,
        idempotencyKey:
            'household-${widget.householdId}-${DateTime.now().microsecondsSinceEpoch}',
        householdId: widget.householdId!,
        termId: _termId!,
        paymentMethodId: _methodId!,
        amountReceived: _received,
        payerName: widget.householdName.replaceFirst(' Household', ''),
        receivedBy: 'School office',
        externalReference: _referenceController.text,
        payments: _students
            .where((student) => student.total(_value) > 0)
            .map(
              (student) => {
                'customStudentId': student.customStudentId,
                'allocations': student.items
                    .where((item) => _value(item.controller) > 0)
                    .map(
                      (item) => {
                        'assessmentId': item.assessmentId,
                        'amount': _value(item.controller),
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _postedResult = result;
        _posting = false;
        _step = 2;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _downloadReceipt(int index) async {
    final transaction = _postedResult!.transactions[index];
    await _downloadReceipts([
      transaction.paymentId,
    ], '${transaction.receiptNumber}.pdf');
  }

  Future<void> _downloadAllReceipts() async {
    await _downloadReceipts(
      _postedResult!.transactions.map((item) => item.paymentId).toList(),
      'household-payment-receipts.pdf',
    );
  }

  Future<void> _downloadReceipts(List<int> paymentIds, String filename) async {
    try {
      final bytes = await widget.api!.downloadPaymentReceipts(
        customSchoolId: widget.customSchoolId!,
        paymentIds: paymentIds,
      );
      final downloaded = await downloadReportPdf(filename, bytes);
      if (!mounted) return;
      if (!downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF download is unavailable on this device.'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Allocate', 'Review', 'Receipts'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            children: labels.asMap().entries.map((entry) {
              final active = entry.key <= step;
              return Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: active
                          ? AppColors.green
                          : AppColors.border,
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.text : AppColors.muted,
                      ),
                    ),
                    if (entry.key < labels.length - 1)
                      const Expanded(child: Divider(indent: 10, endIndent: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.green),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
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
}

class _StudentAllocationCard extends StatelessWidget {
  const _StudentAllocationCard({required this.student});
  final _StudentAllocation student;

  @override
  Widget build(BuildContext context) => _Panel(
    title: student.name,
    icon: Icons.school_outlined,
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            student.customStudentId,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        ...student.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Outstanding: GH₵ ${item.outstanding.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: Key(
                      'household-allocation-${student.customStudentId}-${item.assessmentId}',
                    ),
                    controller: item.controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Allocate',
                      prefixText: 'GH₵ ',
                      errorText:
                          (double.tryParse(item.controller.text.trim()) ?? 0) >
                              item.outstanding + 0.005
                          ? 'Maximum ${item.outstanding.toStringAsFixed(2)}'
                          : (double.tryParse(item.controller.text.trim()) ??
                                    0) <
                                0
                          ? 'Cannot be negative'
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Allocated to this child',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'GH₵ ${student.total((controller) => double.tryParse(controller.text.trim()) ?? 0).toStringAsFixed(2)}',
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({
    required this.received,
    required this.allocated,
    required this.remaining,
  });
  final double received;
  final double allocated;
  final double remaining;
  String _money(double value) => 'GH₵ ${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final balanced = remaining.abs() < 0.005 && received > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: balanced ? AppColors.greenSoft : const Color(0xFFFFF7E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: balanced ? AppColors.green : AppColors.amber),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(label: 'Received', value: _money(received)),
          ),
          Expanded(
            child: _SummaryValue(label: 'Allocated', value: _money(allocated)),
          ),
          Expanded(
            child: _SummaryValue(
              label: remaining < 0 ? 'Over-allocated' : 'Remaining',
              value: _money(remaining.abs()),
              color: balanced ? AppColors.green : AppColors.red,
            ),
          ),
          Icon(
            balanced ? Icons.check_circle_outline : Icons.info_outline,
            color: balanced ? AppColors.green : AppColors.amber,
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: color ?? AppColors.text,
        ),
      ),
    ],
  );
}

class _TransactionPreview extends StatelessWidget {
  const _TransactionPreview({
    required this.number,
    required this.student,
    required this.value,
  });
  final int number;
  final _StudentAllocation student;
  final double Function(TextEditingController) value;
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Transaction $number · ${student.name}',
    icon: Icons.receipt_long_outlined,
    child: Column(
      children: [
        ...student.items
            .where((item) => value(item.controller) > 0)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    Text(
                      'GH₵ ${value(item.controller).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        const Divider(),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Receipt total',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'GH₵ ${student.total(value).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.green,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ReceiptResult extends StatelessWidget {
  const _ReceiptResult({
    required this.receipt,
    required this.transaction,
    required this.student,
    required this.total,
    required this.status,
    this.onReceipt,
  });
  final String receipt;
  final String transaction;
  final _StudentAllocation student;
  final double total;
  final String status;
  final VoidCallback? onReceipt;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.greenSoft,
            child: Icon(Icons.receipt_long, color: AppColors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '$receipt · $transaction',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  status == 'COMPLETED'
                      ? 'PAYMENT COMPLETED'
                      : 'PAYMENT ${status.replaceAll('_', ' ')} · Awaiting confirmation',
                  style: TextStyle(
                    color: status == 'COMPLETED'
                        ? AppColors.green
                        : AppColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'GH₵ ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onReceipt,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Receipt'),
          ),
        ],
      ),
    ),
  );
}

class _StudentAllocation {
  _StudentAllocation({
    required this.name,
    required this.customStudentId,
    required this.items,
  });
  final String name;
  final String customStudentId;
  final List<_FeeAllocation> items;
  double total(double Function(TextEditingController) value) =>
      items.fold(0, (sum, item) => sum + value(item.controller));
}

class _FeeAllocation {
  _FeeAllocation(this.assessmentId, this.name, this.outstanding);
  final int assessmentId;
  final String name;
  final double outstanding;
  final TextEditingController controller = TextEditingController();
}
