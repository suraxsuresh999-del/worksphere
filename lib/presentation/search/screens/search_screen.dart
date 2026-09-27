import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/tamil_nadu_data.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _jobs;
  String _selectedDistrict = 'All Districts';

  @override
  void initState() {
    super.initState();
    _jobs = _loadJobs();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadJobs() async {
    final rows = await Supabase.instance.client
        .from('jobs')
        .select(
          'id, title, description, budget_min, budget_max, required_skill_names, is_fixed_price, location_preference, created_at',
        )
        .eq('status', 'open')
        .order('created_at', ascending: false);
    final term = _search.text.trim().toLowerCase();
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((job) {
          final location = job['location_preference']?.toString() ?? '';
          final searchable =
              '${job['title']} ${job['description']} ${job['required_skill_names']} $location'
                  .toLowerCase();
          final matchesDistrict =
              _selectedDistrict == 'All Districts' ||
              location.toLowerCase().contains(_selectedDistrict.toLowerCase());
          return matchesDistrict && (term.isEmpty || searchable.contains(term));
        })
        .toList();
  }

  void _searchJobs() => setState(() => _jobs = _loadJobs());

  @override
  Widget build(BuildContext context) {
    final districts = ['All Districts', ...TamilNaduData.districts];

    return Scaffold(
      appBar: AppBar(title: const Text('Search Marketplace')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchJobs(),
                  decoration: InputDecoration(
                    hintText: 'Search jobs, skills, freelancers...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _searchJobs,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedDistrict,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        items: districts
                            .map(
                              (district) => DropdownMenuItem(
                                value: district,
                                child: Text(district),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedDistrict = value;
                              _jobs = _loadJobs();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _jobs,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) {
                  return Center(
                    child: OutlinedButton(
                      onPressed: _searchJobs,
                      child: const Text('Retry search'),
                    ),
                  );
                }
                final jobs = snapshot.data ?? const [];
                if (jobs.isEmpty)
                  return const Center(
                    child: Text('No open jobs match your search.'),
                  );
                return RefreshIndicator(
                  onRefresh: () async => _searchJobs(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: jobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildJobCard(context, jobs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final minimum = job['budget_min'];
    final maximum = job['budget_max'];
    final budget = minimum == null && maximum == null
        ? 'Budget not specified'
        : '₹${minimum ?? ''}${minimum != null && maximum != null ? ' – ' : ''}${maximum ?? ''}';
    final skills = (job['required_skill_names'] as List? ?? [])
        .map((skill) => skill.toString())
        .where((skill) => skill.isNotEmpty)
        .take(6);
    final location = job['location_preference']?.toString() ?? 'Remote';
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/job/${job['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job['title']?.toString() ?? 'Untitled job',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$budget · ${(job['is_fixed_price'] ?? true) ? 'Fixed price' : 'Hourly'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: skills
                      .map(
                        (skill) => Chip(
                          label: Text(
                            skill,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
