import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const [];
    final rows = await Supabase.instance.client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> _refresh() {
    final request = _load();
    setState(() => _notifications = request);
    return request.then<void>((_) {});
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', item['id']);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _notifications,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Retry'),
            ),
          );
        }
        final items = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 180),
                    Center(child: Text('You have no notifications.')),
                  ],
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final unread = item['is_read'] != true;
                    return ListTile(
                      leading: Icon(
                        unread ? Icons.notifications : Icons.notifications_none,
                      ),
                      title: Text(
                        item['title'] as String? ?? 'Notification',
                        style: unread
                            ? const TextStyle(fontWeight: FontWeight.w600)
                            : null,
                      ),
                      subtitle: Text(item['body'] as String? ?? ''),
                      onTap: () => _markRead(item),
                    );
                  },
                ),
        );
      },
    ),
  );
}
