import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../utils/divisions.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class TaskTimeEntry {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
}

class TaskPhotoData {
  final String path;
  final String type;
  TaskPhotoData({required this.path, required this.type});
}

class TaskEntryData {
  String name = '';
  String? division;
  String? notes;
  List<TaskTimeEntry> times = [TaskTimeEntry()];
  List<TaskPhotoData> photos = [];
}

// ── TaskEntryCard ─────────────────────────────────────────────────────────────

class TaskEntryCard extends StatefulWidget {
  final int index;
  final TaskEntryData entry;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const TaskEntryCard({
    super.key,
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<TaskEntryCard> createState() => _TaskEntryCardState();
}

class _TaskEntryCardState extends State<TaskEntryCard> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _divisionController;
  List<String> _filteredDivisions = Divisions.all;
  bool _showDivisionList = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _notesController = TextEditingController(text: widget.entry.notes ?? '');
    _divisionController =
        TextEditingController(text: widget.entry.division ?? '');
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
              .where((d) =>
                  d.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  Future<void> _pickTime(TaskTimeEntry entry, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (entry.startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (entry.endTime ?? const TimeOfDay(hour: 9, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          entry.startTime = picked;
        } else {
          entry.endTime = picked;
        }
      });
      widget.onChanged();
    }
  }

  Future<void> _addPhoto(String type) async {
    final source = await _showPhotoSourceDialog(context);
    if (source == null) return;
    final XFile? picked = source == 'camera'
        ? await _picker.pickImage(
            source: ImageSource.camera, imageQuality: 85)
        : await _picker.pickImage(
            source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => widget.entry.photos
        .add(TaskPhotoData(path: picked.path, type: type)));
    widget.onChanged();
  }

  Future<String?> _showPhotoSourceDialog(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Photo',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: Icon(Icons.photo_library,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Upload from Gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        ),
      );

  String _duration(TimeOfDay i, TimeOfDay o) {
    final diff =
        (o.hour * 60 + o.minute) - (i.hour * 60 + i.minute);
    if (diff <= 0) return 'Check times';
    return TimeUtils.formatDuration(
        TimeUtils.roundToNearest15(Duration(minutes: diff)));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surfaceAlt = Theme.of(context).dividerColor;
    final bodyColor = Theme.of(context).textTheme.bodyLarge?.color;
    final mutedColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Task ${widget.index + 1}',
                    style: Theme.of(context).textTheme.labelLarge),
                IconButton(
                  icon: Icon(Icons.close,
                      size: 16,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Name
            TextField(
              controller: _nameController,
              style: TextStyle(color: bodyColor),
              decoration: const InputDecoration(hintText: 'Task name'),
              onChanged: (v) {
                widget.entry.name = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),

            // Division
            if (widget.entry.division != null && !_showDivisionList)
              GestureDetector(
                onTap: () => setState(() {
                  _showDivisionList = true;
                  _divisionController.text = widget.entry.division!;
                  _filterDivisions(widget.entry.division!);
                }),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: primary.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(widget.entry.division!,
                              style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w600))),
                      Icon(Icons.edit, size: 14, color: primary),
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
                  prefixIcon:
                      Icon(Icons.search, color: mutedColor, size: 18),
                  suffixIcon: _divisionController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: mutedColor, size: 16),
                          onPressed: () {
                            _divisionController.clear();
                            _filterDivisions('');
                            setState(() => widget.entry.division = null);
                          },
                        )
                      : null,
                ),
                onTap: () =>
                    setState(() => _showDivisionList = true),
                onChanged: (v) {
                  _filterDivisions(v);
                  setState(() => _showDivisionList = true);
                },
              ),
              if (_showDivisionList) ...[
                const SizedBox(height: 4),
                Container(
                  constraints:
                      const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredDivisions.length,
                    itemBuilder: (context, i) {
                      final div = _filteredDivisions[i];
                      return InkWell(
                        onTap: () => setState(() {
                          widget.entry.division = div;
                          _showDivisionList = false;
                          _divisionController.text = div;
                          widget.onChanged();
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Text(div,
                              style: TextStyle(
                                  color: bodyColor, fontSize: 13)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
            const SizedBox(height: 10),

            // Times — multiple sessions allowed
            ...widget.entry.times.asMap().entries.expand((e) {
              final i = e.key;
              final te = e.value;
              return <Widget>[
                Row(
                  children: [
                    Expanded(
                      child: TimeTap(
                        label: 'Start',
                        time: te.startTime,
                        color: AppColors.success,
                        onTap: () => _pickTime(te, true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TimeTap(
                        label: 'End',
                        time: te.endTime,
                        color: primary,
                        onTap: () => _pickTime(te, false),
                      ),
                    ),
                    if (widget.entry.times.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.close,
                            size: 14,
                            color:
                                Theme.of(context).colorScheme.error),
                        onPressed: () {
                          setState(
                              () => widget.entry.times.removeAt(i));
                          widget.onChanged();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ],
                ),
                if (te.startTime != null && te.endTime != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 2, bottom: 2),
                    child: Text(
                      _duration(te.startTime!, te.endTime!),
                      style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 8),
              ];
            }).toList(),
            OutlinedButton.icon(
              icon: Icon(Icons.add, color: primary, size: 14),
              label: Text('Add Time',
                  style: TextStyle(color: primary, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: primary.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(
                    () => widget.entry.times.add(TaskTimeEntry()));
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),

            // Notes
            TextField(
              controller: _notesController,
              style: TextStyle(color: bodyColor),
              maxLines: 2,
              decoration:
                  const InputDecoration(hintText: 'Notes (optional)'),
              onChanged: (v) {
                widget.entry.notes = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 10),

            // Photos
            Row(
              children: [
                PhotoAddBtn(
                    label: 'Before',
                    color: AppColors.success,
                    onTap: () => _addPhoto('before')),
                const SizedBox(width: 6),
                PhotoAddBtn(
                    label: 'After',
                    color: primary,
                    onTap: () => _addPhoto('after')),
                const SizedBox(width: 6),
                PhotoAddBtn(
                    label: 'General',
                    color: Colors.blueGrey,
                    onTap: () => _addPhoto('general')),
              ],
            ),
            if (widget.entry.photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.entry.photos.length,
                  itemBuilder: (context, i) {
                    final photo = widget.entry.photos[i];
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(photo.path),
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 10,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => widget.entry.photos.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 12),
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

// ── TimeTap ───────────────────────────────────────────────────────────────────

class TimeTap extends StatelessWidget {
  final String label;
  final dynamic time; // TimeOfDay or DateTime or null
  final Color color;
  final VoidCallback? onTap;

  const TimeTap({
    super.key,
    required this.label,
    required this.time,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = onTap != null;
    return GestureDetector(
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
            color: time != null && canTap
                ? color.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12)),
            Text(
              time != null
                  ? (time is TimeOfDay
                      ? time.format(context)
                      : TimeUtils.formatTime(time))
                  : 'Tap to set',
              style: TextStyle(
                color: time != null && canTap
                    ? color
                    : Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── PhotoAddBtn ───────────────────────────────────────────────────────────────

class PhotoAddBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const PhotoAddBtn({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(Icons.add_a_photo, color: color, size: 16),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}
