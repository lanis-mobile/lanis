import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lanis/applets/conversations/view/components/conversation_tile.dart';
import 'package:lanis/applets/conversations/view/components/scrolled_down_container.dart';
import 'package:lanis/applets/conversations/view/components/conversations_layout_builder.dart';
import 'package:lanis/applets/conversations/view/send.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/applets/conversations/definition.dart';
import 'package:lanis/applets/conversations/parser.dart';
import 'package:lanis/utils/back_navigation_manager.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/widgets/combined_applet_builder.dart';
import 'package:lanis/widgets/dynamic_app_bar.dart';
import '../../../core/sph/sph.dart';
import '../../../models/client_status_exceptions.dart';
import '../../../models/conversations.dart';
import '../../../utils/keyboard_observer.dart';
import 'chat.dart';
import 'new_conversation_configurator.dart';

const double tileSize = 80.0;

class ConversationsView extends StatefulWidget {
  final Function? openDrawerCb;
  const ConversationsView({super.key, this.openDrawerCb});

  @override
  State<StatefulWidget> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<ConversationsView>
    with BackNavigationMixin {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();

  static const advancedSearchIcons = {
    SearchFunction.subject: Icon(Icons.subject),
    SearchFunction.name: Icon(Icons.person),
    SearchFunction.schedule: Icon(Icons.calendar_today)
  };

  static bool simpleRemoveButton = false;
  static Map<SearchFunction, bool> advancedRemoveButtons = {
    SearchFunction.subject: false,
    SearchFunction.name: false,
    SearchFunction.schedule: false
  };

  static bool showHidden = false;
  static bool advancedSearch = false;
  static bool toggleMode = false;

  OverviewFiltering get filter => sph!.parser.conversationsParser.filter;

  final TextEditingController simpleSearchController = TextEditingController();
  final Map<SearchFunction, TextEditingController> advancedSearchControllers = {
    SearchFunction.subject: TextEditingController(),
    SearchFunction.name: TextEditingController(),
    SearchFunction.schedule: TextEditingController()
  };
  final ScrollController scrollController = ScrollController();
  final KeyboardObserver keyboardObserver = KeyboardObserver();

  final Map<String, bool> checkedTiles = {};

  bool loadingCreateButton = false;
  bool disableToggleButton = false;
  bool showCreateScreen = false;

  Widget? loadedWidget;
  String? get loadedConversationId => loadedWidget is ConversationsChat
      ? (loadedWidget as ConversationsChat).id
      : null;
  List<String> noBadgeConversations = [];
  bool chatIsShowingStats = false;

  @override
  Future<bool> canHandleBackNavigation() async {
    if (loadedWidget != null || showCreateScreen || toggleMode) {
      return true;
    }
    return false;
  }

  @override
  Future<bool> handleBackNavigation() async {
    final isTablet = Responsive.isTablet(context);
    if (isTablet) {
      if (toggleMode) {
        closeToggleMode();
        return true;
      }
      if (showCreateScreen) {
        closeCreateScreen();
        return true;
      }
      if (loadedWidget != null) {
        setState(() {
          loadedWidget = null;
          noBadgeConversations.clear();
        });
        return true;
      }
    } else {
      if (loadedWidget != null) {
        if ((loadedWidget is ConversationsChat) && chatIsShowingStats) {
          return false;
        }
        setState(() {
          loadedWidget = null;
          noBadgeConversations.clear();
        });
        return true;
      } else if (showCreateScreen) {
        closeCreateScreen();
        return true;
      } else if (toggleMode) {
        closeToggleMode();
        return true;
      }
    }

    return true;
  }

  Widget toggleModeAppBar() {
    return SizedBox(
      height: 64,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              constraints: BoxConstraints.tightFor(
                  width: kToolbarHeight, height: kToolbarHeight),
              onPressed: () {
                closeToggleMode();
                for (final tile in checkedTiles.keys) {
                  checkedTiles[tile] = false;
                }
              },
            ),
            SizedBox(
              width: 16,
            ),
            Text(
              AppLocalizations.of(context).hideShowConversations,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget searchWidget() {
    return Padding(
        padding:
            const EdgeInsets.only(left: 8.0, right: 8.0, top: 0, bottom: 8),
        child: Column(
          children: [
            // Advanced search
            if (advancedSearch) ...[
              ...List<Padding>.generate(filter.advancedSearch.length, (i) {
                SearchFunction function =
                    filter.advancedSearch.keys.elementAt(i);

                filterFunction(String text) {
                  filter.advancedSearch[function] = text;
                  filter.pushEntries();

                  if (text.isEmpty) {
                    setState(() {
                      advancedRemoveButtons[function] = false;
                    });
                  }

                  if (advancedRemoveButtons[function] == false &&
                      text.isNotEmpty) {
                    setState(() {
                      advancedRemoveButtons[function] = true;
                    });
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 2.0),
                  child: SearchBar(
                    hintText: AppLocalizations.of(context)
                        .individualSearchHint(function.name),
                    textInputAction: TextInputAction.search,
                    controller: advancedSearchControllers[function],
                    onSubmitted: filterFunction,
                    onChanged: filterFunction,
                    onTapOutside: (event) {
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: advancedSearchIcons[function],
                    ),
                    trailing: [
                      Visibility(
                        visible: advancedRemoveButtons[function]!,
                        child: IconButton(
                            onPressed: () {
                              filter.advancedSearch[function] = "";
                              advancedSearchControllers[function]!.clear();
                              filter.pushEntries();

                              setState(() {
                                advancedRemoveButtons[function] = false;
                              });
                            },
                            icon: const Icon(Icons.delete)),
                      )
                    ],
                  ),
                );
              })
            ],

            // Simple search
            SearchBar(
              hintText: AppLocalizations.of(context).searchHint,
              textInputAction: TextInputAction.search,
              controller: simpleSearchController,
              onSubmitted: (String text) {
                filter.simpleSearch = text;
                filter.pushEntries();
              },
              onChanged: (String text) {
                filter.simpleSearch = text;
                filter.pushEntries();

                if (text.isEmpty) {
                  setState(() {
                    simpleRemoveButton = false;
                  });
                }

                if (simpleRemoveButton == false && text.isNotEmpty) {
                  setState(() {
                    simpleRemoveButton = true;
                  });
                }
              },
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              trailing: [
                Visibility(
                  visible: simpleRemoveButton,
                  child: IconButton(
                      onPressed: () {
                        filter.simpleSearch = "";
                        simpleSearchController.clear();
                        filter.pushEntries();

                        setState(() {
                          simpleRemoveButton = false;
                        });
                      },
                      icon: const Icon(Icons.delete)),
                ),
                MenuAnchor(
                  builder: (context, controller, _) => IconButton(
                      onPressed: () {
                        if (controller.isOpen) {
                          controller.close();
                        } else {
                          controller.open();
                        }
                      },
                      icon: const Icon(Icons.more_vert)),
                  menuChildren: [
                    MenuItemButton(
                      leadingIcon: advancedSearch
                          ? Icon(Icons.search_off)
                          : Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          advancedSearch = !advancedSearch;
                        });
                      },
                      child: Text(advancedSearch
                          ? AppLocalizations.of(context).simpleSearch
                          : AppLocalizations.of(context).advancedSearch),
                    ),
                    MenuItemButton(
                      leadingIcon: showHidden
                          ? const Icon(Icons.visibility_off)
                          : const Icon(Icons.visibility),
                      onPressed: () {
                        setState(() {
                          if (showHidden) {
                            loadedWidget = null;
                          }
                          showHidden = !showHidden;
                        });

                        final oldEntries = sph!
                            .parser.conversationsParser.stream.value.content;

                        filter.showHidden = showHidden;
                        filter.pushEntries();

                        jumpToTopTile(
                            sph!.parser.conversationsParser.stream.value
                                .content!,
                            oldEntries!);
                      },
                      child: Text(showHidden
                          ? AppLocalizations.of(context).showOnlyVisible
                          : AppLocalizations.of(context).showAll),
                    ),
                    const Divider(),
                    MenuItemButton(
                      leadingIcon: Icon(Icons.restore_from_trash),
                      onPressed: () {
                        final oldEntries = sph!
                            .parser.conversationsParser.stream.value.content;

                        openToggleMode();

                        jumpToTopTile(
                            sph!.parser.conversationsParser.stream.value
                                .content!,
                            oldEntries!);
                      },
                      child: Text(AppLocalizations.of(context).hideShow),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ));
  }

  String? noConversationAsset;
  Widget sideBarNoConversationsLoaded() {
    final List<String> assets = [
      "assets/undraw/chat/undraw_work-chat_hc3y.svg",
      "assets/undraw/chat/undraw_quick-chat_3gj8.svg",
      "assets/undraw/chat/undraw_online-message_k64b.svg",
      "assets/undraw/chat/undraw_chatting_5u5z.svg",
      "assets/undraw/chat/undraw_chat_qmyo.svg",
    ];
    noConversationAsset ??= assets[
        (DateTime.now().millisecondsSinceEpoch / 1000).toInt() % assets.length];

    return Center(
      child: SvgPicture.asset(noConversationAsset!, height: 175.0),
    );
  }

  // Switching between two lists of overview entries messes up the scroll controller, so we just try to jump to the top visible tile and anchor to it.
  // If top tile is not visible in the new list, we try to find the first visible tile above the top tile and jump to it.
  void jumpToTopTile(
      final List<OverviewEntry> entries, final List<OverviewEntry> oldEntries) {
    if (oldEntries.isEmpty) return;

    final offsetTopIndex = (scrollController.offset / 80).toInt();

    double position = 0;
    if (!(entries.contains(oldEntries[offsetTopIndex]))) {
      for (int i = offsetTopIndex; i >= 0; i--) {
        if (entries.contains(oldEntries[i])) {
          final index = entries.indexOf(oldEntries[i]);
          position = index * tileSize;
          break;
        }
      }
    } else {
      final index = entries.indexOf(oldEntries[offsetTopIndex]);
      position = index * tileSize;
    }

    final viewport = scrollController.position.viewportDimension;
    final size = (entries.length + 2.5) * tileSize;

    if (size < viewport) {
      return;
    }

    if (position >= size - viewport) {
      scrollController.jumpTo(size - viewport + 64);
    } else {
      scrollController.jumpTo(
          position + (scrollController.offset - (offsetTopIndex * tileSize)));
    }
  }

  void openToggleMode() {
    setState(() {
      toggleMode = true;
    });
    filter.toggleMode = true;
    filter.pushEntries();
    sph!.parser.conversationsParser.toggleSuspend();
  }

  void closeToggleMode() {
    setState(() {
      toggleMode = false;
      disableToggleButton = false;
    });

    final oldEntries = sph!.parser.conversationsParser.stream.value.content;

    filter.toggleMode = false;
    filter.pushEntries();

    sph!.parser.conversationsParser.toggleSuspend();

    jumpToTopTile(
        sph!.parser.conversationsParser.stream.value.content!, oldEntries!);
  }

  void openCreateScreen() {
    AppBarController.instance
        .setOverrideTitle(AppLocalizations.of(context).createNewConversation);
    AppBarController.instance.setLeadingAction(
      'createConversation',
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          closeCreateScreen();
        },
      ),
      weight: 1,
    );
    setState(() {
      showCreateScreen = true;
    });
  }

  void closeCreateScreen() {
    AppBarController.instance.setOverrideTitle(null);
    AppBarController.instance.removeLeadingAction('createConversation');
    setState(() {
      showCreateScreen = false;
    });
  }

  /// After the create chat modal is created, this function is called to initialize the chat and make the user type in the first message.
  void onInitializeChat(ChatCreationData? chatData) {
    if (chatData == null) {
      return;
    }
    closeCreateScreen();
    setState(() {
      loadedWidget = ConversationsSend(
        updateShowStats: (newValue) => chatIsShowingStats = newValue,
        creationData: chatData,
        isTablet: Responsive.isTablet(context),
        refreshSidebar: () =>
            sph!.parser.conversationsParser.filter.pushEntries(),
        onCreateChat: startNewConversation,
        closeChat: () => setState(() {
          loadedWidget = null;
          noBadgeConversations.clear();
        }),
      );
      noBadgeConversations.clear();
    });
  }

  void startNewConversation(ConversationsChat newChat) {
    setState(() {
      loadedWidget = newChat;
    });
    _refreshKey.currentState?.show();
  }

  @override
  void initState() {
    super.initState();

    sph!.parser.conversationsParser.fetchData();

    keyboardObserver.addDefaultCallback();

    simpleSearchController.text = filter.simpleSearch;

    for (final value in SearchFunction.values) {
      advancedSearchControllers[value]!.text =
          filter.advancedSearch[value] ?? "";
    }
  }

  @override
  void dispose() {
    super.dispose();
    simpleSearchController.dispose();
    for (final value in SearchFunction.values) {
      advancedSearchControllers[value]!.dispose();
    }
    keyboardObserver.dispose();
    scrollController.dispose();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppBarController.instance.setOverrideTitle(null);
      AppBarController.instance.removeLeadingAction('createConversation');
      AppBarController.instance.removeAction('conversationsStatistics');
      AppBarController.instance.setSecondTitle(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (notification) {
        if (notification is CheckTileNotification) {
          if (!toggleMode) {
            openToggleMode();
          }

          setState(() {
            checkedTiles[notification.id!] =
                !(checkedTiles[notification.id!] ?? false);
          });
          return true;
        } else if (notification is JumpToNotification) {
          scrollController.jumpTo(notification.position!);
          return true;
        }

        return false;
      },
      child: ConversationsLayoutBuilder(
          leftBuilder: (context, isTablet) => showCreateScreen
              ? NewConversationConfigurator(
                  isTablet: isTablet,
                  onChatCreated: onInitializeChat,
                )
              : Scaffold(
                  body: CombinedAppletBuilder<List<OverviewEntry>>(
                      parser: sph!.parser.conversationsParser,
                      phpUrl: conversationsDefinition.appletPhpIdentifier,
                      settingsDefaults:
                          conversationsDefinition.settingsDefaults,
                      accountType: sph!.session.accountType,
                      builder: (context, data, accountType, settings,
                          updateSetting, refresh) {
                        noBadgeConversations = [];
                        return RefreshIndicator(
                          key: _refreshKey,
                          edgeOffset: advancedSearch && !toggleMode ? 256 : 64,
                          onRefresh: refresh!,
                          child: CustomScrollView(
                            controller: scrollController,
                            physics: AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFloatingHeader(
                                child: ScrolledDownContainer(
                                    child: toggleMode
                                        ? toggleModeAppBar()
                                        : searchWidget()),
                              ),
                              SliverVariedExtentList.builder(
                                itemCount: data.length + 1,
                                itemExtentBuilder: (index, _) {
                                  if (index > data.length - 1) {
                                    return tileSize * 2.5;
                                  }

                                  return tileSize;
                                },
                                itemBuilder: (context, index) {
                                  if (index > data.length - 1) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          top: 12.0, left: 12.0, right: 12.0),
                                      child: ListTile(
                                        title: Text(
                                          AppLocalizations.of(context)
                                              .noFurtherEntries,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        subtitle: Text(
                                          AppLocalizations.of(context)
                                              .conversationNote,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  }

                                  return ConversationTile(
                                    entry: data[index],
                                    isOpen:
                                        loadedConversationId == data[index].id,
                                    toggleMode: toggleMode,
                                    loadedConversationId: loadedConversationId,
                                    noBadgeConversations: noBadgeConversations,
                                    checked:
                                        checkedTiles[data[index].id] ?? false,
                                    onTap: (entry) {
                                      if (entry.unread == true) {
                                        sph!.parser.conversationsParser.filter
                                            .toggleEntry(entry.id,
                                                unread: true);
                                        sph!.parser.conversationsParser.filter
                                            .pushEntries();
                                      }
                                      setState(() {
                                        noBadgeConversations.add(entry.id);
                                        loadedWidget =
                                            ConversationsChat.fromEntry(
                                          key: Key(entry.id),
                                          refreshSidebar: refresh,
                                          entry,
                                          isTablet,
                                          updateShowStats: (newValue) =>
                                              chatIsShowingStats = newValue,
                                          closeChat: () {
                                            setState(() {
                                              loadedWidget = null;
                                              noBadgeConversations.clear();
                                            });
                                          },
                                        );
                                      });
                                    },
                                  );
                                },
                              )
                            ],
                          ),
                        );
                      }),
                  floatingActionButton: toggleMode
                      ? disableToggleButton
                          ? FloatingActionButton(
                              onPressed: null,
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: const CircularProgressIndicator(),
                              ))
                          : FloatingActionButton.extended(
                              icon: Icon(Icons.visibility),
                              label:
                                  Text(AppLocalizations.of(context).hideShow),
                              onPressed: () async {
                                setState(() {
                                  disableToggleButton = true;
                                  loadedWidget = null;
                                });

                                // So you don't see each tile being toggled
                                Map<String, bool> toggled = {};

                                for (final tile in checkedTiles.entries) {
                                  if (tile.value == true) {
                                    final isHidden = filter.entries
                                        .where(
                                            (element) => element.id == tile.key)
                                        .first
                                        .hidden;

                                    late bool result;
                                    try {
                                      if (isHidden) {
                                        result = await sph!
                                            .parser.conversationsParser
                                            .showConversation(tile.key);
                                      } else {
                                        result = await sph!
                                            .parser.conversationsParser
                                            .hideConversation(tile.key);
                                      }
                                    } on NoConnectionException {
                                      setState(() {
                                        disableToggleButton = false;
                                      });

                                      if (context.mounted) {
                                        showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                                  icon: const Icon(
                                                      Icons.wifi_off),
                                                  title: Text(AppLocalizations
                                                          .of(context)
                                                      .noInternetConnection2),
                                                  actions: [
                                                    FilledButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: Text(
                                                            AppLocalizations.of(
                                                                    context)
                                                                .back))
                                                  ],
                                                ));
                                      }
                                      return;
                                    }

                                    if (!result) {
                                      setState(() {
                                        disableToggleButton = false;
                                      });

                                      if (context.mounted) {
                                        showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                                  icon: const Icon(Icons.error),
                                                  title: Text(
                                                      AppLocalizations.of(
                                                              context)
                                                          .errorOccurred),
                                                  actions: [
                                                    FilledButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                              context);
                                                        },
                                                        child: Text(
                                                            AppLocalizations.of(
                                                                    context)
                                                                .back))
                                                  ],
                                                ));
                                      }
                                      return;
                                    }

                                    toggled.addEntries([tile]);
                                    checkedTiles[tile.key] = false;
                                  }
                                }

                                for (final id in toggled.keys) {
                                  filter.toggleEntry(id, hidden: true);
                                }

                                filter.pushEntries();
                                closeToggleMode();
                              })
                      : FloatingActionButton(
                          heroTag: "create_conversation",
                          onPressed: () async {
                            if (sph!.parser.conversationsParser
                                    .cachedCanChooseType !=
                                null) {
                              openCreateScreen();
                            }

                            setState(() {
                              loadingCreateButton = true;
                            });

                            try {
                              await sph!.parser.conversationsParser
                                  .canChooseType();
                            } on NoConnectionException {
                              setState(() {
                                loadingCreateButton = false;
                              });
                              return;
                            }

                            setState(() {
                              loadingCreateButton = false;
                            });

                            if (context.mounted) {
                              openCreateScreen();
                            }
                          },
                          child: loadingCreateButton
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: const CircularProgressIndicator(),
                                )
                              : const Icon(Icons.edit),
                        ),
                ),
          rightBuilder: (loadedWidget != null)
              ? (context, isTablet) => loadedWidget!
              : null,
          rightPlaceholder: sideBarNoConversationsLoaded(),
          onPopRight: () {
            setState(() {
              loadedWidget = null;
              noBadgeConversations.clear();
            });
          }),
    );
  }
}

class CheckTileNotification extends Notification {
  final String? id;

  const CheckTileNotification({this.id});
}

class JumpToNotification extends Notification {
  final double? position;

  const JumpToNotification({this.position});
}
