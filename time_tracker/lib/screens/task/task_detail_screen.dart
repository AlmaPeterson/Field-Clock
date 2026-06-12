import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/task.dart';
import '../../models/task_photo.dart';
import '../../database/dao/task_dao.dart';
import '../../database/dao/task_photo_dao.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../../utils/divisions.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() =>
      _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _divisionSearchController;
  late DateTime _startTime;
  late DateTime? _endTime;
  String? _selectedDivision;
  List<String> _filteredDivisions = Divisions.all;
  bool _showDivisionList = false;
  List<TaskPhoto> _photos = [];
  bool _saving = false;
  final _photoDao = TaskPhotoDao();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.task.name);
    _notesController =
        TextEditingController(text: widget.task.notes ?? '');
    _divisionSearchController = TextEditingController(
        text: widget.task.division ?? '');
    _selectedDivision = widget.task.division;
    _startTime = widget.task.startTime;
    _endTime = widget.task.endTime;
    _loadPhotos();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _divisionSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    if (widget.task.id == null) return;
    final photos =
        await _photoDao.getByTask(widget.task.id!);
    setState(() => _photos = photos);
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

  Future<void> _pickTime({required bool isStart}) async {
    final initial =
        isStart ? _startTime : (_endTime ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context)
              .colorScheme
              .copyWith(
                  primary:
                      Theme.of(context).colorScheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final base =
          isStart ? _startTime : (_endTime ?? DateTime.now());
      final updated = DateTime(base.year, base.month,
          base.day, picked.hour, picked.minute);
      if (isStart) {
        _startTime = updated;
      } else {
        _endTime = updated;
      }
    });
  }

  Future<void> _addPhoto(String type) async {
    final source = await _showPhotoSourceDialog();
    if (source == null) return;

    final XFile? picked = source == 'camera'
        ? await _picker.pickImage(
            source: ImageSource.camera,
            imageQuality: 85)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 85);

    if (picked == null) return;

    final photo = TaskPhoto(
      taskId: widget.task.id!,
      photoPath: picked.path,
      photoType: type,
      createdAt: DateTime.now(),
    );
    final id = await _photoDao.insert(photo);
    setState(() => _photos.add(photo.copyWith(id: id)));
  }

  Future<String?> _showPhotoSourceDialog() async {
    return showModalBottomSheet<String>(
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
                style:
                    Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.camera_alt,
                  color:
                      Theme.of(context).colorScheme.primary),
              title: const Text('Take Photo'),
              onTap: () =>
                  Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library,
                  color:
                      Theme.of(context).colorScheme.primary),
              title: const Text('Upload from Gallery'),
              onTap: () =>
                  Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setAsPrimary(
      TaskPhoto photo, String type) async {
    // Update task's startPhoto or endPhoto
    final updatedTask = Task(
      id: widget.task.id,
      workDayId: widget.task.workDayId,
      name: _nameController.text.trim(),
      division: _selectedDivision,
      notes: _notesController.text.trim(),
      startTime: _startTime,
      startPhoto: type == 'before'
          ? photo.photoPath
          : widget.task.startPhoto,
      startLocation: widget.task.startLocation,
      endTime: _endTime,
      endPhoto: type == 'after'
          ? photo.photoPath
          : widget.task.endPhoto,
      endLocation: widget.task.endLocation,
      durationMinutesRaw: widget.task.durationMinutesRaw,
      durationMinutesRounded:
          widget.task.durationMinutesRounded,
      hourlyRate: widget.task.hourlyRate,
    );
    await TaskDao().update(updatedTask);

    // Update photo type
    final updatedPhoto = photo.copyWith(photoType: type);
    await _photoDao.update(updatedPhoto);
    await _loadPhotos();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Set as ${type == 'before' ? 'Before' : 'After'} photo')),
      );
    }
  }

  Future<void> _deletePhoto(TaskPhoto photo) async {
    await _photoDao.delete(photo.id!);
    setState(
        () => _photos.removeWhere((p) => p.id == photo.id));
  }

  Future<void> _viewPhoto(TaskPhoto photo) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullPhotoScreen(
          photo: photo,
          onSetBefore: () =>
              _setAsPrimary(photo, 'before'),
          onSetAfter: () =>
              _setAsPrimary(photo, 'after'),
          onDelete: () => _deletePhoto(photo),
        ),
      ),
    );
  }

  int get _rawMinutes => _endTime != null
      ? _endTime!.difference(_startTime).inMinutes
      : 0;

  int get _roundedMinutes =>
      TimeUtils.roundToNearest15(Duration(minutes: _rawMinutes))
          .inMinutes;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final updated = Task(
      id: widget.task.id,
      workDayId: widget.task.workDayId,
      name: _nameController.text.trim().isEmpty
          ? 'Unnamed Task'
          : _nameController.text.trim(),
      division: _selectedDivision,
      notes: _notesController.text.trim(),
      startTime: _startTime,
      startPhoto: widget.task.startPhoto,
      startLocation: widget.task.startLocation,
      endTime: _endTime,
      endPhoto: widget.task.endPhoto,
      endLocation: widget.task.endLocation,
      durationMinutesRaw: _rawMinutes,
      durationMinutesRounded: _roundedMinutes,
      hourlyRate: widget.task.hourlyRate,
    );

    await TaskDao().update(updated);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Delete Task'),
        content: const Text(
            'Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .error))),
        ],
      ),
    );
    if (confirm != true) return;
    if (widget.task.id != null) {
      await _photoDao.deleteByTask(widget.task.id!);
      await TaskDao().delete(widget.task.id!);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color;
    final bodyColor =
        Theme.of(context).textTheme.bodyLarge?.color;
    final surfaceAlt = Theme.of(context).dividerColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Task'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline,
                color:
                    Theme.of(context).colorScheme.error),
            onPressed: _delete,
          ),
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
          // ── Name ──────────────────────────────────────
          _Label('TASK NAME'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: TextStyle(color: bodyColor),
            decoration: const InputDecoration(
                hintText: 'e.g. Framing — Master Bedroom'),
          ),
          const SizedBox(height: 20),

          // ── Division ──────────────────────────────────
          _Label('DIVISION (OPTIONAL)'),
          const SizedBox(height: 8),
          if (_selectedDivision != null && !_showDivisionList)
            GestureDetector(
              onTap: () => setState(() {
                _showDivisionList = true;
                _divisionSearchController.text =
                    _selectedDivision!;
                _filterDivisions(_selectedDivision!);
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(_selectedDivision!,
                            style: TextStyle(
                                color: primary,
                                fontWeight:
                                    FontWeight.w600))),
                    Icon(Icons.edit,
                        size: 14, color: primary),
                  ],
                ),
              ),
            )
          else ...[
            TextField(
              controller: _divisionSearchController,
              style: TextStyle(color: bodyColor),
              decoration: InputDecoration(
                hintText: 'Search divisions...',
                prefixIcon: Icon(Icons.search,
                    color: mutedColor, size: 18),
                suffixIcon: _divisionSearchController
                        .text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: mutedColor, size: 16),
                        onPressed: () {
                          _divisionSearchController.clear();
                          _filterDivisions('');
                          setState(
                              () => _selectedDivision = null);
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
                    const BoxConstraints(maxHeight: 200),
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
                        _selectedDivision = div;
                        _showDivisionList = false;
                        _divisionSearchController.text =
                            div;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Text(div,
                            style: TextStyle(
                                color: bodyColor,
                                fontSize: 14)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),

          // ── Times ─────────────────────────────────────
          _Label('TIMES'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _TimeRow(
                  label: 'Start',
                  time: _startTime,
                  onTap: () => _pickTime(isStart: true),
                ),
                Divider(
                    height: 1, color: surfaceAlt),
                _TimeRow(
                  label: 'End',
                  time: _endTime,
                  onTap: () => _pickTime(isStart: false),
                ),
              ],
            ),
          ),
          if (_endTime != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Duration (rounded to 15 min)',
                      style: TextStyle(
                          color: mutedColor, fontSize: 13)),
                  Text(
                    TimeUtils.formatDuration(Duration(
                        minutes: _roundedMinutes)),
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ── Notes ─────────────────────────────────────
          _Label('NOTES'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            style: TextStyle(color: bodyColor),
            maxLines: 3,
            decoration: const InputDecoration(
                hintText:
                    'Materials used, issues found...'),
          ),
          const SizedBox(height: 20),

          // ── Photos ────────────────────────────────────
          _Label('PHOTOS'),
          const SizedBox(height: 8),
          _PhotoGallery(
            photos: _photos,
            task: widget.task,
            onAdd: _addPhoto,
            onTap: _viewPhoto,
          ),
          const SizedBox(height: 20),

          // ── Location ──────────────────────────────────
          if (widget.task.startLocation != null) ...[
            _Label('LOCATION'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: mutedColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            widget.task.startLocation!,
                            style: TextStyle(
                                color: mutedColor))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Delete ────────────────────────────────────
          OutlinedButton.icon(
            icon: Icon(Icons.delete_outline,
                color:
                    Theme.of(context).colorScheme.error),
            label: Text('Delete Task',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color:
                      Theme.of(context).colorScheme.error),
              padding:
                  const EdgeInsets.symmetric(vertical: 14),
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

// ── Photo Gallery Widget ──────────────────────────────────────────────────────

class _PhotoGallery extends StatelessWidget {
  final List<TaskPhoto> photos;
  final Task task;
  final Function(String type) onAdd;
  final Function(TaskPhoto photo) onTap;

  const _PhotoGallery({
    required this.photos,
    required this.task,
    required this.onAdd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surfaceAlt = Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add photo buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo,
                    size: 16),
                label: const Text('Before'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.success,
                  side: const BorderSide(
                      color: AppColors.success),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
                onPressed: () => onAdd('before'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_a_photo,
                    size: 16),
                label: const Text('After'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
                onPressed: () => onAdd('after'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate,
                    size: 16),
                label: const Text('General'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color,
                  side: BorderSide(
                      color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color ??
                          Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10)),
                ),
                onPressed: () => onAdd('general'),
              ),
            ),
          ],
        ),

        // Photo grid
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: photos.length,
            itemBuilder: (context, i) {
              final photo = photos[i];
              return GestureDetector(
                onTap: () => onTap(photo),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(8),
                      child: Image.file(
                        File(photo.photoPath),
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Type badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2),
                        decoration: BoxDecoration(
                          color: _badgeColor(
                                  photo.photoType)
                              .withOpacity(0.85),
                          borderRadius:
                              BorderRadius.circular(4),
                        ),
                        child: Text(
                          _badgeLabel(photo.photoType),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ] else ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color,
                    size: 32),
                const SizedBox(height: 8),
                Text('No photos yet',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _badgeColor(String type) {
    switch (type) {
      case 'before':
        return AppColors.success;
      case 'after':
        return AppColors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  String _badgeLabel(String type) {
    switch (type) {
      case 'before':
        return 'BEFORE';
      case 'after':
        return 'AFTER';
      default:
        return 'GENERAL';
    }
  }
}

// ── Full Photo Screen ─────────────────────────────────────────────────────────

class _FullPhotoScreen extends StatelessWidget {
  final TaskPhoto photo;
  final VoidCallback onSetBefore;
  final VoidCallback onSetAfter;
  final VoidCallback onDelete;

  const _FullPhotoScreen({
    required this.photo,
    required this.onSetBefore,
    required this.onSetAfter,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme:
            const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            color: Theme.of(context).cardColor,
            onSelected: (val) {
              Navigator.pop(context);
              if (val == 'before') onSetBefore();
              if (val == 'after') onSetAfter();
              if (val == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'before',
                child: Text('Set as Before Photo'),
              ),
              const PopupMenuItem(
                value: 'after',
                child: Text('Set as After Photo'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Photo',
                    style:
                        TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(File(photo.photoPath)),
        ),
      ),
    );
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
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
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge),
              Row(
                children: [
                  Text(
                    time != null
                        ? TimeUtils.formatTime(time!)
                        : 'Not set',
                    style: TextStyle(
                      color: time != null
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                          : Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit,
                      size: 14,
                      color: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.color),
                ],
              ),
            ],
          ),
        ),
      );
}