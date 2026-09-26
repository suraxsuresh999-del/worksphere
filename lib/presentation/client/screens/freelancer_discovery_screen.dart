import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FreelancerDiscoveryScreen extends StatefulWidget {
  const FreelancerDiscoveryScreen({super.key});

  @override
  State<FreelancerDiscoveryScreen> createState() =>
      _FreelancerDiscoveryScreenState();
}

class _FreelancerDiscoveryScreenState extends State<FreelancerDiscoveryScreen> {
  late Future<List<Map<String, dynamic>>> _freelancers;

  @override
  void initState() {
    super.initState();
    _freelancers = _loadFreelancers();
  }

  Future<List<Map<String, dynamic>>> _loadFreelancers() async {
    final rows = await Supabase.instance.client.rpc(
      'get_discoverable_freelancers',
    );
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _refresh() {
    final request = _loadFreelancers();
    setState(() => _freelancers = request);
    return request.then<void>((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find Freelancers')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _freelancers,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          );
        }
        final freelancers = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: freelancers.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 180),
                    Center(
                      child: Text('No freelancer profiles are available yet.'),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: freelancers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final freelancer = freelancers[index];
                    final skills =
                        ((freelancer['languages'] as List?) ??
                                (freelancer['secondary_skills'] as List?) ??
                                const [])
                            .map((skill) => skill.toString())
                            .where((skill) => skill.isNotEmpty)
                            .take(4)
                            .toList();
                    final name =
                        freelancer['full_name'] as String? ?? 'Freelancer';
                    final avatarUrl = freelancer['avatar_url'] as String?;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundImage:
                              avatarUrl != null && avatarUrl.startsWith('http')
                              ? NetworkImage(avatarUrl)
                              : null,
                          child:
                              avatarUrl != null && avatarUrl.startsWith('http')
                              ? null
                              : Text(_initials(name)),
                        ),
                        title: Text(name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((freelancer['title'] as String? ?? '')
                                .isNotEmpty)
                              Text(freelancer['title'] as String),
                            if (skills.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(skills.join(' · ')),
                              ),
                            if ((freelancer['availability'] as String? ?? '')
                                .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  freelancer['availability'] as String,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            context.push('/freelancer/${freelancer['id']}'),
                      ),
                    );
                  },
                ),
        );
      },
    ),
  );

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.length == 1
        ? parts.first[0].toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
