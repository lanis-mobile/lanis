import 'package:lanis/applets/conversations/parser.dart';
import 'package:lanis/core/demo/demo_fetch_mixin.dart';
import 'package:lanis/models/conversations.dart';

class DemoConversationsParser extends ConversationsParser with DemoFetchMixin<List<OverviewEntry>> {
  DemoConversationsParser(super.sph, super.appletDefinition);

  @override
  Future<List<OverviewEntry>> getHome() async {
    return const [
      OverviewEntry(
        id: 'demo-conv-1',
        title: 'Klassenfahrt: Wichtige Infos',
        shortName: 'BRA',
        fullName: 'Herr Brandt',
        date: '03.06.2026',
        unread: true,
        hidden: false,
      ),
      OverviewEntry(
        id: 'demo-conv-2',
        title: 'Informationen zum Schuljahresabschluss',
        shortName: 'SL',
        fullName: 'Schulleitung',
        date: '01.06.2026',
        unread: false,
        hidden: false,
      ),
    ];
  }
}
