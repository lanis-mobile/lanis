import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';

extension SphTimeOfDayUi on SphTimeOfDay {
  TimeOfDay toFlutter() => TimeOfDay(hour: hour, minute: minute);
}

extension TimeOfDayLiblanis on TimeOfDay {
  SphTimeOfDay toSph() => SphTimeOfDay(hour: hour, minute: minute);
}

Color colorFromArgb(int argb) => Color(argb);

int colorToArgb(Color color) => color.toARGB32();
