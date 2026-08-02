import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../generated/l10n.dart';

const sphBase = 'https://start.schulportal.hessen.de';

const _xhrFormHeaders = <String, String>{
  'Accept': '*/*',
  'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
  'Sec-Fetch-Dest': 'empty',
  'Sec-Fetch-Mode': 'cors',
  'Sec-Fetch-Site': 'same-origin',
};

const _conversationsXhrHeaders = <String, String>{
  ..._xhrFormHeaders,
  'X-Requested-With': 'XMLHttpRequest',
};

enum DebugExportPresetId {
  substitutionsMain,
  timetable,
  calendarMain,
  lessonsStudent,
  lessonsTeacher,
  dataStorage,
  studyGroups,
  substitutionsAjax,
  calendarEvents,
  conversations,
}

/// Built request ready for [Dio.request].
class DebugExportHttpRequest {
  final String method;
  final String url;
  final Map<String, dynamic>? queryParameters;
  final Object? data;
  final Map<String, String> headers;
  final String? contentType;

  const DebugExportHttpRequest({
    required this.method,
    required this.url,
    this.queryParameters,
    this.data,
    this.headers = const {},
    this.contentType,
  });

  DebugExportHttpRequest copyWith({
    String? method,
    String? url,
    Map<String, dynamic>? queryParameters,
    Object? data,
    Map<String, String>? headers,
    String? contentType,
  }) {
    return DebugExportHttpRequest(
      method: method ?? this.method,
      url: url ?? this.url,
      queryParameters: queryParameters ?? this.queryParameters,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      contentType: contentType ?? this.contentType,
    );
  }
}

/// One logged subsection produced by a preset (e.g. one AJAX date).
class DebugExportSection {
  final String name;
  final DebugExportHttpRequest request;
  final String? note;

  const DebugExportSection({
    required this.name,
    required this.request,
    this.note,
  });
}

/// Shared state while expanding selected presets into HTTP sections.
class DebugExportPresetContext {
  String? substitutionsHtml;
}

typedef DebugExportSectionBuilder =
    List<DebugExportSection> Function(DebugExportPresetContext ctx);

class DebugExportPreset {
  final DebugExportPresetId id;
  final String Function(AppLocalizations l10n) label;

  /// Needs the substitutions main HTML (for `data-tag` date discovery).
  final bool needsSubstitutionHtml;

  final DebugExportSectionBuilder buildSections;

  const DebugExportPreset({
    required this.id,
    required this.label,
    required this.buildSections,
    this.needsSubstitutionHtml = false,
  });
}

DebugExportHttpRequest _get(String path) =>
    DebugExportHttpRequest(method: 'GET', url: '$sphBase/$path');

DebugExportHttpRequest substitutionsMainRequest() =>
    _get('vertretungsplan.php');

/// [tag] must be `dd.MM.yyyy` as used by the substitutions parser.
DebugExportHttpRequest substitutionsAjaxRequest(String tag) =>
    DebugExportHttpRequest(
      method: 'POST',
      url: '$sphBase/vertretungsplan.php',
      queryParameters: const {'a': 'my'},
      data: {'tag': tag, 'ganzerPlan': 'true'},
      headers: _xhrFormHeaders,
      contentType: Headers.formUrlEncodedContentType,
    );

DebugExportHttpRequest calendarEventsRequest({
  required DateTime startDate,
  required DateTime endDate,
  String searchQuery = '',
}) {
  final formatter = DateFormat('yyyy-MM-dd');
  final start = formatter.format(startDate);
  final end = formatter.format(endDate);
  return DebugExportHttpRequest(
    method: 'POST',
    url: '$sphBase/kalender.php',
    queryParameters: {
      'f': 'getEvents',
      's': searchQuery,
      'start': start,
      'end': end,
    },
    data: 'f=getEvents&start=$start&end=$end&s=$searchQuery',
    headers: _xhrFormHeaders,
    contentType: Headers.formUrlEncodedContentType,
  );
}

/// Default calendar XHR range: first day of this month through last day of next.
({DateTime start, DateTime end}) defaultCalendarExportRange([DateTime? now]) {
  final n = now ?? DateTime.now();
  final start = DateTime(n.year, n.month, 1);
  final end = DateTime(n.year, n.month + 2, 0);
  return (start: start, end: end);
}

/// Same date discovery idea as [SubstitutionsParser.getSubstitutionDates].
List<String> parseSubstitutionPlanDates(String document) {
  final datePattern = RegExp(r'data-tag="(\d{2})\.(\d{2})\.(\d{4})"');
  final matches = datePattern.allMatches(document);
  final uniqueDates = <String>[];
  for (final match in matches) {
    final day = int.parse(match.group(1) ?? '00');
    final month = int.parse(match.group(2) ?? '00');
    final year = int.parse(match.group(3) ?? '00');
    final dateString = DateFormat(
      'dd.MM.yyyy',
    ).format(DateTime(year, month, day));
    if (!uniqueDates.contains(dateString)) {
      uniqueDates.add(dateString);
    }
  }
  return uniqueDates;
}

List<DebugExportSection> _single(
  DebugExportPresetId id,
  DebugExportHttpRequest request,
) => [DebugExportSection(name: id.name, request: request)];

List<DebugExportSection> _buildSubstitutionsAjax(DebugExportPresetContext ctx) {
  final html = ctx.substitutionsHtml;
  final dates = html != null ? parseSubstitutionPlanDates(html) : <String>[];
  if (dates.isEmpty) {
    final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return [
      DebugExportSection(
        name: '${DebugExportPresetId.substitutionsAjax.name}@$today',
        request: substitutionsAjaxRequest(today),
        note:
            'No substitution dates found in main HTML; '
            'using today ($today) for AJAX.',
      ),
    ];
  }
  return [
    for (final date in dates)
      DebugExportSection(
        name: '${DebugExportPresetId.substitutionsAjax.name}@$date',
        request: substitutionsAjaxRequest(date),
        note: dates.first == date
            ? 'Substitution dates: ${dates.join(', ')}'
            : null,
      ),
  ];
}

List<DebugExportSection> _buildCalendarEvents(DebugExportPresetContext ctx) {
  final range = defaultCalendarExportRange();
  return _single(
    DebugExportPresetId.calendarEvents,
    calendarEventsRequest(startDate: range.start, endDate: range.end),
  );
}

/// Ordered list used by the picker and the export runner.
final debugExportPresets = <DebugExportPreset>[
  DebugExportPreset(
    id: DebugExportPresetId.substitutionsMain,
    label: (l) => l.debugExportPresetSubstitutionsMain,
    needsSubstitutionHtml: true,
    buildSections: (_) =>
        _single(DebugExportPresetId.substitutionsMain, substitutionsMainRequest()),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.timetable,
    label: (l) => l.debugExportPresetTimetable,
    buildSections: (_) =>
        _single(DebugExportPresetId.timetable, _get('stundenplan.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.calendarMain,
    label: (l) => l.debugExportPresetCalendarMain,
    buildSections: (_) =>
        _single(DebugExportPresetId.calendarMain, _get('kalender.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.lessonsStudent,
    label: (l) => l.debugExportPresetLessonsStudent,
    buildSections: (_) =>
        _single(DebugExportPresetId.lessonsStudent, _get('meinunterricht.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.lessonsTeacher,
    label: (l) => l.debugExportPresetLessonsTeacher,
    buildSections: (_) => _single(
      DebugExportPresetId.lessonsTeacher,
      _get('meinunterricht.php?jump=no'),
    ),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.dataStorage,
    label: (l) => l.debugExportPresetDataStorage,
    buildSections: (_) => _single(
      DebugExportPresetId.dataStorage,
      _get('dateispeicher.php?a=view&folder=0'),
    ),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.studyGroups,
    label: (l) => l.debugExportPresetStudyGroups,
    buildSections: (_) =>
        _single(DebugExportPresetId.studyGroups, _get('lerngruppen.php')),
  ),
  DebugExportPreset(
    id: DebugExportPresetId.substitutionsAjax,
    label: (l) => l.debugExportPresetSubstitutionsAjax,
    needsSubstitutionHtml: true,
    buildSections: _buildSubstitutionsAjax,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.calendarEvents,
    label: (l) => l.debugExportPresetCalendarEvents,
    buildSections: _buildCalendarEvents,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.conversations,
    label: (l) => l.debugExportPresetConversations,
    buildSections: (_) => _single(
      DebugExportPresetId.conversations,
      const DebugExportHttpRequest(
        method: 'POST',
        url: '$sphBase/nachrichten.php',
        data: {'a': 'headers', 'getType': 'All', 'last': '0'},
        headers: _conversationsXhrHeaders,
        contentType: Headers.formUrlEncodedContentType,
      ),
    ),
  ),
];
