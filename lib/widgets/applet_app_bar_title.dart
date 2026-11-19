import 'package:material_ui/material_ui.dart';

/// Keep the usual title when no child subtitle is needed.
class AppletAppBarTitle extends StatelessWidget {
  final Widget title;
  final String? subtitle;
  const AppletAppBarTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => subtitle == null
      ? title
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
}
