import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiny_wins/app.dart';
import 'package:tiny_wins/core/preferences.dart';
import 'package:tiny_wins/data/database.dart';
import 'package:tiny_wins/data/habit_repository.dart';
import 'package:tiny_wins/data/providers.dart';
import 'package:tiny_wins/domain/streaks.dart';
import 'package:tiny_wins/notifications/reminder_service.dart';

/// An in-memory [HabitRepository] for widget tests and screenshots.
class FakeHabitRepository implements HabitRepository {
  final _habits = <Habit>[];
  final _completions = <Completion>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  /// Adds a habit directly, bypassing the editor.
  Habit seed(
    String name, {
    String icon = 'check',
    Color color = const Color(0xFF22A06B),
    int weekdays = everyDay,
    int startDay = 0,
    int? reminderMinutes,
    Iterable<int> completedDays = const [],
  }) {
    final habit = Habit(
      id: _nextId++,
      name: name,
      icon: icon,
      color: color.toARGB32(),
      weekdays: weekdays,
      reminderMinutes: reminderMinutes,
      startDay: startDay,
    );
    _habits.add(habit);
    _completions.addAll([
      for (final day in completedDays) Completion(habitId: habit.id, day: day),
    ]);
    _changes.add(null);
    return habit;
  }

  bool isDone(int habitId, int day) =>
      _completions.contains(Completion(habitId: habitId, day: day));

  @override
  Stream<List<Habit>> watchHabits() => _watch(() => List.of(_habits));

  @override
  Stream<List<Completion>> watchCompletions() =>
      _watch(() => _completions.toList());

  @override
  Future<Habit> addHabit(HabitDraft draft, {required int startDay}) async {
    final habit = Habit(
      id: _nextId++,
      name: draft.name,
      icon: draft.icon,
      color: draft.color,
      weekdays: draft.weekdays,
      reminderMinutes: draft.reminderMinutes,
      startDay: startDay,
    );
    _habits.add(habit);
    _changes.add(null);
    return habit;
  }

  @override
  Future<Habit> updateHabit(int id, HabitDraft draft) async {
    final index = _habits.indexWhere((h) => h.id == id);
    final habit = _habits[index].copyWith(
      name: draft.name,
      icon: draft.icon,
      color: draft.color,
      weekdays: draft.weekdays,
      reminderMinutes: Value(draft.reminderMinutes),
    );
    _habits[index] = habit;
    _changes.add(null);
    return habit;
  }

  @override
  Future<void> deleteHabit(int id) async {
    _habits.removeWhere((h) => h.id == id);
    _completions.removeWhere((c) => c.habitId == id);
    _changes.add(null);
  }

  @override
  Future<void> setCompleted(
    int habitId,
    int day, {
    required bool completed,
  }) async {
    final row = Completion(habitId: habitId, day: day);
    completed ? _completions.add(row) : _completions.remove(row);
    _changes.add(null);
  }

  Stream<T> _watch<T>(T Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<T>(
      onListen: () {
        controller.add(read());
        subscription = _changes.stream.listen((_) => controller.add(read()));
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}

/// Records calls instead of talking to the notification plugin.
class FakeReminderService implements ReminderService {
  final scheduled = <int, Habit>{};

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(Habit habit) async {
    scheduled.remove(habit.id);
    if (habit.reminderMinutes != null) scheduled[habit.id] = habit;
  }

  @override
  Future<void> cancel(int habitId) async => scheduled.remove(habitId);
}

/// The whole app wired to fakes, with "now" fixed at [now].
Future<Widget> buildTestApp({
  required FakeHabitRepository repository,
  required DateTime now,
  FakeReminderService? reminders,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues({'theme_mode': themeMode.name});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      reminderServiceProvider.overrideWithValue(
        reminders ?? FakeReminderService(),
      ),
      habitRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const TinyWinsApp(),
  );
}
