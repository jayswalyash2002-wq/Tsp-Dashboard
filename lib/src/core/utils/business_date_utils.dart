import 'package:intl/intl.dart';

/// Utility class for handling Business Day logic.
/// In this environment, a "Business Day" starts at 4:00 AM.
class BusinessDateUtils {
  /// Default business-day cutoff time: 4:00 AM.
  static const int cutoffHour = 4;

  /// Returns the business date for a given timestamp based on the 4 AM cutoff.
  /// If the timestamp is between 00:00 and 03:59:59, it returns the previous calendar day.
  static DateTime getBusinessDate(DateTime timestamp) {
    if (timestamp.hour < cutoffHour) {
      final prev = timestamp.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(timestamp.year, timestamp.month, timestamp.day);
  }

  /// Returns the absolute start time of a business day (4:00:00 AM).
  static DateTime getBusinessStart(DateTime date) {
    return DateTime(date.year, date.month, date.day, cutoffHour);
  }

  /// Returns the absolute end time of a business day (3:59:59.999 AM next day).
  static DateTime getBusinessEnd(DateTime date) {
    return DateTime(date.year, date.month, date.day, cutoffHour)
        .add(const Duration(days: 1))
        .subtract(const Duration(milliseconds: 1));
  }

  /// Returns the start of the business week (Monday 4:00 AM) for a given date.
  static DateTime getStartOfBusinessWeek(DateTime date) {
    final bDate = getBusinessDate(date);
    final monday = bDate.subtract(Duration(days: bDate.weekday - 1));
    return getBusinessStart(monday);
  }

  /// Returns the end of the business week (Sunday business day end) for a given date.
  static DateTime getEndOfBusinessWeek(DateTime date) {
    final bDate = getBusinessDate(date);
    final sunday = bDate.add(Duration(days: 7 - bDate.weekday));
    return getBusinessEnd(sunday);
  }

  /// Returns the start of the business month (1st day 4:00 AM) for a given date.
  static DateTime getStartOfBusinessMonth(DateTime date) {
    final bDate = getBusinessDate(date);
    final first = DateTime(bDate.year, bDate.month, 1);
    return getBusinessStart(first);
  }

  /// Returns the end of the business month (Last day business day end) for a given date.
  static DateTime getEndOfBusinessMonth(DateTime date) {
    final bDate = getBusinessDate(date);
    final last = DateTime(bDate.year, bDate.month + 1, 0);
    return getBusinessEnd(last);
  }

  /// Returns the start of the business quarter for a given date.
  static DateTime getStartOfBusinessQuarter(DateTime date) {
    final bDate = getBusinessDate(date);
    final quarterMonth = ((bDate.month - 1) ~/ 3) * 3 + 1;
    return getBusinessStart(DateTime(bDate.year, quarterMonth, 1));
  }

  /// Returns the end of the business quarter for a given date.
  static DateTime getEndOfBusinessQuarter(DateTime date) {
    final bDate = getBusinessDate(date);
    final quarterMonth = ((bDate.month - 1) ~/ 3) * 3 + 1;
    final lastMonthOfQuarter = quarterMonth + 2;
    return getBusinessEnd(DateTime(bDate.year, lastMonthOfQuarter + 1, 0));
  }

  /// Returns the start of the business financial year (April 1st 4:00 AM) for a given date.
  static DateTime getStartOfBusinessFinancialYear(DateTime date) {
    final bDate = getBusinessDate(date);
    final year = bDate.month < 4 ? bDate.year - 1 : bDate.year;
    return getBusinessStart(DateTime(year, 4, 1));
  }

  /// Returns the end of the business financial year (March 31st business day end) for a given date.
  static DateTime getEndOfBusinessFinancialYear(DateTime date) {
    final bDate = getBusinessDate(date);
    final year = bDate.month < 4 ? bDate.year : bDate.year + 1;
    return getBusinessEnd(DateTime(year, 3, 31));
  }

  /// Returns a formatted string for the business date (e.g., "16 May 2026").
  static String formatBusinessDate(DateTime timestamp) {
    final businessDate = getBusinessDate(timestamp);
    return DateFormat('d MMMM yyyy').format(businessDate);
  }

  /// Returns the absolute start and end [DateTime] for a given business day.
  static ({DateTime start, DateTime end}) getBusinessDayRange(DateTime date) {
    return (start: getBusinessStart(date), end: getBusinessEnd(date));
  }
}
