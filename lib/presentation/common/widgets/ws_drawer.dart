import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/route_names.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class WsDrawer extends ConsumerWidget {
  const WsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // BUG-05 FIX: currentUserProvider is now a Provider<AsyncValue<UserEntity?>>
    // derived from the live auth stream — always up-to-date after sign-out.
    final userAsync = ref.watch(currentUserProvider);
    final avatarUrl = ref.watch(profileAvatarUrlProvider).valueOrNull;

    return Drawer(
      child: Column(
        children: [
          userAsync.when(
            data: (user) {
              if (user == null) {
                return const UserAccountsDrawerHeader(
                  accountName: Text('Guest'),
                  accountEmail: Text('Please log in'),
                );
              }
              return UserAccountsDrawerHeader(
                accountName: Text(user.fullName),
                accountEmail: Text(user.email),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? Text(user.initials,
                          style: const TextStyle(fontSize: 24))
                      : null,
                ),
              );
            },
            loading: () => const DrawerHeader(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                const DrawerHeader(child: Text('Error loading user')),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('My Profile'),
            onTap: () {
              context.pop();
              context.push(RouteNames.profile);
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('My Applications'),
            onTap: () {
              context.pop();
              context.push(RouteNames.applications);
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Wallet'),
            onTap: () {
              context.pop();
              // BUG-15 FIX: Wallet navigation restored.
              context.push(RouteNames.wallet);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              context.pop();
              context.push(RouteNames.settings);
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title:
                const Text('Log Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              context.pop();
              await ref.read(authViewModelProvider.notifier).signOut();
              if (context.mounted) {
                context.go(RouteNames.login);
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
