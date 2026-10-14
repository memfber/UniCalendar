/// 日期工具：整个工程只使用「本地时间 + 当天归一化」两种约定，
/// 避免时区/DST 带来的跨端差异（Android / iOS / 鸿蒙 / Windows 行为一致）。
library;

/// 把任意 DateTime 归一化为当天 00:00（保留年月日，丢弃时分秒）。
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 日期主键，用于集合去重、例外日期匹配、缓存 key。
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '-${d.month.toString().padLeft(2, '0')}'
    '-${d.day.toString().padLeft(2, '0')}';

/// "08:30" -> 510（自 00:00 起的分钟数）
int parseHm(String s) {
  final parts = s.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// 510 -> "08:30"
String formatHm(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// ISO-8601 星期：周一=1 … 周日=7
int isoWeekday(DateTime d) => d.weekday;

/// 某月第一天
DateTime firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// 某月天数
int daysInMonth(int year, int month) {
  final next = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
  return next.subtract(const Duration(days: 1)).day;
}
