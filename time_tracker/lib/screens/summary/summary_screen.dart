import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/work_day.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../utils/share_utils.dart';
import '../../database/dao/task_dao.dart';
import '../task/task_detail_screen.dart';
import '../../utils/share_utils.dart';
import '../../models/session.dart';
import '../../database/dao/session_dao.dart';

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
    final tasks = await TaskDao().getByWorkDay(widget.day.id!);
    final sessions =
        await SessionDao().getByWorkDay(widget.day.id!);
    setState(() {
      _tasks = tasks;
      _sessions = sessions;
      _loading = false;
    });
  }

  int get _totalMinutes =>
      _tasks.fold(0, (s, t) => s + t.durationMinutesRounded);

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SHARE SUMMARY',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 20),
            _ShareOption(
              icon: Icons.message,
              label: 'Text Only',
              sublabel: 'WhatsApp, SMS, Email — no photos',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.shareText(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                );
              },
            ),
            const SizedBox(height: 12),
            _ShareOption(
              icon: Icons.photo_library,
              label: 'With All Photos',
              sublabel: 'Summary + all before/after images',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.shareWithPhotos(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                  context: context,
                );
              },
            ),
            const SizedBox(height: 12),
            _ShareOption(
              icon: Icons.picture_as_pdf,
              label: 'PDF Report',
              sublabel: 'Professional formatted document',
              onTap: () {
                Navigator.pop(context);
                ShareUtils.sharePdf(
                  day: widget.day,
                  tasks: _tasks,
                  sessions: _sessions,
                  workerName: widget.workerName,
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
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
                  taskCount: _tasks.where((t) => t.isComplete).length,
                ),
                const SizedBox(height: 16),

                // Tasks
                Text("TASKS (${_tasks.where((t) => t.isComplete).length})",
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 12),

                ..._tasks
                  .where((t) => t.isComplete)
                  .map((t) => _TaskDetailCard(task: t, onEdited: _load)),

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
  final VoidCallback? onEdited;

  const _TaskDetailCard({required this.task, this.onEdited});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final edited = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => TaskDetailScreen(task: task)),
          );
          if (edited == true) onEdited?.call();
        },
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Task name + duration
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(task.name,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    // Share this task
                    IconButton(
                      icon: Icon(Icons.share,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      tooltip: 'Share this task',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _shareTask(context, task),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        TimeUtils.formatDuration(task.durationRounded),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Time range
                Row(
                children: [
                    Icon(Icons.access_time,
                        size: 14, color: Theme.of(context).textTheme.bodyMedium!.color!),
                    const SizedBox(width: 4),
                    Text(
                    '${TimeUtils.formatTime(task.startTime)} → ${task.endTime != null ? TimeUtils.formatTime(task.endTime!) : 'In progress'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
                ),

                // Location
                if (task.startLocation != null) ...[
                const SizedBox(height: 4),
                Row(
                    children: [
                    Icon(Icons.location_on,
                        size: 14, color: Theme.of(context).textTheme.bodyMedium!.color!),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(task.startLocation!,
                            style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    ],
                ),
                ],

                // Notes
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(task.notes!,
                        style: Theme.of(context).textTheme.bodyMedium),
                ),
                ],

                // Before / After photos
                if (task.startPhoto != null || task.endPhoto != null) ...[
                const SizedBox(height: 12),
                Row(
                    children: [
                    if (task.startPhoto != null)
                        _PhotoThumb(
                            label: 'BEFORE', path: task.startPhoto!),
                    if (task.startPhoto != null && task.endPhoto != null)
                        const SizedBox(width: 8),
                    if (task.endPhoto != null)
                        _PhotoThumb(
                            label: 'AFTER', path: task.endPhoto!),
                    ],
                ),
                ],
            ],
            ),
        ),
      ),
    );
  }

  void _shareTask(BuildContext context, Task task) {
    ShareUtils.shareTask(task: task);
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