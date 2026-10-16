/// Calendar days are stored as whole days since 1970-01-01 (a "day key"), so
/// a completion never moves to another day because of time zones or
/// daylight saving changes.
int dayKeyOf(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The local calendar date for [dayKey], at midnight.
DateTime dateOfDayKey(int dayKey) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    dayKey * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

/// ISO weekday (Monday = 1 ... Sunday = 7). 1970-01-01 was a Thursday.
int weekdayOfDayKey(int dayKey) => (dayKey + 3) % 7 + 1;
