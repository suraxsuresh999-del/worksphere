import '../../core/network/network_info.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/enums/enums.dart';
import '../datasources/auth_remote_datasource.dart';
import 'package:file_picker/file_picker.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  AuthRepositoryImpl(this._remoteDataSource, this._networkInfo);

  @override
  Stream<UserEntity?> get authStateChanges {
    return _remoteDataSource.authStateChanges.map(
      (userModel) => userModel?.toEntity(),
    );
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    if (!await _networkInfo.isConnected) {
      // In a full implementation, we might try to fetch from local cache here
      // For now, if no internet, we assume not logged in or rely on stream
      return null;
    }
    try {
      final userModel = await _remoteDataSource.getCurrentUser();
      return userModel?.toEntity();
    } catch (_) {
      // TODO: Log the error (e.g., to a crash reporting service)
      return null;
    }
  }

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    
    final userModel = await _remoteDataSource.signInWithEmail(
      email: email,
      password: password,
    );
    
    return userModel.toEntity();
  }

  @override
  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    
    final userModel = await _remoteDataSource.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
    
    return userModel.toEntity();
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    
    final userModel = await _remoteDataSource.signInWithGoogle();
    return userModel.toEntity();
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    await _remoteDataSource.resendVerificationEmail(email: email);
  }

  @override
  Future<void> updateAccountType({required UserType userType}) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    await _remoteDataSource.updateAccountType(userType: userType);
  }

  @override
  Future<void> completeClientProfile({
    required String companyName,
    required String location,
    String? about,
  }) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    await _remoteDataSource.completeClientProfile(
      companyName: companyName,
      location: location,
      about: about,
    );
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
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    await _remoteDataSource.completeFreelancerProfile(
      title: title,
      bio: bio,
      hourlyRate: hourlyRate,
      location: location,
      skills: skills,
      isStudent: isStudent,
    );
  }

  @override
  Future<void> uploadResume(PlatformFile file) async {
    if (!await _networkInfo.isConnected) throw const NetworkException();
    await _remoteDataSource.uploadResume(file);
  }

  @override
  Future<void> signOut() async {
    // BUG-02 FIX: Do NOT block sign-out on network check.
    // The local Supabase session must always be clearable, even offline.
    // The remote signOut call may fail, but the local session is still removed.
    try {
      await _remoteDataSource.signOut();
    } catch (_) {
      // Swallow remote errors — local session is cleared by Supabase client
      // regardless of whether the server-side invalidation succeeded.
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    await _remoteDataSource.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkException();
    }
    await _remoteDataSource.updatePassword(newPassword: newPassword);
  }
}
