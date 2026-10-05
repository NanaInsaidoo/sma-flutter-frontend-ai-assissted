import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/payroll_api_client.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({
    super.key,
    required this.schoolId,
    required this.accessToken,
    this.onRefreshAccessToken,
    this.api,
  });

  final String schoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;
  final PayrollApiClient? api;

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  late final PayrollApiClient _api;
  List<PayrollStaffRecord> _staff = const [];
  PayrollStaffRecord? _selected;
  PayrollConfiguration? _configuration;
  bool _loading = true;
  bool _canEdit = false;
  bool _loadingConfiguration = false;
  bool _saving = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _api =
        widget.api ??
        PayrollApiClient(
          schoolId: widget.schoolId,
          accessToken: widget.accessToken,
          onRefreshAccessToken: widget.onRefreshAccessToken,
        );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_api.getAccess(), _api.getStaff()]);
      final access = results[0] as PayrollAccess;
      if (!access.canView) {
        throw const PayrollApiException(
          'Your account has not been authorised to view payroll.',
        );
      }
      final staff = results[1] as List<PayrollStaffRecord>;
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _canEdit = access.canEdit;
        _loading = false;
      });
    } on PayrollApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  List<PayrollStaffRecord> get _visibleStaff {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _staff;
    return _staff
        .where(
          (staff) => [
            staff.name,
            staff.jobTitle,
            staff.department,
            staff.payrollStatus,
          ].join(' ').toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _select(PayrollStaffRecord staff) async {
    setState(() {
      _selected = staff;
      _configuration = null;
      _loadingConfiguration = true;
      _error = null;
    });
    try {
      final configuration = await _api.getConfiguration(staff.staffId);
      if (!mounted || _selected?.staffId != staff.staffId) return;
      setState(() {
        _configuration = configuration;
        _loadingConfiguration = false;
      });
    } on PayrollApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingConfiguration = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save(Map<String, dynamic> body) async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _api.saveConfiguration(
        staffId: selected.staffId,
        body: body,
      );
      final staff = await _api.getStaff();
      if (!mounted) return;
      setState(() {
        _configuration = saved;
        _staff = staff;
        _selected = staff.firstWhere(
          (item) => item.staffId == selected.staffId,
          orElse: () => selected,
        );
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.payrollStatus == 'ACTIVE'
                ? 'Payroll setup activated.'
                : 'Payroll draft saved.',
          ),
        ),
      );
    } on PayrollApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  Future<void> _savePaymentAccount(Map<String, dynamic> body) async {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.savePaymentAccount(staffId: selected.staffId, body: body);
      final results = await Future.wait([
        _api.getConfiguration(selected.staffId),
        _api.getStaff(),
      ]);
      if (!mounted) return;
      final configuration = results[0] as PayrollConfiguration;
      final staff = results[1] as List<PayrollStaffRecord>;
      setState(() {
        _configuration = configuration;
        _staff = staff;
        _selected = staff.firstWhere(
          (item) => item.staffId == selected.staffId,
          orElse: () => selected,
        );
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment account saved securely.')),
      );
    } on PayrollApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _staff.isEmpty) {
      return _PayrollAccessError(message: _error!, onRetry: _load);
    }
    final configured = _staff
        .where((staff) => staff.payrollStatus == 'ACTIVE')
        .length;
    final drafts = _staff
        .where((staff) => staff.payrollStatus == 'DRAFT')
        .length;
    final missing = _staff.length - configured - drafts;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 1050;
        final directory = _directory(configured, drafts, missing);
        final detail = _detail();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payroll',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set up staff salary, pension, tax, deductions, and payment readiness separately from onboarding.',
                style: TextStyle(color: AppColors.muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: _error!),
              ],
              const SizedBox(height: 18),
              if (narrow) ...[
                directory,
                const SizedBox(height: 18),
                detail,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 390, child: directory),
                    const SizedBox(width: 18),
                    Expanded(child: detail),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _directory(int configured, int drafts, int missing) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _Metric('Active', '$configured', AppColors.green)),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric('Draft', '$drafts', const Color(0xFFD58B24)),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Metric('Not set', '$missing', AppColors.muted)),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  key: const ValueKey('payroll-staff-search'),
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search staff',
                  ),
                ),
                const SizedBox(height: 12),
                if (_visibleStaff.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No matching staff members.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  ..._visibleStaff.map(
                    (staff) => _StaffTile(
                      staff: staff,
                      selected: _selected?.staffId == staff.staffId,
                      onTap: () => _select(staff),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _detail() {
    if (_selected == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.payments_outlined, size: 44, color: AppColors.muted),
              SizedBox(height: 12),
              Text(
                'Select a staff member',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'Their payroll setup and masked payment account will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    if (_loadingConfiguration || _configuration == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(60),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return _PayrollSetupForm(
      key: ValueKey('payroll-setup-${_selected!.staffId}'),
      staff: _selected!,
      initial: _configuration!,
      saving: _saving,
      canEdit: _canEdit,
      onSave: _save,
      onSavePaymentAccount: _savePaymentAccount,
    );
  }
}

class _PayrollSetupForm extends StatefulWidget {
  const _PayrollSetupForm({
    super.key,
    required this.staff,
    required this.initial,
    required this.saving,
    required this.canEdit,
    required this.onSave,
    required this.onSavePaymentAccount,
  });

  final PayrollStaffRecord staff;
  final PayrollConfiguration initial;
  final bool saving;
  final bool canEdit;
  final ValueChanged<Map<String, dynamic>> onSave;
  final ValueChanged<Map<String, dynamic>> onSavePaymentAccount;

  @override
  State<_PayrollSetupForm> createState() => _PayrollSetupFormState();
}

class _PayrollSetupFormState extends State<_PayrollSetupForm> {
  late final Map<String, TextEditingController> _fields;
  late String _payType;
  late String _ssnitStatus;
  late bool _houseTaxable;
  late bool _transportTaxable;
  late bool _otherTaxable;
  String? _error;

  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    _payType = value.payType.isEmpty ? 'PERMANENT' : value.payType;
    _ssnitStatus = value.ssnitStatus.isEmpty
        ? 'CONTRIBUTING'
        : value.ssnitStatus;
    _houseTaxable = value.houseAllowanceTaxable;
    _transportTaxable = value.transportAllowanceTaxable;
    _otherTaxable = value.otherAllowancesTaxable;
    _fields = {
      'payGrade': TextEditingController(text: value.payGrade),
      'tier2Provider': TextEditingController(text: value.tier2Provider),
      'effectiveDate': TextEditingController(text: value.effectiveDate),
      'ssnitNumber': TextEditingController(text: value.ssnitNumber),
      'tinNumber': TextEditingController(text: value.tinNumber),
      'basicPay': _moneyController(value.basicPay),
      'houseAllowance': _moneyController(value.houseAllowance),
      'transportAllowance': _moneyController(value.transportAllowance),
      'otherAllowances': _moneyController(value.otherAllowances),
      'unionName': TextEditingController(text: value.unionName),
      'unionDues': _moneyController(value.unionDues),
      'tier3Percentage': _moneyController(value.tier3Percentage),
      'otherDeductions': _moneyController(value.otherDeductions),
      'taxRelief': _moneyController(value.taxRelief),
    };
    for (final controller in _fields.values) {
      controller.addListener(_recalculate);
    }
  }

  TextEditingController _moneyController(double value) =>
      TextEditingController(text: value == 0 ? '' : value.toStringAsFixed(2));

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller
        ..removeListener(_recalculate)
        ..dispose();
    }
    super.dispose();
  }

  void _recalculate() => setState(() {});

  double _number(String key) =>
      double.tryParse(_fields[key]!.text.trim().replaceAll(',', '')) ?? 0;

  PayrollEstimate get _estimate => calculatePayrollEstimate(
    basicPay: _number('basicPay'),
    houseAllowance: _number('houseAllowance'),
    transportAllowance: _number('transportAllowance'),
    otherAllowances: _number('otherAllowances'),
    houseTaxable: _houseTaxable,
    transportTaxable: _transportTaxable,
    otherTaxable: _otherTaxable,
    ssnitContributing: _ssnitStatus == 'CONTRIBUTING',
    tier3Percentage: _number('tier3Percentage'),
    taxRelief: _number('taxRelief'),
    unionDues: _number('unionDues'),
    otherDeductions: _number('otherDeductions'),
  );

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_fields['effectiveDate']!.text);
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (date == null) return;
    _fields['effectiveDate']!.text =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _submit(String status) {
    if (_number('basicPay') <= 0) {
      setState(() => _error = 'Enter a basic salary greater than zero.');
      return;
    }
    if (status == 'ACTIVE' && _fields['effectiveDate']!.text.isEmpty) {
      setState(() => _error = 'Choose an effective date before activation.');
      return;
    }
    if (status == 'ACTIVE' && widget.initial.paymentAccountLabel.isEmpty) {
      setState(
        () => _error =
            'Add a bank or Mobile Money account before activating payroll.',
      );
      return;
    }
    if (_number('tier3Percentage') > 16.5) {
      setState(
        () => _error = 'Tier 3 voluntary contribution cannot exceed 16.5%.',
      );
      return;
    }
    setState(() => _error = null);
    widget.onSave({
      'payrollStatus': status,
      'payType': _payType,
      'payGrade': _fields['payGrade']!.text.trim(),
      'tier2Provider': _fields['tier2Provider']!.text.trim(),
      'effectiveDate': _fields['effectiveDate']!.text.trim().isEmpty
          ? null
          : _fields['effectiveDate']!.text.trim(),
      'ssnitStatus': _ssnitStatus,
      'ssnitNumber': _fields['ssnitNumber']!.text.trim(),
      'tinNumber': _fields['tinNumber']!.text.trim(),
      'basicPay': _number('basicPay'),
      'houseAllowance': _number('houseAllowance'),
      'transportAllowance': _number('transportAllowance'),
      'otherAllowances': _number('otherAllowances'),
      'houseAllowanceTaxable': _houseTaxable,
      'transportAllowanceTaxable': _transportTaxable,
      'otherAllowancesTaxable': _otherTaxable,
      'unionName': _fields['unionName']!.text.trim(),
      'unionDues': _number('unionDues'),
      'tier3Percentage': _number('tier3Percentage'),
      'otherDeductions': _number('otherDeductions'),
      'taxRelief': _number('taxRelief'),
    });
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.staff.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.staff.jobTitle} · ${widget.staff.department}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _StatusPill(widget.initial.payrollStatus),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Payment readiness',
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.initial.paymentAccountLabel.isEmpty
                          ? 'No payment account recorded. Save a draft or add the account before activation.'
                          : widget.initial.paymentAccountLabel,
                      style: TextStyle(
                        color: widget.initial.paymentAccountLabel.isEmpty
                            ? AppColors.muted
                            : AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.canEdit)
                    OutlinedButton.icon(
                      key: const ValueKey('payroll-edit-payment-account'),
                      onPressed: widget.saving
                          ? null
                          : () async {
                              final value =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    builder: (context) =>
                                        const _PaymentAccountDialog(),
                                  );
                              if (value != null) {
                                widget.onSavePaymentAccount(value);
                              }
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(
                        widget.initial.paymentAccountLabel.isEmpty
                            ? 'Add account'
                            : 'Change',
                      ),
                    ),
                ],
              ),
            ),
            _Section(
              title: 'Tax and pension IDs',
              child: _FormGrid(
                children: [
                  DropdownButtonFormField<String>(
                    value: _ssnitStatus,
                    decoration: const InputDecoration(
                      labelText: 'SSNIT status',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CONTRIBUTING',
                        child: Text('Contributing'),
                      ),
                      DropdownMenuItem(value: 'EXEMPT', child: Text('Exempt')),
                    ],
                    onChanged: (value) => setState(() => _ssnitStatus = value!),
                  ),
                  _field('ssnitNumber', 'SSNIT number'),
                  _field('tinNumber', 'Ghana Card / TIN'),
                  DropdownButtonFormField<String>(
                    value: _payType,
                    decoration: const InputDecoration(labelText: 'Pay type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'PERMANENT',
                        child: Text('Permanent'),
                      ),
                      DropdownMenuItem(
                        value: 'CONTRACT',
                        child: Text('Contract'),
                      ),
                      DropdownMenuItem(
                        value: 'PART_TIME',
                        child: Text('Part-time'),
                      ),
                      DropdownMenuItem(value: 'CASUAL', child: Text('Casual')),
                    ],
                    onChanged: (value) => setState(() => _payType = value!),
                  ),
                  _field('payGrade', 'Pay grade / scale'),
                  _field('tier2Provider', 'Tier 2 provider'),
                  TextFormField(
                    key: const ValueKey('payroll-effective-date'),
                    controller: _fields['effectiveDate'],
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Effective date',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Earnings (GH¢ / month)',
              child: Column(
                children: [
                  _FormGrid(
                    children: [
                      _field(
                        'basicPay',
                        'Basic pay *',
                        money: true,
                        key: const ValueKey('payroll-basic-pay'),
                      ),
                      _AllowanceField(
                        field: _field(
                          'houseAllowance',
                          'House allowance',
                          money: true,
                        ),
                        taxable: _houseTaxable,
                        onChanged: (value) =>
                            setState(() => _houseTaxable = value),
                      ),
                      _AllowanceField(
                        field: _field(
                          'transportAllowance',
                          'Transport allowance',
                          money: true,
                        ),
                        taxable: _transportTaxable,
                        onChanged: (value) =>
                            setState(() => _transportTaxable = value),
                      ),
                      _AllowanceField(
                        field: _field(
                          'otherAllowances',
                          'Other allowances',
                          money: true,
                        ),
                        taxable: _otherTaxable,
                        onChanged: (value) =>
                            setState(() => _otherTaxable = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ReadOnlyAmount(
                    'Gross salary',
                    estimate.gross,
                    key: const ValueKey('payroll-gross-salary'),
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Deductions and reliefs',
              child: _FormGrid(
                children: [
                  _field('unionName', 'Union'),
                  _field('unionDues', 'Union dues', money: true),
                  _field(
                    'tier3Percentage',
                    'Tier 3 voluntary (%)',
                    money: true,
                  ),
                  _field('otherDeductions', 'Other deductions', money: true),
                  _field('taxRelief', 'Monthly tax relief', money: true),
                ],
              ),
            ),
            _PayrollSummary(estimate: estimate),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: _error!),
            ],
            const SizedBox(height: 18),
            if (!widget.canEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'You have view-only payroll access. Ask an authorised payroll manager to make changes.',
                  style: TextStyle(color: AppColors.green),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('payroll-save-draft'),
                    onPressed: widget.saving ? null : () => _submit('DRAFT'),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save draft'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('payroll-activate'),
                    onPressed: widget.saving ? null : () => _submit('ACTIVE'),
                    icon: widget.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('Activate payroll'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(String name, String label, {bool money = false, Key? key}) =>
      TextFormField(
        key: key,
        controller: _fields[name],
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
      );
}

class _PaymentAccountDialog extends StatefulWidget {
  const _PaymentAccountDialog();

  @override
  State<_PaymentAccountDialog> createState() => _PaymentAccountDialogState();
}

class _PaymentAccountDialogState extends State<_PaymentAccountDialog> {
  String _method = 'BANK';
  final _bank = TextEditingController();
  final _branch = TextEditingController();
  final _accountName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _confirmAccountNumber = TextEditingController();
  final _network = TextEditingController();
  final _momoName = TextEditingController();
  final _momoNumber = TextEditingController();
  final _confirmMomoNumber = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _bank,
      _branch,
      _accountName,
      _accountNumber,
      _confirmAccountNumber,
      _network,
      _momoName,
      _momoNumber,
      _confirmMomoNumber,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _digits(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');

  void _save() {
    if (_method == 'BANK') {
      if (_bank.text.trim().isEmpty ||
          _accountName.text.trim().isEmpty ||
          _accountNumber.text.trim().isEmpty) {
        setState(() => _error = 'Complete the required bank details.');
        return;
      }
      if (_accountNumber.text.replaceAll(' ', '') !=
          _confirmAccountNumber.text.replaceAll(' ', '')) {
        setState(() => _error = 'The account numbers do not match.');
        return;
      }
      Navigator.pop(context, {
        'paymentMethod': 'BANK',
        'bankName': _bank.text.trim(),
        'bankBranch': _branch.text.trim(),
        'accountName': _accountName.text.trim(),
        'accountNumber': _accountNumber.text.trim(),
      });
      return;
    }
    if (_network.text.trim().isEmpty ||
        _momoName.text.trim().isEmpty ||
        _momoNumber.text.trim().isEmpty) {
      setState(() => _error = 'Complete the required Mobile Money details.');
      return;
    }
    if (_digits(_momoNumber.text) != _digits(_confirmMomoNumber.text)) {
      setState(() => _error = 'The Mobile Money numbers do not match.');
      return;
    }
    Navigator.pop(context, {
      'paymentMethod': 'MOBILE_MONEY',
      'mobileMoneyNetwork': _network.text.trim(),
      'mobileMoneyNumber': _digits(_momoNumber.text),
      'mobileMoneyRegisteredName': _momoName.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Salary payment account'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Existing account numbers remain masked. Enter the complete new details to replace an account.',
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'BANK',
                    label: Text('Bank account'),
                    icon: Icon(Icons.account_balance_outlined),
                  ),
                  ButtonSegment(
                    value: 'MOBILE_MONEY',
                    label: Text('Mobile Money'),
                    icon: Icon(Icons.phone_android_outlined),
                  ),
                ],
                selected: {_method},
                onSelectionChanged: (value) =>
                    setState(() => _method = value.first),
              ),
              const SizedBox(height: 16),
              if (_method == 'BANK') ...[
                TextField(
                  controller: _bank,
                  decoration: const InputDecoration(labelText: 'Bank name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _branch,
                  decoration: const InputDecoration(labelText: 'Branch'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountName,
                  decoration: const InputDecoration(
                    labelText: 'Account name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNumber,
                  decoration: const InputDecoration(
                    labelText: 'Account number *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmAccountNumber,
                  decoration: const InputDecoration(
                    labelText: 'Confirm account number *',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _network,
                  decoration: const InputDecoration(labelText: 'Network *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _momoName,
                  decoration: const InputDecoration(
                    labelText: 'Registered name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _momoNumber,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Money number *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmMomoNumber,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Mobile Money number *',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.red)),
              ],
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
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          child: const Text('Save account'),
        ),
      ],
    );
  }
}

class _FormGrid extends StatelessWidget {
  const _FormGrid({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 620
          ? constraints.maxWidth
          : (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _AllowanceField extends StatelessWidget {
  const _AllowanceField({
    required this.field,
    required this.taxable,
    required this.onChanged,
  });
  final Widget field;
  final bool taxable;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      field,
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('Taxable', style: TextStyle(fontSize: 13)),
        value: taxable,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ],
  );
}

class _PayrollSummary extends StatelessWidget {
  const _PayrollSummary({required this.estimate});
  final PayrollEstimate estimate;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.green.withValues(alpha: .5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly pay estimate',
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.green),
        ),
        const SizedBox(height: 8),
        _SummaryLine('Gross salary', estimate.gross),
        _SummaryLine('SSNIT employee', -estimate.ssnitEmployee),
        _SummaryLine('Tier 3 voluntary', -estimate.tier3),
        _SummaryLine(
          'Chargeable income',
          estimate.chargeableIncome,
          muted: true,
        ),
        _SummaryLine('Estimated PAYE', -estimate.paye),
        _SummaryLine('Other deductions', -estimate.otherDeductions),
        const Divider(),
        _SummaryLine('Estimated net pay', estimate.netPay, strong: true),
        _SummaryLine('Employer SSNIT', estimate.ssnitEmployer, muted: true),
        const SizedBox(height: 8),
        const Text(
          'This is an estimate. Statutory rates must be reviewed before each payroll period.',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(
    this.label,
    this.value, {
    this.strong = false,
    this.muted = false,
  });
  final String label;
  final double value;
  final bool strong;
  final bool muted;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: muted ? AppColors.muted : null,
              fontWeight: strong ? FontWeight.w900 : null,
            ),
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            color: value < 0 ? AppColors.red : (muted ? AppColors.muted : null),
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ReadOnlyAmount extends StatelessWidget {
  const _ReadOnlyAmount(this.label, this.value, {super.key});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.greenSoft,
    ),
    child: Text(
      _money(value),
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: AppColors.green,
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.staff,
    required this.selected,
    required this.onTap,
  });
  final PayrollStaffRecord staff;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: selected ? AppColors.greenSoft : const Color(0xFFF7F9F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _initials(staff.name),
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      staff.jobTitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(staff.payrollStatus),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final color = normalized == 'ACTIVE'
        ? AppColors.green
        : normalized == 'DRAFT'
        ? const Color(0xFFD58B24)
        : AppColors.muted;
    final label = normalized == 'NOT_CONFIGURED'
        ? 'Not set'
        : normalized
              .toLowerCase()
              .split('_')
              .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
              .join(' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.red.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message, style: const TextStyle(color: AppColors.red)),
  );
}

class _PayrollAccessError extends StatelessWidget {
  const _PayrollAccessError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color: AppColors.muted,
              ),
              const SizedBox(height: 12),
              const Text(
                'Payroll access restricted',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PayrollEstimate {
  const PayrollEstimate({
    required this.gross,
    required this.ssnitEmployee,
    required this.ssnitEmployer,
    required this.tier3,
    required this.chargeableIncome,
    required this.paye,
    required this.otherDeductions,
    required this.netPay,
  });
  final double gross;
  final double ssnitEmployee;
  final double ssnitEmployer;
  final double tier3;
  final double chargeableIncome;
  final double paye;
  final double otherDeductions;
  final double netPay;
}

PayrollEstimate calculatePayrollEstimate({
  required double basicPay,
  required double houseAllowance,
  required double transportAllowance,
  required double otherAllowances,
  required bool houseTaxable,
  required bool transportTaxable,
  required bool otherTaxable,
  required bool ssnitContributing,
  required double tier3Percentage,
  required double taxRelief,
  required double unionDues,
  required double otherDeductions,
}) {
  double safe(double value) => value < 0 ? 0 : value;
  final basic = safe(basicPay);
  final house = safe(houseAllowance);
  final transport = safe(transportAllowance);
  final other = safe(otherAllowances);
  final gross = basic + house + transport + other;
  final ssnitEmployee = ssnitContributing ? basic * .055 : 0.0;
  final ssnitEmployer = ssnitContributing ? basic * .13 : 0.0;
  final tier3 = basic * safe(tier3Percentage).clamp(0.0, 16.5).toDouble() / 100;
  final taxableAllowances =
      (houseTaxable ? house : 0) +
      (transportTaxable ? transport : 0) +
      (otherTaxable ? other : 0);
  final chargeable =
      (basic + taxableAllowances - ssnitEmployee - tier3 - safe(taxRelief))
          .clamp(0.0, double.infinity)
          .toDouble();
  final paye = _estimatedPaye(chargeable);
  final deductions = safe(unionDues) + safe(otherDeductions);
  return PayrollEstimate(
    gross: gross,
    ssnitEmployee: ssnitEmployee,
    ssnitEmployer: ssnitEmployer,
    tier3: tier3,
    chargeableIncome: chargeable,
    paye: paye,
    otherDeductions: deductions,
    netPay: gross - ssnitEmployee - tier3 - paye - deductions,
  );
}

double _estimatedPaye(double income) {
  var left = income;
  var tax = 0.0;
  const bands = <(double, double)>[
    (490, 0),
    (110, .05),
    (130, .10),
    (3166.67, .175),
    (16000, .25),
    (30520, .30),
  ];
  for (final band in bands) {
    final slice = left < band.$1 ? left : band.$1;
    tax += slice * band.$2;
    left -= slice;
    if (left <= 0) return tax;
  }
  return tax + left * .35;
}

String _money(double value) {
  final negative = value < 0;
  final absolute = value.abs().toStringAsFixed(2);
  final parts = absolute.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${negative ? '− ' : ''}GH¢ $grouped.${parts[1]}';
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'ST';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
