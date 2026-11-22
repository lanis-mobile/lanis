import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../generated/l10n.dart';
import '../../../utils/logger.dart';
import '../../../utils/mono_text_viewer.dart';
import 'debug_export_presets.dart';

class DebugExport extends ConsumerStatefulWidget {
  const DebugExport({super.key});

  @override
  ConsumerState<DebugExport> createState() => _DebugExportState();
}

class _DebugExportState extends ConsumerState<DebugExport> {
  DebugExportPresetId? _selected;
  bool _exporting = false;

  Future<void> _runExport() async {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.debugExportSelectAtLeastOne)),
      );
      return;
    }

    final session = ref.read(sessionProvider).asData?.value;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.debugExportNoSession)),
      );
      return;
    }

    setState(() => _exporting = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      final report = await runDebugExportApplet(
        ref: ref,
        presetId: selected,
        dio: session.dio,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MonoTextViewer(
            report: report,
            title: 'Debug Export Preview',
            fileNameStart: 'lanis_mobile_debug_export',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final supportedApplets = ref.watch(supportedAppletPhpUrlsProvider);
    final accountType =
        ref.watch(activeAccountProvider)?.accountType ??
        ref.watch(sessionProvider).asData?.value?.accountTypeOrNull;

    final selectedPreset = _selected == null
        ? null
        : debugExportPresets.where((p) => p.id == _selected).firstOrNull;
    final effectiveSelected =
        selectedPreset != null &&
            isDebugExportPresetAvailable(
              selectedPreset,
              supportedAppletPhpUrls: supportedApplets,
              accountType: accountType,
            )
        ? selectedPreset.id
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugExport)),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.warning, color: Colors.red),
            title: Text('UFFGEPASST!'),
            subtitle: Text(
              'Über diese Sektion kannst du Debug-Daten exportieren. Versende diese Daten nur an vertrauenswürdige Entwickler. Lösche die Daten, sobald du sie nicht mehr benötigst. Sie können sensible Informationen enthalten, die die Schule und dich betreffen.',
            ),
          ),
          ListTile(
            leading: Icon(Icons.contact_mail),
            title: Text('Mit wem hast du Kontakt?'),
            subtitle: Text(
              'Wenn du Debug-Daten exportierst, stelle sicher, dass du sie ausschließlich an lanis-mobile@alessioc42.dev sendest. Diese E-Mail-Adresse wird von dem Hauptentwickler betreut. Sende die Daten auf keinen Fall an andere E-Mail-Adressen oder über andere Wege!',
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.debugExportSelectPresets,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioGroup<DebugExportPresetId>(
            groupValue: effectiveSelected,
            onChanged: (value) {
              if (_exporting) return;
              setState(() => _selected = value);
            },
            child: Column(
              children: [
                for (final preset in debugExportPresets)
                  RadioListTile<DebugExportPresetId>(
                    value: preset.id,
                    enabled:
                        !_exporting &&
                        isDebugExportPresetAvailable(
                          preset,
                          supportedAppletPhpUrls: supportedApplets,
                          accountType: accountType,
                        ),
                    title: Text(preset.label(l10n)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _exporting || effectiveSelected == null
                  ? null
                  : _runExport,
              icon: const Icon(Icons.download),
              label: Text(l10n.debugExportRun),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l10n.debugExportCustomRequest),
            subtitle: Text(l10n.debugExportCustomRequestSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _exporting
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DebugExportCustomRequest(),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

const _maxRedirectDepth = 2;

Future<void> writeDebugExportHeader({
  required MemoryLogger report,
  required WidgetRef ref,
}) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final account = ref.read(activeAccountProvider);
  report.log('START: Debug Export');
  report.log('SCHOOL: ${account?.schoolID} (${account?.schoolName})');
  report.log(
    'PLATFORM: ${Platform.operatingSystem} ${Platform.version} ${Platform.operatingSystemVersion}',
  );
  report.log(
    'APP VERSION: ${packageInfo.appName} ${packageInfo.buildNumber} ${packageInfo.version}',
  );
  report.log('INSTALL STORE: ${packageInfo.installerStore}');
}

const _redactedDebugHeaders = {
  'set-cookie',
  'cookie',
  'authorization',
  'proxy-authorization',
};

const _crossHostSensitiveHeaders = {
  'cookie',
  'authorization',
  'proxy-authorization',
};

/// Returns a copy of [headers] with sensitive auth/cookie values redacted.
Map<String, String> redactDebugExportHeaders(Map<String, String> headers) {
  return {
    for (final entry in headers.entries)
      entry.key: _redactedDebugHeaders.contains(entry.key.toLowerCase())
          ? '<redacted>'
          : entry.value,
  };
}

/// Drops only sensitive auth/cookie headers when following a redirect across
/// hosts, preserving custom headers required by SPH endpoints.
Map<String, String> stripSensitiveCrossHostHeaders(
  Map<String, String> headers, {
  required String fromUrl,
  required String toUrl,
}) {
  if (headers.isEmpty) return headers;
  final fromHost = Uri.tryParse(fromUrl)?.host.toLowerCase();
  final toHost = Uri.tryParse(toUrl)?.host.toLowerCase();
  if (fromHost != null && fromHost == toHost) {
    return headers;
  }
  return {
    for (final entry in headers.entries)
      if (!_crossHostSensitiveHeaders.contains(entry.key.toLowerCase()))
        entry.key: entry.value,
  };
}

void _writeRequestDescription(
  MemoryLogger report,
  DebugExportHttpRequest request,
) {
  report.write('------------- BEGIN REQUEST DESCRIPTION -------------');
  report.log('URL: ${request.url}');
  report.log('Method: ${request.method}');
  report.log('Query Params:\n${request.queryParameters}');
  report.log('Headers:\n${redactDebugExportHeaders(request.headers)}');
  report.log('Content-Type: ${request.contentType}');
  report.log('Body:\n${request.data}');
  report.write('------------- END REQUEST DESCRIPTION -------------');
}

void _writeResponse(MemoryLogger report, Response<dynamic> response) {
  report.write('------------- BEGIN RESPONSE -------------');
  report.log(
    'Status Code: ${response.statusCode} (${response.statusMessage})',
  );
  report.write('-------- BEGIN HEADER --------');
  for (final key in response.headers.map.keys) {
    final value = _redactedDebugHeaders.contains(key.toLowerCase())
        ? '<redacted>'
        : response.headers.value(key);
    report.write('$key: $value');
  }
  report.write('-------- END HEADER --------');
  report.write('-------- BEGIN BODY --------');
  final data = response.data;
  if (data is String) {
    report.write(data);
  } else if (data is Map || data is List) {
    report.write(jsonEncode(data));
  } else {
    report.write(data?.toString() ?? '');
  }
  report.write('-------- END BODY --------');
  report.write('------------- END RESPONSE -------------');
}

String? _responseBodyAsString(Response<dynamic> response) {
  final data = response.data;
  if (data is String) return data;
  if (data is Map || data is List) return jsonEncode(data);
  return data?.toString();
}

String? _resolveRedirectLocation(String currentUrl, String location) {
  final trimmed = location.trim();
  if (trimmed.isEmpty) return null;
  final absolute = Uri.tryParse(trimmed);
  if (absolute != null && absolute.hasScheme) {
    return absolute.toString();
  }
  final base = Uri.parse(currentUrl);
  return base.resolve(trimmed).toString();
}

Future<Response<dynamic>> _executeRequest(
  Dio dio,
  DebugExportHttpRequest request,
) {
  return dio.request(
    request.url,
    options: Options(
      method: request.method,
      headers: request.headers,
      contentType: request.contentType,
      followRedirects: false,
      validateStatus: (_) => true,
    ),
    data: request.data,
    queryParameters: request.queryParameters,
  );
}

/// Runs [request], logging each hop. Follows HTTP 302 `Location` up to
/// [_maxRedirectDepth] times (follow-up requests are GET without body).
/// Returns the final response body as a string when available.
Future<String?> appendRequestSection({
  required MemoryLogger report,
  required String sectionName,
  required Dio dio,
  required DebugExportHttpRequest request,
  String? note,
}) async {
  report.write('============= BEGIN PRESET: $sectionName =============');
  if (note != null) {
    report.log(note);
  }

  String? finalBody;
  try {
    var current = request;
    var hop = 0;

    while (true) {
      if (hop > 0) {
        report.write('------------- REDIRECT HOP $hop -------------');
      }
      _writeRequestDescription(report, current);
      final response = await _executeRequest(dio, current);
      _writeResponse(report, response);
      finalBody = _responseBodyAsString(response);

      if (response.statusCode != 302 || hop >= _maxRedirectDepth) {
        if (response.statusCode == 302 && hop >= _maxRedirectDepth) {
          report.log(
            'Stopped following redirects (max depth $_maxRedirectDepth).',
          );
        }
        break;
      }

      final location = response.headers.value('location');
      if (location == null || location.trim().isEmpty) {
        report.log('HTTP 302 without Location header; not following.');
        break;
      }

      final nextUrl = _resolveRedirectLocation(current.url, location);
      if (nextUrl == null) {
        report.log('Could not resolve Location: $location');
        break;
      }

      hop += 1;
      report.log('Following 302 Location -> $nextUrl (hop $hop/$_maxRedirectDepth)');
      current = DebugExportHttpRequest(
        method: 'GET',
        url: nextUrl,
        headers: stripSensitiveCrossHostHeaders(
          current.headers,
          fromUrl: current.url,
          toUrl: nextUrl,
        ),
      );
    }
  } catch (e, stackTrace) {
    report.log('----- AN ERROR OCCURRED WHILE CREATING THIS SECTION -----');
    report.write(e.toString());
    report.write(stackTrace.toString());
  }
  report.write('============= END PRESET: $sectionName =============');
  report.write('');
  return finalBody;
}

/// Runs all level-1, level-2, and (for lessons) level-3 requests for [presetId].
Future<void> appendDebugExportAppletSections({
  required MemoryLogger report,
  required DebugExportPresetId presetId,
  required Dio dio,
}) async {
  switch (presetId) {
    case DebugExportPresetId.substitutions:
      final html = await appendRequestSection(
        report: report,
        sectionName: 'substitutions',
        dio: dio,
        request: substitutionsMainRequest(),
      );
      final dates = html != null ? parseSubstitutionPlanDates(html) : <String>[];
      if (dates.isEmpty) {
        final today = DateFormat('dd.MM.yyyy').format(DateTime.now());
        await appendRequestSection(
          report: report,
          sectionName: 'substitutions/ajax@$today',
          dio: dio,
          request: substitutionsAjaxRequest(today),
          note:
              'No substitution dates found in main HTML; '
              'using today ($today) for AJAX.',
        );
      } else {
        for (final date in dates) {
          await appendRequestSection(
            report: report,
            sectionName: 'substitutions/ajax@$date',
            dio: dio,
            request: substitutionsAjaxRequest(date),
            note: dates.first == date
                ? 'Substitution dates: ${dates.join(', ')}'
                : null,
          );
        }
      }
    case DebugExportPresetId.timetable:
      final html = await appendRequestSection(
        report: report,
        sectionName: 'timetable',
        dio: dio,
        request: timetableMainRequest(),
      );
      final childUrls = html != null ? parseParentTimetableUrls(html) : <Uri>[];
      for (final childUrl in childUrls) {
        await appendRequestSection(
          report: report,
          sectionName: formatParentTimetableSectionName(childUrl),
          dio: dio,
          request: DebugExportHttpRequest(
            method: 'GET',
            url: childUrl.toString(),
          ),
        );
      }
    case DebugExportPresetId.calendar:
      await appendRequestSection(
        report: report,
        sectionName: 'calendar',
        dio: dio,
        request: calendarMainRequest(),
      );
      final range = defaultCalendarExportRange();
      await appendRequestSection(
        report: report,
        sectionName: 'calendar/events',
        dio: dio,
        request: calendarEventsRequest(
          startDate: range.start,
          endDate: range.end,
        ),
      );
    case DebugExportPresetId.lessons:
      final mainHtml = await appendRequestSection(
        report: report,
        sectionName: 'lessons',
        dio: dio,
        request: lessonsMainRequest(),
      );
      final courseUrls = mainHtml != null
          ? parseLessonsCourseUrls(mainHtml)
          : <Uri>[];
      final seenUploadUrls = <String>{};
      for (final courseUrl in courseUrls) {
        final courseHtml = await appendRequestSection(
          report: report,
          sectionName: formatLessonCourseSectionName(courseUrl),
          dio: dio,
          request: DebugExportHttpRequest(
            method: 'GET',
            url: courseUrl.toString(),
          ),
        );
        if (courseHtml == null) continue;
        for (final uploadUrl in parseLessonsUploadUrls(courseHtml)) {
          if (!seenUploadUrls.add(uploadUrl.toString())) continue;
          await appendRequestSection(
            report: report,
            sectionName: formatLessonUploadSectionName(uploadUrl),
            dio: dio,
            request: DebugExportHttpRequest(
              method: 'GET',
              url: uploadUrl.toString(),
            ),
          );
        }
      }
    case DebugExportPresetId.dataStorage:
      await appendRequestSection(
        report: report,
        sectionName: 'dataStorage',
        dio: dio,
        request: dataStorageRootRequest(),
      );
    case DebugExportPresetId.studyGroups:
      await appendRequestSection(
        report: report,
        sectionName: 'studyGroups',
        dio: dio,
        request: studyGroupsMainRequest(),
      );
    case DebugExportPresetId.conversations:
      await appendRequestSection(
        report: report,
        sectionName: 'conversations',
        dio: dio,
        request: conversationsOverviewRequest(),
      );
  }
}

Future<String> runDebugExportApplet({
  required WidgetRef ref,
  required DebugExportPresetId presetId,
  required Dio dio,
}) async {
  final report = MemoryLogger();
  await writeDebugExportHeader(report: report, ref: ref);
  report.log('SELECTED APPLET: ${presetId.name}');
  report.write('');

  await appendDebugExportAppletSections(
    report: report,
    presetId: presetId,
    dio: dio,
  );

  report.log('END: Debug Export');
  return report.logs.toString();
}

class DebugExportCustomRequest extends ConsumerStatefulWidget {
  const DebugExportCustomRequest({super.key});

  @override
  ConsumerState<DebugExportCustomRequest> createState() =>
      _DebugExportCustomRequestState();
}

class _DebugExportCustomRequestState
    extends ConsumerState<DebugExportCustomRequest> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController urlController = TextEditingController();
  final TextEditingController methodController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final TextEditingController headersController = TextEditingController();
  final TextEditingController queryParamsController = TextEditingController();
  bool authenticated = true;

  @override
  void initState() {
    super.initState();
    methodController.text = 'GET';
  }

  @override
  void dispose() {
    urlController.dispose();
    methodController.dispose();
    bodyController.dispose();
    headersController.dispose();
    queryParamsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.debugExportCustomRequest)),
      body: ListView(
        children: [
          Form(
            key: formKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                spacing: 8.0,
                children: [
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'HTTP Method',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: 'GET',
                    items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH']
                        .map(
                          (method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      methodController.text = value ?? 'GET';
                    },
                  ),
                  TextFormField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a URL';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: headersController,
                    decoration: const InputDecoration(
                      labelText: 'Headers (JSON: { "key": "value" })',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: queryParamsController,
                    decoration: const InputDecoration(
                      labelText: 'Query Params (JSON: { "key": "value" })',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  TextFormField(
                    controller: bodyController,
                    decoration: const InputDecoration(
                      labelText: 'Body (for POST/PUT/PATCH)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  CheckboxListTile(
                    value: authenticated,
                    onChanged: (bool? value) {
                      setState(() {
                        authenticated = value ?? true;
                      });
                    },
                    title: const Text('Authenticated Request'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState?.validate() ?? false) {
                        final report = await createCustomDebugExport(
                          ref: ref,
                          url: urlController.text,
                          httpMethod: methodController.text,
                          body: bodyController.text,
                          headersJson: headersController.text,
                          queryJson: queryParamsController.text,
                          authenticated: authenticated,
                        );
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MonoTextViewer(
                                report: report,
                                title: 'Debug Export Preview',
                                fileNameStart: 'lanis_mobile_debug_export',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(l10n.debugExportRun),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String> createCustomDebugExport({
  required WidgetRef ref,
  required String url,
  required String httpMethod,
  required String body,
  required String headersJson,
  required String queryJson,
  required bool authenticated,
}) async {
  final report = MemoryLogger();
  await writeDebugExportHeader(report: report, ref: ref);

  final session = ref.read(sessionProvider).asData?.value;
  final Map<String, String> headers;
  final Map<String, dynamic>? query;
  Object? data;
  try {
    headers = headersJson.isNotEmpty
        ? Map<String, dynamic>.from(
            jsonDecode(headersJson) as Map,
          ).map((k, v) => MapEntry(k, v.toString()))
        : <String, String>{};
    query = queryJson.isNotEmpty
        ? Map<String, dynamic>.from(jsonDecode(queryJson) as Map)
        : null;
    if (body.isNotEmpty) {
      data = jsonDecode(body);
    }
  } catch (e) {
    report.log('----- INVALID CUSTOM REQUEST JSON -----');
    report.write(e.toString());
    report.log('END: Debug Export');
    return report.logs.toString();
  }

  final tempDio = authenticated && session != null ? null : Dio();
  try {
    await appendRequestSection(
      report: report,
      sectionName: 'customRequest',
      dio: tempDio ?? session!.dio,
      request: DebugExportHttpRequest(
        method: httpMethod,
        url: url,
        queryParameters: query,
        data: data,
        headers: headers,
        contentType: 'application/json',
      ),
    );
  } finally {
    tempDio?.close();
  }

  report.log('END: Debug Export');
  return report.logs.toString();
}
