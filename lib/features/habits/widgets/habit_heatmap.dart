import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/day.dart';
import '../../../domain/streaks.dart';

/// A GitHub-style grid of the last [weeks] weeks: one column per week
/// (Monday at the top), one cell per day. Tapping a past day toggles it, so
/// a forgotten check-in can be fixed.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.color,
    required this.weekdays,
    required this.startDay,
    required this.completedDays,
    required this.today,
    required this.onToggle,
    this.weeks = 16,
  });

  final Color color;
  final int weekdays;
  final int startDay;
  final Set<int> completedDays;
  final int today;
  final ValueChanged<int> onToggle;
  final int weeks;

  static const _gap = 4.0;
  static const _labelWidth = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final firstMonday = today - (weekdayOfDayKey(today) - 1) - 7 * (weeks - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell =
            (constraints.maxWidth - _labelWidth - _gap * (weeks - 1)) / weeks;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month names above the first week that starts in that month.
            SizedBox(
              height: 18,
              child: Stack(
                children: [
                  for (var w = 0; w < weeks; w++)
                    if (_startsMonth(firstMonday + 7 * w, w))
                      Positioned(
                        left: _labelWidth + w * (cell + _gap),
                        child: Text(
                          DateFormat.MMM().format(
                            dateOfDayKey(firstMonday + 7 * w + 6),
                          ),
                          style: labelStyle,
                        ),
                      ),
                ],
              ),
            ),
            for (var row = 0; row < 7; row++)
              Padding(
                padding: EdgeInsets.only(bottom: row == 6 ? 0 : _gap),
                child: Row(
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        row.isEven ? 'MTWTFSS'[row] : '',
                        style: labelStyle,
                      ),
                    ),
                    for (var w = 0; w < weeks; w++) ...[
                      if (w > 0) const SizedBox(width: _gap),
                      _cell(firstMonday + 7 * w + row, cell, scheme),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  bool _startsMonth(int monday, int column) {
    // Label the column holding the 1st..7th of a month, plus the first
    // column so the grid always has a month on it.
    final sunday = dateOfDayKey(monday + 6);
    return sunday.day <= 7 || column == 0;
  }

  Widget _cell(int day, double size, ColorScheme scheme) {
    final isFuture = day > today;
    final done = completedDays.contains(day);
    final active = day >= startDay && isScheduledOn(weekdays, day);

    final Color fill;
    if (isFuture) {
      fill = Colors.transparent;
    } else if (done) {
      fill = color;
    } else if (active) {
      fill = scheme.surfaceContainerHighest;
    } else {
      fill = scheme.surfaceContainerHighest.withValues(alpha: 0.4);
    }

    final box = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size / 4),
        border: day == today
            ? Border.all(color: scheme.onSurface, width: 1.5)
            : null,
      ),
    );
    if (isFuture) return box;

    return Semantics(
      button: true,
      checked: done,
      label: DateFormat.MMMEd().format(dateOfDayKey(day)),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(day);
        },
        child: box,
      ),
    );
  }
}
