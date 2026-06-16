import 'package:flutter/material.dart';
import '../../database/dao/work_day_dao.dart';
import '../../database/dao/session_dao.dart';
import '../../database/dao/task_dao.dart';
import '../../database/dao/task_photo_dao.dart';
import '../../database/dao/job_dao.dart';
import '../../database/database_helper.dart';
import '../../models/work_day.dart';
import '../../models/session.dart';
import '../../models/task.dart';
import '../../models/task_photo.dart';
import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../task/task_detail_screen.dart';
import '../../models/task_session.dart';
import '../../database/dao/task_session_dao.dart';
import '../../widgets/task_entry_card.dart';

class EditDayScreen extends StatefulWidget {
  final WorkDay day;

  const EditDayScreen({super.key, required this.day});

  @override
  State<EditDayScreen> createState() =>
      _EditDayScreenState();
}

class _EditDayScreenState extends State<EditDayScreen> {
  late DateTime _selectedDate;
  List<Session> _existingSessions = [];
  List<Task> _existingTasks = [];
  final List<_NewSessionEntry> _newSessions = [];
  final List<TaskEntryData> _newTasks = [];
  List<Job> _jobs = [];
  Job? _selectedJob;
  bool _saving = false;

  final _sessionDao = SessionDao();
  final _taskDao = TaskDao();
  final _taskPhotoDao = TaskPhotoDao();
  final _jobDao = JobDao();

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.day.date;
    _load();
  }

  Future<void> _load() async {
    final sessions =
        await _sessionDao.getByWorkDay(widget.day.id!);
    final tasks =
        await _taskDao.getByWorkDay(widget.day.id!);
    final jobs = await _jobDao.getAll();

    Job? currentJob;
    if (widget.day.jobId != null) {
      currentJob =
          await _jobDao.getById(widget.day.jobId!);
    }

    setState(() {
      _existingSessions = sessions;
      _existingTasks = tasks;
      _jobs = jobs;
      _selectedJob = currentJob;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── Existing session actions ─────────────────────

  Future<void> _editExistingSession(
    Session session) async {
      final result =
          await showDialog<Map<String, TimeOfDay?>>(
        context: context,
        builder: (_) =>
            _SessionTimeDialog(session: session),
      );
      if (result == null) return;

      final newIn = result['clockIn'];
      final newOut = result['clockOut'];
      if (newIn == null) return;

      final clockIn = _toDateTime(_selectedDate, newIn);
      final clockOut = newOut != null
          ? _toDateTime(_selectedDate, newOut)
          : session.clockOutTime;

      int duration = session.durationMinutes;
      if (clockOut != null) {
        final raw = clockOut.difference(clockIn);
        duration =
            TimeUtils.roundToNearest15(raw).inMinutes;
      }

      final updated = Session(
        id: session.id,
        workDayId: session.workDayId,
        clockInTime: clockIn,
        clockInPhoto: session.clockInPhoto,
        clockInLocation: session.clockInLocation,
        clockOutTime: clockOut,
        clockOutPhoto: session.clockOutPhoto,
        clockOutLocation: session.clockOutLocation,
        durationMinutes: duration,
      );

      await _sessionDao.update(updated);
      await _load();
    }

  Future<void> _deleteExistingSession(
      Session session) async {
    final confirm = await _confirmDialog(
      title: 'Delete Session?',
      message:
          'This clock-in/out session will be removed.',
    );
    if (confirm != true) return;
    await _sessionDao.delete(session.id!);
    await _load();
  }

  // ── Existing task actions ────────────────────────

  Future<void> _editExistingTask(Task task) async {
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => TaskDetailScreen(task: task)),
    );
    if (edited == true) await _load();
  }

  Future<void> _deleteExistingTask(Task task) async {
    final confirm = await _confirmDialog(
      title: 'Delete Task?',
      message: '"${task.name}" will be permanently removed.',
    );
    if (confirm != true) return;
    if (task.id != null) {
      await _taskPhotoDao.deleteByTask(task.id!);
      await _taskDao.delete(task.id!);
    }
    await _load();
  }

  // ── Save ─────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Save new sessions
      for (final s in _newSessions) {
        if (s.clockIn == null) continue;
        final clockIn =
            _toDateTime(_selectedDate, s.clockIn!);
        final clockOut = s.clockOut != null
            ? _toDateTime(_selectedDate, s.clockOut!)
            : null;
        int duration = 0;
        if (clockOut != null) {
          final raw = clockOut.difference(clockIn);
          duration =
              TimeUtils.roundToNearest15(raw).inMinutes;
        }
        await _sessionDao.insert(Session(
          workDayId: widget.day.id!,
          clockInTime: clockIn,
          clockOutTime: clockOut,
          durationMinutes: duration,
        ));
      }

      // Recalculate and save day with updated date, job, and totals
      final allSessions = await _sessionDao
          .getByWorkDay(widget.day.id!);
      final totalMinutes = allSessions
          .where((s) => !s.isActive)
          .fold<int>(0, (sum, s) => sum + s.durationMinutes);

      await WorkDayDao().update(WorkDay(
        id: widget.day.id,
        jobId: _selectedJob?.id,
        date: _selectedDate,
        clockInTime: widget.day.clockInTime,
        clockInPhoto: widget.day.clockInPhoto,
        clockInLocation: widget.day.clockInLocation,
        totalMinutesRaw: totalMinutes,
        totalMinutesRounded: totalMinutes,
      ));

      // Save new tasks
      for (final t in _newTasks) {
        final validTimes =
            t.times.where((e) => e.startTime != null).toList();
        if (validTimes.isEmpty) continue;
        final task = Task(
          workDayId: widget.day.id!,
          name: t.name.isEmpty ? 'Unnamed Task' : t.name,
          division: t.division,
          notes: t.notes,
          startTime: _toDateTime(_selectedDate, validTimes.first.startTime!),
        );
        final taskId = await _taskDao.insert(task);

        for (final te in validTimes) {
          final startTime = _toDateTime(_selectedDate, te.startTime!);
          final endTime = te.endTime != null
              ? _toDateTime(_selectedDate, te.endTime!)
              : null;
          int rawMin = 0;
          int roundedMin = 0;
          if (endTime != null) {
            final raw = endTime.difference(startTime);
            rawMin = raw.inMinutes;
            roundedMin = TimeUtils.roundToNearest15(raw).inMinutes;
          }
          await TaskSessionDao().insert(TaskSession(
            taskId: taskId,
            startTime: startTime,
            endTime: endTime,
            durationMinutesRaw: rawMin,
            durationMinutesRounded: roundedMin,
          ));
        }

        for (final photo in t.photos) {
          await _taskPhotoDao.insert(TaskPhoto(
            taskId: taskId,
            photoPath: photo.path,
            photoType: photo.type,
            createdAt: DateTime.now(),
          ));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Day updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  // ── Delete entire day ─────────────────────────────

  Future<void> _deleteDay() async {
    final confirm = await _confirmDialog(
      title: 'Delete Entire Day?',
      message:
          'This will permanently delete ${TimeUtils.formatDate(_selectedDate)}, all its sessions, tasks, and photos. This cannot be undone.',
      destructive: true,
    );
    if (confirm != true) return;

    await DatabaseHelper.instance
        .deleteDayCascade(widget.day.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day deleted')),
      );
      // Pop twice — EditDayScreen and SummaryScreen
      Navigator.pop(context, 'deleted');
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    bool destructive = false,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(title,
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.color)),
          content: Text(message,
              style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color)),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: Text(
                destructive ? 'Delete' : 'Confirm',
                style: TextStyle(
                  color: destructive
                      ? Theme.of(context)
                          .colorScheme
                          .error
                      : Theme.of(context)
                          .colorScheme
                          .primary,
                ),
              ),
            ),
          ],
        ),
      );

  DateTime _toDateTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day,
          time.hour, time.minute);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final error = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Day'),
        actions: [
          // Delete day
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: error),
            tooltip: 'Delete Day',
            onPressed: _deleteDay,
          ),
          // Save
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary))
                : Text('Save',
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Date ────────────────────────────────────
          _SectionLabel('DATE'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TimeUtils.formatDate(_selectedDate),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  Icon(Icons.calendar_today,
                      color: primary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Job ──────────────────────────────────────
          if (_jobs.isNotEmpty) ...[
            _SectionLabel('JOB'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Job?>(
                  value: _selectedJob,
                  isExpanded: true,
                  dropdownColor:
                      Theme.of(context).cardColor,
                  hint: Text('No job',
                      style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color)),
                  items: [
                    DropdownMenuItem<Job?>(
                      value: null,
                      child: Text('No job',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                    ),
                    ..._jobs.map((job) =>
                        DropdownMenuItem<Job?>(
                          value: job,
                          child: Text(job.name,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color)),
                        )),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedJob = val),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Existing Sessions ────────────────────────
          _SectionLabel('SESSIONS'),
          const SizedBox(height: 8),
          if (_existingSessions.isEmpty)
            _EmptyHint('No sessions recorded'),
          ..._existingSessions.map((s) =>
              _ExistingSessionCard(
                session: s,
                onEdit: () => _editExistingSession(s),
                onDelete: () =>
                    _deleteExistingSession(s),
              )),

          // New sessions
          ..._newSessions.asMap().entries.map((e) =>
              _NewSessionCard(
                index: e.key,
                entry: e.value,
                date: _selectedDate,
                onRemove: () => setState(
                    () => _newSessions.removeAt(e.key)),
                onChanged: () => setState(() {}),
              )),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.add, color: primary),
            label: Text('Add Session',
                style: TextStyle(color: primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10)),
            ),
            onPressed: () => setState(
                () => _newSessions
                    .add(_NewSessionEntry())),
          ),
          const SizedBox(height: 24),

          // ── Existing Tasks ───────────────────────────
          _SectionLabel('TASKS'),
          const SizedBox(height: 8),
          if (_existingTasks.isEmpty)
            _EmptyHint('No tasks recorded'),
          ..._existingTasks.map((t) =>
              _ExistingTaskCard(
                task: t,
                onEdit: () => _editExistingTask(t),
                onDelete: () =>
                    _deleteExistingTask(t),
              )),

          // New tasks
          ..._newTasks.asMap().entries.map((e) =>
              TaskEntryCard(
                index: e.key,
                entry: e.value,
                onRemove: () => setState(
                    () => _newTasks.removeAt(e.key)),
                onChanged: () => setState(() {}),
              )),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.add, color: primary),
            label: Text('Add Task',
                style: TextStyle(color: primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10)),
            ),
            onPressed: () =>
                setState(() => _newTasks
                    .add(TaskEntryData())),
          ),
          const SizedBox(height: 32),

          // Delete day button
          OutlinedButton.icon(
            icon: Icon(Icons.delete_forever,
                color: error),
            label: Text('Delete Entire Day',
                style: TextStyle(color: error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: error),
              padding: const EdgeInsets.symmetric(
                  vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12)),
            ),
            onPressed: _deleteDay,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Existing session card ─────────────────────────────────────────────────────

class _ExistingSessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExistingSessionCard({
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: session.isActive
                    ? AppColors.success
                    : primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${TimeUtils.formatTime(session.clockInTime)} → ${session.clockOutTime != null ? TimeUtils.formatTime(session.clockOutTime!) : 'Active'}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                  if (!session.isActive)
                    Text(
                      TimeUtils.formatDuration(
                          session.duration),
                      style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit,
                  size: 18,
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .error),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Existing task card ────────────────────────────────────────────────────────

class _ExistingTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExistingTaskCard({
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).textTheme.bodyMedium?.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(task.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge),
                  if (task.division != null)
                    Text(task.division!,
                        style: TextStyle(
                            color: primary,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w600)),
                  Text(
                    'Started ${TimeUtils.formatTime(task.startTime)}',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit,
                  size: 18, color: muted),
              onPressed: onEdit,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .error),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── New session entry ─────────────────────────────────────────────────────────

class _NewSessionEntry {
  TimeOfDay? clockIn;
  TimeOfDay? clockOut;
}

class _NewSessionCard extends StatelessWidget {
  final int index;
  final _NewSessionEntry entry;
  final DateTime date;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _NewSessionCard({
    required this.index,
    required this.entry,
    required this.date,
    required this.onRemove,
    required this.onChanged,
  });

  Future<void> _pickTime(
      BuildContext context, bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isIn
          ? (entry.clockIn ??
              const TimeOfDay(hour: 7, minute: 0))
          : (entry.clockOut ??
              const TimeOfDay(hour: 16, minute: 0)),
    );
    if (picked != null) {
      if (isIn) {
        entry.clockIn = picked;
      } else {
        entry.clockOut = picked;
      }
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text('New Session',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .error),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TimeTap(
                    label: 'Clock In',
                    time: entry.clockIn,
                    color: AppColors.success,
                    onTap: () =>
                        _pickTime(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TimeTap(
                    label: 'Clock Out',
                    time: entry.clockOut,
                    color: AppColors.error,
                    onTap: () =>
                        _pickTime(context, false),
                  ),
                ),
              ],
            ),
            if (entry.clockIn != null &&
                entry.clockOut != null) ...[
              const SizedBox(height: 8),
              Text(
                _duration(
                    entry.clockIn!, entry.clockOut!),
                style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _duration(TimeOfDay i, TimeOfDay o) {
    final diff = (o.hour * 60 + o.minute) -
        (i.hour * 60 + i.minute);
    if (diff <= 0) return 'Check times';
    return TimeUtils.formatDuration(
        TimeUtils.roundToNearest15(
            Duration(minutes: diff)));
  }
}

// ── Session time edit dialog ──────────────────────────────────────────────────

class _SessionTimeDialog extends StatefulWidget {
  final Session session;
  const _SessionTimeDialog({required this.session});

  @override
  State<_SessionTimeDialog> createState() =>
      _SessionTimeDialogState();
}

class _SessionTimeDialogState
    extends State<_SessionTimeDialog> {
  late TimeOfDay _clockIn;
  TimeOfDay? _clockOut;

  @override
  void initState() {
    super.initState();
    _clockIn = TimeOfDay.fromDateTime(
        widget.session.clockInTime);
    _clockOut = widget.session.clockOutTime != null
        ? TimeOfDay.fromDateTime(
            widget.session.clockOutTime!)
        : null;
  }

  Future<void> _pick(bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isIn
          ? _clockIn
          : (_clockOut ??
              const TimeOfDay(hour: 16, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isIn) {
          _clockIn = picked;
        } else {
          _clockOut = picked;
        }
      });
    }
  }

  int get _roundedMin {
    if (_clockOut == null) return 0;
    final diff =
        (_clockOut!.hour * 60 + _clockOut!.minute) -
            (_clockIn.hour * 60 + _clockIn.minute);
    if (diff <= 0) return 0;
    return TimeUtils.roundToNearest15(
        Duration(minutes: diff)).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text('EDIT SESSION',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge),
            const SizedBox(height: 20),
            TimeTap(
              label: 'Clock In',
              time: _clockIn,
              color: AppColors.success,
              onTap: () => _pick(true),
            ),
            const SizedBox(height: 10),
            TimeTap(
              label: 'Clock Out',
              time: _clockOut,
              color: AppColors.error,
              onTap: widget.session.clockOutTime !=
                      null
                  ? () => _pick(false)
                  : null,
            ),
            if (_clockOut != null &&
                _roundedMin > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Duration (rounded)',
                        style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                            fontSize: 13)),
                    Text(
                      TimeUtils.formatDuration(
                          Duration(
                              minutes: _roundedMin)),
                      style: TextStyle(
                          color: primary,
                          fontWeight:
                              FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pop(context, null),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, {
                      'clockIn': _clockIn,
                      'clockOut': _clockOut,
                    }),
                    child: const Text('Save'),
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

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context).textTheme.labelLarge);
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium,
            textAlign: TextAlign.center),
      );
}
