import 'package:flutter/material.dart';

class Callout extends StatelessWidget {
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? buttonTextColor;
  final EdgeInsets? margin;
  final Widget leading;
  final Text title;
  final Text buttonText;
  final void Function()? onPressed;

  const Callout(
      {super.key,
      required this.leading,
      required this.title,
      required this.buttonText,
      required this.onPressed,
      this.backgroundColor,
      this.buttonTextColor,
      this.foregroundColor,
      this.margin});

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      color: backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
      margin: margin ?? EdgeInsets.zero,
      child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            spacing: 12.0,
            children: [
              Row(
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      iconTheme: Theme.of(context).iconTheme.copyWith(
                            color: foregroundColor ??
                                Theme.of(context).colorScheme.primary,
                            size: 40.0,
                          ),
                    ),
                    child: leading,
                  ),
                  SizedBox(
                    width: 8.0,
                  ),
                  Expanded(
                    child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: foregroundColor ??
                                  Theme.of(context).colorScheme.primary,
                            ),
                        child: title),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                        onPressed: onPressed,
                        style: ButtonStyle(
                          backgroundColor: onPressed != null
                              ? WidgetStateColor.resolveWith((states) {
                                  if (states.contains(WidgetState.pressed)) {
                                    return foregroundColor?.withValues(
                                            alpha: 0.95) ??
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.95);
                                  }
                                  return foregroundColor ??
                                      Theme.of(context).colorScheme.primary;
                                })
                              : null,
                        ),
                        child: DefaultTextStyle(
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge!
                                .copyWith(
                                  color: onPressed == null
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                      : buttonTextColor ??
                                          Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                ),
                            child: buttonText)),
                  ),
                ],
              )
            ],
          )),
    );
  }
}
