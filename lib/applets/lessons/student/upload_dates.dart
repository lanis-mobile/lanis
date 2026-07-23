import 'package:intl/intl.dart';

/// Parses Lanis upload deadline strings shown in the student upload UI.
class UploadDates {
  final DateTime start;
  final DateTime deadline;
  final DateTime automaticDeletion;

  const UploadDates({
    required this.start,
    required this.deadline,
    required this.automaticDeletion,
  });

  static String _normalizeDateTime(String raw) => raw
      .replaceAll(",", "")
      .replaceAll(" den", "")
      .replaceAll(" Uhr", "");

  /// Returns null if any field is missing or unparsable.
  static UploadDates? tryParse({
    required String? startRaw,
    required String? deadlineRaw,
    required String? deletionRaw,
  }) {
    if (startRaw == null || deadlineRaw == null || deletionRaw == null) {
      return null;
    }
    try {
      return UploadDates(
        start: DateFormat("EEEE d.M.yy H:mm", "de").parse(
          _normalizeDateTime(startRaw),
        ),
        deadline: DateFormat("EEEE d.M.yy H:mm", "de").parse(
          _normalizeDateTime(deadlineRaw),
        ),
        automaticDeletion: DateFormat("d.M.yyyy", "de").parse(deletionRaw),
      );
    } catch (_) {
      return null;
    }
  }
}
