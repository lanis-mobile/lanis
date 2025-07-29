import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lanis/applets/conversations/view/send.dart';

typedef SendMessageCallback = Future<void> Function(String message);
typedef EditorSizeChangeCallback = void Function(double height);

class RichChatTextEditor extends StatefulWidget {
  final String tooltip;
  final bool sending;
  final SendMessageCallback sendMessage;
  final VoidCallback scrollToBottom;
  final EditorSizeChangeCallback editorSizeChangeCallback;

  const RichChatTextEditor({
    super.key,
    required this.tooltip,
    required this.sending,
    required this.sendMessage,
    required this.scrollToBottom,
    required this.editorSizeChangeCallback,
  });

  @override
  State<RichChatTextEditor> createState() => _RichChatTextEditorState();
}

class _RichChatTextEditorState extends State<RichChatTextEditor> {
  final QuillController quillController = QuillController.basic();
  bool showToolbar = false;
  int editorlineCount = 1;
  final GlobalKey _widgetKey = GlobalKey();

  void onEditorChange() {
    final text = quillController.document.toPlainText();
    setState(() {
      editorlineCount = '\n'.allMatches(text).length + 1;
    });

    _notifyHeightChange();
  }

  void _notifyHeightChange() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox =
          _widgetKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        widget.editorSizeChangeCallback(height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    quillController.changes.listen((_) {
      onEditorChange();
    });
  }

  @override
  void dispose() {
    quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: _widgetKey,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 2.0, left: 4.0, right: 4.0),
                child: IconButton(
                  iconSize: kToolbarHeight / 1.5,
                  onPressed: () {
                    setState(() {
                      showToolbar = !showToolbar;
                    });
                    _notifyHeightChange();
                  },
                  icon: Icon(
                    Icons.format_textdirection_l_to_r_outlined,
                  ),
                  color: Theme.of(context).colorScheme.onSecondary,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                      minHeight: kToolbarHeight, maxHeight: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Theme.of(context).colorScheme.shadow.withAlpha(100),
                        blurRadius: 4.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        constraints: const BoxConstraints(
                          maxHeight: 150,
                        ),
                        child: QuillEditor.basic(
                          configurations: QuillEditorConfigurations(
                            controller: quillController,
                            placeholder: widget.tooltip,
                            customStyles: DefaultStyles(
                              placeHolder: DefaultTextBlockStyle(
                                  TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withAlpha(80),
                                  ),
                                  VerticalSpacing(0, 0),
                                  VerticalSpacing(0, 0),
                                  null),
                              paragraph: DefaultTextBlockStyle(
                                  TextStyle(
                                    fontSize: 18,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  VerticalSpacing(0, 0),
                                  VerticalSpacing(0, 0),
                                  null),
                            ),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(bottom: 2.0, left: 4.0, right: 6.0),
                child: IconButton(
                  iconSize: kToolbarHeight / 1.5,
                  onPressed: () async {
                    final String text = ConversationsSend.parseText(
                        quillController.document.toDelta());
                    if (text.isEmpty) return;

                    quillController.clear();
                    await widget.sendMessage(text);
                    widget.scrollToBottom();
                  },
                  icon: Icon(
                    Icons.send,
                  ),
                  color: quillController.document.isEmpty()
                      ? Theme.of(context).colorScheme.onTertiary.withAlpha(80)
                      : Theme.of(context).colorScheme.onTertiary,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          onEnd: () => _notifyHeightChange(),
          child: showToolbar
              ? QuillToolbar(
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainer),
                      child: SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              QuillToolbarHistoryButton(
                                isUndo: true,
                                controller: quillController,
                              ),
                              QuillToolbarHistoryButton(
                                isUndo: false,
                                controller: quillController,
                              ),
                              QuillToolbarClearFormatButton(
                                controller: quillController,
                              ),
                              QuillToolbarToggleStyleButton(
                                options:
                                    const QuillToolbarToggleStyleButtonOptions(),
                                controller: quillController,
                                attribute: Attribute.bold,
                              ),
                              QuillToolbarToggleStyleButton(
                                options:
                                    const QuillToolbarToggleStyleButtonOptions(),
                                controller: quillController,
                                attribute: Attribute.italic,
                              ),
                              QuillToolbarToggleStyleButton(
                                controller: quillController,
                                attribute: Attribute.underline,
                              ),
                              QuillToolbarToggleStyleButton(
                                  controller: quillController,
                                  attribute: Attribute.strikeThrough),
                              QuillToolbarToggleStyleButton(
                                controller: quillController,
                                attribute: Attribute.inlineCode,
                              ),
                              QuillToolbarToggleStyleButton(
                                controller: quillController,
                                attribute: Attribute.ul,
                              ),
                              QuillToolbarToggleStyleButton(
                                  controller: quillController,
                                  attribute: Attribute.superscript),
                              QuillToolbarToggleStyleButton(
                                  controller: quillController,
                                  attribute: Attribute.subscript),
                            ],
                          ),
                        ),
                      )),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
