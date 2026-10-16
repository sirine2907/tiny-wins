import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/day.dart';
import '../../core/habit_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../domain/streaks.dart';
import '../../widgets/section_card.dart';
import '../../widgets/simple_bar_chart.dart';
import '../../widgets/stat_card.dart';
import '../habits/habit_detail_screen.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider).value ?? const <Habit>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: habits.isEmpty
          ? Center(
              child: Text(
                'Add a habit to see your stats.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : _StatsBody(habits: habits),
    );
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.habits});

  final List<Habit> habits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = ref.watch(todayProvider);
    final completions = ref.watch(completionsProvider).value ?? const {};
    final stats = {for (final h in habits) h: ref.watch(habitStatsProvider(h))};

    final dueToday = habits.where((h) => isScheduledOn(h.weekdays, today));
    final doneToday = dueToday.where((h) => completions.isDone(h.id, today));

    final thisMonday = today - (weekdayOfDayKey(today) - 1);
    var weekWins = 0;
    for (final h in habits) {
      for (var day = thisMonday; day <= today; day++) {
        if (completions.isDone(h.id, day)) weekWins++;
      }
    }

    // Habits created today have nothing to measure yet.
    final rated = habits.where((h) => h.startDay < today).toList();
    final averageRate = rated.isEmpty
        ? null
        : rated.map((h) => stats[h]!.completionRate).reduce((a, b) => a + b) /
              rated.length;

    final leaders = [...habits]
      ..sort((a, b) {
        final byCurrent = stats[b]!.currentStreak.compareTo(
          stats[a]!.currentStreak,
        );
        return byCurrent != 0
            ? byCurrent
            : stats[b]!.bestStreak.compareTo(stats[a]!.bestStreak);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                icon: Icons.today_rounded,
                iconColor: theme.colorScheme.primary,
                value: '${doneToday.length}/${dueToday.length}',
                label: 'Done today',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.bolt_rounded,
                iconColor: AppColors.flame,
                value: '$weekWins',
                label: 'Wins this week',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatCard(
                icon: Icons.donut_large_rounded,
                iconColor: theme.colorScheme.tertiary,
                value: averageRate == null
                    ? '–'
                    : '${(averageRate * 100).round()}%',
                label: '30-day rate',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Last 7 days',
          subtitle: 'Habits completed each day',
          child: SimpleBarChart(
            color: theme.colorScheme.primary,
            maxY: _mostDueInADay(habits, today),
            entries: [
              for (var day = today - 6; day <= today; day++)
                (
                  DateFormat.E().format(dateOfDayKey(day)),
                  habits.where((h) => completions.isDone(h.id, day)).length,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Streaks',
          subtitle: 'Longest running first',
          child: Column(
            children: [
              for (final habit in leaders)
                _StreakRow(habit: habit, stats: stats[habit]!),
            ],
          ),
        ),
      ],
    );
  }

  static int _mostDueInADay(List<Habit> habits, int today) {
    var most = 1;
    for (var day = today - 6; day <= today; day++) {
      final due = habits.where((h) => isScheduledOn(h.weekdays, day)).length;
      if (due > most) most = due;
    }
    return most;
  }
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.habit, required this.stats});

  final Habit habit;
  final HabitStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(habit.color);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => openHabitDetail(context, habit),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Icon(habitIcon(habit.icon), color: color, size: 20),
      ),
      title: Text(habit.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('Best: ${stats.bestStreak} days'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.flame,
          ),
          const SizedBox(width: 4),
          Text(
            '${stats.currentStreak}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
