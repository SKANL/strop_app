import 'package:strop_app/domain/entities/user.dart';
import 'package:strop_app/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._supabaseClient);

  final supabase.SupabaseClient _supabaseClient;

  @override
  Stream<User> get user {
    return _supabaseClient.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) {
        return User.empty;
      }
      return User(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['full_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
      );
    });
  }

  @override
  Future<User> get currentUser async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      return User.empty;
    }
    return User(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  @override
  Future<void> logInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> logOut() async {
    await _supabaseClient.auth.signOut();
  }
}
