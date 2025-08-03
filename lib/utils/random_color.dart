import 'dart:math';

import 'package:flutter/material.dart';

class RandomColor {
  static Color random({int alpha = 255}) {
    final random = Random();
    return Color.fromARGB(
        alpha, random.nextInt(255), random.nextInt(255), random.nextInt(255));
  }

  static ColorPair bySeed(String seed) {
    final int hash = seed.hashCode;
    final int r = (hash & 0xFF0000) >> 16;
    final int g = (hash & 0x00FF00) >> 8;
    final int b = (hash & 0x0000FF);
    return ColorPair(Color.fromARGB(255, r, g, b));
  }

  /// Generate a color based on the input string and a start color
  static Color byStringAndColor(String input, Color startColor) {
    final hash = input.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;

    final startR = startColor.r;
    final startG = startColor.g;
    final startB = startColor.b;

    // Calculate the new color values based on the start color and the hash values
    final newR = ((startR + r) / 2).round();
    final newG = ((startG + g) / 2).round();
    final newB = ((startB + b) / 2).round();

    return Color.fromARGB(255, newR, newG, newB);
  }
}

class ColorPair {
  final Color primary;
  Color get secondary =>
      primary.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  Color get inversePrimary => Color.fromARGB(255, 255 - primary.r.toInt(),
          255 - primary.g.toInt(), 255 - primary.b.toInt())
      .withValues(alpha: 0.75);

  ColorPair(this.primary);
}
