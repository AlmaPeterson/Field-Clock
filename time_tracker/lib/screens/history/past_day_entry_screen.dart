import 'package:flutter/material.dart';
import '../../database/dao/work_day_dao.dart';
import '../../database/dao/session_dao.dart';
import '../../database/dao/task_dao.dart';
import '../../database/dao/task_photo_dao.dart';
import '../../database/dao/job_dao.dart';
import '../../models/work_day.dart';
import '../../models/session.dart';
import '../../models/task.dart';
import '../../models/task_photo.dart';
import '../../models/job.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../models/task_session.dart';
import '../../database/dao/task_session_dao.dart';
import '../../widgets/task_entry_card.dart';

class PastDayEntryScreen extends StatefulWidget {
  const PastDayEntryScreen({super.key});

  @override
  State<PastDayEntryScreen> createState() =>
      _PastDayEntryScreenState();
}

class _PastDayEntryScreenState
    extends State<PastDayEntryScreen> {
  DateTime _selectedDate = DateTime.now().subtract(
      const Duration(days: 1));
  final List<_SessionEntry> _sessions = [];
  final List<TaskEntryData> _tasks = [];
  List<Job> _jobs = [];
  Job? _selectedJob;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadJobs();
    _addSession(); // start with one session
  }

  Future<void> _loadJobs() async {
    final jobs = await JobDao().getActive();
    setState(() => _jobs = jobs);
  }

  void _addSession() {
    setState(() => _sessions.add(_SessionEntry()));
  }

  void _addTask() {
    setState(() => _tasks.add(TaskEntryData()));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    // Validate at least one session
    if (_sessions.isEmpty ||
        _sessions.first.clockIn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please add at least one clock-in time')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
    // Check for duplicate
    final existing =
        await WorkDayDao().getByDate(_selectedDate);
    if (existing != null && mounted) {
        setState(() => _saving = false);
        final overwrite = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text('Day Already Exists'),
            content: Text(
                'A record for ${TimeUtils.formatDate(_selectedDate)} already exists. Do you want to add to it or cancel?'),
            actions: [
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, false),
                child: const Text('Cancel'),
            ),
            TextButton(
                onPressed: () =>
                    Navigator.pop(context, true),
                child: Text('Add Anyway',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .primary)),
            ),
            ],
        ),
        );
        if (overwrite != true) return;
        setState(() => _saving = true);
    }

    // Create work day
      final firstSession = _sessions.first;
      final day = WorkDay(
        date: _selectedDate,
        jobId: _selectedJob?.id,
        clockInTime: _toDateTime(
            _selectedDate, firstSession.clockIn!),
        clockInLocation: null,
        totalMinutesRaw: 0,
        totalMinutesRounded: 0,
      );
      final dayId = await WorkDayDao().insert(day);

      // Create sessions
      int totalMinutes = 0;
      for (final s in _sessions) {
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
          totalMinutes += duration;
        }
        await SessionDao().insert(Session(
          workDayId: dayId,
          clockInTime: clockIn,
          clockOutTime: clockOut,
          durationMinutes: duration,
        ));
      }

      // Update day totals
      final updatedDay = WorkDay(
        id: dayId,
        date: _selectedDate,
        jobId: _selectedJob?.id,
        clockInTime: _toDateTime(
            _selectedDate, firstSession.clockIn!),
        totalMinutesRaw: totalMinutes,
        totalMinutesRounded: totalMinutes,
      );
      await WorkDayDao().update(updatedDay);

      // Create tasks
      for (final t in _tasks) {
        final validTimes =
            t.times.where((e) => e.startTime != null).toList();
        if (validTimes.isEmpty) continue;
        final task = Task(
          workDayId: dayId,
          name: t.name.isEmpty ? 'Unnamed Task' : t.name,
          division: t.division,
          notes: t.notes,
          startTime: _toDateTime(
              _selectedDate, validTimes.first.startTime!),
        );
        final taskId = await TaskDao().insert(task);

        for (final te in validTimes) {
          final startTime =
              _toDateTime(_selectedDate, te.startTime!);
          final endTime = te.endTime != null
              ? _toDateTime(_selectedDate, te.endTime!)
              : null;
          int rawMin = 0;
          int roundedMin = 0;
          if (endTime != null) {
            final raw = endTime.difference(startTime);
            rawMin = raw.inMinutes;
            roundedMin =
                TimeUtils.roundToNearest15(raw).inMinutes;
          }
          await TaskSessionDao().insert(TaskSession(
            taskId: taskId,
            startTime: startTime,
            endTime: endTime,
            durationMinutesRaw: rawMin,
            durationMinutesRounded: roundedMin,
          ));
        }

        // Save photos
        for (final photo in t.photos) {
          await TaskPhotoDao().insert(TaskPhoto(
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
              content: Text('Past day saved successfully')),
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

  DateTime _toDateTime(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day,
          time.hour, time.minute);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Past Day'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary))
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
          // ── Date picker ───────────────────────────────
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

          // ── Job picker ────────────────────────────────
          if (_jobs.isNotEmpty) ...[
            _SectionLabel('JOB (OPTIONAL)'),
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
                  hint: Text('No job selected',
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

          // ── Sessions ──────────────────────────────────
          _SectionLabel('CLOCK IN / OUT SESSIONS'),
          const SizedBox(height: 8),
          ..._sessions.asMap().entries.map((e) =>
              _SessionEntryCard(
                index: e.key,
                entry: e.value,
                onRemove: _sessions.length > 1
                    ? () => setState(
                        () => _sessions.removeAt(e.key))
                    : null,
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(Icons.add, color: primary),
            label: Text('Add Another Session',
                style: TextStyle(color: primary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _addSession,
          ),
          const SizedBox(height: 24),

          // ── Tasks ─────────────────────────────────────
          _SectionLabel('TASKS'),
          const SizedBox(height: 8),
          if (_tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('No tasks added yet',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                  textAlign: TextAlign.center),
            ),
          ..._tasks.asMap().entries.map((e) =>
              TaskEntryCard(
                index: e.key,
                entry: e.value,
                onRemove: () => setState(
                    () => _tasks.removeAt(e.key)),
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _addTask,
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 16)),
            child: const Text('Save Past Day'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Session Entry Card ────────────────────────────────────────────────────────

class _SessionEntry {
  TimeOfDay? clockIn;
  TimeOfDay? clockOut;
}

class _SessionEntryCard extends StatelessWidget {
  final int index;
  final _SessionEntry entry;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _SessionEntryCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  Future<void> _pickTime(
      BuildContext context, bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isIn
          ? (entry.clockIn ?? const TimeOfDay(hour: 7, minute: 0))
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
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text('Session ${index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge),
                if (onRemove != null)
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .error),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(),
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
                _duration(entry.clockIn!,
                    entry.clockOut!),
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
    final inMin = i.hour * 60 + i.minute;
    final outMin = o.hour * 60 + o.minute;
    final diff = outMin - inMin;
    if (diff <= 0) return 'Check times';
    final rounded = TimeUtils.roundToNearest15(
        Duration(minutes: diff));
    return TimeUtils.formatDuration(rounded);
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}
