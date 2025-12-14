import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:flutter_tagging_plus/flutter_tagging_plus.dart';
import '../../../core/connection_checker.dart';
import '../../../core/sph/sph.dart';
import '../../../models/conversations.dart';

class NewConversationConfigurator extends StatefulWidget {
  const NewConversationConfigurator({super.key});

  @override
  State<NewConversationConfigurator> createState() =>
      _NewConversationConfiguratorState();
}

class TriggerRebuild with ChangeNotifier {
  void trigger() {
    notifyListeners();
  }
}

class _NewConversationConfiguratorState
    extends State<NewConversationConfigurator> {
  final TextEditingController subjectController = TextEditingController();
  final List<ReceiverEntry> receivers = [];
  final TriggerRebuild rebuildSearch = TriggerRebuild();
  ChatType selectedChatType = ChatType.values[2];

  bool get isFormValid =>
      subjectController.text.trim().isNotEmpty && receivers.isNotEmpty;

  void _clearAll() {
    setState(() {
      subjectController.clear();
      receivers.clear();
      selectedChatType = ChatType.values[0];
    });
    rebuildSearch.trigger();
  }

  void _createChat() {
    if (!isFormValid) return;

    final chatData = ChatCreationData(
      type: sph!.parser.conversationsParser.cachedCanChooseType!
          ? selectedChatType
          : null,
      subject: subjectController.text.trim(),
      receivers: receivers.map((entry) => entry.id).toList(),
    );

    Navigator.pop(context, chatData);
  }

  @override
  void dispose() {
    subjectController.dispose();
    rebuildSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).createNewConversation),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isFormValid ? _createChat : null,
        icon: const Icon(Icons.create),
        label: Text(AppLocalizations.of(context).create),
        backgroundColor: isFormValid
            ? Theme.of(context).floatingActionButtonTheme.backgroundColor
            : Colors.grey,
      ),
      body: ListView(
        padding: const EdgeInsets.all(4.0),
        children: [
          // Topic Section
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.topic, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).subject,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: null,
                  autofocus: true,
                  onChanged: (value) => setState(() {}),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Participants Section
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).addReceivers,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (receivers.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_all),
                        onPressed: _clearAll,
                        tooltip: AppLocalizations.of(context).clearAll,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListenableBuilder(
                  listenable: rebuildSearch,
                  builder: (context, widget) {
                    return FlutterTagging<ReceiverEntry>(
                      initialItems: receivers,
                      textFieldConfiguration: TextFieldConfiguration(
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(
                            context,
                          ).addReceiversHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      configureSuggestion: (entry) {
                        return SuggestionConfiguration(
                          title: Text(entry.name),
                          leading: Icon(
                            entry.isTeacher ? Icons.school : Icons.person,
                          ),
                          subtitle: entry.isTeacher
                              ? Text(AppLocalizations.of(context).teacher)
                              : null,
                        );
                      },
                      configureChip: (entry) {
                        return ChipConfiguration(
                          label: Text(entry.name),
                          avatar: Icon(
                            entry.isTeacher ? Icons.school : Icons.person,
                          ),
                        );
                      },
                      loadingBuilder: (context) {
                        return ListTile(
                          leading: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          ),
                          title: Text(AppLocalizations.of(context).loading),
                        );
                      },
                      emptyBuilder: (context) {
                        if (connectionChecker.status ==
                            ConnectionStatus.disconnected) {
                          return ListTile(
                            leading: const Icon(Icons.wifi_off),
                            title: Text(
                              AppLocalizations.of(
                                context,
                              ).noInternetConnection2,
                            ),
                          );
                        }

                        return ListTile(
                          leading: const Icon(Icons.person_off),
                          title: Text(
                            AppLocalizations.of(context).noPersonFound,
                          ),
                        );
                      },
                      onAdded: (receiverEntry) {
                        setState(() {});
                        return receiverEntry;
                      },
                      findSuggestions: (query) async {
                        query = query.trim();
                        if (query.isEmpty) return <ReceiverEntry>[];

                        final dynamic result = await sph!
                            .parser
                            .conversationsParser
                            .searchTeacher(query);
                        return result;
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          if (sph!.parser.conversationsParser.cachedCanChooseType ?? false) ...[
            const Divider(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.chat, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context).conversationType,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...ChatType.values.map((chatType) {
                      return RadioListTile<ChatType>(
                        dense: true,
                        value: chatType,
                        groupValue: selectedChatType,
                        onChanged: (value) {
                          setState(() {
                            selectedChatType = value!;
                          });
                        },
                        title: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(chatType.icon),
                            ),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(
                                  context,
                                ).conversationTypeName(chatType.name),
                              ),
                            ),
                            if (chatType == ChatType.openChat) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).experimental.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                            if (chatType == ChatType.groupOnly) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).recommended.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          AppLocalizations.of(
                            context,
                          ).conversationTypeDescription(chatType.name),
                          textAlign: TextAlign.start,
                        ),
                        isThreeLine: chatType == ChatType.openChat,
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: 200),
        ],
      ),
    );
  }
}
