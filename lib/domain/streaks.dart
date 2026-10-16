import 'dart:math';

import '../core/day.dart';

const everyDay = 0x7f;
const weekdaysOnly = 0x1f;
const weekendsOnly = 0x60;

/// Whether a habit with the [weekdays] bitmask is due on [dayKey].
bool isScheduledOn(int weekdays, int dayKey) =>
    weekdays & (1 << (weekdayOfDayKey(dayKey) - 1)) != 0;

class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate,
    required this.totalCompletions,
  });

  static const empty = HabitStats(
    currentStreak: 0,
    bestStreak: 0,
    completionRate: 0,
    totalCompletions: 0,
  );

  /// Scheduled days completed in a row, ending today (or yesterday if today
  /// isn't done yet).
  final int currentStreak;
  final int bestStreak;

  /// Share of scheduled days completed in the last [rateWindow] days, 0 to 1.
  final double completionRate;
  final int totalCompletions;
}

/// Calculates streaks for one habit.
///
/// The rules:
/// * Only scheduled days count. A day off neither breaks nor extends a
///   streak, and a completion on a day off is ignored.
/// * Today never breaks a streak: until it is done it is still in progress.
/// * Nothing before [startDay] (or the first completion, if earlier) counts.
HabitStats calculateStats({
  required int weekdays,
  required int startDay,
  required Set<int> completedDays,
  required int today,
  int rateWindow = 30,
}) {
  final first = completedDays.isEmpty
      ? startDay
      : min(startDay, completedDays.reduce(min));

  var current = 0;
  for (var day = today; day >= first; day--) {
    if (!isScheduledOn(weekdays, day)) continue;
    if (completedDays.contains(day)) {
      current++;
    } else if (day != today) {
      break;
    }
  }

  var best = 0;
  var run = 0;
  for (var day = first; day <= today; day++) {
    if (!isScheduledOn(weekdays, day)) continue;
    if (completedDays.contains(day)) {
      run++;
      best = max(best, run);
    } else if (day != today) {
      run = 0;
    }
  }

  var due = 0;
  var done = 0;
  for (var day = max(first, today - rateWindow + 1); day <= today; day++) {
    if (!isScheduledOn(weekdays, day)) continue;
    if (completedDays.contains(day)) {
      due++;
      done++;
    } else if (day != today) {
      due++;
    }
  }

  return HabitStats(
    currentStreak: current,
    bestStreak: best,
    completionRate: due == 0 ? 0 : done / due,
    totalCompletions: completedDays.length,
  );
}
