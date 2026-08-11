/// Resolves the selected week badge for the student timetable.
///
/// [currentWeekIndex] uses `0` for "all weeks" and `1..n` for
/// [uniqueBadges] entries. Out-of-range / empty badge lists fall back to
/// "all weeks" so UI builds never index an empty list.
({int index, String? badge}) resolveTimetableWeekSelection({
  required int currentWeekIndex,
  required List<String> uniqueBadges,
}) {
  if (uniqueBadges.isEmpty || currentWeekIndex <= 0) {
    return (index: 0, badge: null);
  }
  if (currentWeekIndex > uniqueBadges.length) {
    return (index: 0, badge: null);
  }
  return (
    index: currentWeekIndex,
    badge: uniqueBadges[currentWeekIndex - 1],
  );
}

/// Initial week index from settings / current school week badge.
int initialTimetableWeekIndex({
  required bool showByWeek,
  required String? weekBadge,
  required List<String> uniqueBadges,
}) {
  if (showByWeek || weekBadge == null || weekBadge.isEmpty) {
    return 0;
  }
  final idx = uniqueBadges.indexOf(weekBadge);
  return idx >= 0 ? idx + 1 : 0;
}

/// True when the timetable has hour rows but no visible day columns after
/// week / hidden-lesson filtering (would crash [DefaultTabController]).
bool isTimetableVisuallyEmpty({
  required bool hoursEmpty,
  required bool daysEmpty,
}) =>
    hoursEmpty || daysEmpty;
