import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/substitutions/substitutions_listtile.dart';

import '../helpers/test_app.dart';

Substitution _sub({
  String? klasse,
  String? klasseAlt,
  String? fach,
  String? fachAlt,
  String? raum,
  String? raumAlt,
  String? vertreter,
  String? lehrer,
  String? hinweis,
  String? art,
  String stunde = '1',
}) {
  return Substitution(
    tag: '11.08.2026',
    tag_en: '2026-08-11',
    stunde: stunde,
    klasse: klasse,
    klasse_alt: klasseAlt,
    fach: fach,
    fach_alt: fachAlt,
    raum: raum,
    raum_alt: raumAlt,
    vertreter: vertreter,
    lehrer: lehrer,
    hinweis: hinweis,
    art: art,
  );
}

Future<void> _pumpTile(WidgetTester tester, Substitution sub) async {
  await pumpTestApp(
    tester,
    child: Scaffold(body: SubstitutionListTile(substitutionData: sub)),
  );
}

/// MarqueeWidget schedules pause timers; dispose + advance time to clear them.
Future<void> _drainMarquee(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Cover pauseDuration (800ms) after dispose sets _active=false.
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  tearDown(LanisClient.reset);

  testWidgets(
    'klasse_alt fallback renders alt class and help icon without crashing',
    (tester) async {
      await _pumpTile(
        tester,
        _sub(klasse: null, klasseAlt: '7a', fach: 'M', art: 'Vertretung'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('7a'), findsOneWidget);
      expect(find.byIcon(Icons.help_outline_outlined), findsWidgets);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('Vertretung'), findsOneWidget);
      await _drainMarquee(tester);
    },
  );

  testWidgets('blank klasse placeholders ("-") fall back to klasse_alt', (
    tester,
  ) async {
    await _pumpTile(tester, _sub(klasse: '-', klasseAlt: 'Q1', fach: 'D'));

    expect(tester.takeException(), isNull);
    expect(find.text('Q1'), findsOneWidget);
    expect(find.text('-'), findsNothing);
    await _drainMarquee(tester);
  });

  testWidgets('blank klasse "---" and " " fall back to klasse_alt', (
    tester,
  ) async {
    for (final blank in ['---', ' ']) {
      await _pumpTile(tester, _sub(klasse: blank, klasseAlt: '8b', fach: 'E'));
      expect(tester.takeException(), isNull);
      expect(find.text('8b'), findsOneWidget);
      await _drainMarquee(tester);
    }
  });

  testWidgets('prefers klasse over klasse_alt when both present', (tester) async {
    await _pumpTile(tester, _sub(klasse: '9c', klasseAlt: 'alt', fach: 'M'));

    expect(find.text('9c'), findsOneWidget);
    expect(find.text('alt'), findsNothing);
    await _drainMarquee(tester);
  });

  testWidgets('omits class row when klasse and klasse_alt are blank', (
    tester,
  ) async {
    await _pumpTile(tester, _sub(klasse: null, klasseAlt: '-', fach: 'M'));

    expect(tester.takeException(), isNull);
    expect(find.text('M'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline_outlined), findsNothing);
    await _drainMarquee(tester);
  });

  testWidgets('fach_alt fallback and raum_alt info render', (tester) async {
    await _pumpTile(
      tester,
      _sub(
        fach: null,
        fachAlt: 'Bio',
        raum: '-',
        raumAlt: 'R101',
        art: 'Raumänderung',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Bio'), findsOneWidget);
    expect(find.text('Raum'), findsOneWidget);
    expect(find.text('R101', findRichText: true), findsOneWidget);
    await _drainMarquee(tester);
  });

  testWidgets('hinweis-only and art-null tiles still build', (tester) async {
    await _pumpTile(
      tester,
      _sub(
        art: null,
        hinweis: 'Bitte im Lehrerzimmer melden',
        stunde: '3 - 4',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Bitte im Lehrerzimmer melden'), findsOneWidget);
    expect(find.text('3 - 4'), findsOneWidget);
    await _drainMarquee(tester);
  });

  test('primaryOrAlt unit matrix covers blank placeholders', () {
    final tile = SubstitutionListTile(substitutionData: _sub());
    expect(tile.primaryOrAlt(null, '7a'), '7a');
    expect(tile.primaryOrAlt('-', '7a'), '7a');
    expect(tile.primaryOrAlt('---', '7a'), '7a');
    expect(tile.primaryOrAlt(' ', '7a'), '7a');
    expect(tile.primaryOrAlt('', '7a'), '7a');
    expect(tile.primaryOrAlt('9a', '7a'), '9a');
    expect(tile.primaryOrAlt(null, null), isNull);
    expect(tile.primaryOrAlt('-', '---'), isNull);
  });
}
