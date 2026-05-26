import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class DateTimeUtils {
  /// Returns the business-adjusted date.
  /// If [startHour] is 4, then 3 AM today is treated as yesterday.
  static DateTime getBusinessAdjustedDate(DateTime dateTime, int startHour) {
    if (dateTime.hour < startHour) {
      return dateTime.subtract(const Duration(days: 1));
    }
    return dateTime;
  }

  /// Returns the start of the business day for a given date.
  static DateTime getStartOfBusinessDay(DateTime date, int startHour, {String? timezone}) {
    if (timezone != null) {
      final location = tz.getLocation(timezone);
      return tz.TZDateTime(location, date.year, date.month, date.day, startHour);
    }
    return DateTime(date.year, date.month, date.day, startHour);
  }

  /// Returns the end of the business day for a given date.
  static DateTime getEndOfBusinessDay(DateTime date, int startHour, {String? timezone}) {
    final nextDay = date.add(const Duration(days: 1));
    if (timezone != null) {
      final location = tz.getLocation(timezone);
      return tz.TZDateTime(location, nextDay.year, nextDay.month, nextDay.day, startHour).subtract(const Duration(seconds: 1));
    }
    return DateTime(nextDay.year, nextDay.month, nextDay.day, startHour).subtract(const Duration(seconds: 1));
  }

  /// Returns a range for the operational day containing [dateTime]
  static ({DateTime start, DateTime end}) getOperationalDayRange(DateTime dateTime, int startHour, {String? timezone}) {
    final bTime = timezone != null ? toBusinessTime(dateTime, timezone) : dateTime;
    final opDay = getBusinessAdjustedDate(bTime, startHour);
    return (
      start: getStartOfBusinessDay(opDay, startHour, timezone: timezone),
      end: getEndOfBusinessDay(opDay, startHour, timezone: timezone),
    );
  }

  static String formatBusinessDay(DateTime dateTime, int startHour) {
    final adjusted = getBusinessAdjustedDate(dateTime, startHour);
    return DateFormat('yyyy-MM-dd').format(adjusted);
  }

  /// Converts a DateTime to the business timezone.
  static DateTime toBusinessTime(DateTime dateTime, String timezone) {
    try {
      final location = tz.getLocation(timezone);
      if (dateTime is tz.TZDateTime) return dateTime;
      return tz.TZDateTime.from(dateTime, location);
    } catch (e) {
      debugPrint('DATETIME_UTILS: Error converting to timezone $timezone: $e');
      return dateTime;
    }
  }
}
