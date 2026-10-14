import '../domain/date_util.dart';
import '../domain/term.dart';

/// 教学周计算器。
///
/// 中国高校课表的一切排课规则（单双周、周次范围、调休）都建立在
/// 「开学第一周周一」这个锚点上，所以把它单独抽成无状态可测的组件。
class WeekResolver {
  final Term term;

  const WeekResolver(this.term);

  /// 返回该日期所处的教学周（1..totalWeeks）。
  /// 开学前返回 0，放假后返回 totalWeeks + n（调用方用 isInTerm 判定）。
  int weekOf(DateTime day) {
    final d = dayOnly(day);
    final diff = d.difference(term.origin).inDays;
    if (diff < 0) return 0;
    return diff ~/ 7 + 1;
  }

  bool isInTerm(DateTime day) {
    final w = weekOf(day);
    return w >= 1 && w <= term.totalWeeks;
  }

  /// 第 week 周的周一
  DateTime mondayOfWeek(int week) => term.origin.add(Duration(days: (week - 1) * 7));

  /// 第 week 周的星期 isoWeekday
  DateTime dateOfWeekday(int week, int isoWeekday) =>
      mondayOfWeek(week).add(Duration(days: isoWeekday - 1));

  /// 当前所处的教学周（不在学期内时返回最近的合法周，便于 UI 兜底展示）
  int currentWeek(DateTime now) {
    final w = weekOf(now);
    if (w < 1) return 1;
    if (w > term.totalWeeks) return term.totalWeeks;
    return w;
  }
}
