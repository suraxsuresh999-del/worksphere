import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<List<Map<String, dynamic>>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = _loadConversations();
  }

  Future<List<Map<String, dynamic>>> _loadConversations() async {
    final result = await Supabase.instance.client.rpc('get_my_conversations');
    return (result as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _refresh() => setState(() => _conversations = _loadConversations());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _conversations,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load conversations.'),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        final conversations = snapshot.data ?? const [];
        if (conversations.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No messages yet. Start a conversation from a project or profile.'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final name = conversation['other_user_name'] as String? ?? 'WorkSphere member';
              return ListTile(
                leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase())),
                title: Text(name),
                subtitle: Text(conversation['last_message'] as String? ?? 'No messages yet'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/chat/${conversation['id']}'),
              );
            },
          ),
        );
      },
    );
  }
}
