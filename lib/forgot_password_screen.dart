// Élan — Forgot password.
// Step 1: email → the server emails a 6-digit code.
// Step 2: code + new password → password updated, every old session signed out.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';
import 'theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _api = ApiService();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _messageFor(ApiResponse r, String fallback) => r.isNetworkError
      ? 'Cannot reach the Élan server. Check your connection and try again.'
      : (r.error ?? fallback);

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter the email address you signed up with');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await _api.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.success) {
        _codeSent = true;
        _info = 'If $email has an Élan account, a 6-digit code is on its way. '
            'It expires in 15 minutes. Check your spam folder too.';
      } else {
        _error = _messageFor(r, 'Could not send the code');
      }
    });
  }

  Future<void> _reset() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await _api.resetPassword(
      email: _email.text.trim(),
      code: code,
      password: _password.text,
    );
    if (!mounted) return;
    if (!r.success) {
      setState(() {
        _busy = false;
        _error = _messageFor(r, 'Could not reset the password');
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Password updated. Sign in with your new password.'),
    ));
    Navigator.of(context).pop(_email.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Reset password',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                children: [
                  Text(
                    _codeSent
                        ? 'Enter the code we emailed you and choose a new password.'
                        : 'Enter your account email and we will send you a code to set a new password.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  TextField(
                    controller: _email,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                    ),
                  ),
                  if (_codeSent) ...[
                    if (_info != null) ...[
                      const SizedBox(height: AppSpace.md),
                      Text(_info!, style: text.bodyMedium),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: '6-digit code',
                        counterText: '',
                        prefixIcon: Icon(Icons.pin_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text('At least 6 characters. This signs you out on all '
                        'other devices.', style: text.bodySmall),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.lg),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  PrimaryButton(
                    label: _codeSent ? 'Set new password' : 'Send code',
                    icon: _codeSent
                        ? Icons.check_rounded
                        : Icons.mail_outline_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: AppSpace.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _codeSent = false;
                                    _info = null;
                                    _error = null;
                                    _code.clear();
                                  }),
                          child: const Text('Change email'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _sendCode,
                          child: const Text('Send a new code'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
