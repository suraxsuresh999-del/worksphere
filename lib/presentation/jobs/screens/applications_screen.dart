import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});
  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late Future<List<Map<String, dynamic>>> _applications;
  String? _status;

  @override
  void initState() {
    super.initState();
    _applications = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    var query = Supabase.instance.client
        .from('job_applications')
        .select(
          'id, job_id, bid_amount, estimated_duration, status, created_at, jobs(title)',
        )
        .eq('freelancer_id', user.id);
    if (_status != null) query = query.eq('status', _status!);
    final rows = await query.order('created_at', ascending: false);
    final items = (rows as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final ids = items.map((item) => item['id']).whereType<String>().toList();
    if (ids.isNotEmpty) {
      final offers = await Supabase.instance.client
          .from('job_offers')
          .select(
            'id, application_id, amount, duration_text, message, status, created_at',
          )
          .inFilter('application_id', ids)
          .order('created_at', ascending: false);
      final byApplication = <String, List<Map<String, dynamic>>>{};
      for (final row in (offers as List).cast<Map>()) {
        final offer = Map<String, dynamic>.from(row);
        byApplication
            .putIfAbsent(offer['application_id'].toString(), () => [])
            .add(offer);
      }
      for (final item in items)
        item['offers'] =
            byApplication[item['id'].toString()] ?? <Map<String, dynamic>>[];
    }
    return items;
  }

  void _reload([String? status]) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _applications = _load();
    });
  }

  Future<void> _respondToOffer(
    BuildContext context,
    Map<String, dynamic> offer,
    String decision,
  ) async {
    try {
      final projectId = await Supabase.instance.client.rpc(
        'respond_to_job_offer',
        params: {'offer_id_input': offer['id'], 'decision_input': decision},
      );
      _reload(_status);
      if (decision == 'accepted' && projectId != null && context.mounted) {
        context.push('/project/$projectId');
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'accepted'
                  ? 'Offer accepted and project created.'
                  : 'Offer declined.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to respond to this offer.')),
        );
    }
  }

  Future<void> _refresh() async {
    final request = _load();
    setState(() => _applications = request);
    await request;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My applications')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _applications,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: () => _reload(_status),
              child: const Text('Try again'),
            ),
          );
        final items = snapshot.data ?? [];
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String?>(
                showSelectedIcon: false,
                selected: {_status},
                onSelectionChanged: (value) => _reload(value.first),
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: 'pending', label: Text('Pending')),
                  ButtonSegment(
                    value: 'shortlisted',
                    label: Text('Shortlisted'),
                  ),
                  ButtonSegment(value: 'accepted', label: Text('Accepted')),
                  ButtonSegment(value: 'rejected', label: Text('Rejected')),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send_outlined, size: 48),
                          const SizedBox(height: 12),
                          const Text("You haven't applied to any jobs yet."),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/jobs'),
                            child: const Text('Find jobs'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final job = item['jobs'] as Map?;
                          final status =
                              item['status']?.toString() ?? 'pending';
                          final date = DateTime.tryParse(
                            item['created_at']?.toString() ?? '',
                          );
                          final offers =
                              (item['offers'] as List?)
                                  ?.cast<Map<String, dynamic>>() ??
                              const <Map<String, dynamic>>[];
                          return Card(
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(
                                    job?['title']?.toString() ?? 'Job',
                                  ),
                                  subtitle: Text(
                                    '₹${item['bid_amount'] ?? '-'} · ${item['estimated_duration'] ?? 'Delivery time not specified'}\nApplied ${date == null ? 'recently' : timeago.format(date)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: _StatusBadge(status: status),
                                  onTap: () =>
                                      context.push('/job/${item['job_id']}'),
                                ),
                                for (final offer in offers.where(
                                  (offer) => offer['status'] == 'pending',
                                ))
                                  ListTile(
                                    leading: const Icon(
                                      Icons.local_offer_outlined,
                                    ),
                                    title: Text(
                                      'Offer: ₹${offer['amount']} · ${offer['duration_text'] ?? 'Duration not specified'}',
                                    ),
                                    subtitle: Text(
                                      offer['message']?.toString() ??
                                          'Review the client offer.',
                                    ),
                                    isThreeLine:
                                        (offer['message']?.toString() ?? '')
                                            .isNotEmpty,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Decline offer',
                                          onPressed: () => _respondToOffer(
                                            context,
                                            offer,
                                            'declined',
                                          ),
                                          icon: const Icon(Icons.close),
                                        ),
                                        IconButton(
                                          tooltip: 'Accept offer',
                                          onPressed: () => _respondToOffer(
                                            context,
                                            offer,
                                            'accepted',
                                          ),
                                          icon: const Icon(
                                            Icons.check_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' => Colors.green,
      'rejected' => Colors.red,
      'shortlisted' => Colors.orange,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Chip(
      label: Text(status.replaceAll('_', ' ')),
      backgroundColor: color.withAlpha(25),
      side: BorderSide(color: color.withAlpha(100)),
    );
  }
}
