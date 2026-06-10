import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../database/dao/task_dao.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late DateTime _startTime;
  late DateTime? _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.task.name);
    _notesController =
        TextEditingController(text: widget.task.notes ?? '');
    _startTime = widget.task.startTime;
    _endTime = widget.task.endTime;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : (_endTime ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            backgroundColor: Theme.of(context).cardColor,
            hourMinuteColor: Theme.of(context).dividerColor,
            hourMinuteTextColor: Theme.of(context).textTheme.bodyLarge!.color!,
            dayPeriodColor: Theme.of(context).dividerColor,
            dayPeriodTextColor: Theme.of(context).textTheme.bodyLarge!.color!,
            dialBackgroundColor: Theme.of(context).dividerColor,
            dialHandColor: Theme.of(context).colorScheme.primary,
            dialTextColor: Theme.of(context).textTheme.bodyLarge!.color!,
            entryModeIconColor: Theme.of(context).colorScheme.primary,
          ),
          colorScheme: ColorScheme.dark(
            primary: Theme.of(context).colorScheme.primary,
            surface: Theme.of(context).cardColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    setState(() {
      final base = isStart ? _startTime : (_endTime ?? DateTime.now());
      final updated = DateTime(
        base.year, base.month, base.day,
        picked.hour, picked.minute,
      );
      if (isStart) {
        _startTime = updated;
      } else {
        _endTime = updated;
      }
    });
  }

  int get _rawMinutes =>
      _endTime != null ? _endTime!.difference(_startTime).inMinutes : 0;

  int get _roundedMinutes =>
      TimeUtils.roundToNearest15(Duration(minutes: _rawMinutes)).inMinutes;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final updated = widget.task.copyWith(
      name: _nameController.text.trim().isEmpty
          ? 'Unnamed Task'
          : _nameController.text.trim(),
      notes: _notesController.text.trim(),
      endTime: _endTime,
      durationMinutesRaw: _rawMinutes,
      durationMinutesRounded: _roundedMinutes,
    );

    // Need a custom copyWith that also updates startTime
    final withStart = Task(
      id: updated.id,
      workDayId: updated.workDayId,
      name: updated.name,
      notes: updated.notes,
      startTime: _startTime,
      startPhoto: updated.startPhoto,
      startLocation: updated.startLocation,
      endTime: updated.endTime,
      endPhoto: updated.endPhoto,
      endLocation: updated.endLocation,
      durationMinutesRaw: updated.durationMinutesRaw,
      durationMinutesRounded: updated.durationMinutesRounded,
      hourlyRate: updated.hourlyRate,
    );

    await TaskDao().update(withStart);

    if (mounted) {
      Navigator.pop(context, true); // true = was edited
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Task',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
        content: Text(
            'Are you sure? This cannot be undone.',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await TaskDao().delete(widget.task.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            onPressed: _delete,
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                  )
                : Text('Save',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Name
          _SectionLabel('TASK NAME'),
          const SizedBox(height: 8),
          _InputField(
            controller: _nameController,
            hint: 'e.g. Framing — Master Bedroom',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 20),

          // Times
          _SectionLabel('TIMES'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _TimeRow(
                  label: 'Start',
                  time: _startTime,
                  onTap: () => _pickTime(isStart: true),
                ),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                _TimeRow(
                  label: 'End',
                  time: _endTime,
                  onTap: () => _pickTime(isStart: false),
                ),
              ],
            ),
          ),

          // Duration preview
          if (_endTime != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Duration (rounded to 15 min)',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    TimeUtils.formatDuration(
                        Duration(minutes: _roundedMinutes)),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Notes
          _SectionLabel('NOTES'),
          const SizedBox(height: 8),
          _InputField(
            controller: _notesController,
            hint: 'Materials used, issues found...',
            keyboardType: TextInputType.multiline,
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Photos
          if (widget.task.startPhoto != null ||
              widget.task.endPhoto != null) ...[
            _SectionLabel('PHOTOS'),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.task.startPhoto != null)
                  _PhotoCard(
                      label: 'BEFORE',
                      path: widget.task.startPhoto!),
                if (widget.task.startPhoto != null &&
                    widget.task.endPhoto != null)
                  const SizedBox(width: 10),
                if (widget.task.endPhoto != null)
                  _PhotoCard(
                      label: 'AFTER',
                      path: widget.task.endPhoto!),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Location
          if (widget.task.startLocation != null) ...[
            _SectionLabel('LOCATION'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Theme.of(context).textTheme.bodyMedium!.color!, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.task.startLocation!,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Delete button
          OutlinedButton.icon(
            icon: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            label: Text('Delete Task',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _delete,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!),
          filled: true,
          fillColor: Theme.of(context).dividerColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
}

class _TimeRow extends StatelessWidget {
  final String label;
  final DateTime? time;
  final VoidCallback onTap;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.bodyLarge),
              Row(
                children: [
                  Text(
                    time != null
                        ? TimeUtils.formatTime(time!)
                        : 'Not set',
                    style: TextStyle(
                      color: time != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).textTheme.bodyMedium!.color!,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit,
                      size: 14, color: Theme.of(context).textTheme.bodyMedium!.color!),
                ],
              ),
            ],
          ),
        ),
      );
}

class _PhotoCard extends StatelessWidget {
  final String label;
  final String path;

  const _PhotoCard({required this.label, required this.path});

  @override
  Widget build(BuildContext context) => Expanded(
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
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(path),
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      );
}