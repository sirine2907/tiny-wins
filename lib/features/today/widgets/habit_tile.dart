import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/habit_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';

class HabitTile extends ConsumerWidget {
  const HabitTile({
    super.key,
    required this.habit,
    this.dayOff = false,
    this.onTap,
  });

  final Habit habit;

  /// The habit isn't scheduled today: it's shown dimmed with no check button.
  final bool dayOff;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(habit.color);
    final today = ref.watch(todayProvider);
    final done = (ref.watch(completionsProvider).value ?? const {}).isDone(
      habit.id,
      today,
    );
    final streak = ref.watch(habitStatsProvider(habit)).currentStreak;

    return Opacity(
      opacity: dayOff ? 0.55 : 1,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.16),
                  child: Icon(habitIcon(habit.icon), color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _StreakLabel(streak: streak, dayOff: dayOff),
                    ],
                  ),
                ),
                if (!dayOff)
                  _CheckButton(
                    done: done,
                    color: color,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(habitRepositoryProvider)
                          .setCompleted(habit.id, today, completed: !done);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakLabel extends StatelessWidget {
  const _StreakLabel({required this.streak, required this.dayOff});

  final int streak;
  final bool dayOff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (dayOff) return Text('Day off', style: muted);
    if (streak == 0) return Text('Start a streak today', style: muted);

    return Row(
      children: [
        const Icon(
          Icons.local_fire_department_rounded,
          size: 18,
          color: AppColors.flame,
        ),
        const SizedBox(width: 2),
        Text('$streak day streak', style: muted),
      ],
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.done,
    required this.color,
    required this.onPressed,
  });

  final bool done;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;

    return Semantics(
      button: true,
      checked: done,
      label: done ? 'Mark as not done' : 'Mark as done',
      child: InkResponse(
        onTap: onPressed,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? color : Colors.transparent,
              border: Border.all(color: done ? color : outline, width: 2.5),
            ),
            child: AnimatedScale(
              scale: done ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
