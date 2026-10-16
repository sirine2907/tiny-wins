import 'package:flutter/material.dart';

import '../domain/streaks.dart';

const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Every day", "Weekdays", "Weekends" or a list like "Mon, Wed, Fri".
String describeWeekdays(int weekdays) {
  if (weekdays == everyDay) return 'Every day';
  if (weekdays == weekdaysOnly) return 'Weekdays';
  if (weekdays == weekendsOnly) return 'Weekends';
  return [
    for (var i = 0; i < 7; i++)
      if (weekdays & (1 << i) != 0) weekdayShortNames[i],
  ].join(', ');
}

TimeOfDay timeOfMinutes(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

int minutesOfTime(TimeOfDay time) => time.hour * 60 + time.minute;
