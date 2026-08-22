import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/account_access_api_client.dart';

enum AccountRecoveryKind { username, password }

class AccountRecoveryScreen extends StatefulWidget {
  const AccountRecoveryScreen({
    super.key,
    required this.kind,
    required this.onBackToLogin,
    this.api,
  });
  final AccountRecoveryKind kind;
  final VoidCallback onBackToLogin;
  final AccountAccessApiClient? api;

  @override
  State<AccountRecoveryScreen> createState() => _AccountRecoveryScreenState();
}

class _AccountRecoveryScreenState extends State<AccountRecoveryScreen> {
  late final AccountAccessApiClient _api =
      widget.api ?? AccountAccessApiClient();
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _code = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dob = TextEditingController();
  final _email = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  ChallengeStarted? _challenge;
  RecoveryVerified? _verified;
  bool _done = false;
  bool _loading = false;
  String? _error;

  bool get _recoveringUsername => widget.kind == AccountRecoveryKind.username;

  @override
  void dispose() {
    for (final controller in [
      _identifier,
      _code,
      _firstName,
      _lastName,
      _dob,
      _email,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_challenge == null) {
        final challenge = _recoveringUsername
            ? await _api.startUsernameRecovery(_identifier.text)
            : await _api.startPasswordReset(_identifier.text);
        if (!mounted) return;
        setState(() {
          _challenge = challenge;
          _loading = false;
          if (challenge.testingCode?.isNotEmpty ?? false) {
            _code.text = challenge.testingCode!;
          }
        });
        return;
      }
      if (_verified == null) {
        final result = await _api.verifyRecovery(
          challengeId: _challenge!.challengeId,
          code: _code.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
          dateOfBirth: _dob.text,
          email: _email.text,
        );
        if (!mounted) return;
        setState(() {
          _verified = result;
          _loading = false;
        });
        return;
      }
      if (_recoveringUsername) {
        setState(() {
          _done = true;
          _loading = false;
        });
        return;
      }
      await _api.resetPassword(
        challengeId: _challenge!.challengeId,
        proofToken: _verified!.proofToken,
        newPassword: _newPassword.text,
      );
      if (mounted) {
        setState(() {
          _done = true;
          _loading = false;
        });
      }
    } on AccountAccessException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _recoveringUsername
                          ? Icons.person_search_outlined
                          : Icons.lock_reset_rounded,
                      size: 38,
                      color: AppColors.green,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _recoveringUsername
                          ? 'Use the registered phone number to find eligible usernames, then confirm the verification code and personal information. Recovery never merges accounts.'
                          : 'Enter the global username. We send a verification code to the registered contact, then confirm personal information before allowing a new password.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    ..._fields(),
                    const SizedBox(height: 22),
                    if (!_done)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_buttonLabel),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: widget.onBackToLogin,
                        child: Text(_done ? 'Sign in' : 'Back to sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _fields() {
    if (_done) {
      return [
        const Center(
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFFE2F4EF),
            child: Icon(Icons.check_rounded, color: AppColors.green, size: 34),
          ),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'Password updated successfully.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ];
    }
    if (_challenge == null) {
      return [
        TextFormField(
          controller: _identifier,
          keyboardType: _recoveringUsername
              ? TextInputType.phone
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: _recoveringUsername
                ? 'Registered phone number'
                : 'Global username',
          ),
          validator: _required,
        ),
      ];
    }
    if (_verified == null) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6F3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${_challenge!.message} ${_challenge!.deliveryChannel}: ${_challenge!.maskedDestination}',
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Verification code'),
          validator: _required,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        TextFormField(
          controller: _dob,
          decoration: const InputDecoration(
            labelText: 'Date of birth (if recorded)',
            hintText: 'YYYY-MM-DD',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email (if recorded)'),
        ),
      ];
    }
    if (_recoveringUsername) {
      return [
        Text(
          _verified!.accounts.isEmpty
              ? 'No eligible usernames were found.'
              : 'Your eligible accounts',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ..._verified!.accounts.map(
          (account) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: SelectableText(
              account.username,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${account.accountType.toLowerCase()} · ${account.schoolLabel}',
            ),
          ),
        ),
      ];
    }
    return [
      TextFormField(
        controller: _newPassword,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'New password'),
        validator: _passwordValidator,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _confirmPassword,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Confirm new password'),
        validator: (value) =>
            value != _newPassword.text ? 'Passwords do not match' : null,
      ),
    ];
  }

  String get _title =>
      _recoveringUsername ? 'Recover username' : 'Reset password';
  String get _buttonLabel {
    if (_challenge == null) return 'Send verification code';
    if (_verified == null) return 'Verify account information';
    return _recoveringUsername ? 'Done' : 'Update password';
  }

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
