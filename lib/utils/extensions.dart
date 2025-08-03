import 'package:flutter/material.dart';

extension ParsableTimeOfDay on TimeOfDay {
  double toTimeDouble() => hour + minute / 60.0;

  TimeOfDay ceil() {
    if (minute > 0) {
      return TimeOfDay(hour: hour + 1, minute: 0);
    }
    return this;
  }

  TimeOfDay floor() {
    return TimeOfDay(hour: hour, minute: 0);
  }
}

extension TimeOfDayExtension on TimeOfDay {
  int differenceInMinutes(TimeOfDay other) {
    return (other.hour - hour) * 60 + other.minute - minute;
  }

  operator <=(TimeOfDay other) {
    return hour < other.hour || (hour == other.hour && minute <= other.minute);
  }

  operator >=(TimeOfDay other) {
    return hour > other.hour || (hour == other.hour && minute >= other.minute);
  }

  operator >(TimeOfDay other) {
    return hour > other.hour || (hour == other.hour && minute > other.minute);
  }

  operator <(TimeOfDay other) {
    return hour < other.hour || (hour == other.hour && minute < other.minute);
  }
}
