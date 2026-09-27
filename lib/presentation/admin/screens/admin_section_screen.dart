import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSectionScreen extends StatefulWidget {
  final String section;

  const AdminSectionScreen({super.key, required this.section});

  @override
  State<AdminSectionScreen> createState() => _AdminSectionScreenState();
}

class _AdminSectionScreenState extends State<AdminSectionScreen> {
  late Future<List<Map<String, dynamic>>> _items;
  final _search = TextEditingController();
  String _statusFilter = 'All statuses';
  String _roleFilter = 'All roles';
  String _verificationFilter = 'All verification';

  @override
  void initState() {
    super.initState();
    _items = _loadItems();
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final client = Supabase.instance.client;
    final section = widget.section;
    final rows = section == 'users'
        ? await client
              .from('profiles')
              .select(
                'id, full_name, email, user_type, account_status, verification_status, created_at',
              )
              .order('created_at', ascending: false)
              .limit(50)
        : section == 'jobs'
        ? await client
              .from('jobs')
              .select('id, title, status, budget_min, budget_max, created_at')
              .order('created_at', ascending: false)
              .limit(50)
        : section == 'projects'
        ? await client
              .from('projects')
              .select(
                'id, title, status, total_amount, payment_status, created_at',
              )
              .order('created_at', ascending: false)
              .limit(50)
        : section == 'transactions'
        ? await client
              .from('project_payment_transactions')
              .select(
                'transaction_id, project_name, amount, payment_method, payment_status, utr, created_at',
              )
              .order('created_at', ascending: false)
              .limit(50)
        : section == 'payment-methods'
        ? await client
              .from('freelancer_payment_methods')
              .select(
                'user_id, upi_id, account_holder_name, qr_code_path, status, updated_at',
              )
              .order('updated_at', ascending: false)
              .limit(100)
        : section == 'reports'
        ? await client
              .from('reports')
              .select(
                'id, target_type, category, status, created_at, description',
              )
              .order('created_at', ascending: false)
              .limit(50)
        : section == 'support'
        ? await client
              .from('support_tickets')
              .select('*, support_ticket_replies(*)')
              .order('updated_at', ascending: false)
              .limit(100)
        : <Map<String, dynamic>>[];

    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  void _refresh() => setState(() => _items = _loadItems());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _manageAdminRecord(Map<String, dynamic> item) async {
    if (widget.section == 'users' &&
        (item['user_type'] == 'admin' ||
            item['id'] == Supabase.instance.client.auth.currentUser?.id)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_titleForItem(item)),
          content: const Text(
            'Administrator accounts cannot be suspended from this panel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final currentStatus =
        item[widget.section == 'users' ? 'account_status' : 'status']
            ?.toString();
    const manageableProjectStatuses = {'active', 'on_hold', 'disputed'};
    if ((widget.section == 'jobs' &&
            currentStatus != 'open' &&
            currentStatus != 'paused') ||
        (widget.section == 'projects' &&
            !manageableProjectStatuses.contains(currentStatus))) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This record is read-only in its current workflow state.',
            ),
          ),
        );
      return;
    }
    final statuses = switch (widget.section) {
      'users' => const ['active', 'suspended'],
      'jobs' => const ['open', 'paused', 'closed'],
      'projects' => const ['active', 'on_hold', 'disputed'],
      _ => const <String>[],
    };
    if (statuses.isEmpty) return;
    final field = widget.section == 'users' ? 'account_status' : 'status';
    var status =
        item[field]?.toString() ??
        (widget.section == 'users' ? 'active' : statuses.first);
    if (!statuses.contains(status)) status = statuses.first;
    final reason = TextEditingController();
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_titleForItem(item)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current status: ${item[field] ?? (widget.section == 'users' ? 'active' : 'unknown')}',
              ),
              DropdownButton<String>(
                value: status,
                isExpanded: true,
                items: statuses
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => status = value);
                },
              ),
              TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for audit log',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, status),
              child: const Text('Apply action'),
            ),
          ],
        ),
      ),
    );
    final reasonText = reason.text.trim();
    reason.dispose();
    if (selected == null) return;
    final section = widget.section;
    final rpc = section == 'users'
        ? 'admin_set_account_status'
        : section == 'jobs'
        ? 'admin_moderate_job'
        : 'admin_review_project';
    final idParam = section == 'users'
        ? 'user_id_input'
        : section == 'jobs'
        ? 'job_id_input'
        : 'project_id_input';
    try {
      await Supabase.instance.client.rpc(
        rpc,
        params: {
          idParam: item['id'],
          'status_input': selected,
          'reason_input': reasonText,
        },
      );
      _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Updated status to ${selected.replaceAll('_', ' ')}.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to apply this admin action.')),
        );
    }
  }

  Future<void> _manageSupportTicket(Map<String, dynamic> ticket) async {
    final reply = TextEditingController();
    var status = ticket['status']?.toString() ?? 'open';
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ticket['subject']?.toString() ?? 'Support ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket['description']?.toString() ?? ''),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In progress'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                TextField(
                  controller: reply,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reply to user (optional)',
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
              onPressed: () => Navigator.pop(context, {
                'status': status,
                'reply': reply.text.trim(),
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    reply.dispose();
    if (values == null) return;
    try {
      final client = Supabase.instance.client;
      await client
          .from('support_tickets')
          .update({
            'status': values['status'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', ticket['id']);
      final message = values['reply'] ?? '';
      final adminId = client.auth.currentUser?.id;
      if (message.isNotEmpty && adminId != null) {
        await client.from('support_ticket_replies').insert({
          'ticket_id': ticket['id'],
          'sender_id': adminId,
          'message': message,
        });
      }
      _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update this support ticket.'),
          ),
        );
    }
  }

  Future<void> _reviewPayment(
    Map<String, dynamic> transaction,
    String decision,
  ) async {
    String? reason;
    if (decision == 'rejected') {
      final controller = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject payment confirmation'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null || reason.isEmpty) return;
    }
    try {
      await Supabase.instance.client.rpc(
        'review_project_payment',
        params: {
          'transaction_id_input': transaction['transaction_id'],
          'decision_input': decision,
          'rejection_reason_input': reason,
        },
      );
      _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'verified'
                  ? 'Payment verified.'
                  : 'Payment rejected.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to review this payment.')),
        );
    }
  }

  Future<void> _showPayment(Map<String, dynamic> item) async {
    final canReview =
        item['payment_status'] == 'under_review' ||
        item['payment_status'] == 'payment_submitted';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['project_name']?.toString() ?? 'Payment'),
        content: SingleChildScrollView(
          child: SelectableText(
            item.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (canReview)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reviewPayment(item, 'rejected');
              },
              child: const Text('Reject'),
            ),
          if (canReview)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _reviewPayment(item, 'verified');
              },
              child: const Text('Verify payment'),
            ),
        ],
      ),
    );
  }

  Future<void> _reviewPayoutAccount(
    Map<String, dynamic> item,
    String decision,
  ) async {
    try {
      await Supabase.instance.client.rpc(
        'review_freelancer_payment_method',
        params: {
          'freelancer_id_input': item['user_id'],
          'decision_input': decision,
        },
      );
      _refresh();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              decision == 'verified'
                  ? 'Payout account verified.'
                  : 'Payout account returned to pending.',
            ),
          ),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to review this payout account.'),
          ),
        );
    }
  }

  Future<void> _showPayoutAccount(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Freelancer payout account'),
        content: SelectableText(
          'UPI: ${item['upi_id'] ?? ''}\nAccount holder: ${item['account_holder_name'] ?? ''}\nStatus: ${item['status'] ?? ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (item['status'] != 'verified')
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _reviewPayoutAccount(item, 'verified');
              },
              child: const Text('Verify details'),
            ),
        ],
      ),
    );
  }

  Future<void> _showReport(Map<String, dynamic> item) async {
    var status = item['status']?.toString() ?? 'open';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item['category']?.toString() ?? 'Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['description']?.toString() ?? 'No description provided.',
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: status,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In progress'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
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
              onPressed: () => Navigator.pop(context, status),
              child: const Text('Save status'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    try {
      await Supabase.instance.client
          .from('reports')
          .update({
            'status': selected,
            if (selected == 'resolved')
              'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', item['id']);
      _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update report status.')),
        );
    }
  }

  String get _title => switch (widget.section) {
    'users' => 'Users Management',
    'jobs' => 'Jobs Management',
    'projects' => 'Projects Management',
    'transactions' => 'Transactions & Payments',
    'payment-methods' => 'Freelancer Payout Accounts',
    'reports' => 'Reports & Disputes',
    'support' => 'Support Inbox',
    _ => 'Admin Section',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.section == 'support') {
      return Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _items,
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
                child: Text('No support tickets are waiting.'),
              );
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  final replies =
                      ticket['support_ticket_replies'] as List? ?? const [];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.support_agent_outlined),
                      title: Text(
                        ticket['subject']?.toString() ?? 'Support ticket',
                      ),
                      subtitle: Text(
                        '${ticket['category']} · ${ticket['status']} · ${replies.length} replies',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _manageSupportTicket(ticket),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _items,
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
                    const Text('Unable to load this admin section.'),
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

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No records found.'));
          }
          final statuses = widget.section == 'users'
              ? const ['All statuses', 'active', 'suspended']
              : widget.section == 'jobs'
              ? const [
                  'All statuses',
                  'open',
                  'paused',
                  'closed',
                  'in_progress',
                  'completed',
                ]
              : widget.section == 'projects'
              ? const [
                  'All statuses',
                  'active',
                  'on_hold',
                  'completed',
                  'disputed',
                  'cancelled',
                ]
              : const ['All statuses'];
          final visibleItems = items.where((item) {
            final term = _search.text.trim().toLowerCase();
            final matchesTerm =
                term.isEmpty ||
                item.values.any(
                  (value) => value.toString().toLowerCase().contains(term),
                );
            final status =
                (item[widget.section == 'users'
                            ? 'account_status'
                            : 'status'] ??
                        'active')
                    .toString();
            final role = item['user_type']?.toString() ?? '';
            return matchesTerm &&
                (_statusFilter == 'All statuses' || status == _statusFilter) &&
                (widget.section != 'users' ||
                    _roleFilter == 'All roles' ||
                    role == _roleFilter) &&
                (widget.section != 'users' ||
                    _verificationFilter == 'All verification' ||
                    item['verification_status']?.toString() ==
                        _verificationFilter);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search records',
                  ),
                ),
              ),
              if (statuses.length > 1 || widget.section == 'users')
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 20,
                      children: [
                        if (statuses.length > 1)
                          DropdownButton<String>(
                            value: _statusFilter,
                            items: statuses
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.replaceAll('_', ' ')),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _statusFilter = value);
                            },
                          ),
                        if (widget.section == 'users')
                          DropdownButton<String>(
                            value: _roleFilter,
                            items:
                                const [
                                      'All roles',
                                      'freelancer',
                                      'client',
                                      'admin',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value.replaceAll('_', ' ')),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _roleFilter = value);
                            },
                          ),
                        if (widget.section == 'users')
                          DropdownButton<String>(
                            value: _verificationFilter,
                            items:
                                const [
                                      'All verification',
                                      'unverified',
                                      'pending',
                                      'approved',
                                      'rejected',
                                      'reupload_required',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value.replaceAll('_', ' ')),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value != null)
                                setState(() => _verificationFilter = value);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: visibleItems.isEmpty
                    ? const Center(
                        child: Text('No records match these filters.'),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: visibleItems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return Card(
                              child: ListTile(
                                title: Text(_titleForItem(item)),
                                subtitle: Text(_subtitleForItem(item)),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () =>
                                    const {
                                      'users',
                                      'jobs',
                                      'projects',
                                    }.contains(widget.section)
                                    ? _manageAdminRecord(item)
                                    : widget.section == 'transactions'
                                    ? _showPayment(item)
                                    : widget.section == 'payment-methods'
                                    ? _showPayoutAccount(item)
                                    : widget.section == 'reports'
                                    ? _showReport(item)
                                    : showDialog<void>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(_titleForItem(item)),
                                          content: SingleChildScrollView(
                                            child: SelectableText(
                                              item.entries
                                                  .map(
                                                    (entry) =>
                                                        '${entry.key}: ${entry.value}',
                                                  )
                                                  .join('\n'),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      ),
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

  String _titleForItem(Map<String, dynamic> item) {
    return switch (widget.section) {
      'users' => item['full_name'] as String? ?? 'User',
      'jobs' => item['title'] as String? ?? 'Job',
      'projects' => item['title'] as String? ?? 'Project',
      'transactions' => item['transaction_id'] as String? ?? 'Transaction',
      'payment-methods' =>
        item['account_holder_name'] as String? ?? 'Payout account',
      'reports' => item['category'] as String? ?? 'Report',
      _ => 'Record',
    };
  }

  String _subtitleForItem(Map<String, dynamic> item) {
    return switch (widget.section) {
      'users' =>
        '${item['email'] ?? ''} | ${item['user_type'] ?? ''} | ${item['account_status'] ?? 'active'}',
      'jobs' =>
        '${item['status'] ?? ''} | ${item['budget_min'] ?? ''} - ${item['budget_max'] ?? ''}',
      'projects' => '${item['status'] ?? ''} | ${item['payment_status'] ?? ''}',
      'transactions' =>
        '${item['payment_status'] ?? ''} | Rs. ${item['amount'] ?? ''}',
      'payment-methods' => '${item['upi_id'] ?? ''} | ${item['status'] ?? ''}',
      'reports' => '${item['status'] ?? ''} | ${item['target_type'] ?? ''}',
      _ => '',
    };
  }
}
