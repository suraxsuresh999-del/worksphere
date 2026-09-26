import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/route_names.dart';
import '../../../core/enums/enums.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../common/widgets/ws_drawer.dart';

class MainShellScreen extends ConsumerWidget {
  final Widget child;

  const MainShellScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isClient = user?.type == UserType.client;
    final workRoute = isClient ? RouteNames.postJob : RouteNames.jobs;
    final index = path.startsWith(workRoute)
        ? 1
        : path.startsWith(RouteNames.chat)
            ? 2
            : path.startsWith(RouteNames.profile)
                ? 3
                : 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorkSphere'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: FutureBuilder<List<dynamic>>(
              future: Supabase.instance.client
                  .from('notifications')
                  .select('id')
                  .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '')
                  .eq('is_read', false),
              builder: (context, snapshot) {
                final unread = snapshot.data?.length ?? 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (unread > 0)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: CircleAvatar(
                          radius: 8,
                          child: Text(unread > 9 ? '9+' : '$unread', style: const TextStyle(fontSize: 9)),
                        ),
                      ),
                  ],
                );
              },
            ),
            onPressed: () => context.push(RouteNames.notifications),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authViewModelProvider.notifier).signOut();
              if (context.mounted) context.go(RouteNames.login);
            },
          ),
        ],
      ),
      drawer: const WsDrawer(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (selected) {
          final route = [RouteNames.home, workRoute, RouteNames.chat, RouteNames.profile][selected];
          context.go(route);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(isClient ? Icons.add_business_outlined : Icons.work_outline),
            selectedIcon: Icon(isClient ? Icons.add_business : Icons.work),
            label: isClient ? 'Post Job' : 'Find Jobs',
          ),
          const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
