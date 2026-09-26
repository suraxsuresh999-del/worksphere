import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/providers.dart';
import '../../../app/router/route_names.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, 'Account'),
          _tile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & Security',
            subtitle: 'Control account privacy, verification and login security.',
            onTap: () => context.push(RouteNames.verification),
          ),
          _tile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notification Preferences',
            subtitle: 'Choose how WorkSphere contacts you.',
            onTap: () => _showInfo(context, 'Notification preferences', 'Notification settings are managed from your account preferences.'),
          ),
          _tile(
            context,
            icon: Icons.payments_outlined,
            title: 'Payment Methods',
            subtitle: 'Add UPI details for receiving project payments.',
            onTap: () => context.push(RouteNames.paymentMethods),
          ),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Preferences'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Language'),
              trailing: DropdownButton<String>(
                value: locale,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    ref.read(localeProvider.notifier).setLocale(newValue);
                  }
                },
              ),
            ),
          ),
          _tile(
            context,
            icon: Icons.password_outlined,
            title: 'Password & Security',
            subtitle: 'Change your password and recovery options.',
            onTap: () => context.push(RouteNames.passwordSecurity),
          ),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Support'),
          _tile(
            context,
            icon: Icons.support_agent_outlined,
            title: 'Support',
            subtitle: 'Contact the WorkSphere team.',
            onTap: () => _showInfo(context, 'Support', 'Email support@worksphere.example or use the in-app help center.'),
          ),
          _tile(
            context,
            icon: Icons.help_outline,
            title: 'Help Center / FAQs',
            subtitle: 'Find answers to common questions.',
            onTap: () => _showInfo(context, 'Help Center', 'Help articles and FAQs can be added here without changing the app layout.'),
          ),
          _tile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            subtitle: 'Review the platform terms.',
            onTap: () => _showInfo(context, 'Terms & Conditions', 'The terms screen can be linked to your published policy page.'),
          ),
          _tile(
            context,
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Review the privacy policy.',
            onTap: () => _showInfo(context, 'Privacy Policy', 'The privacy policy screen can be linked to your published policy page.'),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ref.read(authViewModelProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(RouteNames.login);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
