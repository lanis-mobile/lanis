import 'package:intl/intl.dart';
import 'package:lanis/applets/timetable/teacher/teacher_timetable_models.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/liblanis_ui.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:liblanis/liblanis.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact inline banner shown above the timetable grid only when the active
/// plan has a school notice.
class TeacherPlanContextBanner extends StatelessWidget {
  final TeacherTimetablePlan plan;

  const TeacherPlanContextBanner({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final noticeText = plan.noticeHtml == null
        ? ''
        : plainNoticeText(plan.noticeHtml!);
    if (noticeText.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.tertiary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: cs.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Text(
                noticeText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onTertiaryContainer,
                ),
              ),
            ),
            if (plan.validFromLabel != null &&
                plan.validFromLabel!.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  plan.validFromLabel!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared C2 search & catalog core component used in both the Tablet left
/// sidebar and the Phone modal bottom sheet: search bar at top → compact
/// "Mein Plan & Zuletzt" chip strip → collapsible category accordions.
class TeacherPlanCatalogPanel extends StatefulWidget {
  final TeacherTimetableOverview overview;
  final TeacherTimetableTarget? ownTarget;
  final String? ownTeacherId;
  final TeacherTimetableTarget? activeTarget;
  final List<TeacherTimetableTarget> recentTargets;
  final Set<TeacherTimetableCategory> expandedCategories;
  final ValueChanged<TeacherTimetableCategory> onToggleCategory;
  final ValueChanged<TeacherTimetableTarget> onSelectTarget;
  final ScrollController? scrollController;

  const TeacherPlanCatalogPanel({
    super.key,
    required this.overview,
    required this.ownTarget,
    this.ownTeacherId,
    required this.activeTarget,
    this.recentTargets = const [],
    required this.expandedCategories,
    required this.onToggleCategory,
    required this.onSelectTarget,
    this.scrollController,
  });

  @override
  State<TeacherPlanCatalogPanel> createState() =>
      _TeacherPlanCatalogPanelState();
}

class _TeacherPlanCatalogPanelState extends State<TeacherPlanCatalogPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CatalogSection> _buildSections(AppLocalizations l10n) {
    final q = _query.trim().toLowerCase();
    bool matches(String label, String id) =>
        q.isEmpty ||
        label.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q);

    final sections = <_CatalogSection>[];

    // Teachers (excluding own plan — "Mein Plan" lives in the quick strip / search header)
    final own = widget.ownTarget;
    final ownIdLower = widget.ownTeacherId?.trim().toLowerCase();
    final teacherItems = <TeacherTimetableTarget>[
      for (final ref in widget.overview.teachers)
        if (!(own != null &&
                ownIdLower != null &&
                ownIdLower.isNotEmpty &&
                ref.id.trim().toLowerCase() == ownIdLower) &&
            matches(ref.label, ref.id))
          TeacherTimetableTarget(reference: ref),
    ];
    if (teacherItems.isNotEmpty) {
      sections.add(
        _CatalogSection(
          category: TeacherTimetableCategory.teacher,
          title: l10n.teacherTimetableTeachers,
          icon: Icons.person_outline,
          items: teacherItems,
        ),
      );
    }

    // Classes
    final classItems = [
      for (final ref in widget.overview.classes)
        if (matches(ref.label, ref.id))
          TeacherTimetableTarget(reference: ref),
    ];
    if (classItems.isNotEmpty) {
      sections.add(
        _CatalogSection(
          category: TeacherTimetableCategory.schoolClass,
          title: l10n.teacherTimetableClasses,
          icon: Icons.groups_outlined,
          items: classItems,
        ),
      );
    }

    // Rooms
    final roomItems = [
      for (final ref in widget.overview.rooms)
        if (matches(ref.label, ref.id))
          TeacherTimetableTarget(reference: ref),
    ];
    if (roomItems.isNotEmpty) {
      sections.add(
        _CatalogSection(
          category: TeacherTimetableCategory.room,
          title: l10n.teacherTimetableRooms,
          icon: Icons.meeting_room_outlined,
          items: roomItems,
        ),
      );
    }

    // Break supervisions
    final pauseItems = [
      for (final ref in widget.overview.breakSupervisions)
        if (matches(ref.label, ref.id))
          TeacherTimetableTarget(reference: ref),
    ];
    if (pauseItems.isNotEmpty) {
      sections.add(
        _CatalogSection(
          category: TeacherTimetableCategory.breakSupervision,
          title: l10n.teacherTimetableBreakSupervisions,
          icon: Icons.shield_outlined,
          items: pauseItems,
        ),
      );
    }

    return sections;
  }

  String _shortChipLabel(TeacherTimetableTarget target) {
    if (target.isOwn) return target.label;
    // For teacher labels like "unpriviligiert, alessio (CAP2)", use the short
    // code inside parentheses so chips stay crisp even in a 228px sidebar.
    if (target.category == TeacherTimetableCategory.teacher &&
        target.id.trim().isNotEmpty) {
      return target.id.trim();
    }
    return target.label;
  }

  Widget _buildSearchField(AppLocalizations l10n, ColorScheme cs) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        isDense: true,
        hintText: l10n.teacherTimetableFilterPlans,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  List<Widget> _buildQuickChips(TeacherTimetableTarget? own) {
    final chips = <Widget>[];
    if (own != null) {
      chips.add(
        _QuickAccessChip(
          icon: Icons.person,
          label: own.label,
          selected: widget.activeTarget == own,
          onTap: () => widget.onSelectTarget(own),
        ),
      );
    }
    for (final recent in widget.recentTargets) {
      chips.add(
        _QuickAccessChip(
          icon: Icons.schedule,
          label: _shortChipLabel(recent),
          selected: widget.activeTarget == recent,
          onTap: () => widget.onSelectTarget(recent),
        ),
      );
    }
    // Fallback suggestions if an admin has neither own plan nor recents yet.
    if (chips.isEmpty) {
      final fallback = [
        ...widget.overview.classes,
        ...widget.overview.rooms,
        ...widget.overview.teachers,
      ].take(3);
      for (final ref in fallback) {
        final target = TeacherTimetableTarget(reference: ref);
        chips.add(
          _QuickAccessChip(
            icon: Icons.groups_outlined,
            label: _shortChipLabel(target),
            selected: widget.activeTarget == target,
            onTap: () => widget.onSelectTarget(target),
          ),
        );
      }
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final trimmedQuery = _query.trim();
    final isSearching = trimmedQuery.isNotEmpty;
    final sections = _buildSections(l10n);

    final own = widget.ownTarget;
    final ownMatchesQuery =
        own != null &&
        isSearching &&
        (own.label.toLowerCase().contains(trimmedQuery.toLowerCase()) ||
            (widget.ownTeacherId?.toLowerCase().contains(
                  trimmedQuery.toLowerCase(),
                ) ??
                false));

    final showQuickStrip =
        !isSearching && (own != null || widget.recentTargets.isNotEmpty);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(l10n, cs),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: showQuickStrip
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _buildQuickChips(own),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: sections.isEmpty && !ownMatchesQuery
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l10n.teacherTimetableNoMatches,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
                  children: [
                    if (ownMatchesQuery)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _CatalogListItem(
                          target: own,
                          selected: widget.activeTarget == own,
                          highlightQuery: trimmedQuery,
                          onTap: () => widget.onSelectTarget(own),
                        ),
                      ),
                    for (final section in sections)
                      _CatalogAccordion(
                        section: section,
                        expanded:
                            isSearching ||
                            widget.expandedCategories.contains(
                              section.category,
                            ),
                        activeTarget: widget.activeTarget,
                        highlightQuery: trimmedQuery,
                        onToggle: () =>
                            widget.onToggleCategory(section.category),
                        onSelectTarget: widget.onSelectTarget,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QuickAccessChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickAccessChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.surfaceContainerHighest.withValues(alpha: 0.7),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? cs.primary.withValues(alpha: 0.55)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? cs.onPrimaryContainer : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogAccordion extends StatelessWidget {
  final _CatalogSection section;
  final bool expanded;
  final TeacherTimetableTarget? activeTarget;
  final String highlightQuery;
  final VoidCallback onToggle;
  final ValueChanged<TeacherTimetableTarget> onSelectTarget;

  const _CatalogAccordion({
    required this.section,
    required this.expanded,
    required this.activeTarget,
    required this.highlightQuery,
    required this.onToggle,
    required this.onSelectTarget,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    Icon(section.icon, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${section.items.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? section.category == TeacherTimetableCategory.teacher
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Column(
                              children: [
                                for (final target in section.items)
                                  _CatalogListItem(
                                    target: target,
                                    selected: activeTarget == target,
                                    highlightQuery: highlightQuery,
                                    onTap: () => onSelectTarget(target),
                                  ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final target in section.items)
                                  _CatalogWrapChip(
                                    target: target,
                                    selected: activeTarget == target,
                                    highlightQuery: highlightQuery,
                                    onTap: () => onSelectTarget(target),
                                  ),
                              ],
                            ),
                          )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogSection {
  final TeacherTimetableCategory category;
  final String title;
  final IconData icon;
  final List<TeacherTimetableTarget> items;

  const _CatalogSection({
    required this.category,
    required this.title,
    required this.icon,
    required this.items,
  });
}

class _CatalogListItem extends StatelessWidget {
  final TeacherTimetableTarget target;
  final bool selected;
  final String highlightQuery;
  final VoidCallback onTap;

  const _CatalogListItem({
    required this.target,
    required this.selected,
    this.highlightQuery = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected ? cs.onPrimaryContainer : cs.onSurface,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected
            ? cs.primaryContainer.withValues(alpha: 0.85)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            child: Row(
              children: [
                if (target.isOwn) ...[
                  Icon(
                    Icons.person,
                    size: 16,
                    color: selected ? cs.onPrimaryContainer : cs.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: _HighlightedText(
                    text: target.label,
                    query: highlightQuery,
                    style: baseStyle,
                    highlightBg: cs.primary.withValues(alpha: 0.22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogWrapChip extends StatelessWidget {
  final TeacherTimetableTarget target;
  final bool selected;
  final String highlightQuery;
  final VoidCallback onTap;

  const _CatalogWrapChip({
    required this.target,
    required this.selected,
    this.highlightQuery = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected ? cs.onPrimaryContainer : cs.onSurface,
    );

    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.surfaceContainerHighest.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected
              ? cs.primary.withValues(alpha: 0.6)
              : cs.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: _HighlightedText(
            text: target.label,
            query: highlightQuery,
            style: baseStyle,
            highlightBg: cs.primary.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final Color highlightBg;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightBg,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim();
    if (q.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final match = RegExp(
      RegExp.escape(q),
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (match.start > 0) TextSpan(text: text.substring(0, match.start)),
          TextSpan(
            text: text.substring(match.start, match.end),
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              backgroundColor: highlightBg,
            ),
          ),
          if (match.end < text.length) TextSpan(text: text.substring(match.end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Zero-redundancy detail inspector shown in Pane 3 on Tablet (1B-2) and inside
/// a modal bottom sheet on Phone (Design 1).
class TeacherEntryInspectorPanel extends StatelessWidget {
  final TeacherTimetablePlan plan;
  final TeacherTimetableOverview overview;
  final TeacherEntrySelection selection;
  final DateTime weekStart;
  final ValueChanged<TeacherTimetableTarget> onOpenTarget;
  final ValueChanged<TeacherTimetableEntry> onSelectSibling;
  final VoidCallback? onClose;

  const TeacherEntryInspectorPanel({
    super.key,
    required this.plan,
    required this.overview,
    required this.selection,
    required this.weekStart,
    required this.onOpenTarget,
    required this.onSelectSibling,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final entry = selection.entry;
    final cell = formatTeacherCell(
      entry,
      plan.category,
      fallbackLesson: l10n.unknownLesson,
      fallbackBooking: l10n.teacherTimetableRoomBooking,
      fallbackSubstitution: l10n.teacherTimetableSubstitutionAdded,
      fallbackSubstitutionChanged: l10n.teacherTimetableSubstitutionChanged,
      weekBadgeLabel: l10n.timetableWeek,
    );

    final weekdayIdx =
        selection.dayColumnIndex >= 0 &&
            selection.dayColumnIndex < plan.weekdayIndices.length
        ? plan.weekdayIndices[selection.dayColumnIndex]
        : selection.dayColumnIndex.clamp(0, 6);
    final date = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + weekdayIdx,
    );
    final dayName = DateFormat.EEEE(
      Localizations.localeOf(context).languageCode,
    ).format(date);

    TimeTableRow? hourRow;
    for (final r in plan.hours) {
      if (r.lessonIndex == entry.hourIndex) {
        hourRow = r;
        break;
      }
    }

    final timeLabel = entry.isBreakSupervision
        ? '$dayName · ${l10n.teacherTimetablePauseBefore(hourRow?.label ?? '${entry.hourIndex ?? ''}.')}'
        : _formatLessonTime(context, dayName, hourRow, entry, plan.timesHidden);

    final metadata = resolveEntryMetadata(
      entry: entry,
      plan: plan,
      overview: overview,
      openRoomPlanLabel: l10n.teacherTimetableOpenRoomPlan,
    );

    final siblings = <TeacherTimetableEntry>[];
    if (selection.dayColumnIndex >= 0 &&
        selection.dayColumnIndex < plan.days.length &&
        !entry.isBreakSupervision) {
      for (final other in plan.days[selection.dayColumnIndex]) {
        if (other.id != entry.id &&
            !other.isBreakSupervision &&
            other.hourIndex == entry.hourIndex) {
          siblings.add(other);
        }
      }
    }

    final headerTitle = entry.isBreakSupervision
        ? l10n.teacherTimetableBreakSupervisions
        : entry.isRoomBooking
        ? l10n.teacherTimetableRoomBooking
        : l10n.teacherTimetableLessonDetails;

    final heroAccent = _heroAccent(context, entry);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: heroAccent.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: heroAccent.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      cell.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (cell.eyebrow != null || entry.isBreakSupervision) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: heroAccent.tagBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cell.eyebrow ?? l10n.teacherTimetablePause,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: heroAccent.tagFg,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 15,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      timeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isRedundantLanisTooltip(entry.tooltip)) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.tooltip!.trim(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (metadata.attributes.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final attr in metadata.attributes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    attr.isCourse
                        ? Icons.book_outlined
                        : _categoryIcon(attr.category),
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      attr.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (metadata.links.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.teacherTimetableLinkedPlans.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          for (final link in metadata.links)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: FilledButton.tonal(
                onPressed: () => onOpenTarget(link.target),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_categoryIcon(link.category), size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        link.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
        ],
        if (entry.externalUrl != null && entry.isRoomBooking) ...[
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () => safeLaunchUrl(
              entry.externalUrl!,
              context: context,
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l10n.teacherTimetableOpenInRumbs),
          ),
        ],
        if (siblings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.teacherTimetableParallelInSlot.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          for (final sib in siblings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Builder(
                builder: (context) {
                  final sc = formatTeacherCell(
                    sib,
                    plan.category,
                    fallbackLesson: l10n.unknownLesson,
                    fallbackBooking: l10n.teacherTimetableRoomBooking,
                    fallbackSubstitution: l10n.teacherTimetableSubstitutionAdded,
                    weekBadgeLabel: l10n.timetableWeek,
                  );
                  return OutlinedButton(
                    onPressed: () => onSelectSibling(sib),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sc.title,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (sc.subtitle.isNotEmpty)
                                Text(
                                  sc.subtitle,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (sc.eyebrow != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              sc.eyebrow!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );

    if (onClose == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: content,
      );
    }

    return Column(
      children: [
        SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    headerTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: content,
          ),
        ),
      ],
    );
  }

  static String _formatLessonTime(
    BuildContext context,
    String dayName,
    TimeTableRow? row,
    TeacherTimetableEntry entry,
    bool timesHidden,
  ) {
    final hourPart = row != null
        ? row.label
        : (entry.hourIndex != null ? '${entry.hourIndex}.' : '');
    final hasTimes =
        !timesHidden &&
        (entry.startTime.hour != 0 ||
            entry.startTime.minute != 0 ||
            entry.endTime.hour != 0 ||
            entry.endTime.minute != 0);
    if (hasTimes) {
      final start = entry.startTime.toFlutter().format(context);
      final end = entry.endTime.toFlutter().format(context);
      return hourPart.isNotEmpty
          ? '$dayName · $hourPart ($start–$end)'
          : '$dayName · $start–$end';
    }
    return hourPart.isNotEmpty ? '$dayName · $hourPart' : dayName;
  }

  static IconData _categoryIcon(TeacherTimetableCategory? cat) => switch (cat) {
    TeacherTimetableCategory.teacher => Icons.person_outline,
    TeacherTimetableCategory.schoolClass => Icons.groups_outlined,
    TeacherTimetableCategory.room => Icons.meeting_room_outlined,
    TeacherTimetableCategory.breakSupervision => Icons.shield_outlined,
    null => Icons.info_outline,
  };

  static ({Color bg, Color border, Color tagBg, Color tagFg}) _heroAccent(
    BuildContext context,
    TeacherTimetableEntry entry,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (entry.kind) {
      case TeacherTimetableEntryKind.substitutionAdded:
        final accent = isDark
            ? const Color(0xFF66BB6A)
            : const Color(0xFF2E7D32);
        return (
          bg: Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.18 : 0.12),
            cs.surfaceContainerLow,
          ),
          border: accent.withValues(alpha: 0.65),
          tagBg: accent,
          tagFg: isDark ? const Color(0xFF06290B) : Colors.white,
        );
      case TeacherTimetableEntryKind.substitutionChanged:
        return (
          bg: Color.alphaBlend(
            cs.error.withValues(alpha: isDark ? 0.18 : 0.10),
            cs.surfaceContainerLow,
          ),
          border: cs.error.withValues(alpha: 0.65),
          tagBg: cs.error,
          tagFg: cs.onError,
        );
      case TeacherTimetableEntryKind.roomBooking:
        final accent = isDark
            ? const Color(0xFF42A5F5)
            : const Color(0xFF1565C0);
        return (
          bg: Color.alphaBlend(
            accent.withValues(alpha: isDark ? 0.18 : 0.12),
            cs.surfaceContainerLow,
          ),
          border: accent.withValues(alpha: 0.65),
          tagBg: accent,
          tagFg: isDark ? const Color(0xFF052242) : Colors.white,
        );
      case TeacherTimetableEntryKind.breakSupervision:
        return (
          bg: cs.tertiaryContainer.withValues(alpha: 0.65),
          border: cs.tertiary.withValues(alpha: 0.6),
          tagBg: cs.tertiary,
          tagFg: cs.onTertiary,
        );
      case TeacherTimetableEntryKind.regular:
        return (
          bg: cs.surfaceContainerHigh,
          border: cs.outlineVariant,
          tagBg: cs.secondaryContainer,
          tagFg: cs.onSecondaryContainer,
        );
    }
  }
}

/// Interactive Free Rooms finder ("Freie Räume") used both in Tablet Pane 3
/// (1B-2) and inside the Phone modal bottom sheet (Design 1).
class TeacherFreeRoomsPanel extends StatelessWidget {
  final int weekday;
  final List<int> selectedHours;
  final List<int> availableHours;
  final List<TeacherTimetableReference> rooms;
  final bool loading;
  final Object? error;
  final bool isTabletPane;
  final ValueChanged<int> onSelectWeekday;
  final ValueChanged<int> onToggleHour;
  final ValueChanged<TeacherTimetableTarget> onOpenRoom;
  final VoidCallback onRetry;
  final VoidCallback? onClose;

  const TeacherFreeRoomsPanel({
    super.key,
    required this.weekday,
    required this.selectedHours,
    required this.availableHours,
    required this.rooms,
    required this.loading,
    required this.error,
    required this.isTabletPane,
    required this.onSelectWeekday,
    required this.onToggleHour,
    required this.onOpenRoom,
    required this.onRetry,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    // Reference Monday for short weekday names (2024-01-01 was a Monday).
    final monday = DateTime(2024, 1, 1);
    final hours = availableHours.isNotEmpty
        ? availableHours
        : const [1, 2, 3, 4, 5, 6, 7, 8];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.teacherTimetableWeekday.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 5; d++)
              ChoiceChip(
                label: Text(
                  DateFormat.E(
                    locale,
                  ).format(DateTime(monday.year, monday.month, d)),
                ),
                selected: weekday == d,
                onSelected: (_) => onSelectWeekday(d),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.teacherTimetablePeriods.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final h in hours)
              FilterChip(
                label: Text('$h'),
                selected: selectedHours.contains(h),
                onSelected: (_) => onToggleHour(h),
                visualDensity: VisualDensity.compact,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.teacherTimetableFreeRoomsCount(rooms.length).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (error != null) ...[
          Text(
            error.toString(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.error),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onRetry,
              child: Text(l10n.tryAgain),
            ),
          ),
        ] else if (selectedHours.isEmpty) ...[
          Text(
            l10n.teacherTimetableSelectHourPrompt,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ] else if (rooms.isEmpty && !loading) ...[
          Text(
            l10n.noEntries,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ] else ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final room in rooms)
                ActionChip(
                  label: Text(room.label),
                  onPressed: () =>
                      onOpenRoom(TeacherTimetableTarget(reference: room)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTabletPane
                ? l10n.teacherTimetableFreeRoomsHintTablet
                : l10n.teacherTimetableFreeRoomsHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );

    if (onClose == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: body,
      );
    }

    return Column(
      children: [
        SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.teacherTimetableFreeRooms,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: body,
          ),
        ),
      ],
    );
  }
}
