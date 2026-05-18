import 'dart:math';

/// A utility class to generate human-readable Unique Identification Numbers (UIN).
/// 
/// Format: [PREFIX]-[CITY]-[ALPHANUMERIC_CODE]
/// Example: TSP-DEL-8F2K9
class UINGenerator {
  /// Characters used for random generation.
  /// Excludes visually similar characters: O, 0, I, 1, L, S (5), Z (2) if desired.
  /// Standard "No-Lookalike" set:
  static const String _charset = 'ABCDEFGHJKMNPQRSTUVWXYZ346789';

  /// Generates a unique-looking business ID.
  /// 
  /// [prefix] - Defaults to 'TSP'.
  /// [city] - Optional city name to derive a 3-letter code.
  static String generateBusinessUIN({
    String prefix = 'TSP',
    String? city,
  }) {
    final random = Random();
    
    // Generate 5-character alphanumeric code
    final randomCode = StringBuffer();
    for (var i = 0; i < 5; i++) {
      randomCode.write(_charset[random.nextInt(_charset.length)]);
    }

    String cityCode = 'GEN';
    if (city != null && city.trim().isNotEmpty) {
      // Remove spaces/special chars, take first 3, uppercase
      final sanitizedCity = city.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      
      if (sanitizedCity.length >= 3) {
        cityCode = sanitizedCity.substring(0, 3);
      } else if (sanitizedCity.isNotEmpty) {
        cityCode = sanitizedCity.padRight(3, 'X');
      }
    }

    return '$prefix-$cityCode-$randomCode';
  }
}
