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
  final _search = TextEditingController();
  final Set<String> _favoriteIds = {};
  bool _availableOnly = false;
  bool _favoritesOnly = false;
  String _experience = 'Any';
  _FreelancerSort _sort = _FreelancerSort.newest;

  @override
  void initState() {
    super.initState();
    _freelancers = _loadFreelancers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadFreelancers() async {
    final client = Supabase.instance.client;
    final response = await client.rpc('get_discoverable_freelancers');
    final rows = (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final userId = client.auth.currentUser?.id;
    if (rows.isEmpty || userId == null) return rows;
    final ids = rows.map((row) => row['id']).whereType<String>().toList();
    final extras = await client
        .from('freelancer_profiles')
        .select('user_id, rating, hourly_rate, city, district, is_available')
        .inFilter('user_id', ids);
    final details = {
      for (final row in (extras as List).cast<Map>())
        row['user_id'].toString(): Map<String, dynamic>.from(row),
    };
    for (final row in rows) {
      row.addAll(details[row['id'].toString()] ?? const {});
    }
    final saved = await client
        .from('client_favorite_freelancers')
        .select('freelancer_id')
        .eq('client_id', userId);
    _favoriteIds
      ..clear()
      ..addAll((saved as List).map((row) => row['freelancer_id'].toString()));
    return rows;
  }

  Future<void> _refresh() async {
    final request = _loadFreelancers();
    setState(() => _freelancers = request);
    await request;
  }

  Future<void> _toggleFavorite(String freelancerId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final wasSaved = _favoriteIds.contains(freelancerId);
    try {
      final table = Supabase.instance.client.from(
        'client_favorite_freelancers',
      );
      if (wasSaved) {
        await table
            .delete()
            .eq('client_id', userId)
            .eq('freelancer_id', freelancerId);
      } else {
        await table.insert({
          'client_id': userId,
          'freelancer_id': freelancerId,
        });
      }
      if (mounted)
        setState(
          () => wasSaved
              ? _favoriteIds.remove(freelancerId)
              : _favoriteIds.add(freelancerId),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update favorites.')),
        );
    }
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> source) {
    final term = _search.text.trim().toLowerCase();
    final results = source.where((person) {
      final searchable = [
        person['full_name'],
        person['title'],
        person['primary_skill'],
        person['secondary_skills'],
        person['languages'],
        person['city'],
        person['district'],
      ].join(' ').toLowerCase();
      final experience = (person['years_experience'] as num?)?.toDouble() ?? 0;
      final experienceMatches = switch (_experience) {
        '0–2 years' => experience <= 2,
        '3–5 years' => experience >= 3 && experience <= 5,
        '6+ years' => experience >= 6,
        _ => true,
      };
      final availability =
          person['availability']?.toString().toLowerCase() ?? '';
      final available =
          person['is_available'] == true ||
          (availability.contains('available') &&
              !availability.contains('unavailable'));
      return (term.isEmpty || searchable.contains(term)) &&
          (!_availableOnly || available) &&
          (!_favoritesOnly || _favoriteIds.contains(person['id'])) &&
          experienceMatches;
    }).toList();
    if (_sort != _FreelancerSort.newest)
      results.sort((a, b) {
        final aRating = (a['rating'] as num?)?.toDouble() ?? 0;
        final bRating = (b['rating'] as num?)?.toDouble() ?? 0;
        final aRate = (a['hourly_rate'] as num?)?.toDouble() ?? 0;
        final bRate = (b['hourly_rate'] as num?)?.toDouble() ?? 0;
        final aExperience = (a['years_experience'] as num?)?.toDouble() ?? 0;
        final bExperience = (b['years_experience'] as num?)?.toDouble() ?? 0;
        return switch (_sort) {
          _FreelancerSort.newest => 0,
          _FreelancerSort.rating => bRating.compareTo(aRating),
          _FreelancerSort.rate => aRate.compareTo(bRate),
          _FreelancerSort.experience => bExperience.compareTo(aExperience),
        };
      });
    return results;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find Freelancers')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search name, skill, experience, or location',
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Available'),
                selected: _availableOnly,
                onSelected: (value) => setState(() => _availableOnly = value),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Favorites'),
                selected: _favoritesOnly,
                onSelected: (value) => setState(() => _favoritesOnly = value),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _experience,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'Any', child: Text('Any experience')),
                  DropdownMenuItem(
                    value: '0–2 years',
                    child: Text('0–2 years'),
                  ),
                  DropdownMenuItem(
                    value: '3–5 years',
                    child: Text('3–5 years'),
                  ),
                  DropdownMenuItem(value: '6+ years', child: Text('6+ years')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _experience = value);
                },
              ),
              const SizedBox(width: 8),
              DropdownButton<_FreelancerSort>(
                value: _sort,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(
                    value: _FreelancerSort.newest,
                    child: Text('Newest'),
                  ),
                  DropdownMenuItem(
                    value: _FreelancerSort.rating,
                    child: Text('Top rated'),
                  ),
                  DropdownMenuItem(
                    value: _FreelancerSort.rate,
                    child: Text('Rate: low to high'),
                  ),
                  DropdownMenuItem(
                    value: _FreelancerSort.experience,
                    child: Text('Most experience'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sort = value);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _freelancers,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(
                  child: OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                );
              final freelancers = _filtered(snapshot.data ?? const []);
              if (freelancers.isEmpty)
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: const [
                      SizedBox(height: 180),
                      Center(
                        child: Text('No matching freelancer profiles found.'),
                      ),
                    ],
                  ),
                );
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: freelancers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final freelancer = freelancers[index];
                    final skills =
                        ((freelancer['secondary_skills'] as List?) ??
                                (freelancer['languages'] as List?) ??
                                const [])
                            .map((skill) => skill.toString())
                            .where((skill) => skill.isNotEmpty)
                            .take(4)
                            .toList();
                    final name =
                        freelancer['full_name'] as String? ?? 'Freelancer';
                    final avatarUrl = freelancer['avatar_url'] as String?;
                    final id = freelancer['id'].toString();
                    final rating =
                        (freelancer['rating'] as num?)?.toDouble() ?? 0;
                    final rate = (freelancer['hourly_rate'] as num?)
                        ?.toDouble();
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
                            Text(
                              '★ ${rating.toStringAsFixed(1)} · ${freelancer['years_experience'] ?? 0} years experience${rate == null ? '' : ' · ₹${rate.toStringAsFixed(0)}/hr'}',
                            ),
                            Text(
                              '${freelancer['city'] ?? freelancer['district'] ?? 'Location not set'} · ${freelancer['availability'] ?? 'Availability not set'}',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: _favoriteIds.contains(id)
                              ? 'Remove favorite'
                              : 'Add favorite',
                          onPressed: () => _toggleFavorite(id),
                          icon: Icon(
                            _favoriteIds.contains(id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _favoriteIds.contains(id)
                                ? Colors.red
                                : null,
                          ),
                        ),
                        onTap: () => context.push('/freelancer/$id'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
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

enum _FreelancerSort { newest, rating, rate, experience }
