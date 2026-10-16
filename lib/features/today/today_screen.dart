import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/day.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/streaks.dart';
import '../habits/habit_detail_screen.dart';
import '../habits/habit_editor_screen.dart';
import 'widgets/habit_tile.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final habits = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMMM d').format(dateOfDayKey(today)),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Today',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: habits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Something went wrong.\n$error')),
        data: (habits) => habits.isEmpty
            ? const _EmptyState()
            : _HabitList(habits: habits, today: today),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openHabitEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('New habit'),
      ),
    );
  }
}

class _HabitList extends ConsumerWidget {
  const _HabitList({required this.habits, required this.today});

  final List<Habit> habits;
  final int today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completions = ref.watch(completionsProvider).value ?? const {};
    final due = [
      for (final h in habits)
        if (isScheduledOn(h.weekdays, today)) h,
    ];
    final dayOff = [
      for (final h in habits)
        if (!isScheduledOn(h.weekdays, today)) h,
    ];
    final doneCount = due.where((h) => completions.isDone(h.id, today)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        _ProgressCard(done: doneCount, total: due.length),
        if (due.isNotEmpty) ...[
          const _SectionTitle('Due today'),
          for (final habit in due)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HabitTile(
                habit: habit,
                onTap: () => openHabitDetail(context, habit),
              ),
            ),
        ],
        if (dayOff.isNotEmpty) ...[
          const _SectionTitle('Not today'),
          for (final habit in dayOff)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HabitTile(
                habit: habit,
                dayOff: true,
                onTap: () => openHabitDetail(context, habit),
              ),
            ),
        ],
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});

  final int done;
  final int total;

  String get _message {
    if (total == 0) return 'Nothing due today. Enjoy the rest.';
    if (done == 0) return 'Start with the easiest one.';
    if (done < total) return 'Keep going, every tiny win counts.';
    return "All done. That's a win!";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = total == 0 ? 0.0 : done / total;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: scheme.primary,
                      backgroundColor: scheme.onPrimaryContainer.withValues(
                        alpha: 0.12,
                      ),
                    ),
                    Center(
                      child: Text(
                        '${(value * 100).round()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$done of $total done',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Start with one tiny habit',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick something so small you can do it on your worst day. '
              'Two minutes of reading counts.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
