import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:tiny_wins/data/database.dart';
import 'package:tiny_wins/data/habit_repository.dart';
import 'package:tiny_wins/domain/streaks.dart';

void main() {
  setUpAll(() {
    // Windows doesn't ship sqlite3.dll, but it does ship winsqlite3.dll.
    if (Platform.isWindows) {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open('winsqlite3.dll'),
      );
    }
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late DriftHabitRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftHabitRepository(db);
  });

  tearDown(() => db.close());

  const draft = HabitDraft(
    name: 'Read',
    icon: 'book',
    color: 0xFF22A06B,
    weekdays: everyDay,
  );

  test('adds a habit and emits it', () async {
    final habit = await repository.addHabit(draft, startDay: 100);

    expect(habit.id, isPositive);
    expect(habit.startDay, 100);
    expect(habit.reminderMinutes, isNull);
    expect(await repository.watchHabits().first, [habit]);
  });

  test('updates fields but keeps the start day', () async {
    final habit = await repository.addHabit(draft, startDay: 100);

    final updated = await repository.updateHabit(
      habit.id,
      const HabitDraft(
        name: 'Read 20 pages',
        icon: 'book',
        color: 0xFF0EA5E9,
        weekdays: weekdaysOnly,
        reminderMinutes: 8 * 60,
      ),
    );

    expect(updated.name, 'Read 20 pages');
    expect(updated.weekdays, weekdaysOnly);
    expect(updated.reminderMinutes, 480);
    expect(updated.startDay, 100);
  });

  test('marking a day done twice keeps one row', () async {
    final habit = await repository.addHabit(draft, startDay: 100);

    await repository.setCompleted(habit.id, 101, completed: true);
    await repository.setCompleted(habit.id, 101, completed: true);
    await repository.setCompleted(habit.id, 102, completed: true);

    expect(await repository.watchCompletions().first, hasLength(2));

    await repository.setCompleted(habit.id, 101, completed: false);
    final rows = await repository.watchCompletions().first;
    expect(rows.map((c) => c.day), [102]);
  });

  test('deleting a habit deletes its history', () async {
    final keep = await repository.addHabit(draft, startDay: 100);
    final remove = await repository.addHabit(draft, startDay: 100);
    await repository.setCompleted(keep.id, 101, completed: true);
    await repository.setCompleted(remove.id, 101, completed: true);

    await repository.deleteHabit(remove.id);

    expect(await repository.watchHabits().first, [keep]);
    final rows = await repository.watchCompletions().first;
    expect(rows.map((c) => c.habitId), [keep.id]);
  });
}
