import 'package:flutter/material.dart';

class RangeSliderTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final RangeValues values;
  final Function(RangeValues)? onChanged;
  final Function(RangeValues)? onChangeEnd;
  final RangeLabels? labels;
  final double min;
  final double max;
  final int divisions;
  final Color? inactiveColor;

  const RangeSliderTile(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      required this.values,
      this.onChanged,
      this.onChangeEnd,
      this.labels,
      required this.min,
      required this.max,
      required this.divisions,
      this.inactiveColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) leading!,
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) subtitle!,
                ],
              ),
            ),
            RangeSlider(
              values: values,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
              labels: labels,
              min: min,
              max: max,
              divisions: divisions,
              inactiveColor: inactiveColor,
            ),
          ],
        )),
      ],
    );
  }
}
