import 'package:flutter/foundation.dart';
import 'package:strop_app/domain/entities/user.dart';
import 'package:strop_app/domain/repositories/user_repository.dart';
import 'package:strop_app/data/datasources/local/local_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// Real implementation of [UserRepository] backed by Supabase.
///
/// - [getUserProfile]   → reads `public.users` to build the User entity.
/// - [updateUserProfile] → writes `full_name` / `avatar_url` back to Supabase.
/// - [getSyncStatus]    → queries the local SQLite DB for pending counts so
///                        the value reflects the true offline queue.
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._client, this._localDb);

  final SupabaseClient _client;
  final LocalDatabase _localDb;

  @override
  Future<User> getUserProfile() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return User.empty;

    try {
      final data = await _client
          .from('users')
          .select('id, email, full_name, avatar_url')
          .eq('id', authUser.id)
          .single();

      return User(
        id: data['id'] as String,
        email: data['email'] as String,
        name: data['full_name'] as String?,
        avatarUrl: data['avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('UserRepositoryImpl.getUserProfile error: $e');
      // Fallback: build from auth metadata so the app never shows empty profile
      return User(
        id: authUser.id,
        email: authUser.email ?? '',
        name: authUser.userMetadata?['full_name'] as String?,
        avatarUrl: authUser.userMetadata?['avatar_url'] as String?,
      );
    }
  }

  @override
  Future<void> updateUserProfile(User user) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;

    await _client
        .from('users')
        .update({
          if (user.name != null) 'full_name': user.name,
          if (user.avatarUrl != null) 'avatar_url': user.avatarUrl,
        })
        .eq('id', authUser.id);
  }

  @override
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final db = await _localDb.database;

      final pendingRows = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM incidents WHERE sync_status = 0",
      );
      final pendingIncidents = (pendingRows.first['cnt'] as int?) ?? 0;

      final pendingPhotos_rows = await db.rawQuery(
        "SELECT COUNT(*) AS cnt FROM photos WHERE sync_status = 0",
      );
      final pendingPhotos = (pendingPhotos_rows.first['cnt'] as int?) ?? 0;

      return {
        'pendingIncidents': pendingIncidents,
        'pendingPhotos': pendingPhotos,
        'lastSync': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('UserRepositoryImpl.getSyncStatus error: $e');
      return {
        'pendingIncidents': 0,
        'pendingPhotos': 0,
        'lastSync': null,
      };
    }
  }
}
