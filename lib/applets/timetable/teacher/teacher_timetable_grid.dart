import 'dart:async';
import 'dart:math';

import 'package:dart_date/dart_date.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/timetable/student/timetable_week_selection.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_models.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:lanis/utils/random_color.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';

const double _teacherHeaderHeight = 42;
const double _teacherRowHeight = 56;
const double _teacherCompactRowHeight = 50;
const double _teacherPauseHeight = 24;
const double _teacherRowGap = 5;

/// Authentic Lanis Material 3 timetable grid for teacher plans.
///
/// Mirrors [TimeTableView] (rounded day headers with dates, rounded hour rail,
/// slim pause rows carrying break supervisions, colored lesson blocks, red
/// time marker) while adding teacher-specific zero-redundancy tiles, embedded
/// substitution & R&M indicators, and selection highlighting for the 3-pane
/// tablet view.
class TeacherTimetableGrid extends StatelessWidget {
  final TeacherTimetablePlan plan;
  final DateTime weekStart;
  final String? selectedBadge;
  final bool singleDay;
  final bool compact;
  final TeacherEntrySelection? selectedEntry;
  final void Function(int dayColumnIndex, TeacherTimetableEntry entry)
  onSelectEntry;
  final Future<void> Function()? onRefresh;

  const TeacherTimetableGrid({
    super.key,
    required this.plan,
    required this.weekStart,
    this.selectedBadge,
    this.singleDay = false,
    this.compact = false,
    this.selectedEntry,
    required this.onSelectEntry,
    this.onRefresh,
  });

  double get _rowHeight =>
      compact ? _teacherCompactRowHeight : _teacherRowHeight;

  double _hourWidth(bool compactMode) => compactMode ? 44 : 58;

  double _calculateTotalHeight(List<TeacherGridRow> rows) {
    var total = 0.0;
    for (final row in rows) {
      total +=
          (row.kind == TeacherGridRowKind.lesson
              ? _rowHeight
              : _teacherPauseHeight) +
          _teacherRowGap;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final rows = buildTeacherGridRows(plan);
    if (rows.isEmpty || plan.days.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event_busy_outlined, size: 52),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).noEntries,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final filteredDays = [
      for (final day in plan.days) filterTeacherDayByBadge(day, selectedBadge),
    ];

    final hourWidth = _hourWidth(compact);
    final totalHeight = _calculateTotalHeight(rows);
    final todayWeekday = (DateTime.now().weekday - 1) % 7;

    if (singleDay) {
      return _buildSingleDayView(
        context,
        rows: rows,
        filteredDays: filteredDays,
        todayWeekday: todayWeekday,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 84),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HourRailColumn(
                    rows: rows,
                    weekStart: weekStart,
                    weekBadge: selectedBadge ?? plan.weekBadge,
                    timesHidden: plan.timesHidden,
                    width: hourWidth,
                    rowHeight: _rowHeight,
                    compact: compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (
                          var dayCol = 0;
                          dayCol < filteredDays.length;
                          dayCol++
                        )
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: dayCol == 0 ? 0 : 3,
                              ),
                              child: _DayColumn(
                                plan: plan,
                                rows: rows,
                                entries: filteredDays[dayCol],
                                dayColumnIndex: dayCol,
                                weekdayIndex:
                                    dayCol < plan.weekdayIndices.length
                                    ? plan.weekdayIndices[dayCol]
                                    : dayCol,
                                weekStart: weekStart,
                                isToday:
                                    (dayCol < plan.weekdayIndices.length
                                            ? plan.weekdayIndices[dayCol]
                                            : dayCol) ==
                                        todayWeekday &&
                                    timetableWeekStart(DateTime.now()) ==
                                        weekStart,
                                rowHeight: _rowHeight,
                                totalHeight: totalHeight,
                                compact: compact,
                                selectedEntry: selectedEntry,
                                onSelectEntry: onSelectEntry,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDayView(
    BuildContext context, {
    required List<TeacherGridRow> rows,
    required List<List<TeacherTimetableEntry>> filteredDays,
    required int todayWeekday,
  }) {
    var initialIndex = plan.weekdayIndices.indexOf(todayWeekday);
    if (initialIndex < 0) {
      initialIndex = plan.weekdayIndices.indexWhere((d) => d > todayWeekday);
      if (initialIndex < 0) initialIndex = 0;
    }

    return DefaultTabController(
      length: filteredDays.length,
      initialIndex: initialIndex.clamp(0, max(0, filteredDays.length - 1)),
      child: Column(
        children: [
          _SingleDayTabStrip(
            dayCount: filteredDays.length,
            weekdayIndices: plan.weekdayIndices,
            weekStart: weekStart,
            todayWeekday: todayWeekday,
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (var dayCol = 0; dayCol < filteredDays.length; dayCol++)
                  _SingleDayAgendaList(
                    plan: plan,
                    entries: filteredDays[dayCol],
                    dayColumnIndex: dayCol,
                    selectedEntry: selectedEntry,
                    onSelectEntry: onSelectEntry,
                    onRefresh: onRefresh,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleDayTabStrip extends StatelessWidget {
  final int dayCount;
  final List<int> weekdayIndices;
  final DateTime weekStart;
  final int todayWeekday;

  const _SingleDayTabStrip({
    required this.dayCount,
    required this.weekdayIndices,
    required this.weekStart,
    required this.todayWeekday,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final cs = Theme.of(context).colorScheme;
    final isCurrentWeek = timetableWeekStart(DateTime.now()) == weekStart;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (var dayCol = 0; dayCol < dayCount; dayCol++)
            Builder(
              builder: (context) {
                final weekdayIdx = dayCol < weekdayIndices.length
                    ? weekdayIndices[dayCol]
                    : dayCol;
                final date = DateTime(
                  weekStart.year,
                  weekStart.month,
                  weekStart.day + weekdayIdx,
                );
                final isToday = isCurrentWeek && weekdayIdx == todayWeekday;
                return Tab(
                  height: 44,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat.E(locale).format(date),
                          maxLines: 1,
                          style: TextStyle(
                            fontWeight: isToday ? FontWeight.w700 : null,
                          ),
                        ),
                        Text(
                          date.format('dd.MM.'),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SingleDayAgendaList extends StatelessWidget {
  final TeacherTimetablePlan plan;
  final List<TeacherTimetableEntry> entries;
  final int dayColumnIndex;
  final TeacherEntrySelection? selectedEntry;
  final void Function(int dayColumnIndex, TeacherTimetableEntry entry)
  onSelectEntry;
  final Future<void> Function()? onRefresh;

  const _SingleDayAgendaList({
    required this.plan,
    required this.entries,
    required this.dayColumnIndex,
    required this.selectedEntry,
    required this.onSelectEntry,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final sorted = [...entries]
      ..sort((a, b) {
        final hCmp = (a.hourIndex ?? 0).compareTo(b.hourIndex ?? 0);
        if (hCmp != 0) return hCmp;
        if (a.isBreakSupervision != b.isBreakSupervision) {
          return a.isBreakSupervision ? -1 : 1;
        }
        return a.startTime.compareTo(b.startTime);
      });

    if (sorted.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              child: Center(
                child: Text(
                  l10n.noEntries,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 88),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = sorted[index];
          final cell = formatTeacherCell(
            entry,
            plan.category,
            fallbackLesson: l10n.unknownLesson,
            fallbackBooking: l10n.teacherTimetableRoomBooking,
            fallbackSubstitution: l10n.teacherTimetableSubstitutionAdded,
            fallbackSubstitutionChanged:
                l10n.teacherTimetableSubstitutionChanged,
            weekBadgeLabel: l10n.timetableWeek,
          );
          final hourRow = _findLessonRow(plan.hours, entry.hourIndex);
          final style = _entryColors(context, entry);
          final isSelected =
              selectedEntry?.dayColumnIndex == dayColumnIndex &&
              selectedEntry?.entry.id == entry.id;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: entry.isBreakSupervision
                        ? cs.tertiaryContainer.withValues(alpha: 0.7)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.isBreakSupervision
                            ? l10n.teacherTimetablePause
                            : (hourRow?.label ??
                                  (entry.hourIndex != null
                                      ? '${entry.hourIndex}.'
                                      : '—')),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.isBreakSupervision && hourRow != null)
                        Text(
                          l10n.teacherTimetablePauseBefore(hourRow.label),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        )
                      else if (!plan.timesHidden &&
                          (entry.startTime.hour != 0 ||
                              entry.startTime.minute != 0))
                        Text(
                          entry.startTime.toFlutter().format(context),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: style.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? cs.primary : style.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelectEntry(dayColumnIndex, entry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cell.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: style.foreground,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (cell.eyebrow != null) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: style.badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        cell.eyebrow!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: style.badgeFg,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (cell.subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                cell.subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (!isRedundantLanisTooltip(entry.tooltip) &&
                                (entry.isEmbeddedSubstitution ||
                                    entry.isRoomBooking)) ...[
                              const SizedBox(height: 3),
                              Text(
                                entry.tooltip!.trim(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HourRailColumn extends StatelessWidget {
  final List<TeacherGridRow> rows;
  final DateTime weekStart;
  final String? weekBadge;
  final bool timesHidden;
  final double width;
  final double rowHeight;
  final bool compact;

  const _HourRailColumn({
    required this.rows,
    required this.weekStart,
    this.weekBadge,
    required this.timesHidden,
    required this.width,
    required this.rowHeight,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: _teacherHeaderHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'KW ${timetableWeekNumber(weekStart)}',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (weekBadge != null && weekBadge!.trim().isNotEmpty)
                    Text(
                      l10n.timetableWeek(weekBadge!.trim()),
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontSize: 9.5, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _teacherRowGap),
          for (final row in rows) ...[
            if (row.kind == TeacherGridRowKind.pause)
              Container(
                width: width,
                height: _teacherPauseHeight,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  compact
                      ? (l10n.teacherTimetablePause.isNotEmpty
                            ? l10n.teacherTimetablePause[0]
                            : 'P')
                      : l10n.teacherTimetablePause,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: compact ? 9.5 : 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                width: width,
                height: rowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        row.lessonRow!.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!timesHidden &&
                          (row.lessonRow!.startTime.hour != 0 ||
                              row.lessonRow!.startTime.minute != 0)) ...[
                        Text(
                          row.lessonRow!.startTime.toFlutter().format(context),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (!compact)
                          Text(
                            row.lessonRow!.endTime.toFlutter().format(context),
                            style: TextStyle(
                              fontSize: 9.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: _teacherRowGap),
          ],
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final TeacherTimetablePlan plan;
  final List<TeacherGridRow> rows;
  final List<TeacherTimetableEntry> entries;
  final int dayColumnIndex;
  final int weekdayIndex;
  final DateTime weekStart;
  final bool isToday;
  final double rowHeight;
  final double totalHeight;
  final bool compact;
  final TeacherEntrySelection? selectedEntry;
  final void Function(int dayColumnIndex, TeacherTimetableEntry entry)
  onSelectEntry;

  const _DayColumn({
    required this.plan,
    required this.rows,
    required this.entries,
    required this.dayColumnIndex,
    required this.weekdayIndex,
    required this.weekStart,
    required this.isToday,
    required this.rowHeight,
    required this.totalHeight,
    required this.compact,
    required this.selectedEntry,
    required this.onSelectEntry,
  });

  double _offsetForRowIndex(int gridIndex) {
    var offset = 0.0;
    for (var j = 0; j < gridIndex; j++) {
      offset +=
          (rows[j].kind == TeacherGridRowKind.lesson
              ? rowHeight
              : _teacherPauseHeight) +
          _teacherRowGap;
    }
    return offset;
  }

  double _spanHeight(int startGridIndex, int duration) {
    if (duration <= 1) return rowHeight;
    var remainingLessons = duration;
    var height = 0.0;
    for (var j = startGridIndex; j < rows.length && remainingLessons > 0; j++) {
      final isLesson = rows[j].kind == TeacherGridRowKind.lesson;
      height += isLesson ? rowHeight : _teacherPauseHeight;
      if (isLesson) remainingLessons--;
      if (remainingLessons > 0) height += _teacherRowGap;
    }
    return max(rowHeight, height);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final date = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + weekdayIndex,
    );

    final lessonEntries = [
      for (final e in entries)
        if (!e.isBreakSupervision) e,
    ];
    final pauseEntries = [
      for (final e in entries)
        if (e.isBreakSupervision) e,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: _teacherHeaderHeight,
          decoration: BoxDecoration(
            color: isToday ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.E(locale).format(date),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12.5,
                      fontWeight: FontWeight.w700,
                      color: isToday ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                  Text(
                    date.format('dd.MM.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      color: isToday
                          ? cs.onPrimary.withValues(alpha: 0.9)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: _teacherRowGap),
        SizedBox(
          height: totalHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colWidth = constraints.maxWidth;
              final children = <Widget>[];

              // 1. Background pause strips + break supervision chips
              for (var rIdx = 0; rIdx < rows.length; rIdx++) {
                final row = rows[rIdx];
                final top = _offsetForRowIndex(rIdx);
                if (row.kind == TeacherGridRowKind.pause) {
                  final slotPauses = [
                    for (final p in pauseEntries)
                      if (p.hourIndex == row.beforeHourIndex) p,
                  ];
                  children.add(
                    Positioned(
                      top: top,
                      left: 0,
                      width: colWidth,
                      height: _teacherPauseHeight,
                      child: _PauseRowSlot(
                        plan: plan,
                        pauses: slotPauses,
                        dayColumnIndex: dayColumnIndex,
                        compact: compact,
                        selectedEntry: selectedEntry,
                        onSelectEntry: onSelectEntry,
                      ),
                    ),
                  );
                } else {
                  children.add(
                    Positioned(
                      top: top,
                      left: 0,
                      width: colWidth,
                      height: rowHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }
              }

              // 2. Lesson, substitution, and R&M blocks with overlap-aware lane layout
              final lessonRowIndices = <int, int>{
                for (var rIdx = 0; rIdx < rows.length; rIdx++)
                  if (rows[rIdx].kind == TeacherGridRowKind.lesson)
                    rows[rIdx].lessonRow!.lessonIndex: rIdx,
              };
              final placed =
                  <({TeacherTimetableEntry entry, int startRow, int endRow})>[];
              for (final e in lessonEntries) {
                final rIdx = e.hourIndex == null
                    ? null
                    : lessonRowIndices[e.hourIndex!];
                if (rIdx == null) continue;
                final dur = max(1, e.duration);
                var endRow = rIdx;
                var lessonsCounted = 0;
                for (var i = rIdx; i < rows.length; i++) {
                  endRow = i + 1;
                  if (rows[i].kind == TeacherGridRowKind.lesson) {
                    lessonsCounted++;
                    if (lessonsCounted >= dur) break;
                  }
                }
                placed.add((entry: e, startRow: rIdx, endRow: endRow));
              }
              placed.sort((a, b) {
                final s = a.startRow.compareTo(b.startRow);
                if (s != 0) return s;
                return b.endRow.compareTo(a.endRow);
              });

              // Group into connected overlap clusters so multi-period lessons
              // overlapping later single-period substitutions never obscure each other.
              var cursor = 0;
              while (cursor < placed.length) {
                final cluster = [placed[cursor]];
                var clusterEnd = placed[cursor].endRow;
                cursor++;
                while (cursor < placed.length &&
                    placed[cursor].startRow < clusterEnd) {
                  cluster.add(placed[cursor]);
                  if (placed[cursor].endRow > clusterEnd) {
                    clusterEnd = placed[cursor].endRow;
                  }
                  cursor++;
                }

                // Compact 2-way vertical stack when two single-period entries
                // occupy the exact same narrow slot.
                final useVerticalStack =
                    cluster.length == 2 &&
                    cluster[0].startRow == cluster[1].startRow &&
                    cluster.every((item) => item.entry.duration <= 1) &&
                    colWidth < 110;

                if (useVerticalStack) {
                  final top = _offsetForRowIndex(cluster[0].startRow);
                  final eachHeight = (rowHeight - 2) / 2;
                  for (var idx = 0; idx < cluster.length; idx++) {
                    final entry = cluster[idx].entry;
                    children.add(
                      Positioned(
                        top: top + idx * (eachHeight + 2),
                        left: 0,
                        width: colWidth,
                        height: eachHeight,
                        child: _TeacherLessonBlock(
                          plan: plan,
                          entry: entry,
                          compact: true,
                          veryCompact: true,
                          isSelected:
                              selectedEntry?.dayColumnIndex == dayColumnIndex &&
                              selectedEntry?.entry.id == entry.id,
                          onTap: () => onSelectEntry(dayColumnIndex, entry),
                        ),
                      ),
                    );
                  }
                } else {
                  final laneEnds = <int>[];
                  final assignedLanes = <int>[];
                  for (final item in cluster) {
                    var lane = -1;
                    for (var l = 0; l < laneEnds.length; l++) {
                      if (laneEnds[l] <= item.startRow) {
                        lane = l;
                        laneEnds[l] = item.endRow;
                        break;
                      }
                    }
                    if (lane < 0) {
                      lane = laneEnds.length;
                      laneEnds.add(item.endRow);
                    }
                    assignedLanes.add(lane);
                  }
                  final laneCount = laneEnds.length;
                  final eachWidth = max(
                    1.0,
                    (colWidth - (laneCount - 1) * 2) / laneCount,
                  );
                  for (var idx = 0; idx < cluster.length; idx++) {
                    final item = cluster[idx];
                    final lane = assignedLanes[idx];
                    final top = _offsetForRowIndex(item.startRow);
                    final blockHeight = _spanHeight(
                      item.startRow,
                      item.entry.duration,
                    );
                    children.add(
                      Positioned(
                        top: top,
                        left: lane * (eachWidth + 2),
                        width: eachWidth,
                        height: blockHeight,
                        child: _TeacherLessonBlock(
                          plan: plan,
                          entry: item.entry,
                          compact: compact || laneCount > 1,
                          veryCompact: false,
                          isSelected:
                              selectedEntry?.dayColumnIndex == dayColumnIndex &&
                              selectedEntry?.entry.id == item.entry.id,
                          onTap: () =>
                              onSelectEntry(dayColumnIndex, item.entry),
                        ),
                      ),
                    );
                  }
                }
              }

              // 3. Authentic Lanis red live TimeMarker line
              if (isToday && !plan.timesHidden) {
                children.add(
                  _TeacherTimeMarker(
                    rows: rows,
                    rowHeight: rowHeight,
                    width: colWidth,
                  ),
                );
              }

              return Stack(children: children);
            },
          ),
        ),
      ],
    );
  }
}

class _PauseRowSlot extends StatelessWidget {
  final TeacherTimetablePlan plan;
  final List<TeacherTimetableEntry> pauses;
  final int dayColumnIndex;
  final bool compact;
  final TeacherEntrySelection? selectedEntry;
  final void Function(int dayColumnIndex, TeacherTimetableEntry entry)
  onSelectEntry;

  const _PauseRowSlot({
    required this.plan,
    required this.pauses,
    required this.dayColumnIndex,
    required this.compact,
    required this.selectedEntry,
    required this.onSelectEntry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (pauses.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < pauses.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Builder(
              builder: (context) {
                final p = pauses[i];
                final cell = formatTeacherCell(
                  p,
                  plan.category,
                  fallbackLesson: l10n.unknownLesson,
                  fallbackBooking: l10n.teacherTimetableRoomBooking,
                  fallbackSubstitution: l10n.teacherTimetableSubstitutionAdded,
                );
                final isSelected =
                    selectedEntry?.dayColumnIndex == dayColumnIndex &&
                    selectedEntry?.entry.id == p.id;
                return Material(
                  color: cs.tertiaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: isSelected
                          ? cs.primary
                          : cs.tertiary.withValues(alpha: 0.55),
                      width: isSelected ? 1.8 : 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onSelectEntry(dayColumnIndex, p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cell.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 9 : 10,
                            fontWeight: FontWeight.w700,
                            color: cs.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _TeacherLessonBlock extends StatelessWidget {
  final TeacherTimetablePlan plan;
  final TeacherTimetableEntry entry;
  final bool compact;
  final bool veryCompact;
  final bool isSelected;
  final VoidCallback onTap;

  const _TeacherLessonBlock({
    required this.plan,
    required this.entry,
    required this.compact,
    required this.veryCompact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final cell = formatTeacherCell(
      entry,
      plan.category,
      fallbackLesson: l10n.unknownLesson,
      fallbackBooking: l10n.teacherTimetableRoomBooking,
      fallbackSubstitution: l10n.teacherTimetableSubstitutionAdded,
      fallbackSubstitutionChanged: l10n.teacherTimetableSubstitutionChanged,
      weekBadgeLabel: l10n.timetableWeek,
    );
    final style = _entryColors(context, entry);

    return Material(
      color: style.background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(veryCompact ? 6 : 8),
        side: BorderSide(
          color: isSelected ? cs.primary : style.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: veryCompact ? 1.5 : (compact ? 3 : 4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cell.eyebrow != null && !veryCompact)
                      Text(
                        cell.eyebrow!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 8 : 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                          color: style.eyebrowColor,
                          height: 1.1,
                        ),
                      ),
                    Text(
                      cell.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: veryCompact ? 9.5 : (compact ? 10.5 : 11.5),
                        fontWeight: FontWeight.w700,
                        color: style.foreground,
                        height: 1.15,
                      ),
                    ),
                    if (cell.subtitle.isNotEmpty && !veryCompact)
                      Text(
                        cell.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 8.5 : 9.5,
                          color: style.subtitleColor,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeacherTimeMarker extends StatefulWidget {
  final List<TeacherGridRow> rows;
  final double rowHeight;
  final double width;

  const _TeacherTimeMarker({
    required this.rows,
    required this.rowHeight,
    required this.width,
  });

  @override
  State<_TeacherTimeMarker> createState() => _TeacherTimeMarkerState();
}

class _TeacherTimeMarkerState extends State<_TeacherTimeMarker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final ms = (60 - now.second) * 1000 - now.millisecond;
    _timer = Timer(Duration(milliseconds: max(250, ms)), () {
      if (!mounted) return;
      setState(() {});
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowTod = SphTimeOfDay(hour: now.hour, minute: now.minute);
    final timedRows = [
      for (final r in widget.rows)
        if (r.effectiveStartTime != null &&
            r.effectiveEndTime != null &&
            (r.effectiveStartTime!.hour != 0 ||
                r.effectiveStartTime!.minute != 0))
          r,
    ];
    if (timedRows.isEmpty) return const SizedBox.shrink();
    if (nowTod < timedRows.first.effectiveStartTime! ||
        nowTod > timedRows.last.effectiveEndTime!) {
      return const SizedBox.shrink();
    }

    var offset = 0.0;
    for (final row in widget.rows) {
      final h = row.kind == TeacherGridRowKind.lesson
          ? widget.rowHeight
          : _teacherPauseHeight;
      final start = row.effectiveStartTime;
      final end = row.effectiveEndTime;
      if (start != null &&
          end != null &&
          (start.hour != 0 || start.minute != 0)) {
        if (nowTod >= start && nowTod <= end) {
          final span = end.differenceInMinutes(start).abs();
          if (span > 0) {
            final elapsed = nowTod.differenceInMinutes(start).abs();
            offset += h * (elapsed / span).clamp(0.0, 1.0);
          }
          break;
        } else if (nowTod > end) {
          offset += h + _teacherRowGap;
        } else if (nowTod < start) {
          break;
        }
      } else {
        offset += h + _teacherRowGap;
      }
    }

    return Positioned(
      top: max(0, offset - 1),
      left: 0,
      width: widget.width,
      child: IgnorePointer(
        child: Container(height: 2, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _EntryVisualStyle {
  final Color background;
  final Color border;
  final Color foreground;
  final Color subtitleColor;
  final Color eyebrowColor;
  final Color badgeBg;
  final Color badgeFg;

  const _EntryVisualStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.subtitleColor,
    required this.eyebrowColor,
    required this.badgeBg,
    required this.badgeFg,
  });
}

_EntryVisualStyle _entryColors(
  BuildContext context,
  TeacherTimetableEntry entry,
) {
  final cs = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  switch (entry.kind) {
    case TeacherTimetableEntryKind.substitutionAdded:
      final accent = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
      return _EntryVisualStyle(
        background: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.22 : 0.14),
          cs.surfaceContainerLow,
        ),
        border: accent.withValues(alpha: 0.75),
        foreground: cs.onSurface,
        subtitleColor: cs.onSurfaceVariant,
        eyebrowColor: accent,
        badgeBg: accent,
        badgeFg: isDark ? const Color(0xFF06290B) : Colors.white,
      );
    case TeacherTimetableEntryKind.substitutionChanged:
      return _EntryVisualStyle(
        background: Color.alphaBlend(
          cs.error.withValues(alpha: isDark ? 0.22 : 0.13),
          cs.surfaceContainerLow,
        ),
        border: cs.error.withValues(alpha: 0.75),
        foreground: cs.onSurface,
        subtitleColor: cs.onSurfaceVariant,
        eyebrowColor: cs.error,
        badgeBg: cs.error,
        badgeFg: cs.onError,
      );
    case TeacherTimetableEntryKind.roomBooking:
      final accent = isDark ? const Color(0xFF42A5F5) : const Color(0xFF1565C0);
      return _EntryVisualStyle(
        background: Color.alphaBlend(
          accent.withValues(alpha: isDark ? 0.22 : 0.14),
          cs.surfaceContainerLow,
        ),
        border: accent.withValues(alpha: 0.75),
        foreground: cs.onSurface,
        subtitleColor: cs.onSurfaceVariant,
        eyebrowColor: accent,
        badgeBg: accent,
        badgeFg: isDark ? const Color(0xFF052242) : Colors.white,
      );
    case TeacherTimetableEntryKind.breakSupervision:
      return _EntryVisualStyle(
        background: cs.tertiaryContainer,
        border: cs.tertiary.withValues(alpha: 0.65),
        foreground: cs.onTertiaryContainer,
        subtitleColor: cs.onTertiaryContainer.withValues(alpha: 0.8),
        eyebrowColor: cs.tertiary,
        badgeBg: cs.tertiary,
        badgeFg: cs.onTertiary,
      );
    case TeacherTimetableEntryKind.regular:
      final seed = entry.subject ?? entry.course ?? entry.id;
      final baseColor = RandomColor.bySeed(seed).primary;
      final tinted = Color.alphaBlend(
        baseColor.withValues(alpha: isDark ? 0.26 : 0.18),
        cs.surfaceContainerHigh,
      );
      return _EntryVisualStyle(
        background: tinted,
        border: baseColor.withValues(alpha: isDark ? 0.5 : 0.35),
        foreground: cs.onSurface,
        subtitleColor: cs.onSurfaceVariant,
        eyebrowColor: cs.onSurfaceVariant,
        badgeBg: cs.secondaryContainer,
        badgeFg: cs.onSecondaryContainer,
      );
  }
}

TimeTableRow? _findLessonRow(List<TimeTableRow> hours, int? hourIndex) {
  if (hourIndex == null) return null;
  for (final r in hours) {
    if (r.lessonIndex == hourIndex) return r;
  }
  return null;
}
