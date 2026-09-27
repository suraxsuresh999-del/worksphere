import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../app/di/providers.dart';
import '../../../app/router/route_names.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final theme = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, 'Account'),
          _tile(
            context,
            Icons.person_outline,
            'Profile',
            'Name, photo, bio, skills and location',
            () => context.push(RouteNames.editProfile),
          ),
          _tile(
            context,
            Icons.privacy_tip_outlined,
            'Privacy & Security',
            'Verification and login security',
            () => context.push(RouteNames.verification),
          ),
          _tile(
            context,
            Icons.notifications_outlined,
            'Notification Preferences',
            'Choose how WorkSphere contacts you',
            () => context.push(RouteNames.notifications),
          ),
          _tile(
            context,
            Icons.payments_outlined,
            'Payment Methods',
            'Manage UPI payout details',
            () => context.push(RouteNames.paymentMethods),
          ),
          _tile(
            context,
            Icons.link,
            'Connected Accounts',
            'No external account connections are available yet',
            () => _info(
              context,
              'Connected Accounts',
              'Google, Microsoft, GitHub and LinkedIn connections are not available yet.',
            ),
          ),

          _sectionTitle(context, 'Work & Projects'),
          _tile(
            context,
            Icons.work_outline,
            'Work Preferences',
            'Update your work profile and expertise',
            () => context.push(RouteNames.editProfile),
          ),
          _tile(
            context,
            Icons.psychology_outlined,
            'Skills & Expertise',
            'Manage skills on your profile',
            () => context.push(RouteNames.editProfile),
          ),
          _tile(
            context,
            Icons.event_available_outlined,
            'Availability',
            'Availability is managed in your profile',
            () => context.push(RouteNames.editProfile),
          ),
          _tile(
            context,
            Icons.calendar_month_outlined,
            'Work Calendar',
            'Project deadlines, task dates, and interviews',
            () => context.push(RouteNames.calendar),
          ),
          _tile(
            context,
            Icons.notifications_active_outlined,
            'Project Notifications',
            'View your WorkSphere notifications',
            () => context.push(RouteNames.notifications),
          ),
          _tile(
            context,
            Icons.tune,
            'Default Project Settings',
            'Not available yet',
            () => _info(
              context,
              'Default Project Settings',
              'Project defaults are not configurable yet.',
            ),
          ),
          _tile(
            context,
            Icons.bookmark_outline,
            'Saved Filters & Views',
            'Not available yet',
            () => _info(
              context,
              'Saved Filters & Views',
              'The app does not currently provide persistable saved views.',
            ),
          ),

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
                onChanged: (value) {
                  if (value != null)
                    ref.read(localeProvider.notifier).setLocale(value);
                },
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Theme'),
              trailing: DropdownButton<ThemeModeState>(
                value: theme,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: ThemeModeState.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeModeState.dark,
                    child: Text('Dark'),
                  ),
                  DropdownMenuItem(
                    value: ThemeModeState.system,
                    child: Text('System'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null)
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                },
              ),
            ),
          ),
          _settingChoice(context, 'Currency', 'INR', const [
            'INR',
            'USD',
            'EUR',
          ]),
          _settingChoice(context, 'Timezone', 'Asia/Kolkata', const [
            'Asia/Kolkata',
            'UTC',
            'America/New_York',
            'Europe/London',
          ]),
          _settingChoice(context, 'Date Format', 'DD/MM/YYYY', const [
            'DD/MM/YYYY',
            'MM/DD/YYYY',
            'YYYY-MM-DD',
          ]),
          _settingChoice(context, 'Font Size', 'Standard', const [
            'Small',
            'Standard',
            'Large',
          ]),
          _settingChoice(context, 'High Contrast', 'Off', const ['Off', 'On']),
          _settingChoice(context, 'Reduced Motion', 'Off', const ['Off', 'On']),
          _tile(
            context,
            Icons.dashboard_outlined,
            'Default Dashboard',
            'Only one dashboard destination is available',
            () => _info(
              context,
              'Default Dashboard',
              'A default destination cannot be selected because WorkSphere currently has one dashboard.',
            ),
          ),

          _sectionTitle(context, 'Communication'),
          _settingChoice(context, 'Chat Preferences', 'Available', const [
            'Available',
            'Do not disturb',
          ]),
          _settingChoice(context, 'Email Preferences', 'On', const [
            'On',
            'Off',
          ]),
          _settingChoice(
            context,
            'Mention & Comment Notifications',
            'On',
            const ['On', 'Off'],
          ),
          _settingChoice(context, 'Quiet Hours', 'Off', const ['Off', 'On']),
          _settingChoice(context, 'Notification Digest', 'Off', const [
            'Off',
            'Daily',
            'Weekly',
          ]),

          _sectionTitle(context, 'Security'),
          _tile(
            context,
            Icons.password_outlined,
            'Password & Security',
            'Change your password',
            () => context.push(RouteNames.passwordSecurity),
          ),
          _tile(
            context,
            Icons.verified_user_outlined,
            'Two-Factor Authentication',
            'Not available yet',
            () => _info(
              context,
              'Two-Factor Authentication',
              'Two-factor authentication is not supported by the current authentication setup.',
            ),
          ),
          _tile(
            context,
            Icons.devices_outlined,
            'Active Sessions / Devices',
            'Not available yet',
            () => _info(
              context,
              'Active Sessions / Devices',
              'Session management is not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.history,
            'Login History',
            'Not available yet',
            () => _info(
              context,
              'Login History',
              'Login history is not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.warning_amber_outlined,
            'Security Alerts',
            'Not available yet',
            () => _info(
              context,
              'Security Alerts',
              'Security alert preferences are not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.contact_mail_outlined,
            'Recovery Email / Phone',
            'Manage verified contact details in your profile',
            () => context.push(RouteNames.editProfile),
          ),
          _tile(
            context,
            Icons.fingerprint,
            'Passkeys / Biometric Login',
            'Not available yet',
            () => _info(
              context,
              'Passkeys / Biometric Login',
              'Passkeys and biometric login are not supported by the current authentication setup.',
            ),
          ),

          _sectionTitle(context, 'Payments & Billing'),
          _tile(
            context,
            Icons.account_balance_outlined,
            'Payout Account',
            'Manage UPI payout details',
            () => context.push(RouteNames.paymentMethods),
          ),
          _tile(
            context,
            Icons.receipt_long_outlined,
            'Transaction History',
            'View project payments and earnings',
            () => context.push(RouteNames.wallet),
          ),
          _tile(
            context,
            Icons.receipt_outlined,
            'Invoices',
            'View verified project invoices',
            () => context.push(RouteNames.invoices),
          ),
          _tile(
            context,
            Icons.assignment_outlined,
            'Tax Information',
            'Not available yet',
            () => _info(
              context,
              'Tax Information',
              'Tax information management is not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.schedule_outlined,
            'Payout Schedule',
            'Not available yet',
            () => _info(
              context,
              'Payout Schedule',
              'Payout schedules are not configurable in the current payment setup.',
            ),
          ),

          _sectionTitle(context, 'Documents & Verification'),
          _tile(
            context,
            Icons.verified_outlined,
            'Identity Verification & Documents',
            'View or submit verification documents',
            () => context.push(RouteNames.verification),
          ),
          _tile(
            context,
            Icons.workspace_premium_outlined,
            'Certificates',
            'Manage certificates in your profile',
            () => context.push(RouteNames.editProfile),
          ),

          _sectionTitle(context, 'Integrations'),
          _tile(
            context,
            Icons.extension_outlined,
            'Available Integrations',
            'No external integrations are connected',
            () => _info(
              context,
              'Integrations',
              'Google Calendar, Google Drive, Microsoft Teams, Slack, GitHub, Zoom and Dropbox are not supported by the current app.',
            ),
          ),

          _sectionTitle(context, 'Privacy & Data'),
          _settingChoice(context, 'Profile Visibility', 'Public', const [
            'Public',
            'Private',
          ]),
          _settingChoice(context, 'Who Can Contact Me', 'Everyone', const [
            'Everyone',
            'No one',
          ]),
          _settingChoice(
            context,
            'Project & Skills Visibility',
            'Public',
            const ['Public', 'Private'],
          ),
          _tile(
            context,
            Icons.download_outlined,
            'Download My Data',
            'Not available yet',
            () => _info(
              context,
              'Download My Data',
              'Data export is not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.cookie_outlined,
            'Cookie Preferences',
            'Not applicable in this app',
            () => _info(
              context,
              'Cookie Preferences',
              'Cookie preference controls are not applicable to the current app.',
            ),
          ),
          _tile(
            context,
            Icons.delete_outline,
            'Delete Account',
            'Account deletion is not available yet',
            () => _confirmDeleteUnavailable(context),
          ),

          _sectionTitle(context, 'Support'),
          _tile(
            context,
            Icons.support_agent_outlined,
            'Support',
            'Create a ticket and track replies',
            () => context.push(RouteNames.supportCenter),
          ),
          _tile(
            context,
            Icons.help_outline,
            'Help Center / FAQs',
            'Find answers to common questions',
            () => _info(
              context,
              'Help Center',
              'Help articles and FAQs are not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.feedback_outlined,
            'Report a Problem / Submit Feedback',
            'Contact support and track replies',
            () => context.push(RouteNames.supportCenter),
          ),
          _tile(
            context,
            Icons.lightbulb_outline,
            'Feature Request',
            'Not available yet',
            () => _info(
              context,
              'Feature Request',
              'Feature requests are not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.monitor_heart_outlined,
            'System Status',
            'Not available yet',
            () => _info(
              context,
              'System Status',
              'A system status page is not available yet.',
            ),
          ),
          _tile(
            context,
            Icons.confirmation_number_outlined,
            'Support Tickets',
            'View support ticket history',
            () => context.push(RouteNames.supportCenter),
          ),
          _tile(
            context,
            Icons.description_outlined,
            'Terms & Conditions',
            'Review the platform terms',
            () => _info(
              context,
              'Terms & Conditions',
              'Published terms are not configured in the app yet.',
            ),
          ),
          _tile(
            context,
            Icons.privacy_tip,
            'Privacy Policy',
            'Review the privacy policy',
            () => _info(
              context,
              'Privacy Policy',
              'A published privacy policy is not configured in the app yet.',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ref.read(authViewModelProvider.notifier).signOut();
                if (context.mounted) context.go(RouteNames.login);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 16),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  Widget _settingChoice(
    BuildContext context,
    String title,
    String defaultValue,
    List<String> values,
  ) => Card(
    child: ListTile(
      leading: const Icon(Icons.settings_outlined),
      title: Text(title),
      trailing: _PersistedChoice(
        title: title,
        defaultValue: defaultValue,
        values: values,
      ),
    ),
  );

  void _info(BuildContext context, String title, String message) =>
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

  void _confirmDeleteUnavailable(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
        'Account deletion permanently removes your account and data. This action is not available yet, so no account changes will be made.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _PersistedChoice extends StatefulWidget {
  const _PersistedChoice({
    required this.title,
    required this.defaultValue,
    required this.values,
  });
  final String title;
  final String defaultValue;
  final List<String> values;

  @override
  State<_PersistedChoice> createState() => _PersistedChoiceState();
}

class _PersistedChoiceState extends State<_PersistedChoice> {
  String? _value;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox(AppConstants.settingsBox);
    final saved =
        box.get('settings.${widget.title}', defaultValue: widget.defaultValue)
            as String;
    if (mounted)
      setState(
        () => _value = widget.values.contains(saved)
            ? saved
            : widget.defaultValue,
      );
  }

  @override
  Widget build(BuildContext context) => DropdownButton<String>(
    value: _value ?? widget.defaultValue,
    underline: const SizedBox(),
    items: widget.values
        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
        .toList(),
    onChanged: (value) async {
      if (value == null) return;
      setState(() => _value = value);
      final box = await Hive.openBox(AppConstants.settingsBox);
      await box.put('settings.${widget.title}', value);
    },
  );
}
