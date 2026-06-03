import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sph/sph.dart';
import '../models/account_types.dart';
import '../models/timetable.dart';
import '../utils/logger.dart';

class WidgetDataService {
  WidgetDataService._();
  static final instance = WidgetDataService._();

  static const _channel = MethodChannel('io.github.alessioc42.sph/widgets');

  bool get _isIOS => Platform.isIOS;

  Future<void> _write(String key, Map<String, dynamic> data) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('writeData', {
        'key': key,
        'value': jsonEncode(data),
      });
    } catch (e) {
      logger.w('WidgetDataService: writeData failed for $key: $e');
    }
  }

  Future<void> _reloadWidgets() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('reloadWidgets');
    } catch (e) {
      logger.w('WidgetDataService: reloadWidgets failed: $e');
    }
  }

  Future<void> updateAll(SPH sph, AccountType accountType) async {
    if (!_isIOS) return;
    await Future.wait([
      updateTimetable(sph),
      updateSubstitutions(sph),
      updateCalendar(sph),
      updateConversations(sph),
    ]);
    await _reloadWidgets();
  }

  Future<void> updateTimetable(SPH sph) async {
    if (!_isIOS) return;
    try {
      final data = await sph.parser.timetableStudentParser.getHome();
      final now = TimeOfDay.now();
      final today = _getTodayLessons(data);

      TimetableSubject? current;
      for (final lesson in today) {
        if (_isOngoing(lesson, now)) {
          current = lesson;
          break;
        }
      }

      await _write('widget_timetable', {
        'updatedAt': DateTime.now().toIso8601String(),
        'today': today.map((l) => _lessonToJson(l)).toList(),
        'currentLesson': current != null ? _lessonToJson(current) : null,
      });
    } catch (e) {
      logger.w('WidgetDataService: updateTimetable failed: $e');
    }
  }

  Future<void> updateSubstitutions(SPH sph) async {
    if (!_isIOS) return;
    try {
      final plan = await sph.parser.substitutionsParser.getHome();
      final today = plan.days.isNotEmpty ? plan.days.first : null;
      final entries = today?.substitutions ?? [];

      await _write('widget_substitutions', {
        'updatedAt': DateTime.now().toIso8601String(),
        'date': today?.parsedDate ?? '',
        'entries': entries
            .map((s) => {
                  'stunde': s.stunde,
                  'fach': s.fach,
                  'art': s.art,
                  'raum': s.raum,
                  'vertreter': s.vertreter,
                })
            .toList(),
      });
    } catch (e) {
      logger.w('WidgetDataService: updateSubstitutions failed: $e');
    }
  }

  Future<void> updateCalendar(SPH sph) async {
    if (!_isIOS) return;
    try {
      final events = await sph.parser.calendarParser.getHome();
      final upcoming = events
          .where((e) => e.endTime.isAfter(DateTime.now()))
          .take(10)
          .toList();

      await _write('widget_calendar', {
        'updatedAt': DateTime.now().toIso8601String(),
        'events': upcoming
            .map((e) => {
                  'title': e.title,
                  'start': e.startTime.toIso8601String(),
                  'allDay': e.allDay,
                  'color': _colorToHex(e.color),
                })
            .toList(),
      });
    } catch (e) {
      logger.w('WidgetDataService: updateCalendar failed: $e');
    }
  }

  Future<void> updateConversations(SPH sph) async {
    if (!_isIOS) return;
    try {
      final entries = await sph.parser.conversationsParser.getHome();
      final unread = entries.where((e) => e.unread).length;

      await _write('widget_conversations', {
        'updatedAt': DateTime.now().toIso8601String(),
        'unreadCount': unread,
        'latest': entries
            .take(5)
            .map((e) => {
                  'sender': e.fullName,
                  'subject': e.title,
                  'isUnread': e.unread,
                })
            .toList(),
      });
    } catch (e) {
      logger.w('WidgetDataService: updateConversations failed: $e');
    }
  }

  Future<void> startLessonActivity(
      TimetableSubject current, TimetableSubject? next) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod(
          'startLessonActivity', jsonEncode(_lessonActivityJson(current, next)));
    } catch (e) {
      logger.w('WidgetDataService: startLessonActivity failed: $e');
    }
  }

  Future<void> updateLessonActivity(
      TimetableSubject current, TimetableSubject? next) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('updateLessonActivity',
          jsonEncode(_lessonActivityJson(current, next)));
    } catch (e) {
      logger.w('WidgetDataService: updateLessonActivity failed: $e');
    }
  }

  Future<void> endLessonActivity() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('endLessonActivity');
    } catch (e) {
      logger.w('WidgetDataService: endLessonActivity failed: $e');
    }
  }

  Future<void> startSubstitutionActivity(
      List<Map<String, String?>> entries) async {
    if (!_isIOS) return;
    try {
      final json = jsonEncode({
        'date': DateTime.now().toIso8601String(),
        'newEntries': entries,
      });
      await _channel.invokeMethod('startSubstitutionActivity', json);
    } catch (e) {
      logger.w('WidgetDataService: startSubstitutionActivity failed: $e');
    }
  }

  Future<void> endSubstitutionActivity() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod('endSubstitutionActivity');
    } catch (e) {
      logger.w('WidgetDataService: endSubstitutionActivity failed: $e');
    }
  }

  List<TimetableSubject> _getTodayLessons(TimeTable data) {
    final today = data.planForOwn ?? data.planForAll ?? [];
    final dayIndex = DateTime.now().weekday - 1; // 0=Mo
    if (dayIndex < 0 || dayIndex >= today.length) return [];
    return today[dayIndex];
  }

  bool _isOngoing(TimetableSubject lesson, TimeOfDay now) {
    final startMinutes =
        lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  Map<String, dynamic> _lessonToJson(TimetableSubject l) => {
        'name': l.name ?? '',
        'room': l.raum,
        'teacher': l.lehrer,
        'start':
            '${l.startTime.hour.toString().padLeft(2, '0')}:${l.startTime.minute.toString().padLeft(2, '0')}',
        'end':
            '${l.endTime.hour.toString().padLeft(2, '0')}:${l.endTime.minute.toString().padLeft(2, '0')}',
        'stunde': l.stunde ?? 0,
        'color': null,
      };

  Map<String, dynamic> _lessonActivityJson(
      TimetableSubject current, TimetableSubject? next) {
    return {
      'name': current.name ?? '',
      'room': current.raum,
      'teacher': current.lehrer,
      'start':
          '${current.startTime.hour.toString().padLeft(2, '0')}:${current.startTime.minute.toString().padLeft(2, '0')}',
      'end':
          '${current.endTime.hour.toString().padLeft(2, '0')}:${current.endTime.minute.toString().padLeft(2, '0')}',
      'nextName': next?.name,
      'nextStart': next != null
          ? '${next.startTime.hour.toString().padLeft(2, '0')}:${next.startTime.minute.toString().padLeft(2, '0')}'
          : null,
    };
  }

  /// Converts a [Color] to a 6-digit RGB hex string (e.g. `#FF4242FC`).
  /// Uses the new Flutter Color API (r/g/b as doubles 0.0–1.0) to avoid
  /// the deprecated Color.value property.
  String _colorToHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}
