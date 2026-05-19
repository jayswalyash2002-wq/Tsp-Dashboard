import 'dart:math';
import 'package:intl/intl.dart';

/// A utility class to generate permanent, human-readable Unique Identification Numbers (UIN).
/// 
/// Format: [TYPE]-[YEAR]-[SEQUENCE]-[SUFFIX]
/// Example: BIZ-24-00142-X7K29
class UINGenerator {
  static const String _charset = 'ABCDEFGHJKMNPQRSTUVWXYZ346789';

  /// Generates a display UIN.
  /// 
  /// [type] - 'BIZ' for Business, 'BRN' for Branch, 'INV' for Invoice, etc.
  /// [sequence] - An incrementing number (e.g. from a database counter).
  /// [year] - Defaults to current 2-digit year.
  static String generateUIN({
    required String type,
    required int sequence,
    String? year,
  }) {
    final random = Random();
    
    // 1. Random Suffix (5 chars) to prevent easy guessing and add collision safety
    final randomCode = StringBuffer();
    for (var i = 0; i < 5; i++) {
      randomCode.write(_charset[random.nextInt(_charset.length)]);
    }

    // 2. Year Code (YY)
    final yearCode = year ?? DateFormat('yy').format(DateTime.now());

    // 3. Padded Sequence (e.g. 00001)
    final paddedSequence = sequence.toString().padLeft(5, '0');

    return '$type-$yearCode-$paddedSequence-${randomCode.toString()}';
  }
}
