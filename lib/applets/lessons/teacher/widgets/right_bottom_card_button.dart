import 'package:flutter/material.dart';

class RightBottomCardButton extends StatelessWidget {
  final void Function() onTap;
  final bool topLeftNotRounded;
  final bool bottomRightNotRounded;
  final bool? isExpanded;
  final String? text;
  final IconData icon;
  final Color color;
  final Color onColor;
  const RightBottomCardButton(
      {super.key,
      this.text,
      required this.onTap,
      required this.onColor,
      this.topLeftNotRounded = false,
      this.bottomRightNotRounded = false,
      required this.icon,
      required this.color,
      this.isExpanded});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.only(
        topLeft: topLeftNotRounded ? Radius.zero : Radius.circular(8),
        bottomRight: bottomRightNotRounded ? Radius.zero : Radius.circular(8),
      ),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: topLeftNotRounded ? Radius.zero : Radius.circular(8),
            bottomRight:
                bottomRightNotRounded ? Radius.zero : Radius.circular(8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            spacing: 2,
            children: [
              if (text != null)
                Text(
                  text!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: onColor,
                      ),
                ),
              Icon(
                icon,
                color: onColor,
                size: 20,
              ),
              if (isExpanded != null)
                Icon(
                  isExpanded! ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: onColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
