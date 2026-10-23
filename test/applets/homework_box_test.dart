import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/applets/lessons/student/homework_box.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

class _WithoutChildLayout extends SingleChildRenderObjectWidget {
  const _WithoutChildLayout({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _UnlaidOutChild();
}

class _UnlaidOutChild extends RenderProxyBox {
  @override
  void performLayout() => size = constraints.smallest;

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

void main() {
  tearDown(LanisClient.reset);
  for (final layout in [false, true]) {
    testWidgets(
      'homework measurement ${layout ? 'reads a laid-out row' : 'skips a row with no layout'}',
      (tester) async {
        final box = HomeworkBox(
          courseID: 'course',
          currentEntry: CurrentEntry(
            entryID: 'entry',
            files: const [],
            uploads: const [],
            homework: Homework(
              description: 'Test homework',
              homeWorkDone: false,
            ),
          ),
        );
        await pumpTestApp(
          tester,
          child: Scaffold(body: layout ? box : _WithoutChildLayout(child: box)),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        if (layout) {
          expect(
            find.text('Test homework', findRichText: true),
            findsOneWidget,
          );
        }
      },
    );
  }
}
