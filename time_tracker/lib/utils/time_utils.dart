class TimeUtils {
  /// Round a duration to the nearest 15 minutes
  static Duration roundToNearest15(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final remainder = totalMinutes % 15;
    final rounded = remainder < 8
        ? totalMinutes - remainder
        : totalMinutes + (15 - remainder);
    return Duration(minutes: rounded);
  }

  /// Format duration as "2h 45m"
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  /// Format DateTime as "7:02 AM"
  static String formatTime(DateTime dt) {
    final hour = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Format DateTime as "Monday, June 9 2026"
  static String formatDate(DateTime dt) {
    const days = [
      'Monday','Tuesday','Wednesday',
      'Thursday','Friday','Saturday','Sunday'
    ];
    const months = [
      '','January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month]} ${dt.day} ${dt.year}';
  }

  /// Format DateTime as "June 17 2026" (no weekday)
  static String formatDateShort(DateTime dt) {
    const months = [
      '','January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return '${months[dt.month]} ${dt.day} ${dt.year}';
  }

  /// Format minutes as decimal hours, e.g. 450 -> "7.5", 480 -> "8"
  static String formatHoursDecimal(int minutes) {
    final hours = minutes / 60.0;
    String s = hours.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Calculate earnings from duration and hourly rate
  static double calculateEarnings(Duration duration, double hourlyRate) {
    return (duration.inMinutes / 60) * hourlyRate;
  }
}