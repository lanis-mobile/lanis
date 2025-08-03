import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:dart_date/dart_date.dart';
import 'package:flutter_svg/svg.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/conversations/view/components/date_header_widget.dart';
import 'package:lanis/applets/conversations/view/components/message_widget.dart';
import 'package:lanis/applets/conversations/view/components/rich_chat_text_editor.dart';
import 'package:lanis/applets/conversations/view/components/statistic_widget.dart';
import 'package:lanis/generated/l10n.dart';
import 'dart:async';

import '../../../core/sph/sph.dart';
import '../../../models/client_status_exceptions.dart';
import '../../../models/conversations.dart';
import '../../../utils/fetch_more_indicator.dart';
import '../../../utils/logger.dart';
import '../../../widgets/error_view.dart';
import 'shared.dart';

class ConversationsChat extends StatefulWidget {
  final String id;
  final String title;
  final NewConversationSettings? newSettings;
  final bool hidden;
  final bool isTablet;
  final Function refreshSidebar;

  const ConversationsChat(
      {super.key,
      required this.title,
      required this.id,
      this.newSettings,
      required this.isTablet,
      required this.refreshSidebar,
      this.hidden = false});

  ConversationsChat.fromEntry(OverviewEntry entry, this.isTablet,
      {super.key, required this.refreshSidebar})
      : id = entry.id,
        title = entry.title,
        newSettings = null,
        hidden = entry.hidden;
  @override
  State<ConversationsChat> createState() => _ConversationsChatState();
}

class _ConversationsChatState extends State<ConversationsChat>
    with SingleTickerProviderStateMixin {
  late final Future<void> _conversationFuture = initConversation();
  Timer? _refreshTimer;
  int _lastRefresh = 0;
  final List<String> _messagesSendInThisSession = [];

  final TextEditingController messageField = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final ValueNotifier<bool> isSendVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isScrollToBottomVisible =
      ValueNotifier<bool>(false);
  final TextEditingController textEditingController = TextEditingController();

  final IndicatorController refreshIndicatorController = IndicatorController();

  final Map<String, TextStyle> textStyles = {};

  late ConversationSettings settings;
  late ParticipationStatistics? statistics;

  double richTextEditorSize = 74.0;

  late bool hidden;
  bool refreshing = false;

  final List<dynamic> chat = [];

  void initRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (mounted) {
        setState(() {
          refreshing = true;
        });
        await refreshConversation(scrollToEnd: false);
        setState(() {
          refreshing = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(toggleScrollToBottomFab);
    hidden = widget.hidden;

    initRefreshTimer();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
    _refreshTimer?.cancel();
  }

  void toggleScrollToBottomFab() {
    final currentScrollPosition = scrollController.position.pixels;
    isScrollToBottomVisible.value = currentScrollPosition > 100;
  }

  Future<void> refreshConversation({bool scrollToEnd = true}) async {
    if (widget.newSettings == null) {
      try {
        final result = await sph!.parser.conversationsParser
            .refreshConversation(widget.id, _lastRefresh);

        _lastRefresh = result.lastRefresh;
        for (final UnparsedMessage message in result.messages) {
          if (_messagesSendInThisSession.contains(message.id)) {
            continue;
          }
          setState(() {
            _renderSingleMessage(message);
          });
        }
        if (result.messages.isNotEmpty) {
          widget.refreshSidebar();
        }

        // Update send button visibility
        if (settings.own) {
          isSendVisible.value = true;
        } else {
          isSendVisible.value = !settings.noReply;
        }

        // Scroll to bottom after refresh
        if (scrollToEnd) scrollToBottom();
      } on NoConnectionException {
        showNoInternetDialog();
      } catch (e) {
        logger.w(
          "Error while refreshing conversation. This can happen, when the user tuns off their phone or suspends the app.",
        );
      }
    }
  }

  void scrollToBottom({Duration initDelay = Duration.zero}) {
    Future.delayed(initDelay, () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    });
  }

  void showErrorDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              icon: const Icon(Icons.error),
              title: Text(AppLocalizations.of(context).errorOccurred),
              actions: [
                FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(AppLocalizations.of(context).back))
              ],
            ));
  }

  void showNoInternetDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              icon: const Icon(Icons.wifi_off),
              title: Text(AppLocalizations.of(context).noInternetConnection2),
              actions: [
                FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(AppLocalizations.of(context).back))
              ],
            ));
  }

  static DateTime parseDateString(String date) {
    if (date.contains("heute")) {
      DateTime now = DateTime.now();
      DateTime conversation = DateFormat("H:m").parse(date.substring(6));

      return now.copyWith(
          hour: conversation.hour, minute: conversation.minute, second: 0);
    } else if (date.contains("gestern")) {
      DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
      DateTime conversation = DateFormat("H:m").parse(date.substring(8));

      return yesterday.copyWith(
          hour: conversation.hour, minute: conversation.minute, second: 0);
    } else {
      return DateFormat("d.M.y H:m").parse(date);
    }
  }

  void addAuthorTextStyles(final List<String> authors) {
    final ThemeData theme = Theme.of(context);
    for (final String author in authors) {
      textStyles[author] = BubbleStyle.getAuthorTextStyle(theme, author);
    }
  }

  Future<void> sendMessage(String text) async {
    MessageState state = MessageState.first;
    if (chat.last is Message) {
      DateTime date = chat.last.date;
      if (date.isToday) {
        state = MessageState.series;
      }
    }

    final textMessage = Message(
      text: text,
      own: true,
      date: DateTime.now(),
      author: null,
      state: state,
      status: MessageStatus.sending,
    );

    setState(() {
      DateTime lastMessageDate = chat.last.date;
      if (lastMessageDate.isToday) {
        chat.add(textMessage);
      } else {
        chat.addAll([DateHeader(date: DateTime.now()), textMessage]);
      }
    });

    final result = await sph!.parser.conversationsParser.replyToConversation(
        settings.id,
        "all",
        settings.groupChat ? "ja" : "nein",
        settings.onlyPrivateAnswers ? "ja" : "nein",
        text);

    widget.refreshSidebar();
    setState(() {
      if (result.success) {
        _messagesSendInThisSession.add(result.messageId);
        chat.last.status = MessageStatus.sent;
      } else {
        chat.last.status = MessageStatus.error;
        showSnackbar(context, AppLocalizations.of(context).errorSendingMessage);
      }
    });
  }

  Message addMessage(UnparsedMessage message, MessageState position) {
    final contentParsed = parse(message.content);
    final content = contentParsed.body!.text;

    return Message(
      text: content,
      own: message.own,
      author: message.author,
      date: parseDateString(message.date),
      state: position,
      status: MessageStatus.sent,
    );
  }

  List<String> authors = [];

  void _renderSingleMessage(UnparsedMessage message) {
    final DateTime messageDate = parseDateString(message.date);
    final String messageAuthor = message.author;
    MessageState position = MessageState.first;

    // Check if this message should be part of a series by examining the last message in chat
    if (chat.isNotEmpty && chat.last is Message) {
      Message lastMessage = chat.last;
      if (messageAuthor == lastMessage.author &&
          messageDate.isSameDay(lastMessage.date)) {
        position = MessageState.series;
      }
    }

    // Add message to appropriate authors list for styling
    if (message.own != true) {
      authors.add(messageAuthor);
    }

    // Add message to chat with appropriate date header if needed
    if (chat.isEmpty ||
        (chat.last is Message && !messageDate.isSameDay(chat.last.date))) {
      chat.addAll(
          [DateHeader(date: messageDate), addMessage(message, position)]);
    } else {
      chat.add(addMessage(message, position));
    }
  }

  void renderMessages(Conversation unparsedMessages) {
    chat.clear(); // Clear existing messages for refresh capability
    authors.clear(); // Clear existing authors

    // Process parent message
    final DateTime parentDate = parseDateString(unparsedMessages.parent.date);
    final String parentAuthor = unparsedMessages.parent.author;

    if (unparsedMessages.parent.own != true) {
      authors.add(parentAuthor);
    }

    // Add parent message with initial date header
    chat.addAll([
      DateHeader(date: parentDate),
      addMessage(unparsedMessages.parent, MessageState.first)
    ]);

    // Process all replies
    for (UnparsedMessage reply in unparsedMessages.replies) {
      _renderSingleMessage(reply);
    }

    addAuthorTextStyles(authors.toList());
  }

  Future<void> initConversation() async {
    if (widget.newSettings == null) {
      Conversation result = await sph!.parser.conversationsParser
          .getSingleConversation(widget.id);
      _lastRefresh = result.msgLastRefresh;
      logger.d("last refresh: $_lastRefresh");

      settings = ConversationSettings(
        id: widget.id,
        groupChat: result.groupChat,
        onlyPrivateAnswers: result.onlyPrivateAnswers,
        noReply: result.noReply,
        author: result.parent.author,
        own: result.parent.own,
      );

      statistics = ParticipationStatistics(
          countParents: result.countParents,
          countStudents: result.countStudents,
          countTeachers: result.countTeachers,
          knownParticipants: result.knownParticipants);

      renderMessages(result);
    } else {
      settings = widget.newSettings!.settings;

      statistics = null;

      chat.addAll([
        DateHeader(date: widget.newSettings!.firstMessage.date),
        widget.newSettings!.firstMessage
      ]);
    }

    if (settings.own) {
      isSendVisible.value = true;
    } else {
      isSendVisible.value = !settings.noReply;
    }
  }

  String get tooltipMessage {
    if (settings.onlyPrivateAnswers && !settings.own) {
      return AppLocalizations.of(context).replyToPerson(settings.author!);
    } else if (settings.groupChat == false &&
        settings.onlyPrivateAnswers == false &&
        settings.noReply == false) {
      return AppLocalizations.of(context).openChatWarning;
    } else {
      return AppLocalizations.of(context).sendMessagePlaceholder;
    }
  }

  Widget appBar() {
    return AppBar(
      title: Text(widget.title),
      scrolledUnderElevation: 0.0,
      backgroundColor: Colors.transparent,
      actions: [
        if (refreshing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        if (settings.groupChat == false &&
            settings.onlyPrivateAnswers == false &&
            settings.noReply == false)
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    icon: const Icon(Icons.groups),
                    title: Text(AppLocalizations.of(context)
                        .conversationTypeName(ChatType.openChat.name)),
                    content: Text(AppLocalizations.of(context).openChatWarning),
                    actions: [
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text("Ok"),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.warning),
          ),
        if (statistics != null)
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StatisticWidget(
                      statistics: statistics!, conversationTitle: widget.title),
                ),
              );
            },
            icon: const Icon(Icons.people),
          ),
      ],
    );
  }

  Widget triangularPattern({required Color lineColor}) {
    return SvgPicture.asset(
      "assets/triangle_pattern.svg",
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(lineColor, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ValueListenableBuilder(
        valueListenable: isScrollToBottomVisible,
        builder: (context, isVisible, _) {
          return Visibility(
            visible: isVisible,
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 60,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () =>
                    scrollToBottom(initDelay: const Duration(milliseconds: 50)),
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondaryFixedDim,
                        width: 1.5,
                      ),
                      color: Theme.of(context).colorScheme.surfaceDim),
                  child: const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ),
          );
        },
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: _conversationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.waiting) {
              // Error content
              if (snapshot.hasError) {
                if (snapshot.error is LanisException) {
                  return ErrorView(
                    error: snapshot.error as LanisException,
                    showAppBar: true,
                    retry: () {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                          builder: (_) => ConversationsChat(
                                refreshSidebar: widget.refreshSidebar,
                                title: widget.title,
                                id: widget.id,
                                newSettings: widget.newSettings,
                                isTablet: widget.isTablet,
                              )));
                    },
                  );
                }
              }

              return Column(
                children: [
                  appBar(),
                  Container(
                    width: double.infinity,
                    height: 1,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 1,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surfaceBright
                              : Theme.of(context).colorScheme.surfaceDim,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        triangularPattern(
                          lineColor: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.07),
                        ),
                        NotificationListener<ScrollMetricsNotification>(
                          onNotification: (_) {
                            toggleScrollToBottomFab();
                            return false;
                          },
                          child: FetchMoreIndicator(
                            controller: refreshIndicatorController,
                            onAction: refreshConversation,
                            child: CustomScrollView(
                              controller: scrollController,
                              reverse: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                SliverToBoxAdapter(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                    height: richTextEditorSize + 10,
                                  ),
                                ),
                                SliverList.builder(
                                  itemCount: chat.length,
                                  itemBuilder: (context, index) {
                                    // Reverse the index to show messages in correct order
                                    final reversedIndex =
                                        chat.length - 1 - index;
                                    if (chat[reversedIndex] is Message) {
                                      return MessageWidget(
                                          message: chat[reversedIndex],
                                          textStyle: textStyles[
                                              chat[reversedIndex].author]);
                                    } else {
                                      return DateHeaderWidget(
                                          header: chat[reversedIndex]);
                                    }
                                  },
                                ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Flexible(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12.0),
                                                child: Text(
                                                  widget.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineMedium,
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (settings.onlyPrivateAnswers &&
                                            !settings.own) ...[
                                          Container(
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8.0,
                                                horizontal: 12.0),
                                            margin: const EdgeInsets.only(
                                                top: 16.0),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHigh),
                                            child: Text(
                                              AppLocalizations.of(context)
                                                  .privateConversation(
                                                      settings.author!),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Visibility(
                          visible: settings.own || !settings.noReply,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: RichChatTextEditor(
                              scrollToBottom: scrollToBottom,
                              sendMessage: sendMessage,
                              tooltip: tooltipMessage,
                              sending: isSendVisible.value,
                              editorSizeChangeCallback: (height) {
                                bool wasScrolledToBottom =
                                    scrollController.position.pixels <= 40;
                                setState(() {
                                  richTextEditorSize = height;
                                });
                                if (wasScrolledToBottom &&
                                    scrollController.position.pixels != 0) {
                                  scrollController.animateTo(
                                    0,
                                    duration: Duration(milliseconds: 100),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            // Waiting content
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }
}
