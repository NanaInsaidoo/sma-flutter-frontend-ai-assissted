import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../data/account_access_api_client.dart';

class AccountActivationScreen extends StatefulWidget {
  const AccountActivationScreen({
    super.key,
    required this.token,
    required this.onGoToLogin,
    this.api,
  });

  final String token;
  final VoidCallback onGoToLogin;
  final AccountAccessApiClient? api;

  @override
  State<AccountActivationScreen> createState() =>
      _AccountActivationScreenState();
}

class _AccountActivationScreenState extends State<AccountActivationScreen> {
  late final AccountAccessApiClient _api =
      widget.api ?? AccountAccessApiClient();
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dob = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _existingUsername = TextEditingController();
  final _existingPassword = TextEditingController();

  InvitationSummary? _summary;
  VerifiedInvitation? _verified;
  ActivationResult? _result;
  String _decision = 'CREATE_NEW';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _firstName,
      _lastName,
      _dob,
      _username,
      _password,
      _confirmPassword,
      _existingUsername,
      _existingPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final requestedToken = widget.token;
    try {
      final summary = await _api.invitation(requestedToken);
      if (!mounted || widget.token != requestedToken) return;
      setState(() {
        _summary = summary;
        _loading = false;
        if (summary.testingCode?.isNotEmpty ?? false) {
          _code.text = summary.testingCode!;
        }
      });
    } on AccountAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final verified = await _api.verifyInvitation(
        token: widget.token,
        code: _code.text,
        firstName: _firstName.text,
        lastName: _lastName.text,
        dateOfBirth: _dob.text,
      );
      if (!mounted) return;
      setState(() {
        _verified = verified;
        _loading = false;
        _decision = 'CREATE_NEW';
        if (verified.assignedUsername.isNotEmpty) {
          _username.text = verified.assignedUsername;
        } else if (verified.usernameSuggestions.isNotEmpty) {
          _username.text = verified.usernameSuggestions.first;
        }
      });
    } on AccountAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.activate(
        token: widget.token,
        activationSession: _verified!.activationSession,
        decision: _verified!.accountType == 'STAFF'
            ? 'ACTIVATE_RESERVED'
            : _decision,
        username: _username.text,
        password: _password.text,
        existingUsername: _existingUsername.text,
        existingPassword: _existingPassword.text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on AccountAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _notMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _api.dispute(widget.token);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Activation stopped. The school must correct the invitation before it can be used.';
      });
    } on AccountAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.resendCode(widget.token);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = result.message;
        if (result.testingCode?.isNotEmpty ?? false) {
          _code.text = result.testingCode!;
        }
      });
    } on AccountAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  DateTime? _parseDateOfBirth(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }
    return parsed;
  }

  String? _validateDateOfBirth(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = _parseDateOfBirth(value);
    if (parsed == null) return 'Enter a valid date as YYYY-MM-DD';
    final today = DateUtils.dateOnly(DateTime.now());
    if (parsed.isAfter(today)) return 'Date of birth cannot be in the future';
    return null;
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _chooseDateOfBirth() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final typedDate = _parseDateOfBirth(_dob.text);
    final suggestedYear = today.year - 18;
    final selected = await showDatePicker(
      context: context,
      initialDate: typedDate ?? DateTime(suggestedYear, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Choose date of birth',
      fieldLabelText: 'Date of birth',
      fieldHintText: 'YYYY-MM-DD',
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (selected == null || !mounted) return;
    setState(() => _dob.text = _formatDate(selected));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _loading && _summary == null
                    ? const Center(child: CircularProgressIndicator())
                    : Form(key: _formKey, child: _content()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    if (_result != null) return _success();
    if (_summary == null) return _unavailable();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.school_outlined, color: AppColors.green, size: 38),
        const SizedBox(height: 14),
        Text(
          _verified == null ? 'Confirm your invitation' : 'Set up your access',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${_summary!.schoolName} invited you as ${_summary!.accountType.toLowerCase()}.',
          style: const TextStyle(color: AppColors.muted),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          _notice(_error!, error: true),
        ],
        const SizedBox(height: 24),
        if (_verified == null) _verificationFields() else _accountDecision(),
      ],
    );
  }

  Widget _verificationFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _notice(
        'A code was sent by ${_summary!.deliveryChannel.toLowerCase()} to ${_summary!.maskedDestination}. We also ask for the name given to the school so incorrect contact details cannot activate the account.',
      ),
      const SizedBox(height: 20),
      TextFormField(
        controller: _code,
        decoration: const InputDecoration(
          labelText: '6-digit verification code',
        ),
        keyboardType: TextInputType.number,
        validator: _required,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _firstName,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: _required,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _lastName,
              decoration: const InputDecoration(labelText: 'Last name'),
              validator: _required,
            ),
          ),
        ],
      ),
      if (_summary!.dateOfBirthRequired) ...[
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _dob,
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                ),
                keyboardType: TextInputType.datetime,
                autofillHints: const [AutofillHints.birthday],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateDateOfBirth,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Choose date of birth',
              onPressed: _loading ? null : _chooseDateOfBirth,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
      ],
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _loading ? null : _verify,
          child: _loading ? const _Spinner() : const Text('Verify invitation'),
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _loading ? null : _resendCode,
            child: const Text('Send a new code'),
          ),
          TextButton(
            onPressed: _loading ? null : _notMe,
            child: const Text('This is not me'),
          ),
        ],
      ),
    ],
  );

  Widget _accountDecision() {
    if (_verified!.accountType == 'STAFF') return _staffPasswordSetup();
    final connectsGuardian =
        _decision == 'CONNECT_EXISTING' && _verified!.accountType == 'GUARDIAN';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose your account access',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _notice(
          'SMA does not guess account ownership from a matching phone number or email. Existing access is accepted only after the exact username and password are verified.',
        ),
        const SizedBox(height: 10),
        RadioListTile<String>(
          value: 'CREATE_NEW',
          groupValue: _decision,
          onChanged: (value) => setState(() => _decision = value!),
          title: const Text('Create new access'),
          subtitle: const Text('I do not already use an SMA account.'),
        ),
        RadioListTile<String>(
          value: 'CONNECT_EXISTING',
          groupValue: _decision,
          onChanged: (value) => setState(() => _decision = value!),
          title: const Text('I already have SMA access'),
          subtitle: const Text(
            'Prove the account with its exact username and password.',
          ),
        ),
        const SizedBox(height: 14),
        if (_decision == 'CONNECT_EXISTING') ...[
          TextFormField(
            controller: _existingUsername,
            decoration: const InputDecoration(
              labelText: 'Existing global username',
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _existingPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Existing account password',
            ),
            validator: _required,
          ),
          const SizedBox(height: 8),
          _notice('A proven guardian account can be reused across schools.'),
          const SizedBox(height: 14),
        ],
        if (!connectsGuardian) ...[
          TextFormField(
            controller: _username,
            decoration: InputDecoration(
              labelText: _decision == 'CONNECT_EXISTING'
                  ? 'Username for this school'
                  : 'New global username',
            ),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _decision == 'CONNECT_EXISTING'
                  ? 'Password for this school'
                  : 'New password',
            ),
            validator: _passwordValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
            validator: (value) =>
                value != _password.text ? 'Passwords do not match' : null,
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _activate,
            child: _loading
                ? const _Spinner()
                : const Text('Finish account setup'),
          ),
        ),
      ],
    );
  }

  Widget _staffPasswordSetup() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Create your password',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      _notice(
        'Your school has already created and reserved this unique username for your staff record. It cannot be changed during activation.',
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _username,
        readOnly: true,
        enableInteractiveSelection: true,
        decoration: const InputDecoration(
          labelText: 'Assigned username',
          suffixIcon: Icon(Icons.lock_outline),
        ),
        validator: _required,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Create password'),
        validator: _passwordValidator,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _confirmPassword,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm password'),
        validator: (value) =>
            value != _password.text ? 'Passwords do not match' : null,
      ),
      const SizedBox(height: 22),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _loading ? null : _activate,
          child: _loading
              ? const _Spinner()
              : const Text('Activate staff account'),
        ),
      ),
    ],
  );

  Widget _success() => Column(
    children: [
      const CircleAvatar(
        radius: 34,
        backgroundColor: Color(0xFFE2F4EF),
        child: Icon(Icons.check_rounded, size: 38, color: AppColors.green),
      ),
      const SizedBox(height: 18),
      Text(
        'Your account is ready',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(_result!.message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      SelectableText(
        _result!.username,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.onGoToLogin,
          child: const Text('Go to sign in'),
        ),
      ),
    ],
  );

  Widget _unavailable() => Column(
    children: [
      const Icon(Icons.link_off_rounded, size: 44, color: AppColors.red),
      const SizedBox(height: 14),
      Text(
        _error ?? 'This invitation is unavailable.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: widget.onGoToLogin,
        child: const Text('Go to sign in'),
      ),
    ],
  );

  Widget _notice(String message, {bool error = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEEEE) : const Color(0xFFEAF6F3),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: error ? AppColors.red : AppColors.text),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _passwordValidator(String? value) {
    if (value == null || value.length < 10) return 'Use at least 10 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value) ||
        !RegExp(r'[a-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include upper case, lower case, and a number';
    }
    return null;
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
