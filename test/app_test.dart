import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_wins/core/day.dart';
import 'package:tiny_wins/domain/streaks.dart';

import 'support/fakes.dart';

void main() {
  // Friday 16 October 2026, mid-morning.
  final now = DateTime(2026, 10, 16, 9, 30);
  final today = dayKeyOf(now);

  late FakeHabitRepository repository;
  late FakeReminderService reminders;

  setUp(() {
    repository = FakeHabitRepository();
    reminders = FakeReminderService();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      await buildTestApp(
        repository: repository,
        reminders: reminders,
        now: now,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state with no habits', (tester) async {
    await pumpApp(tester);

    expect(find.text('Start with one tiny habit'), findsOneWidget);
    expect(find.text('New habit'), findsOneWidget);
  });

  testWidgets('splits habits into due today and not today', (tester) async {
    repository
      ..seed('Read 10 pages', startDay: today - 10)
      ..seed('Long run', weekdays: weekendsOnly, startDay: today - 10);
    await pumpApp(tester);

    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Not today'), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(find.text('Day off'), findsOneWidget);
  });

  testWidgets('checking a habit off updates progress and streak', (
    tester,
  ) async {
    final habit = repository.seed(
      'Drink water',
      startDay: today - 10,
      completedDays: [today - 2, today - 1],
    );
    await pumpApp(tester);

    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(find.text('2 day streak'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Mark as done'));
    await tester.pumpAndSettle();
    semantics.dispose();

    expect(repository.isDone(habit.id, today), isTrue);
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(find.text('3 day streak'), findsOneWidget);
    expect(find.text("All done. That's a win!"), findsOneWidget);
  });

  testWidgets('creates a habit with a reminder', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('New habit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Stretch');
    await tester.tap(find.text('Weekdays'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add habit'));
    await tester.pumpAndSettle();

    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Start a streak today'), findsOneWidget);
    // No reminder was switched on, so nothing is scheduled.
    expect(reminders.scheduled, isEmpty);
  });

  testWidgets('cannot save a habit without a name', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('New habit'));
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add habit'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('detail screen shows streak stats', (tester) async {
    repository.seed(
      'Meditate',
      icon: 'meditate',
      startDay: today - 20,
      completedDays: [
        for (var d = 1; d <= 4; d++) today - d,
        for (var d = 8; d <= 15; d++) today - d,
      ],
    );
    await pumpApp(tester);

    await tester.tap(find.text('Meditate'));
    await tester.pumpAndSettle();

    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('12 tiny wins so far'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('12 tiny wins so far'), findsOneWidget);
  });

  testWidgets('deleting a habit returns to Today and cancels reminders', (
    tester,
  ) async {
    final habit = repository.seed(
      'Journal',
      startDay: today - 3,
      reminderMinutes: 21 * 60,
    );
    reminders.scheduled[habit.id] = habit;
    await pumpApp(tester);

    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Start with one tiny habit'), findsOneWidget);
    expect(reminders.scheduled, isEmpty);
  });

  testWidgets('stats tab ranks habits by current streak', (tester) async {
    repository
      ..seed('Short', startDay: today - 10, completedDays: [today - 1])
      ..seed(
        'Long',
        startDay: today - 10,
        completedDays: [for (var d = 1; d <= 6; d++) today - d],
      );
    await pumpApp(tester);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    final long = tester.getTopLeft(find.text('Long').last);
    final short = tester.getTopLeft(find.text('Short').last);
    expect(long.dy, lessThan(short.dy));
    expect(find.text('0/2'), findsOneWidget);
  });
}
