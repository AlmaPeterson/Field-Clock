import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/work_day.dart';
import '../../models/task.dart';
import '../../utils/time_utils.dart';
import '../../utils/share_utils.dart';
import '../../database/dao/task_dao.dart';
import '../task/task_detail_screen.dart';
import '../../models/session.dart';
import '../../database/dao/session_dao.dart';
import '../history/edit_day_screen.dart';
import '../../database/database_helper.dart';
import '../../models/task_session.dart';
import '../../database/dao/task_session_dao.dart';

class SummaryScreen extends StatefulWidget {
  final WorkDay day;
  final String workerName;

  const SummaryScreen({
    super.key,
    required this.day,
    required this.workerName,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Map<int, List<TaskSession>> _taskSessionsMap = {};
  List<Session> _sessions = [];
  List<Task> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.day.id == null) return;
    final tasks =
        await TaskDao().getByWorkDay(widget.day.id!);
    final sessions =
        await SessionDao().getByWorkDay(widget.day.id!);

    // Load task sessions for total calc
    final Map<int, List<TaskSession>> tsMap = {};
    for (final task in tasks) {
      if (task.id != null) {
        tsMap[task.id!] = await TaskSessionDao()
            .getByTask(task.id!);
      }
    }

    setState(() {
      _tasks = tasks;
      _sessions = sessions;
      _taskSessionsMap = tsMap;
      _loading = false;
    });
  }

  int get _totalMinutes => _sessions
    .where((s) => !s.isActive)
    .fold<int>(0, (sum, s) => sum + s.durationMinutes);

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text('SHARE SUMMARY',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge),
            const SizedBox(height: 20),

            _ShareOption(
              icon: Icons.short_text,
              label: 'Condensed Text',
              sublabel:
                  'Task names + totals only, no details',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.shareText(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                  taskSessions: _taskSessionsMap,
                  condensed: true,
                );
              },
            ),
            const SizedBox(height: 10),

            _ShareOption(
              icon: Icons.article_outlined,
              label: 'Full Text',
              sublabel:
                  'All sessions, times, notes, locations',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.shareText(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                  taskSessions: _taskSessionsMap,
                  condensed: false,
                );
              },
            ),
            const SizedBox(height: 10),

            _ShareOption(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF — Condensed',
              sublabel:
                  'Clean one-pager, easy to approve',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.sharePdf(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                  taskSessions: _taskSessionsMap,
                  condensed: true,
                );
              },
            ),
            const SizedBox(height: 10),

            _ShareOption(
              icon: Icons.picture_as_pdf,
              label: 'PDF — Full',
              sublabel:
                  'All sessions, photos, notes',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.sharePdf(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                  taskSessions: _taskSessionsMap,
                  condensed: false,
                );
              },
            ),

            SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom +
                        8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Summary'),
        actions: [
          // Edit day
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Day',
            onPressed: () async {
              final result = await Navigator.push<dynamic>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditDayScreen(day: widget.day),
                ),
              );
              if (result == 'deleted') {
                if (mounted) Navigator.pop(context, 'deleted');
              } else if (result == true) {
                _load();
              }
            },
          ),
          // Delete day
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            tooltip: 'Delete Day',
            onPressed: _deleteDay,
          ),
          // Share
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showShareSheet,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date header
                Text(
                  TimeUtils.formatDate(day.date),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 16),

                // Clock in/out card
                _DayOverviewCard(
                  day: widget.day,
                  totalMinutes: _totalMinutes,
                  sessions: _sessions,
                  taskCount: _tasks.length,
                ),
                const SizedBox(height: 16),

                // Tasks
                Text("TASKS (${_tasks.length})",
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),

                ..._tasks.map((t) => _TaskDetailCard(
                  task: t,
                  sessions: _taskSessionsMap[t.id ?? 0] ?? [],
                  onEdited: _load,
                )),

                const SizedBox(height: 24),

                // Share button
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share with Manager'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _showShareSheet,
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Future<void> _deleteDay() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete This Day?'),
        content: Text(
          'This will permanently delete ${TimeUtils.formatDate(widget.day.date)}, all its sessions, tasks, and photos. This cannot be undone.',
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (widget.day.id == null) return;

    await DatabaseHelper.instance
        .deleteDayCascade(widget.day.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day deleted')),
      );
      Navigator.pop(context, 'deleted');
    }
  }
}

// ── Day Overview Card ────────────────────────────────────────────────────────

class _DayOverviewCard extends StatelessWidget {
  final WorkDay day;
  final int totalMinutes;
  final List<Session> sessions;
  final int taskCount;

  const _DayOverviewCard({
    required this.day,
    required this.totalMinutes,
    required this.sessions,
    required this.taskCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top stats
            Row(
              children: [
                _StatBlock(
                  label: 'ON SITE',
                  value: TimeUtils.formatDuration(
                      Duration(minutes: totalMinutes)),
                  highlight: true,
                ),
                _StatBlock(
                  label: 'SESSIONS',
                  value: '${sessions.length}',
                ),
                _StatBlock(
                  label: 'TASKS',
                  value: '$taskCount',
                ),
              ],
            ),
            if (sessions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 8),
              ...sessions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text(
                          TimeUtils.formatTime(s.clockInTime),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                        const Text('  →  ',
                            style: TextStyle(
                                color: Colors.grey)),
                        Text(
                          s.clockOutTime != null
                              ? TimeUtils.formatTime(
                                  s.clockOutTime!)
                              : 'Active',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          TimeUtils.formatDuration(
                              s.duration),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (day.clockInLocation != null) ...[
              const SizedBox(height: 8),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 14,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color),
                  const SizedBox(width: 4),
                  Text(day.clockInLocation!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String? photo;
  final bool highlight;

  const _StatBlock({
    required this.label,
    required this.value,
    this.photo,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(photo!),
                  width: 52, height: 52, fit: BoxFit.cover),
            ),
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).textTheme.bodyMedium!.color!,
                  )),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: highlight ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyLarge!.color!,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Task Detail Card ─────────────────────────────────────────────────────────

class _TaskDetailCard extends StatelessWidget {
  final Task task;
  final List<TaskSession> sessions;
  final VoidCallback? onEdited;

  const _TaskDetailCard({
    required this.task,
    required this.sessions,
    this.onEdited,
  });

  int get _totalMinutes => sessions
      .where((s) => !s.isActive)
      .fold<int>(0, (sum, s) => sum + s.durationMinutesRounded);

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).textTheme.bodyMedium?.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final edited = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => TaskDetailScreen(
                    task: task)),
          );
          if (edited == true) {
            onEdited?.call();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // Name + duration + share
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(task.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        if (task.division !=
                            null) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.division!,
                            style: TextStyle(
                              color: primary,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.share,
                        size: 18, color: primary),
                    tooltip: 'Share task',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(),
                    onPressed: () =>
                        ShareUtils.shareTask(
                            task: task,
                            sessions: sessions),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          primary.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      TimeUtils.formatDuration(
                          Duration(
                              minutes: _totalMinutes)),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              // Sessions breakdown
              if (sessions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(
                    height: 1,
                    color:
                        Theme.of(context).dividerColor),
                const SizedBox(height: 8),
                ...sessions
                    .where((s) => !s.isActive)
                    .map((s) => Padding(
                          padding:
                              const EdgeInsets.only(
                                  bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration:
                                    BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  color: primary
                                      .withOpacity(
                                          0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${TimeUtils.formatTime(s.startTime)} → ${TimeUtils.formatTime(s.endTime!)}',
                                style: TextStyle(
                                    color: muted,
                                    fontSize: 13),
                              ),
                              const Spacer(),
                              Text(
                                TimeUtils.formatDuration(
                                    s.durationRounded),
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )),
              ],

              // Location
              if (task.startLocation != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          task.startLocation!,
                          style: TextStyle(
                              color: muted,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ],

              // Notes
              if (task.notes != null &&
                  task.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .dividerColor,
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                  child: Text(task.notes!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String label;
  final String path;

  const _PhotoThumb({required this.label, required this.path});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontSize: 10)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Share Option Row ─────────────────────────────────────────────────────────

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(sublabel,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).textTheme.bodyMedium!.color!),
          ],
        ),
      ),
    );
  }
}