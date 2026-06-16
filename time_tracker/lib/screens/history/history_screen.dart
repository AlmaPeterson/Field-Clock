import 'package:flutter/material.dart';
import '../../database/dao/work_day_dao.dart';
import '../../database/dao/task_dao.dart';
import '../../models/work_day.dart';
import '../../models/task.dart';
import '../../utils/time_utils.dart';
import 'past_day_entry_screen.dart';
import '../../database/dao/session_dao.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WorkDay> _days = [];
  Map<int, int> _taskMinutesByDay = {};
  Map<int, List<Task>> _tasksByDay = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await WorkDayDao().getAll();
    final Map<int, List<Task>> taskMap = {};
    final Map<int, int> minutesMap = {};

    for (final day in days) {
      if (day.id != null) {
        final tasks = await TaskDao().getByWorkDay(day.id!);
        taskMap[day.id!] = tasks;
        final daySessions = await SessionDao().getByWorkDay(day.id!);
        minutesMap[day.id!] = daySessions
            .where((s) => !s.isActive)
            .fold<int>(0, (sum, s) => sum + s.durationMinutes);
      }
    }
    setState(() {
      _days = days;
      _tasksByDay = taskMap;
      _taskMinutesByDay = minutesMap;
      _loading = false;
    });
  }

  // Group days by month label e.g. "June 2026"
  Map<String, List<WorkDay>> get _grouped {
    final Map<String, List<WorkDay>> map = {};
    for (final day in _days) {
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final key = '${months[day.date.month]} ${day.date.year}';
      map.putIfAbsent(key, () => []).add(day);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Log Past Day',
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const PastDayEntryScreen()),
              );
              if (saved == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : _days.isEmpty
              ? _EmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Monthly totals banner
                    _MonthlyBanner(
                      days: _days,
                      tasksByDay: _tasksByDay,
                      taskMinutesByDay: _taskMinutesByDay,
                    ),
                    const SizedBox(height: 20),

                    // Days grouped by month
                    ..._grouped.entries.map((entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(entry.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge),
                        ),
                        ...entry.value.map((day) => _DayCard(
                          day: day,
                          tasks: _tasksByDay[day.id] ?? [],
                          totalMinutes: _taskMinutesByDay[day.id] ?? 0,
                          onRefresh: _load,
                          onTap: () async { /* ... unchanged */ },
                        )),
                        const SizedBox(height: 8),
                      ],
                    )),
                  ],
                ),
    );
  }
}

// ── Monthly Banner ───────────────────────────────────────────────────────────

class _MonthlyBanner extends StatelessWidget {
  final List<WorkDay> days;
  final Map<int, List<Task>> tasksByDay;
  final Map<int, int> taskMinutesByDay;

  const _MonthlyBanner({
    required this.days,
    required this.tasksByDay,
    required this.taskMinutesByDay,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = days.where(
        (d) => d.date.month == now.month &&
            d.date.year == now.year);

    int totalMinutes = 0;
    int totalTasks = 0;
    int totalDays = thisMonth.length;

    for (final day in thisMonth) {
      totalMinutes += taskMinutesByDay[day.id] ?? 0;
      totalTasks +=
          (tasksByDay[day.id] ?? []).length;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS MONTH',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          Row(
            children: [
              _BannerStat(
                value: TimeUtils.formatDuration(
                    Duration(minutes: totalMinutes)),
                label: 'Total Hours',
              ),
              _BannerStat(
                value: '$totalDays',
                label: 'Days Worked',
              ),
              _BannerStat(
                value: '$totalTasks',
                label: 'Tasks Done',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String value;
  final String label;

  const _BannerStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 22,
                  )),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Day Card ─────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final WorkDay day;
  final List<Task> tasks;
  final int totalMinutes;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const _DayCard({
    required this.day,
    required this.tasks,
    required this.totalMinutes,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final completed = tasks.toList();
    final isComplete = day.isComplete;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Date block
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isComplete
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                      : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '${day.date.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isComplete
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium!.color!,
                      ),
                    ),
                    Text(
                      _shortMonth(day.date.month),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isComplete
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).textTheme.bodyMedium!.color!,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Day info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekday(day.date.weekday),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isComplete
                          ? '${TimeUtils.formatTime(day.clockInTime!)} → ${TimeUtils.formatTime(day.clockOutTime!)}'
                          : day.clockInTime != null
                              ? 'Clocked in ${TimeUtils.formatTime(day.clockInTime!)}'
                              : 'No clock in',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${completed.length} task${completed.length == 1 ? '' : 's'}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).textTheme.bodyMedium!.color!),
                      ),
                    ],
                  ],
                ),
              ),

              // Hours + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    TimeUtils.formatDuration(
                        Duration(minutes: totalMinutes)),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right,
                      color: Theme.of(context).textTheme.bodyMedium!.color!, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortMonth(int month) {
    const m = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return m[month];
  }

  String _weekday(int weekday) {
    const d = [
      '', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return d[weekday];
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Theme.of(context).textTheme.bodyMedium!.color!),
          const SizedBox(height: 16),
          Text('No history yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Your past workdays will appear here',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}