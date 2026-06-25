import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/auth_api_client.dart';

enum _AuthMode {
  login,
  forgot,
  dob,
  otp,
  reset,
  done,
  firstLoginDob,
  firstLoginPassword,
  firstLoginPasswordDone,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthApiClient _api = AuthApiClient();
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  PasswordResetStart? _reset;
  AuthSession? _pendingSession;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _otp.dispose();
    _dateOfBirth.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _message = null;
      _isError = false;
    });

    try {
      switch (_mode) {
        case _AuthMode.login:
          final session = await _api.login(
            identifier: _identifier.text,
            password: _password.text,
          );
          if (!mounted) return;
          _continueAfterLogin(session);
        case _AuthMode.forgot:
          final reset = await _api.requestPasswordReset(
            identifier: _identifier.text,
          );
          setState(() {
            _reset = reset;
            _mode = reset.requiresDateOfBirth ? _AuthMode.dob : _AuthMode.otp;
            _message = 'Verification code sent to ${reset.destination}.';
          });
        case _AuthMode.dob:
          await _api.verifyDobForReset(
            userName: _resetUserName,
            dateOfBirth: _dateOfBirth.text,
          );
          setState(() {
            _mode = _AuthMode.otp;
            _message = 'Identity confirmed. Enter the code we sent you.';
          });
        case _AuthMode.otp:
          await _api.verifyOtp(userName: _resetUserName, otp: _otp.text);
          setState(() {
            _mode = _AuthMode.reset;
            _message = 'Code verified. Create a new password.';
          });
        case _AuthMode.reset:
          await _api.resetPasswordWithOtp(
            userName: _resetUserName,
            otp: _otp.text,
            newPassword: _newPassword.text,
            dateOfBirth: _dateOfBirth.text,
          );
          setState(() {
            _mode = _AuthMode.done;
            _message = 'Password updated. You can sign in now.';
          });
        case _AuthMode.done:
          _backToLogin();
        case _AuthMode.firstLoginDob:
          final session = _pendingSession;
          if (session == null) {
            _backToLogin();
            return;
          }
          await _api.verifyDateOfBirth(
            accessToken: session.accessToken,
            userName: session.userName,
            dateOfBirth: _dateOfBirth.text,
          );
          final verifiedSession = session.copyWith(requiresDateOfBirth: false);
          if (!mounted) return;
          _continueAfterLogin(verifiedSession);
        case _AuthMode.firstLoginPassword:
          final session = _pendingSession;
          if (session == null) {
            _backToLogin();
            return;
          }
          await _api.changePasswordAfterVerification(
            accessToken: session.accessToken,
            userName: session.userName,
            newPassword: _newPassword.text,
          );
          setState(() {
            _pendingSession = null;
            _mode = _AuthMode.firstLoginPasswordDone;
            _message =
                'Password updated. Sign in again with your new password.';
            _password.clear();
            _newPassword.clear();
            _confirmPassword.clear();
          });
        case _AuthMode.firstLoginPasswordDone:
          _backToLogin();
      }
    } on AuthException catch (error) {
      setState(() {
        _message = error.message;
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _resetUserName {
    final fromApi = _reset?.userName.trim() ?? '';
    return fromApi.isEmpty ? _identifier.text.trim() : fromApi;
  }

  void _continueAfterLogin(AuthSession session) {
    final role = session.role.toUpperCase();
    final bypassSetup =
        role == 'SUPER_ADMIN' ||
        role == 'SUPER_ACCOUNT_MANAGER' ||
        role == 'ACCOUNT_MANAGER' ||
        role == 'ACCOUNT_MANAGER_UNVERIFIED' ||
        role == 'ACCOUNT_MANAGER_VERIFIED_STAFF' ||
        session.isAccountManager;

    if (!bypassSetup && session.requiresDateOfBirth) {
      setState(() {
        _pendingSession = session;
        _mode = _AuthMode.firstLoginDob;
        _message = 'Confirm your date of birth to activate this account.';
        _dateOfBirth.clear();
      });
      return;
    }

    if (!bypassSetup && session.mustChangePassword) {
      setState(() {
        _pendingSession = session;
        _mode = _AuthMode.firstLoginPassword;
        _message = 'Create your own password before entering the dashboard.';
        _newPassword.clear();
        _confirmPassword.clear();
      });
      return;
    }

    widget.onAuthenticated(
      session.copyWith(
        requiresDateOfBirth: false,
        mustChangePassword: bypassSetup ? session.mustChangePassword : false,
      ),
    );
  }

  void _startForgotPassword() {
    setState(() {
      _mode = _AuthMode.forgot;
      _password.clear();
      _message = null;
      _isError = false;
    });
  }

  void _backToLogin() {
    setState(() {
      _mode = _AuthMode.login;
      _reset = null;
      _pendingSession = null;
      _password.clear();
      _otp.clear();
      _dateOfBirth.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _message = null;
      _isError = false;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked == null) return;
    _dateOfBirth.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Row(
            children: [
              if (wide) const _BrandPanel(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 48 : 20,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 510),
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(wide ? 34 : 22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Header(mode: _mode),
                                const SizedBox(height: 24),
                                if (_message != null) ...[
                                  _MessageBanner(
                                    message: _message!,
                                    isError: _isError,
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                ..._fieldsForMode(),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
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
                                        : Text(_primaryActionLabel),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _secondaryAction(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _fieldsForMode() {
    switch (_mode) {
      case _AuthMode.login:
        return [
          _TextFieldBlock(
            label: 'USERNAME, PHONE, OR EMAIL',
            child: TextFormField(
              controller: _identifier,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'e.g. admin@school.com or +233...',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: _required('Enter your username, phone, or email'),
            ),
          ),
          const SizedBox(height: 16),
          _TextFieldBlock(
            label: 'PASSWORD',
            child: TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _required('Enter your password'),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _loading ? null : _startForgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
        ];
      case _AuthMode.forgot:
        return [
          _TextFieldBlock(
            label: 'ACCOUNT IDENTIFIER',
            child: TextFormField(
              controller: _identifier,
              decoration: const InputDecoration(
                hintText: 'Username, phone, or email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: _required(
                'Enter the account username, phone, or email',
              ),
            ),
          ),
        ];
      case _AuthMode.dob:
        return [
          _TextFieldBlock(
            label: 'DATE OF BIRTH',
            child: TextFormField(
              controller: _dateOfBirth,
              readOnly: true,
              onTap: _pickDateOfBirth,
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD',
                prefixIcon: Icon(Icons.cake_outlined),
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              validator: _required('Select date of birth'),
            ),
          ),
        ];
      case _AuthMode.otp:
        return [
          _TextFieldBlock(
            label: 'VERIFICATION CODE',
            child: TextFormField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                hintText: 'Enter code',
                prefixIcon: Icon(Icons.pin_outlined),
                counterText: '',
              ),
              validator: (value) {
                final code = value?.trim() ?? '';
                if (code.length < 4) return 'Enter the verification code';
                return null;
              },
            ),
          ),
        ];
      case _AuthMode.reset:
        return [
          _TextFieldBlock(
            label: 'NEW PASSWORD',
            child: TextFormField(
              controller: _newPassword,
              obscureText: _obscureNewPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Create a strong password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _passwordValidator,
            ),
          ),
          const SizedBox(height: 12),
          _PasswordRules(password: _newPassword.text),
          const SizedBox(height: 16),
          _TextFieldBlock(
            label: 'CONFIRM PASSWORD',
            child: TextFormField(
              controller: _confirmPassword,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Repeat new password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (value) {
                if (value != _newPassword.text) return 'Passwords do not match';
                return null;
              },
            ),
          ),
        ];
      case _AuthMode.done:
        return const [_SuccessPanel()];
      case _AuthMode.firstLoginDob:
        return [
          _TextFieldBlock(
            label: 'DATE OF BIRTH',
            child: TextFormField(
              controller: _dateOfBirth,
              readOnly: true,
              onTap: _pickDateOfBirth,
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD',
                prefixIcon: Icon(Icons.cake_outlined),
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              validator: _required('Select date of birth'),
            ),
          ),
        ];
      case _AuthMode.firstLoginPassword:
        return [
          _TextFieldBlock(
            label: 'NEW PASSWORD',
            child: TextFormField(
              controller: _newPassword,
              obscureText: _obscureNewPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Create a strong password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureNewPassword = !_obscureNewPassword);
                  },
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: _passwordValidator,
            ),
          ),
          const SizedBox(height: 12),
          _PasswordRules(password: _newPassword.text),
          const SizedBox(height: 16),
          _TextFieldBlock(
            label: 'CONFIRM PASSWORD',
            child: TextFormField(
              controller: _confirmPassword,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'Repeat new password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (value) {
                if (value != _newPassword.text) return 'Passwords do not match';
                return null;
              },
            ),
          ),
        ];
      case _AuthMode.firstLoginPasswordDone:
        return const [_SuccessPanel()];
    }
  }

  String get _primaryActionLabel {
    return switch (_mode) {
      _AuthMode.login => 'Sign In',
      _AuthMode.forgot => 'Send Reset Code',
      _AuthMode.dob => 'Confirm Identity',
      _AuthMode.otp => 'Verify Code',
      _AuthMode.reset => 'Update Password',
      _AuthMode.done => 'Back to Login',
      _AuthMode.firstLoginDob => 'Confirm Identity',
      _AuthMode.firstLoginPassword => 'Update Password',
      _AuthMode.firstLoginPasswordDone => 'Back to Login',
    };
  }

  Widget _secondaryAction() {
    if (_mode == _AuthMode.login) {
      return const Center(
        child: Text(
          'SMA Ghana platform access for school and platform teams.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );
    }
    if (_mode == _AuthMode.firstLoginDob ||
        _mode == _AuthMode.firstLoginPassword) {
      return Center(
        child: TextButton.icon(
          onPressed: _loading ? null : _backToLogin,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Cancel and return to login'),
        ),
      );
    }
    return Center(
      child: TextButton.icon(
        onPressed: _loading ? null : _backToLogin,
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Back to login'),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? _passwordValidator(String? value) {
    final password = value ?? '';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp('[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp('[a-z]').hasMatch(password)) {
      return 'Add at least one lowercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) return 'Add at least one number';
    return null;
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, Color(0xFF197A70), AppColors.navyDark],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: _GlowCircle(size: 290, opacity: .08),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: _GlowCircle(size: 300, opacity: .06),
          ),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .24),
                        ),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMA Ghana',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'School Management Platform',
                          style: TextStyle(
                            color: Color(0xBFFFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Built for Ghanaian private schools.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Admissions, fees, attendance, reports, and school onboarding in one responsive workspace.',
                  style: TextStyle(
                    color: Color(0xCFFFFFFF),
                    fontSize: 15,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 32),
                const _BrandFeature('Offline-friendly views for daily work'),
                const _BrandFeature('Live updates when records change'),
                const _BrandFeature('Built around Ghana school operations'),
                const Spacer(),
                const Text(
                  'GHANA · BASIC SCHOOL · PRIVATE SCHOOLS',
                  style: TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFFA7F3D0)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.mode});
  final _AuthMode mode;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      _AuthMode.login => 'Welcome back',
      _AuthMode.forgot => 'Reset your password',
      _AuthMode.dob => 'Confirm identity',
      _AuthMode.otp => 'Enter verification code',
      _AuthMode.reset => 'Create new password',
      _AuthMode.done => 'Password updated',
      _AuthMode.firstLoginDob => 'Confirm identity',
      _AuthMode.firstLoginPassword => 'Create your password',
      _AuthMode.firstLoginPasswordDone => 'Password updated',
    };
    final subtitle = switch (mode) {
      _AuthMode.login => 'Sign in to continue to your SMA workspace.',
      _AuthMode.forgot =>
        'Enter your username, phone number, or email to receive a reset code.',
      _AuthMode.dob =>
        'For this account, we need date of birth verification before reset.',
      _AuthMode.otp => 'Use the code sent to your email or phone.',
      _AuthMode.reset => 'Choose a password that meets the security rules.',
      _AuthMode.done => 'Your account is ready for sign in.',
      _AuthMode.firstLoginDob =>
        'This is required the first time you activate your staff account.',
      _AuthMode.firstLoginPassword =>
        'Set a private password before accessing your school dashboard.',
      _AuthMode.firstLoginPasswordDone =>
        'Your account is ready. Sign in again with the new password.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.school_rounded, color: AppColors.green),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _TextFieldBlock extends StatelessWidget {
  const _TextFieldBlock({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .9,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.red : AppColors.green;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  const _PasswordRules({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _RuleChip(label: '8+ characters', passed: password.length >= 8),
        _RuleChip(
          label: 'Uppercase',
          passed: RegExp('[A-Z]').hasMatch(password),
        ),
        _RuleChip(
          label: 'Lowercase',
          passed: RegExp('[a-z]').hasMatch(password),
        ),
        _RuleChip(label: 'Number', passed: RegExp(r'\d').hasMatch(password)),
      ],
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.passed});
  final String label;
  final bool passed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: passed ? AppColors.greenSoft : AppColors.background,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: passed ? AppColors.green : AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          passed ? Icons.check_rounded : Icons.circle_outlined,
          size: 14,
          color: passed ? AppColors.green : AppColors.muted,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: passed ? AppColors.green : AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.green.withValues(alpha: .2)),
    ),
    child: const Column(
      children: [
        Icon(Icons.verified_rounded, color: AppColors.green, size: 38),
        SizedBox(height: 10),
        Text(
          'Your password has been updated successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
