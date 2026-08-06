class WorkTimeSettings {
  const WorkTimeSettings({
    required this.startHour,
    required this.endHour,
    required this.offWeekdays,
    required this.breakMinutesPerHour,
  });

  final int startHour;
  final int endHour;
  final Set<int> offWeekdays;
  final int breakMinutesPerHour;

  bool get isValid => startHour >= 0 && endHour <= 24 && startHour < endHour;

  bool isOffDay(DateTime date) => offWeekdays.contains(date.weekday);

  DateTime workStartFor(DateTime date) => DateTime(date.year, date.month, date.day, startHour);
  DateTime workEndFor(DateTime date) => DateTime(date.year, date.month, date.day, endHour);

  int availableMinutesFor(DateTime date) {
    if (isOffDay(date)) return 0;
    final total = (endHour - startHour) * 60;
    final breakMinutes = (endHour - startHour) * breakMinutesPerHour;
    return (total - breakMinutes).clamp(0, 24 * 60).toInt();
  }

  Map<String, dynamic> toJson() => {
        'startHour': startHour,
        'endHour': endHour,
        'offWeekdays': offWeekdays.toList(),
        'breakMinutesPerHour': breakMinutesPerHour,
      };

  factory WorkTimeSettings.fromJson(Map<String, dynamic> json) {
    return WorkTimeSettings(
      startHour: (json['startHour'] as num?)?.toInt() ?? 9,
      endHour: (json['endHour'] as num?)?.toInt() ?? 18,
      offWeekdays: ((json['offWeekdays'] as List<dynamic>?) ?? [DateTime.friday]).map((e) => (e as num).toInt()).toSet(),
      breakMinutesPerHour: (json['breakMinutesPerHour'] as num?)?.toInt() ?? 10,
    );
  }

  static const defaultSettings = WorkTimeSettings(
    startHour: 9,
    endHour: 18,
    offWeekdays: {DateTime.friday},
    breakMinutesPerHour: 10,
  );
}
