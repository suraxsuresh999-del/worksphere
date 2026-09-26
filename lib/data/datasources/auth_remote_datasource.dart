import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../../core/errors/exceptions.dart';
import '../../core/enums/enums.dart';
import '../../core/constants/supabase_constants.dart';

abstract class AuthRemoteDataSource {
  Stream<UserModel?> get authStateChanges;
  Future<UserModel?> getCurrentUser();
  Future<UserModel> signInWithEmail(
      {required String email, required String password});
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  });
  Future<UserModel> signInWithGoogle();
  Future<void> resendVerificationEmail({required String email});
  Future<void> updateAccountType({required UserType userType});
  Future<void> completeClientProfile({
    required String companyName,
    required String location,
    String? about,
  });
  Future<void> completeFreelancerProfile({
    required String title,
    required String bio,
    required String hourlyRate,
    String? location,
    String? skills,
    required bool isStudent,
  });
  Future<void> uploadResume(PlatformFile file);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> updatePassword({required String newPassword});
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final supabase.SupabaseClient _supabaseClient;

  AuthRemoteDataSourceImpl(this._supabaseClient);

  @override
  Stream<UserModel?> get authStateChanges {
    return _supabaseClient.auth.onAuthStateChange.asyncMap((event) async {
      final user = event.session?.user;
      if (user == null) return null;
      return await _fetchUserProfile(user.id, user.email ?? '');
    });
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) return null;
    return await _fetchUserProfile(user.id, user.email ?? '');
  }

  Future<UserModel> _fetchUserProfile(String userId, String email) async {
    try {
      final response = await _supabaseClient
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      final freelancerProfile = await _supabaseClient
          .from('freelancer_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      final clientProfile = await _supabaseClient
          .from('client_profiles')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();
 
      final supabase.User? authUser = _supabaseClient.auth.currentUser;
      final bool isEmailVerified = authUser?.emailConfirmedAt != null;
 
      if (response == null) {
        return UserModel(
          id: userId,
          email: email,
          fullName: 'User',
          isEmailVerified: isEmailVerified,
          hasProfile: false,
          onboardingStatus: OnboardingStatus.rolePending,
          createdAt: DateTime.now(),
        );
      }
 
      final profile = UserModel.fromJson(response);
      final hasRoleRecord = freelancerProfile != null || clientProfile != null;
      final userType = (!hasRoleRecord && profile.onboardingStatus == OnboardingStatus.rolePending)
          ? UserType.rolePending
          : profile.type;
      return UserModel(
        id: profile.id,
        email: profile.email,
        phone: profile.phone,
        fullName: profile.fullName,
        avatarUrl: profile.avatarUrl,
        type: userType,
        verificationStatus: profile.verificationStatus,
        isEmailVerified: isEmailVerified,
        isPhoneVerified: profile.isPhoneVerified,
        hasProfile: profile.onboardingStatus == OnboardingStatus.active,
        onboardingStatus: profile.onboardingStatus,
        createdAt: profile.createdAt,
      );
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> signInWithEmail(
      {required String email, required String password}) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) throw AuthException.userNotFound();
      if (user.emailConfirmedAt == null) {
        throw AuthException.emailNotVerified();
      }

      return await _fetchUserProfile(user.id, user.email ?? email);
    } on supabase.AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        throw AuthException.invalidCredentials();
      }
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('email not verified')) {
        throw AuthException.emailNotVerified();
      }
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final existingPhone = await _supabaseClient
          .from(SupabaseConstants.profilesTable)
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      if (existingPhone != null) {
        throw AuthException.phoneAlreadyExists();
      }
 
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );
 
      final user = response.user;
      if (user == null) throw const ServerException(message: 'Sign up failed');
 
      final profile = UserModel(
        id: user.id,
        email: email,
        phone: phone,
        fullName: fullName,
        hasProfile: false,
        onboardingStatus: OnboardingStatus.rolePending,
        createdAt: DateTime.now(),
      );
      // Insert only the base profile fields so role selection stays explicit.
      try {
        await _supabaseClient
            .from(SupabaseConstants.profilesTable)
            .upsert({
              'id': profile.id,
              'email': profile.email,
              'phone': profile.phone,
              'full_name': profile.fullName,
              'onboarding_status': profile.onboardingStatus.value,
              'created_at': profile.createdAt.toIso8601String(),
            });
      } catch (_) {
        // If upsert fails (e.g. row already created by DB trigger), ignore.
      }

      return profile;
    } on supabase.AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        throw AuthException.emailAlreadyExists();
      }
      if (e.message.contains('weak_password')) {
        throw AuthException.weakPassword();
      }
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      final launched = await _supabaseClient.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: SupabaseConstants.authCallbackUrl,
      );
      if (!launched) {
        throw const ServerException(message: 'Unable to launch Google login.');
      }

      final currentUser = _supabaseClient.auth.currentUser;
      if (currentUser != null) {
        return await _fetchUserProfile(currentUser.id, currentUser.email ?? '');
      }

      // Wait for the auth state change event in the case the OAuth flow completes
      // asynchronously and returns to the app after browser-based authentication.
      final userModel = await _supabaseClient.auth.onAuthStateChange
          .asyncMap((event) async {
            final user = event.session?.user;
            if (user == null) return null;
            return await _fetchUserProfile(user.id, user.email ?? '');
          })
          .firstWhere((profile) => profile != null)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw const AuthException(
              message: 'Google sign-in timed out. Please try again.',
            ),
          );

      return userModel!;
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    try {
      await _supabaseClient.auth.resend(
        email: email,
        type: supabase.OtpType.signup,
      );
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updateAccountType({required UserType userType}) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw AuthException.userNotFound();

    try {
      await _supabaseClient.rpc(
        'select_account_type',
        params: {'selected_role': userType.value},
      );
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> completeClientProfile({
    required String companyName,
    required String location,
    String? about,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw AuthException.userNotFound();

    try {
      await _supabaseClient.rpc(
        'complete_client_onboarding',
        params: {
          'company_name_input': companyName,
          'district_input': location,
          'description_input': about,
        },
      );
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> completeFreelancerProfile({
    required String title,
    required String bio,
    required String hourlyRate,
    String? location,
    String? skills,
    required bool isStudent,
  }) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw AuthException.userNotFound();

    try {
      await _supabaseClient.rpc(
        'complete_freelancer_onboarding',
        params: {
          'title_input': title,
          'bio_input': bio,
          'hourly_rate_input': double.tryParse(hourlyRate) ?? 0,
          'district_input': location,
          'languages_input': skills == null || skills.trim().isEmpty
              ? <String>[]
              : skills.split(',').map((s) => s.trim()).toList(),
        },
      );
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> uploadResume(PlatformFile file) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw AuthException.userNotFound();
    final extension = file.name.split('.').last.toLowerCase();
    const mimeTypes = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    final mimeType = mimeTypes[extension];
    final size = await file.length();
    if (mimeType == null || size <= 0 || size > 5 * 1024 * 1024) {
      throw const AuthException(message: 'Choose a PDF, DOC, or DOCX file smaller than 5 MB.');
    }
    final bytes = await file.readAsBytes();
    final path = '${user.id}/resume.$extension';
    try {
      await _supabaseClient.storage.from(SupabaseConstants.resumesBucket).uploadBinary(
        path,
        bytes,
        fileOptions: supabase.FileOptions(contentType: mimeType, upsert: true),
      );
      await _supabaseClient.rpc('save_my_resume', params: {
        'storage_path_input': path,
      });
    } catch (e) {
      if (e is AuthException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _supabaseClient.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
