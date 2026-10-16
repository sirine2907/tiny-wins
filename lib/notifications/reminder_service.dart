import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/database.dart';

/// Initialized in `main()` and injected with an override.
final reminderServiceProvider = Provider<ReminderService>(
  (ref) => throw UnimplementedError('Override reminderServiceProvider'),
);

/// Schedules a repeating local notification for each weekday a habit is
/// due, at the habit's reminder time.
class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_reminders',
      'Habit reminders',
      channelDescription: 'Daily nudges for habits that have a reminder.',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // Without the device zone, reminders fire at the right time in UTC.
      debugPrint('Could not read the local time zone: $error');
    }

    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is asked for when the first reminder is set instead.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (error) {
      debugPrint('Notifications are unavailable: $error');
    }
  }

  /// Asks for permission to show notifications. Returns whether it was
  /// granted. Safe to call again: the OS only prompts once.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Replaces any reminders for [habit] with ones matching its settings.
  Future<void> schedule(Habit habit) async {
    await cancel(habit.id);
    final minutes = habit.reminderMinutes;
    if (!_ready || minutes == null) return;

    for (var weekday = 1; weekday <= 7; weekday++) {
      if (habit.weekdays & (1 << (weekday - 1)) == 0) continue;
      await _plugin.zonedSchedule(
        id: _notificationId(habit.id, weekday),
        title: habit.name,
        body: 'A tiny win is waiting. Keep your streak going!',
        scheduledDate: _nextInstance(weekday, minutes),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancel(int habitId) async {
    if (!_ready) return;
    for (var weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _notificationId(habitId, weekday));
    }
  }

  static int _notificationId(int habitId, int weekday) =>
      habitId * 10 + weekday;

  /// The next [weekday] at [minutes] past midnight, local time.
  static tz.TZDateTime _nextInstance(int weekday, int minutes) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    while (date.weekday != weekday || !date.isAfter(now)) {
      // Rebuild from calendar fields rather than adding 24 hours, so the
      // time stays put across daylight saving changes.
      date = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day + 1,
        date.hour,
        date.minute,
      );
    }
    return date;
  }
}
