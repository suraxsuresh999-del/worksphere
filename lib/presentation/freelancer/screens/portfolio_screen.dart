import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  late Future<List<Map<String, dynamic>>> _items;
  bool _saving = false;
  bool _isFreelancer = false;

  @override
  void initState() {
    super.initState();
    _items = _loadItems();
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('Please sign in again.');
    final account = await Supabase.instance.client
        .from('profiles')
        .select('user_type')
        .eq('id', userId)
        .maybeSingle();
    if (account?['user_type'] != 'freelancer') {
      throw StateError('Portfolio management is available to freelancers.');
    }
    if (mounted && !_isFreelancer) setState(() => _isFreelancer = true);
    final result = await Supabase.instance.client
        .from('portfolio_items')
        .select('id, title, description, project_url, created_at')
        .eq('freelancer_id', userId)
        .order('created_at', ascending: false);
    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  void _reload() => setState(() => _items = _loadItems());

  Future<void> _refresh() async {
    final request = _loadItems();
    setState(() => _items = request);
    await request;
  }

  Future<void> _editItem([Map<String, dynamic>? item]) async {
    if (!_isFreelancer) return;
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController(text: item?['title'] as String? ?? '');
    final description = TextEditingController(
      text: item?['description'] as String? ?? '',
    );
    final url = TextEditingController(
      text: item?['project_url'] as String? ?? '',
    );
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          item == null ? 'Add portfolio item' : 'Edit portfolio item',
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Title *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                TextFormField(
                  controller: description,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextFormField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Project URL'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final uri = Uri.tryParse(text);
                    return uri != null &&
                            (uri.scheme == 'https' || uri.scheme == 'http') &&
                            uri.host.isNotEmpty
                        ? null
                        : 'Enter a valid http or https URL';
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, {
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'project_url': url.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    description.dispose();
    url.dispose();
    if (values == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      if (item == null) {
        final userId = client.auth.currentUser?.id;
        if (userId == null) throw StateError('Please sign in again.');
        await client.from('portfolio_items').insert({
          ...values,
          'freelancer_id': userId,
        });
      } else {
        await client
            .from('portfolio_items')
            .update(values)
            .eq('id', item['id'].toString());
      }
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Portfolio item saved.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the portfolio item.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    if (!_isFreelancer) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete portfolio item?'),
        content: Text(
          '“${item['title']}” will be removed from your portfolio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client
          .from('portfolio_items')
          .delete()
          .eq('id', item['id'].toString());
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Portfolio item deleted.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete the portfolio item.')),
        );
      }
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this project link.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Portfolio'),
      actions: [
        IconButton(
          tooltip: 'Add portfolio item',
          onPressed: _saving ? null : () => _editItem(),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done || _saving) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isFreelancer
                      ? 'Unable to load your portfolio.'
                      : snapshot.error is StateError
                      ? (snapshot.error as StateError).message
                      : 'Unable to load your portfolio.',
                ),
                const SizedBox(height: 12),
                if (_isFreelancer)
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.work_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Your portfolio is empty.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _editItem(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add your first item'),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final projectUrl = item['project_url'] as String?;
              return Card(
                child: ListTile(
                  title: Text(item['title'] as String? ?? 'Untitled'),
                  subtitle: (item['description'] as String?)?.isNotEmpty == true
                      ? Text(item['description'] as String)
                      : null,
                  onTap: projectUrl == null || projectUrl.isEmpty
                      ? null
                      : () => _openUrl(projectUrl),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'edit') _editItem(item);
                      if (action == 'delete') _deleteItem(item);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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
}
