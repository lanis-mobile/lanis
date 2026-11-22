import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';
import 'package:liblanis/liblanis.dart';

import '../../../generated/l10n.dart';

const sphBase = 'https://start.schulportal.hessen.de';
final _sphBaseUri = Uri.parse('$sphBase/');

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
  substitutions,
  timetable,
  calendar,
  lessons,
  dataStorage,
  studyGroups,
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

/// One logged subsection produced by a preset (e.g. one AJAX date or subpage).
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

class DebugExportPreset {
  final DebugExportPresetId id;
  final String appletPhpUrl;
  final List<AccountType> supportedAccountTypes;
  final String Function(AppLocalizations l10n) label;

  const DebugExportPreset({
    required this.id,
    required this.appletPhpUrl,
    required this.supportedAccountTypes,
    required this.label,
  });
}

/// Whether [preset] is available to the active account based on the school's
/// supported applets and the account's role.
bool isDebugExportPresetAvailable(
  DebugExportPreset preset, {
  required Set<String> supportedAppletPhpUrls,
  AccountType? accountType,
}) {
  if (!supportedAppletPhpUrls.contains(preset.appletPhpUrl)) {
    return false;
  }
  if (accountType != null &&
      !preset.supportedAccountTypes.contains(accountType)) {
    return false;
  }
  return true;
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

DebugExportHttpRequest timetableMainRequest() => _get('stundenplan.php');

DebugExportHttpRequest calendarMainRequest() => _get('kalender.php');

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
    data: Uri(
      queryParameters: {
        'f': 'getEvents',
        'start': start,
        'end': end,
        's': searchQuery,
      },
    ).query,
    headers: _xhrFormHeaders,
    contentType: Headers.formUrlEncodedContentType,
  );
}

DebugExportHttpRequest lessonsMainRequest() => _get('meinunterricht.php');

DebugExportHttpRequest dataStorageRootRequest() =>
    _get('dateispeicher.php?a=view&folder=0');

DebugExportHttpRequest studyGroupsMainRequest() => _get('lerngruppen.php');

DebugExportHttpRequest conversationsOverviewRequest() =>
    const DebugExportHttpRequest(
      method: 'POST',
      url: '$sphBase/nachrichten.php',
      data: {'a': 'headers', 'getType': 'All', 'last': '0'},
      headers: _conversationsXhrHeaders,
      contentType: Headers.formUrlEncodedContentType,
    );

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

Uri? _resolveSameOriginSphUri(String? rawHref) {
  final trimmed = rawHref?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final Uri resolved;
  try {
    resolved = _sphBaseUri.resolve(trimmed);
  } on FormatException {
    return null;
  }
  if (resolved.scheme != _sphBaseUri.scheme ||
      resolved.host != _sphBaseUri.host ||
      resolved.port != _sphBaseUri.port) {
    return null;
  }
  return resolved.removeFragment();
}

/// Extracts parent child-timetable detail URLs from `stundenplan.php` HTML.
List<Uri> parseParentTimetableUrls(String html) {
  final document = parse(html);
  final seen = <String>{};
  final urls = <Uri>[];
  for (final link in document.querySelectorAll(
    '#content #accordion a.list-group-item[href]',
  )) {
    final uri = _resolveSameOriginSphUri(link.attributes['href']);
    if (uri == null || uri.path != '/stundenplan.php') continue;
    final params = uri.queryParameters;
    if (params['a'] != 'detail_klasse') continue;
    if ((params['p'] ?? '').isEmpty) continue;
    if (seen.add(uri.toString())) {
      urls.add(uri);
    }
  }
  return urls;
}

/// Extracts student and parent course detail URLs (`a=sus_view`) from
/// `meinunterricht.php` HTML, preserving distinct pupils and semesters.
List<Uri> parseLessonsCourseUrls(String html) {
  final document = parse(html);
  final seen = <String>{};
  final urls = <Uri>[];
  for (final link in document.querySelectorAll('a[href]')) {
    final uri = _resolveSameOriginSphUri(link.attributes['href']);
    if (uri == null || uri.path != '/meinunterricht.php') continue;
    final params = uri.queryParameters;
    if (params['a'] != 'sus_view') continue;
    if ((params['id'] ?? '').isEmpty) continue;
    if (seen.add(uri.toString())) {
      urls.add(uri);
    }
  }
  return urls;
}

/// Extracts 3rd-level student/parent submission upload URLs (`a=sus_abgabe`)
/// from a course detail page.
List<Uri> parseLessonsUploadUrls(String html) {
  final document = parse(html);
  final seen = <String>{};
  final urls = <Uri>[];
  for (final link in document.querySelectorAll('a[href]')) {
    final uri = _resolveSameOriginSphUri(link.attributes['href']);
    if (uri == null || uri.path != '/meinunterricht.php') continue;
    if (uri.queryParameters['a'] != 'sus_abgabe') continue;
    if (seen.add(uri.toString())) {
      urls.add(uri);
    }
  }
  return urls;
}

String formatParentTimetableSectionName(Uri uri) {
  final pupil = uri.queryParameters['p'];
  return pupil != null && pupil.isNotEmpty
      ? 'timetable/pupil#$pupil'
      : 'timetable/detail';
}

String formatLessonCourseSectionName(Uri uri) {
  final params = uri.queryParameters;
  final parts = <String>['course#${params['id'] ?? 'unknown'}'];
  if ((params['p'] ?? '').isNotEmpty) parts.add('p=${params['p']}');
  if ((params['halb'] ?? '').isNotEmpty) parts.add('halb=${params['halb']}');
  return 'lessons/${parts.join('_')}';
}

String formatLessonUploadSectionName(Uri uri) {
  final params = uri.queryParameters;
  final parts = <String>['upload#${params['id'] ?? 'unknown'}'];
  if ((params['b'] ?? '').isNotEmpty) parts.add('b=${params['b']}');
  if ((params['e'] ?? '').isNotEmpty) parts.add('e=${params['e']}');
  if ((params['p'] ?? '').isNotEmpty) parts.add('p=${params['p']}');
  return 'lessons/${parts.join('_')}';
}

/// Ordered list of applets shown in the Debug Export picker.
final debugExportPresets = <DebugExportPreset>[
  DebugExportPreset(
    id: DebugExportPresetId.substitutions,
    appletPhpUrl: Applets.substitutions.appletPhpUrl,
    supportedAccountTypes: Applets.substitutions.supportedAccountTypes,
    label: (l) => l.substitutions,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.timetable,
    appletPhpUrl: Applets.timetable.appletPhpUrl,
    supportedAccountTypes: Applets.timetable.supportedAccountTypes,
    label: (l) => l.timeTable,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.calendar,
    appletPhpUrl: Applets.calendar.appletPhpUrl,
    supportedAccountTypes: Applets.calendar.supportedAccountTypes,
    label: (l) => l.calendar,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.lessons,
    appletPhpUrl: Applets.lessons.appletPhpUrl,
    supportedAccountTypes: const [AccountType.student, AccountType.parent],
    label: (l) => l.lessons,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.dataStorage,
    appletPhpUrl: Applets.dataStorage.appletPhpUrl,
    supportedAccountTypes: Applets.dataStorage.supportedAccountTypes,
    label: (l) => l.storage,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.studyGroups,
    appletPhpUrl: Applets.studyGroups.appletPhpUrl,
    supportedAccountTypes: Applets.studyGroups.supportedAccountTypes,
    label: (l) => l.studyGroups,
  ),
  DebugExportPreset(
    id: DebugExportPresetId.conversations,
    appletPhpUrl: Applets.conversations.appletPhpUrl,
    supportedAccountTypes: Applets.conversations.supportedAccountTypes,
    label: (l) => l.messages,
  ),
];
