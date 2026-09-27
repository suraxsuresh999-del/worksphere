import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/widgets/report_action.dart';

class FreelancerProfileScreen extends StatefulWidget {
  final String freelancerId;
  const FreelancerProfileScreen({super.key, required this.freelancerId});

  @override
  State<FreelancerProfileScreen> createState() =>
      _FreelancerProfileScreenState();
}

class _FreelancerProfileScreenState extends State<FreelancerProfileScreen> {
  late Future<Map<String, dynamic>?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<String?> _resolveAvatar(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http')) return path;
    try {
      return await Supabase.instance.client.storage
          .from('verification-documents')
          .createSignedUrl(path, 600);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final client = Supabase.instance.client;
    final response = await client.rpc(
      'get_public_freelancer_profile',
      params: {'freelancer_id_input': widget.freelancerId},
    );
    if (response == null) return null;
    final profile = Map<String, dynamic>.from(response as Map);
    profile['avatar_url'] = await _resolveAvatar(
      profile['avatar_url'] as String?,
    );
    final portfolioRows = await client
        .from('portfolio_items')
        .select()
        .eq('freelancer_id', widget.freelancerId)
        .order('created_at', ascending: false)
        .limit(20);
    final experienceRows = await client
        .from('experience')
        .select()
        .eq('freelancer_id', widget.freelancerId)
        .order('created_at', ascending: false)
        .limit(10);
    final reviewRows = await client
        .from('reviews')
        .select('rating, comment, created_at')
        .eq('reviewee_id', widget.freelancerId)
        .order('created_at', ascending: false)
        .limit(10);
    profile['portfolio'] = (portfolioRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    profile['experience'] = (experienceRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    profile['reviews'] = (reviewRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    return profile;
  }

  void _refresh() => setState(() => _profile = _loadProfile());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freelancer Profile'),
        actions: [
          ReportAction(
            targetType: 'freelancer',
            targetId: widget.freelancerId,
            targetName: 'freelancer',
          ),
          IconButton(
            tooltip: 'Share profile',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                uri: Uri.base.resolve('/freelancer/${widget.freelancerId}'),
                subject: 'Freelancer profile on WorkSphere',
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load freelancer profile.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('Freelancer not found.'));
          }

          final avatarUrl = profile['avatar_url'] as String?;
          final paymentMethod =
              profile['payment_method'] as Map<String, dynamic>? ?? const {};
          final verified =
              (profile['verification_status'] as String?) == 'approved';
          final hasPaymentMethod = profile['has_payment_method'] == true;
          final completion =
              (profile['profile_completion'] as num?)?.clamp(0, 100).toInt() ??
              0;
          final location = _compact([
            profile['city_profile'],
            profile['district'],
            profile['state'],
            profile['country'],
          ]);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _profileHeader(
                  context,
                  avatarUrl: avatarUrl,
                  name: profile['full_name'] as String? ?? 'Freelancer',
                  title: profile['title'] as String?,
                  bio: profile['bio'] as String?,
                  location: location,
                  verified: verified,
                  completion: completion,
                  hasPaymentMethod: hasPaymentMethod,
                ),
                _infoCard('Account details', [
                  _infoRow('Location', location),
                  _infoRow('Availability', profile['availability'] as String?),
                  _infoRow(
                    'Preferred work type',
                    profile['preferred_work_type'] as String?,
                  ),
                  _infoRow(
                    'Experience level',
                    profile['experience_level'] as String?,
                  ),
                ]),
                _infoCard('Professional expertise', [
                  _infoRow('Skills', _listText(profile['languages'])),
                  _infoRow(
                    'Certifications',
                    profile['certifications'] as String?,
                  ),
                  _infoRow(
                    'Portfolio link',
                    profile['portfolio_url'] as String?,
                  ),
                ]),
                if (hasPaymentMethod)
                  _infoCard('Payment availability', [
                    _infoRow('Status', paymentMethod['status'] as String?),
                    const Text('UPI Payment Available'),
                  ]),
                _listCard(
                  'Portfolio',
                  (profile['portfolio'] as List).cast<Map<String, dynamic>>(),
                  (item) =>
                      '${item['title'] ?? ''}\n${item['description'] ?? ''}',
                ),
                _listCard(
                  'Experience',
                  (profile['experience'] as List).cast<Map<String, dynamic>>(),
                  (item) => '${item['title'] ?? ''} • ${item['company'] ?? ''}',
                ),
                _listCard(
                  'Reviews',
                  (profile['reviews'] as List).cast<Map<String, dynamic>>(),
                  (item) =>
                      '${item['rating'] ?? ''} stars\n${item['comment'] ?? ''}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context, {
    required String? avatarUrl,
    required String name,
    required String? title,
    required String? bio,
    required String location,
    required bool verified,
    required int completion,
    required bool hasPaymentMethod,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundImage: avatarUrl == null
                      ? null
                      : NetworkImage(avatarUrl),
                  child: avatarUrl == null
                      ? Text(_initials(name), style: theme.textTheme.titleLarge)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.headlineSmall),
                      if (title != null && title.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                      if (location != 'Not added') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 16),
                            const SizedBox(width: 4),
                            Expanded(child: Text(location)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (bio != null && bio.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(bio, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    verified ? Icons.verified : Icons.verified_outlined,
                    color: verified ? Colors.green : null,
                    size: 18,
                  ),
                  label: Text(verified ? 'Verified' : 'Not verified'),
                ),
                if (hasPaymentMethod)
                  const Chip(label: Text('UPI payment available')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profile completion',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text('$completion%', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: completion / 100),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _listCard(
    String title,
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) builder,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('No records found.')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(builder(item)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              (value == null || value.trim().isEmpty) ? 'Not added' : value,
            ),
          ),
        ],
      ),
    );
  }

  String _compact(List<Object?> values) {
    final parts = values
        .where((value) => value != null && value.toString().trim().isNotEmpty)
        .map((value) => value.toString().trim())
        .toList();
    return parts.isEmpty ? 'Not added' : parts.join(', ');
  }

  String _listText(Object? value) {
    if (value is List) {
      final parts = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      return parts.isEmpty ? 'Not added' : parts.join(', ');
    }
    return value?.toString() ?? 'Not added';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
