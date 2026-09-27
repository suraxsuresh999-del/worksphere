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
  late Future<_ClientDashboardData> _clientDashboard;
  @override
  void initState() {
    super.initState();
    _dashboard = _load();
    _clientDashboard =
        ref.read(currentUserProvider).valueOrNull?.type == UserType.client
        ? _loadClientDashboard()
        : Future.value(const _ClientDashboardData());
  }

  Future<_ClientDashboardData> _loadClientDashboard() async {
    final api = Supabase.instance.client;
    final user = api.auth.currentUser;
    if (user == null) return const _ClientDashboardData();
    final results = await Future.wait([
      api.from('jobs').select('id, status').eq('client_id', user.id),
      api.from('projects').select('id, status').eq('client_id', user.id),
      api
          .from('project_payment_transactions')
          .select('amount')
          .eq('client_id', user.id)
          .eq('payment_status', 'verified'),
    ]);
    final jobs = (results[0] as List).cast<Map>();
    final projects = (results[1] as List).cast<Map>();
    final transactions = (results[2] as List).cast<Map>();
    final jobIds = jobs.map((job) => job['id']).whereType<String>().toList();
    final applications = jobIds.isEmpty
        ? const <Map>[]
        : ((await api
                      .from('job_applications')
                      .select('id, status')
                      .inFilter('job_id', jobIds))
                  as List)
              .cast<Map>();
    final spending = transactions.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
    return _ClientDashboardData(
      activeJobs: jobs.where((job) => job['status'] == 'open').length,
      applicationCount: applications.length,
      activeProjects: projects
          .where((project) => project['status'] == 'active')
          .length,
      completedProjects: projects
          .where((project) => project['status'] == 'completed')
          .length,
      verifiedSpending: spending,
    );
  }

  Future<_DashboardData> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _DashboardData();
    final api = Supabase.instance.client;
    final results = await Future.wait([
      api
          .from('job_applications')
          .select('id, status')
          .eq('freelancer_id', user.id),
      api
          .from('projects')
          .select('id, title, deadline')
          .eq('freelancer_id', user.id)
          .eq('status', 'active'),
      api
          .from('jobs')
          .select('id, title, budget_min, budget_max, experience_level')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(3),
      api
          .from('profiles')
          .select('full_name, avatar_url, city, state, country')
          .eq('id', user.id)
          .maybeSingle(),
      api
          .from('freelancer_profiles')
          .select(
            'title, bio, primary_skill, secondary_skills, years_experience, education_summary, certifications, languages, availability, is_available, total_earnings',
          )
          .eq('user_id', user.id)
          .maybeSingle(),
    ]);
    final account = results[3] as Map<String, dynamic>? ?? const {};
    final profile = results[4] as Map<String, dynamic>? ?? const {};
    final completionFields = <bool>[
      _hasText(account['full_name']),
      _hasText(account['avatar_url']),
      _hasText(account['city']) ||
          _hasText(account['state']) ||
          _hasText(account['country']),
      _hasText(profile['title']),
      _hasText(profile['bio']),
      _hasText(profile['primary_skill']) ||
          _hasItems(profile['secondary_skills']),
      profile['years_experience'] != null,
      _hasText(profile['education_summary']),
      _hasText(profile['certifications']),
      _hasItems(profile['languages']),
      _hasText(profile['availability']),
    ];
    final completion =
        completionFields.where((isComplete) => isComplete).length /
        completionFields.length;
    final availability = profile['availability']?.toString().trim();
    return _DashboardData(
      applications: (results[0] as List).cast<Map>(),
      projects: (results[1] as List).cast<Map>(),
      jobs: (results[2] as List).cast<Map>(),
      profileCompletion: completion,
      totalEarnings: (profile['total_earnings'] as num?)?.toDouble() ?? 0,
      availability: availability?.isNotEmpty == true
          ? availability!
          : ((profile['is_available'] as bool? ?? false)
                ? 'Available'
                : 'Unavailable'),
    );
  }

  bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;
  bool _hasItems(Object? value) =>
      value is List && value.any((item) => item.toString().trim().isNotEmpty);

  void _refresh() => setState(() => _dashboard = _load());

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user?.type == UserType.rolePending)
      return Center(
        child: FilledButton(
          onPressed: () => context.go(RouteNames.userTypeSelection),
          child: const Text('Select your role'),
        ),
      );
    if (user?.type == UserType.client)
      return _clientHome(context, user?.verificationStatus);
    return FutureBuilder<_DashboardData>(
      future: _dashboard,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? const _DashboardData();
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Freelancer Dashboard',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text('Welcome back, ${user?.fullName ?? 'WorkSphere member'}'),
              const SizedBox(height: 20),
              _profileCard(context, data.profileCompletion),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Verification status'),
                  subtitle: Text(
                    user?.verificationStatus.label ?? 'Not submitted',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(RouteNames.verification),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(
                    label: 'Total earnings',
                    value: '₹${data.totalEarnings.toStringAsFixed(2)}',
                  ),
                  _Metric(label: 'Availability', value: data.availability),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Your applications',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(label: 'Total', value: '${data.applications.length}'),
                  _Metric(
                    label: 'Under review',
                    value: '${data.count('pending')}',
                  ),
                  _Metric(
                    label: 'Shortlisted',
                    value: '${data.count('shortlisted')}',
                  ),
                  _Metric(
                    label: 'Accepted',
                    value: '${data.count('accepted')}',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.jobs),
                    icon: const Icon(Icons.search),
                    label: const Text('Find jobs'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.applications),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Applications'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.projects),
                    icon: const Icon(Icons.work_history_outlined),
                    label: const Text('Projects'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go(RouteNames.chat),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Messages'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Recommended jobs',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (data.jobs.isEmpty)
                const _Empty(text: 'No recommended jobs available yet.')
              else
                ...data.jobs.map(
                  (job) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.work_outline),
                      ),
                      title: Text(job['title']?.toString() ?? 'Job'),
                      subtitle: Text(
                        '₹${job['budget_min'] ?? ''} – ₹${job['budget_max'] ?? ''}\n${job['experience_level'] ?? 'Experience not specified'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/job/${job['id']}'),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go(RouteNames.jobs),
                  child: const Text('View all jobs'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Active projects',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (data.projects.isEmpty)
                const _Empty(text: "You don't have any active projects.")
              else
                ...data.projects.map(
                  (project) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.assignment_turned_in_outlined),
                      title: Text(project['title']?.toString() ?? 'Project'),
                      subtitle: Text(
                        'Deadline: ${project['deadline'] ?? 'Not specified'}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _clientHome(BuildContext context, VerificationStatus? status) {
    return FutureBuilder<_ClientDashboardData>(
      future: _clientDashboard,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Client Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              Row(
                children: [
                  const Expanded(
                    child: Text('Dashboard summaries are unavailable.'),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _clientDashboard = _loadClientDashboard(),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              )
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(
                    label: 'Active jobs',
                    value: '${data?.activeJobs ?? 0}',
                  ),
                  _Metric(
                    label: 'Applications',
                    value: '${data?.applicationCount ?? 0}',
                  ),
                  _Metric(
                    label: 'Active projects',
                    value: '${data?.activeProjects ?? 0}',
                  ),
                  _Metric(
                    label: 'Completed projects',
                    value: '${data?.completedProjects ?? 0}',
                  ),
                  _Metric(
                    label: 'Verified spending',
                    value:
                        '₹${(data?.verifiedSpending ?? 0).toStringAsFixed(2)}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: ListTile(
                leading: const Icon(Icons.work_outline),
                title: const Text('My jobs'),
                onTap: () => context.push(RouteNames.myPostedJobs),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_business_outlined),
                title: const Text('Post a job'),
                onTap: () async {
                  if (status?.isVerified == true) {
                    context.push(RouteNames.postJob);
                  } else {
                    await showVerificationRequiredDialog(
                      context,
                      status ?? VerificationStatus.unverified,
                    );
                  }
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.search_outlined),
                title: const Text('Find freelancers'),
                onTap: () => context.push(RouteNames.freelancerDiscovery),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.work_history_outlined),
                title: const Text('Projects'),
                onTap: () => context.push(RouteNames.projects),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _profileCard(BuildContext context, double completion) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile completion · ${(completion * 100).round()}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: completion),
          const SizedBox(height: 8),
          Text(
            completion >= 1
                ? 'Your profile is complete.'
                : 'Add your profile details to help clients understand your experience.',
          ),
          TextButton(
            onPressed: () => context.push(RouteNames.editProfile),
            child: const Text('Complete profile'),
          ),
        ],
      ),
    ),
  );
}

class _DashboardData {
  const _DashboardData({
    this.applications = const [],
    this.projects = const [],
    this.jobs = const [],
    this.profileCompletion = 0,
    this.totalEarnings = 0,
    this.availability = 'Unavailable',
  });
  final List<Map> applications, projects, jobs;
  final double profileCompletion, totalEarnings;
  final String availability;
  int count(String status) =>
      applications.where((item) => item['status'] == status).length;
}

class _ClientDashboardData {
  const _ClientDashboardData({
    this.activeJobs = 0,
    this.applicationCount = 0,
    this.activeProjects = 0,
    this.completedProjects = 0,
    this.verifiedSpending = 0,
  });
  final int activeJobs, applicationCount, activeProjects, completedProjects;
  final double verifiedSpending;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(text)),
  );
}
