import 'package:flutter/foundation.dart';
import 'package:strop_app/domain/entities/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileRepository {
  UserProfileRepository(this._client);
  final SupabaseClient _client;

  UserProfile? _cached;

  Future<UserProfile?> getCurrentUserProfile() async {
    if (_cached != null) return _cached;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final data = await _client
          .from('users')
          .select('id, email, full_name, user_type, organization_id, role:roles(capabilities)')
          .eq('id', userId)
          .single();

      final caps = data['role']?['capabilities'];
      final capabilities =
          caps is List ? caps.cast<String>() : <String>[];

      _cached = UserProfile(
        id: data['id'] as String,
        email: data['email'] as String,
        fullName: data['full_name'] as String?,
        roleCapabilities: capabilities,
        userType: data['user_type'] as String? ?? 'staff',
        organizationId: data['organization_id'] as String?,
      );
      return _cached;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  void clearCache() => _cached = null;
}
