import 'package:html/parser.dart' as html_parser;
import 'package:liblanis/liblanis.dart';

/// Identifies an openable timetable target in the teacher timetable view.
class TeacherTimetableTarget {
  final TeacherTimetableReference reference;
  final bool isOwn;

  const TeacherTimetableTarget({required this.reference, this.isOwn = false});

  TeacherTimetableCategory get category => reference.category;
  String get id => reference.id;
  String get label => reference.label;

  /// Stable key for caching and selection comparison.
  String get key => isOwn ? 'own' : '${reference.category.name}:${reference.id}';

  @override
  bool operator ==(Object other) =>
      other is TeacherTimetableTarget && key == other.key;

  @override
  int get hashCode => key.hashCode;
}

/// Selected cell entry inside a [TeacherTimetablePlan].
class TeacherEntrySelection {
  final int dayColumnIndex;
  final TeacherTimetableEntry entry;

  const TeacherEntrySelection({
    required this.dayColumnIndex,
    required this.entry,
  });

  @override
  bool operator ==(Object other) =>
      other is TeacherEntrySelection &&
      dayColumnIndex == other.dayColumnIndex &&
      entry.id == other.entry.id;

  @override
  int get hashCode => Object.hash(dayColumnIndex, entry.id);
}

enum TeacherGridRowKind { lesson, pause }

/// Display row in the teacher timetable grid (either a lesson period or a
/// synthesized slim break bar that also carries break supervisions).
class TeacherGridRow {
  final TeacherGridRowKind kind;
  final TimeTableRow? lessonRow;

  /// For [TeacherGridRowKind.pause]: the 1-based [TimeTableRow.index] of the
  /// lesson row that immediately follows this break.
  final int? beforeHourIndex;

  /// Optional start/end times for break rows (for TimeMarker positioning).
  final SphTimeOfDay? startTime;
  final SphTimeOfDay? endTime;

  const TeacherGridRow.lesson(TimeTableRow row)
    : kind = TeacherGridRowKind.lesson,
      lessonRow = row,
      beforeHourIndex = null,
      startTime = null,
      endTime = null;

  const TeacherGridRow.pause({
    required this.beforeHourIndex,
    this.startTime,
    this.endTime,
  }) : kind = TeacherGridRowKind.pause,
       lessonRow = null;

  SphTimeOfDay? get effectiveStartTime =>
      kind == TeacherGridRowKind.lesson ? lessonRow!.startTime : startTime;

  SphTimeOfDay? get effectiveEndTime =>
      kind == TeacherGridRowKind.lesson ? lessonRow!.endTime : endTime;
}

/// Builds the ordered grid rows for [plan], inserting slim break rows wherever
/// there is a time gap between periods or a [TeacherTimetableEntryKind.breakSupervision]
/// attached to a period.
List<TeacherGridRow> buildTeacherGridRows(TeacherTimetablePlan plan) {
  final pauseBeforeIndices = <int>{};
  for (final day in plan.days) {
    for (final entry in day) {
      if (entry.isBreakSupervision && entry.hourIndex != null) {
        pauseBeforeIndices.add(entry.hourIndex!);
      }
    }
  }

  final rows = <TeacherGridRow>[];
  TimeTableRow? prev;
  for (final row in plan.hours) {
    final gapMinutes =
        !plan.timesHidden &&
            prev != null &&
            _hasRealTime(prev.endTime) &&
            _hasRealTime(row.startTime)
        ? prev.endTime.differenceInMinutes(row.startTime)
        : 0;
    final hasTimeGap = gapMinutes > 10;
    final hasSupervisionBefore = pauseBeforeIndices.contains(row.lessonIndex);
    if (hasTimeGap || hasSupervisionBefore) {
      rows.add(
        TeacherGridRow.pause(
          beforeHourIndex: row.lessonIndex,
          startTime: hasTimeGap ? prev!.endTime : null,
          endTime: hasTimeGap ? row.startTime : null,
        ),
      );
    }
    rows.add(TeacherGridRow.lesson(row));
    prev = row;
  }
  return rows;
}

bool _hasRealTime(SphTimeOfDay t) => t.hour != 0 || t.minute != 0;

/// Zero-redundancy cell presentation for a [TeacherTimetableEntry].
class TeacherCellPresentation {
  final String? eyebrow;
  final String title;
  final String subtitle;

  const TeacherCellPresentation({
    this.eyebrow,
    required this.title,
    required this.subtitle,
  });
}

/// Formats a timetable entry for the grid without repeating the active view's
/// own dimension (no teacher code on teacher plan, no class on class plan,
/// no room on room plan, no location on break-supervision plan).
TeacherCellPresentation formatTeacherCell(
  TeacherTimetableEntry entry,
  TeacherTimetableCategory viewCategory, {
  required String fallbackLesson,
  required String fallbackBooking,
  required String fallbackSubstitution,
  String? fallbackSubstitutionChanged,
  String Function(String badge)? weekBadgeLabel,
}) {
  if (entry.isBreakSupervision) {
    final main = viewCategory == TeacherTimetableCategory.breakSupervision
        ? (entry.teachers.isNotEmpty
              ? entry.teachers.join(', ')
              : (entry.supervisionLocation ?? ''))
        : (entry.supervisionLocation ??
              (entry.teachers.isNotEmpty ? entry.teachers.join(', ') : ''));
    return TeacherCellPresentation(eyebrow: null, title: main, subtitle: '');
  }

  if (entry.isRoomBooking) {
    final date = entry.embeddedDate?.trim();
    final eyebrow = (date != null && date.isNotEmpty) ? 'R&M $date' : 'R&M';
    final main = viewCategory == TeacherTimetableCategory.room
        ? (entry.teachers.isNotEmpty
              ? entry.teachers.join(', ')
              : (entry.subject ?? fallbackBooking))
        : (entry.room ?? entry.subject ?? fallbackBooking);
    final subParts = <String>[];
    if (entry.subject != null &&
        entry.subject!.trim().isNotEmpty &&
        entry.subject != main) {
      subParts.add(entry.subject!.trim());
    }
    if (viewCategory != TeacherTimetableCategory.teacher &&
        entry.teachers.isNotEmpty &&
        main != entry.teachers.join(', ')) {
      subParts.add(entry.teachers.join(', '));
    }
    return TeacherCellPresentation(
      eyebrow: eyebrow,
      title: main,
      subtitle: subParts.join(' · '),
    );
  }

  if (entry.isEmbeddedSubstitution) {
    final date = entry.embeddedDate?.trim();
    final isAdded = entry.kind == TeacherTimetableEntryKind.substitutionAdded;
    final eyebrow = (date != null && date.isNotEmpty)
        ? (isAdded ? '+$date' : '−$date')
        : (isAdded ? '+' : '−');
    final subParts = <String>[];
    if (viewCategory != TeacherTimetableCategory.schoolClass &&
        entry.classes.isNotEmpty) {
      subParts.add(entry.classes.join(', '));
    }
    if (viewCategory != TeacherTimetableCategory.room &&
        entry.room != null &&
        entry.room!.trim().isNotEmpty) {
      subParts.add(entry.room!.trim());
    }
    if (viewCategory != TeacherTimetableCategory.teacher &&
        entry.teachers.isNotEmpty) {
      subParts.add(entry.teachers.join(', '));
    }
    return TeacherCellPresentation(
      eyebrow: eyebrow,
      title: (entry.subject?.trim().isNotEmpty ?? false)
          ? entry.subject!.trim()
          : (isAdded
                ? fallbackSubstitution
                : (fallbackSubstitutionChanged ?? fallbackSubstitution)),
      subtitle: subParts.join(' · '),
    );
  }

  final subParts = <String>[];
  if (viewCategory != TeacherTimetableCategory.schoolClass &&
      entry.classes.isNotEmpty) {
    subParts.add(entry.classes.join(', '));
  }
  if (viewCategory != TeacherTimetableCategory.teacher &&
      entry.teachers.isNotEmpty) {
    subParts.add(entry.teachers.join(', '));
  }
  if (viewCategory != TeacherTimetableCategory.room &&
      entry.room != null &&
      entry.room!.trim().isNotEmpty) {
    subParts.add(entry.room!.trim());
  }
  final badge = entry.badge?.trim();
  final eyebrow = (badge != null && badge.isNotEmpty)
      ? (weekBadgeLabel != null ? weekBadgeLabel(badge) : badge)
      : null;

  return TeacherCellPresentation(
    eyebrow: eyebrow,
    title: (entry.subject?.trim().isNotEmpty ?? false)
        ? entry.subject!.trim()
        : fallbackLesson,
    subtitle: subParts.join(' · '),
  );
}

/// Cross-link target discovered from an entry's metadata (class, room, teacher,
/// or break supervision location) matched against available catalog references.
class TeacherCrossLink {
  final TeacherTimetableCategory category;
  final String displayLabel;
  final TeacherTimetableTarget target;

  const TeacherCrossLink({
    required this.category,
    required this.displayLabel,
    required this.target,
  });
}

/// Non-linkable attribute row (e.g. course code, or a class/room/teacher that
/// is not present in the school's navigable catalog).
class TeacherStaticAttribute {
  final TeacherTimetableCategory? category;
  final String text;
  final bool isCourse;

  const TeacherStaticAttribute({
    this.category,
    required this.text,
    this.isCourse = false,
  });
}

/// Splits an entry's metadata into zero-redundancy interactive [TeacherCrossLink]s
/// and non-linkable [TeacherStaticAttribute]s.
({List<TeacherCrossLink> links, List<TeacherStaticAttribute> attributes})
resolveEntryMetadata({
  required TeacherTimetableEntry entry,
  required TeacherTimetablePlan plan,
  required TeacherTimetableOverview overview,
  required String openRoomPlanLabel,
}) {
  final links = <TeacherCrossLink>[];
  final attributes = <TeacherStaticAttribute>[];
  final seenKeys = <String>{};

  TeacherTimetableReference? findRef(
    TeacherTimetableCategory category,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final list = switch (category) {
      TeacherTimetableCategory.teacher => overview.teachers,
      TeacherTimetableCategory.schoolClass => overview.classes,
      TeacherTimetableCategory.room => overview.rooms,
      TeacherTimetableCategory.breakSupervision => overview.breakSupervisions,
    };
    for (final ref in list) {
      if (ref.id.trim().toLowerCase() == normalized ||
          ref.label.trim().toLowerCase() == normalized) {
        return ref;
      }
    }
    if (plan.category == category) {
      for (final ref in plan.availableTargets) {
        if (ref.id.trim().toLowerCase() == normalized ||
            ref.label.trim().toLowerCase() == normalized) {
          return ref;
        }
      }
    }
    return null;
  }

  void addLink(
    TeacherTimetableCategory category,
    String displayLabel,
    TeacherTimetableReference ref,
  ) {
    final target = TeacherTimetableTarget(reference: ref);
    if (seenKeys.add(target.key)) {
      links.add(
        TeacherCrossLink(
          category: category,
          displayLabel: displayLabel,
          target: target,
        ),
      );
    }
  }

  if (plan.category != TeacherTimetableCategory.schoolClass) {
    for (final cls in entry.classes) {
      final ref = findRef(TeacherTimetableCategory.schoolClass, cls);
      if (ref != null) {
        addLink(TeacherTimetableCategory.schoolClass, cls, ref);
      } else if (cls.trim().isNotEmpty) {
        attributes.add(
          TeacherStaticAttribute(
            category: TeacherTimetableCategory.schoolClass,
            text: cls.trim(),
          ),
        );
      }
    }
  }

  if (plan.category != TeacherTimetableCategory.room &&
      entry.room != null &&
      entry.room!.trim().isNotEmpty) {
    final roomName = entry.room!.trim();
    final ref = findRef(TeacherTimetableCategory.room, roomName);
    if (ref != null) {
      addLink(
        TeacherTimetableCategory.room,
        entry.isRoomBooking ? openRoomPlanLabel : roomName,
        ref,
      );
    } else {
      attributes.add(
        TeacherStaticAttribute(
          category: TeacherTimetableCategory.room,
          text: roomName,
        ),
      );
    }
  }

  if (plan.category != TeacherTimetableCategory.teacher) {
    for (final teacher in entry.teachers) {
      final ref = findRef(TeacherTimetableCategory.teacher, teacher);
      if (ref != null) {
        addLink(TeacherTimetableCategory.teacher, ref.label, ref);
      } else if (teacher.trim().isNotEmpty) {
        attributes.add(
          TeacherStaticAttribute(
            category: TeacherTimetableCategory.teacher,
            text: teacher.trim(),
          ),
        );
      }
    }
  }

  if (plan.category != TeacherTimetableCategory.breakSupervision &&
      entry.supervisionLocation != null &&
      entry.supervisionLocation!.trim().isNotEmpty) {
    final loc = entry.supervisionLocation!.trim();
    final ref = findRef(TeacherTimetableCategory.breakSupervision, loc);
    if (ref != null) {
      addLink(TeacherTimetableCategory.breakSupervision, loc, ref);
    } else if (!entry.isBreakSupervision) {
      attributes.add(
        TeacherStaticAttribute(
          category: TeacherTimetableCategory.breakSupervision,
          text: loc,
        ),
      );
    }
  }

  if (entry.course != null && entry.course!.trim().isNotEmpty) {
    final courseText = entry.course!.trim();
    final subjectText = entry.subject?.trim().toLowerCase() ?? '';
    if (courseText.toLowerCase() != subjectText) {
      attributes.add(TeacherStaticAttribute(text: courseText, isCourse: true));
    }
  }

  return (links: links, attributes: attributes);
}

/// Returns `true` when [tooltip] is merely Lanis's auto-generated summary
/// (`"<Fach> im Raum <Raum> bei der Klasse/Stufe/Lerngruppe <Klasse>"`)
/// that duplicates structured fields already displayed in the card/inspector.
bool isRedundantLanisTooltip(String? tooltip) {
  if (tooltip == null) return true;
  final trimmed = tooltip.trim();
  if (trimmed.isEmpty) return true;
  if (trimmed.contains(' bei der Klasse/Stufe/Lerngruppe ')) return true;
  // Standard Lanis teacher-plan boilerplate: "<Fach> im Raum <Raum> (<Kurs>)"
  return RegExp(
    r'^[^.\n!?]+ im Raum [^.\n!?]+(\s*\([^)]+\))?$',
  ).hasMatch(trimmed);
}

/// Strips HTML tags cleanly for inline notice banners.
String plainNoticeText(String noticeHtml) {
  final doc = html_parser.parseFragment(noticeHtml);
  return (doc.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Filters [entries] by an optional school-week badge (e.g. "A", "B").
/// Break supervisions, substitutions, and room bookings always remain visible.
List<TeacherTimetableEntry> filterTeacherDayByBadge(
  List<TeacherTimetableEntry> entries,
  String? selectedBadge,
) {
  if (selectedBadge == null || selectedBadge.trim().isEmpty) return entries;
  final target = selectedBadge.trim();
  return [
    for (final e in entries)
      if (e.isBreakSupervision ||
          e.isEmbeddedSubstitution ||
          e.isRoomBooking ||
          e.badge == null ||
          e.badge!.trim().isEmpty ||
          e.badge!.trim() == target)
        e,
  ];
}

/// Collects all distinct week badges present in [plan].
List<String> collectTeacherWeekBadges(TeacherTimetablePlan plan) {
  final set = <String>{
    if (plan.weekBadge != null && plan.weekBadge!.trim().isNotEmpty)
      plan.weekBadge!.trim(),
    for (final day in plan.days)
      for (final e in day)
        if (e.badge != null && e.badge!.trim().isNotEmpty) e.badge!.trim(),
  };
  return set.toList()..sort();
}
