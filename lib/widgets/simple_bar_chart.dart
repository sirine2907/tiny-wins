import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A minimal bar chart: one bar per entry, a label under each bar and a
/// tooltip with the exact value on touch. The last bar is drawn at full
/// strength, the others slightly faded, so "now" stands out.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.entries,
    required this.color,
    this.maxY,
    this.height = 160,
  });

  final List<(String label, int value)> entries;
  final Color color;

  /// Top of the y axis, raised if a value is larger. Defaults to the
  /// largest value (at least 1).
  final int? maxY;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Never let a bar poke out of the top, even if maxY is too small.
    final top = entries.fold<int>(
      maxY ?? 1,
      (top, e) => e.$2 > top ? e.$2 : top,
    );

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top.toDouble(),
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    entries[value.toInt()].$1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                    '${rod.toY.toInt()}',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].$2.toDouble(),
                    width: 18,
                    color: i == entries.length - 1
                        ? color
                        : color.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: top.toDouble(),
                      color: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
