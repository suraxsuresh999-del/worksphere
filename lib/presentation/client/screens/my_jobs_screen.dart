import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  late Future<List<Map<String, dynamic>>> _jobs;

  @override
  void initState() {
    super.initState();
    _jobs = _loadJobs();
  }

  Future<List<Map<String, dynamic>>> _loadJobs() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    final rows = await Supabase.instance.client
        .from('jobs')
        .select(
          'id, title, description, budget_min, budget_max, status, created_at',
        )
        .eq('client_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _refresh() {
    final request = _loadJobs();
    setState(() => _jobs = request);
    return request.then<void>((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Jobs')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading jobs'),
            ),
          );
        }
        final jobs = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: jobs.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('You have not posted any jobs yet.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(job['title'] as String? ?? 'Untitled job'),
                        subtitle: Text(
                          '${job['description'] ?? ''}\n₹${job['budget_min'] ?? '-'} – ₹${job['budget_max'] ?? '-'}\n${job['status'] ?? 'draft'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/job/${job['id']}'),
                      ),
                    );
                  },
                ),
        );
      },
    ),
  );
}
