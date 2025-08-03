// Credits: https://retroportalstudio.medium.com/focused-pop-up-menu-in-flutter-15766d0ab414

import 'package:flutter/material.dart';

class FocusedMenuItem {
  final String title;
  final IconData icon;

  FocusedMenuItem({required this.icon, required this.title});
}

class FocusedMenu extends StatefulWidget {
  final Widget child;
  final EdgeInsets margin;
  final List<FocusedMenuItem> items;

  const FocusedMenu(
      {super.key,
      required this.child,
      required this.items,
      this.margin = EdgeInsets.zero});

  @override
  State<FocusedMenu> createState() => _FocusedMenuState();
}

class _FocusedMenuState extends State<FocusedMenu> {
  GlobalKey containerKey = GlobalKey();

  ({Offset offset, Size size})? getDimensions() {
    RenderBox? renderBox =
        containerKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return null;
    }

    Size size = renderBox.size;
    Offset offset = renderBox.localToGlobal(Offset.zero);

    return (size: size, offset: offset);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: containerKey,
      padding: widget.margin,
      child: Stack(
        // Dirty but needed to have a Ripple effect on every possible widget.
        children: [
          widget.child,
          Positioned.fill(
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12.0),
                  onTap: () async {
                    final dimensions = getDimensions();

                    if (dimensions == null) {
                      return;
                    }

                    showDialog(
                      context: context,
                      useSafeArea: false,
                      builder: (context) {
                        return FocusedMenuDetails(
                          childOffset: dimensions.offset,
                          childSize: dimensions.size,
                          items: widget.items,
                          margin: widget.margin,
                          child: Padding(
                            padding: widget.margin,
                            child: widget.child,
                          ),
                        );
                      },
                    );
                  },
                )),
          )
        ],
      ),
    );
  }
}

class FocusedMenuDetails extends StatelessWidget {
  final Offset childOffset;
  final Size childSize;
  final EdgeInsets margin;
  final List<FocusedMenuItem> items;
  final Widget child;

  const FocusedMenuDetails(
      {super.key,
      required this.childOffset,
      required this.childSize,
      this.margin = EdgeInsets.zero,
      required this.items,
      required this.child});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);

    final maxMenuWidth = childSize.width * 0.75;
    final menuHeight = size.height * 0.35;
    final leftOffset = (childOffset.dx + maxMenuWidth) < size.width
        ? childOffset.dx
        : (childOffset.dx - maxMenuWidth + childSize.width);
    final topOffset =
        (childOffset.dy + menuHeight + childSize.height) < size.height
            ? childOffset.dy + childSize.height
            : childOffset.dy - menuHeight;

    final onTop = (childOffset.dy + menuHeight + childSize.height) < size.height
        ? false
        : true;

    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Positioned(
              top: topOffset,
              left: leftOffset,
              child: SizedBox(
                width: maxMenuWidth,
                height: menuHeight,
                child: Padding(
                  padding: margin.copyWith(
                      top: onTop ? 0 : 2, bottom: onTop ? 2 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment:
                        onTop ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      for (var item in items)
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  item.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
                top: childOffset.dy,
                left: childOffset.dx,
                child: AbsorbPointer(
                    child: SizedBox(
                        width: childSize.width,
                        height: childSize.height,
                        child: child)))
          ],
        ));
  }
}
