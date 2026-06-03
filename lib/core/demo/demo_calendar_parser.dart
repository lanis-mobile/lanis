import 'package:lanis/applets/calendar/parser.dart';
import 'package:lanis/models/calendar_event.dart';

class DemoCalendarParser extends CalendarParser {
  DemoCalendarParser(super.sph, super.appletDefinition);

  @override
  Future<List<CalendarEvent>> getHome() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return [
      CalendarEvent(
        id: 'demo-1',
        title: 'Klassenfahrt Planung',
        description: 'Besprechung der Klassenfahrt nach Berlin',
        startTime: monday.add(const Duration(hours: 8)),
        endTime: monday.add(const Duration(hours: 9)),
        allDay: false,
        secret: false,
        isNew: false,
        public: true,
        private: false,
        place: 'Aula',
      ),
      CalendarEvent(
        id: 'demo-2',
        title: 'Elternsprechtag',
        description: 'Halbjährlicher Elternsprechtag',
        startTime: monday.add(const Duration(days: 1, hours: 14)),
        endTime: monday.add(const Duration(days: 1, hours: 18)),
        allDay: false,
        secret: false,
        isNew: true,
        public: true,
        private: false,
        place: 'Schulgebäude',
      ),
      CalendarEvent(
        id: 'demo-3',
        title: 'Sportfest',
        description: 'Jährliches Schulsportfest auf dem Sportplatz',
        startTime: monday.add(const Duration(days: 2)),
        endTime: monday.add(const Duration(days: 2, hours: 23, minutes: 59)),
        allDay: true,
        secret: false,
        isNew: false,
        public: true,
        private: false,
        place: 'Sportplatz',
      ),
      CalendarEvent(
        id: 'demo-4',
        title: 'Schulfeier 50 Jahre',
        description: 'Festakt zum Schuljubiläum',
        startTime: monday.add(const Duration(days: 3, hours: 16)),
        endTime: monday.add(const Duration(days: 3, hours: 19)),
        allDay: false,
        secret: false,
        isNew: false,
        public: true,
        private: false,
        place: 'Aula',
      ),
      CalendarEvent(
        id: 'demo-5',
        title: 'Hausaufgaben Mathe',
        description: 'Seite 42–44 im Buch',
        startTime: monday.add(const Duration(days: 4)),
        endTime: monday.add(const Duration(days: 4)),
        allDay: true,
        secret: false,
        isNew: false,
        public: false,
        private: true,
      ),
    ];
  }
}
