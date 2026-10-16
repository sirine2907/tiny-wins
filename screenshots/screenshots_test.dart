// Renders the README screenshots into docs/screenshots.
//
//   flutter test screenshots --update-goldens
//
// Kept out of test/ because pixel output differs between machines, so these
// files would make the normal test run flaky.

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiny_wins/core/day.dart';
import 'package:tiny_wins/domain/streaks.dart';

import '../test/support/fakes.dart';

final now = DateTime(2026, 10, 16, 8, 45);
final today = dayKeyOf(now);

void main() {
  setUpAll(_loadFonts);

  Future<void> capture(
    WidgetTester tester,
    String name, {
    ThemeMode themeMode = ThemeMode.light,
    Future<void> Function()? navigate,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      await buildTestApp(
        repository: _demoData(),
        now: now,
        themeMode: themeMode,
      ),
    );
    await tester.pumpAndSettle();
    await navigate?.call();
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/$name.png'),
    );
  }

  testWidgets('today', (tester) => capture(tester, 'today'));

  testWidgets(
    'today dark',
    (tester) => capture(tester, 'today_dark', themeMode: ThemeMode.dark),
  );

  testWidgets(
    'detail',
    (tester) => capture(
      tester,
      'detail',
      navigate: () => tester.tap(find.text('Meditate 5 min')),
    ),
  );

  testWidgets(
    'stats',
    (tester) => capture(
      tester,
      'stats',
      navigate: () => tester.tap(find.text('Stats')),
    ),
  );

  testWidgets(
    'editor',
    (tester) => capture(
      tester,
      'editor',
      navigate: () async {
        await tester.tap(find.text('Read 10 pages'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Edit habit'));
      },
    ),
  );
}

FakeHabitRepository _demoData() {
  final repository = FakeHabitRepository();
  final random = Random(7);

  void add(
    String name, {
    required String icon,
    required int color,
    int weekdays = everyDay,
    required int streak,
    required bool doneToday,
    double missRate = 0.15,
    int? reminderMinutes,
  }) {
    final start = today - 140;
    final scheduled = [
      for (var day = start; day < today; day++)
        if (isScheduledOn(weekdays, day)) day,
    ];
    final done = <int>{
      // A clean run of [streak] days ending yesterday (or today)...
      ...scheduled.reversed.take(streak - (doneToday ? 1 : 0)),
      // ...and a slightly patchy history before the day that broke it.
      ...scheduled.reversed
          .skip(streak - (doneToday ? 1 : 0) + 1)
          .where((_) => random.nextDouble() > missRate),
      if (doneToday) today,
    };
    repository.seed(
      name,
      icon: icon,
      color: Color(color),
      weekdays: weekdays,
      startDay: start,
      reminderMinutes: reminderMinutes,
      completedDays: done,
    );
  }

  add(
    'Meditate 5 min',
    icon: 'meditate',
    color: 0xFF22A06B,
    streak: 41,
    doneToday: true,
    reminderMinutes: 7 * 60 + 30,
  );
  add(
    'Drink 8 glasses of water',
    icon: 'water',
    color: 0xFF0EA5E9,
    streak: 23,
    doneToday: true,
  );
  add(
    'Read 10 pages',
    icon: 'book',
    color: 0xFF6366F1,
    streak: 12,
    doneToday: false,
    reminderMinutes: 21 * 60,
  );
  add(
    'Morning run',
    icon: 'run',
    color: 0xFFF97316,
    weekdays: 0x15, // Mon, Wed, Fri
    streak: 9,
    doneToday: true,
    missRate: 0.25,
  );
  add(
    'Practice Japanese',
    icon: 'language',
    color: 0xFFEC4899,
    weekdays: weekdaysOnly,
    streak: 5,
    doneToday: false,
    missRate: 0.3,
  );
  add(
    'Weekly review',
    icon: 'write',
    color: 0xFFA855F7,
    weekdays: 0x40, // Sunday
    streak: 7,
    doneToday: false,
  );
  return repository;
}

/// Widget tests render text in a placeholder font. Load the real Roboto and
/// Material Icons that ship inside the Flutter SDK so the screenshots look
/// like the app.
Future<void> _loadFonts() async {
  var dir = File(Platform.resolvedExecutable).parent;
  while (!Directory('${dir.path}/material_fonts').existsSync()) {
    if (dir.parent.path == dir.path) {
      throw StateError('Could not find the Flutter SDK material_fonts');
    }
    dir = dir.parent;
  }
  final fonts = '${dir.path}/material_fonts';

  Future<ByteData> read(String file) async =>
      ByteData.sublistView(await File('$fonts/$file').readAsBytes());

  final roboto = FontLoader('Roboto');
  for (final weight in [
    'thin',
    'light',
    'regular',
    'medium',
    'bold',
    'black',
  ]) {
    roboto.addFont(read('roboto-$weight.ttf'));
  }
  await roboto.load();

  await (FontLoader(
    'MaterialIcons',
  )..addFont(read('materialicons-regular.otf'))).load();
}
