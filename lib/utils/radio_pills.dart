import 'package:flutter/material.dart';

const _borderRadius = Radius.circular(12.0);

enum _RadioPillVariant { vertical, horizontal }

enum RadioBorder {
  left(BorderRadius.horizontal(left: _borderRadius)),
  right(BorderRadius.horizontal(right: _borderRadius)),
  both(BorderRadius.all(_borderRadius)),
  topLeft(BorderRadius.only(topLeft: _borderRadius)),
  topRight(BorderRadius.only(topRight: _borderRadius)),
  top(BorderRadius.vertical(top: _borderRadius)),
  bottom(BorderRadius.vertical(bottom: _borderRadius)),
  none(BorderRadius.zero),
  all(BorderRadius.all(_borderRadius));

  final BorderRadius borderRadius;

  const RadioBorder(
    this.borderRadius,
  );
}

class RadioPill<T> extends StatelessWidget {
  final Text title;
  final Text? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final Widget? leading;
  final RadioBorder border;
  final Color? color;

  const RadioPill.vertical({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.leading,
    this.border = RadioBorder.both,
    this.color,
  })  : _variant = _RadioPillVariant.vertical,
        _trailing = null;

  const RadioPill.horizontal({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.groupValue,
    this.onChanged,
    this.leading,
    Widget? trailing,
    this.border = RadioBorder.both,
    this.color,
  })  : _variant = _RadioPillVariant.horizontal,
        _trailing = trailing;

  final Widget? _trailing;

  final _RadioPillVariant _variant;

  @override
  Widget build(BuildContext context) {
    final selected = groupValue == value;

    return Material(
      color: onChanged == null
          ? selected
              ? Theme.of(context).colorScheme.surfaceDim
              : Theme.of(context).colorScheme.surfaceContainerHighest
          : selected
              ? Theme.of(context).colorScheme.primaryContainer
              : color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: border.borderRadius,
      child: InkWell(
        onTap: onChanged != null
            ? () {
                onChanged!(value);
              }
            : null,
        borderRadius: border.borderRadius,
        child: Padding(
            padding: _variant == _RadioPillVariant.vertical
                ? const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0)
                : const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: _variant == _RadioPillVariant.vertical
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        Theme(
                            data: Theme.of(context).copyWith(
                              iconTheme: Theme.of(context).iconTheme.copyWith(
                                    color: onChanged == null
                                        ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                        : selected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                    size: 20.0,
                                  ),
                            ),
                            child: leading!),
                        SizedBox(height: 4.0),
                      ],
                      Column(
                        children: [
                          DefaultTextStyle(
                            style:
                                Theme.of(context).textTheme.bodySmall!.copyWith(
                                      color: onChanged == null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                    ),
                            child: title,
                          ),
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
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          if (leading != null) ...[
                            Theme(
                                data: Theme.of(context).copyWith(
                                  iconTheme:
                                      Theme.of(context).iconTheme.copyWith(
                                            color: onChanged == null
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                : selected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                            size: 20.0,
                                          ),
                                ),
                                child: leading!),
                            SizedBox(width: 8.0),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle(
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                      color: onChanged == null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                          : selected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                    ),
                                child: title,
                              ),
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
                      if (_trailing != null) _trailing!,
                    ],
                  )),
      ),
    );
  }
}

class RadioPillGroupItem<T> {
  final Text title;
  final Text? subtitle;
  final T value;
  final Widget? leading;

  const RadioPillGroupItem.vertical({
    required this.title,
    this.subtitle,
    required this.value,
    this.leading,
  })  : _trailing = null,
        _variant = _RadioPillVariant.vertical;

  const RadioPillGroupItem.horizontal({
    required this.title,
    this.subtitle,
    required this.value,
    this.leading,
    Widget? trailing,
  })  : _trailing = trailing,
        _variant = _RadioPillVariant.horizontal;

  final Widget? _trailing;
  final _RadioPillVariant _variant;
}

enum _RadioPillGroupVariant { row, large }

class RadioPillGroup<T> extends StatelessWidget {
  final List<RadioPillGroupItem<T>> pills;
  final T? groupValue;
  final Color? color;
  final ValueChanged<T>? onChanged;

  const RadioPillGroup(
      {super.key,
      required this.pills,
      this.groupValue,
      this.onChanged,
      this.color})
      : _customPillBuilder = null,
        _variant = _RadioPillGroupVariant.row;

  const RadioPillGroup.large(
      {super.key,
      required this.pills,
      this.groupValue,
      this.onChanged,
      required Widget Function(T? groupValue, ValueChanged<T>? onChanged)
          customPillBuilder,
      this.color})
      : _customPillBuilder = customPillBuilder,
        _variant = _RadioPillGroupVariant.large;

  final Widget Function(T? groupValue, ValueChanged<T>? onChanged)?
      _customPillBuilder;

  final _RadioPillGroupVariant _variant;

  RadioPill<T> instantiatePill(
      final RadioPillGroupItem<T> pill, final int index) {
    late RadioBorder border;

    if (_variant == _RadioPillGroupVariant.large) {
      border = RadioBorder.top;

      if (pills.length > 1) {
        if (index == 0) {
          border = RadioBorder.topLeft;
        } else if (index == pills.length - 1) {
          border = RadioBorder.topRight;
        } else {
          border = RadioBorder.none;
        }
      }
    } else {
      border = RadioBorder.both;

      if (pills.length > 1) {
        if (index == 0) {
          border = RadioBorder.left;
        } else if (index == pills.length - 1) {
          border = RadioBorder.right;
        } else {
          border = RadioBorder.none;
        }
      }
    }

    if (pill._variant == _RadioPillVariant.horizontal) {
      return RadioPill.horizontal(
        title: pill.title,
        subtitle: pill.subtitle,
        value: pill.value,
        groupValue: groupValue,
        onChanged: onChanged,
        leading: pill.leading,
        trailing: pill._trailing,
        border: border,
        color: color,
      );
    }

    return RadioPill.vertical(
      title: pill.title,
      subtitle: pill.subtitle,
      value: pill.value,
      groupValue: groupValue,
      onChanged: onChanged,
      leading: pill.leading,
      border: border,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          spacing: 2.0,
          children: [
            for (var i = 0; i < pills.length; i++) ...[
              Expanded(
                child: instantiatePill(pills[i], i),
              ),
            ]
          ],
        ),
        if (_customPillBuilder != null)
          _customPillBuilder!(groupValue, onChanged),
      ],
    );
  }
}

// We could use a CustomPainter but this is simpler.
class TrailingCircle extends StatelessWidget {
  final Color selectedBackgroundColor;
  final Color selectedColor;
  final bool selected;

  const TrailingCircle(
      {super.key,
      required Color color,
      required this.selectedBackgroundColor,
      required this.selectedColor,
      required this.selected})
      : _color = color,
        _customCircle = null;

  const TrailingCircle.custom(
      {super.key,
      required this.selectedBackgroundColor,
      required this.selectedColor,
      required this.selected,
      required Widget customCircle})
      : _customCircle = customCircle,
        _color = null;

  final Color? _color;
  final Widget? _customCircle;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: Size.square(32),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (selected) ...[
            SizedBox.fromSize(
              size: Size.square(32),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(100))),
            ),
            SizedBox.fromSize(
              size: Size.square(29),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: selectedBackgroundColor,
                      borderRadius: BorderRadius.circular(100))),
            ),
          ],
          SizedBox.fromSize(
            size: Size.square(selected ? 25 : 32),
            child: _customCircle ??
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: _color ?? Colors.transparent,
                        borderRadius: BorderRadius.circular(100))),
          ),
        ],
      ),
    );
  }
}

class ColorPair<T> {
  final Color color;
  final T value;

  const ColorPair({required this.color, required this.value});
}

class RadioTrailingCircleGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final List<ColorPair<T>> colors;
  final RadioBorder border;
  final Color? color;

  const RadioTrailingCircleGroup(
      {super.key,
      this.groupValue,
      this.onChanged,
      required this.colors,
      this.border = RadioBorder.all,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                    color ?? Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: border.borderRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Wrap(
                    spacing: 16.0,
                    runSpacing: 8.0,
                    alignment: WrapAlignment.center,
                    children: List.generate(colors.length, (index) {
                      return InkWell(
                        onTap: onChanged != null
                            ? () {
                                onChanged!(colors[index].value);
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: TrailingCircle(
                            color: colors[index].color,
                            selectedBackgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            selectedColor:
                                Theme.of(context).colorScheme.primary,
                            selected: groupValue == colors[index].value,
                          ),
                        ),
                      );
                    })),
              )),
        ),
      ],
    );
  }
}
