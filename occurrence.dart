import 'date_util.dart';

/// 三源统一后的「时间轴条目」。
///
/// 这是整个整合设计的枢纽：课程、日程、待办是三种异构数据，
/// 上层三种视图（今日时间轴 / 周课表 / 月日历）只消费这一种类型，
/// 从而彻底消除「三套数据三套 UI」的重复。
enum SourceKind { course, event, todo }

extension SourceKindX on SourceKind {
  String get label => switch (this) {
        SourceKind.course => '课程',
        SourceKind.event => '日程',
        SourceKind.todo => '待办',
      };
}

class Occurrence {
  /// 全局唯一 id：`${kind.name}:${sourceId}:${dateKey(day)}`
  final String id;
  final SourceKind kind;

  /// 指向原始实体（Course.id / CalendarEvent.id / Todo.id）
  final String sourceId;
  final String title;

  /// 副标题：地点 / 教师 / 备注
  final String? subtitle;

  /// 所属日期（已 dayOnly）
  final DateTime day;

  /// 自 00:00 起的分钟数；allDay 时无意义
  final int startMinute;
  final int endMinute;
  final bool allDay;

  /// 待办完成态
  final bool done;
  final int colorValue;

  /// 课表条目才有：教学周次
  final int? weekNumber;

  const Occurrence({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.title,
    this.subtitle,
    required this.day,
    this.startMinute = -1,
    this.endMinute = -1,
    this.allDay = false,
    this.done = false,
    this.colorValue = 0xFF4E7FFF,
    this.weekNumber,
  });

  int get duration => endMinute - startMinute;

  /// 与另一条是否时间重叠（用于冲突检测）
  bool overlaps(Occurrence other) {
    if (allDay || other.allDay) return false;
    return startMinute < other.endMinute && other.startMinute < endMinute;
  }

  String get timeLabel => allDay ? '全天' : '${formatHm(startMinute)}–${formatHm(endMinute)}';
}
