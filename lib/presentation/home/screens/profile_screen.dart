import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/route_names.dart';
import '../../../core/enums/enums.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Map<String, dynamic>> _profile;

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

  Future<Map<String, dynamic>> _loadProfile() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw Exception('User not found');
    }

    final client = Supabase.instance.client;
    final profileRow = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (profileRow == null) {
      throw Exception('Profile not found');
    }

    final profile = Map<String, dynamic>.from(profileRow as Map);
    final type = UserType.fromString(
      profile['user_type'] as String? ?? UserType.rolePending.value,
    );
    final avatarUrl = await _resolveAvatar(profile['avatar_url'] as String?);

    Map<String, dynamic>? roleProfile;
    List<Map<String, dynamic>> portfolio = [];
    List<Map<String, dynamic>> education = [];
    List<Map<String, dynamic>> experience = [];

    if (type == UserType.client) {
      final row = await client
          .from('client_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      roleProfile = row == null ? null : Map<String, dynamic>.from(row as Map);
    } else if (type == UserType.freelancer) {
      final row = await client
          .from('freelancer_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      roleProfile = row == null ? null : Map<String, dynamic>.from(row as Map);

      final portfolioRows = await client
          .from('portfolio_items')
          .select()
          .eq('freelancer_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);
      portfolio = (portfolioRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final educationRows = await client
          .from('education')
          .select()
          .eq('freelancer_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);
      education = (educationRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final experienceRows = await client
          .from('experience')
          .select()
          .eq('freelancer_id', user.id)
          .order('created_at', ascending: false)
          .limit(10);
      experience = (experienceRows as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    }

    return {
      'profile': profile,
      'roleProfile': roleProfile,
      'portfolio': portfolio,
      'education': education,
      'experience': experience,
      'avatarUrl': avatarUrl,
      'type': type,
    };
  }

  void _refresh() => setState(() => _profile = _loadProfile());

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Unable to load profile.')),
        data: (account) {
          if (account == null) {
            return const Center(child: Text('Please sign in again.'));
          }
          return FutureBuilder<Map<String, dynamic>>(
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
                        const Text('Unable to load your profile details.'),
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

              final data = snapshot.data!;
              final profile = data['profile'] as Map<String, dynamic>;
              final roleProfile = data['roleProfile'] as Map<String, dynamic>?;
              final avatarUrl = data['avatarUrl'] as String?;
              final type = data['type'] as UserType;
              final verification = VerificationStatus.fromString(
                profile['verification_status'] as String? ?? '',
              );

              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 44,
                        backgroundImage: avatarUrl != null
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl == null
                            ? Text(
                                account.initials.isEmpty
                                    ? '?'
                                    : account.initials,
                                style: Theme.of(context).textTheme.titleLarge,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        profile['full_name'] as String? ?? 'WorkSphere member',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(child: Text(profile['email'] as String? ?? '')),
                    const SizedBox(height: 12),
                    Center(
                      child: Chip(
                        avatar: Icon(
                          verification.isVerified
                              ? Icons.verified
                              : Icons.verified_outlined,
                          color: verification.isVerified ? Colors.green : null,
                        ),
                        label: Text(
                          verification.isVerified
                              ? 'Verified'
                              : verification.label,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _infoCard(context, 'Account details', [
                      _infoTile('Role', type.label),
                      _infoTile(
                        'Date of birth',
                        _formatDate(profile['date_of_birth'] as String?),
                      ),
                      _infoTile(
                        'Location',
                        _compact([
                          profile['city'],
                          profile['state'],
                          profile['country'],
                        ]),
                      ),
                    ]),
                    if (type == UserType.freelancer && roleProfile != null) ...[
                      _infoCard(context, 'Freelancer profile', [
                        _infoTile('Headline', roleProfile['title'] as String?),
                        _infoTile('Bio', roleProfile['bio'] as String?),
                        _infoTile(
                          'Skills',
                          _listText(roleProfile['languages']),
                        ),
                        _infoTile(
                          'Availability',
                          roleProfile['availability'] as String?,
                        ),
                        _infoTile(
                          'Preferred work type',
                          roleProfile['preferred_work_type'] as String?,
                        ),
                        _infoTile(
                          'Experience',
                          roleProfile['experience_level'] as String?,
                        ),
                        _infoTile(
                          'Certifications',
                          roleProfile['certifications'] as String?,
                        ),
                        _infoTile(
                          'Portfolio',
                          roleProfile['portfolio_url'] as String?,
                        ),
                        _infoTile(
                          'Hourly rate',
                          _formatCurrency(roleProfile['hourly_rate']),
                        ),
                      ]),
                      _listCard(
                        context,
                        'Portfolio',
                        (data['portfolio'] as List)
                            .cast<Map<String, dynamic>>(),
                        (item) =>
                            '${item['title'] ?? ''}\n${item['description'] ?? ''}',
                      ),
                      _listCard(
                        context,
                        'Education',
                        (data['education'] as List)
                            .cast<Map<String, dynamic>>(),
                        (item) =>
                            '${item['degree'] ?? ''} • ${item['institution'] ?? ''}',
                      ),
                      _listCard(
                        context,
                        'Experience',
                        (data['experience'] as List)
                            .cast<Map<String, dynamic>>(),
                        (item) =>
                            '${item['title'] ?? ''} • ${item['company'] ?? ''}',
                      ),
                    ] else if (type == UserType.client &&
                        roleProfile != null) ...[
                      _infoCard(context, 'Client profile', [
                        _infoTile(
                          'Company',
                          roleProfile['company_name'] as String?,
                        ),
                        _infoTile(
                          'Industry',
                          roleProfile['industry'] as String?,
                        ),
                        _infoTile(
                          'Company size',
                          roleProfile['company_size'] as String?,
                        ),
                        _infoTile(
                          'Description',
                          roleProfile['description'] as String?,
                        ),
                        _infoTile('Website', roleProfile['website'] as String?),
                        _infoTile(
                          'Location',
                          _compact([
                            roleProfile['city'],
                            roleProfile['district'],
                          ]),
                        ),
                        _infoTile(
                          'Jobs posted',
                          roleProfile['jobs_posted']?.toString(),
                        ),
                        _infoTile(
                          'Total spending',
                          _formatCurrency(roleProfile['total_spent']),
                        ),
                        _infoTile(
                          'Rating',
                          (roleProfile['reviews_count'] as num? ?? 0) > 0
                              ? '${roleProfile['rating'] ?? '—'} (${roleProfile['reviews_count']} reviews)'
                              : null,
                        ),
                      ]),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.push(RouteNames.editProfile),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.push(RouteNames.verification),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('View verification'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _infoCard(BuildContext context, String title, List<Widget> children) {
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
    BuildContext context,
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
              const Text('No records saved yet.')
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

  Widget _infoTile(String label, String? value) {
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

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return 'Not added';
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  String _formatCurrency(Object? value) {
    if (value == null) return 'Not added';
    return '₹${value.toString()}';
  }
}
