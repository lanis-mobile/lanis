import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:lanis/applets/calendar/definition.dart';
import 'package:lanis/globals.dart';
import 'package:lanis/utils/keyboard_observer.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:lanis/generated/l10n.dart';

import '../../core/sph/sph.dart';
import '../../models/calendar_event.dart';
import '../../models/client_status_exceptions.dart';
import '../../utils/logger.dart';
import '../../widgets/error_view.dart';

class CalendarView extends StatefulWidget {
  final Function? openDrawerCb;
  const CalendarView({super.key, this.openDrawerCb});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;

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

  List<CalendarEvent> fuzzySearchEventList(String query) {
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

  Future<Map<String, dynamic>?> fetchEvent(
    String id, {
    secondTry = false,
  }) async {
    try {
      if (secondTry) {
        await sph!.session.authenticate(withoutData: true);
      }

      return await sph!.parser.calendarParser.getEvent(id);
    } catch (e) {
      if (!secondTry) {
        fetchEvent(id, secondTry: true);
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

  bool doesEntryExist(dynamic entry) => entry != null && entry != "";

  Widget eventBottomSheet(
    CalendarEvent calendarData,
    Map<String, dynamic> singleEventData,
  ) {
    const double iconSize = 24;

    // German-formatted readable date string
    String date = "";

    String startTime = calendarData.startTime.format("E d MMM y", "de_DE");
    String endTime = calendarData.endTime.format("E d MMM y", "de_DE");

    if (calendarData.allDay) {
      if (startTime == endTime) {
        date += startTime;
      } else {
        date += "$startTime bis $endTime";
      }
    } else {
      if (startTime == endTime) {
        date +=
            "${calendarData.startTime.format("E d MMM y H:mm", "de_DE")} bis ${calendarData.endTime.format("H:mm", "de_DE")}";
      } else {
        date +=
            "${calendarData.startTime.format("E d MMM y H:mm", "de_DE")} bis ${calendarData.endTime.format("E MMM d y H:mm", "de_DE")}";
      }
    }

    // For which group (Public, Students & Parents, Teachers) it's targeted for.
    String targetGroup = "";

    if (doesEntryExist(singleEventData["properties"]) &&
        doesEntryExist(singleEventData["properties"]["zielgruppen"])) {
      Map<String, dynamic> data = singleEventData["properties"]["zielgruppen"];

      data.forEach((key, value) {
        if (key == "-sus") {
          targetGroup += value.replaceAll("amp;", "").toString();
          return;
        }
        targetGroup += "$value, ";
      });
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: ListView(
        shrinkWrap: true,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              calendarData.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Responsible (Teacher, Admin, ...)
          if (doesEntryExist(singleEventData["properties"]) &&
              doesEntryExist(
                singleEventData["properties"]["verantwortlich"],
              )) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.person, size: iconSize),
                  ),
                  Text(
                    singleEventData["properties"]["verantwortlich"],
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ],
          // Time
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.access_time_filled, size: iconSize),
                ),
                Flexible(
                  child: Text(
                    date,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          // Place
          if (doesEntryExist(calendarData.place)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.place, size: iconSize),
                  ),
                  Text(
                    calendarData.place!,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ],
          // Target group
          if (doesEntryExist(singleEventData["properties"]) &&
              doesEntryExist(singleEventData["properties"]["zielgruppen"])) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.group, size: iconSize),
                  ),
                  Flexible(
                    child: Text(
                      targetGroup,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (doesEntryExist(calendarData.lerngruppe)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.school, size: iconSize),
                  ),
                  Flexible(
                    child: Text(
                      calendarData.lerngruppe["Name"],
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (doesEntryExist(calendarData.description)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Linkify(
                onOpen: (link) async {
                  if (!await launchUrl(Uri.parse(link.url))) {
                    logger.w("${link.url} konnte nicht geöffnet werden.");
                  }
                },
                text: calendarData.description.replaceAll("<br />", "\n"),
                style: Theme.of(context).textTheme.bodyLarge,
                linkStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          SizedBox(height: 50.0),
        ],
      ),
    );
  }

  Future<void> openEventBottomSheet(CalendarEvent calendarData) async {
    try {
      var singleEvent = await fetchEvent(calendarData.id);
      if (singleEvent == null) return;
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (context) {
            return eventBottomSheet(calendarData, singleEvent);
          },
        );
      }
    } on NoConnectionException {
      if (mounted) {
        return;
      }
    } on LanisException catch (ex) {
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return AppletErrorView(error: ex);
          },
        );
      }
    }
  }

  Widget _itemsListView(context) {
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
                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 8,
                      right: 8,
                      bottom: 4,
                    ),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await openEventBottomSheet(value[index]);
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 40,
                              decoration: BoxDecoration(
                                color: value[index].color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      unescape.convert(value[index].title),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      unescape.convert(
                                        value[index].category?.name ??
                                            value[index].place ??
                                            value[index].description,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_right),
                            SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
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
                    color: events[index].color,
                    border:
                        (events[index].color.computeLuminance() -
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
                  final results = fuzzySearchEventList(searchController.text);

                  return results
                      .map(
                        (event) => ListTile(
                          title: Text(event.title),
                          iconColor: event.color,
                          subtitle: Text(
                            '${event.startTime.format("E d MMM y", "de_DE")} - ${event.endTime.format("E d MMM y", "de_DE")}',
                          ),
                          leading: event.endTime.isBefore(DateTime.now())
                              ? const Icon(Icons.done)
                              : const Icon(Icons.event),
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
              parser: sph!.parser.calendarParser,
              phpUrl: calendarDefinition.appletPhpUrl,
              settingsDefaults: calendarDefinition.settingsDefaults,
              accountType: sph!.session.accountType,
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
