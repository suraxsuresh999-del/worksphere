import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/widgets/report_action.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<List<Map<String, dynamic>>> _projects;

  @override
  void initState() {
    super.initState();
    _projects = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    final response = await Supabase.instance.client
        .from('projects')
        .select(
          'id, title, description, total_amount, amount_paid, start_date, deadline, status, client_id, freelancer_id',
        )
        .or('client_id.eq.${user.id},freelancer_id.eq.${user.id}')
        .order('updated_at', ascending: false);
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _projects = future);
    await future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Projects')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _projects,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading projects'),
            ),
          );
        }
        final projects = snapshot.data ?? const [];
        if (projects.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No projects yet. Projects will appear here when a client and freelancer begin working together.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = projects[index];
              final paid = (project['amount_paid'] as num?)?.toDouble() ?? 0;
              final total = (project['total_amount'] as num?)?.toDouble() ?? 0;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(child: Icon(Icons.work_outline)),
                  title: Text(project['title'] as String? ?? 'Project'),
                  subtitle: Text(
                    'Status: ${project['status'] ?? 'pending'}\nPaid: ₹${paid.toStringAsFixed(2)} of ₹${total.toStringAsFixed(2)}\nDeadline: ${_date(project['deadline'])}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/project/${project['id']}'),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  String _date(Object? value) {
    if (value == null) return 'Not set';
    final date = DateTime.tryParse(value.toString());
    return date == null
        ? 'Not set'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<_ProjectWorkspace> _workspace;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _workspace = _load();
  }

  Future<_ProjectWorkspace> _load() async {
    final client = Supabase.instance.client;
    final project = await client
        .from('projects')
        .select()
        .eq('id', widget.projectId)
        .maybeSingle();
    if (project == null) throw Exception('Project not found');
    final related = await Future.wait([
      client
          .from('milestones')
          .select()
          .eq('project_id', widget.projectId)
          .order('created_at'),
      client
          .from('project_tasks')
          .select()
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false),
      client
          .from('project_deliverables')
          .select()
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false),
      client
          .from('reviews')
          .select('reviewer_id, reviewee_id, rating, comment, created_at')
          .eq('project_id', widget.projectId)
          .order('created_at', ascending: false),
    ]);
    final userId = client.auth.currentUser?.id;
    return _ProjectWorkspace(
      project: Map<String, dynamic>.from(project),
      milestones: (related[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      tasks: (related[1] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      deliverables: (related[2] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      reviews: (related[3] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      isClient: userId != null && project['client_id'] == userId,
      currentUserId: userId ?? '',
    );
  }

  void _refresh() => setState(() => _workspace = _load());

  Future<void> _generateInvoice() async {
    try {
      final result = await Supabase.instance.client.rpc(
        'generate_project_invoice',
        params: {'project_id_input': widget.projectId},
      );
      final invoice = Map<String, dynamic>.from(result as Map);
      if (mounted) context.push('/invoice/${invoice['id']}');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'An invoice is available after the project is completed and payment is verified.',
            ),
          ),
        );
    }
  }

  Future<void> _createMilestone() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final amount = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add milestone'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextField(
                controller: amount,
                decoration: const InputDecoration(labelText: 'Amount (INR)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      title.dispose();
      description.dispose();
      amount.dispose();
      return;
    }
    final parsedAmount = double.tryParse(amount.text.trim());
    if (title.text.trim().isEmpty ||
        parsedAmount == null ||
        parsedAmount <= 0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a title and a valid amount.')),
        );
      return;
    }
    setState(() => _working = true);
    try {
      await Supabase.instance.client.from('milestones').insert({
        'project_id': widget.projectId,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'amount': parsedAmount,
        'status': 'pending',
      });
      _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to add milestone.')),
        );
    } finally {
      title.dispose();
      description.dispose();
      amount.dispose();
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _submissionNotes() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit milestone'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Work submitted / notes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _perform(Future<void> Function() action, String success) async {
    setState(() => _working = true);
    try {
      await action();
      _refresh();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update the milestone.')),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _createTask(_ProjectWorkspace workspace) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final clientId = workspace.project['client_id']?.toString();
    final freelancerId = workspace.project['freelancer_id']?.toString();
    var assigneeId = userId;
    var priority = 'medium';
    DateTime? dueDate;
    final task = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add project task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Task title'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                DropdownButton<String?>(
                  value: assigneeId,
                  isExpanded: true,
                  items: [
                    if (clientId != null)
                      DropdownMenuItem(
                        value: clientId,
                        child: const Text('Assign to client'),
                      ),
                    if (freelancerId != null)
                      DropdownMenuItem(
                        value: freelancerId,
                        child: const Text('Assign to freelancer'),
                      ),
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => assigneeId = value),
                ),
                DropdownButton<String>(
                  value: priority,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low priority')),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium priority'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('High priority'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => priority = value);
                  },
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: dueDate ?? DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    dueDate == null
                        ? 'Set due date'
                        : 'Due ${dueDate!.toIso8601String().split('T').first}',
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
                'assignee_id': assigneeId,
                'priority': priority,
                'due_date': dueDate?.toIso8601String().split('T').first,
              }),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (task == null || title.text.trim().isEmpty) {
      title.dispose();
      description.dispose();
      return;
    }
    try {
      await Supabase.instance.client.from('project_tasks').insert({
        'project_id': widget.projectId,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'created_by': userId,
        'assignee_id': task['assignee_id'],
        'priority': task['priority'],
        'due_date': task['due_date'],
      });
      _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to add task.')));
    } finally {
      title.dispose();
      description.dispose();
    }
  }

  Future<void> _uploadDeliverable() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'png',
        'jpg',
        'jpeg',
        'txt',
        'zip',
        'docx',
      ],
    );
    if (picked.isEmpty) return;
    final file = picked.single;
    if (await file.length() > 20 * 1024 * 1024) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Files must be 20 MB or smaller.')),
        );
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'bin';
    final path =
        '${widget.projectId}/${user.id}/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
    setState(() => _working = true);
    try {
      final bytes = await file.readAsBytes();
      final storage = Supabase.instance.client.storage.from(
        'project-workspace-assets',
      );
      await storage.uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: FileOptions(contentType: contentType),
      );
      try {
        await Supabase.instance.client.from('project_deliverables').insert({
          'project_id': widget.projectId,
          'uploaded_by': user.id,
          'file_path': path,
          'description': file.name,
        });
      } catch (_) {
        await storage.remove([path]);
        rethrow;
      }
      _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to upload deliverable.')),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openDeliverable(String path) async {
    try {
      final url = await Supabase.instance.client.storage
          .from('project-workspace-assets')
          .createSignedUrl(path, 600);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this file.')),
        );
    }
  }

  Future<void> _writeReview() async {
    final comment = TextEditingController();
    var rating = 5;
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review project partner'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: rating,
                isExpanded: true,
                items: [1, 2, 3, 4, 5]
                    .map(
                      (score) => DropdownMenuItem(
                        value: score,
                        child: Text('$score / 5 stars'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => rating = value);
                },
              ),
              TextField(
                controller: comment,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
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
              onPressed: () => Navigator.pop(context, {
                'rating': rating,
                'comment': comment.text.trim(),
              }),
              child: const Text('Submit review'),
            ),
          ],
        ),
      ),
    );
    comment.dispose();
    if (result == null) return;
    await _perform(() async {
      await Supabase.instance.client.rpc(
        'submit_project_review',
        params: {
          'project_id_input': widget.projectId,
          'rating_input': result['rating'],
          'comment_input': result['comment'],
        },
      );
    }, 'Review submitted.');
  }

  List<_ActivityEntry> _activity(_ProjectWorkspace workspace) {
    final entries = <_ActivityEntry>[];
    final created = DateTime.tryParse(
      workspace.project['created_at']?.toString() ?? '',
    );
    if (created != null)
      entries.add(_ActivityEntry(created, 'Project created'));
    for (final milestone in workspace.milestones) {
      final time = DateTime.tryParse(
        (milestone['updated_at'] ?? milestone['created_at'])?.toString() ?? '',
      );
      if (time != null)
        entries.add(
          _ActivityEntry(
            time,
            'Milestone: ${milestone['title']} · ${milestone['status']}',
          ),
        );
    }
    for (final task in workspace.tasks) {
      final time = DateTime.tryParse(
        (task['updated_at'] ?? task['created_at'])?.toString() ?? '',
      );
      if (time != null)
        entries.add(
          _ActivityEntry(time, 'Task: ${task['title']} · ${task['status']}'),
        );
    }
    for (final deliverable in workspace.deliverables) {
      final time = DateTime.tryParse(
        deliverable['created_at']?.toString() ?? '',
      );
      if (time != null)
        entries.add(
          _ActivityEntry(
            time,
            'Deliverable submitted: ${deliverable['description'] ?? 'File'}',
          ),
        );
    }
    entries.sort((a, b) => b.time.compareTo(a.time));
    return entries.take(20).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Project workspace'),
      actions: [
        IconButton(
          tooltip: 'Generate or view invoice',
          onPressed: _generateInvoice,
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        ReportAction(
          targetType: 'project',
          targetId: widget.projectId,
          targetName: 'project',
        ),
      ],
    ),
    body: FutureBuilder<_ProjectWorkspace>(
      future: _workspace,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || !snapshot.hasData)
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry loading project'),
            ),
          );
        final workspace = snapshot.data!;
        final project = workspace.project;
        final milestones = workspace.milestones;
        final tasks = workspace.tasks;
        final completedMilestones = milestones
            .where(
              (item) =>
                  item['status'] == 'approved' || item['status'] == 'completed',
            )
            .length;
        final completedTasks = tasks
            .where((item) => item['status'] == 'completed')
            .length;
        final totalWorkItems = milestones.length + tasks.length;
        final progress = totalWorkItems == 0
            ? 0.0
            : (completedMilestones + completedTasks) / totalWorkItems;
        final deadline = project['deadline'] == null
            ? 'Not set'
            : project['deadline'].toString().split('T').first;
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project['title']?.toString() ?? 'Project',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project['description']?.toString() ??
                            'No project description provided.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Status: ${project['status'] ?? 'pending'} · Deadline: $deadline',
                      ),
                      const SizedBox(height: 12),
                      Text('Milestone progress · ${(progress * 100).round()}%'),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text(
                        'Budget: ₹${((project['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} · Paid: ₹${((project['amount_paid'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _working
                              ? null
                              : () => _messagePartner(
                                  project,
                                  workspace.isClient,
                                ),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('Message project partner'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Milestones',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (workspace.isClient)
                    IconButton(
                      onPressed: _working ? null : _createMilestone,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Add milestone',
                    ),
                ],
              ),
              if (milestones.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No milestones have been added yet.'),
                  ),
                ),
              ...milestones.map(
                (milestone) =>
                    _milestoneCard(context, milestone, workspace.isClient),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _working ? null : () => _createTask(workspace),
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add task',
                  ),
                ],
              ),
              if (tasks.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No project tasks yet.'),
                  ),
                ),
              ...tasks.map(
                (task) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(task['title']?.toString() ?? 'Task'),
                    subtitle: Text(
                      '${task['description'] ?? ''}\nPriority: ${task['priority'] ?? 'medium'}${task['due_date'] == null ? '' : ' · Due ${task['due_date']}'}',
                    ),
                    isThreeLine: true,
                    trailing: DropdownButton<String>(
                      value:
                          const [
                            'to_do',
                            'in_progress',
                            'completed',
                          ].contains(task['status'])
                          ? task['status'] as String
                          : 'to_do',
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'to_do', child: Text('To do')),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: Text('In progress'),
                        ),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Done'),
                        ),
                      ],
                      onChanged: _working
                          ? null
                          : (status) {
                              if (status != null)
                                _perform(() async {
                                  await Supabase.instance.client
                                      .from('project_tasks')
                                      .update({'status': status})
                                      .eq('id', task['id']);
                                }, 'Task updated.');
                            },
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Deliverables & files',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _working ? null : _uploadDeliverable,
                    icon: const Icon(Icons.upload_file_outlined),
                    tooltip: 'Upload deliverable',
                  ),
                ],
              ),
              if (workspace.deliverables.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No files have been shared on this project.'),
                  ),
                ),
              ...workspace.deliverables.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(
                      item['description']?.toString() ?? 'Project file',
                    ),
                    subtitle: Text(
                      'Status: ${(item['review_status'] ?? 'submitted').toString().replaceAll('_', ' ')}',
                    ),
                    onTap: () => _openDeliverable(item['file_path'] as String),
                    trailing:
                        workspace.isClient &&
                            item['review_status'] == 'submitted'
                        ? PopupMenuButton<String>(
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'approved',
                                child: Text('Approve'),
                              ),
                              PopupMenuItem(
                                value: 'revision_required',
                                child: Text('Request revision'),
                              ),
                            ],
                            onSelected: (status) => _perform(() async {
                              await Supabase.instance.client
                                  .from('project_deliverables')
                                  .update({'review_status': status})
                                  .eq('id', item['id']);
                            }, 'Deliverable review saved.'),
                          )
                        : const Icon(Icons.open_in_new),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reviews',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (project['status'] == 'completed' &&
                      !workspace.reviews.any(
                        (review) =>
                            review['reviewer_id'] == workspace.currentUserId,
                      ))
                    TextButton.icon(
                      onPressed: _working ? null : _writeReview,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Review partner'),
                    ),
                ],
              ),
              if (workspace.reviews.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No reviews have been submitted for this project.',
                    ),
                  ),
                ),
              ...workspace.reviews.map(
                (review) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                    ),
                    title: Text('${review['rating']} / 5'),
                    subtitle: Text(
                      (review['comment']?.toString().isNotEmpty ?? false)
                          ? review['comment'].toString()
                          : 'No written comment',
                    ),
                  ),
                ),
              ),
              Text('Activity', style: Theme.of(context).textTheme.titleLarge),
              if (_activity(workspace).isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No project activity recorded yet.'),
                  ),
                ),
              ..._activity(workspace).map(
                (event) => ListTile(
                  leading: const Icon(Icons.circle, size: 10),
                  title: Text(event.summary),
                  subtitle: Text(
                    event.time.toLocal().toString().split('.').first,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _milestoneCard(
    BuildContext context,
    Map<String, dynamic> milestone,
    bool isClient,
  ) {
    final id = milestone['id'] as String;
    final status = milestone['status']?.toString() ?? 'pending';
    final notes = milestone['submission_notes']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              milestone['title']?.toString() ?? 'Milestone',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if ((milestone['description']?.toString() ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(milestone['description'].toString()),
              ),
            const SizedBox(height: 6),
            Text(
              '₹${((milestone['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} · ${status.replaceAll('_', ' ')}',
            ),
            if (notes != null && notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Submission: $notes'),
              ),
            if (!isClient && status == 'pending')
              TextButton(
                onPressed: _working
                    ? null
                    : () => _perform(() async {
                        await Supabase.instance.client.rpc(
                          'start_project_milestone',
                          params: {'milestone_id_input': id},
                        );
                      }, 'Milestone started.'),
                child: const Text('Start work'),
              ),
            if (!isClient &&
                (status == 'pending' ||
                    status == 'in_progress' ||
                    status == 'revision_required'))
              TextButton(
                onPressed: _working
                    ? null
                    : () async {
                        final notes = await _submissionNotes();
                        if (notes == null) return;
                        await _perform(() async {
                          await Supabase.instance.client.rpc(
                            'submit_project_milestone',
                            params: {
                              'milestone_id_input': id,
                              'submission_notes_input': notes,
                            },
                          );
                        }, 'Milestone submitted for review.');
                      },
                child: const Text('Submit for review'),
              ),
            if (isClient && status == 'submitted')
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _working
                        ? null
                        : () => _perform(() async {
                            await Supabase.instance.client.rpc(
                              'review_project_milestone',
                              params: {
                                'milestone_id_input': id,
                                'decision_input': 'revision_required',
                              },
                            );
                          }, 'Revision requested.'),
                    child: const Text('Request revision'),
                  ),
                  FilledButton(
                    onPressed: _working
                        ? null
                        : () => _perform(() async {
                            await Supabase.instance.client.rpc(
                              'review_project_milestone',
                              params: {
                                'milestone_id_input': id,
                                'decision_input': 'approved',
                              },
                            );
                          }, 'Milestone approved.'),
                    child: const Text('Approve'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _messagePartner(
    Map<String, dynamic> project,
    bool isClient,
  ) async {
    final otherUserId =
        (isClient ? project['freelancer_id'] : project['client_id'])
            ?.toString();
    if (otherUserId == null || otherUserId.isEmpty) return;
    setState(() => _working = true);
    try {
      final conversationId = await Supabase.instance.client.rpc(
        'get_or_create_direct_conversation',
        params: {'other_user_id': otherUserId},
      );
      if (mounted) context.push('/chat/$conversationId');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open a conversation.')),
        );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }
}

class _ProjectWorkspace {
  const _ProjectWorkspace({
    required this.project,
    required this.milestones,
    required this.tasks,
    required this.deliverables,
    required this.reviews,
    required this.isClient,
    required this.currentUserId,
  });
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> milestones;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> deliverables;
  final List<Map<String, dynamic>> reviews;
  final bool isClient;
  final String currentUserId;
}

class _ActivityEntry {
  const _ActivityEntry(this.time, this.summary);
  final DateTime time;
  final String summary;
}
