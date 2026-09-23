String writingWeekKey(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day
      .subtract(Duration(days: now.weekday - DateTime.monday))
      .toIso8601String()
      .substring(0, 10);
}

Map<String, dynamic> recordWritingProgress(Map<String, dynamic> metadata,
    {required int before, required int after, required DateTime now}) {
  final key = writingWeekKey(now);
  final previous = metadata['writing_week'] == key
      ? (metadata['writing_words'] as num?)?.toInt() ?? 0
      : 0;
  return {
    ...metadata,
    'writing_week': key,
    'writing_words': previous + (after - before).clamp(0, after)
  };
}
