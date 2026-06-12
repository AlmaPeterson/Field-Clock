import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/work_day_provider.dart';
import '../../screens/camera/camera_screen.dart';
import '../../utils/time_utils.dart';
import '../../utils/location_utils.dart';
import '../../widgets/task_name_dialog.dart';
import '../../theme/app_theme.dart';
import '../summary/summary_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/prefs_utils.dart';
import '../task/task_detail_screen.dart';
import '../jobs/jobs_screen.dart';
import '../../database/dao/job_dao.dart';
import 'package:flutter/scheduler.dart';
import '../../widgets/session_edit_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver{
  String _workerName = 'Worker';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadName();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadName();
      context.read<WorkDayProvider>().loadToday();
    }
  }

  Future<void> _loadName() async {
    final name = await PrefsUtils.getWorkerName();
    setState(() => _workerName = name);
  }

  Future<void> _handleClockIn(
      BuildContext context, WorkDayProvider provider) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
          builder: (_) => const CameraScreen(mode: CaptureMode.clockIn)),
    );
    if (result == null) return; // user cancelled (X button)
    final photoPath = result == 'skip' ? null : result;
    final location = await LocationUtils.getCurrentLocation();
    final jobId = await _pickJob(context);
    await provider.clockIn(
        photoPath: photoPath, location: location, jobId: jobId);
  }

  Future<void> _handleClockOut(
      BuildContext context, WorkDayProvider provider) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
          builder: (_) => const CameraScreen(mode: CaptureMode.clockOut)),
    );
    if (result == null) return;
    final photoPath = result == 'skip' ? null : result;
    final location = await LocationUtils.getCurrentLocation();
    await provider.clockOut(photoPath: photoPath, location: location);
  }

  Future<void> _handleStartTask(
      BuildContext context, WorkDayProvider provider) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
          builder: (_) => const CameraScreen(mode: CaptureMode.taskStart)),
    );
    if (result == null) return;
    final photoPath = result == 'skip' ? null : result;
    final location = await LocationUtils.getCurrentLocation();
    await provider.startTask(photoPath: photoPath, location: location);
  }

  Future<void> _handleEndTask(
      BuildContext context, WorkDayProvider provider) async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          mode: CaptureMode.taskEnd,
          taskName: provider.activeTask?.name,
        ),
      ),
    );
    if (result == null) return;
    final photoPath = result == 'skip' ? null : result;
    final location = await LocationUtils.getCurrentLocation();
    if (!context.mounted) return;

    // Wait for the push pop animation to fully complete
    await Future.delayed(const Duration(milliseconds: 150));

    if (!context.mounted) return;
    final taskResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TaskNameDialog(),
    );
    await provider.endTask(
      name: taskResult?['name'] ?? 'Unnamed Task',
      division: taskResult?['division'],
      notes: taskResult?['notes'],
      photoPath: photoPath,
      location: location,
    );
  }

  Future<int?> _pickJob(BuildContext context) async {
    final jobs = await JobDao().getActive();
    if (jobs.isEmpty) return null;
    if (!context.mounted) return null;

    return showModalBottomSheet<int>(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text('SELECT JOB',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 16),
            ...jobs.map((job) => ListTile(
                    title: Text(job.name,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge!.color!)),
                    subtitle: job.address != null
                        ? Text(job.address!,
                            style: TextStyle(
                                color: Theme.of(context).textTheme.bodyMedium!.color!))
                        : null,
                    trailing: Icon(Icons.chevron_right,
                        color: Theme.of(context).textTheme.bodyMedium!.color!),
                    onTap: () => Navigator.pop(context, job.id),
                )),
            ListTile(
                title: Text('No specific job',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!)),
                onTap: () => Navigator.pop(context, null),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldClock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.work_outline),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const JobsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
              // Reload name after returning from settings
              _loadName();
            },
          ),
        ],
      ),
      body: Consumer<WorkDayProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                TimeUtils.formatDate(DateTime.now()),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 16),
              _ClockCard(
                provider: provider,
                onClockIn: () => _handleClockIn(context, provider),
                onClockOut: () => _handleClockOut(context, provider),
              ),
              const SizedBox(height: 16),
              if (provider.isClockedIn && !provider.today!.isComplete) ...[
                _TaskActionCard(
                  provider: provider,
                  onStartTask: () => _handleStartTask(context, provider),
                  onEndTask: () => _handleEndTask(context, provider),
                ),
                const SizedBox(height: 16),
              ],
              if (provider.todayTasks.isNotEmpty) ...[
                _TaskListCard(provider: provider),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.summarize,
                        color: Theme.of(context).colorScheme.primary),
                    label: Text('View & Share Daily Summary',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SummaryScreen(
                          day: provider.today!,
                          workerName: _workerName,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Clock Card ───────────────────────────────────────────────────────────────

class _ClockCard extends StatelessWidget {
  final WorkDayProvider provider;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const _ClockCard({
    required this.provider,
    required this.onClockIn,
    required this.onClockOut,
  });

  Future<void> _handleUndo(
      BuildContext context, WorkDayProvider provider) async {
    final isClockedIn = provider.isClockedIn;
    final hasCompletedSessions = provider.todaySessions
        .any((s) => !s.isActive);

    final message = isClockedIn
        ? 'Cancel this clock-in? Any active task will be lost.'
        : hasCompletedSessions
            ? 'Undo your last clock-out? You will be clocked back in.'
            : 'Delete today\'s record entirely? This cannot be undone.';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          isClockedIn ? 'Cancel Clock-In?' : 'Undo Clock-Out?',
          style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.color),
        ),
        content: Text(message,
            style: TextStyle(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (isClockedIn) {
      await provider.cancelActiveSession();
    } else if (hasCompletedSessions) {
      await provider.undoClockOut();
    } else {
      await provider.resetDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = provider.today;
    final isClockedIn = provider.isClockedIn;
    final sessions = provider.todaySessions;
    final totalMinutes = provider.totalSessionMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isClockedIn
                        ? AppColors.success
                        : today != null
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isClockedIn
                      ? 'CLOCKED IN'
                      : today != null
                          ? 'CLOCKED OUT'
                          : 'NOT CLOCKED IN',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                        color: isClockedIn
                            ? AppColors.success
                            : today != null
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                : Colors.grey,
                      ),
                ),
                const Spacer(),
                // Undo button — show whenever there's a today record
                if (today != null)
                  IconButton(
                    icon: const Icon(Icons.undo, size: 18),
                    tooltip: isClockedIn
                        ? 'Cancel clock-in'
                        : 'Undo clock-out',
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () =>
                        _handleUndo(context, provider),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Session list
            if (sessions.isNotEmpty) ...[
              ...sessions.map((s) => GestureDetector(
                onTap: () async {
                  final result =
                      await showDialog<Map<String, DateTime?>>(
                    context: context,
                    builder: (_) =>
                        SessionEditDialog(session: s),
                  );
                  if (result == null) return;
                  await context
                      .read<WorkDayProvider>()
                      .editSessionTime(
                        session: s,
                        newClockIn: result['clockIn'],
                        newClockOut: result['clockOut'],
                      );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .dividerColor
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (s.clockInPhoto != null)
                        _MiniPhoto(path: s.clockInPhoto!)
                      else
                        const _MiniPhotoPlaceholder(),
                      const SizedBox(width: 8),
                      Text(
                        TimeUtils.formatTime(s.clockInTime),
                        style:
                            Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Text('  →  ',
                          style: TextStyle(color: Colors.grey)),
                      if (s.isActive)
                        Text('Now',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ))
                      else ...[
                        if (s.clockOutPhoto != null)
                          _MiniPhoto(path: s.clockOutPhoto!)
                        else
                          const _MiniPhotoPlaceholder(),
                        const SizedBox(width: 8),
                        Text(
                          TimeUtils.formatTime(s.clockOutTime!),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                        const Spacer(),
                        Text(
                          TimeUtils.formatDuration(s.duration),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.edit,
                            size: 12,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color),
                      ],
                    ],
                  ),
                ),
              )),

              // Total
              if (sessions.length > 1 ||
                  sessions.any((s) => !s.isActive)) ...[
                Divider(
                    color: Theme.of(context).dividerColor),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total on site',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium),
                    Text(
                      TimeUtils.formatDuration(Duration(
                          minutes: totalMinutes)),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Clock in / out button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(
                    isClockedIn ? Icons.logout : Icons.login),
                label: Text(
                    isClockedIn ? 'Clock Out' : 'Clock In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClockedIn
                      ? AppColors.error
                      : Theme.of(context)
                          .colorScheme
                          .primary,
                ),
                onPressed:
                    isClockedIn ? onClockOut : onClockIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPhoto extends StatelessWidget {
  final String path;
  const _MiniPhoto({required this.path});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(path),
          width: 28,
          height: 28,
          fit: BoxFit.cover,
        ),
      );
}

class _MiniPhotoPlaceholder extends StatelessWidget {
  const _MiniPhotoPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(Icons.camera_alt,
            size: 14,
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color),
      );
}

// ── Task Action Card ─────────────────────────────────────────────────────────

class _TaskActionCard extends StatelessWidget {
  final WorkDayProvider provider;
  final VoidCallback onStartTask;
  final VoidCallback onEndTask;

  const _TaskActionCard({
    required this.provider,
    required this.onStartTask,
    required this.onEndTask,
  });

  @override
  Widget build(BuildContext context) {
    final activeTask = provider.activeTask;

    if (activeTask != null) {
      return Card(
        color: Theme.of(context).dividerColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACTIVE TASK',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.success,
                  )),
              const SizedBox(height: 4),
              Text(
                'Started ${TimeUtils.formatTime(activeTask.startTime)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take After Photo & End Task'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary),
                  onPressed: onEndTask,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.camera_alt),
        label: const Text('Take Before Photo & Start Task'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
        onPressed: onStartTask,
      ),
    );
  }
}

// ── Task List Card ───────────────────────────────────────────────────────────

class _TaskListCard extends StatelessWidget {
  final WorkDayProvider provider;
  const _TaskListCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final tasks = provider.todayTasks.where((t) => t.isComplete).toList();
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TODAY'S TASKS",
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            ...tasks.map((task) => _TaskRow(task: task)),
            Divider(color: Theme.of(context).dividerColor, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total hours',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  TimeUtils.formatDuration(Duration(
                    minutes: tasks.fold(
                        0, (s, t) => s + t.durationMinutesRounded),
                  )),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TaskDetailScreen(task: task)),
        );
        // Provider reloads automatically via loadToday
        if (context.mounted) {
          context.read<WorkDayProvider>().loadToday();
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
            children: [
            // Before photo thumbnail
            if (task.startPhoto != null)
                ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                    File(task.startPhoto!),
                    width: 40, height: 40, fit: BoxFit.cover,
                ),
                )
            else
                Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.image_not_supported,
                    color: Theme.of(context).textTheme.bodyMedium!.color!, size: 18),
                ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(task.name,
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text(
                    '${TimeUtils.formatTime(task.startTime)} → ${TimeUtils.formatTime(task.endTime!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
                ),
            ),
            Text(
                TimeUtils.formatDuration(task.durationRounded),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                ),
            ),
            ],
        ),
        ),
    );
  }
}

// ── Time + Photo Row ─────────────────────────────────────────────────────────

class _TimePhotoRow extends StatelessWidget {
  final String label;
  final String time;
  final String? photoPath;

  const _TimePhotoRow({
    required this.label,
    required this.time,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (photoPath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(photoPath!),
              width: 36, height: 36, fit: BoxFit.cover,
            ),
          )
        else
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        const SizedBox(width: 10),
        Text(
          '$label:  $time',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}