import 'package:intl/intl.dart';

final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _rupeePaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _compact = NumberFormat.compact(locale: 'en_IN');

String money(num value, {bool paise = false}) =>
    (paise ? _rupeePaise : _rupee).format(value);

String compactNumber(num value) => _compact.format(value);

String dayMonth(DateTime d) => DateFormat('d MMM').format(d);
String dayMonthYear(DateTime d) => DateFormat('d MMM yyyy').format(d);
String weekdayLong(DateTime d) => DateFormat('EEEE, d MMMM').format(d);
String timeOfDay(DateTime d) => DateFormat('h:mm a').format(d);
String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

/// "12 Aug, 6:00 PM – 9:00 PM" when the event ends the same day.
String eventWhen(DateTime start, DateTime? end) {
  final startText = '${dayMonth(start)}, ${timeOfDay(start)}';
  if (end == null) return startText;
  final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
  return sameDay
      ? '$startText – ${timeOfDay(end)}'
      : '$startText – ${dayMonth(end)}, ${timeOfDay(end)}';
}

String relativeTime(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return dayMonth(when);
  return dayMonthYear(when);
}

/// "in 3 days" / "tomorrow" for upcoming event cards.
String countdown(DateTime when) {
  final diff = when.difference(DateTime.now());
  if (diff.isNegative) return 'Ended';
  if (diff.inHours < 1) return 'in ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'in ${diff.inHours} hr';
  if (diff.inDays == 1) return 'tomorrow';
  if (diff.inDays < 30) return 'in ${diff.inDays} days';
  return dayMonth(when);
}

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Matches the greeting to the illustrations shipped in assets/svg.
String greetingAsset() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'assets/svg/morning.svg';
  if (hour < 17) return 'assets/svg/after_noon.svg';
  if (hour < 20) return 'assets/svg/sunset.svg';
  return 'assets/svg/night.svg';
}
