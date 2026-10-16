import 'package:drift/drift.dart';

import 'database.dart';

/// The editable fields of a habit, used for both creating and updating.
class HabitDraft {
  const HabitDraft({
    required this.name,
    required this.icon,
    required this.color,
    required this.weekdays,
    this.reminderMinutes,
  });

  final String name;
  final String icon;
  final int color;
  final int weekdays;
  final int? reminderMinutes;
}

abstract interface class HabitRepository {
  Stream<List<Habit>> watchHabits();
  Stream<List<Completion>> watchCompletions();

  /// Creates a habit and returns it with its new id.
  Future<Habit> addHabit(HabitDraft draft, {required int startDay});
  Future<Habit> updateHabit(int id, HabitDraft draft);
  Future<void> deleteHabit(int id);
  Future<void> setCompleted(int habitId, int day, {required bool completed});
}

class DriftHabitRepository implements HabitRepository {
  DriftHabitRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Habit>> watchHabits() => (_db.select(
    _db.habits,
  )..orderBy([(h) => OrderingTerm.asc(h.id)])).watch();

  @override
  Stream<List<Completion>> watchCompletions() =>
      _db.select(_db.completions).watch();

  @override
  Future<Habit> addHabit(HabitDraft draft, {required int startDay}) {
    return _db
        .into(_db.habits)
        .insertReturning(_companion(draft).copyWith(startDay: Value(startDay)));
  }

  @override
  Future<Habit> updateHabit(int id, HabitDraft draft) async {
    final updated = await (_db.update(
      _db.habits,
    )..where((h) => h.id.equals(id))).writeReturning(_companion(draft));
    return updated.single;
  }

  @override
  Future<void> deleteHabit(int id) =>
      (_db.delete(_db.habits)..where((h) => h.id.equals(id))).go();

  @override
  Future<void> setCompleted(
    int habitId,
    int day, {
    required bool completed,
  }) async {
    if (completed) {
      await _db
          .into(_db.completions)
          .insertOnConflictUpdate(
            CompletionsCompanion.insert(habitId: habitId, day: day),
          );
    } else {
      await (_db.delete(
        _db.completions,
      )..where((c) => c.habitId.equals(habitId) & c.day.equals(day))).go();
    }
  }

  HabitsCompanion _companion(HabitDraft draft) => HabitsCompanion(
    name: Value(draft.name),
    icon: Value(draft.icon),
    color: Value(draft.color),
    weekdays: Value(draft.weekdays),
    reminderMinutes: Value(draft.reminderMinutes),
  );
}
