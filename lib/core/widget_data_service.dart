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

  bool _dayEndScheduled = false;

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
      TimetableSubject? next;
      String? phase;
      String? phaseStartTime;
      String? phaseEndTime;

      for (int i = 0; i < today.length; i++) {
        if (_isOngoing(today[i], now)) {
          current = today[i];
          next = (i + 1 < today.length) ? today[i + 1] : null;
          phase = 'lesson';
          phaseStartTime = _formatTime(today[i].startTime);
          phaseEndTime = _formatTime(today[i].endTime);
          break;
        }
        if (i + 1 < today.length && _isInBreak(today[i], today[i + 1], now)) {
          current = today[i];
          next = today[i + 1];
          phase = 'break';
          phaseStartTime = _formatTime(today[i].endTime);
          phaseEndTime = _formatTime(today[i + 1].startTime);
          break;
        }
      }

      // Day end: after last lesson, before midnight
      if (current == null && today.isNotEmpty) {
        final lastLesson = today.last;
        final lastEndMinutes =
            lastLesson.endTime.hour * 60 + lastLesson.endTime.minute;
        final nowMinutes = now.hour * 60 + now.minute;
        if (nowMinutes >= lastEndMinutes) {
          current = lastLesson;
          phase = 'dayEnd';
          phaseStartTime = _formatTime(lastLesson.endTime);
          phaseEndTime = phaseStartTime; // dayEnd has no countdown
        }
      }

      await _write('widget_timetable', {
        'updatedAt': DateTime.now().toIso8601String(),
        'today': today.map((l) => _lessonToJson(l)).toList(),
        'currentLesson': current != null ? _lessonToJson(current) : null,
      });

      final liveActivityEnabled =
          await sph.prefs.kv.get('live-activity-lesson') ?? true;
      if (liveActivityEnabled == true && current != null && phase != null) {
        if (phase == 'dayEnd') {
          if (!_dayEndScheduled) {
            _dayEndScheduled = true;
            await updateLessonActivity(current, null,
                phase: phase,
                phaseStartTime: phaseStartTime!,
                phaseEndTime: phaseEndTime!);
            Future.delayed(const Duration(seconds: 50), () async {
              await endLessonActivity();
              _dayEndScheduled = false;
            });
          }
        } else {
          _dayEndScheduled = false;
          await startLessonActivity(current, next,
              phase: phase,
              phaseStartTime: phaseStartTime!,
              phaseEndTime: phaseEndTime!);
        }
      } else if (phase == null) {
        _dayEndScheduled = false;
        await endLessonActivity();
      }
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
      TimetableSubject current,
      TimetableSubject? next, {
      required String phase,
      required String phaseStartTime,
      required String phaseEndTime,
    }) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod(
          'startLessonActivity',
          jsonEncode(_lessonActivityJson(current, next,
              phase: phase,
              phaseStartTime: phaseStartTime,
              phaseEndTime: phaseEndTime)));
    } catch (e) {
      logger.w('WidgetDataService: startLessonActivity failed: $e');
    }
  }

  Future<void> updateLessonActivity(
      TimetableSubject current,
      TimetableSubject? next, {
      required String phase,
      required String phaseStartTime,
      required String phaseEndTime,
    }) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod(
          'updateLessonActivity',
          jsonEncode(_lessonActivityJson(current, next,
              phase: phase,
              phaseStartTime: phaseStartTime,
              phaseEndTime: phaseEndTime)));
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

  bool _isInBreak(TimetableSubject prev, TimetableSubject next, TimeOfDay now) {
    final prevEnd = prev.endTime.hour * 60 + prev.endTime.minute;
    final nextStart = next.startTime.hour * 60 + next.startTime.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= prevEnd && nowMinutes < nextStart;
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
        'color': _colorForLesson(l),
      };

  /// Generates a deterministic color from the lesson name/id so each subject
  /// always gets the same distinct color in the widget.
  String _colorForLesson(TimetableSubject l) {
    final key = (l.id?.split('-').first ?? l.name ?? '').toLowerCase();
    final hash = key.codeUnits.fold(0, (h, c) => (h * 31 + c) & 0xFFFFFFFF);
    const colors = [
      '#E53935', // Rot
      '#8E24AA', // Violett
      '#1E88E5', // Blau
      '#00897B', // Teal
      '#43A047', // Grün
      '#FB8C00', // Orange
      '#F4511E', // Tiefes Orange
      '#6D4C41', // Braun
      '#00ACC1', // Cyan
      '#3949AB', // Indigo
    ];
    return colors[hash % colors.length];
  }

  Map<String, dynamic> _lessonActivityJson(
      TimetableSubject current, TimetableSubject? next, {
      required String phase,
      required String phaseStartTime,
      required String phaseEndTime,
    }) {
    return {
      'name': current.name ?? '',
      'room': current.raum,
      'teacher': current.lehrer,
      'phase': phase,
      'phaseStartTime': phaseStartTime,
      'phaseEndTime': phaseEndTime,
      'nextName': next?.name,
      'nextRoom': next?.raum,
      'nextTeacher': next?.lehrer,
      'nextStart': next != null ? _formatTime(next.startTime) : null,
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

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
