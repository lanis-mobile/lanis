import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/calendar/calendar_view.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:table_calendar/table_calendar.dart';

import '../helpers/test_app.dart';

class _CalendarContext implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CalendarSession implements LanisSession {
  @override
  AccountType get accountTypeOrNull => AccountType.student;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReadySession extends Session {
  @override
  LanisSession build() => _CalendarSession();
}

class _EmptyCalendarParser extends CalendarParser {
  _EmptyCalendarParser()
    : super(_CalendarContext(), isConnected: () async => true);

  @override
  Future<void> fetchData({
    bool forceRefresh = false,
    bool secondTry = false,
  }) async {
    addResponse(
      FetcherResponse(status: FetcherStatus.done, content: [], error: null),
    );
  }
}

void main() {
  tearDown(LanisClient.reset);

  testWidgets('Android calendar header advances to the next month', (
    tester,
  ) async {
    await initializeDateFormatting();
    final parser = _EmptyCalendarParser();
    addTearDown(parser.dispose);

    await pumpTestApp(
      tester,
      child: const CalendarView(),
      overrides: [
        sessionProvider.overrideWith(_ReadySession.new),
        calendarParserProvider.overrideWithValue(parser),
      ],
    );
    await tester.pumpAndSettle();

    final calendar = find.byType(TableCalendar<CalendarEvent>);
    final before = tester.widget<TableCalendar<CalendarEvent>>(calendar);
    final nextMonth = DateTime(
      before.focusedDay.year,
      before.focusedDay.month + 1,
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(DateFormat.yMMMM('en').format(nextMonth)), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));
}
