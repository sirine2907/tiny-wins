import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

@DataClassName('Habit')
class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get icon => text().withDefault(const Constant('check'))();
  IntColumn get color => integer()();

  /// Bit `n` set means the habit is scheduled on ISO weekday `n + 1`
  /// (bit 0 is Monday). `0x7f` is every day.
  IntColumn get weekdays => integer().withDefault(const Constant(0x7f))();

  /// Minutes after midnight for the daily reminder, or null for none.
  IntColumn get reminderMinutes => integer().nullable()();

  /// Day key of the day the habit was created. Streaks never look further
  /// back than this.
  IntColumn get startDay => integer()();
}

@DataClassName('Completion')
class Completions extends Table {
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  IntColumn get day => integer()();

  @override
  Set<Column<Object>> get primaryKey => {habitId, day};
}

@DriftDatabase(tables: [Habits, Completions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'tiny_wins'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
