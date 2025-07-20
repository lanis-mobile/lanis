import 'dart:io';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:dart_date/dart_date.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:lanis/applets/conversations/view/components/rich_chat_text_editor.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/bottom_nav_bar_change_notifier.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/widgets/dynamic_app_bar.dart';
import 'dart:async';

import '../../../core/sph/sph.dart';
import '../../../models/client_status_exceptions.dart';
import '../../../models/conversations.dart';
import '../../../utils/fetch_more_indicator.dart';
import '../../../widgets/error_view.dart';
import '../../../widgets/format_text.dart';

import '../shared.dart';

class ConversationsChat extends StatefulWidget {
  final String id;
  final String title;
  final NewConversationSettings? newSettings;
  final bool hidden;
  final bool isTablet;
  final VoidCallback refreshSidebar;
  final VoidCallback closeChat;
  final void Function(bool) updateShowStats;

  const ConversationsChat(
      {super.key,
      required this.title,
      required this.id,
      this.newSettings,
      required this.isTablet,
      required this.refreshSidebar,
      required this.closeChat,
      this.hidden = false,
      required this.updateShowStats});

  //bool get stateAreDetailesOpened => state

  ConversationsChat.fromEntry(OverviewEntry entry, this.isTablet,
      {super.key,
      required this.refreshSidebar,
      required this.closeChat,
      required this.updateShowStats})
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

  final IndicatorController refreshIndicatorController = IndicatorController();

  double richTextEditorSize = 74.0;

  final Map<String, TextStyle> textStyles = {};

  late ConversationSettings settings;
  late ParticipationStatistics? statistics;

  bool showStats = false;
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

  Widget backButton() {
    return IconButton(
      onPressed: () {
        widget.closeChat();
      },
      icon: Icon(Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back),
    );
  }

  @override
  void initState() {
    super.initState();
    scrollController.addListener(toggleScrollToBottomFab);
    hidden = widget.hidden;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      BottomNavBarChangeNotifier.instance.setVisible(false);
      AppBarController.instance.setSecondTitle(widget.title);
      AppBarController.instance
          .setLeadingAction('conversationsExitChat', backButton(), weight: 2,
              canBeUsed: (constraints) {
        // Only show back button if the chat is not hidden
        return !(constraints.maxWidth > 600);
      });
    });
    initRefreshTimer();
  }

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
    _messagesSendInThisSession.clear();
    _lastRefresh = 0;
    isSendVisible.dispose();
    isScrollToBottomVisible.dispose();
    refreshIndicatorController.dispose();
    messageField.dispose();
    _refreshTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      BottomNavBarChangeNotifier.instance.setVisible(true);
      AppBarController.instance.setSecondTitle(null);
      AppBarController.instance.removeAction('conversationsStatistics');
      AppBarController.instance.removeLeadingAction('conversationsExitChat');
      AppBarController.instance.setOverrideTitle(null);
    });
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

    if (statistics != null) {
      AppBarController.instance.addAction(
        'conversationsStatistics',
        IconButton(
          icon: Icon(Icons.people),
          onPressed: () {
            setState(
              () {
                showStats = !showStats;
              },
            );
            widget.updateShowStats(showStats);
          },
        ),
      );
    }
  }

  bool initScrollToBottom = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ValueListenableBuilder(
        valueListenable: isScrollToBottomVisible,
        builder: (context, isVisible, _) {
          return Visibility(
            visible: isVisible,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: richTextEditorSize,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: scrollToBottom,
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.secondaryFixedDim,
                        width: 2,
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
        top: false,
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
                  );
                }
              }
              if (initScrollToBottom) {
                initScrollToBottom = false;
                //scrollToBottom(initDelay: Duration(milliseconds: 120));
              }
              return Stack(
                children: [
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
                              final reversedIndex = chat.length - 1 - index;
                              if (chat[reversedIndex] is Message) {
                                return MessageWidget(
                                    message: chat[reversedIndex],
                                    textStyle:
                                        textStyles[chat[reversedIndex].author]);
                              } else {
                                return DateHeaderWidget(
                                    header: chat[reversedIndex]);
                              }
                            },
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
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
                                          vertical: 8.0, horizontal: 12.0),
                                      margin: const EdgeInsets.only(top: 16.0),
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
                  Row(
                    children: [
                      Spacer(),
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
                    ],
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
                  Visibility(
                    visible: showStats,
                    child: StatisticWidget(
                      statistics: statistics!,
                      conversationTitle: widget.title,
                      close: () {
                        setState(() {
                          showStats = false;
                        });
                        widget.updateShowStats(showStats);
                      },
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

class StatisticWidget extends StatelessWidget {
  final String conversationTitle;
  final ParticipationStatistics statistics;
  final VoidCallback close;

  const StatisticWidget(
      {super.key,
      required this.statistics,
      required this.conversationTitle,
      required this.close});

  Widget statisticsHeaderRow(
      BuildContext context, Icon icon, String title, int count) {
    return Column(
      children: [
        icon,
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.bodyMedium,
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: close,
        ),
        title: Text(AppLocalizations.of(context).receivers),
      ),
      body: ListView(
        children: [
          const SizedBox(
            height: 30,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 60,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  conversationTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 30,
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                      child: statisticsHeaderRow(
                          context,
                          const Icon(Icons.person),
                          AppLocalizations.of(context).participants,
                          statistics.countStudents)),
                  Expanded(
                      child: statisticsHeaderRow(
                          context,
                          const Icon(Icons.school),
                          AppLocalizations.of(context).supervisors,
                          statistics.countTeachers)),
                  Expanded(
                      child: statisticsHeaderRow(
                          context,
                          const Icon(Icons.supervisor_account),
                          AppLocalizations.of(context).parents,
                          statistics.countParents)),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Text(
            AppLocalizations.of(context).knownReceivers,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 5,
          ),
          for (final KnownParticipant participant
              in statistics.knownParticipants) ...[
            ListTile(
              title: Text(participant.name),
              leading: Icon(participant.type.icon),
            )
          ]
        ],
      ),
    );
  }
}

class DateHeaderWidget extends StatelessWidget {
  final DateHeader header;

  const DateHeaderWidget({super.key, required this.header});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Card(
          margin: const EdgeInsets.only(top: 16.0, bottom: 4.0),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Text(DateFormat(
                    "d. MMMM y", Localizations.localeOf(context).languageCode)
                .format(header.date)),
          ),
        )
      ],
    );
  }
}

class MessageWidget extends StatelessWidget {
  final Message message;
  final TextStyle? textStyle;

  const MessageWidget(
      {super.key, required this.message, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    final double size = MediaQuery.sizeOf(context).width - 200;

    return Padding(
      padding: BubbleStructure.getMargin(message.state),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: BubbleStructure.getAlignment(message.own),
        children: [
          // Author name
          if (message.state == MessageState.first && !message.own) ...[
            Text(
              message.author!,
              style: textStyle,
            )
          ],

          // Message bubble
          ClipPath(
            clipper: message.state == MessageState.first
                ? BubbleStructure.getFirstStateClipper(message.own)
                : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.clamp(350, 600),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: BubbleStyles.getStyle(message.own).mainColor,
                  borderRadius: message.state != MessageState.first
                      ? BubbleStructure.radius
                      : null,
                ),
                child: Padding(
                  padding: BubbleStructure.getPadding(
                      message.state == MessageState.first, message.own),
                  child: FormattedText(
                      text: message.text,
                      formatStyle:
                          BubbleStyles.getStyle(message.own).textFormatStyle),
                ),
              ),
            ),
          ),

          // Date text
          Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: message.state == MessageState.first
                      ? BubbleStructure.compensatedPadding
                      : BubbleStructure.horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat("HH:mm").format(message.date),
                      style: BubbleStyles.getStyle(message.own).dateTextStyle),
                  if (message.own) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        Icons.circle,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 3,
                      ),
                    ),
                    if (message.status == MessageStatus.sending) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 2.0),
                        child: SizedBox(
                            width: 10.0,
                            height: 10.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            )),
                      )
                    ] else if (message.status == MessageStatus.error) ...[
                      Icon(
                        Icons.error,
                        color: Theme.of(context).colorScheme.error,
                        size: 12,
                      )
                    ] else ...[
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 12,
                      )
                    ]
                  ]
                ],
              ))
        ],
      ),
    );
  }
}
