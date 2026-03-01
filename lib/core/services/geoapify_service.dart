import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeoapifyService {
  // Key is injected at build time via --dart-define=GEOAPIFY_API_KEY=...
  // Falls back to the free-tier key so local dev works without extra setup.
  static const String _apiKey = String.fromEnvironment(
    'GEOAPIFY_API_KEY',
    defaultValue: '7bfb473cf38d4b318d87fdadeb891318',
  );
  static const String _baseUrl = 'https://api.geoapify.com';

  /// Converts GPS coordinates to a human-readable address.
  /// Returns the formatted address string, or null on failure.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/v1/geocode/reverse?lat=$lat&lon=$lng&lang=es&apiKey=$_apiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;

      final props = features[0]['properties'] as Map<String, dynamic>?;
      if (props == null) return null;

      // Build a concise location string: "street housenumber, city" or full formatted
      final street = props['street'] as String?;
      final housenumber = props['housenumber'] as String?;
      final suburb = props['suburb'] as String?;
      final city =
          props['city'] as String? ??
          props['town'] as String? ??
          props['village'] as String?;

      if (street != null) {
        final parts = <String>[
          if (housenumber != null) '$street $housenumber' else street,
          if (suburb != null) suburb,
          if (city != null) city,
        ];
        return parts.join(', ');
      }

      // Fallback to formatted address
      return props['formatted'] as String?;
    } catch (e) {
      debugPrint('GeoapifyService.reverseGeocode error: $e');
      return null;
    }
  }
}
