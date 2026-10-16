import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../domain/streaks.dart';
import 'database.dart';
import 'habit_repository.dart';

/// Overridden in tests to pin "now" to a fixed date.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Today's day key. Invalidated when the app resumes so it rolls over at
/// midnight.
final todayProvider = Provider<int>(
  (ref) => dayKeyOf(ref.watch(clockProvider)()),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final habitRepositoryProvider = Provider<HabitRepository>(
  (ref) => DriftHabitRepository(ref.watch(databaseProvider)),
);

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(habitRepositoryProvider).watchHabits(),
);

/// Completed day keys, grouped by habit id.
final completionsProvider = StreamProvider<Map<int, Set<int>>>((ref) {
  return ref.watch(habitRepositoryProvider).watchCompletions().map((rows) {
    final byHabit = <int, Set<int>>{};
    for (final row in rows) {
      byHabit.putIfAbsent(row.habitId, () => {}).add(row.day);
    }
    return byHabit;
  });
});

final habitStatsProvider = Provider.family<HabitStats, Habit>((ref, habit) {
  final done = ref.watch(completionsProvider).value?[habit.id] ?? const {};
  return calculateStats(
    weekdays: habit.weekdays,
    startDay: habit.startDay,
    completedDays: done,
    today: ref.watch(todayProvider),
  );
});

extension CompletionLookup on Map<int, Set<int>> {
  bool isDone(int habitId, int day) => this[habitId]?.contains(day) ?? false;
}
