import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';

import '../../../core/sph/sph.dart';
import '../../../models/lessons.dart';
import '../../../widgets/format_text.dart';

class HomeworkBox extends StatefulWidget {
  final CurrentEntry currentEntry;
  final String courseID;
  const HomeworkBox(
      {super.key, required this.currentEntry, required this.courseID});

  @override
  State<HomeworkBox> createState() => _HomeworkBoxState();
}

class _HomeworkBoxState extends State<HomeworkBox> with WidgetsBindingObserver {
  final GlobalKey _columnKey = GlobalKey();
  Size _columnSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateColumnSize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _updateColumnSize();
  }

  void _updateColumnSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Checks if the context is still available to prevent _TypeError
      if (_columnKey.currentContext != null) {
        final RenderBox renderBox =
            _columnKey.currentContext!.findRenderObject() as RenderBox;
        setState(() {
          _columnSize = renderBox.size;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: _columnSize.height == 0 ? 0 : _columnSize.height + 12,
              width: _columnSize.width,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12)),
              ),
            ),
          ],
        ),
        Column(
          children: [
            Row(
              key: _columnKey,
              children: [
                const SizedBox(
                  width: 8,
                ),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.task,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).homework,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary),
                    ),
                  ],
                ),
                const Spacer(),
                Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: widget.currentEntry.homework!.homeWorkDone,
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.onPrimary, width: 2),
                  onChanged: (bool? value) {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(AppLocalizations.of(context).homeworkSaving),
                          duration: const Duration(milliseconds: 500)));
                      sph!.parser.lessonsStudentParser
                          .setHomework(widget.courseID,
                              widget.currentEntry.entryID, value!)
                          .then((val) {
                        if (val != "1") {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(AppLocalizations.of(context)
                                  .homeworkSavingError),
                            ));
                          }
                        } else {
                          setState(() {
                            widget.currentEntry.homework!.homeWorkDone = value;
                          });
                        }
                      });
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            AppLocalizations.of(context).homeworkSavingError),
                      ));
                    }
                  },
                ),
                const SizedBox(
                  width: 4,
                ),
              ],
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  // Default card color as ground color with primary color on top. (primary with opacity 0.1)
                  color: Color.alphaBlend(
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      Theme.of(context).cardColor),
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.only(
                  left: 12.0, right: 12.0, top: 8.0, bottom: 8.0),
              child: FormattedText(
                text: widget.currentEntry.homework!.description,
                formatStyle: DefaultFormatStyle(context: context),
              ),
            )
          ],
        ),
      ],
    );
  }
}
