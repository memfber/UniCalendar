import 'package:flutter/material.dart';

import 'src/data/repository.dart';
import 'src/domain/date_util.dart';
import 'src/domain/occurrence.dart';
import 'src/domain/todo.dart';
import 'src/engine/agenda_merger.dart';
import 'src/engine/week_resolver.dart';

void main() => runApp(const UniCalApp());

/// 整合后的应用外壳：一个 App、三个入口（今日 / 课表 / 日历），
/// 三者消费同一份 [AgendaMerger] 输出。
class UniCalApp extends StatelessWidget {
  const UniCalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniCal · 课表日历日程',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E7FFF)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UniCalRepository _repo = DemoRepository();
  AgendaMerger? _merger;
  WeekResolver? _resolver;
  int _tab = 0;
  int _weekOffset = 0;
  DateTime _focusedMonth = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final terms = await _repo.terms();
    final courses = await _repo.courses();
    final events = await _repo.events();
    final todos = await _repo.todos();
    if (!mounted || terms.isEmpty) return;
    setState(() {
      _resolver = WeekResolver(terms.first);
      _merger = AgendaMerger(
        terms: terms,
        courses: courses,
        events: events,
        todos: todos,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final merger = _merger;
    if (merger == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('UniCal'), centerTitle: true),
      body: IndexedStack(
        index: _tab,
        children: [
          _TodayView(merger: merger),
          _TimetableView(
            merger: merger,
            resolver: _resolver!,
            weekOffset: _weekOffset,
            onWeekChanged: (d) => setState(() => _weekOffset += d),
          ),
          _CalendarView(
            merger: merger,
            focusedMonth: _focusedMonth,
            onMonthChanged: (d) => setState(
              () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + d),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), label: '今日'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), label: '课表'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: '日历'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 今日

class _TodayView extends StatelessWidget {
  final AgendaMerger merger;
  const _TodayView({required this.merger});

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final items = merger.forDay(today);
    final conflicts = merger.conflictsOn(today);
    final inbox = merger.inboxTodos();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${today.month} 月 ${today.day} 日 · 星期${_cn(today.weekday)}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('共 ${items.length} 项安排', style: const TextStyle(color: Colors.grey)),
        if (conflicts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ConflictBanner(count: conflicts.length),
        ],
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('今天没有安排，享受一天。')),
          )
        else
          ...items.map((o) => _OccurrenceTile(o: o)),
        if (inbox.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('待办箱（无截止日期）',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...inbox.map((t) => _TodoTile(todo: t)),
        ],
      ],
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  final int count;
  const _ConflictBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFE67E22)),
          const SizedBox(width: 8),
          Text('检测到 $count 处时间冲突', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _OccurrenceTile extends StatelessWidget {
  final Occurrence o;
  const _OccurrenceTile({required this.o});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: Color(o.colorValue),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          o.title,
          style: TextStyle(
            decoration: o.done ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('${o.timeLabel}${o.subtitle != null ? ' · ${o.subtitle}' : ''}'),
        trailing: _KindChip(kind: o.kind),
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  final Todo todo;
  const _TodoTile({required this.todo});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.check_circle_outline, color: Color(0xFF27AE60)),
        title: Text(todo.title),
        subtitle: Text(todo.category.label),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  final SourceKind kind;
  const _KindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      SourceKind.course => const Color(0xFF4E7FFF),
      SourceKind.event => const Color(0xFFF2994A),
      SourceKind.todo => const Color(0xFF27AE60),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(kind.label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

// ---------------------------------------------------------------- 课表

class _TimetableView extends StatelessWidget {
  final AgendaMerger merger;
  final WeekResolver resolver;
  final int weekOffset;
  final ValueChanged<int> onWeekChanged;

  const _TimetableView({
    required this.merger,
    required this.resolver,
    required this.weekOffset,
    required this.onWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final term = resolver.term;
    final week = resolver.currentWeek(DateTime.now()) + weekOffset;
    final monday = resolver.mondayOfWeek(week);
    final items = merger.forWeek(monday);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onWeekChanged(-1),
              ),
              Text('第 $week 周',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onWeekChanged(1),
              ),
            ],
          ),
        ),
        Row(
          children: List.generate(7, (i) {
            final d = monday.add(Duration(days: i));
            final isToday = dateKey(d) == dateKey(DateTime.now());
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: isToday ? const Color(0xFFE8F0FF) : null,
                child: Center(
                  child: Text(
                    '${_cn(i + 1)}\n${d.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? const Color(0xFF4E7FFF) : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final h = c.maxHeight;
              final start = term.gridStartMinute;
              final span = (term.gridEndMinute - start).clamp(1, 1440);
              return Row(
                children: List.generate(7, (i) {
                  final d = monday.add(Duration(days: i));
                  final dayItems = items.where((o) => dateKey(o.day) == dateKey(d)).toList();
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade200, width: i < 6 ? 1 : 0),
                        ),
                      ),
                      child: Stack(
                        children: dayItems.map((o) {
                          final top = ((o.startMinute - start) / span) * h;
                          final height = ((o.endMinute - o.startMinute).clamp(20, 1440) / span) * h;
                          return Positioned(
                            top: top,
                            left: 2,
                            right: 2,
                            height: height,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Color(o.colorValue),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${o.title}\n${o.subtitle ?? ''}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 日历

class _CalendarView extends StatelessWidget {
  final AgendaMerger merger;
  final DateTime focusedMonth;
  final ValueChanged<int> onMonthChanged;

  const _CalendarView({
    required this.merger,
    required this.focusedMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final y = focusedMonth.year;
    final m = focusedMonth.month;
    final density = merger.monthDensity(y, m);
    final first = firstDayOfMonth(focusedMonth);
    final leading = first.weekday - 1; // 周一为第一列
    final total = daysInMonth(y, m);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonthChanged(-1),
              ),
              Text('$y 年 $m 月',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonthChanged(1),
              ),
            ],
          ),
        ),
        Row(
          children: List.generate(
            7,
            (i) => Expanded(
              child: Center(
                child: Text(_cn(i + 1),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: leading + total,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final day = index - leading + 1;
              final d = DateTime(y, m, day);
              final count = density[dateKey(d)] ?? 0;
              final isToday = dateKey(d) == dateKey(DateTime.now());
              return Container(
                decoration: BoxDecoration(
                  color: isToday ? const Color(0xFF4E7FFF) : null,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? null : Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        color: isToday ? Colors.white : Colors.black87,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (count > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isToday ? Colors.white : const Color(0xFF4E7FFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 工具

String _cn(int isoWeekday) => switch (isoWeekday) {
      1 => '一',
      2 => '二',
      3 => '三',
      4 => '四',
      5 => '五',
      6 => '六',
      _ => '日',
    };
