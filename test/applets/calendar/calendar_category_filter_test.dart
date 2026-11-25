import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/calendar/calendar_category_filter.dart';
import 'package:liblanis/liblanis.dart';

CalendarEvent _makeEvent(String id, {CalendarEventCategory? category}) {
  return CalendarEvent(
    startTime: DateTime(2026, 11, 25, 10, 0),
    endTime: DateTime(2026, 11, 25, 11, 0),
    secret: false,
    id: id,
    isNew: false,
    public: true,
    private: false,
    allDay: false,
    category: category,
    description: '',
    title: 'Event $id',
  );
}

void main() {
  final catDsh = CalendarEventCategory(
    id: 4,
    colorArgb: 0xFF0080FF,
    name: 'DSH',
  );
  final catPublic = CalendarEventCategory(
    id: 5,
    colorArgb: 0xFFFF8040,
    name: 'Für die Öffentlichkeit',
  );
  final catAll = CalendarEventCategory(
    id: 1,
    colorArgb: 0xFF000000,
    name: 'Alle',
  );

  group('extractCalendarCategories', () {
    test('deduplicates by id and sorts alphabetically', () {
      final events = [
        _makeEvent('1', category: catPublic),
        _makeEvent('2', category: catDsh),
        _makeEvent('3', category: catAll),
        _makeEvent(
          '4',
          category: CalendarEventCategory(
            id: 4,
            colorArgb: 0xFF0080FF,
            name: 'DSH',
          ),
        ),
        _makeEvent('5', category: null),
      ];

      final categories = extractCalendarCategories(events);
      expect(categories.map((c) => c.id), [1, 4, 5]);
      expect(categories.map((c) => c.name), [
        'Alle',
        'DSH',
        'Für die Öffentlichkeit',
      ]);
    });
  });

  group('hasUncategorizedEvents', () {
    test('returns true only when at least one event has null category', () {
      expect(hasUncategorizedEvents([_makeEvent('1', category: catDsh)]), isFalse);
      expect(
        hasUncategorizedEvents([
          _makeEvent('1', category: catDsh),
          _makeEvent('2', category: null),
        ]),
        isTrue,
      );
    });
  });

  group('filterCalendarEvents', () {
    final events = [
      _makeEvent('1', category: catDsh),
      _makeEvent('2', category: catPublic),
      _makeEvent('3', category: catAll),
      _makeEvent('4', category: null),
    ];

    test('returns all events when no filter is active', () {
      final filtered = filterCalendarEvents(
        events,
        selectedCategoryIds: const {},
        includeUncategorized: false,
      );
      expect(filtered.map((e) => e.id), ['1', '2', '3', '4']);
    });

    test('filters to selected category ids', () {
      final filtered = filterCalendarEvents(
        events,
        selectedCategoryIds: const {4, 5},
        includeUncategorized: false,
      );
      expect(filtered.map((e) => e.id), ['1', '2']);
    });

    test('filters to uncategorized only', () {
      final filtered = filterCalendarEvents(
        events,
        selectedCategoryIds: const {},
        includeUncategorized: true,
      );
      expect(filtered.map((e) => e.id), ['4']);
    });

    test('combines selected category ids and uncategorized', () {
      final filtered = filterCalendarEvents(
        events,
        selectedCategoryIds: const {1},
        includeUncategorized: true,
      );
      expect(filtered.map((e) => e.id), ['3', '4']);
    });
  });
}
