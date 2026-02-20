import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'Strop';

  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Storage
  static const String dbName = 'strop_local.db';
  static const String incidentsTable = 'pending_incidents';
  static const String photosTable = 'pending_photos';
}
