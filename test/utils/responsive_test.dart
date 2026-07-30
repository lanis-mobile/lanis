import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/responsive.dart';

void main() {
  testWidgets('phone width is not tablet', (tester) async {
    late bool tablet;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Builder(
          builder: (context) {
            tablet = Responsive.isTablet(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tablet, isFalse);
  });

  testWidgets('width above 600 is tablet', (tester) async {
    late bool tablet;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: Builder(
          builder: (context) {
            tablet = Responsive.isTablet(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tablet, isTrue);
  });

  testWidgets('exactly 600 is phone', (tester) async {
    late bool tablet;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(600, 800)),
        child: Builder(
          builder: (context) {
            tablet = Responsive.isTablet(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tablet, isFalse);
  });

  testWidgets('exactly 780 is not conversations split', (tester) async {
    late bool split;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(780, 600)),
        child: Builder(
          builder: (context) {
            split = Responsive.isConversationsSplit(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(split, isFalse);
  });

  testWidgets('width above 780 is conversations split', (tester) async {
    late bool split;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(781, 600)),
        child: Builder(
          builder: (context) {
            split = Responsive.isConversationsSplit(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(split, isTrue);
  });

  testWidgets('mid-band is tablet but not conversations split', (tester) async {
    late bool tablet;
    late bool split;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(700, 600)),
        child: Builder(
          builder: (context) {
            tablet = Responsive.isTablet(context);
            split = Responsive.isConversationsSplit(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tablet, isTrue);
    expect(split, isFalse);
  });
}
