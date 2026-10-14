import 'date_util.dart';

/// 重复频率。刻意做成 RFC 5545 RRULE 的一个**最小可用子集**，
/// 既能覆盖 95% 真实场景，又避免引入完整 RRULE 解析器带来的体积与复杂度。
enum RepeatFreq { none, daily, weekly, biweekly, monthly, yearly }

class RRule {
  final RepeatFreq freq;

  /// 每 interval 个周期重复一次
  final int interval;

  /// 重复截止日（含）
  final DateTime? until;

  /// weekly/biweekly 时指定周几：{1,3,5} 表示周一三五
  final Set<int> byWeekday;

  /// monthly 时指定「第几月的哪一天」由 start 推导；yearly 同理
  const RRule({
    this.freq = RepeatFreq.none,
    this.interval = 1,
    this.until,
    this.byWeekday = const <int>{},
  });

  bool get isRepeating => freq != RepeatFreq.none;
}

/// 日程 / 事件（日历方向）。
class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final RRule rrule;

  /// 例外日期（重复系列中被单独删除的某一天）
  final Set<String> exDates;

  /// 提前提醒分钟数，如 [0, 15, 60]
  final List<int> reminderMinutes;
  final int colorValue;

  /// 可选：关联到某门课程（例如该课程的考试）
  final String? courseId;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.start,
    required this.end,
    this.allDay = false,
    this.rrule = const RRule(),
    this.exDates = const <String>{},
    this.reminderMinutes = const <int>[15],
    this.colorValue = 0xFFF2994A,
    this.courseId,
  });

  bool isExcluded(DateTime day) => exDates.contains(dateKey(day));

  /// 判断重复事件是否命中某一天（[day] 必须为 dayOnly 后的值）
  bool hitsDay(DateTime day) {
    if (isExcluded(day)) return false;
    final s = dayOnly(start);
    if (day.isBefore(s)) return false;
    if (rrule.until != null && day.isAfter(dayOnly(rrule.until!))) return false;

    switch (rrule.freq) {
      case RepeatFreq.none:
        return day == s;

      case RepeatFreq.daily:
        return _everyNDays(s, day, rrule.interval);

      case RepeatFreq.weekly:
        return _everyNWeeks(s, day, rrule.interval) &&
            (rrule.byWeekday.isEmpty || rrule.byWeekday.contains(day.weekday));

      case RepeatFreq.biweekly:
        return _everyNWeeks(s, day, rrule.interval * 2) &&
            (rrule.byWeekday.isEmpty || rrule.byWeekday.contains(day.weekday));

      case RepeatFreq.monthly:
        return day.day == s.day;

      case RepeatFreq.yearly:
        return day.month == s.month && day.day == s.day;
    }
  }

  static bool _everyNDays(DateTime s, DateTime day, int n) {
    if (n <= 0) return false;
    final diff = day.difference(dayOnly(s)).inDays;
    return diff >= 0 && diff % n == 0;
  }

  static bool _everyNWeeks(DateTime s, DateTime day, int n) {
    if (n <= 0) return false;
    // 两侧都先归一化到当天 00:00 再回退到该周周一，
    // 否则 start 带时分（如 19:00）会与 dayOnly 的 day 产生小时级偏移，
    // 使跨零点的差值为负，导致首周命中失败。
    final sDay = dayOnly(s);
    final anchor = sDay.subtract(Duration(days: sDay.weekday - 1));
    final target = day.subtract(Duration(days: day.weekday - 1));
    final diffWeeks = target.difference(anchor).inDays ~/ 7;
    return diffWeeks >= 0 && diffWeeks % n == 0;
  }
}
