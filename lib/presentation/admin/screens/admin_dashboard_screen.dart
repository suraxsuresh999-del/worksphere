import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

/// Internal platform back-office. Access is enforced again by the database RPC.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _loadSummary();
  }

  Future<Map<String, dynamic>> _loadSummary() async {
    final response = await Supabase.instance.client.rpc(
      'get_admin_dashboard_summary',
    );
    return Map<String, dynamic>.from(response as Map);
  }

  void _refresh() => setState(() => _summary = _loadSummary());

  Future<void> _signOut() async {
    await ref.read(authViewModelProvider.notifier).signOut();
    if (mounted) context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkSphere Admin'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This account is not authorized to view the admin dashboard.',
                ),
              ),
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Platform overview',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Monitor marketplace health and review items that need attention.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 700
                      ? 4
                      : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _MetricCard(
                      'Total Users',
                      '${data['total_users'] ?? 0}',
                      Icons.people_outline,
                      route: RouteNames.adminUsers,
                    ),
                    _MetricCard(
                      'Freelancers',
                      '${data['freelancers'] ?? 0}',
                      Icons.person_outline,
                      route: RouteNames.adminUsers,
                    ),
                    _MetricCard(
                      'Clients',
                      '${data['clients'] ?? 0}',
                      Icons.business_outlined,
                      route: RouteNames.adminUsers,
                    ),
                    _MetricCard(
                      'Open Jobs',
                      '${data['open_jobs'] ?? 0}',
                      Icons.work_outline,
                      route: RouteNames.adminJobs,
                    ),
                    _MetricCard(
                      'Pending ID Checks',
                      '${data['pending_verifications'] ?? 0}',
                      Icons.verified_user_outlined,
                      route: RouteNames.adminVerification,
                    ),
                    _MetricCard(
                      'Active Projects',
                      '${data['active_projects'] ?? 0}',
                      Icons.handshake_outlined,
                      route: RouteNames.adminProjects,
                    ),
                    _MetricCard(
                      'Completed Projects',
                      '${data['completed_projects'] ?? 0}',
                      Icons.task_alt_outlined,
                      route: RouteNames.adminProjects,
                    ),
                    _MetricCard(
                      'Total Transactions',
                      '${data['total_transactions'] ?? 0}',
                      Icons.receipt_long_outlined,
                      route: RouteNames.adminTransactions,
                    ),
                    _MetricCard(
                      'Verified Revenue',
                      '₹${data['verified_revenue'] ?? 0}',
                      Icons.currency_rupee,
                      route: RouteNames.adminTransactions,
                    ),
                    _MetricCard(
                      'Reports & Disputes',
                      '${data['reports_disputes'] ?? 0}',
                      Icons.report_problem_outlined,
                      route: RouteNames.adminReports,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Admin tools',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const _AdminTool(
                  icon: Icons.verified_user_outlined,
                  title: 'Verification queue',
                  subtitle:
                      'Review identity documents and approve or reject submissions.',
                  route: RouteNames.adminVerification,
                ),
                const _AdminTool(
                  icon: Icons.people_outline,
                  title: 'User management',
                  subtitle: 'Review platform users and their current status.',
                  route: RouteNames.adminUsers,
                ),
                const _AdminTool(
                  icon: Icons.work_outline,
                  title: 'Jobs management',
                  subtitle: 'Inspect jobs, statuses and moderation history.',
                  route: RouteNames.adminJobs,
                ),
                const _AdminTool(
                  icon: Icons.handshake_outlined,
                  title: 'Projects management',
                  subtitle: 'Review active, completed and disputed projects.',
                  route: RouteNames.adminProjects,
                ),
                const _AdminTool(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transactions & payments',
                  subtitle:
                      'Review payment confirmations and verification outcomes.',
                  route: RouteNames.adminTransactions,
                ),
                const _AdminTool(
                  icon: Icons.account_balance_outlined,
                  title: 'Freelancer payout accounts',
                  subtitle: 'Review submitted UPI payout details.',
                  route: RouteNames.adminPayments,
                ),
                const _AdminTool(
                  icon: Icons.support_agent_outlined,
                  title: 'Reports & disputes',
                  subtitle:
                      'Track reports and support tickets from open to closed.',
                  route: RouteNames.adminReports,
                ),
                const _AdminTool(
                  icon: Icons.analytics_outlined,
                  title: 'Support',
                  subtitle: 'Find support contacts and help-center actions.',
                  route: RouteNames.adminSupport,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? route;
  const _MetricCard(this.label, this.value, this.icon, {this.route});
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: route == null ? null : () => context.push(route!),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.primary),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _AdminTool extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  const _AdminTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: route == null ? null : () => context.push(route!),
    ),
  );
}
