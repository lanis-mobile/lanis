import 'package:liblanis/liblanis.dart';

/// Extracts unique [CalendarEventCategory] items from [events], deduplicated
/// by [CalendarEventCategory.id] and sorted alphabetically by name.
List<CalendarEventCategory> extractCalendarCategories(
  List<CalendarEvent> events,
) {
  final byId = <int, CalendarEventCategory>{};
  for (final event in events) {
    final category = event.category;
    if (category != null) {
      byId.putIfAbsent(category.id, () => category);
    }
  }
  final result = byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
}

/// Returns `true` if at least one event in [events] has no category.
bool hasUncategorizedEvents(List<CalendarEvent> events) {
  return events.any((event) => event.category == null);
}

/// Filters [events] by [selectedCategoryIds] and [includeUncategorized].
///
/// When both [selectedCategoryIds] is empty and [includeUncategorized] is
/// `false`, no filter is active and all [events] are returned.
List<CalendarEvent> filterCalendarEvents(
  List<CalendarEvent> events, {
  required Set<int> selectedCategoryIds,
  required bool includeUncategorized,
}) {
  if (selectedCategoryIds.isEmpty && !includeUncategorized) {
    return events;
  }

  return events.where((event) {
    final category = event.category;
    if (category == null) {
      return includeUncategorized;
    }
    return selectedCategoryIds.contains(category.id);
  }).toList();
}
