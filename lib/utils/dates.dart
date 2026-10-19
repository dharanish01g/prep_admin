const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Tomorrow", "Yesterday", or e.g. "12 Oct" ("12 Oct 2027" when
/// not this year).
String formatDay(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final a = DateTime.utc(today.year, today.month, today.day);
  final b = DateTime.utc(date.year, date.month, date.day);
  switch (b.difference(a).inDays) {
    case 0:
      return 'Today';
    case 1:
      return 'Tomorrow';
    case -1:
      return 'Yesterday';
  }
  final label = '${date.day} ${_months[date.month - 1]}';
  return date.year == today.year ? label : '$label ${date.year}';
}

/// e.g. "Today, 14:05" or "12 Oct, 09:30".
String formatDateTime(DateTime date, {DateTime? now}) {
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${formatDay(date, now: now)}, $hh:$mm';
}

/// e.g. "Monday, 19 October".
String formatLongDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${date.day} ${_monthsLong[date.month - 1]}';

String greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
