import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart' as legacy show Material, MaterialType;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:lanis/applets/calendar/calendar_category_filter.dart';
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
  final Set<int> _selectedCategoryIds = {};
  bool _includeUncategorized = false;
  final GlobalKey _filterButtonKey = GlobalKey();
  SearchController searchController = SearchController();

  bool get _hasActiveCategoryFilter =>
      _selectedCategoryIds.isNotEmpty || _includeUncategorized;

  List<CalendarEvent> get _filteredEvents => filterCalendarEvents(
    eventList,
    selectedCategoryIds: _selectedCategoryIds,
    includeUncategorized: _includeUncategorized,
  );

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

    for (var event in _filteredEvents) {
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
    final calendar = TableCalendar<CalendarEvent>(
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
                        (colorFromArgb(
                                      events[index].colorArgb,
                                    ).computeLuminance() -
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
    // TableCalendar's header buttons still use Flutter's legacy InkWell.
    return legacy.Material(
      type: legacy.MaterialType.transparency,
      child: calendar,
    );
  }

  Widget _categoryColorDot(BuildContext context, int colorArgb) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = colorFromArgb(colorArgb);
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border:
            (color.computeLuminance() - colorScheme.surface.computeLuminance())
                    .abs() <
                0.02
            ? Border.all(color: colorScheme.onSurface, width: 0.75)
            : null,
      ),
    );
  }

  void _applyFilterChange(VoidCallback update) {
    setState(update);
    _selectedEvents.value = _getEventsForDay(_selectedDay!);
  }

  Widget _buildFilterPopoverItem({
    required BuildContext context,
    required String label,
    required bool selected,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 18, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterPopover(BuildContext context) async {
    final renderBox =
        _filterButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final topOffset = renderBox != null
        ? renderBox.localToGlobal(Offset.zero).dy + renderBox.size.height + 6
        : MediaQuery.of(context).padding.top + kToolbarHeight + 6;

    await Navigator.of(context, rootNavigator: true).push(
      _CalendarFilterPopoverRoute(
        top: topOffset,
        builder: (popoverContext, setPopoverState) {
          void applyChange(VoidCallback update) {
            _applyFilterChange(update);
            setPopoverState(() {});
          }

          return _buildFilterPopoverMenu(
            popoverContext,
            onApplyChange: applyChange,
          );
        },
      ),
    );
  }

  Widget _buildFilterPopoverMenu(
    BuildContext context, {
    required void Function(VoidCallback) onApplyChange,
  }) {
    final categories = extractCalendarCategories(eventList);
    final hasUncategorized = hasUncategorizedEvents(eventList);
    final l10n = AppLocalizations.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 220,
        maxWidth: 280,
        maxHeight: 340,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterPopoverItem(
              context: context,
              label: l10n.calendarFilterAll,
              selected: !_hasActiveCategoryFilter,
              leading: const Icon(Icons.layers_outlined, size: 16),
              onTap: () {
                if (!_hasActiveCategoryFilter) return;
                onApplyChange(() {
                  _selectedCategoryIds.clear();
                  _includeUncategorized = false;
                });
              },
            ),
            if (categories.isNotEmpty || hasUncategorized)
              const Divider(height: 1),
            for (final category in categories)
              _buildFilterPopoverItem(
                context: context,
                label: _unescape.convert(category.name),
                selected: _selectedCategoryIds.contains(category.id),
                leading: _categoryColorDot(context, category.colorArgb),
                onTap: () => onApplyChange(() {
                  if (_selectedCategoryIds.contains(category.id)) {
                    _selectedCategoryIds.remove(category.id);
                  } else {
                    _selectedCategoryIds.add(category.id);
                  }
                }),
              ),
            if (hasUncategorized)
              _buildFilterPopoverItem(
                context: context,
                label: l10n.calendarFilterUncategorized,
                selected: _includeUncategorized,
                leading: const Icon(Icons.label_off_outlined, size: 16),
                onTap: () => onApplyChange(() {
                  _includeUncategorized = !_includeUncategorized;
                }),
              ),
          ],
        ),
      ),
    );
  }

  int get _activeFilterCount =>
      _selectedCategoryIds.length + (_includeUncategorized ? 1 : 0);

  AppBar _calendarAppBar(BuildContext context, {bool showFilterAction = false}) {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      title: Text(calendarDefinition.label(context)),
      leading: widget.openDrawerCb != null
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => widget.openDrawerCb!(),
            )
          : null,
      actions: [
        if (showFilterAction)
          IconButton(
            key: _filterButtonKey,
            tooltip: l10n.calendarFilterTitle,
            icon: Badge.count(
              count: _activeFilterCount,
              isLabelVisible: _hasActiveCategoryFilter,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _openFilterPopover(context),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);

    if (sessionAsync case AsyncError(:final error, :final stackTrace)) {
      final exception = error is Exception
          ? error
          : UnknownException(error.toString());
      return Scaffold(
        appBar: _calendarAppBar(context),
        body: AppletErrorView(
          error: exception,
          stack: stackTrace,
          retry: () => ref.invalidate(sessionProvider),
        ),
      );
    }

    final session = sessionAsync.asData?.value;
    if (session == null) {
      return Scaffold(
        appBar: _calendarAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _calendarAppBar(context, showFilterAction: true),
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
                    _filteredEvents,
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
              accountType:
                  session.accountTypeOrNull ??
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

class _CalendarFilterPopoverRoute extends PopupRoute<void> {
  final double top;
  final Widget Function(BuildContext context, StateSetter setState) builder;

  _CalendarFilterPopoverRoute({required this.top, required this.builder});

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 130);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        Positioned(
          top: top,
          right: 12,
          left: 12,
          child: Align(
            alignment: Alignment.topRight,
            child: FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                alignment: Alignment.topRight,
                child: Material(
                  elevation: 6,
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: StatefulBuilder(builder: builder),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
