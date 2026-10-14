import '../domain/course.dart';
import '../domain/date_util.dart';
import '../domain/event.dart';
import '../domain/term.dart';
import '../domain/todo.dart';

/// 数据层契约。
///
/// 四端只实现这一层即可：Android/iOS/鸿蒙 用 sqflite，Windows 用同一份
/// sqflite（或 sqlite3）。上层引擎完全不知道数据从哪来，方便单测与换库。
abstract class UniCalRepository {
  Future<List<Term>> terms();
  Future<List<Course>> courses({String? termId});
  Future<List<CalendarEvent>> events();
  Future<List<Todo>> todos();

  Future<void> upsertTodo(Todo todo);
  Future<void> deleteTodo(String id);

  /// 全量导出（JSON 备份 / WebDAV 同步用）
  Future<Map<String, dynamic>> exportJson();

  /// 全量导入
  Future<void> importJson(Map<String, dynamic> json);
}

/// 内存实现：用于骨架演示与单元测试，零依赖、零 I/O。
class DemoRepository implements UniCalRepository {
  late final Term _term;
  final List<Course> _courses = [];
  final List<CalendarEvent> _events = [];
  final List<Todo> _todos = [];

  DemoRepository() {
    final now = DateTime.now();
    final thisMonday = dayOnly(now).subtract(Duration(days: now.weekday - 1));
    // 让「今天」落在第 4 周，保证首次打开就有课
    final origin = thisMonday.subtract(const Duration(days: 7 * 3));

    _term = Term(
      id: 'term-2026-1',
      name: '2026–2027 学年 第一学期',
      startDate: origin,
      totalWeeks: 20,
      slots: const [
        TimeSlot(index: 1, start: '08:00', end: '08:45'),
        TimeSlot(index: 2, start: '08:55', end: '09:40'),
        TimeSlot(index: 3, start: '10:00', end: '10:45'),
        TimeSlot(index: 4, start: '10:55', end: '11:40'),
        TimeSlot(index: 5, start: '14:00', end: '14:45'),
        TimeSlot(index: 6, start: '14:55', end: '15:40'),
        TimeSlot(index: 7, start: '16:00', end: '16:45'),
        TimeSlot(index: 8, start: '16:55', end: '17:40'),
      ],
    );

    _courses.addAll([
      Course(
        id: 'c1',
        termId: _term.id,
        name: '高等数学 A',
        teacher: '李老师',
        location: '教三 301',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF4E7FFF,
      ),
      Course(
        id: 'c2',
        termId: _term.id,
        name: '数据结构',
        teacher: '王老师',
        location: '实验楼 B204',
        weekday: 2,
        startSection: 3,
        endSection: 4,
        colorValue: 0xFF27AE60,
      ),
      Course(
        id: 'c3',
        termId: _term.id,
        name: '线性代数',
        teacher: '张老师',
        location: '教二 108',
        weekday: 3,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF9B51E0,
      ),
      Course(
        id: 'c4',
        termId: _term.id,
        name: '操作系统（双周）',
        teacher: '陈老师',
        location: '教三 402',
        weekday: 3,
        startSection: 5,
        endSection: 6,
        pattern: WeekPattern.even,
        colorValue: 0xFFEB5757,
      ),
      Course(
        id: 'c5',
        termId: _term.id,
        name: '大学英语（单周）',
        teacher: '刘老师',
        location: '外语楼 205',
        weekday: 4,
        startSection: 3,
        endSection: 4,
        pattern: WeekPattern.odd,
        colorValue: 0xFFF2994A,
      ),
      Course(
        id: 'c6',
        termId: _term.id,
        name: '编译原理',
        teacher: '赵老师',
        location: '实验楼 A101',
        weekday: 5,
        startSection: 1,
        endSection: 2,
        weekFrom: 1,
        weekTo: 16,
        colorValue: 0xFF2D9CDB,
      ),
    ]);

    final today = dayOnly(now);
    _events.addAll([
      CalendarEvent(
        id: 'e1',
        title: '高等数学月考',
        location: '教三 301',
        start: DateTime(today.year, today.month, today.day, 14, 0),
        end: DateTime(today.year, today.month, today.day, 15, 40),
        colorValue: 0xFFEB5757,
      ),
      CalendarEvent(
        id: 'e2',
        title: '实验室组会',
        location: '实验楼 B204',
        start: DateTime(today.year, today.month, today.day, 19, 0),
        end: DateTime(today.year, today.month, today.day, 20, 30),
        rrule: const RRule(freq: RepeatFreq.weekly, byWeekday: {3}),
        colorValue: 0xFF2D9CDB,
      ),
      CalendarEvent(
        id: 'e3',
        title: '校园马拉松',
        start: today.add(const Duration(days: 2)),
        end: today.add(const Duration(days: 2)),
        allDay: true,
        colorValue: 0xFFF2C94C,
      ),
      CalendarEvent(
        id: 'e4',
        title: '期末考试周',
        start: today.add(const Duration(days: 30)),
        end: today.add(const Duration(days: 36)),
        allDay: true,
        colorValue: 0xFFEB5757,
      ),
    ]);

    _todos.addAll([
      Todo(
        id: 't1',
        title: '数据结构第五章作业',
        note: 'P128 3、5、7 题',
        due: DateTime(today.year, today.month, today.day, 22, 0),
        category: TodoCategory.homework,
        priority: 2,
      ),
      Todo(
        id: 't2',
        title: '操作系统实验报告',
        due: today.add(const Duration(days: 1)).add(const Duration(hours: 10)),
        category: TodoCategory.homework,
      ),
      Todo(
        id: 't3',
        title: '英语四级报名',
        category: TodoCategory.exam,
        priority: 1,
      ),
    ]);
  }

  @override
  Future<List<Term>> terms() async => [_term];

  @override
  Future<List<Course>> courses({String? termId}) async =>
      _courses.where((c) => termId == null || c.termId == termId).toList();

  @override
  Future<List<CalendarEvent>> events() async => List.unmodifiable(_events);

  @override
  Future<List<Todo>> todos() async => List.unmodifiable(_todos);

  @override
  Future<void> upsertTodo(Todo todo) async {
    final i = _todos.indexWhere((t) => t.id == todo.id);
    if (i >= 0) {
      _todos[i] = todo;
    } else {
      _todos.add(todo);
    }
  }

  @override
  Future<void> deleteTodo(String id) async => _todos.removeWhere((t) => t.id == id);

  @override
  Future<Map<String, dynamic>> exportJson() async => {
        'version': 1,
        'terms': [_term.id],
        'courses': _courses.length,
        'events': _events.length,
        'todos': _todos.length,
      };

  @override
  Future<void> importJson(Map<String, dynamic> json) async {
    // 骨架阶段：真实实现见 README「数据层落地」
  }
}
