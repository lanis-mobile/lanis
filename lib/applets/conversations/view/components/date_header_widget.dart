import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/conversations/view/shared.dart';

class DateHeaderWidget extends StatelessWidget {
  final DateHeader header;

  const DateHeaderWidget({super.key, required this.header});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          margin: const EdgeInsets.only(top: 16.0, bottom: 4.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Text(
              DateFormat(
                "d. MMMM y",
                Localizations.localeOf(context).languageCode,
              ).format(header.date),
            ),
          ),
        ),
      ],
    );
  }
}
