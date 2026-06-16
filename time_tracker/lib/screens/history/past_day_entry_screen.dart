import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../utils/divisions.dart';
import 'dart:io';
import '../../models/task_session.dart';
import '../../database/dao/task_session_dao.dart';

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
  final List<_TaskEntry> _tasks = [];
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
    setState(() => _tasks.add(_TaskEntry()));
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
        if (t.startTime == null) continue;
        final startTime =
            _toDateTime(_selectedDate, t.startTime!);
        final endTime = t.endTime != null
            ? _toDateTime(_selectedDate, t.endTime!)
            : null;
        int rawMin = 0;
        int roundedMin = 0;
        if (endTime != null) {
          final raw = endTime.difference(startTime);
          rawMin = raw.inMinutes;
          roundedMin =
              TimeUtils.roundToNearest15(raw).inMinutes;
        }
        final task = Task(
          workDayId: dayId,
          name: t.name.isEmpty ? 'Unnamed Task' : t.name,
          division: t.division,
          notes: t.notes,
          startTime: startTime,
        );
        final taskId = await TaskDao().insert(task);

        if (endTime != null) {
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
              _TaskEntryCard(
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
                  child: _TimeTap(
                    label: 'Clock In',
                    time: entry.clockIn,
                    color: AppColors.success,
                    onTap: () =>
                        _pickTime(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeTap(
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

// ── Task Entry Card ───────────────────────────────────────────────────────────

class _TaskPhoto {
  final String path;
  final String type;
  _TaskPhoto({required this.path, required this.type});
}

class _TaskEntry {
  String name = '';
  String? division;
  String? notes;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  List<_TaskPhoto> photos = [];
}

class _TaskEntryCard extends StatefulWidget {
  final int index;
  final _TaskEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _TaskEntryCard({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_TaskEntryCard> createState() =>
      _TaskEntryCardState();
}

class _TaskEntryCardState
    extends State<_TaskEntryCard> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _divisionController;
  List<String> _filteredDivisions = Divisions.all;
  bool _showDivisionList = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.entry.name);
    _notesController = TextEditingController(
        text: widget.entry.notes ?? '');
    _divisionController = TextEditingController(
        text: widget.entry.division ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _divisionController.dispose();
    super.dispose();
  }

  void _filterDivisions(String query) {
    setState(() {
      _filteredDivisions = query.isEmpty
          ? Divisions.all
          : Divisions.all
              .where((d) => d
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (widget.entry.startTime ??
              const TimeOfDay(hour: 8, minute: 0))
          : (widget.entry.endTime ??
              const TimeOfDay(hour: 9, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          widget.entry.startTime = picked;
        } else {
          widget.entry.endTime = picked;
        }
      });
      widget.onChanged();
    }
  }

  Future<void> _addPhoto(String type) async {
    final source =
        await _showPhotoSourceDialog(context);
    if (source == null) return;

    final XFile? picked = source == 'camera'
        ? await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85);

    if (picked == null) return;
    setState(() => widget.entry.photos
        .add(_TaskPhoto(path: picked.path, type: type)));
    widget.onChanged();
  }

  Future<String?> _showPhotoSourceDialog(
      BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add Photo',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt,
                  color: Theme.of(context)
                      .colorScheme
                      .primary),
              title: const Text('Take Photo'),
              onTap: () =>
                  Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library,
                  color: Theme.of(context)
                      .colorScheme
                      .primary),
              title:
                  const Text('Upload from Gallery'),
              onTap: () =>
                  Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;
    final surfaceAlt =
        Theme.of(context).dividerColor;
    final bodyColor =
        Theme.of(context).textTheme.bodyLarge?.color;
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text('Task ${widget.index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .error),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Name
            TextField(
              controller: _nameController,
              style: TextStyle(color: bodyColor),
              decoration: const InputDecoration(
                  hintText: 'Task name'),
              onChanged: (v) {
                widget.entry.name = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),

            // Division
            if (widget.entry.division != null &&
                !_showDivisionList)
              GestureDetector(
                onTap: () => setState(() {
                  _showDivisionList = true;
                  _divisionController.text =
                      widget.entry.division!;
                  _filterDivisions(
                      widget.entry.division!);
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        primary.withOpacity(0.12),
                    borderRadius:
                        BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              widget.entry.division!,
                              style: TextStyle(
                                  color: primary,
                                  fontWeight:
                                      FontWeight
                                          .w600))),
                      Icon(Icons.edit,
                          size: 14, color: primary),
                    ],
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _divisionController,
                style: TextStyle(color: bodyColor),
                decoration: InputDecoration(
                  hintText: 'Division (optional)',
                  prefixIcon: Icon(Icons.search,
                      color: mutedColor, size: 18),
                  suffixIcon: _divisionController
                          .text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: mutedColor,
                              size: 16),
                          onPressed: () {
                            _divisionController
                                .clear();
                            _filterDivisions('');
                            setState(() => widget
                                .entry.division = null);
                          },
                        )
                      : null,
                ),
                onTap: () => setState(
                    () => _showDivisionList = true),
                onChanged: (v) {
                  _filterDivisions(v);
                  setState(
                      () => _showDivisionList = true);
                },
              ),
              if (_showDivisionList) ...[
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(
                      maxHeight: 160),
                  decoration: BoxDecoration(
                    color: surfaceAlt,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount:
                        _filteredDivisions.length,
                    itemBuilder: (context, i) {
                      final div =
                          _filteredDivisions[i];
                      return InkWell(
                        onTap: () => setState(() {
                          widget.entry.division =
                              div;
                          _showDivisionList = false;
                          _divisionController.text =
                              div;
                          widget.onChanged();
                        }),
                        child: Padding(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 14,
                              vertical: 10),
                          child: Text(div,
                              style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
            const SizedBox(height: 10),

            // Times
            Row(
              children: [
                Expanded(
                  child: _TimeTap(
                    label: 'Start',
                    time: widget.entry.startTime,
                    color: AppColors.success,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeTap(
                    label: 'End',
                    time: widget.entry.endTime,
                    color: primary,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Notes
            TextField(
              controller: _notesController,
              style: TextStyle(color: bodyColor),
              maxLines: 2,
              decoration: const InputDecoration(
                  hintText: 'Notes (optional)'),
              onChanged: (v) {
                widget.entry.notes = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),

            // Photos
            Row(
              children: [
                _PhotoAddButton(
                  label: 'Before',
                  color: AppColors.success,
                  onTap: () => _addPhoto('before'),
                ),
                const SizedBox(width: 6),
                _PhotoAddButton(
                  label: 'After',
                  color: primary,
                  onTap: () => _addPhoto('after'),
                ),
                const SizedBox(width: 6),
                _PhotoAddButton(
                  label: 'General',
                  color: Colors.blueGrey,
                  onTap: () => _addPhoto('general'),
                ),
              ],
            ),
            if (widget.entry.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      widget.entry.photos.length,
                  itemBuilder: (context, i) {
                    final photo =
                        widget.entry.photos[i];
                    return Stack(
                      children: [
                        Container(
                          margin:
                              const EdgeInsets.only(
                                  right: 8),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                                    8),
                            child: Image.file(
                              File(photo.path),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => setState(() =>
                                widget.entry.photos
                                    .removeAt(i)),
                            child: Container(
                              padding:
                                  const EdgeInsets
                                      .all(2),
                              decoration:
                                  const BoxDecoration(
                                color: Colors.black54,
                                shape:
                                    BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
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
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _TimeTap extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final Color color;
  final VoidCallback onTap;

  const _TimeTap({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: time != null
                ? color.withOpacity(0.12)
                : Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: time != null
                  ? color.withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                      fontSize: 12)),
              Text(
                time != null
                    ? time!.format(context)
                    : 'Tap to set',
                style: TextStyle(
                  color: time != null
                      ? color
                      : Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
}

class _PhotoAddButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PhotoAddButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                  color: color.withOpacity(0.5)),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.add_a_photo,
                    color: color, size: 16),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}