import 'dart:math';

class UINGenerator {
  static String generateBusinessUIN({
    String prefix = 'TSP',
    String? city,
  }) {
    final random = Random();
    final randomDigits = random.nextInt(9000) + 1000; // 4-digit random number

    String cityCode = 'GEN';
    if (city != null && city.trim().isNotEmpty) {
      final sanitizedCity = city.trim().toUpperCase();
      if (sanitizedCity.length >= 3) {
        cityCode = sanitizedCity.substring(0, 3);
      } else {
        cityCode = sanitizedCity.padRight(3, 'X');
      }
    }

    return '$prefix-$cityCode-$randomDigits';
  }
}
