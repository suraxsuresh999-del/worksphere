import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../app/theme/app_colors.dart';
import '../../common/widgets/report_action.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;
  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<_JobData?> _data;
  bool _saved = false;
  bool _applied = false;
  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_JobData?> _load() async {
    final client = Supabase.instance.client;
    final job = await client
        .from('jobs')
        .select(
          'id, client_id, title, description, budget_min, budget_max, experience_level, category_label, required_skill_names, attachment_paths, status, proposals_count, is_fixed_price, duration_text, location_preference, created_at',
        )
        .eq('id', widget.jobId)
        .maybeSingle();
    if (job == null) return null;
    final user = client.auth.currentUser;
    if (user != null) {
      final saved = await client
          .from('saved_jobs')
          .select('job_id')
          .eq('freelancer_id', user.id)
          .eq('job_id', widget.jobId)
          .maybeSingle();
      final application = await client
          .from('job_applications')
          .select('id')
          .eq('freelancer_id', user.id)
          .eq('job_id', widget.jobId)
          .maybeSingle();
      _saved = saved != null;
      _applied = application != null;
    }
    final clientId = job['client_id']?.toString();
    final clientProfile = clientId == null
        ? null
        : await client
              .from('client_profiles')
              .select(
                'company_name, rating, reviews_count, jobs_posted, total_spent',
              )
              .eq('user_id', clientId)
              .maybeSingle();
    final profile = clientId == null
        ? null
        : await client
              .from('profiles')
              .select('full_name, verification_status, created_at')
              .eq('id', clientId)
              .maybeSingle();
    return _JobData(
      Map<String, dynamic>.from(job),
      clientProfile == null ? null : Map<String, dynamic>.from(clientProfile),
      profile == null ? null : Map<String, dynamic>.from(profile),
    );
  }

  void _refresh() => setState(() => _data = _load());
  Future<void> _toggleSaved() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      if (_saved) {
        await Supabase.instance.client
            .from('saved_jobs')
            .delete()
            .eq('freelancer_id', user.id)
            .eq('job_id', widget.jobId);
      } else {
        await Supabase.instance.client.from('saved_jobs').insert({
          'freelancer_id': user.id,
          'job_id': widget.jobId,
        });
      }
      if (!mounted) return;
      setState(() => _saved = !_saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _saved ? 'Job saved successfully.' : 'Job removed from saved jobs.',
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update saved jobs.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Job details'),
      actions: [
        IconButton(
          tooltip: _saved ? 'Remove saved job' : 'Save job',
          onPressed: _toggleSaved,
          icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
        ),
        ReportAction(
          targetType: 'job',
          targetId: widget.jobId,
          targetName: 'job',
        ),
        IconButton(
          tooltip: 'Share job',
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text: 'Check out this job on WorkSphere: ${widget.jobId}',
            ),
          ),
          icon: const Icon(Icons.share_outlined),
        ),
      ],
    ),
    body: FutureBuilder<_JobData?>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const _DetailSkeleton();
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading job'),
            ),
          );
        final data = snapshot.data;
        if (data == null)
          return const Center(child: Text('This job is no longer available.'));
        return _detail(context, data);
      },
    ),
  );

  Widget _detail(BuildContext context, _JobData data) {
    final job = data.job;
    final open = job['status'] == 'open';
    final skills = (job['required_skill_names'] as List? ?? [])
        .map((skill) => skill.toString())
        .where((skill) => skill.isNotEmpty)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final content = ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Chip(
              label: Text(job['status']?.toString().toUpperCase() ?? 'OPEN'),
            ),
            const SizedBox(height: 12),
            Text(
              job['title']?.toString() ?? 'Untitled job',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if ((job['category_label']?.toString() ?? '').isNotEmpty)
              Text(
                job['category_label'].toString(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 12),
            Text(
              '${_budget(job)} · ${job['experience_level'] ?? 'Experience not specified'} · ${(job['is_fixed_price'] ?? true) ? 'Fixed price' : 'Hourly'}',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Posted ${_posted(job['created_at'])}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'Description',
              child: Text(
                job['description']?.toString() ?? '',
                style: const TextStyle(height: 1.5),
              ),
            ),
            if (skills.isNotEmpty)
              _Section(
                title: 'Required skills',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills
                      .map((skill) => Chip(label: Text(skill)))
                      .toList(),
                ),
              ),
            _Section(
              title: 'Project details',
              child: _DetailsGrid(
                values: {
                  'Project type': (job['is_fixed_price'] ?? true)
                      ? 'Fixed price'
                      : 'Hourly',
                  'Budget': _budget(job),
                  'Duration':
                      job['duration_text']?.toString() ?? 'Not specified',
                  'Experience':
                      job['experience_level']?.toString() ?? 'Not specified',
                  'Proposals': '${job['proposals_count'] ?? 0}',
                  'Location':
                      job['location_preference']?.toString() ?? 'Remote',
                },
              ),
            ),
            if (data.client != null || data.profile != null)
              _Section(
                title: 'About client',
                child: _ClientInfo(client: data.client, profile: data.profile),
              ),
            if (!wide) const SizedBox(height: 96),
          ],
        );
        final action = _ActionArea(
          open: open,
          applied: _applied,
          saved: _saved,
          onSave: _toggleSaved,
          onApply: () => context.push('/job/${widget.jobId}/apply'),
        );
        if (!wide)
          return Stack(
            children: [
              content,
              Align(alignment: Alignment.bottomCenter, child: action),
            ],
          );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            SizedBox(
              width: 330,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                child: action,
              ),
            ),
          ],
        );
      },
    );
  }

  String _budget(Map<String, dynamic> job) {
    final min = job['budget_min'];
    final max = job['budget_max'];
    return min == null && max == null
        ? 'Budget not specified'
        : '₹${min ?? ''}${min != null && max != null ? ' – ' : ''}${max ?? ''}';
  }

  String _posted(Object? value) {
    final time = DateTime.tryParse(value?.toString() ?? '');
    return time == null ? 'recently' : timeago.format(time);
  }
}

class _JobData {
  const _JobData(this.job, this.client, this.profile);
  final Map<String, dynamic> job;
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? profile;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.values});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 24,
    runSpacing: 16,
    children: values.entries
        .map(
          (entry) => SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _ClientInfo extends StatelessWidget {
  const _ClientInfo({this.client, this.profile});
  final Map<String, dynamic>? client;
  final Map<String, dynamic>? profile;
  @override
  Widget build(BuildContext context) {
    final name = client?['company_name']?.toString();
    final rating = client?['rating'];
    final verified = profile?['verification_status'] == 'approved';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (name?.isNotEmpty ?? false)
              ? name!
              : profile?['full_name']?.toString() ?? 'Client',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (rating != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('★ $rating (${client?['reviews_count'] ?? 0} reviews)'),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('${client?['jobs_posted'] ?? 0} jobs posted'),
            if (verified)
              const Text(
                '✓ Verified client',
                style: TextStyle(color: AppColors.primaryDark),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.open,
    required this.applied,
    required this.saved,
    required this.onSave,
    required this.onApply,
  });
  final bool open, applied, saved;
  final VoidCallback onSave, onApply;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSave,
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                  label: Text(saved ? 'Saved' : 'Save'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Share job',
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: 'WorkSphere job'),
                ),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !open
                  ? null
                  : (applied ? () => context.go('/applications') : onApply),
              child: Text(
                !open
                    ? 'Job closed'
                    : (applied ? 'View application' : 'Apply now'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: List.generate(
      4,
      (_) => Container(
        height: 130,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}
