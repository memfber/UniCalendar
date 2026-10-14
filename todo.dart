/// 待办（日程方向）。
enum TodoCategory { homework, exam, activity, life }

extension TodoCategoryX on TodoCategory {
  String get label => switch (this) {
        TodoCategory.homework => '作业',
        TodoCategory.exam => '考试',
        TodoCategory.activity => '活动',
        TodoCategory.life => '生活',
      };
}

class Todo {
  final String id;
  final String title;
  final String? note;

  /// 截止时间；为 null 表示「无期限」，在日历上归入当天待办箱
  final DateTime? due;
  final bool done;
  final TodoCategory category;

  /// 0=低 1=中 2=高
  final int priority;
  final String? courseId;

  const Todo({
    required this.id,
    required this.title,
    this.note,
    this.due,
    this.done = false,
    this.category = TodoCategory.life,
    this.priority = 1,
    this.courseId,
  });

  Todo copyWith({
    String? title,
    String? note,
    DateTime? due,
    bool? done,
    TodoCategory? category,
    int? priority,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      due: due ?? this.due,
      done: done ?? this.done,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      courseId: courseId,
    );
  }
}
