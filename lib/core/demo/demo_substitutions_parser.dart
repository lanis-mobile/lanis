import 'package:lanis/applets/substitutions/parser.dart';
import 'package:lanis/models/substitution.dart';
import 'package:intl/intl.dart';

class DemoSubstitutionsParser extends SubstitutionsParser {
  DemoSubstitutionsParser(super.sph, super.appletDefinition);

  @override
  Future<SubstitutionPlan> getHome() async {
    final today = DateTime.now();
    final fmt = DateFormat('dd.MM.yyyy');
    final fmtEn = DateFormat('yyyy-MM-dd');
    final todayStr = fmt.format(today);
    final todayEnStr = fmtEn.format(today);

    final plan = SubstitutionPlan(lastUpdated: today);
    plan.add(SubstitutionDay(
      parsedDate: todayStr,
      substitutions: [
        Substitution(
          tag: todayStr,
          tag_en: todayEnStr,
          stunde: '3',
          lehrer: 'Müller',
          vertreter: 'Schmidt',
          klasse: '10a',
          fach: 'Mathematik',
          raum: '204',
          art: 'Vertretung',
          Lehrerkuerzel: 'MÜL',
          Vertreterkuerzel: 'SCH',
          lerngruppe: null,
          hervorgehoben: null,
        ),
        Substitution(
          tag: todayStr,
          tag_en: todayEnStr,
          stunde: '5',
          lehrer: 'Weber',
          vertreter: null,
          klasse: '10a',
          fach: 'Englisch',
          raum: null,
          art: 'Ausfall',
          hinweis: 'Selbststudium',
          Lehrerkuerzel: 'WEB',
          Vertreterkuerzel: null,
          lerngruppe: null,
          hervorgehoben: null,
        ),
      ],
    ));
    return plan;
  }
}
