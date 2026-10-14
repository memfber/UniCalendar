import 'date_util.dart';

/// 一节课的作息时间段，例如第 1 节 08:00–08:45。
class TimeSlot {
  final int index; // 节次，从 1 开始
  final String start; // "08:00"
  final String end; // "08:45"

  const TimeSlot({required this.index, required this.start, required this.end});

  int get startMinute => parseHm(start);
  int get endMinute => parseHm(end);
  int get duration => endMinute - startMinute;
}

/// 一周从周几开始（课表网格用）
enum WeekStart { monday, sunday }

/// 学期。startDate 必须是「第 1 周的周一」，周次全部由此推导。
class Term {
  final String id;
  final String name;
  final DateTime startDate;
  final int totalWeeks;
  final WeekStart weekStart;
  final List<TimeSlot> slots;

  const Term({
    required this.id,
    required this.name,
    required this.startDate,
    required this.totalWeeks,
    this.weekStart = WeekStart.monday,
    required this.slots,
  });

  /// 第 1 周周一（已归一化）
  DateTime get origin => dayOnly(startDate);

  TimeSlot slotAt(int section) {
    if (section < 1 || section > slots.length) {
      throw RangeError('节次 $section 超出作息表范围 (1..${slots.length})');
    }
    return slots[section - 1];
  }

  /// 当天第一节 / 最后一节的时间范围，用于课表网格纵向比例换算
  int get gridStartMinute => slots.isEmpty ? 480 : slots.first.startMinute;
  int get gridEndMinute => slots.isEmpty ? 1320 : slots.last.endMinute;
}
