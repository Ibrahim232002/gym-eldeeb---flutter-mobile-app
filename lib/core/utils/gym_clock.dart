import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// All membership calendar boundaries use the gym's Cairo business timezone,
/// independent of the device's timezone. Keep date-only values as calendar dates.
class GymClock {
  static final tz.Location _cairo = _initialize();

  static tz.Location _initialize() {
    tzdata.initializeTimeZones();
    return tz.getLocation('Africa/Cairo');
  }

  static DateTime today([DateTime? instant]) {
    final cairo = tz.TZDateTime.from(instant ?? DateTime.now(), _cairo);
    return DateTime.utc(cairo.year, cairo.month, cairo.day);
  }

  /// Returns the current Cairo calendar month as a half-open UTC interval.
  /// Use this for timestamp filters so DST changes do not shift month boundaries.
  static ({DateTime startUtc, DateTime endUtc}) currentMonthUtcRange(
      [DateTime? instant]) {
    final cairo = tz.TZDateTime.from(instant ?? DateTime.now(), _cairo);
    final start = tz.TZDateTime(_cairo, cairo.year, cairo.month, 1);
    final end = tz.TZDateTime(_cairo, cairo.year, cairo.month + 1, 1);
    return (startUtc: start.toUtc(), endUtc: end.toUtc());
  }

  static bool isInCurrentMonth(DateTime value, [DateTime? reference]) {
    final cairoValue = tz.TZDateTime.from(value, _cairo);
    final cairoReference =
        tz.TZDateTime.from(reference ?? DateTime.now(), _cairo);
    return cairoValue.year == cairoReference.year &&
        cairoValue.month == cairoReference.month;
  }

  static Duration untilNextDay([DateTime? instant]) {
    final now = instant ?? DateTime.now();
    final cairo = tz.TZDateTime.from(now, _cairo);
    return tz.TZDateTime(_cairo, cairo.year, cairo.month, cairo.day + 1)
        .difference(now);
  }
}
