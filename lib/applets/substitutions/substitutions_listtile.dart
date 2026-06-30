import 'package:flutter/material.dart';

import '../../models/substitution.dart';
import '../../widgets/marquee.dart';

class SubstitutionListTile extends StatelessWidget {
  final Substitution substitutionData;
  const SubstitutionListTile({super.key, required this.substitutionData});

  bool isBlankNotice(String? info) {
    List empty = [null, "", " ", "-", "---"];
    return empty.contains(info);
  }

  Widget? getSubstitutionInfo({
    required BuildContext context,
    required String displayKey,
    required String? value,
    required String? valueAlt,
    required IconData icon,
  }) {
    if (isBlankNotice(value) && isBlankNotice(valueAlt)) {
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 30, left: 30, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icon),
              ),
              Text(displayKey, style: Theme.of(context).textTheme.labelLarge),
              if (isBlankNotice(value)) Icon(
                Icons.help_outline_outlined,
                size: Theme.of(context).textTheme.titleLarge?.fontSize,
              ),
            ],
          ),
          SubstitutionsFormattedText(
            !isBlankNotice(value)
                ? value!
                : valueAlt!,
            Theme.of(context).textTheme.bodyMedium!,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxClassWidth =
            constraints.maxWidth *
            0.3; // Limit class width to 30% of the tile width

        return ListTile(
          dense:
              (isBlankNotice(substitutionData.vertreter) &&
              isBlankNotice(substitutionData.lehrer) &&
              isBlankNotice(substitutionData.raum) &&
              isBlankNotice(substitutionData.fach) &&
              isBlankNotice(substitutionData.hinweis)),
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
                  bottom:
                      (isBlankNotice(substitutionData.vertreter) &&
                          isBlankNotice(substitutionData.lehrer) &&
                          isBlankNotice(substitutionData.raum) &&
                          !isBlankNotice(substitutionData.fach))
                      ? 12
                      : 0,
                ),
                child: Column(
                  children: [
                    getSubstitutionInfo(
                          context: context,
                          displayKey: "Vertreter",
                          value: substitutionData.vertreter,
                          valueAlt: null,
                          icon: Icons.person,
                        ) ??
                        const SizedBox.shrink(),
                    getSubstitutionInfo(
                          context: context,
                          displayKey: "Lehrer",
                          value: substitutionData.lehrer,
                          valueAlt: null,
                          icon: Icons.school,
                        ) ??
                        const SizedBox.shrink(),
                    getSubstitutionInfo(
                          context: context,
                          displayKey: "Raum",
                          value: substitutionData.raum,
                          valueAlt: substitutionData.raum_alt,
                          icon: Icons.room,
                        ) ??
                        const SizedBox.shrink(),
                  ],
                ),
              ),
              if (!isBlankNotice(substitutionData.hinweis)) ...[
                Padding(
                  padding: EdgeInsets.only(
                    right: 30,
                    left: 30,
                    top: 2,
                    bottom: isBlankNotice(substitutionData.fach) ? 12 : 0,
                  ),
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
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isBlankNotice(substitutionData.klasse) || !isBlankNotice(substitutionData.klasse_alt)) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxClassWidth),
                      child: MarqueeWidget(
                        direction: Axis.horizontal,
                        child: Row(
                          spacing: 2,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isBlankNotice(substitutionData.klasse)) ...[
                              Icon(
                                Icons.help_outline_outlined,
                                size: Theme.of(context).textTheme.titleMedium?.fontSize,
                              ),
                            ],
                            Text(
                              substitutionData.klasse!,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (!isBlankNotice(substitutionData.fach) || !isBlankNotice(substitutionData.fach_alt)) ...[
                    Row(
                      spacing: 2,
                      mainAxisSize: .min,
                      children: [
                        if (isBlankNotice(substitutionData.fach)) ...[
                          Icon(
                            Icons.help_outline_outlined,
                            size: Theme.of(context).textTheme.titleLarge?.fontSize,
                          ),
                        ],
                        Text(
                          // prioritize new subject over old subject
                          !isBlankNotice(substitutionData.fach)
                              ? substitutionData.fach!
                              : substitutionData.fach_alt!,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ],
                  if (!isBlankNotice(substitutionData.stunde)) ...[
                    Text(
                      substitutionData.stunde,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
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
        style: style.copyWith(fontWeight: FontWeight.bold),
      );
    } else if (data.startsWith("<i>") && data.endsWith("</i>")) {
      return TextSpan(
        text: data.substring(3, data.length - 4),
        style: style.copyWith(fontStyle: FontStyle.italic),
      );
    } else if (data.startsWith("<del>") && data.endsWith("</del>")) {
      return TextSpan(
        text: data.substring(5, data.length - 6),
        style: style.copyWith(decoration: TextDecoration.lineThrough),
      );
    } else {
      return TextSpan(text: data, style: style);
    }
  }
}
