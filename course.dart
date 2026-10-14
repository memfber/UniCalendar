/// 课程（课表方向）。
///
/// 一门课在一周内只占一个「星期 + 节次区间」，通过周次规则决定它在
/// 哪些教学周生效——这是课程表区别于普通日程的核心。
enum WeekPattern {
  /// 每周都上
  all,

  /// 单周（第 1、3、5…周）
  odd,

  /// 双周（第 2、4、6…周）
  even,

  /// 仅在 customWeeks 中列出的周次
  custom,
}

class Course {
  final String id;
  final String termId;
  final String name;
  final String? teacher;
  final String? location;

  /// ARGB 整型色值（Flutter Color.value）
  final int colorValue;

  /// ISO 星期：周一=1 … 周日=7
  final int weekday;

  /// 起始/结束节次（闭区间，对应 Term.slots 的 index）
  final int startSection;
  final int endSection;

  final WeekPattern pattern;

  /// pattern == custom 时生效
  final Set<int> customWeeks;

  /// 生效周次范围（闭区间），默认整学期
  final int weekFrom;
  final int weekTo;

  const Course({
    required this.id,
    required this.termId,
    required this.name,
    this.teacher,
    this.location,
    this.colorValue = 0xFF4E7FFF,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    this.pattern = WeekPattern.all,
    this.customWeeks = const <int>{},
    this.weekFrom = 1,
    this.weekTo = 999,
  });

  /// 判断该课程在指定教学周是否上课
  bool happensOnWeek(int week) {
    if (week < weekFrom || week > weekTo) return false;
    switch (pattern) {
      case WeekPattern.all:
        return true;
      case WeekPattern.odd:
        return week.isOdd;
      case WeekPattern.even:
        return week.isEven;
      case WeekPattern.custom:
        return customWeeks.contains(week);
    }
  }

  Course copyWith({
    String? name,
    String? teacher,
    String? location,
    int? colorValue,
    int? weekday,
    int? startSection,
    int? endSection,
    WeekPattern? pattern,
    Set<int>? customWeeks,
    int? weekFrom,
    int? weekTo,
  }) {
    return Course(
      id: id,
      termId: termId,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      colorValue: colorValue ?? this.colorValue,
      weekday: weekday ?? this.weekday,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      pattern: pattern ?? this.pattern,
      customWeeks: customWeeks ?? this.customWeeks,
      weekFrom: weekFrom ?? this.weekFrom,
      weekTo: weekTo ?? this.weekTo,
    );
  }
}
