import '../../core/strings.dart';

/// Human "time ago" for ISO-8601 timestamps from the API.
/// Returns null when the timestamp cannot be parsed (caller shows nothing).
String? boardTimeAgo(String? iso, AppStrings s) {
  if (iso == null || iso.isEmpty) return null;
  DateTime? dt;
  try {
    dt = DateTime.parse(iso);
  } catch (_) {
    return null;
  }
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inMinutes < 1) return s.boardJustNow;
  if (diff.inMinutes < 60) return '${diff.inMinutes} ${s.boardMinutesAgo}';
  if (diff.inHours < 24) return '${diff.inHours} ${s.boardHoursAgo}';
  return '${diff.inDays} ${s.boardDaysAgo}';
}
