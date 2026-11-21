import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/conversations/routes.dart';
import '../helpers/test_app.dart';

class _Context implements AppletContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Parser extends ConversationsParser {
  final response = Completer<Conversation>();
  _Parser() : super(_Context(), isConnected: () async => true);
  @override
  Future<Conversation> getSingleConversation(String id) => response.future;
}

void main() {
  tearDown(LanisClient.reset);
  testWidgets(
    'message receivers keep the header during loading and offline failure',
    (tester) async {
      final parser = _Parser();
      addTearDown(parser.dispose);
      await pumpTestApp(
        tester,
        overrides: [conversationsParserProvider.overrideWithValue(parser)],
        child: const ConversationStatsPage(
          id: 'test',
          title: 'Test conversation',
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Receivers'),
        ),
        findsOneWidget,
      );
      parser.response.completeError(NoConnectionException());
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Receivers'),
        ),
        findsOneWidget,
      );
      expect(find.text('No internet connection!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
