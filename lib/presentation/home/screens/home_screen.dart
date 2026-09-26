import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/enums/enums.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../common/widgets/verification_required_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late Future<_DashboardData> _dashboard;
  @override
  void initState() { super.initState(); _dashboard = _load(); }

  Future<_DashboardData> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _DashboardData();
    final api = Supabase.instance.client;
    final results = await Future.wait([
      api.from('job_applications').select('id, status').eq('freelancer_id', user.id),
      api.from('projects').select('id, title, deadline').eq('freelancer_id', user.id).eq('status', 'active'),
      api.from('jobs').select('id, title, budget_min, budget_max, experience_level').eq('status', 'open').order('created_at', ascending: false).limit(3),
    ]);
    return _DashboardData(applications: (results[0] as List).cast<Map>(), projects: (results[1] as List).cast<Map>(), jobs: (results[2] as List).cast<Map>());
  }

  void _refresh() => setState(() => _dashboard = _load());

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user?.type == UserType.rolePending) return Center(child: FilledButton(onPressed: () => context.go(RouteNames.userTypeSelection), child: const Text('Select your role')));
    if (user?.type == UserType.client) return _clientHome(context, user?.verificationStatus);
    return FutureBuilder<_DashboardData>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? const _DashboardData();
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Freelancer Dashboard', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Welcome back, ${user?.fullName ?? 'WorkSphere member'}'),
              const SizedBox(height: 20),
              _profileCard(context),
              const SizedBox(height: 16),
              Card(child: ListTile(leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary), title: const Text('Verification status'), subtitle: Text(user?.verificationStatus.label ?? 'Not submitted'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(RouteNames.verification))),
              const SizedBox(height: 20),
              Text('Your applications', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, children: [_Metric(label: 'Total', value: '${data.applications.length}'), _Metric(label: 'Under review', value: '${data.count('pending')}'), _Metric(label: 'Shortlisted', value: '${data.count('shortlisted')}'), _Metric(label: 'Accepted', value: '${data.count('accepted')}')]),
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: [OutlinedButton.icon(onPressed: () => context.go(RouteNames.jobs), icon: const Icon(Icons.search), label: const Text('Find jobs')), OutlinedButton.icon(onPressed: () => context.push(RouteNames.applications), icon: const Icon(Icons.send_outlined), label: const Text('Applications')), OutlinedButton.icon(onPressed: () => context.go(RouteNames.chat), icon: const Icon(Icons.chat_outlined), label: const Text('Messages'))]),
              const SizedBox(height: 20),
              Text('Recommended jobs', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (data.jobs.isEmpty) const _Empty(text: 'No recommended jobs available yet.') else ...data.jobs.map((job) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.work_outline)), title: Text(job['title']?.toString() ?? 'Job'), subtitle: Text('₹${job['budget_min'] ?? ''} – ₹${job['budget_max'] ?? ''}\n${job['experience_level'] ?? 'Experience not specified'}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/job/${job['id']}')))),
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => context.go(RouteNames.jobs), child: const Text('View all jobs'))),
              const SizedBox(height: 12),
              Text('Active projects', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (data.projects.isEmpty) const _Empty(text: "You don't have any active projects.") else ...data.projects.map((project) => Card(child: ListTile(leading: const Icon(Icons.assignment_turned_in_outlined), title: Text(project['title']?.toString() ?? 'Project'), subtitle: Text('Deadline: ${project['deadline'] ?? 'Not specified'}')))),
            ],
          ),
        );
      },
    );
  }

  Widget _clientHome(BuildContext context, VerificationStatus? status) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Client Dashboard', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: const Icon(Icons.work_outline), title: const Text('My jobs'), onTap: () => context.push(RouteNames.myPostedJobs))),
      Card(child: ListTile(leading: const Icon(Icons.add_business_outlined), title: const Text('Post a job'), onTap: () async { if (status?.isVerified == true) { context.push(RouteNames.postJob); } else { await showVerificationRequiredDialog(context, status ?? VerificationStatus.unverified); } })),
      Card(child: ListTile(leading: const Icon(Icons.search_outlined), title: const Text('Find freelancers'), onTap: () => context.push(RouteNames.freelancerDiscovery))),
    ]);
  }

  Widget _profileCard(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Profile completion', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), const LinearProgressIndicator(value: .6), const SizedBox(height: 8), const Text('Complete your profile to improve your chances of getting hired.'), TextButton(onPressed: () => context.push(RouteNames.editProfile), child: const Text('Complete profile'))])));
}

class _DashboardData { const _DashboardData({this.applications = const [], this.projects = const [], this.jobs = const []}); final List<Map> applications, projects, jobs; int count(String status) => applications.where((item) => item['status'] == status).length; }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value}); final String label, value; @override Widget build(BuildContext context) => SizedBox(width: 145, child: Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: Theme.of(context).textTheme.headlineSmall), Text(label, style: Theme.of(context).textTheme.bodySmall)])))); }
class _Empty extends StatelessWidget { const _Empty({required this.text}); final String text; @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Text(text))); }
