import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';

/// Search suggestion tile for a calendar event.
class CalendarSearchResultTile extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const CalendarSearchResultTile({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(event.title),
      iconColor: colorFromArgb(event.colorArgb),
      subtitle: Text(
        '${event.startTime.format("E d MMM y", "de_DE")} - ${event.endTime.format("E d MMM y", "de_DE")}',
      ),
      leading: event.endTime.isBefore(DateTime.now())
          ? const Icon(Icons.done)
          : const Icon(Icons.event),
      onTap: onTap,
    );
  }
}
