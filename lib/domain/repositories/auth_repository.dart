import '../entities/user_entity.dart';
import '../../core/enums/enums.dart';
import 'package:file_picker/file_picker.dart';

/// Authentication Repository Interface
abstract class AuthRepository {
  /// Stream of current user state changes
  Stream<UserEntity?> get authStateChanges;

  /// Get the current logged in user (null if not logged in)
  Future<UserEntity?> getCurrentUser();

  /// Sign in with Email and Password
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign up with Email and Password
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  });
  
  /// Sign in with Google
  Future<UserEntity> signInWithGoogle();
  
  /// Re-send sign-up email verification to the provided email.
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

  /// Sign out the current user
  Future<void> signOut();

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email});
  
  /// Update password (when logged in or via reset flow)
  Future<void> updatePassword({required String newPassword});
}
