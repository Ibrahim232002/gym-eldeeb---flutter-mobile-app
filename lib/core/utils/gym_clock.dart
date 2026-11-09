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

  static Duration untilNextDay([DateTime? instant]) {
    final now = instant ?? DateTime.now();
    final cairo = tz.TZDateTime.from(now, _cairo);
    return tz.TZDateTime(_cairo, cairo.year, cairo.month, cairo.day + 1)
        .difference(now);
  }
}
