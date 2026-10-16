import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_wins/core/day.dart';
import 'package:tiny_wins/domain/streaks.dart';

void main() {
  // Friday 16 October 2026.
  final today = dayKeyOf(DateTime(2026, 10, 16));

  Set<int> daysAgo(Iterable<int> offsets) => {for (final o in offsets) today - o};

  HabitStats stats(
    Set<int> done, {
    int weekdays = everyDay,
    int startDay = -1,
  }) => calculateStats(
    weekdays: weekdays,
    startDay: startDay == -1 ? today - 60 : startDay,
    completedDays: done,
    today: today,
  );

  group('day keys', () {
    test('round-trip a local date', () {
      final date = DateTime(2026, 3, 29);
      expect(dateOfDayKey(dayKeyOf(date)), date);
    });

    test('know the weekday', () {
      expect(weekdayOfDayKey(today), DateTime.friday);
      expect(weekdayOfDayKey(today + 1), DateTime.saturday);
      expect(weekdayOfDayKey(today + 3), DateTime.monday);
    });
  });

  group('current streak', () {
    test('is zero with no completions', () {
      expect(stats({}).currentStreak, 0);
    });

    test('counts consecutive days ending today', () {
      expect(stats(daysAgo([0, 1, 2])).currentStreak, 3);
    });

    test('is not broken by an unfinished today', () {
      expect(stats(daysAgo([1, 2, 3, 4])).currentStreak, 4);
    });

    test('is broken by a missed day', () {
      expect(stats(daysAgo([0, 1, 3, 4, 5])).currentStreak, 2);
    });

    test('skips days the habit is not scheduled', () {
      // Weekdays only: last Saturday and Sunday don't break the run from
      // Thursday last week to today.
      final done = daysAgo([0, 1, 2, 3, 4, 7, 8]);
      expect(stats(done, weekdays: weekdaysOnly).currentStreak, 7);
      expect(stats(done).currentStreak, 5);
    });

    test('ignores completions on days off', () {
      final saturday = today - 6;
      expect(stats({saturday}, weekdays: weekdaysOnly).currentStreak, 0);
    });
  });

  group('best streak', () {
    test('finds the longest run in history', () {
      final done = {...daysAgo([0, 1]), ...daysAgo([10, 11, 12, 13, 14])};
      final result = stats(done);
      expect(result.currentStreak, 2);
      expect(result.bestStreak, 5);
    });

    test('includes the current run', () {
      expect(stats(daysAgo([0, 1, 2, 3, 5, 6])).bestStreak, 4);
    });
  });

  group('completion rate', () {
    test('does not count today against you before it is done', () {
      final result = stats(daysAgo([1, 2]), startDay: today - 3);
      // Due: 3 days ago, 2 days ago, yesterday. Done: 2 of them.
      expect(result.completionRate, closeTo(2 / 3, 0.001));
    });

    test('is 1 when every due day is done', () {
      expect(stats(daysAgo([0, 1]), startDay: today - 1).completionRate, 1);
    });

    test('is 0 for a habit created today', () {
      expect(stats({}, startDay: today).completionRate, 0);
    });

    test('only looks at the last 30 days', () {
      final result = calculateStats(
        weekdays: everyDay,
        startDay: today - 100,
        completedDays: {for (var i = 1; i <= 15; i++) today - i},
        today: today,
      );
      // 29 due days in the window (today excluded), 15 done.
      expect(result.completionRate, closeTo(15 / 29, 0.001));
      expect(result.totalCompletions, 15);
    });
  });
}
