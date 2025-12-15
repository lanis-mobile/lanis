import 'package:flutter/material.dart';

class SliderTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final double value;
  final Function(double)? onChanged;
  final Function(double)? onChangedEnd;
  final String? label;
  final double min;
  final double max;
  final int divisions;
  final Color? inactiveColor;

  const SliderTile(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      required this.value,
      this.onChanged,
      this.onChangedEnd,
      this.label,
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
            Slider(
              value: value,
              onChanged: onChanged,
              onChangeEnd: onChangedEnd,
              label: label,
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
