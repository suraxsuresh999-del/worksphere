import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../app/di/auth_providers.dart';
import '../../../core/constants/supabase_constants.dart';

// ─── Auth State View Model ──────────────────────────────────────

final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final authStateChanges = ref.watch(authStateChangesUseCaseProvider);
  return authStateChanges();
});

final currentUserProvider = Provider<AsyncValue<UserEntity?>>((ref) {
  // BUG-05 FIX: Derive from the live auth stream so this stays in sync
  // after sign-in / sign-out, instead of being a stale one-shot future.
  return ref.watch(authStateProvider);
});

/// Profile edits do not emit an auth event, so keep the drawer avatar in sync
/// by watching the signed-in user's persisted profile row.
final profileAvatarUrlProvider = StreamProvider<String?>((ref) async* {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    yield null;
    return;
  }
  await for (final rows in client
      .from(SupabaseConstants.profilesTable)
      .stream(primaryKey: ['id'])
      .eq('id', user.id)) {
    final path = rows.isEmpty ? null : rows.first['avatar_url'] as String?;
    if (path == null || path.trim().isEmpty) {
      yield null;
    } else if (path.startsWith('http')) {
      yield path;
    } else {
      try {
        yield await client.storage
            .from(SupabaseConstants.verificationDocumentsBucket)
            .createSignedUrl(path, 600);
      } catch (_) {
        yield null;
      }
    }
  }
});

class AuthViewModel extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AuthViewModel(this._ref) : super(const AsyncData(null));

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      final signOutUseCase = _ref.read(signOutUseCaseProvider);
      await signOutUseCase();
      state = const AsyncData(null);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }
}

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AsyncValue<void>>((ref) {
  return AuthViewModel(ref);
});
