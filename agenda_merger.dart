import '../domain/course.dart';
import '../domain/date_util.dart';
import '../domain/event.dart';
import '../domain/occurrence.dart';
import '../domain/term.dart';
import '../domain/todo.dart';
import 'week_resolver.dart';

/// 三源合并引擎 —— 把「课程 / 日程 / 待办」展开并统一到同一条时间轴。
///
/// 设计要点：
/// 1. 纯 Dart、零平台依赖、零 I/O，可 100% 单元测试；
/// 2. 惰性展开：只计算被请求的某一天/某一周，不做全年实例化（省内存）；
/// 3. 输出统一为 [Occurrence]，上层三种视图共用一份结果。
class AgendaMerger {
  final List<Term> terms;
  final List<Course> courses;
  final List<CalendarEvent> events;
  final List<Todo> todos;

  late final Map<String, Term> _termMap = {for (final t in terms) t.id: t};

  AgendaMerger({
    required this.terms,
    required this.courses,
    required this.events,
    required this.todos,
  });

  // ---------------------------------------------------------------- 单日

  /// 某一天的完整时间轴（课程 + 日程 + 待办），已排好序。
  List<Occurrence> forDay(DateTime day) {
    final d = dayOnly(day);
    final list = <Occurrence>[
      ..._coursesOn(d),
      ..._eventsOn(d),
      ..._todosOn(d),
    ];
    _sort(list);
    return list;
  }

  // ---------------------------------------------------------------- 整周

  /// 某一天的那一整周（周一至周日）。
  List<Occurrence> forWeek(DateTime anyDayInWeek) {
    final d = dayOnly(anyDayInWeek);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final list = <Occurrence>[];
    for (var i = 0; i < 7; i++) {
      list.addAll(forDay(monday.add(Duration(days: i))));
    }
    return list;
  }

  // ------------------------------------------------------- 月视图密度打点

  /// 返回 `dateKey -> 当天条目数`，供月日历画圆点。
  /// 逐日调用 forDay，结果已足够快（每月 ≤31 次纯内存计算）。
  Map<String, int> monthDensity(int year, int month) {
    final total = daysInMonth(year, month);
    final result = <String, int>{};
    for (var day = 1; day <= total; day++) {
      final d = DateTime(year, month, day);
      result[dateKey(d)] = forDay(d).length;
    }
    return result;
  }

  // ---------------------------------------------------------------- 冲突

  /// 当天存在时间重叠的条目对（课程撞课、日程撞课等）。
  List<(Occurrence, Occurrence)> conflictsOn(DateTime day) {
    final list = forDay(day).where((o) => !o.allDay && o.duration > 0).toList();
    final result = <(Occurrence, Occurrence)>[];
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        if (list[i].overlaps(list[j])) result.add((list[i], list[j]));
      }
    }
    return result;
  }

  // ------------------------------------------------------- 无期限待办箱

  /// 没有截止时间的待办（不进时间轴，单独展示）
  List<Todo> inboxTodos() => todos.where((t) => t.due == null && !t.done).toList();

  // ------------------------------------------------------------ 三个展开器

  List<Occurrence> _coursesOn(DateTime d) {
    final out = <Occurrence>[];
    for (final c in courses) {
      final term = _termMap[c.termId];
      if (term == null) continue;
      if (c.startSection < 1 || c.endSection > term.slots.length) continue;

      final resolver = WeekResolver(term);
      if (!resolver.isInTerm(d)) continue;
      if (d.weekday != c.weekday) continue;

      final week = resolver.weekOf(d);
      if (!c.happensOnWeek(week)) continue;

      final startSlot = term.slotAt(c.startSection);
      final endSlot = term.slotAt(c.endSection);
      final subtitle = <String>[
        if (c.location != null) c.location!,
        if (c.teacher != null) c.teacher!,
      ].join(' · ');

      out.add(
        Occurrence(
          id: 'course:${c.id}:${dateKey(d)}',
          kind: SourceKind.course,
          sourceId: c.id,
          title: c.name,
          subtitle: subtitle.isEmpty ? null : subtitle,
          day: d,
          startMinute: startSlot.startMinute,
          endMinute: endSlot.endMinute,
          colorValue: c.colorValue,
          weekNumber: week,
        ),
      );
    }
    return out;
  }

  List<Occurrence> _eventsOn(DateTime d) {
    final out = <Occurrence>[];
    for (final e in events) {
      if (!e.hitsDay(d)) continue;
      final sm = e.start.hour * 60 + e.start.minute;
      final em = e.end.hour * 60 + e.end.minute;
      out.add(
        Occurrence(
          id: 'event:${e.id}:${dateKey(d)}',
          kind: SourceKind.event,
          sourceId: e.id,
          title: e.title,
          subtitle: e.location ?? e.description,
          day: d,
          startMinute: e.allDay ? -1 : sm,
          endMinute: e.allDay ? -1 : (em > sm ? em : sm),
          allDay: e.allDay,
          colorValue: e.colorValue,
        ),
      );
    }
    return out;
  }

  List<Occurrence> _todosOn(DateTime d) {
    final out = <Occurrence>[];
    for (final t in todos) {
      if (t.due == null) continue;
      if (dayOnly(t.due!) != d) continue;
      final m = t.due!.hour * 60 + t.due!.minute;
      out.add(
        Occurrence(
          id: 'todo:${t.id}:${dateKey(d)}',
          kind: SourceKind.todo,
          sourceId: t.id,
          title: t.title,
          subtitle: t.category.label,
          day: d,
          startMinute: m,
          endMinute: m, // 待办是时间点，duration 为 0，不参与冲突判定
          done: t.done,
          colorValue: 0xFF27AE60,
        ),
      );
    }
    return out;
  }

  // ---------------------------------------------------------------- 排序

  /// 全天在前，其后按开始时间；时间相同则课程 > 日程 > 待办
  static void _sort(List<Occurrence> list) {
    list.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      if (!a.allDay && a.startMinute != b.startMinute) {
        return a.startMinute.compareTo(b.startMinute);
      }
      final ka = a.kind.index.compareTo(b.kind.index);
      if (ka != 0) return ka;
      return a.title.compareTo(b.title);
    });
  }
}
