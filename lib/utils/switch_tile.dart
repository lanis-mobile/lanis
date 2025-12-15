import 'package:flutter/material.dart';

class MinimalSwitchTile extends StatelessWidget {
  final Text title;
  final Text? subtitle;
  final Widget? leading;
  final bool value;
  final EdgeInsets? contentPadding;
  final Function(bool)? onChanged;
  final bool useInkWell;

  const MinimalSwitchTile(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      required this.value,
      this.contentPadding,
      this.onChanged,
      this.useInkWell = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged != null && useInkWell
          ? () {
              onChanged!(!value);
            }
          : null,
      child: Padding(
        padding: contentPadding ?? EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  Theme(
                      data: Theme.of(context).copyWith(
                        iconTheme: Theme.of(context).iconTheme.copyWith(
                              color: onChanged == null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                              size: 20.0,
                            ),
                      ),
                      child: leading!),
                  SizedBox(width: 16.0),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                            color: onChanged != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                        child: title),
                    if (subtitle != null)
                      DefaultTextStyle(
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                          child: subtitle!),
                  ],
                ),
              ],
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
