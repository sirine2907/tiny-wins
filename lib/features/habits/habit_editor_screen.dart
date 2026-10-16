import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatting.dart';
import '../../core/habit_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../data/habit_repository.dart';
import '../../data/providers.dart';
import '../../domain/streaks.dart';
import '../../notifications/reminder_service.dart';

/// Creates a habit, or edits [habit] when one is given.
class HabitEditorScreen extends ConsumerStatefulWidget {
  const HabitEditorScreen({super.key, this.habit});

  final Habit? habit;

  @override
  ConsumerState<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends ConsumerState<HabitEditorScreen> {
  late final _name = TextEditingController(text: widget.habit?.name);
  late var _icon = widget.habit?.icon ?? 'check';
  late var _color =
      widget.habit?.color ?? AppColors.habitPalette.first.toARGB32();
  late var _weekdays = widget.habit?.weekdays ?? everyDay;
  late var _reminder = widget.habit?.reminderMinutes;
  var _saving = false;

  bool get _isNew => widget.habit == null;
  bool get _canSave => _name.text.trim().isNotEmpty && _weekdays != 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final draft = HabitDraft(
      name: _name.text.trim(),
      icon: _icon,
      color: _color,
      weekdays: _weekdays,
      reminderMinutes: _reminder,
    );
    final repository = ref.read(habitRepositoryProvider);
    final reminders = ref.read(reminderServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    final habit = _isNew
        ? await repository.addHabit(draft, startDay: ref.read(todayProvider))
        : await repository.updateHabit(widget.habit!.id, draft);

    if (habit.reminderMinutes != null && !await reminders.requestPermission()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Allow notifications in system settings to get reminders.',
          ),
        ),
      );
    }
    await reminders.schedule(habit);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text(
          '"${widget.habit!.name}" and its whole history will be removed. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(reminderServiceProvider).cancel(widget.habit!.id);
    await ref.read(habitRepositoryProvider).deleteHabit(widget.habit!.id);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _pickReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: timeOfMinutes(_reminder ?? 20 * 60),
    );
    if (picked != null) setState(() => _reminder = minutesOfTime(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(_color);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New habit' : 'Edit habit'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete habit',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _name,
            autofocus: _isNew,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Habit',
              hintText: 'e.g. Read 10 pages',
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const _Label('Icon'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in habitIcons.entries)
                _IconChoice(
                  icon: entry.value,
                  color: color,
                  selected: entry.key == _icon,
                  onTap: () => setState(() => _icon = entry.key),
                ),
            ],
          ),
          const _Label('Color'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final option in AppColors.habitPalette)
                _ColorChoice(
                  color: option,
                  selected: option.toARGB32() == _color,
                  onTap: () => setState(() => _color = option.toARGB32()),
                ),
            ],
          ),
          const _Label('Repeat'),
          _WeekdayPicker(
            weekdays: _weekdays,
            color: color,
            onChanged: (value) => setState(() => _weekdays = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, value) in const [
                ('Every day', everyDay),
                ('Weekdays', weekdaysOnly),
                ('Weekends', weekendsOnly),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _weekdays == value,
                  onSelected: (_) => setState(() => _weekdays = value),
                ),
            ],
          ),
          if (_weekdays == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pick at least one day.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const _Label('Reminder'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Daily reminder'),
                  subtitle: const Text('On the days this habit is due'),
                  value: _reminder != null,
                  onChanged: (on) =>
                      on ? _pickReminder() : setState(() => _reminder = null),
                ),
                if (_reminder != null)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Time'),
                    trailing: Text(
                      timeOfMinutes(_reminder!).format(context),
                      style: theme.textTheme.titleMedium,
                    ),
                    onTap: _pickReminder,
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _canSave && !_saving ? _save : null,
            child: Text(_isNew ? 'Add habit' : 'Save changes'),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 12),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : scheme.surfaceContainerHighest,
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 3,
                )
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({
    required this.weekdays,
    required this.color,
    required this.onChanged,
  });

  final int weekdays;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final on = weekdays & (1 << i) != 0;
              return Semantics(
                label: weekdayShortNames[i],
                selected: on,
                child: InkResponse(
                  onTap: () => onChanged(weekdays ^ (1 << i)),
                  radius: 24,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: on ? color : scheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      weekdayShortNames[i][0],
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

Future<void> openHabitEditor(BuildContext context, [Habit? habit]) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: habit == null,
      builder: (_) => HabitEditorScreen(habit: habit),
    ),
  );
}
