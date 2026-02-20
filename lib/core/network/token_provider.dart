import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTokenProvider {
  SupabaseTokenProvider(this._supabaseClient);

  final SupabaseClient _supabaseClient;

  Future<String?> getAccessToken() async {
    return _supabaseClient.auth.currentSession?.accessToken;
  }
}
