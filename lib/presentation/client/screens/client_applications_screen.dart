import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientApplicationsScreen extends StatefulWidget {
  const ClientApplicationsScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<ClientApplicationsScreen> createState() =>
      _ClientApplicationsScreenState();
}

class _ClientApplicationsScreenState extends State<ClientApplicationsScreen> {
  late Future<_ApplicationsData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_ApplicationsData> _load() async {
    final api = Supabase.instance.client;
    final job = await api
        .from('jobs')
        .select('id, title')
        .eq('id', widget.jobId)
        .maybeSingle();
    if (job == null)
      return const _ApplicationsData(title: 'Job', applications: []);
    final rows = await api
        .from('job_applications')
        .select(
          'id, freelancer_id, cover_letter, bid_amount, estimated_duration, status, created_at',
        )
        .eq('job_id', widget.jobId)
        .order('created_at', ascending: false);
    final applications = (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final offers = await api
        .from('job_offers')
        .select('id, application_id, amount, duration_text, status, created_at')
        .eq('job_id', widget.jobId)
        .order('created_at', ascending: false);
    final offersByApplication = <String, List<Map<String, dynamic>>>{};
    for (final rawOffer in (offers as List).cast<Map>()) {
      final offer = Map<String, dynamic>.from(rawOffer);
      offersByApplication
          .putIfAbsent(offer['application_id'].toString(), () => [])
          .add(offer);
    }
    for (final application in applications) {
      application['offers'] =
          offersByApplication[application['id'].toString()] ??
          <Map<String, dynamic>>[];
    }
    final ids = applications
        .map((row) => row['freelancer_id'])
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty)
      return _ApplicationsData(
        title: job['title']?.toString() ?? 'Job',
        applications: applications,
      );

    final result = await Future.wait([
      api
          .from('profiles')
          .select('id, full_name, avatar_url')
          .inFilter('id', ids),
      api
          .from('freelancer_profiles')
          .select('user_id, title, primary_skill, years_experience, rating')
          .inFilter('user_id', ids),
    ]);
    final profiles = {
      for (final row in (result[0] as List).cast<Map>())
        row['id'].toString(): Map<String, dynamic>.from(row),
    };
    final details = {
      for (final row in (result[1] as List).cast<Map>())
        row['user_id'].toString(): Map<String, dynamic>.from(row),
    };
    for (final application in applications) {
      final id = application['freelancer_id'].toString();
      application['profile'] = profiles[id] ?? const {};
      application['freelancer'] = details[id] ?? const {};
    }
    return _ApplicationsData(
      title: job['title']?.toString() ?? 'Job',
      applications: applications,
    );
  }

  Future<void> _refresh() async {
    final request = _load();
    if (!mounted) return;
    setState(() => _data = request);
    await request;
  }

  Future<void> _reviewApplication(String applicationId, String decision) async {
    try {
      await Supabase.instance.client.rpc(
        'review_job_application',
        params: {
          'application_id_input': applicationId,
          'decision_input': decision,
        },
      );
      await _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'shortlisted'
                  ? 'Applicant shortlisted.'
                  : 'Application declined.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update this application.')),
        );
    }
  }

  Future<void> _sendOffer(Map<String, dynamic> application) async {
    final amount = TextEditingController(
      text: application['bid_amount']?.toString() ?? '',
    );
    final duration = TextEditingController(
      text: application['estimated_duration']?.toString() ?? '',
    );
    final message = TextEditingController();
    final values = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send offer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Offer amount (INR)',
                ),
              ),
              TextField(
                controller: duration,
                decoration: const InputDecoration(
                  labelText: 'Delivery duration',
                ),
              ),
              TextField(
                controller: message,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send offer'),
          ),
        ],
      ),
    );
    if (values == true) {
      final parsed = double.tryParse(amount.text.trim());
      if (parsed == null || parsed <= 0) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid offer amount.')),
          );
      } else {
        try {
          await Supabase.instance.client.rpc(
            'create_job_offer',
            params: {
              'application_id_input': application['id'],
              'amount_input': parsed,
              'duration_input': duration.text.trim(),
              'message_input': message.text.trim(),
            },
          );
          await _refresh();
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Offer sent to the freelancer.')),
            );
        } catch (_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to send this offer.')),
            );
        }
      }
    }
    amount.dispose();
    duration.dispose();
    message.dispose();
  }

  Future<void> _scheduleInterview(String applicationId) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null || !mounted) return;
    final scheduled = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future interview time.')),
      );
      return;
    }
    try {
      await Supabase.instance.client.rpc(
        'schedule_job_interview',
        params: {
          'application_id_input': applicationId,
          'scheduled_at_input': scheduled.toUtc().toIso8601String(),
          'notes_input': null,
        },
      );
      await _refresh();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Interview scheduled.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to schedule this interview.')),
        );
    }
  }

  Future<void> _messageFreelancer(String freelancerId) async {
    try {
      final conversationId = await Supabase.instance.client.rpc(
        'get_or_create_direct_conversation',
        params: {'other_user_id': freelancerId},
      );
      if (mounted) context.push('/chat/$conversationId');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this conversation.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Job applications')),
    body: FutureBuilder<_ApplicationsData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading applications'),
            ),
          );
        final data = snapshot.data;
        if (data == null)
          return const Center(child: Text('This job is unavailable.'));
        if (data.applications.isEmpty)
          return Center(child: Text('No applications for ${data.title} yet.'));
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.applications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final application = data.applications[index];
              final profile =
                  application['profile'] as Map<String, dynamic>? ?? const {};
              final freelancer =
                  application['freelancer'] as Map<String, dynamic>? ??
                  const {};
              final id = application['freelancer_id']?.toString() ?? '';
              final name = profile['full_name']?.toString() ?? 'Freelancer';
              final avatar = profile['avatar_url']?.toString();
              final status = application['status']?.toString() ?? 'pending';
              final canAct = status == 'pending' || status == 'shortlisted';
              final offers =
                  (application['offers'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  const <Map<String, dynamic>>[];
              final pendingOfferExists = offers.any(
                (offer) => offer['status'] == 'pending',
              );
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage:
                              avatar != null && avatar.startsWith('http')
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null || !avatar.startsWith('http')
                              ? Text(_initials(name))
                              : null,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          '${freelancer['title'] ?? freelancer['primary_skill'] ?? 'Freelancer'} · ${freelancer['years_experience'] ?? 0} years experience',
                        ),
                        trailing: Chip(
                          label: Text(status.replaceAll('_', ' ')),
                        ),
                        onTap: id.isEmpty
                            ? null
                            : () => context.push('/freelancer/$id'),
                      ),
                      const Divider(),
                      Text(
                        'Proposal · ₹${application['bid_amount'] ?? '—'} · ${application['estimated_duration'] ?? 'Delivery time not specified'}',
                      ),
                      if ((application['cover_letter']?.toString() ?? '')
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(application['cover_letter'].toString()),
                      ],
                      for (final offer in offers.take(2))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.local_offer_outlined),
                          title: Text(
                            'Offer ₹${offer['amount']} · ${offer['status']}',
                          ),
                          subtitle: Text(
                            offer['duration_text']?.toString() ?? '',
                          ),
                        ),
                      if (canAct)
                        Wrap(
                          spacing: 4,
                          runSpacing: 0,
                          children: [
                            TextButton.icon(
                              onPressed: () => _messageFreelancer(id),
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('Message'),
                            ),
                            TextButton.icon(
                              onPressed: () => _scheduleInterview(
                                application['id'].toString(),
                              ),
                              icon: const Icon(Icons.event_outlined),
                              label: const Text('Interview'),
                            ),
                            if (!pendingOfferExists)
                              TextButton.icon(
                                onPressed: () => _sendOffer(application),
                                icon: const Icon(Icons.local_offer_outlined),
                                label: const Text('Offer'),
                              ),
                            if (status == 'pending')
                              TextButton.icon(
                                onPressed: () => _reviewApplication(
                                  application['id'].toString(),
                                  'shortlisted',
                                ),
                                icon: const Icon(Icons.star_outline),
                                label: const Text('Shortlist'),
                              ),
                            TextButton.icon(
                              onPressed: () => _reviewApplication(
                                application['id'].toString(),
                                'rejected',
                              ),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: id.isEmpty
                              ? null
                              : () => context.push('/freelancer/$id'),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('View profile'),
                        ),
                      ),
                    ],
                  ),
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

class _ApplicationsData {
  const _ApplicationsData({required this.title, required this.applications});
  final String title;
  final List<Map<String, dynamic>> applications;
}
