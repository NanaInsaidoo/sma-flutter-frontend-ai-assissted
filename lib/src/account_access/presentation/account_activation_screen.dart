import 'package:flutter/material.dart';

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
  final _email = TextEditingController();
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
      _email,
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
        email: _email.text,
      );
      if (!mounted) return;
      setState(() {
        _verified = verified;
        _loading = false;
        _decision = verified.possibleAccounts.isEmpty
            ? 'CREATE_NEW'
            : 'DECIDE_LATER';
        if (verified.usernameSuggestions.isNotEmpty) {
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
        decision: _decision,
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
        TextFormField(
          controller: _dob,
          decoration: const InputDecoration(
            labelText: 'Date of birth',
            hintText: 'YYYY-MM-DD',
          ),
          validator: _required,
        ),
      ],
      if (_summary!.emailRequired) ...[
        const SizedBox(height: 14),
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(
            labelText: 'Email given to the school',
          ),
          validator: _required,
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
    final hasCandidates = _verified!.possibleAccounts.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCandidates) ...[
          Text(
            'Possible existing access',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ..._verified!.possibleAccounts.map(
            (candidate) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${candidate.maskedUsername} · ${candidate.schoolLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          candidate.explanation,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (!hasCandidates)
          RadioListTile<String>(
            value: 'CREATE_NEW',
            groupValue: _decision,
            onChanged: (value) => setState(() => _decision = value!),
            title: const Text('Create my access'),
            subtitle: const Text('Use a new global username and password.'),
          ),
        if (hasCandidates)
          RadioListTile<String>(
            value: 'CONNECT_EXISTING',
            groupValue: _decision,
            onChanged: (value) => setState(() => _decision = value!),
            title: const Text('Use or connect an existing account'),
            subtitle: const Text(
              'You must prove it with its exact username and password.',
            ),
          ),
        if (hasCandidates)
          RadioListTile<String>(
            value: 'DECIDE_LATER',
            groupValue: _decision,
            onChanged: (value) => setState(() => _decision = value!),
            title: const Text('Decide later'),
            subtitle: const Text(
              'Create separate access now; connect from My account later.',
            ),
          ),
        if (hasCandidates)
          RadioListTile<String>(
            value: 'NOT_MINE',
            groupValue: _decision,
            onChanged: (value) => setState(() => _decision = value!),
            title: const Text('None of these accounts is mine'),
            subtitle: const Text(
              'Create separate access and record that you rejected the matches.',
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
          _notice(
            'If this is a guardian account, it can be reused across schools. Staff access always remains separate by school, so a new username and password may still be required.',
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _username,
          decoration: const InputDecoration(labelText: 'New global username'),
          validator: (value) =>
              _decision == 'CONNECT_EXISTING' &&
                  _verified!.accountType == 'GUARDIAN'
              ? null
              : _required(value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
          validator: (value) =>
              _decision == 'CONNECT_EXISTING' &&
                  _verified!.accountType == 'GUARDIAN'
              ? null
              : _passwordValidator(value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPassword,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
          validator: (value) {
            if (_decision == 'CONNECT_EXISTING' &&
                _verified!.accountType == 'GUARDIAN') {
              return null;
            }
            return value != _password.text ? 'Passwords do not match' : null;
          },
        ),
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
