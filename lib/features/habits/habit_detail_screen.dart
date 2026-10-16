import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/day.dart';
import '../../core/formatting.dart';
import '../../core/habit_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../widgets/simple_bar_chart.dart';
import 'habit_editor_screen.dart';
import 'widgets/habit_heatmap.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = ref
        .watch(habitsProvider)
        .value
        ?.where((h) => h.id == habitId)
        .firstOrNull;
    // Briefly null while the habit is being deleted.
    if (habit == null) return Scaffold(appBar: AppBar());

    final theme = Theme.of(context);
    final color = Color(habit.color);
    final today = ref.watch(todayProvider);
    final stats = ref.watch(habitStatsProvider(habit));
    final done = ref.watch(completionsProvider).value?[habit.id] ?? const {};

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Edit habit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => openHabitEditor(context, habit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Header(habit: habit, color: color),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: AppColors.flame,
                value: '${stats.currentStreak}',
                label: 'Current streak',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.emoji_events_rounded,
                iconColor: color,
                value: '${stats.bestStreak}',
                label: 'Best streak',
              ),
              const SizedBox(width: 10),
              _StatCard(
                icon: Icons.donut_large_rounded,
                iconColor: theme.colorScheme.primary,
                value: '${(stats.completionRate * 100).round()}%',
                label: '30-day rate',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'History',
            subtitle: 'Tap a day to fix a missed check-in.',
            child: HabitHeatmap(
              color: color,
              weekdays: habit.weekdays,
              startDay: habit.startDay,
              completedDays: done,
              today: today,
              onToggle: (day) => ref
                  .read(habitRepositoryProvider)
                  .setCompleted(habit.id, day, completed: !done.contains(day)),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Weekly wins',
            subtitle: '${stats.totalCompletions} tiny wins so far',
            child: SimpleBarChart(
              color: color,
              maxY: _popCount(habit.weekdays),
              entries: _weeklyCounts(done, today),
            ),
          ),
        ],
      ),
    );
  }

  /// Completions per week (Monday to Sunday) for the last eight weeks.
  static List<(String, int)> _weeklyCounts(Set<int> done, int today) {
    final thisMonday = today - (weekdayOfDayKey(today) - 1);
    final format = DateFormat.MMMd();
    return [
      for (var w = 7; w >= 0; w--)
        (
          w == 0 ? 'This wk' : format.format(dateOfDayKey(thisMonday - 7 * w)),
          [
            for (var d = 0; d < 7; d++) thisMonday - 7 * w + d,
          ].where(done.contains).length,
        ),
    ];
  }

  static int _popCount(int bits) {
    var count = 0;
    for (var i = 0; i < 7; i++) {
      if (bits & (1 << i) != 0) count++;
    }
    return count;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.habit, required this.color});

  final Habit habit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final reminder = habit.reminderMinutes;

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(habitIcon(habit.icon), color: color, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                children: [
                  _IconText(
                    icon: Icons.repeat_rounded,
                    text: describeWeekdays(habit.weekdays),
                    style: muted,
                  ),
                  if (reminder != null)
                    _IconText(
                      icon: Icons.notifications_none_rounded,
                      text: timeOfMinutes(reminder).format(context),
                      style: muted,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: style?.color),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

Future<void> openHabitDetail(BuildContext context, Habit habit) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id)),
  );
}
