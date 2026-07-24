import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:lanis/applets/calendar/calendar_event_card.dart';
import 'package:lanis/applets/calendar/calendar_event_sheet.dart';
import 'package:lanis/applets/calendar/calendar_fuzzy_search.dart';
import 'package:lanis/applets/calendar/calendar_search_result_tile.dart';
import 'package:lanis/applets/calendar/definition.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:lanis/utils/keyboard_observer.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/root_nav.dart';

import '../../widgets/error_view.dart';

class CalendarView extends ConsumerStatefulWidget {
  final Function? openDrawerCb;
  const CalendarView({super.key, this.openDrawerCb});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;
  final _unescape = HtmlUnescape();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> eventList = [];
  SearchController searchController = SearchController();

  KeyboardObserver keyboardObserver = KeyboardObserver();
  bool noTrigger = false;

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    keyboardObserver.addDefaultCallback();
  }

  Future<Map<String, dynamic>?> fetchEvent(
    String id, {
    secondTry = false,
  }) async {
    try {
      if (secondTry) {
        await ref
            .read(sessionProvider.notifier)
            .authenticate(withoutData: true);
      }

      return await ref.read(calendarParserProvider).getEvent(id);
    } catch (e) {
      if (!secondTry) {
        return await fetchEvent(id, secondTry: true);
      }
    }
    return null;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    List<CalendarEvent> validEvents = [];

    for (var event in eventList) {
      // Compare only the date part of startTime and endTime
      bool isStartTimeOnDay =
          event.startTime.year == day.year &&
          event.startTime.month == day.month &&
          event.startTime.day == day.day;

      bool isEndTimeOnDay =
          event.endTime.year == day.year &&
          event.endTime.month == day.month &&
          event.endTime.day == day.day;

      if ((isStartTimeOnDay || event.startTime.isBefore(day)) &&
          (isEndTimeOnDay || event.endTime.isAfter(day))) {
        validEvents.add(event);
      }
    }

    return validEvents;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  Future<void> openEventBottomSheet(CalendarEvent calendarData) async {
    try {
      var singleEvent = await fetchEvent(calendarData.id);
      if (singleEvent == null) return;
      if (mounted) {
        await showRootModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) {
            return CalendarEventBottomSheet(
              calendarData: calendarData,
              singleEventData: singleEvent,
            );
          },
        );
      }
    } on NoConnectionException {
      if (mounted) {
        return;
      }
    } on LanisException catch (ex) {
      if (mounted) {
        await showRootModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return AppletErrorView(error: ex);
          },
        );
      }
    }
  }

  Widget _itemsListView(BuildContext context) {
    return ValueListenableBuilder<List<CalendarEvent>>(
      valueListenable: _selectedEvents,
      builder: (context, value, _) {
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CustomScrollView(
            slivers: [
              if (value.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_available, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).noEntries,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: value.length,
                itemBuilder: (context, index) {
                  return CalendarEventCard(
                    event: value[index],
                    unescape: _unescape,
                    onTap: () async {
                      await openEventBottomSheet(value[index]);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableCalendar(BuildContext context) {
    return TableCalendar<CalendarEvent>(
      locale: AppLocalizations.of(context).locale,
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2030),
      availableCalendarFormats: {
        CalendarFormat.month: AppLocalizations.of(context).calendarFormatMonth,
        CalendarFormat.twoWeeks: AppLocalizations.of(
          context,
        ).calendarFormatTwoWeeks,
        CalendarFormat.week: AppLocalizations.of(context).calendarFormatWeek,
      },
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultDecoration: const BoxDecoration(shape: BoxShape.circle),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(
          fontSize: 16.0,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSecondary,
          fontSize: 16,
        ),
        markerDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.inversePrimary,
        ),
        markerSize: 8,
        isTodayHighlighted: false,
      ),
      onDaySelected: _onDaySelected,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (BuildContext context, date, events) {
          if (events.isEmpty) return SizedBox();
          return ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(top: 21),
                padding: const EdgeInsets.all(1),
                child: Container(
                  height: 6,
                  width: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorFromArgb(events[index].colorArgb),
                    border:
                        (colorFromArgb(events[index].colorArgb).computeLuminance() -
                                    Theme.of(
                                      context,
                                    ).colorScheme.surface.computeLuminance())
                                .abs() <
                            0.02
                        ? Border.all(
                            color: Theme.of(context).colorScheme.onSurface,
                            width: 0.75,
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
      pageJumpingEnabled: true,
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      headerStyle: HeaderStyle(
        formatButtonTextStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
        ),
        formatButtonDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(sessionProvider).asData?.value == null) {
      return Scaffold(
        appBar: widget.openDrawerCb != null
            ? AppBar(
                title: Text(calendarDefinition.label(context)),
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => widget.openDrawerCb!(),
                ),
              )
            : null,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: widget.openDrawerCb != null
          ? AppBar(
              title: Text(calendarDefinition.label(context)),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => widget.openDrawerCb!(),
              ),
            )
          : null,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8, left: 8, right: 8),
            child: Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus == true && noTrigger == false) {
                  FocusManager.instance.primaryFocus?.consumeKeyboardToken();

                  if (keyboardObserver.value == KeyboardStatus.closed) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                }
              },
              child: SearchAnchor.bar(
                searchController: searchController,
                isFullScreen: false,
                viewLeading: IconButton(
                  onPressed: () {
                    searchController.closeView(null);
                  },
                  icon: Icon(Icons.arrow_back),
                ),
                barTrailing: [
                  if (!_selectedDay!.isSameDay(DateTime.now()))
                    IconButton(
                      icon: const Icon(Icons.restore),
                      onPressed: () {
                        setState(() {
                          searchController.text = "";
                          _selectedDay = DateTime.now();
                          _focusedDay = DateTime.now();
                        });
                      },
                    ),
                ],
                onSubmitted: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                suggestionsBuilder: (context, searchController) {
                  final results = fuzzySearchEventList(
                    eventList,
                    searchController.text,
                  );

                  return results
                      .map(
                        (event) => CalendarSearchResultTile(
                          event: event,
                          onTap: () async {
                            setState(() {
                              _selectedDay = event.startTime;
                              _focusedDay = event.startTime;
                            });
                            searchController.closeView(null);

                            noTrigger = true;
                            if (keyboardObserver.value ==
                                KeyboardStatus.closed) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            }

                            await openEventBottomSheet(event).whenComplete(() {
                              FocusManager.instance.primaryFocus?.unfocus();
                              noTrigger = false;
                            });
                          },
                        ),
                      )
                      .toList();
                },
              ),
            ),
          ),
          Expanded(
            child: CombinedAppletBuilder<List<CalendarEvent>>(
              parser: ref.watch(calendarParserProvider),
              phpUrl: calendarDefinition.appletPhpUrl,
              settingsDefaults: calendarDefinition.settingsDefaults,
              accountType: ref.watch(sessionProvider).asData?.value?.accountType ??
                  ref.watch(activeAccountProvider)?.accountType ??
                  AccountType.student,
              builder:
                  (
                    context,
                    data,
                    accountType,
                    settings,
                    updateSetting,
                    refresh,
                  ) {
                    eventList = data;
                    _selectedEvents.value = _getEventsForDay(_selectedDay!);

                    return LayoutBuilder(
                      builder: (context, constrains) {
                        if (constrains.maxWidth > 550) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: _tableCalendar(context)),
                              const VerticalDivider(),
                              Expanded(child: _itemsListView(context)),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _tableCalendar(context),
                            Expanded(child: _itemsListView(context)),
                          ],
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}
