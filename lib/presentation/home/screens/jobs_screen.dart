import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../app/theme/app_colors.dart';

class JobsScreen extends StatefulWidget { const JobsScreen({super.key}); @override State<JobsScreen> createState() => _JobsScreenState(); }
class _JobsScreenState extends State<JobsScreen> {
  late Future<List<Map<String, dynamic>>> _jobs;
  final _search = TextEditingController();
  _JobFilter _filter = _JobFilter.all;

  @override void initState() { super.initState(); _jobs = _loadJobs(); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<List<Map<String, dynamic>>> _loadJobs() async {
    final api = Supabase.instance.client;
    final user = api.auth.currentUser;
    if (user == null) return [];
    const fields = 'id, title, description, budget_min, budget_max, experience_level, required_skill_names, status, proposals_count, is_fixed_price, created_at';
    dynamic rows;
    if (_filter == _JobFilter.saved) {
      final saved = await api.from('saved_jobs').select('job_id').eq('freelancer_id', user.id);
      final ids = (saved as List).map((row) => row['job_id']).whereType<String>().toList();
      if (ids.isEmpty) return [];
      rows = await api.from('jobs').select(fields).inFilter('id', ids);
    } else if (_filter == _JobFilter.applied || _filter == _JobFilter.interviews) {
      var query = api.from('job_applications').select('job_id').eq('freelancer_id', user.id);
      if (_filter == _JobFilter.interviews) query = query.eq('status', 'shortlisted');
      final ids = ((await query) as List).map((row) => row['job_id']).whereType<String>().toList();
      if (ids.isEmpty) return [];
      rows = await api.from('jobs').select(fields).inFilter('id', ids);
    } else {
      rows = await api.from('jobs').select(fields).eq('status', 'open');
    }
    final term = _search.text.trim().toLowerCase();
    return (rows as List).map((row) => Map<String, dynamic>.from(row as Map)).where((job) => term.isEmpty || '${job['title']} ${job['description']} ${job['required_skill_names']}'.toLowerCase().contains(term)).toList()..sort((a, b) => (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
  }

  void _reload() => setState(() => _jobs = _loadJobs());
  void _chooseFilter(_JobFilter value) => setState(() { _filter = value; _jobs = _loadJobs(); });

  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
      Expanded(child: TextField(controller: _search, onSubmitted: (_) => _reload(), decoration: InputDecoration(hintText: 'Search jobs, skills, or keywords...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(tooltip: 'Search', onPressed: _reload, icon: const Icon(Icons.arrow_forward))))),
    ])),
    SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: SegmentedButton<_JobFilter>(showSelectedIcon: false, selected: {_filter}, onSelectionChanged: (value) => _chooseFilter(value.first), segments: const [ButtonSegment(value: _JobFilter.all, label: Text('All')), ButtonSegment(value: _JobFilter.saved, label: Text('Saved')), ButtonSegment(value: _JobFilter.applied, label: Text('Applied')), ButtonSegment(value: _JobFilter.interviews, label: Text('Interviews'))])),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: _jobs, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: OutlinedButton(onPressed: _reload, child: const Text('Try again')));
      final jobs = snapshot.data ?? [];
      if (jobs.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.work_outline, size: 48), const SizedBox(height: 12), const Text('No jobs found'), const SizedBox(height: 4), const Text('Try changing your search or filters.'), const SizedBox(height: 12), OutlinedButton(onPressed: () { _search.clear(); _chooseFilter(_JobFilter.all); }, child: const Text('Clear filters'))]));
      return RefreshIndicator(onRefresh: () async => _reload(), child: ListView.separated(padding: const EdgeInsets.all(16), itemCount: jobs.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, index) => _JobCard(job: jobs[index])));
    })),
  ]);
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job}); final Map<String, dynamic> job;
  @override Widget build(BuildContext context) {
    final skills = (job['required_skill_names'] as List? ?? []).take(4).map((skill) => skill.toString()).toList();
    final date = DateTime.tryParse(job['created_at']?.toString() ?? '');
    return Card(child: InkWell(onTap: () => context.push('/job/${job['id']}'), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const CircleAvatar(child: Icon(Icons.work_outline)), const SizedBox(width: 12), Expanded(child: Text(job['title']?.toString() ?? 'Untitled job', style: Theme.of(context).textTheme.titleMedium)), const Icon(Icons.chevron_right)]), const SizedBox(height: 12), Text('${job['experience_level'] ?? 'Experience not specified'} · ${(job['is_fixed_price'] ?? true) ? 'Fixed price' : 'Hourly'}'), const SizedBox(height: 8), Text(_budget(), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)), if (skills.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 6, children: skills.map((skill) => Chip(label: Text(skill), visualDensity: VisualDensity.compact)).toList())], const SizedBox(height: 10), Text('${date == null ? 'Recently posted' : 'Posted ${timeago.format(date)}'} · ${job['proposals_count'] ?? 0} proposals', style: Theme.of(context).textTheme.bodySmall)]))));
  }
  String _budget() { final min = job['budget_min']; final max = job['budget_max']; return min == null && max == null ? 'Budget not specified' : '₹${min ?? ''}${min != null && max != null ? ' – ' : ''}${max ?? ''}'; }
}
enum _JobFilter { all, saved, applied, interviews }
