import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart';
import 'package:lanis/core/applet_parser.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../../core/connection_checker.dart';
import '../../core/sph/cryptor.dart';
import '../../globals.dart';
import '../../models/client_status_exceptions.dart';
import '../../models/conversations.dart';
import '../../utils/logger.dart';

class ConversationsParser extends AppletParser<List<OverviewEntry>> {
  late final OverviewFiltering filter;

  bool? cachedCanChooseType;

  ConversationsParser(super.sph, super.appletDefinition) {
    filter = OverviewFiltering(this);
  }

  bool _suspend = false;

  void toggleSuspend() {
    _suspend = !_suspend;
  }

  @override
  void timerCallback(Timer timer) {
    if (!_suspend) {
      super.timerCallback(timer);
    }
  }

  /// Gets the entries which you can see in the overview.
  @override
  Future<List<OverviewEntry>> getHome() async {
    final response = await sph.session.dio.post(
        "https://start.schulportal.hessen.de/nachrichten.php",
        data: {
          "a": "headers",
          "getType": "All", // "unvisibleOnly", "visibleOnly" also possible
          "last": "0"
        },
        options: Options(
          headers: {
            "Accept": "*/*",
            "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
            "Sec-Fetch-Dest": "empty",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Site": "same-origin",
            "X-Requested-With": "XMLHttpRequest",
          },
        ));

    final dynamic json = await compute(
        computeJson, [response.toString(), sph.session.cryptor.key.bytes]);

    List<OverviewEntry> entries = [];
    for (final entry in json) {
      entries.add(OverviewEntry.fromJson(entry));
    }

    filter.entries = entries;

    return filter.filteredAndSearched(entries);
  }

  // Move decrypting and decoding away from the main thread to avoid freezing.
  static dynamic computeJson(List<dynamic> args) {
    final Map<String, dynamic> encryptedJSON = jsonDecode(args[0]);

    final String? decryptedConversations = Cryptor.decryptWithKeyString(
        encryptedJSON["rows"], encrypt.Key(args[1]));

    if (decryptedConversations == null) {
      throw UnsaltedOrUnknownException();
    }

    return jsonDecode(decryptedConversations);
  }

  /// Hides the conversation
  /// [id] is the **"Uniquid"** of the conversation.
  Future<bool> hideConversation(String id) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {"a": "deleteAll", "uniqid": id},
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      return bool.parse(response.data);
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Shows a hidden conversation.
  /// [id] is the **"Uniquid"** of the conversation.
  Future<bool> showConversation(String id) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {"a": "recycleMsg", "uniqid": id},
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      return bool.parse(response.data);
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  // Sometimes usernames are the same as "SenderName", a HTML-Element.
  String fixUsername(String username) {
    if (!username.contains("fa-user")) {
      return username;
    }

    return getUsernameInsideHTML.firstMatch(username)!.group(1)!;
  }

  /// Gets a whole single conversation with statistics.
  Future<Conversation> getSingleConversation(String uniqueID) async {
    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final encryptedUniqueID = sph.session.cryptor.encryptString(uniqueID);

      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/nachrichten.php",
              queryParameters: {"a": "read", "msg": uniqueID},
              data: {"a": "read", "uniqid": encryptedUniqueID},
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final Map<String, dynamic> encryptedJSON =
          jsonDecode(response.toString());

      final String? decryptedConversations =
          sph.session.cryptor.decryptString(encryptedJSON["message"]);

      if (decryptedConversations == null) {
        throw UnsaltedOrUnknownException();
      }

      final Map<String, dynamic> conversation =
          jsonDecode(decryptedConversations);

      final UnparsedMessage parent = UnparsedMessage(
          id: conversation["Uniquid"],
          date: unescape.convert(conversation["Datum"]),
          author: unescape.convert(fixUsername(conversation["username"])),
          own: conversation["own"],
          content: unescape.convert(conversation["Inhalt"]));

      final List<UnparsedMessage> replies = [];
      for (dynamic reply in conversation["reply"]) {
        replies.add(UnparsedMessage(
            id: reply["Uniquid"],
            date: unescape.convert(reply["Datum"]),
            author: unescape.convert(fixUsername(reply["username"])),
            own: reply["own"],
            content: unescape.convert(reply["Inhalt"])));
      }

      int countStudents = conversation["statistik"]["teilnehmer"];
      int countTeachers = conversation["statistik"]["betreuer"];
      int countParents = conversation["statistik"]["eltern"];
      if (conversation["SenderArt"] == "Teilnehmer") {
        countStudents++;
      } else if (conversation["SenderArt"] == "Betreuer") {
        countTeachers++;
      } else {
        countParents++;
      }

      final Set<KnownParticipant> knownParticipants = {
        KnownParticipant(
            name: unescape.convert(fixUsername(conversation["username"])),
            type: PersonType.fromJson(conversation["SenderArt"]))
      };

      for (Map reply in conversation["reply"]) {
        knownParticipants.add(KnownParticipant(
            name: unescape.convert(fixUsername(reply["username"])),
            type: PersonType.fromJson(reply["SenderArt"])));
      }

      if (conversation["empf"] is List) {
        for (String receiver in conversation["empf"]) {
          final String name =
              parse(receiver).querySelector("span")!.text.substring(1);
          knownParticipants.add(KnownParticipant(
              name: unescape.convert(name), type: PersonType.other));
        }
      }

      if (conversation["WeitereEmpfaenger"] != "" &&
          conversation["WeitereEmpfaenger"] != null) {
        final others =
            parse(conversation["WeitereEmpfaenger"]).querySelectorAll("span");
        for (final other in others) {
          knownParticipants.add(KnownParticipant(
              name: unescape.convert(other.text.trim()),
              type: PersonType.group));
        }
      }

      return Conversation(
          groupChat: conversation["groupOnly"] == "ja",
          onlyPrivateAnswers: conversation["privateAnswerOnly"] == "ja",
          noReply: conversation["noAnswerAllowed"] == "ja",
          parent: parent,
          countStudents: countStudents,
          countTeachers: countTeachers,
          countParents: countParents,
          knownParticipants: knownParticipants.toList(),
          replies: replies,
          msgLastRefresh: encryptedJSON["time"]);
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  Future<ConversationsRefreshResult> refreshConversation(
      String uniqID, int lastRefresh) async {
    try {
      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {
                "a": "refresh",
                "last": "$lastRefresh",
                "uniqid": sph.session.cryptor.encryptString(uniqID),
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final decodedResponse = jsonDecode(response.data);
      final messages = jsonDecode(
          sph.session.cryptor.decryptString(decodedResponse['reply'])!);
      final int newLastRefresh = decodedResponse['time'];

      return ConversationsRefreshResult(
        messages: messages.map<UnparsedMessage>((dynamic message) {
          return UnparsedMessage(
              id: message["Uniquid"],
              date: unescape.convert(message["Datum"]),
              author: unescape.convert(fixUsername(message["username"])),
              own: message["own"],
              content: unescape.convert(message["Inhalt"]));
        }).toList(),
        lastRefresh: newLastRefresh,
      );
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      if (e is SocketException || e is DioException) {
        throw NetworkException();
      } else if (e is LanisException) {
        rethrow;
      } else {
        throw UnknownException();
      }
    }
  }

  /// Replies to an already existing conversation.
  ///
  /// [headId] is the **"Uniquid"** of the head message.
  ///
  /// [groupOnly] and [privateAnswerOnly] are only checked for existence and then ignored.
  ///
  /// [sender] is the **"Sender"** of the head message, you can also use **"all"**.
  ///
  /// [message] supports Lanis-styled text.
  ///
  /// If successful, it returns `true`.
  Future<ReplyToConversationResult> replyToConversation(
      String headId,
      String sender,
      String groupOnly,
      String privateAnswerOnly,
      String message) async {
    try {
      final Map replyData = {
        "to": sender,
        "groupOnly": groupOnly,
        "privateAnswerOnly": privateAnswerOnly,
        "message": message,
        "replyToMsg": headId,
      };

      String encrypted =
          sph.session.cryptor.encryptString(json.encode(replyData));

      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {
                "a": "reply",
                "c": encrypted,
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final jsonDecode = json.decode(response.data);

      return ReplyToConversationResult(
        success: jsonDecode["back"],
        messageId: jsonDecode["id"],
      );
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Creates a new conversation.
  ///
  /// [receivers] are Strings of Ids which you can get with `Unimplemented`.
  /// Possible receivers are _(from the point of a student)_:
  ///   - Students from the same _Lerngruppe_.
  ///   - All teachers
  ///
  /// [type] is one of the following types:
  ///   - `noAnswerAllowed`
  ///     - **Hinweis**: No answers.
  ///   - `privateAnswerOnly`
  ///     - **Mitteilung**: Answers only to sender.
  ///   - `groupOnly`
  ///     - **Gruppenchat**: Answers to everyone.
  ///   - `openChat`
  ///     - **Offener Chat**: Private messages among themselves possible.
  ///
  ///  [text] also supports Lanis-styled text.
  ///
  ///  If successful, it returns true.
  Future<CreationResponse> createConversation(
      List<String> receivers, String? type, String subject, String text) async {
    try {
      final List<Map<String, String>> createData = [
        {"name": "subject", "value": subject},
        {"name": "text", "value": text},
      ];

      if (type != null) {
        createData.add({"name": "Art", "value": type});
      }

      for (final String receiver in receivers) {
        createData.add({"name": "to[]", "value": receiver});
      }

      String encrypted =
          sph.session.cryptor.encryptString(json.encode(createData));

      final response = await sph.session.dio
          .post("https://start.schulportal.hessen.de/nachrichten.php",
              data: {
                "a": "newmessage",
                "c": encrypted,
              },
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Content-Type":
                      "application/x-www-form-urlencoded; charset=UTF-8",
                  "Sec-Fetch-Dest": "empty",
                  "Sec-Fetch-Mode": "cors",
                  "Sec-Fetch-Site": "same-origin",
                  "X-Requested-With": "XMLHttpRequest",
                },
              ));

      final Map decoded = json.decode(response.data);

      return CreationResponse(
          success: decoded["back"],
          id: decoded["id"]); // "back" should be bool, id is Uniquid
    } on (SocketException, DioException) {
      throw NetworkException();
    } on LanisException {
      rethrow;
    } catch (e) {
      throw UnknownException();
    }
  }

  Future<bool> canChooseType() async {
    if (cachedCanChooseType != null) {
      return cachedCanChooseType!;
    }

    if (!(await connectionChecker.connected)) {
      throw NoConnectionException();
    }

    try {
      final html = await sph.session.dio
          .get("https://start.schulportal.hessen.de/nachrichten.php",
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Sec-Fetch-Dest": "document",
                  "Sec-Fetch-Mode": "navigate",
                  "Sec-Fetch-Site": "none",
                },
              ));

      final document = parse(html.data);

      cachedCanChooseType = document.querySelector("#MsgOptions") != null;

      return cachedCanChooseType!;
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Searches for teachers using at least 2 chars.
  ///
  /// Returns an empty list or a list of [ReceiverEntry].
  Future<List<ReceiverEntry>> searchTeacher(String name) async {
    if (name.length < 2 || !(await connectionChecker.connected)) {
      return [];
    }

    try {
      final response = await sph.session.dio
          .get("https://start.schulportal.hessen.de/nachrichten.php",
              queryParameters: {"a": "searchRecipt", "q": name},
              options: Options(
                headers: {
                  "Accept": "*/*",
                  "Sec-Fetch-Dest": "document",
                  "Sec-Fetch-Mode": "navigate",
                  "Sec-Fetch-Site": "none",
                },
              ));

      /// total_count (don't need), incomplete_results (?, don't need),
      /// items => type: (lul, sus for students?, parents?, groups?),
      ///          id: (l-xxxx..., s-xxx.... for students?, parents?, groups?),
      ///          logo: (font awesome icons like: fa fa-user),
      ///          text: (name)
      ///       or empty
      final data = json.decode(response.data);

      if (data["items"] != null && data["items"].isNotEmpty) {
        final List<ReceiverEntry> teacherEntries = [];

        for (final teacher in data["items"]) {
          teacherEntries.add(ReceiverEntry.fromJson(teacher));
        }

        return teacherEntries;
      }

      return [];
    } on (SocketException, DioException) {
      throw NetworkException();
    } catch (e) {
      throw UnknownException();
    }
  }

  /// Force pushes new data for the stream.
  void addData(final List<OverviewEntry> content) {
    addResponse(FetcherResponse<List<OverviewEntry>>(
        status: FetcherStatus.done, content: content));
  }
}

/// Collection of filter functions for the search.
enum SearchFunction {
  subject,
  schedule, // can't use "date" bc of l10n
  name;

  static final functions = {
    SearchFunction.subject: (OverviewEntry entry, String search) =>
        entry.title.toLowerCase().contains(search.toLowerCase()),
    SearchFunction.name: (OverviewEntry entry, String search) =>
        (entry.shortName != null &&
            entry.shortName!.toLowerCase().contains(search.toLowerCase())) ||
        entry.fullName.toLowerCase().contains(search.toLowerCase()),
    SearchFunction.schedule: (OverviewEntry entry, String search) =>
        entry.date.toLowerCase().contains(search.toLowerCase()),
  };

  call(OverviewEntry entry, String search) {
    return functions[this]!(entry, search);
  }
}

/// A useful class to directly modify the most recent downloaded overview stream,
/// so it's fast.
class OverviewFiltering {
  late ConversationsParser parser;

  OverviewFiltering(this.parser);

  /// Cached overview entries set by a [getOverview] call.
  List<OverviewEntry> entries = [];

  /// Skip current options when in toggle mode.
  bool toggleMode = false;

  bool showHidden = false;
  String simpleSearch = "";

  final advancedSearch = {
    SearchFunction.subject: "",
    SearchFunction.name: "",
    SearchFunction.schedule: "",
  };

  /// Pushes entries to the fetcher using the current settings.
  void pushEntries() {
    parser.addData(filteredAndSearched(entries));
  }

  void toggleEntry(String id, {bool? hidden, bool? unread}) {
    final index = entries.indexWhere((entry) => entry.id == id);
    entries.replaceRange(index, index + 1, [
      entries[index].copyWith(
        hidden:
            hidden == null || hidden == false ? null : !entries[index].hidden,
        unread:
            unread == null || unread == false ? null : !entries[index].unread,
      )
    ]);
  }

  List<OverviewEntry> filteredAndSearched(List<OverviewEntry> entries) {
    return searched(filtered(entries));
  }

  /// Show all conversations or just non-hidden ones.
  List<OverviewEntry> filtered(List<OverviewEntry> entries) {
    if (showHidden || toggleMode) {
      return entries;
    }

    return entries.where((entry) => entry.hidden == false).toList();
  }

  List<OverviewEntry> advancedSearched(
      List<OverviewEntry> entries, SearchFunction function) {
    return entries
        .where((entry) => function.call(entry, advancedSearch[function]!))
        .toList();
  }

  List<OverviewEntry> searched(List<OverviewEntry> entries) {
    List<OverviewEntry> newEntries = [];

    // Basic search which often is enough.
    for (int i = 0; i < entries.length; i++) {
      bool add = false;
      for (final function in SearchFunction.values) {
        if (function.call(entries[i], simpleSearch)) {
          add = true;
          break;
        }
      }

      if (add) {
        newEntries.add(entries[i]);
      }
    }

    // Search with the expanded precision search.
    for (final function in advancedSearch.keys) {
      newEntries = advancedSearched(newEntries, function);
    }

    return newEntries;
  }
}
