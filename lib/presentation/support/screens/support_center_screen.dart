import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  late Future<List<Map<String, dynamic>>> _tickets;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _tickets = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await Supabase.instance.client
        .from('support_tickets')
        .select('*, support_ticket_replies(*)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  void _refresh() => setState(() => _tickets = _load());

  Future<void> _createTicket() async {
    final subject = TextEditingController();
    final description = TextEditingController();
    var category = 'other';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create support ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subject,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'account', child: Text('Account')),
                    DropdownMenuItem(
                      value: 'payments',
                      child: Text('Payments'),
                    ),
                    DropdownMenuItem(
                      value: 'projects',
                      child: Text('Projects'),
                    ),
                    DropdownMenuItem(value: 'jobs', child: Text('Jobs')),
                    DropdownMenuItem(
                      value: 'technical',
                      child: Text('Technical issue'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                TextField(
                  controller: description,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Describe the issue',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {'category': category}),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (values == null ||
        subject.text.trim().isEmpty ||
        description.text.trim().isEmpty) {
      subject.dispose();
      description.dispose();
      if (values != null && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a subject and description.')),
        );
      return;
    }
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _working = true);
    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': userId,
        'subject': subject.text.trim(),
        'category': values['category'],
        'description': description.text.trim(),
      });
      _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket submitted.')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to submit the support ticket.')),
        );
    } finally {
      subject.dispose();
      description.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reply(String ticketId) async {
    final controller = TextEditingController();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a reply'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    setState(() => _working = true);
    try {
      await Supabase.instance.client.from('support_ticket_replies').insert({
        'ticket_id': ticketId,
        'sender_id': userId,
        'message': value,
      });
      _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to send the reply.')),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Support Center'),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _working ? null : _createTicket,
      icon: const Icon(Icons.add),
      label: const Text('New ticket'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _tickets,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading tickets'),
            ),
          );
        final tickets = snapshot.data ?? const [];
        if (tickets.isEmpty)
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'You have no support tickets yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final replies =
                  (ticket['support_ticket_replies'] as List? ?? const [])
                      .cast<Map>();
              return Card(
                child: ExpansionTile(
                  title: Text(
                    ticket['subject']?.toString() ?? 'Support ticket',
                  ),
                  subtitle: Text(
                    '${ticket['category']} · ${ticket['status']} · ${replies.length} replies',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(ticket['description']?.toString() ?? ''),
                    ),
                    const Divider(),
                    if (replies.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No replies yet.'),
                      ),
                    ...replies.map(
                      (reply) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.forum_outlined),
                        title: Text(reply['message']?.toString() ?? ''),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _working || ticket['status'] == 'closed'
                            ? null
                            : () => _reply(ticket['id'] as String),
                        icon: const Icon(Icons.reply),
                        label: const Text('Reply'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
