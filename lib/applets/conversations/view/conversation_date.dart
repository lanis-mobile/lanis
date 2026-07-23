import 'package:intl/intl.dart';

/// Parses Lanis conversation date strings ("heute …", "gestern …", or absolute).
DateTime parseConversationDate(String date) {
  if (date.contains("heute")) {
    DateTime now = DateTime.now();
    DateTime conversation = DateFormat("H:m").parse(date.substring(6));

    return now.copyWith(
      hour: conversation.hour,
      minute: conversation.minute,
      second: 0,
    );
  } else if (date.contains("gestern")) {
    DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    DateTime conversation = DateFormat("H:m").parse(date.substring(8));

    return yesterday.copyWith(
      hour: conversation.hour,
      minute: conversation.minute,
      second: 0,
    );
  } else {
    return DateFormat("d.M.y H:m").parse(date);
  }
}
