import 'package:flutter/material.dart';

import '../../models/substitution.dart';
import '../../widgets/marquee.dart';

class SubstitutionListTile extends StatelessWidget {
  final Substitution substitutionData;
  const SubstitutionListTile({super.key, required this.substitutionData});

  bool doesNoticeExist(String? info) {
    List empty = [null, "", " ", "-", "---"];
    return empty.contains(info);
  }

  Widget? getSubstitutionInfo(
      BuildContext context, String key, String? value, IconData icon) {
    if (doesNoticeExist(value)) {
      return null;
    }

    return Padding(
        padding: const EdgeInsets.only(right: 30, left: 30, bottom: 2),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon),
              ),
              Text(
                key,
                style: Theme.of(context).textTheme.labelLarge,
              )
            ],
          ),
          SubstitutionsFormattedText(
              value!, Theme.of(context).textTheme.bodyMedium!)
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxClassWidth = constraints.maxWidth *
            0.3; // Limit class width to 30% of the tile width

        return ListTile(
          dense: (doesNoticeExist(substitutionData.vertreter) &&
              doesNoticeExist(substitutionData.lehrer) &&
              doesNoticeExist(substitutionData.raum) &&
              doesNoticeExist(substitutionData.fach) &&
              doesNoticeExist(substitutionData.hinweis)),
          title: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: (substitutionData.art != null)
                ? MarqueeWidget(
                    direction: Axis.horizontal,
                    child: Text(
                      substitutionData.art!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                : null,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                    top: 0,
                    bottom: (doesNoticeExist(substitutionData.vertreter) &&
                            doesNoticeExist(substitutionData.lehrer) &&
                            doesNoticeExist(substitutionData.raum) &&
                            !doesNoticeExist(substitutionData.fach))
                        ? 12
                        : 0),
                child: Column(
                  children: [
                    getSubstitutionInfo(context, "Vertreter",
                            substitutionData.vertreter, Icons.person) ??
                        const SizedBox.shrink(),
                    getSubstitutionInfo(context, "Lehrer",
                            substitutionData.lehrer, Icons.school) ??
                        const SizedBox.shrink(),
                    getSubstitutionInfo(context, "Raum", substitutionData.raum,
                            Icons.room) ??
                        const SizedBox.shrink(),
                  ],
                ),
              ),
              if (!doesNoticeExist(substitutionData.hinweis)) ...[
                Padding(
                  padding: EdgeInsets.only(
                      right: 30,
                      left: 30,
                      top: 2,
                      bottom: doesNoticeExist(substitutionData.fach) ? 12 : 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.info),
                          ),
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              substitutionData.hinweis!,
                              overflow: TextOverflow.visible,
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4)
                    ],
                  ),
                )
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!doesNoticeExist(substitutionData.klasse)) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxClassWidth),
                      child: MarqueeWidget(
                        direction: Axis.horizontal,
                        child: Text(
                          substitutionData.klasse!,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  if (!doesNoticeExist(substitutionData.fach)) ...[
                    Text(
                      substitutionData.fach!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                  if (!doesNoticeExist(substitutionData.stunde)) ...[
                    Text(
                      substitutionData.stunde,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ]
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Takes a string with eventual html tags and applies the necessary formatting according to the tags.
/// Tags may only occur at the beginning or end of the string.
///
/// Tags include: <b>, <i>, <del>
class SubstitutionsFormattedText extends StatelessWidget {
  final String data;
  final TextStyle style;

  const SubstitutionsFormattedText(this.data, this.style, {super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(text: _format(data, style));
  }

  TextSpan _format(String data, TextStyle style) {
    if (data.startsWith("<b>") && data.endsWith("</b>")) {
      return TextSpan(
          text: data.substring(3, data.length - 4),
          style: style.copyWith(fontWeight: FontWeight.bold));
    } else if (data.startsWith("<i>") && data.endsWith("</i>")) {
      return TextSpan(
          text: data.substring(3, data.length - 4),
          style: style.copyWith(fontStyle: FontStyle.italic));
    } else if (data.startsWith("<del>") && data.endsWith("</del>")) {
      return TextSpan(
          text: data.substring(5, data.length - 6),
          style: style.copyWith(decoration: TextDecoration.lineThrough));
    } else {
      return TextSpan(text: data, style: style);
    }
  }
}
