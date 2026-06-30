import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';

enum GradeCategory { oral, written, other }

class _GradeEntry {
  final String name;
  final String rawValue;
  GradeCategory category;
  final bool isManual;

  _GradeEntry({
    required this.name,
    required this.rawValue,
    required this.category,
    this.isManual = false,
  });

  double? get numericValue {
    final trimmed = rawValue.trim();
    final asDouble = double.tryParse(trimmed);
    if (asDouble != null && asDouble > 6 && asDouble <= 15) return asDouble;
    return _parseGermanGrade(trimmed);
  }

  bool get isPoints {
    final v = double.tryParse(rawValue.trim());
    return v != null && v > 6;
  }
}

double? _parseGermanGrade(String raw) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) return null;
  final suffix = cleaned.endsWith('+')
      ? 1
      : cleaned.endsWith('-')
          ? -1
          : 0;
  final digit = double.tryParse(
    cleaned.replaceAll('+', '').replaceAll('-', ''),
  );
  if (digit == null || digit < 1 || digit > 6) return null;
  return digit - suffix * 0.33;
}

class GradeCalculatorCard extends StatefulWidget {
  final List<LessonMark> sphMarks;
  final String courseId;

  const GradeCalculatorCard({
    super.key,
    required this.sphMarks,
    required this.courseId,
  });

  @override
  State<GradeCalculatorCard> createState() => _GradeCalculatorCardState();
}

class _GradeCalculatorCardState extends State<GradeCalculatorCard> {
  static const _appletId = 'meinunterricht.php';
  late List<_GradeEntry> _entries;
  double _oralWeight = 0.5;
  bool _loaded = false;

  String get _storageKey => 'grade-calc-${widget.courseId}';

  @override
  void initState() {
    super.initState();
    _entries = widget.sphMarks
        .map((m) => _GradeEntry(
              name: m.name,
              rawValue: m.mark,
              category: GradeCategory.other,
            ))
        .toList();
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    final raw = await sph!.prefs.kv.getAppletValue(_appletId, _storageKey);
    if (raw == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final Map<String, dynamic> data = jsonDecode(raw as String);
    final List cats = data['cats'] ?? [];
    final List manuals = data['manuals'] ?? [];
    final double? w = (data['oralWeight'] as num?)?.toDouble();

    if (!mounted) return;
    setState(() {
      _oralWeight = w ?? 0.5;
      for (var i = 0; i < _entries.length && i < cats.length; i++) {
        _entries[i].category = GradeCategory.values[cats[i] as int];
      }
      for (final m in manuals) {
        _entries.add(_GradeEntry(
          name: m['name'] as String,
          rawValue: m['value'] as String,
          category: GradeCategory.values[m['cat'] as int],
          isManual: true,
        ));
      }
      _loaded = true;
    });
  }

  Future<void> _saveLocal() async {
    final cats = _entries
        .where((e) => !e.isManual)
        .map((e) => e.category.index)
        .toList();
    final manuals = _entries
        .where((e) => e.isManual)
        .map((e) => {'name': e.name, 'value': e.rawValue, 'cat': e.category.index})
        .toList();
    final payload = jsonEncode({
      'cats': cats,
      'manuals': manuals,
      'oralWeight': _oralWeight,
    });
    await sph!.prefs.kv.setAppletValue(_appletId, _storageKey, payload);
  }

  double? _average(List<_GradeEntry> entries) {
    final values = entries
        .map((e) => e.numericValue)
        .where((v) => v != null)
        .cast<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _formatAvg(double? avg, bool points) {
    if (avg == null) return '—';
    return points ? avg.toStringAsFixed(1) : avg.toStringAsFixed(2);
  }

  Future<void> _addManualNote() async {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    GradeCategory cat = GradeCategory.other;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(AppLocalizations.of(context).gradeCalculatorAddNote),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).gradeCalculatorNoteName,
                ),
              ),
              TextField(
                controller: valueCtrl,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).gradeCalculatorNoteValue,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<GradeCategory>(
                segments: [
                  ButtonSegment(
                    value: GradeCategory.oral,
                    label: Text(AppLocalizations.of(context).gradeCalculatorOral),
                  ),
                  ButtonSegment(
                    value: GradeCategory.written,
                    label: Text(AppLocalizations.of(context).gradeCalculatorWritten),
                  ),
                  ButtonSegment(
                    value: GradeCategory.other,
                    label: Text(AppLocalizations.of(context).gradeCalculatorOther),
                  ),
                ],
                selected: {cat},
                onSelectionChanged: (s) => setS(() => cat = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || valueCtrl.text.trim().isEmpty) return;
                setState(() {
                  _entries.add(_GradeEntry(
                    name: nameCtrl.text.trim(),
                    rawValue: valueCtrl.text.trim(),
                    category: cat,
                    isManual: true,
                  ));
                });
                _saveLocal();
                Navigator.pop(ctx);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    valueCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final oralEntries = _entries.where((e) => e.category == GradeCategory.oral).toList();
    final writtenEntries = _entries.where((e) => e.category == GradeCategory.written).toList();
    final otherEntries = _entries.where((e) => e.category == GradeCategory.other).toList();

    final hasPoints = _entries.any((e) => e.isPoints);

    final oralAvg = _average(oralEntries);
    final writtenAvg = _average(writtenEntries);
    final otherAvg = _average(otherEntries);

    double? weightedAvg;
    if (oralAvg != null && writtenAvg != null) {
      weightedAvg = oralAvg * _oralWeight + writtenAvg * (1 - _oralWeight);
    } else if (oralAvg != null) {
      weightedAvg = oralAvg;
    } else if (writtenAvg != null) {
      weightedAvg = writtenAvg;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ExpansionTile(
        title: Text(AppLocalizations.of(context).gradeCalculator),
        subtitle: weightedAvg != null
            ? Text(
                '${AppLocalizations.of(context).gradeCalculatorAverage}: '
                '${_formatAvg(weightedAvg, hasPoints)}',
              )
            : null,
        children: [
          ..._entries.map((entry) {
            return ListTile(
              dense: true,
              title: Text(entry.name),
              subtitle: Text(entry.rawValue),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<GradeCategory>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: GradeCategory.oral,
                        label: Text(
                          AppLocalizations.of(context).gradeCalculatorOral,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      ButtonSegment(
                        value: GradeCategory.written,
                        label: Text(
                          AppLocalizations.of(context).gradeCalculatorWritten,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      ButtonSegment(
                        value: GradeCategory.other,
                        label: Text(
                          AppLocalizations.of(context).gradeCalculatorOther,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                    selected: {entry.category},
                    onSelectionChanged: (s) {
                      setState(() => entry.category = s.first);
                      _saveLocal();
                    },
                  ),
                  if (entry.isManual)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() => _entries.remove(entry));
                        _saveLocal();
                      },
                    ),
                ],
              ),
            );
          }),

          if (oralEntries.isNotEmpty || writtenEntries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(AppLocalizations.of(context).gradeCalculatorOral),
                  Expanded(
                    child: Slider(
                      value: _oralWeight,
                      onChanged: (v) {
                        setState(() => _oralWeight = v);
                        _saveLocal();
                      },
                      divisions: 10,
                    ),
                  ),
                  Text(AppLocalizations.of(context).gradeCalculatorWritten),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${((_oralWeight) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${((1 - _oralWeight) * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (oralAvg != null)
                  Text(
                    '${AppLocalizations.of(context).gradeCalculatorOral}: '
                    '${_formatAvg(oralAvg, hasPoints)}',
                  ),
                if (writtenAvg != null)
                  Text(
                    '${AppLocalizations.of(context).gradeCalculatorWritten}: '
                    '${_formatAvg(writtenAvg, hasPoints)}',
                  ),
                if (otherAvg != null)
                  Text(
                    '${AppLocalizations.of(context).gradeCalculatorOther}: '
                    '${_formatAvg(otherAvg, hasPoints)}',
                  ),
                if (weightedAvg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${AppLocalizations.of(context).gradeCalculatorAverage}: '
                      '${_formatAvg(weightedAvg, hasPoints)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton.icon(
              onPressed: _addManualNote,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).gradeCalculatorAddNote),
            ),
          ),
        ],
      ),
    );
  }
}
