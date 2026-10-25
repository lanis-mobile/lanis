import 'package:dart_date/dart_date.dart';

enum TimetableWeekMode { current, all, badge }

/// A school-week choice is identified by its badge, never by its position in a
/// plan's lessons. Current-week mode follows newly fetched server badges.
class TimetableWeekSelection {
  final TimetableWeekMode mode;
  final String? badge;

  const TimetableWeekSelection.current()
    : mode = TimetableWeekMode.current,
      badge = null;
  const TimetableWeekSelection.all()
    : mode = TimetableWeekMode.all,
      badge = null;
  const TimetableWeekSelection.badge(this.badge)
    : mode = TimetableWeekMode.badge;

  factory TimetableWeekSelection.fromSettings(Map<String, dynamic> settings) {
    final saved = settings['student-week-selection'];
    if (saved is Map) {
      if (saved['mode'] == 'all') return const TimetableWeekSelection.all();
      final badge = saved['badge'];
      if (saved['mode'] == 'badge' &&
          badge is String &&
          badge.trim().isNotEmpty) {
        return TimetableWeekSelection.badge(badge.trim());
      }
      if (saved['mode'] == 'current') {
        return const TimetableWeekSelection.current();
      }
    }
    // The legacy boolean used true for all weeks and false for current week.
    return settings['student-selected-week'] == true
        ? const TimetableWeekSelection.all()
        : const TimetableWeekSelection.current();
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (mode == TimetableWeekMode.badge) 'badge': badge,
  };

  String? resolveBadge(String? currentBadge) {
    final value = switch (mode) {
      TimetableWeekMode.current => currentBadge,
      TimetableWeekMode.all => null,
      TimetableWeekMode.badge => badge,
    };
    return value == null || value.trim().isEmpty ? null : value.trim();
  }
}

/// Keep Sunday in the server's current school week. Advancing to next Monday
/// would require a server badge for that week, not an inferred A/B alternation.
DateTime timetableWeekStart(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day - (date.weekday - DateTime.monday),
);

int timetableWeekNumber(DateTime weekStart) => weekStart.getISOWeek;

/// True when the timetable has no visible lessons after filtering.
bool isTimetableVisuallyEmpty({
  required bool hoursEmpty,
  required bool daysEmpty,
}) => hoursEmpty || daysEmpty;
