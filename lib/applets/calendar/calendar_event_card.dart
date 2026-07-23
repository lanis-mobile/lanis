import 'package:flutter/material.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/liblanis_ui.dart';

/// Card row for a calendar event in the selected-day list.
class CalendarEventCard extends StatelessWidget {
  final CalendarEvent event;
  final HtmlUnescape unescape;
  final VoidCallback onTap;

  const CalendarEventCard({
    super.key,
    required this.event,
    required this.unescape,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: colorFromArgb(event.colorArgb),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unescape.convert(event.title),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        unescape.convert(
                          event.category?.name ??
                              event.place ??
                              event.description,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              Icon(Icons.arrow_right),
              SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
