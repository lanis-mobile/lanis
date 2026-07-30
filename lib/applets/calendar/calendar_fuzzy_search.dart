import 'package:liblanis/liblanis.dart';

/// Fuzzy-ish title/description/place search over calendar events.
///
/// Upcoming events are returned first (ascending), then past events (descending).
List<CalendarEvent> fuzzySearchEventList(
  List<CalendarEvent> eventList,
  String query,
) {
  List<CalendarEvent> searchResultsBeforeToday = [];
  List<CalendarEvent> searchResultsAfterToday = [];

  for (var event in eventList) {
    String searchString =
        '${event.title} ${event.description} ${event.place ?? ''} ${event.startTime.year}'
            .toLowerCase();
    if (searchString.contains(query.toLowerCase())) {
      if (event.endTime.isBefore(DateTime.now())) {
        searchResultsBeforeToday.add(event);
      } else {
        searchResultsAfterToday.add(event);
      }
    }
  }

  // Sort the search results by date
  searchResultsBeforeToday.sort((a, b) => b.startTime.compareTo(a.startTime));
  searchResultsAfterToday.sort((a, b) => a.startTime.compareTo(b.startTime));

  List<CalendarEvent> searchResults = [];
  searchResults.addAll(searchResultsAfterToday);
  searchResults.addAll(searchResultsBeforeToday);

  return searchResults;
}
