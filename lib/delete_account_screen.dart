// Élan — Delete account.
// Google Play requires apps with sign-up to offer in-app account deletion.
// Mirrors the web page at /delete-account on the backend.

import 'package:flutter/material.dart';

import 'models.dart';
import 'screens.dart';
import 'theme.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _understood = false;
  bool _obscure = true;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _understood && _password.text.isNotEmpty && !_deleting;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });

    final error = await AuthService().deleteAccount(_password.text);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _deleting = false;
        _error = error;
      });
      return;
    }

    // Account gone: leave every signed-in screen behind.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messenger.showSnackBar(const SnackBar(
      content: Text('Your account and its data have been permanently deleted.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentLoggedInUser?.email ?? '';
    final text = Theme.of(context).textTheme;

    Widget bullet(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                      color: AppColors.textSecondary, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: Text(s, style: text.bodyMedium)),
            ],
          ),
        );

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Delete account',
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                children: [
                  Text(
                    'This permanently deletes $email and everything '
                    'linked to it. It cannot be undone.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deleted', style: text.titleMedium),
                        const SizedBox(height: 8),
                        bullet('Your account: name, email, phone and password'),
                        bullet('Your emergency alerts, including symptoms, '
                            'messages and locations, and each hospital\'s copy'),
                        bullet('Your saved location and notification token'),
                        bullet('Patient, vital-sign and report records you created'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kept', style: text.titleMedium),
                        const SizedBox(height: 8),
                        bullet('Payment transaction records (amount, date, '
                            'payment ID) for accounting and tax obligations, '
                            'no longer linked to your name, email or alerts.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Password',
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
                  const SizedBox(height: AppSpace.sm),
                  CheckboxListTile(
                    value: _understood,
                    onChanged: (v) => setState(() => _understood = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.emergency,
                    title: Text('I understand this cannot be undone',
                        style: text.bodyLarge),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  PrimaryButton(
                    label: 'Delete my account',
                    icon: Icons.delete_forever_rounded,
                    loading: _deleting,
                    onPressed: _canDelete ? _delete : null,
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
