import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/auth_providers.dart';
import '../../../core/utils/validators.dart';
import '../../common/widgets/ws_button.dart';
import '../../common/widgets/ws_text_field.dart';

/// Changes the password for the currently authenticated account. Password-reset
/// links remain available from the login screen for signed-out users.
class PasswordSecurityScreen extends ConsumerStatefulWidget {
  const PasswordSecurityScreen({super.key});

  @override
  ConsumerState<PasswordSecurityScreen> createState() => _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState extends ConsumerState<PasswordSecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_password.text != _confirmation.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword: _password.text);
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Password & Security')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Change password', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Use a strong password you do not use on other services.'),
              const SizedBox(height: 28),
              WsTextField(label: 'New password', hint: 'At least 8 characters', controller: _password, obscureText: true, validator: Validators.password),
              const SizedBox(height: 16),
              WsTextField(label: 'Confirm new password', hint: 'Enter it again', controller: _confirmation, obscureText: true, validator: Validators.password),
              const SizedBox(height: 28),
              WsButton(text: 'Update password', onPressed: _save, isLoading: _saving),
            ]),
          ),
        ),
      );
}
