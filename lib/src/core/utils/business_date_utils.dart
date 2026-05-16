import 'package:intl/intl.dart';

/// Utility class for handling Business Day logic.
/// In a POS/Café environment, a "Business Day" often extends past midnight.
class BusinessDateUtils {
  /// Default business-day cutoff time: 4:00 AM.
  /// This means the business day of May 16th actually runs from
  /// May 16th 04:00 AM to May 17th 03:59:59 AM.
  static const int cutoffHour = 4;

  /// Returns the business date for a given timestamp based on the 4 AM cutoff.
  /// If the timestamp is between 00:00 and 03:59, it returns the previous calendar day.
  static DateTime getBusinessDate(DateTime timestamp) {
    if (timestamp.hour < cutoffHour) {
      final prev = timestamp.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(timestamp.year, timestamp.month, timestamp.day);
  }

  /// Returns a formatted string for the business date (e.g., "16 May 2026").
  /// This is used for grouping and session tracking.
  static String formatBusinessDate(DateTime timestamp) {
    final businessDate = getBusinessDate(timestamp);
    return DateFormat('d MMMM yyyy').format(businessDate);
  }

  /// Returns the start and end [DateTime] for a given business day.
  /// Useful for filtering reports and order history.
  static ({DateTime start, DateTime end}) getBusinessDayRange(DateTime date) {
    final start = DateTime(date.year, date.month, date.day, cutoffHour);
    final end = start.add(const Duration(days: 1));
    return (start: start, end: end);
  }

  /// Returns the start of the business week (last 7 business days).
  /// Starts from 4 AM of the calculated start day.
  static DateTime getStartOfBusinessWeek(DateTime now) {
    final businessDate = getBusinessDate(now);
    final start = businessDate.subtract(const Duration(days: 6));
    return DateTime(start.year, start.month, start.day, cutoffHour);
  }

  /// Returns the start of the business month (1st of the current business month).
  /// Starts from 4 AM on the 1st.
  static DateTime getStartOfBusinessMonth(DateTime now) {
    final businessDate = getBusinessDate(now);
    return DateTime(businessDate.year, businessDate.month, 1, cutoffHour);
  }
}
